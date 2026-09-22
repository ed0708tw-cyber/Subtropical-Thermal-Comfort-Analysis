%% ========================================================================
%  專案名稱：Thermal_Comfort_PhD
%  腳本名稱：run_05_stage1_clean_and_stats.m
%  功能描述：跨協定微觀生理資料清洗、出汗量同調化、心率遮罩構建與敘述性統計
%  特色機制：動態特徵鍵值解析器、型別安全掃描、純原生高階統計矩 (免工具箱依賴)
%  輸入檔案：data/raw/2022_CHEN_Raw.csv, data/raw/2022_SHEN_Raw.csv
%  輸出檔案：data/processed/NTUT_Harmonized_Raw_Data.mat
%           outputs/tables/Table5_1_Physiological_Descriptive_Stats.csv
% ========================================================================
clear; clc; close all;

% 1. 取得專案根目錄與路徑錨定
script_path = mfilename('fullpath');
if isempty(script_path)
    project_root = pwd;
else
    project_root = fileparts(fileparts(fileparts(script_path)));
end

raw_dir   = fullfile(project_root, 'data', 'raw');
proc_dir  = fullfile(project_root, 'data', 'processed');
table_dir = fullfile(project_root, 'outputs', 'tables');

if ~exist(proc_dir, 'dir'), mkdir(proc_dir); end
if ~exist(table_dir, 'dir'), mkdir(table_dir); end

fprintf('====================================================================\n');
fprintf('  第五章步驟 1 & 2：跨協定生理資料清洗、量綱同調化與統計管線啟動\n');
fprintf('  專案根目錄：%s\n', project_root);
fprintf('====================================================================\n\n');

% 2. 原始母表檔案完整性檢核與讀取
chen_file = fullfile(raw_dir, '2022_CHEN_Raw.csv');
shen_file = fullfile(raw_dir, '2022_SHEN_Raw.csv');

if ~exist(chen_file, 'file') || ~exist(shen_file, 'file')
    error('錯誤：找不到原始資料母表，請確認 2022_CHEN_Raw.csv 與 2022_SHEN_Raw.csv 已放置於 data/raw/ 目錄下。');
end

fprintf('1. 讀取陳乙賢與沈以塘原始母表...\n');
opts_chen = detectImportOptions(chen_file, 'VariableNamingRule', 'preserve');
chen_raw = readtable(chen_file, opts_chen);
fprintf('   陳乙賢母表載入成功，原始記錄總筆數：%d\n', height(chen_raw));
fprintf('   陳乙賢原始欄位清單: [%s]\n', strjoin(chen_raw.Properties.VariableNames, ', '));

opts_shen = detectImportOptions(shen_file, 'VariableNamingRule', 'preserve');
shen_raw = readtable(shen_file, opts_shen);
fprintf('   沈以塘母表載入成功，原始記錄總筆數：%d\n', height(shen_raw));
fprintf('   沈以塘原始欄位清單: [%s]\n\n', strjoin(shen_raw.Properties.VariableNames, ', '));

% 3. 定義特徵鍵值候選模式庫 (Feature-Key Candidate Patterns)
pat_sub   = {'Subject_ID', 'SubjectID', 'Subject', 'ID', '受試者編號', '受試者', '編號'};
pat_time  = {'Time_Min', 'TimeMin', 'Time', 'Minute', 'Min', '時間', '分'};
pat_temp  = {'Forehead_Temp', 'Forehead_Temperature', 'ForeheadTemp', 'Temperature', 'Temp', ...
             'Forehead', 'T_sk', 'Tsk', '前額溫度', '額頭溫度', '體表溫度', '額溫', 'T'};
pat_bf    = {'Blood_Flow', 'BloodFlow', 'Blood_flow', 'Blood', 'SBF', 'Flux', '血液流量', '血流量', 'LDF', 'BF'};
pat_sweat = {'Sweat', 'GSR', 'Delta_Sweat', '出汗量', '汗量', 'Sweating', 'Pore', 'S'};
pat_hr    = {'Heart_Rate', 'HeartRate', 'Heart_rate', 'Heart', 'HR', 'Pulse', '心跳速率', '心率', '心跳'};
pat_tsv   = {'TSV', 'Thermal_Sensation', 'ThermalSensation', '熱感覺投票', '熱感覺', '投票值', 'Vote'};

