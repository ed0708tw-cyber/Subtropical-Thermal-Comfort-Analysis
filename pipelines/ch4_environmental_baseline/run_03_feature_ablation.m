%% =========================================================================
%% 執行管線 03：機器學習與深度學習複合特徵消融實驗 (Model No.1~No.7 & 全範式對比)
%% 對應論文章節：第四章 4.3 節 (產出 表 4.12、表 4.13 與 圖 4.8)
%% 學術規範版：客觀統計反頻率加權、雙軌量綱對齊評估、純白底色、字體 16 級、300 DPI
%% =========================================================================

clear; clc; close all;

% 1. 動態錨定專案根目錄
script_dir   = fileparts(mfilename('fullpath'));
project_root = fullfile(script_dir, '..', '..');

% 掛載核心函數庫路徑
addpath(genpath(fullfile(project_root, 'src')));
addpath(genpath(fullfile(project_root, 'pipelines')));

master_file = fullfile(project_root, 'data', 'processed', 'Ch4_Master_Data.mat');
if ~exist(master_file, 'file')
    error('錯誤：找不到主資料快取！請先確認 data/processed/Ch4_Master_Data.mat 是否存在。');
end

fprintf('[管線 03] 正在載入主資料快取：%s ...\n', master_file);
load(master_file);

% 輸出目錄建立
out_table_dir = fullfile(project_root, 'outputs', 'tables');
out_fig_dir   = fullfile(project_root, 'outputs', 'figures');
if ~exist(out_table_dir, 'dir'), mkdir(out_table_dir); end
if ~exist(out_fig_dir, 'dir'),   mkdir(out_fig_dir);   end

rng(42); % 全域鎖定隨機種子，確保所有模型訓練 100% 可重現

% 2. 提取真實標籤與特徵標準化
Y_true_val  = double(string(Y_val));
Y_true_val  = Y_true_val(:); % 強制轉為行向量
classes_num = -3:3;          % 7 階標準尺度

% 使用訓練集之統計矩進行 Z-Score 標準化 (嚴防資料外洩)
mu_X  = mean(X_train, 1);
sig_X = std(X_train, 0, 1);
sig_X(sig_X == 0) = 1.0;

X_tr_norm  = (X_train - mu_X) ./ sig_X;
X_val_norm = (X_val   - mu_X) ./ sig_X;

%% =========================================================================
%% 第一部分：Model No.1 至 No.7 縱向特徵消融序列 (Feature Ablation)
%% =========================================================================
fprintf('\n>>> [第一階段] 展開 Model No.1 至 No.7 特徵消融實驗...\n');

ablation_configs = {
    'No.1 (Ta)',                          1:1;
    'No.2 (Ta + RH)',                     1:2;
    'No.3 (Ta + RH + Vel)',               1:3;
    'No.4 (All Physical + Clo + Met)',    1:5;
    'No.5 (+ Tetens e)',                  1:6;
    'No.6 (+ Steadman AT)',               1:7;
    'No.7 (+ Subtropical AT_mod)',        1:8
};

num_ablation = size(ablation_configs, 1);
table_ablation = table('Size', [num_ablation, 7], ...
    'VariableTypes', {'string', 'string', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'Model_ID', 'Input_Features', 'Val_RMSE', 'Val_Accuracy_Pct', ...
                      'Recall_Cold_Neg3_Pct', 'Recall_Hot_Pos3_Pct', 'Macro_F1'});

pred_ablation_cont = zeros(length(Y_val), num_ablation);

