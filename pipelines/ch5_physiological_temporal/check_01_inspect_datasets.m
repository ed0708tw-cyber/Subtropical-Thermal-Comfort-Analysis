%% =========================================================================
%% 診斷腳本：check_01_inspect_datasets.m
%% 功能：讀取陳乙賢與沈以塘母表 CSV，印出欄位名稱與前 3 筆樣本，驗證特徵對齊
%% =========================================================================

clear; clc;

% 1. 定位專案根目錄與資料路徑
script_dir   = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end
project_root = fullfile(script_dir, '..', '..');

raw_dir = fullfile(project_root, 'data', 'raw');
if ~exist(raw_dir, 'dir'), raw_dir = pwd; end

% 檔案候選路徑
chen_file = fullfile(raw_dir, '陳乙賢_AI訓練用數據_ALL_Attention_LSTM_Dataset_的副本.csv');
shen_file = fullfile(raw_dir, '沈以塘_動態無刺激數據_Attention_LSTM_Dataset.csv');

% 若檔名有別名則自動適應
if ~exist(chen_file, 'file') && exist(fullfile(raw_dir, '2022_CHEN_Raw.csv'), 'file')
    chen_file = fullfile(raw_dir, '2022_CHEN_Raw.csv');
end
if ~exist(shen_file, 'file') && exist(fullfile(raw_dir, '2022_SHEN_Raw.csv'), 'file')
    shen_file = fullfile(raw_dir, '2022_SHEN_Raw.csv');
end

fprintf('========================================================================================\n');
fprintf(' [資料診斷工程] 啟動臺北科技大學跨研究資料庫 (陳乙賢 vs. 沈以塘) 欄位與樣本檢核\n');
fprintf('========================================================================================\n\n');

% -------------------------------------------------------------------------
% 2. 檢視陳乙賢資料集 (2022_CHEN)
% -------------------------------------------------------------------------
if exist(chen_file, 'file')
    fprintf('>>> 正在讀取陳乙賢資料集：%s ...\n', chen_file);
    opts_chen = detectImportOptions(chen_file, 'VariableNamingRule', 'preserve');
    tbl_chen = readtable(chen_file, opts_chen);

    fprintf('  [1] 資料規模：總筆數 = %d 筆，總欄位數 = %d 個\n', height(tbl_chen), width(tbl_chen));
    fprintf('  [2] 原始欄位清單：\n      ');
    disp(tbl_chen.Properties.VariableNames);

    fprintf('  [3] 前 3 筆資料樣本視圖：\n');
    disp(tbl_chen(1:min(3, height(tbl_chen)), :));
else
    warning('找不到陳乙賢資料檔，請確認路徑：%s', chen_file);
end

fprintf('----------------------------------------------------------------------------------------\n\n');

% -------------------------------------------------------------------------
% 3. 檢視沈以塘資料集 (2022_SHEN)
% -------------------------------------------------------------------------
if exist(shen_file, 'file')
    fprintf('>>> 正在讀取沈以塘資料集：%s ...\n', shen_file);
    opts_shen = detectImportOptions(shen_file, 'VariableNamingRule', 'preserve');
    tbl_shen = readtable(shen_file, opts_shen);

    fprintf('  [1] 資料規模：總筆數 = %d 筆，總欄位數 = %d 個\n', height(tbl_shen), width(tbl_shen));
    fprintf('  [2] 原始欄位清單：\n      ');
    disp(tbl_shen.Properties.VariableNames);

    fprintf('  [3] 前 3 筆資料樣本視圖：\n');
    disp(tbl_shen(1:min(3, height(tbl_shen)), :));
else
    warning('找不到沈以塘資料檔，請確認路徑：%s', shen_file);
end

fprintf('========================================================================================\n');
fprintf(' [檢驗結論] 若兩者之 Forehead_Temp, Blood_Flux, GSR_Max, TSV 欄位皆正常存在，\n');
fprintf('            且 Time_Step 為連續分鐘增量，則資料結構已符合第五章管線對齊標準！\n');
fprintf('========================================================================================\n');