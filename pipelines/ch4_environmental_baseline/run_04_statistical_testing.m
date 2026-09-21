%% =========================================================================
%% 執行管線 04：麥克尼馬配對統計檢定與迴歸誤差特徵 (REC) 曲線分析
%% 對應論文章節：第四章 4.4 節 (產出 表 4.14 與 圖 4.9)
%% 規範：字體 16 級、純白底色、線寬加粗、300 DPI 印刷級匯出
%% =========================================================================

clear; clc; close all;

% 1. 動態錨定專案根目錄與路徑掛載
script_dir   = fileparts(mfilename('fullpath'));
project_root = fullfile(script_dir, '..', '..');

addpath(genpath(fullfile(project_root, 'src')));
addpath(genpath(fullfile(project_root, 'pipelines')));

master_file = fullfile(project_root, 'data', 'processed', 'Ch4_Master_Data.mat');
if ~exist(master_file, 'file')
    error('錯誤：找不到主資料快取！請先確認 data/processed/Ch4_Master_Data.mat 是否存在。');
end

fprintf('[管線 04] 正在載入資料快取：%s ...\n', master_file);
load(master_file);

out_table_dir = fullfile(project_root, 'outputs', 'tables');
out_fig_dir   = fullfile(project_root, 'outputs', 'figures');
if ~exist(out_table_dir, 'dir'), mkdir(out_table_dir); end
if ~exist(out_fig_dir, 'dir'),   mkdir(out_fig_dir);   end

rng(42); % 鎖定隨機種子確保 100% 可重現

% 2. 真實標籤提取與特徵標準化
Y_true_val  = double(string(Y_val));
Y_true_val  = Y_true_val(:);
N_val       = length(Y_true_val);
classes_num = -3:3;

mu_X  = mean(X_train, 1);
sig_X = std(X_train, 0, 1);
sig_X(sig_X == 0) = 1.0;

X_tr_norm  = (X_train - mu_X) ./ sig_X;
X_val_norm = (X_val   - mu_X) ./ sig_X;

%% =========================================================================
%% 第一階段：重新載入/提取跨範式模型驗證集預測結果 (連續期望值與離散標籤)
%% =========================================================================
fprintf('\n>>> [第一階段] 提取驗證集雙軌預測結果 (N_val = %d)...\n', N_val);

% 1. 傳統經驗物理基準：當代副熱帶 AT_mod 線性迴歸
% 訓練集配適 TSV = a * AT_mod + b
p_at = polyfit(X_train(:, 8), double(string(Y_train)), 1);
y_cont_at = polyval(p_at, X_val(:, 8));
y_disc_at = round(min(max(y_cont_at, -3), 3));

% 2. 經驗二階多項式：Ta_Poly2
p_ta = polyfit(X_train(:, 1), double(string(Y_train)), 2);
y_cont_ta = polyval(p_ta, X_val(:, 1));
y_disc_ta = round(min(max(y_cont_ta, -3), 3));

% 3. 經典機器學習：隨機森林 (Random Forest)
fprintf('  -> 正在推論隨機森林 (RF)...\n');
rf_model = TreeBagger(80, X_train, Y_train, ...
    'Method', 'classification', 'MinLeafSize', 5, 'NumPredictorsToSample', 3);
[~, rf_scores] = predict(rf_model, X_val);
rf_cls_order = double(string(rf_model.ClassNames))';
[~, max_idx_rf] = max(rf_scores, [], 2);
y_disc_rf = rf_cls_order(max_idx_rf);
y_cont_rf = sum(rf_scores .* rf_cls_order, 2);

% 4. 經典機器學習：支援向量機 (SVM)
fprintf('  -> 正在推論支援向量機 (SVM)...\n');
t_svm = templateSVM('KernelFunction', 'linear', 'Standardize', false);
svm_model = fitcecoc(X_tr_norm, Y_train, 'Learners', t_svm, 'Coding', 'onevsall');
svm_pred = predict(svm_model, X_val_norm);
y_disc_svm = double(string(svm_pred));
y_cont_svm = y_disc_svm; % SVM 無連續期望機率，連續擬合以離散輸出代入

% 5. 深度神經網路：標準交叉熵 (MLP-CE)
fprintf('  -> 正在推論 MLP-CE ...\n');
mlp_ce = fitcnet(X_tr_norm, Y_train, 'LayerSizes', [128, 64], ...
    'Activations', 'relu', 'Standardize', false, 'IterationLimit', 250);
[~, prob_ce] = predict(mlp_ce, X_val_norm);
cls_order_ce = double(string(mlp_ce.ClassNames))';
[~, max_idx_ce] = max(prob_ce, [], 2);
y_disc_ce = cls_order_ce(max_idx_ce);
y_cont_ce = sum(prob_ce .* cls_order_ce, 2);