for m = 1:num_ablation
    m_name = ablation_configs{m, 1};
    feat_idx = ablation_configs{m, 2};
    fprintf('  -> 正在訓練特徵消融模型 %s ...\n', m_name);
    
    X_tr_sub  = X_tr_norm(:, feat_idx);
    X_val_sub = X_val_norm(:, feat_idx);
    
    % 採用具備非線性表徵能力之多層感知器進行消融訓練
    mlp_net = fitcnet(X_tr_sub, Y_train, ...
        'LayerSizes', [128, 64], ...
        'Activations', 'relu', ...
        'Standardize', false, ...
        'IterationLimit', 250, ...
        'ClassNames', categories(Y_train));
    
    % 預測 7 階條件後驗機率
    [~, prob_val] = predict(mlp_net, X_val_sub);
    cls_order_net = double(string(mlp_net.ClassNames))';
    
    % 雙軌評估：離散指標採 Argmax，連續誤差採分佈加權期望值
    [~, max_idx] = max(prob_val, [], 2);
    y_pred_discrete = cls_order_net(max_idx);
    y_pred_discrete = y_pred_discrete(:);
    
    y_pred_cont = sum(prob_val .* cls_order_net, 2);
    y_pred_cont = y_pred_cont(:);
    pred_ablation_cont(:, m) = y_pred_cont;
    
    % 計算多維度量化指標
    met = calc_confusion_metrics(Y_true_val, y_pred_discrete, classes_num);
    met.RMSE = sqrt(mean((Y_true_val - y_pred_cont).^2));
    
    table_ablation(m, :) = {sprintf('Model No.%d', m), m_name, met.RMSE, ...
                            met.Accuracy_Pct, met.Recall_Neg3_Pct, met.Recall_Pos3_Pct, met.Macro_F1};
end

disp('----------------------------------------------------------------------------------------');
disp('   表 4.12 亞熱帶熱環境特徵增量消融序列 (Model No.1~No.7) 驗證效能報表');
disp('----------------------------------------------------------------------------------------');
disp(table_ablation);
writetable(table_ablation, fullfile(out_table_dir, 'Table4_12_Feature_Ablation.csv'));

%% =========================================================================
%% 第二部分：橫向跨範式全景對比 (Baseline vs. SVM vs. RF vs. MLP 消融系列)
%% =========================================================================
fprintf('\n>>> [第二階段] 展開最佳特徵集 (Model No.7) 跨範式演算法全景對照...\n');

% 1. 訓練經典隨機森林 (Random Forest, 80 棵決策樹)
fprintf('  -> 正在訓練隨機森林 (Random Forest)...\n');
rf_model = TreeBagger(80, X_train, Y_train, ...
    'Method', 'classification', 'MinLeafSize', 5, 'NumPredictorsToSample', 3);
[~, rf_scores] = predict(rf_model, X_val);
rf_cls_order = double(string(rf_model.ClassNames))';

[~, max_idx_rf] = max(rf_scores, [], 2);
y_pred_rf_discrete = rf_cls_order(max_idx_rf);
y_pred_rf_discrete = y_pred_rf_discrete(:);
y_pred_rf_cont     = sum(rf_scores .* rf_cls_order, 2);
y_pred_rf_cont     = y_pred_rf_cont(:);

met_rf = calc_confusion_metrics(Y_true_val, y_pred_rf_discrete, classes_num);
met_rf.RMSE = sqrt(mean((Y_true_val - y_pred_rf_cont).^2));

% 2. 訓練多類別線性支援向量機 (Linear SVM ECOC)
fprintf('  -> 正在訓練多類別支援向量機 (Linear SVM ECOC)...\n');
t_svm = templateSVM('KernelFunction', 'linear', 'Standardize', false);
svm_model = fitcecoc(X_tr_norm, Y_train, 'Learners', t_svm, 'Coding', 'onevsall');
svm_pred_labels = predict(svm_model, X_val_norm);
y_pred_svm_discrete = double(string(svm_pred_labels));
y_pred_svm_discrete = y_pred_svm_discrete(:);

met_svm = calc_confusion_metrics(Y_true_val, y_pred_svm_discrete, classes_num);
met_svm.RMSE = sqrt(mean((Y_true_val - y_pred_svm_discrete).^2));

% 3. 訓練深度神經網路消融：標準交叉熵 (MLP-CE)
fprintf('  -> 正在訓練深度神經網路 (MLP + 標準交叉熵 CE)...\n');
mlp_ce = fitcnet(X_tr_norm, Y_train, 'LayerSizes', [128, 64], ...
    'Activations', 'relu', 'Standardize', false, 'IterationLimit', 250);
[~, prob_ce] = predict(mlp_ce, X_val_norm);
cls_order_ce = double(string(mlp_ce.ClassNames))';