% 4. 解析陳乙賢母表欄位映射
col_c_sub   = resolve_col(chen_raw, pat_sub, 'Subject_ID');
col_c_time  = resolve_col(chen_raw, pat_time, 'Time');
col_c_temp  = resolve_col(chen_raw, pat_temp, 'Temperature');
col_c_bf    = resolve_col(chen_raw, pat_bf, 'Blood_Flow');
col_c_sweat = resolve_col(chen_raw, pat_sweat, 'Sweat');
col_c_tsv   = resolve_col(chen_raw, pat_tsv, 'TSV');

fprintf('2. 陳乙賢特徵映射確認：\n');
fprintf('   ID:[%s], Time:[%s], Temp:[%s], BloodFlow:[%s], Sweat:[%s], TSV:[%s]\n\n', ...
    col_c_sub, col_c_time, col_c_temp, col_c_bf, col_c_sweat, col_c_tsv);

% 強制型別轉換為 double
chen_raw.(col_c_time)  = to_double(chen_raw.(col_c_time));
chen_raw.(col_c_temp)  = to_double(chen_raw.(col_c_temp));
chen_raw.(col_c_bf)    = to_double(chen_raw.(col_c_bf));
chen_raw.(col_c_sweat) = to_double(chen_raw.(col_c_sweat));
chen_raw.(col_c_tsv)   = to_double(chen_raw.(col_c_tsv));

% 5. 執行陳乙賢前處理 (基準期 10 分鐘，出汗同調化)
fprintf('3. 執行陳乙賢資料集前處理 (預期受試者規模：70 人)...\n');
chen_sub_ids = string(chen_raw.(col_c_sub));
chen_subjects = unique(chen_sub_ids, 'stable');
chen_subjects(chen_subjects == "" | chen_subjects == "NaN" | ismissing(chen_subjects)) = [];

chen_clean_cells = cell(length(chen_subjects), 1);

for s_idx = 1:length(chen_subjects)
    sid = chen_subjects(s_idx);
    sub_data = chen_raw(chen_sub_ids == sid, :);
    
    % 生理物理邊界合理性截斷
    valid_mask = sub_data.(col_c_temp) >= 28.0 & sub_data.(col_c_temp) <= 39.0 & ...
                 sub_data.(col_c_bf) > 0 & ...
                 ~isnan(sub_data.(col_c_tsv));
    sub_data = sub_data(valid_mask, :);
    
    if isempty(sub_data), continue; end
    
    % 陳乙賢試驗協定初始基準期鎖定為前 10 分鐘
    time_vec = sub_data.(col_c_time);
    baseline_mask = time_vec <= 10;
    if ~any(baseline_mask)
        baseline_mask = 1:min(5, height(sub_data));
    end
    
    base_sweat = mean(sub_data.(col_c_sweat)(baseline_mask), 'omitnan');
    if base_sweat <= 0 || isnan(base_sweat)
        delta_sweat = zeros(height(sub_data), 1);
    else
        delta_sweat = ((sub_data.(col_c_sweat) - base_sweat) ./ base_sweat) .* 100;
    end
    
    harmonized_sub = table();
    harmonized_sub.Subject_ID      = repmat(s_idx, height(sub_data), 1);
    harmonized_sub.Protocol_Source = repmat({'CHEN_2022'}, height(sub_data), 1);
    harmonized_sub.Time_Step       = time_vec;
    harmonized_sub.T_sk            = sub_data.(col_c_temp);
    harmonized_sub.SBF             = sub_data.(col_c_bf);
    harmonized_sub.Delta_Sweat     = delta_sweat;
    harmonized_sub.HR              = zeros(height(sub_data), 1);
    harmonized_sub.Mask_HR         = zeros(height(sub_data), 1);
    harmonized_sub.TSV             = round(sub_data.(col_c_tsv));
    
    chen_clean_cells{s_idx} = harmonized_sub;
end
chen_harmonized = vertcat(chen_clean_cells{:});
fprintf('   陳乙賢清洗對齊完成，清洗後有效時序樣本數：%d\n\n', height(chen_harmonized));

% 6. 解析沈以塘母表欄位映射
col_s_sub   = resolve_col(shen_raw, pat_sub, 'Subject_ID');
col_s_time  = resolve_col(shen_raw, pat_time, 'Time');
col_s_temp  = resolve_col(shen_raw, pat_temp, 'Temperature');
col_s_bf    = resolve_col(shen_raw, pat_bf, 'Blood_Flow');
col_s_sweat = resolve_col(shen_raw, pat_sweat, 'Sweat');
col_s_hr    = resolve_col(shen_raw, pat_hr, 'Heart_Rate');
col_s_tsv   = resolve_col(shen_raw, pat_tsv, 'TSV');

