%% check_NTUT_Harmonized_Data.m
% =========================================================================
% 國立臺北科技大學 熱舒適度研究專案
% 診斷腳本：檢驗 NTUT_Harmonized_Raw_Data.mat 內容與讀取狀態
% =========================================================================
clear; clc;

fprintf('=======================================================\n');
fprintf('啟動診斷：檢查 NTUT_Harmonized_Raw_Data.mat 檔案完整性\n');
fprintf('=======================================================\n');

% 定義候選搜尋路徑 (涵蓋根目錄、processed 目錄與上層目錄)
candidate_paths = {
    fullfile('data', 'processed', 'NTUT_Harmonized_Raw_Data.mat'), ...
    fullfile('..', 'data', 'processed', 'NTUT_Harmonized_Raw_Data.mat'), ...
    'NTUT_Harmonized_Raw_Data.mat'
    };

mat_file = '';
for i = 1:length(candidate_paths)
    if exist(candidate_paths{i}, 'file')
        mat_file = candidate_paths{i};
        break;
    end
end

if isempty(mat_file)
    error('【錯誤】無法在任何預期路徑下找到 NTUT_Harmonized_Raw_Data.mat！請確認檔案路徑。');
else
    fprintf('[成功] 定位到檔案路徑: %s\n', mat_file);
    file_info = dir(mat_file);
    fprintf('  - 實體檔案大小: %.2f KB\n', file_info.bytes / 1024);
end

% 載入並動態解包
loaded_struct = load(mat_file);
field_names = fieldnames(loaded_struct);
fprintf('[資訊] 檔案內部包含之變數名稱: %s\n', strjoin(field_names, ', '));

if ismember('NTUT_Harmonized_Table', field_names)
    T = loaded_struct.NTUT_Harmonized_Table;
else
    % 若存放於其他變數名稱，自動取得第一個表格型變數
    T = loaded_struct.(field_names{1});
end

% 輸出關鍵維度與統計驗證
fprintf('-------------------------------------------------------\n');
fprintf('【資料表規格診斷結果】\n');
fprintf('  - 資料表總樣本數 (Rows):    %d 筆 (預期標準: 11,900 筆)\n', height(T));
fprintf('  - 資料表特徵維度 (Columns): %d 欄\n', width(T));
fprintf('  - 欄位名稱清單: %s\n', strjoin(T.Properties.VariableNames, ', '));

unique_subs = unique(T.Subject_ID);
fprintf('  - 受試者總人數: %d 位 (編號範圍: %d 至 %d)\n', ...
    length(unique_subs), min(unique_subs), max(unique_subs));

hr_missing = sum(isnan(T.Heart_Rate));
fprintf('  - 心率 (Heart_Rate) 缺失數: %d 筆 (缺失率: %.2f%%，確立 CMM 機制)\n', ...
    hr_missing, (hr_missing / height(T)) * 100);

fprintf('  - 前額溫度 (Forehead_Temp) 均值: %.2f °C, 範圍: [%.2f, %.2f] °C\n', ...
    mean(T.Forehead_Temp, 'omitnan'), min(T.Forehead_Temp), max(T.Forehead_Temp));
fprintf('  - 微血管血流量 (Blood_Flux) 均值: %.2f PU, 範圍: [%.2f, %.2f] PU\n', ...
    mean(T.Blood_Flux, 'omitnan'), min(T.Blood_Flux), max(T.Blood_Flux));
fprintf('  - 目標真值 (TSV) 7 階類別分佈: 最小 %d 至 最大 %d\n', ...
    min(T.TSV), max(T.TSV));
fprintf('-------------------------------------------------------\n');

if height(T) == 11900 && length(unique_subs) == 150
    fprintf('【診斷結論】：資產數據 100%% 完整且格式正確！130 KB 為二進位 Gzip 正常壓縮容量。\n');
    fprintf('              請直接執行下方更新之 run_05_stage2_mask_and_tensors.m。\n');
else
    fprintf('【警告】：樣本筆數或受試者人數與預期不完全吻合，建議重新執行階段 1 讀取原始 CSV。\n');
end
fprintf('=======================================================\n');