% 6. 深度神經網路：類別反頻率加權 (MLP-CW)
fprintf('  -> 正在推論 MLP-CW ...\n');
class_counts = countcats(Y_train);
inv_weights  = sum(class_counts) ./ (length(class_counts) * class_counts);
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
y_disc_cw = cls_order_cw(max_idx_cw);
y_cont_cw = sum(prob_cw .* cls_order_cw, 2);

% 7. 深度神經網路：自適應聚焦損失 (MLP-AFL)
fprintf('  -> 正在推論 MLP-AFL ...\n');
[~, prob_ce_tr] = predict(mlp_ce, X_tr_norm);
pt_tr = zeros(size(X_tr_norm, 1), 1);
Y_tr_double = double(string(Y_train));
for k = 1:length(cls_order_ce)
    idx_k = (Y_tr_double == cls_order_ce(k));
    pt_tr(idx_k) = prob_ce_tr(idx_k, k);
end
pt_tr = max(min(pt_tr, 0.999), 0.001);
sample_alpha = zeros(height(X_train), 1);
for c = 1:length(cats)
    sample_alpha(Y_train == cats{c}) = inv_weights(c);
end
gamma_val = 1.5;
focal_sample_weights = sample_alpha .* ((1.0 - pt_tr) .^ gamma_val);

mlp_afl = fitcnet(X_tr_norm, Y_train, 'LayerSizes', [128, 64], ...
    'Activations', 'relu', 'Standardize', false, 'Weights', focal_sample_weights, 'IterationLimit', 300);
[~, prob_afl] = predict(mlp_afl, X_val_norm);
cls_order_afl = double(string(mlp_afl.ClassNames))';
[~, max_idx_afl] = max(prob_afl, [], 2);
y_disc_afl = cls_order_afl(max_idx_afl);
y_cont_afl = sum(prob_afl .* cls_order_afl, 2);

%% =========================================================================
%% 第二階段：麥克尼馬配對統計檢定 (產出 表 4.14)
%% =========================================================================
fprintf('\n>>> [第二階段] 計算配對麥克尼馬檢定統計量...\n');

comparisons = {
    'RF vs. 當代 AT_mod',        y_disc_rf,  y_disc_at;
    'MLP-CE vs. 當代 AT_mod',    y_disc_ce,  y_disc_at;
    'MLP-CW vs. 當代 AT_mod',    y_disc_cw,  y_disc_at;
    'MLP-AFL vs. 當代 AT_mod',   y_disc_afl, y_disc_at;
    'RF vs. SVM',                y_disc_rf,  y_disc_svm;
    'RF vs. MLP-CE',             y_disc_rf,  y_disc_ce;
    'RF vs. MLP-CW',             y_disc_rf,  y_disc_cw;
    'RF vs. MLP-AFL',            y_disc_rf,  y_disc_afl;
    'MLP-CW vs. MLP-CE',         y_disc_cw,  y_disc_ce;
    'MLP-AFL vs. MLP-CE',        y_disc_afl, y_disc_ce;
    'MLP-AFL vs. MLP-CW',        y_disc_afl, y_disc_cw
};

num_comp = size(comparisons, 1);
table_mcnemar = table('Size', [num_comp, 7], ...
    'VariableTypes', {'string', 'double', 'double', 'double', 'double', 'string', 'string'}, ...
    'VariableNames', {'Comparison_Pair', 'Discordant_A_True_B_False', 'Discordant_A_False_B_True', ...
                      'Chi_Square_Stat', 'P_Value', 'Significance_Level', 'Academic_Inference'});

for i = 1:num_comp
    c_name = comparisons{i, 1};
    pred_A = comparisons{i, 2};
    pred_B = comparisons{i, 3};
    
    [p_val, chi2_stat, b, c] = mcnemar_test_yates(Y_true_val, pred_A, pred_B);
    
    % 標記統計顯著水準
    if p_val < 0.001
        sig_str = '*** (p < 0.001)';
        inf_str = '具備極高度統計顯著性差異';
    elseif p_val < 0.01
        sig_str = '** (p < 0.01)';
        inf_str = '具備高度統計顯著性差異';
    elseif p_val < 0.05
        sig_str = '* (p < 0.05)';
        inf_str = '具備統計顯著性差異';
    else
        sig_str = 'ns (p >= 0.05)';
        inf_str = '無統計顯著差異';
    end
    
    table_mcnemar(i, :) = {c_name, b, c, chi2_stat, p_val, sig_str, inf_str};
end

