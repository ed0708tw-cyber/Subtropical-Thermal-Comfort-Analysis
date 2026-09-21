%% =========================================================================
%% 執行管線 05：隨機森林袋外特徵重要性 (OOB Feature Importance) 與傳熱解耦分析
%% 對應論文章節：第四章 4.5 節 (產出 表 4.15 與 圖 4.10)
%% 規範：純白底色、橫向長條圖 (barh)、字體 16 級、線寬加粗、300 DPI 印刷級匯出
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

fprintf('[管線 05] 正在載入主資料快取：%s ...\n', master_file);
load(master_file);

out_table_dir = fullfile(project_root, 'outputs', 'tables');
out_fig_dir   = fullfile(project_root, 'outputs', 'figures');
if ~exist(out_table_dir, 'dir'), mkdir(out_table_dir); end
if ~exist(out_fig_dir, 'dir'),   mkdir(out_fig_dir);   end

rng(42); % 鎖定隨機種子確保 100% 可重現

%% =========================================================================
%% 第一階段：隨機森林袋外置換特徵重要性 (OOB Permutation Importance) 計算
%% =========================================================================
fprintf('\n>>> [第一階段] 訓練隨機森林 (100 棵決策樹) 並計算 OOB 置換誤差增量...\n');

% 定義 8 維輸入特徵之標準學術名稱與熱力學傳熱分類
feat_names_raw = {
    'Ta (室內氣溫)', ...
    'RH (相對濕度)', ...
    'Vel (室內微風速)', ...
    'I_{clo} (衣著熱阻)', ...
    'Met (代謝率)', ...
    'e (實際水氣壓)', ...
    'AT_{Steadman} (戶外體感)', ...
    'AT_{mod} (亞熱帶體感)'
};

feat_categories = {
    '顯熱傳導 (Sensible Heat)', ...
    '相對潛熱 (Relative Latent)', ...
    '對流換熱 (Convective Flux)', ...
    '被動保溫阻抗 (Thermal Resistance)', ...
    '內生代謝產熱 (Internal Heat Source)', ...
    '絕對潛熱壓階 (Absolute Latent Gradient)', ...
    '歐美經驗先驗 (Outdoor Empirical Prior)', ...
    '在地化傳熱先驗 (Subtropical Physics Prior)'
};

% 訓練 100 棵決策樹之隨機森林，開啟袋外特徵置換重要性計算
rf_model = TreeBagger(100, X_train, Y_train, ...
    'Method', 'classification', ...
    'MinLeafSize', 5, ...
    'NumPredictorsToSample', 3, ...
    'OOBPredictorImportance', 'on');

% 提取 OOB 置換誤差增量 (Mean Decrease in Accuracy)
oob_delta_err = rf_model.OOBPermutedPredictorDeltaError;

% 計算相對重要性百分比 (%)
rel_importance_pct = (oob_delta_err / sum(oob_delta_err)) * 100;

% 依重要性降冪排序
[sorted_imp, sort_idx] = sort(rel_importance_pct, 'descend');
sorted_names           = feat_names_raw(sort_idx);
sorted_cats            = feat_categories(sort_idx);
sorted_delta_err       = oob_delta_err(sort_idx);

%% =========================================================================
%% 第二階段：建立並匯出 表 4.15 特徵重要性分析總表
%% =========================================================================
num_features = length(feat_names_raw);
table_importance = table('Size', [num_features, 5], ...
    'VariableTypes', {'double', 'string', 'string', 'double', 'double'}, ...
    'VariableNames', {'Feature_Rank', 'Feature_Name', 'Physical_Category', ...
                      'OOB_Delta_Error', 'Relative_Importance_Pct'});

for i = 1:num_features
    table_importance(i, :) = {i, string(sorted_names{i}), string(sorted_cats{i}), ...
                              sorted_delta_err(i), sorted_imp(i)};
end

disp('----------------------------------------------------------------------------------------');
disp('   表 4.15 亞熱帶熱環境與人體行為特徵袋外重要性 (OOB Importance) 排序總表');
disp('----------------------------------------------------------------------------------------');
disp(table_importance);
writetable(table_importance, fullfile(out_table_dir, 'Table4_15_Feature_Importance.csv'));

%% =========================================================================
%% 第三階段：繪製並匯出 圖 4.10 特徵重要性橫向長條圖 (純白底、字體 16 級、300 DPI)
%% =========================================================================
fprintf('\n>>> [第三階段] 正在繪製並匯出圖 4.10...\n');

fig = figure('Name', 'Fig4_10_Feature_Importance', ...
             'Position', [100, 100, 1050, 680], 'Color', 'w');
ax = axes('Parent', fig);
hold(ax, 'on');

set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
        'FontSize', 16, 'LineWidth', 1.3, 'FontName', 'Helvetica');
grid(ax, 'on'); box(ax, 'on');
set(ax, 'GridColor', [0.88, 0.88, 0.88], 'GridAlpha', 0.9, 'GridLineStyle', '--');

% 為確保橫向條狀圖由上而下遞減排列，將數據倒序繪製
plot_imp   = sorted_imp(end:-1:1);
plot_names = sorted_names(end:-1:1);
y_pos      = 1:num_features;

% 繪製水平長條圖
b = barh(ax, y_pos, plot_imp, 0.62, 'FaceColor', 'flat', 'LineWidth', 1.2);

% 為不同物理機制賦予層次分明的色票 (在地化先驗與關鍵環境量以深色凸顯)
for k = 1:num_features
    orig_rank = num_features - k + 1;
    if orig_rank == 1
        b.CData(k, :) = [0.18, 0.42, 0.68]; % 第 1 名：深海軍藍
    elseif orig_rank <= 3
        b.CData(k, :) = [0.28, 0.55, 0.78]; % 第 2~3 名：鋼青藍
    elseif orig_rank <= 5
        b.CData(k, :) = [0.45, 0.68, 0.85]; % 第 4~5 名：淺藍
    else
        b.CData(k, :) = [0.70, 0.75, 0.82]; % 第 6~8 名：冷灰藍
    end
end

% 在長條末端精確標註數值百分比
for k = 1:num_features
    text(ax, plot_imp(k) + 0.6, y_pos(k), sprintf('%.2f%%', plot_imp(k)), ...
        'VerticalAlignment', 'middle', 'FontSize', 15, 'FontWeight', 'bold', 'Color', 'k');
end

set(ax, 'YTick', y_pos, 'YTickLabel', plot_names);
xlabel(ax, '袋外特徵相對重要性 (OOB Relative Importance, %)', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
ylabel(ax, '熱環境與個體行為特徵變數', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
title(ax, '亞熱帶熱感覺預測模型特徵袋外重要性與傳熱機制解耦分析', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
xlim(ax, [0, max(sorted_imp) * 1.18]);
ylim(ax, [0.4, num_features + 0.6]);

% 匯出 300 DPI 印刷級圖檔
out_fig_file = fullfile(out_fig_dir, 'Fig4_10_Feature_Importance.png');
exportgraphics(fig, out_fig_file, 'Resolution', 300, 'BackgroundColor', 'w');

fprintf('[完成] 管線 05 執行完畢！\n');
fprintf('  -> 表 4.15：%s\n', fullfile(out_table_dir, 'Table4_15_Feature_Importance.csv'));
fprintf('  -> 圖 4.10：%s\n', out_fig_file);