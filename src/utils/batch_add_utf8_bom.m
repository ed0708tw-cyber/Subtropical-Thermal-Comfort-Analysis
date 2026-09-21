%% =========================================================================
%% 工具腳本：batch_add_utf8_bom.m
%% 功能：批次為指定目錄下所有 CSV 檔案注入 UTF-8 BOM 識別碼 (0xEF, 0xBB, 0xBF)
%% 特點：基於底層二進位位元組串流 (uint8)，絕不轉譯文字，杜絕 Big5 二度污染
%% =========================================================================

clear; clc;

% 1. 定位目標資料夾路徑 (預設為專案 raw 資料夾，亦可指定本機資料夾)
script_dir   = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end
project_root = fullfile(script_dir, '..', '..');

target_dir = fullfile(project_root, 'data', 'raw');

% 若標準路徑不存在，則自動搜尋當前工作目錄
if ~exist(target_dir, 'dir')
    target_dir = pwd;
end

fprintf('=========================================================================\n');
fprintf(' [資料工程工具] 啟動 CSV 檔案 UTF-8 BOM 批次安全注入程序\n');
fprintf(' 目標掃描目錄：%s\n', target_dir);
fprintf('=========================================================================\n');

% 2. 檢索目標目錄下所有 CSV 檔案
csv_files = dir(fullfile(target_dir, '*.csv'));

if isempty(csv_files)
    fprintf('提示：在目錄中未發現任何 CSV 檔案，請確認檔案存放位置。\n');
    return;
end

% 標準 UTF-8 BOM 之 3 位元組簽章 (十六進位 EF BB BF)
utf8_bom = uint8([239; 187; 191]);

processed_count = 0;
skipped_count   = 0;
failed_count    = 0;

for k = 1:length(csv_files)
    file_name = csv_files(k).name;
    file_path = fullfile(target_dir, file_name);

    % 忽略備份檔
    if endsWith(file_name, '.bak.csv') || endsWith(file_name, '_backup.csv')
        continue;
    end

    % 以二進位唯讀模式開啟檔案
    fid_in = fopen(file_path, 'rb');
    if fid_in == -1
        warning('無法開啟檔案 (可能正被 Excel 開啟鎖定中)：%s', file_name);
        failed_count = failed_count + 1;
        continue;
    end

    % 讀取全部原始位元組
    raw_bytes = fread(fid_in, '*uint8');
    fclose(fid_in);

    % 檢查前 3 位元組是否已包含 BOM
    if length(raw_bytes) >= 3 && isequal(raw_bytes(1:3), utf8_bom)
        fprintf('  [-] 跳過：%s (已具備 UTF-8 BOM 識別碼)\n', file_name);
        skipped_count = skipped_count + 1;
        continue;
    end

    % 建立安全備份檔案 (.bak)
    backup_path = [file_path, '.bak'];
    if ~exist(backup_path, 'file')
        copyfile(file_path, backup_path);
    end

    % 將 BOM 注入開頭，拼接原始位元組
    new_bytes = [utf8_bom; raw_bytes];

    % 以二進位寫入模式寫回檔案
    fid_out = fopen(file_path, 'wb');
    if fid_out == -1
        warning('寫入失敗！請確認檔案未被其他軟體開啟：%s', file_name);
        failed_count = failed_count + 1;
        continue;
    end

    fwrite(fid_out, new_bytes, 'uint8');
    fclose(fid_out);

    fprintf('  [+] 成功注入 BOM：%s (已備份為 .bak)\n', file_name);
    processed_count = processed_count + 1;
end

fprintf('=========================================================================\n');
fprintf(' 處理完畢統計：\n');
fprintf('   - 成功轉換筆數：%d 檔\n', processed_count);
fprintf('   - 原生具備跳過：%d 檔\n', skipped_count);
fprintf('   - 存取被拒失敗：%d 檔 (若有失敗，請關閉 Excel 後重試)\n', failed_count);
fprintf('=========================================================================\n\n');