disp('----------------------------------------------------------------------------------------');
disp('   表 4.14 跨範式熱感覺預測模型麥克尼馬配對統計檢定總表 (N_val = 3,399)');
disp('----------------------------------------------------------------------------------------');
disp(table_mcnemar);
writetable(table_mcnemar, fullfile(out_table_dir, 'Table4_14_McNemar_Test.csv'));

%% =========================================================================
%% 第三階段：繪製迴歸誤差特徵 (REC) 曲線 (產出 圖 4.9，純白底，字體 16 級)
%% =========================================================================
fprintf('\n>>> [第三階段] 正在繪製並匯出圖 4.9 (REC 曲線)...\n');

fig = figure('Name', 'Fig4_9_REC_Curve', 'Position', [100, 100, 960, 680], 'Color', 'w');
ax = axes('Parent', fig);
hold(ax, 'on');
set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
        'FontSize', 16, 'LineWidth', 1.3, 'FontName', 'Helvetica');
grid(ax, 'on'); box(ax, 'on');
set(ax, 'GridColor', [0.85, 0.85, 0.85], 'GridAlpha', 0.9, 'GridLineStyle', '--');

% 容許誤差容限網格 (0 至 2.5 階梯，解析度 0.01)
tol_grid = 0:0.01:2.5;

models_rec = {
    'AT_{mod} (當代體感)',   y_cont_at,   [0.55, 0.55, 0.55], '--', 1.8;
    'Ta Poly2 (經驗多項式)', y_cont_ta,   [0.70, 0.70, 0.70], ':',  1.8;
    'SVM (線性超平面)',      y_cont_svm,  [0.15, 0.70, 0.75], '-.', 1.8;
    'Random Forest (RF)',    y_cont_rf,   [0.10, 0.35, 0.75], '-',  2.5;
    'MLP-CE (標準交叉熵)',   y_cont_ce,   [0.85, 0.55, 0.15], '-',  2.0;
    'MLP-CW (類別加權)',     y_cont_cw,   [0.20, 0.65, 0.30], '-',  2.0;
    'MLP-AFL (自適應聚焦)',  y_cont_afl,  [0.85, 0.15, 0.15], '-',  2.5
};

rec_curves = zeros(size(models_rec, 1), length(tol_grid));

for m = 1:size(models_rec, 1)
    m_name  = models_rec{m, 1};
    y_pred  = models_rec{m, 2};
    c_color = models_rec{m, 3};
    l_style = models_rec{m, 4};
    l_width = models_rec{m, 5};
    
    abs_err = abs(Y_true_val - y_pred(:));
    rec_acc = mean(abs_err <= tol_grid, 1) * 100;
    rec_curves(m, :) = rec_acc;
    
    plot(ax, tol_grid, rec_acc, 'Color', c_color, 'LineStyle', l_style, ...
         'LineWidth', l_width, 'DisplayName', m_name);
end

% 標註工程關鍵容許誤差容限：tau = 0.5 (嚴格區間) 與 tau = 1.0 (容許區間)
xline(ax, 0.5, ':k', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xline(ax, 1.0, ':k', 'LineWidth', 1.2, 'HandleVisibility', 'off');

text(ax, 0.51, 15, '\tau = 0.5 (精確區間)', 'FontSize', 13, 'FontWeight', 'bold', 'Color', [0.3, 0.3, 0.3]);
text(ax, 1.01, 15, '\tau = 1.0 (工程容許)', 'FontSize', 13, 'FontWeight', 'bold', 'Color', [0.3, 0.3, 0.3]);

xlabel(ax, '絕對預測誤差容許限值 \tau (Error Tolerance, 階梯)', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
ylabel(ax, '累積預測準確樣本覆蓋率 (%)', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
title(ax, '跨範式熱感覺預測模型迴歸誤差特徵 (REC) 曲線對比', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
xlim(ax, [0, 2.5]);
ylim(ax, [0, 100]);

lgd = legend(ax, 'Location', 'southeast', 'FontSize', 12);
set(lgd, 'Box', 'on', 'Color', 'w', 'EdgeColor', [0.7, 0.7, 0.7]);

% 匯出 300 DPI 印刷級圖檔
out_fig_file = fullfile(out_fig_dir, 'Fig4_9_REC_Curve.png');
exportgraphics(fig, out_fig_file, 'Resolution', 300, 'BackgroundColor', 'w');
fprintf('[完成] 管線 04 執行完畢！\n');
fprintf('  -> 表 4.14：%s\n', fullfile(out_table_dir, 'Table4_14_McNemar_Test.csv'));
fprintf('  -> 圖 4.9 ：%s\n', out_fig_file);