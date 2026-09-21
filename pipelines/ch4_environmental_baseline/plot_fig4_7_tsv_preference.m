%% =========================================================================
%% 繪圖腳本：plot_fig4_7_tsv_preference.m
%% 功能：繪製圖 4.7 亞熱帶氣候區熱感覺投票 (TSV) 與熱偏好 (TP) 非對稱映射堆疊圖
%% 對應論文章節：第四章 4.2.7 節 (符合 IEEE 頂刊排版標準：字體 16、強制純白底)
%% =========================================================================

clear; clc; close all;

% 1. 動態錨定專案根目錄與輸出路徑
script_dir   = fileparts(mfilename('fullpath'));
project_root = fullfile(script_dir, '..', '..');
out_fig_dir  = fullfile(project_root, 'outputs', 'figures');

if ~exist(out_fig_dir, 'dir')
    mkdir(out_fig_dir);
end

% 2. 建立畫布 (強制全圖純白底色，加寬加高確保 16 級字體排版舒適)
fig = figure('Name', 'Fig4_7_TSV_Preference_Asymmetry', ...
             'Position', [80, 80, 1150, 620], 'Color', 'w');

% 3. 準備交叉列聯數據 (7 階 TSV 對應之百分比：[Cooler, No Change, Warmer])
% 數據來源：表 4.10 實測統計 (n = 13,842)
tsv_labels = {'-3 (極冷)', '-2 (冷)', '-1 (微涼)', '0 (中性)', '+1 (微暖)', '+2 (暖)', '+3 (極熱)'};
pref_data = [
     1.6,  12.5,  85.9;  % TSV = -3
     3.2,  24.6,  72.2;  % TSV = -2
    14.8,  68.7,  16.5;  % TSV = -1 (滿意度最高峰值 68.7%)
    52.4,  44.8,   2.8;  % TSV =  0 (52.4% 隱性向冷偏好)
    88.2,  11.4,   0.4;  % TSV = +1
    96.5,   3.5,   0.0;  % TSV = +2
    98.6,   1.4,   0.0   % TSV = +3
];

% 4. 繪製 100% 水平堆疊長條圖
b = barh(1:7, pref_data, 0.62, 'stacked', 'LineWidth', 1.2);

% 設定莫蘭迪學術配色
b(1).FaceColor = [0.18, 0.45, 0.72]; % 希望更涼 (Prefer Cooler)
b(2).FaceColor = [0.60, 0.72, 0.65]; % 維持不變 (No Change)
b(3).FaceColor = [0.85, 0.38, 0.25]; % 希望更暖 (Prefer Warmer)

hold on;

% 5. 強制鎖定繪圖區為純白底色、純黑座標軸
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
         'FontSize', 16, 'LineWidth', 1.2, 'FontName', 'Helvetica');
grid on; box on;
set(gca, 'GridColor', [0.85, 0.85, 0.85], 'GridAlpha', 0.9, 'GridLineStyle', '--');

% 6. 標註內部百分比標籤 (字體 14 粗體)
for i = 1:7
    % Cooler 百分比標註
    if pref_data(i, 1) >= 8.0
        text(pref_data(i, 1)/2, i, sprintf('%.1f%%', pref_data(i, 1)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 14, 'FontWeight', 'bold', 'Color', 'w');
    end
    % No Change 百分比標註
    if pref_data(i, 2) >= 8.0
        text(pref_data(i, 1) + pref_data(i, 2)/2, i, sprintf('%.1f%%', pref_data(i, 2)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');
    end
    % Warmer 百分比標註
    if pref_data(i, 3) >= 8.0
        text(pref_data(i, 1) + pref_data(i, 2) + pref_data(i, 3)/2, i, sprintf('%.1f%%', pref_data(i, 3)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 14, 'FontWeight', 'bold', 'Color', 'w');
    end
end

% 7. 繪製關鍵分析指引線與提示文字 (字體 15 粗體)
yline(4.5, ':k', 'LineWidth', 1.5, 'HandleVisibility', 'off');
text(102, 4, '← TSV = 0 狀態下 52.4% 渴望更涼', ...
     'FontSize', 15, 'FontWeight', 'bold', 'Color', [0.18, 0.45, 0.72]);
text(102, 3, '← TSV = -1 滿意度達峰值 (68.7%)', ...
     'FontSize', 15, 'FontWeight', 'bold', 'Color', [0.20, 0.55, 0.30]);

% 8. 座標軸與標籤格式化 (字體 16 純黑粗體)
set(gca, 'YTick', 1:7, 'YTickLabel', tsv_labels);
xlabel('受測者熱偏好累積百分比 Cumulative Percentage (%)', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
ylabel('熱感覺投票尺度 (TSV Scale)', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
title('亞熱帶氣候區熱感覺與熱偏好非對稱映射特性 (n = 13,842)', 'FontSize', 18, 'FontWeight', 'bold', 'Color', 'k');
xlim([0, 100]);
ylim([0.4, 7.6]);

% 9. 設定頂部圖例 (字體 16、純白底、深灰框)
lgd = legend({'希望更涼 (Prefer Cooler)', '維持不變 (No Change)', '希望更暖 (Prefer Warmer)'}, ...
             'Location', 'northoutside', 'Orientation', 'horizontal', 'FontSize', 16, 'TextColor', 'k');
set(lgd, 'Color', 'w', 'EdgeColor', [0.6, 0.6, 0.6], 'LineWidth', 1.0);

% 10. 匯出 300 DPI 印刷級圖檔 (強制純白背景)
out_file = fullfile(out_fig_dir, 'Fig4_7_Taiwan_Subtropical_TSV_Preference_Asymmetry.png');
exportgraphics(fig, out_file, 'Resolution', 300, 'BackgroundColor', 'w');
fprintf('[完成] 圖 4.7 已成功輸出至：%s\n', out_file);