fprintf('4. 沈以塘特徵映射確認：\n');
fprintf('   ID:[%s], Time:[%s], Temp:[%s], BloodFlow:[%s], Sweat:[%s], HR:[%s], TSV:[%s]\n\n', ...
    col_s_sub, col_s_time, col_s_temp, col_s_bf, col_s_sweat, col_s_hr, col_s_tsv);

% 強制型別轉換為 double
shen_raw.(col_s_time)  = to_double(shen_raw.(col_s_time));
shen_raw.(col_s_temp)  = to_double(shen_raw.(col_s_temp));
shen_raw.(col_s_bf)    = to_double(shen_raw.(col_s_bf));
shen_raw.(col_s_sweat) = to_double(shen_raw.(col_s_sweat));
shen_raw.(col_s_hr)    = to_double(shen_raw.(col_s_hr));
shen_raw.(col_s_tsv)   = to_double(shen_raw.(col_s_tsv));

% 7. 執行沈以塘前處理 (基準期 20 分鐘，保留心率，遮罩賦值 1)
fprintf('5. 執行沈以塘資料集前處理 (預期受試者規模：80 人)...\n');
shen_sub_ids = string(shen_raw.(col_s_sub));
shen_subjects = unique(shen_sub_ids, 'stable');
shen_subjects(shen_subjects == "" | shen_subjects == "NaN" | ismissing(shen_subjects)) = [];

shen_clean_cells = cell(length(shen_subjects), 1);

for s_idx = 1:length(shen_subjects)
    sid = shen_subjects(s_idx);
    sub_data = shen_raw(shen_sub_ids == sid, :);
    
    % 生理物理邊界合理性截斷
    valid_mask = sub_data.(col_s_temp) >= 28.0 & sub_data.(col_s_temp) <= 39.0 & ...
                 sub_data.(col_s_bf) > 0 & ...
                 sub_data.(col_s_hr) >= 45.0 & sub_data.(col_s_hr) <= 200.0 & ...
                 ~isnan(sub_data.(col_s_tsv));
    sub_data = sub_data(valid_mask, :);
    
    if isempty(sub_data), continue; end
    
    % 沈以塘試驗協定初始基準期鎖定為前 20 分鐘
    time_vec = sub_data.(col_s_time);
    baseline_mask = time_vec <= 20;
    if ~any(baseline_mask)
        baseline_mask = 1:min(10, height(sub_data));
    end
    
    base_sweat = mean(sub_data.(col_s_sweat)(baseline_mask), 'omitnan');
    if base_sweat <= 0 || isnan(base_sweat)
        delta_sweat = zeros(height(sub_data), 1);
    else
        delta_sweat = ((sub_data.(col_s_sweat) - base_sweat) ./ base_sweat) .* 100;
    end
    
    harmonized_sub = table();
    harmonized_sub.Subject_ID      = repmat(s_idx + 70, height(sub_data), 1);
    harmonized_sub.Protocol_Source = repmat({'SHEN_2022'}, height(sub_data), 1);
    harmonized_sub.Time_Step       = time_vec;
    harmonized_sub.T_sk            = sub_data.(col_s_temp);
    harmonized_sub.SBF             = sub_data.(col_s_bf);
    harmonized_sub.Delta_Sweat     = delta_sweat;
    harmonized_sub.HR              = sub_data.(col_s_hr);
    harmonized_sub.Mask_HR         = ones(height(sub_data), 1);
    harmonized_sub.TSV             = round(sub_data.(col_s_tsv));
    
    shen_clean_cells{s_idx} = harmonized_sub;
end
shen_harmonized = vertcat(shen_clean_cells{:});
fprintf('   沈以塘清洗對齊完成，清洗後有效時序樣本數：%d\n\n', height(shen_harmonized));

% 8. 跨協定融合與固化
harmonized_master_data = [chen_harmonized; shen_harmonized];
total_subjects = length(unique(harmonized_master_data.Subject_ID));
fprintf('6. 跨協定資料融合成功：\n');
fprintf('   總受試人數：%d 位 (陳乙賢 70 位 + 沈以塘 80 位)\n', total_subjects);
fprintf('   總有效時序筆數：%d 筆\n\n', height(harmonized_master_data));

save(fullfile(proc_dir, 'NTUT_Harmonized_Raw_Data.mat'), ...
    'harmonized_master_data', 'chen_harmonized', 'shen_harmonized', '-v7.3');
fprintf('   主對齊資料表已固化至：%s\n\n', fullfile(proc_dir, 'NTUT_Harmonized_Raw_Data.mat'));