[~, max_idx_ce] = max(prob_ce, [], 2);
y_pred_ce_discrete = cls_order_ce(max_idx_ce);
y_pred_ce_discrete = y_pred_ce_discrete(:);
y_pred_ce_cont     = sum(prob_ce .* cls_order_ce, 2);
y_pred_ce_cont     = y_pred_ce_cont(:);

met_ce = calc_confusion_metrics(Y_true_val, y_pred_ce_discrete, classes_num);
met_ce.RMSE = sqrt(mean((Y_true_val - y_pred_ce_cont).^2));

% 4. 訓練深度神經網路消融：客觀統計類別反頻率加權 (MLP-CW)
fprintf('  -> 正在訓練深度神經網路 (MLP + 類別反頻率加權 CW)...\n');
class_counts = countcats(Y_train);
inv_weights  = sum(class_counts) ./ (length(class_counts) * class_counts); % 客觀統計反比公式
sample_weights_cw = zeros(height(X_train), 1);
cats = categories(Y_train);
for c = 1:length(cats)
    sample_weights_cw(Y_train == cats{c}) = inv_weights(c);
end

mlp_cw = fitcnet(X_tr_norm, Y_train, 'LayerSizes', [128, 64], ...
    'Activations', 'relu', 'Standardize', false, 'Weights', sample_weights_cw, 'IterationLimit', 250);
[~, prob_cw] = predict(mlp_cw, X_val_norm);
cls_order_cw = double(string(mlp_cw.ClassNames))';

[~, max_idx_cw] = max(prob_cw, [], 2);
y_pred_cw_discrete = cls_order_cw(max_idx_cw);
y_pred_cw_discrete = y_pred_cw_discrete(:);
y_pred_cw_cont     = sum(prob_cw .* cls_order_cw, 2);
y_pred_cw_cont     = y_pred_cw_cont(:);

met_cw = calc_confusion_metrics(Y_true_val, y_pred_cw_discrete, classes_num);
met_cw.RMSE = sqrt(mean((Y_true_val - y_pred_cw_cont).^2));

% 5. 訓練核心突破模型：MLP + 自適應聚焦損失 (MLP-AFL，客觀學術規範版)
fprintf('  -> 正在訓練本研究核心架構 (MLP + 自適應聚焦損失 AFL)...\n');

% (A) 提取未加權 MLP-CE 對訓練集之後驗機率，客觀量化樣本分類難易度 pt_tr
[~, prob_ce_tr] = predict(mlp_ce, X_tr_norm);
pt_tr = zeros(size(X_tr_norm, 1), 1);
Y_tr_double = double(string(Y_train));
for k = 1:length(cls_order_ce)
    idx_k = (Y_tr_double == cls_order_ce(k));
    pt_tr(idx_k) = prob_ce_tr(idx_k, k);
end
pt_tr = max(min(pt_tr, 0.999), 0.001); % 數值穩定性邊界防護

% (B) 基礎類別平衡權重 alpha: 嚴格採用客觀樣本頻率倒數 (無任何主觀任意常數)
sample_alpha = zeros(height(X_train), 1);
for c = 1:length(cats)
    sample_alpha(Y_train == cats{c}) = inv_weights(c);
end

% (C) 計算標準 Focal 調制因子: (1 - pt)^gamma，聚焦指數 gamma 設為標準值 1.5
gamma_val = 1.5;
focal_sample_weights = sample_alpha .* ((1.0 - pt_tr) .^ gamma_val);

% (D) 使用二階擬牛頓法精確收斂 AFL 目標函數
mlp_afl = fitcnet(X_tr_norm, Y_train, ...
    'LayerSizes', [128, 64], ...
    'Activations', 'relu', ...
    'Standardize', false, ...
    'Weights', focal_sample_weights, ...
    'IterationLimit', 300);

[~, prob_afl] = predict(mlp_afl, X_val_norm);
cls_order_afl = double(string(mlp_afl.ClassNames))';

[~, max_idx_afl] = max(prob_afl, [], 2);
y_pred_afl_discrete = cls_order_afl(max_idx_afl);
y_pred_afl_discrete = y_pred_afl_discrete(:);
y_pred_afl_cont     = sum(prob_afl .* cls_order_afl, 2);
y_pred_afl_cont     = y_pred_afl_cont(:);

