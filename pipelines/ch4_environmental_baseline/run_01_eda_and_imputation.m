%% =========================================================================
%% 執行管線 01：資料清洗、特徵工程與 80/20 分層切分 (官方工具箱標準版)
%% 對應論文章節：第四章 4.1 節
%% =========================================================================

clear; clc; close all;

% 1. 動態錨定專案根目錄 (無論在何處執行皆能自動定位)
script_dir   = fileparts(mfilename('fullpath'));
project_root = fullfile(script_dir, '..', '..');

% 掛載核心函數庫路徑
addpath(genpath(fullfile(project_root, 'src')));
addpath(genpath(fullfile(project_root, 'pipelines')));

rng(42); % 全域鎖定隨機種子，確保 80/20 分層抽樣 100% 可重現

fprintf('[管線 01] 啟動原始資料清洗與 80/20 分層切分...\n');

% 2. 定義路徑
raw_meas_file  = fullfile(project_root, 'data', 'raw', 'db_measurements_v2.1.0.csv');
raw_meta_file  = fullfile(project_root, 'data', 'raw', 'db_metadata.csv');
out_cache_file = fullfile(project_root, 'data', 'processed', 'Ch4_Master_Data.mat');

processed_dir = fullfile(project_root, 'data', 'processed');
if ~exist(processed_dir, 'dir')
    mkdir(processed_dir);
end

if ~exist(raw_meas_file, 'file') && exist(fullfile(project_root, 'data', 'raw', '2010_2019db_measurements_v2.1.0.csv'), 'file')
    raw_meas_file = fullfile(project_root, 'data', 'raw', '2010_2019db_measurements_v2.1.0.csv');
end

if ~exist(raw_meas_file, 'file') || ~exist(raw_meta_file, 'file')
    error('錯誤：找不到原始資料檔！請確認檔案已置於：%s', fullfile(project_root, 'data', 'raw'));
end

% 3. 資料讀取與內部合併 (Inner-Join)
fprintf(' -> 正在讀取與合併 ASHRAE 資料庫...\n');
measurements = readtable(raw_meas_file, 'TreatAsEmpty', {'NA', 'na', 'NaN', ''});
metadata     = readtable(raw_meta_file, 'TreatAsEmpty', {'NA', 'na', 'NaN', ''});
joined_data  = innerjoin(measurements, metadata, 'Keys', 'building_id');

% 4. 柯本氣候分類篩選：副熱帶氣候區 (Cfa / Cwa)
climate_str = lower(string(joined_data.climate));
is_subtropical = contains(climate_str, "humid subtropical") | ...
                 contains(climate_str, "cfa") | contains(climate_str, "cwa");
subtropical_data = joined_data(is_subtropical, :);

% 5. 目標標籤 (TSV) 處理：列表剔除 (Listwise Deletion)
tsv_col = find(strcmpi(subtropical_data.Properties.VariableNames, 'thermal_sensation'), 1);
subtropical_data.Properties.VariableNames{tsv_col} = 'tsv';
clean_data = subtropical_data(~isnan(subtropical_data.tsv), :);

% 6. 特徵名稱統一與中位數插補 (Median Imputation)
key_vars = {'ta', 'rh', 'vel', 'clo', 'met'};
for kv = 1:length(key_vars)
    idx = find(strcmpi(clean_data.Properties.VariableNames, key_vars{kv}), 1);
    if ~isempty(idx)
        clean_data.Properties.VariableNames{idx} = key_vars{kv};
    end
end

clean_data.rh  = fillmissing(clean_data.rh, 'constant', median(clean_data.rh, 'omitnan'));
clean_data.vel = fillmissing(clean_data.vel, 'constant', median(clean_data.vel, 'omitnan'));
clean_data.clo = fillmissing(clean_data.clo, 'constant', median(clean_data.clo, 'omitnan'));
clean_data.met = fillmissing(clean_data.met, 'constant', median(clean_data.met, 'omitnan'));

% 7. 呼叫 src 模組：計算物理衍生特徵 (Tetens 水氣壓與體感溫度)
fprintf(' -> 執行物理特徵轉換 (Tetens 水氣壓與體感溫度)...\n');
clean_data.e_hPa = calc_vapor_pressure_tetens(clean_data.ta, clean_data.rh);
[clean_data.at_steadman, clean_data.at_mod] = calc_apparent_temperature(...
    clean_data.ta, clean_data.e_hPa, clean_data.vel);

% 8. 執行嚴格 80/20 分層切割 (使用官方 cvpartition 物件)
fprintf(' -> 執行 80/20 分層資料切割 (cvpartition 分層鎖定)...\n');
X_all = clean_data{:, {'ta', 'rh', 'vel', 'clo', 'met', 'e_hPa', 'at_steadman', 'at_mod'}};
feature_names = {'T_a', 'RH', 'Vel', 'Clo', 'Met', 'e_hPa', 'AT_steadman', 'AT_mod'};

tsv_rounded = max(min(round(clean_data.tsv), 3), -3);
Y_all_cat = categorical(tsv_rounded);

% 官方分層抽樣物件
cv = cvpartition(Y_all_cat, 'HoldOut', 0.2);
idx_train = training(cv);
idx_val   = test(cv);

X_train = X_all(idx_train, :);
Y_train = Y_all_cat(idx_train);
X_val   = X_all(idx_val, :);
Y_val   = Y_all_cat(idx_val);
classes_7 = -3:3;

% 提取驗證集之 PMV 基準以供後續殘差分析
if any(strcmpi(clean_data.Properties.VariableNames, 'pmv'))
    pmv_all = clean_data.pmv;
    pmv_all(isnan(pmv_all)) = 0.303 * exp(-0.036 * (clean_data.met(isnan(pmv_all))*58.15)) .* ...
                              (clean_data.ta(isnan(pmv_all)) - 24.0);
    pmv_val = pmv_all(idx_val);
else
    pmv_val = 0.303 * exp(-0.036 * (X_val(:,5)*58.15)) .* (X_val(:,1) - 24.0);
end

% 9. 封存主資料字典 (Master Data Artifact)
save(out_cache_file, 'X_train', 'Y_train', 'X_val', 'Y_val', ...
                     'idx_train', 'idx_val', 'feature_names', 'classes_7', ...
                     'pmv_val', 'clean_data');

fprintf('[成功] 管線 01 執行完畢！核心快取已封存至：%s\n', out_cache_file);
fprintf('       有效總樣本 N = %d 筆\n', height(clean_data));
fprintf('       訓練集 N = %d 筆 | 驗證集 N = %d 筆\n', sum(idx_train), sum(idx_val));