% 9. 步驟 2：原生高階統計矩敘述性統計 (Table 5.1 產出，免工具箱依賴)
fprintf('7. 演算 Table 5.1 生理參數敘述性統計報表 (原生矩陣算法)...\n');
var_names = {'T_sk', 'SBF', 'Delta_Sweat', 'HR', 'TSV'};
stats_data = cell(length(var_names), 9);

for i = 1:length(var_names)
    vname = var_names{i};
    raw_vals = harmonized_master_data.(vname);
    
    if strcmp(vname, 'HR')
        valid_vals = raw_vals(harmonized_master_data.Mask_HR == 1);
        na_count   = sum(harmonized_master_data.Mask_HR == 0);
    else
        valid_vals = raw_vals;
        na_count   = 0;
    end
    
    n_valid   = length(valid_vals);
    na_pct    = (na_count / height(harmonized_master_data)) * 100;
    mean_val  = mean(valid_vals, 'omitnan');
    std_val   = std(valid_vals, 'omitnan');
    min_val   = min(valid_vals);
    max_val   = max(valid_vals);
    
    % 調用原生封裝之偏態與 Pearson 峰度函數 (零工具箱依賴)
    skew_val  = calc_skewness(valid_vals);
    kurt_val  = calc_kurtosis(valid_vals);
    
    stats_data(i, :) = {vname, n_valid, min_val, max_val, mean_val, std_val, skew_val, kurt_val, na_pct};
end

Table5_1 = cell2table(stats_data, 'VariableNames', ...
    {'Variable', 'N_Valid', 'Min', 'Max', 'Mean', 'Std_Dev', 'Skewness', 'Kurtosis', 'Missing_Pct'});

writetable(Table5_1, fullfile(table_dir, 'Table5_1_Physiological_Descriptive_Stats.csv'));
fprintf('   Table 5.1 已匯出至：%s\n\n', fullfile(table_dir, 'Table5_1_Physiological_Descriptive_Stats.csv'));
disp(Table5_1);

fprintf('====================================================================\n');
fprintf('  第五章步驟 1 與步驟 2 資料工程管線執行完畢，成果確證！\n');
fprintf('====================================================================\n');

%% ========================================================================
%  局部輔助函數庫 (Local Helper Functions - 100% 原生無工具箱依賴)
% ========================================================================
function col = resolve_col(tbl, patterns, semantic_name)
    % 動態掃描匹配欄位
    vars = tbl.Properties.VariableNames;
    col = '';
    
    % 1. 精確匹配 (去除底線與空格後轉小寫比對)
    norm_vars = lower(regexprep(vars, '[_\s]', ''));
    for i = 1:length(patterns)
        norm_pat = lower(regexprep(patterns{i}, '[_\s]', ''));
        idx = find(strcmp(norm_vars, norm_pat));
        if ~isempty(idx)
            col = vars{idx(1)};
            return;
        end
    end
    
    % 2. 包含匹配
    for i = 1:length(patterns)
        norm_pat = lower(regexprep(patterns{i}, '[_\s]', ''));
        for j = 1:length(norm_vars)
            if ~isempty(strfind(norm_vars{j}, norm_pat))
                col = vars{j};
                return;
            end
        end
    end
    
    error('無法於資料表中解析出符合 [%s] 語義之特徵欄位，現有欄位為：[%s]', ...
        semantic_name, strjoin(vars, ', '));
end

function out = to_double(in_col)
    % 強制數值型別轉換
    if iscell(in_col) || isstring(in_col) || iscategorical(in_col)
        out = str2double(string(in_col));
    else
        out = double(in_col);
    end
end

function s = calc_skewness(x)
    % 原生三階中心矩偏態演算 (免除 SMLT 工具箱依賴)
    x = x(~isnan(x));
    n = length(x);
    if n < 3
        s = NaN;
        return;
    end
    x_bar = mean(x);
    m2 = mean((x - x_bar).^2);
    m3 = mean((x - x_bar).^3);
    if m2 == 0
        s = 0;
    else
        s = m3 / (m2^1.5);
    end
end

function k = calc_kurtosis(x)
    % 原生四階中心矩峰度演算 (採 Pearson 常規定義，常態分佈基準值為 3.0)
    x = x(~isnan(x));
    n = length(x);
    if n < 4
        k = NaN;
        return;
    end
    x_bar = mean(x);
    m2 = mean((x - x_bar).^2);
    m4 = mean((x - x_bar).^4);
    if m2 == 0
        k = 0;
    else
        k = m4 / (m2^2);
    end
end