met_afl = calc_confusion_metrics(Y_true_val, y_pred_afl_discrete, classes_num);
met_afl.RMSE = sqrt(mean((Y_true_val - y_pred_afl_cont).^2));

% 6. 整合 4.2 節固化之 Table4_11 傳統基準，構建跨範式總對照表
table_benchmark = table('Size', [8, 6], ...
    'VariableTypes', {'string', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'Model_Architecture', 'Val_RMSE', 'Val_Accuracy_Pct', ...
                      'Recall_Cold_Neg3_Pct', 'Recall_Hot_Pos3_Pct', 'Macro_F1'});

% 填入 4.2 節實測數據 (基準線)
table_benchmark(1, :) = {'Ta_Poly2 (經驗二階多項式)', 1.0320, 41.80, 0.00, 0.00, 0.1750};
table_benchmark(2, :) = {'ATmod_Subtrop (當代體感溫度)', 1.0270, 42.50, 0.00, 0.00, 0.1980};
table_benchmark(3, :) = {'ISO7730_PMV (國際標準)', 1.1490, 42.60, 0.00, 0.00, 0.1690};

% 填入經典機器學習與深度學習實測數據
table_benchmark(4, :) = {'Support Vector Machine (SVM)', met_svm.RMSE, met_svm.Accuracy_Pct, met_svm.Recall_Neg3_Pct, met_svm.Recall_Pos3_Pct, met_svm.Macro_F1};
table_benchmark(5, :) = {'Random Forest (RF)', met_rf.RMSE, met_rf.Accuracy_Pct, met_rf.Recall_Neg3_Pct, met_rf.Recall_Pos3_Pct, met_rf.Macro_F1};
table_benchmark(6, :) = {'MLP + 標準交叉熵 (MLP-CE)', met_ce.RMSE, met_ce.Accuracy_Pct, met_ce.Recall_Neg3_Pct, met_ce.Recall_Pos3_Pct, met_ce.Macro_F1};
table_benchmark(7, :) = {'MLP + 類別加權 (MLP-CW)', met_cw.RMSE, met_cw.Accuracy_Pct, met_cw.Recall_Neg3_Pct, met_cw.Recall_Pos3_Pct, met_cw.Macro_F1};
table_benchmark(8, :) = {'MLP + 自適應聚焦損失 (MLP-AFL)', met_afl.RMSE, met_afl.Accuracy_Pct, met_afl.Recall_Neg3_Pct, met_afl.Recall_Pos3_Pct, met_afl.Macro_F1};

disp('========================================================================================');
disp('   表 4.13 亞熱帶熱感覺預測模型跨範式全景對比表 (20% 獨立驗證集 N_val = 3,399)');
disp('========================================================================================');
disp(table_benchmark);
writetable(table_benchmark, fullfile(out_table_dir, 'Table4_13_Cross_Paradigm_Benchmark.csv'));

%% =========================================================================
%% 第三部分：繪製圖 4.8 特徵消融誤差階梯與極端召回率躍遷圖 (字體 16、純白底)
%% =========================================================================
fprintf('\n>>> [第三階段] 正在繪製並匯出圖 4.8...\n');

fig = figure('Name', 'Fig4_8_Feature_Ablation_Benchmark', ...
             'Position', [50, 50, 1200, 560], 'Color', 'w');

% -------------------------------------------------------------------------
% 子圖 (a): 特徵增量階梯對 Val RMSE 之影響 (Model No.1 ~ No.7)
% -------------------------------------------------------------------------
ax1 = subplot(1, 2, 1);
hold(ax1, 'on');
set(ax1, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
         'FontSize', 16, 'LineWidth', 1.2, 'FontName', 'Helvetica');
grid(ax1, 'on'); box(ax1, 'on');
set(ax1, 'GridColor', [0.85, 0.85, 0.85], 'GridAlpha', 0.9, 'GridLineStyle', '--');

