%% =========================================================================
%% 執行腳本：run_02_traditional_baseline.m
%% 功能：計算 4.2.8 節 表 4.2-Baseline 傳統經驗基準模型 20% 獨立驗證集效能
%% 對應論文章節：第四章 4.2.8 節 (符合 IEEE 頂刊資料標準)
%% =========================================================================

clear; clc; close all;

% 1. 動態錨定專案根目錄
script_dir   = fileparts(mfilename('fullpath'));
project_root = fullfile(script_dir, '..', '..');

% 掛載函數庫
addpath(genpath(fullfile(project_root, 'src')));
addpath(genpath(fullfile(project_root, 'pipelines')));

master_file = fullfile(project_root, 'data', 'processed', 'Ch4_Master_Data.mat');
if ~exist(master_file, 'file')
    error('錯誤：找不到主快取檔！請先執行 run_01_eda_and_imputation.m');
end

fprintf('[管線 02] 載入主資料字典：%s ...\n', master_file);
load(master_file);

% 2. 提取 80% 訓練集特徵 (N_train = 13,596)
Ta_tr  = X_train(:, 1);  RH_tr  = X_train(:, 2);  Vel_tr = X_train(:, 3);
Clo_tr = X_train(:, 4); Met_tr = X_train(:, 5);  e_tr   = X_train(:, 6);
AT_tr  = X_train(:, 7); TSV_tr = clean_data.tsv(idx_train);

% 3. 提取 20% 獨立驗證集特徵與真值 (N_val = 3,399)
Ta_val  = X_val(:, 1);  RH_val  = X_val(:, 2);  Vel_val = X_val(:, 3);
Clo_val = X_val(:, 4); Met_val = X_val(:, 5);  e_val   = X_val(:, 6);
AT_val  = X_val(:, 7);  TSV_val = clean_data.tsv(idx_val);
Y_true_val = double(string(Y_val));

fprintf(' -> 正在 80%% 訓練集上配適 9 組傳統經驗模型...\n');

% 4. 訓練集配適 (OLS 迴歸與多項式)
lm_Ta      = fitlm(Ta_tr, TSV_tr);
p_poly2    = polyfit(Ta_tr, TSV_tr, 2);
lm_RH      = fitlm(RH_tr, TSV_tr);
lm_e       = fitlm(e_tr, TSV_tr);
lm_Vel     = fitlm(Vel_tr, TSV_tr);
lm_Clo     = fitlm(Clo_tr, TSV_tr);
lm_AT      = fitlm(AT_tr, TSV_tr);
lm_ATmod   = fitlm([Ta_tr, e_tr, Vel_tr], TSV_tr);

% 5. 20% 驗證集推論
pred_cont = struct();
pred_cont.Ta_Linear       = predict(lm_Ta, Ta_val);
pred_cont.Ta_Poly2        = polyval(p_poly2, Ta_val);
pred_cont.RH_Linear       = predict(lm_RH, RH_val);
pred_cont.e_Linear        = predict(lm_e, e_val);
pred_cont.Vel_Linear      = predict(lm_Vel, Vel_val);
pred_cont.Clo_Linear      = predict(lm_Clo, Clo_val);
pred_cont.Steadman_AT     = predict(lm_AT, AT_val);
pred_cont.ATmod_Subtrop   = predict(lm_ATmod, [Ta_val, e_val, Vel_val]);
pred_cont.ISO7730_PMV     = pmv_val;

% 6. 綜合評估指標計算 (呼叫 src/utils/calc_confusion_metrics.m)
model_names = fieldnames(pred_cont);
table_baseline = table('Size', [length(model_names), 6], ...
    'VariableTypes', {'string', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'Model_Architecture', 'Val_RMSE', 'Val_Accuracy_Pct', ...
                      'Recall_Cold_Neg3_Pct', 'Recall_Hot_Pos3_Pct', 'Macro_F1'});

for k = 1:length(model_names)
    m_name = model_names{k};
    metrics = calc_confusion_metrics(Y_true_val, pred_cont.(m_name), classes_7);
    table_baseline(k, :) = {m_name, metrics.RMSE, metrics.Accuracy_Pct, ...
                            metrics.Recall_Neg3_Pct, metrics.Recall_Pos3_Pct, metrics.Macro_F1};
end

% 7. 螢幕報表輸出
disp('========================================================================================');
disp('   表 4.2-Baseline 傳統物理經驗基準模型 20% 獨立驗證集 (N_val = 3,399) 效能報表');
disp('========================================================================================');
disp(table_baseline);

% 8. 匯出 CSV 報表
out_table_dir = fullfile(project_root, 'outputs', 'tables');
if ~exist(out_table_dir, 'dir'), mkdir(out_table_dir); end
out_csv = fullfile(out_table_dir, 'Table4_2_Baseline_Performance.csv');
writetable(table_baseline, out_csv);
fprintf('[成功] 表 4.2-Baseline 效能表已成功匯出至：%s\n', out_csv);