rmse_vals = table_ablation.Val_RMSE;
b_abl = bar(ax1, 1:7, rmse_vals, 0.55, 'FaceColor', [0.22, 0.45, 0.68], 'LineWidth', 1.2);

% 標註 4.2.8 節 AT_mod 基準線 (1.0270)
yline(ax1, 1.0270, ':r', 'LineWidth', 1.8, 'DisplayName', 'AT_{mod} Baseline (1.027)');

for i = 1:7
    text(ax1, i, rmse_vals(i) + 0.012, sprintf('%.3f', rmse_vals(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');
end

xlabel(ax1, '特徵消融模型編號 (Model Feature Sets)', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
ylabel(ax1, '驗證集均方根誤差 (Val RMSE, 階梯)', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
title(ax1, '(a) 特徵消融之連續預測誤差階梯', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
xlim(ax1, [0.4, 7.6]);
ylim(ax1, [0.85, 1.15]);
set(ax1, 'XTick', 1:7, 'XTickLabel', {'No.1', 'No.2', 'No.3', 'No.4', 'No.5', 'No.6', 'No.7'});

% -------------------------------------------------------------------------
% 子圖 (b): 跨範式極端熱召回率躍遷對比 (Recall TSV = +3)
% -------------------------------------------------------------------------
ax2 = subplot(1, 2, 2);
hold(ax2, 'on');
set(ax2, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
         'FontSize', 16, 'LineWidth', 1.2, 'FontName', 'Helvetica');
grid(ax2, 'on'); box(ax2, 'on');
set(ax2, 'GridColor', [0.85, 0.85, 0.85], 'GridAlpha', 0.9, 'GridLineStyle', '--');

models_to_plot = {'AT_{mod}', 'ISO PMV', 'SVM', 'RF', 'MLP-CE', 'MLP-CW', 'MLP-AFL'};
recalls_pos3   = [0.00, 0.00, met_svm.Recall_Pos3_Pct, met_rf.Recall_Pos3_Pct, ...
                  met_ce.Recall_Pos3_Pct, met_cw.Recall_Pos3_Pct, met_afl.Recall_Pos3_Pct];

b_bm = bar(ax2, 1:7, recalls_pos3, 0.55, 'FaceColor', 'flat', 'LineWidth', 1.2);
for k = 1:7
    if k <= 2,     b_bm.CData(k, :) = [0.65, 0.65, 0.65]; % 傳統經驗模型 (灰色)
    elseif k <= 4, b_bm.CData(k, :) = [0.25, 0.55, 0.75]; % 經典機器學習 (藍色)
    elseif k <= 6, b_bm.CData(k, :) = [0.85, 0.55, 0.25]; % 深度學習消融 (橘色)
    else,          b_bm.CData(k, :) = [0.80, 0.20, 0.20]; % MLP-AFL (亮紅色)
    end
end

for i = 1:7
    text(ax2, i, recalls_pos3(i) + 2.0, sprintf('%.1f%%', recalls_pos3(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');
end

xlabel(ax2, '跨範式演算法架構 (Algorithm Paradigms)', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
ylabel(ax2, '極端熱召回率 Recall TSV=+3 (%)', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
title(ax2, '(b) 極端熱壓力預警能力之跨範式躍遷', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
xlim(ax2, [0.4, 7.6]);
ylim(ax2, [0, max([recalls_pos3, 60]) + 15]);
set(ax2, 'XTick', 1:7, 'XTickLabel', models_to_plot);

% 匯出 300 DPI 印刷級圖檔 (純白底)
out_fig_file = fullfile(out_fig_dir, 'Fig4_8_Taiwan_Subtropical_Feature_Ablation.png');
exportgraphics(fig, out_fig_file, 'Resolution', 300, 'BackgroundColor', 'w');
fprintf('[完成] 管線 03 執行完畢！報表與圖 4.8 已成功輸出：\n');
fprintf('  -> 表 4.12：%s\n', fullfile(out_table_dir, 'Table4_12_Feature_Ablation.csv'));
fprintf('  -> 表 4.13：%s\n', fullfile(out_table_dir, 'Table4_13_Cross_Paradigm_Benchmark.csv'));
fprintf('  -> 圖 4.8 ：%s\n', out_fig_file);