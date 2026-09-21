%% =========================================================================
%% 繪圖腳本：plot_fig4_6_cross_decadal_drift.m
%% 功能：繪製圖 4.6 亞熱帶氣候區跨世代熱期望漂移趨勢與熱敏感度演變圖
%% 對應論文章節：第四章 4.2.6 節 (符合 IEEE 頂刊排版標準：字體 16、強制純白底)
%% =========================================================================

clear; clc; close all;

% 1. 動態錨定專案根目錄與輸出路徑
script_dir   = fileparts(mfilename('fullpath'));
project_root = fullfile(script_dir, '..', '..');
out_fig_dir  = fullfile(project_root, 'outputs', 'figures');

if ~exist(out_fig_dir, 'dir')
    mkdir(out_fig_dir);
end

% 2. 建立畫布 (強制全圖純白底色，尺寸加寬至 1200x560 確保 16 級字體排版通透)
fig = figure('Name', 'Fig4_6_Cross_Decadal_Drift', ...
             'Position', [80, 80, 1200, 560], 'Color', 'w');

% -------------------------------------------------------------------------
% 子圖 (a): Shift in Thermal Expectation Trends (TSV 幾何迴歸線與 95% CI)
% -------------------------------------------------------------------------
ax1 = subplot(1, 2, 1);
hold(ax1, 'on'); 

% 強制設定子圖 (a) 繪圖區為純白底、純黑軸線與深灰格線
set(ax1, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
         'FontSize', 16, 'LineWidth', 1.2, 'FontName', 'Helvetica');
grid(ax1, 'on'); box(ax1, 'on');
set(ax1, 'GridColor', [0.85, 0.85, 0.85], 'GridAlpha', 0.9, 'GridLineStyle', '--');

% 定義溫度繪圖區間 (15 到 35 °C)
x_temp = linspace(15, 35, 200);

% 各年代迴歸參數 (依據表 4.8 實測數據)
% 1983-1999: TSV = 0.2110 * Ta - 4.9199
y_80 = 0.2110 * x_temp - 4.9199;
ci_80 = 1.96 * 0.055; % 95% CI 頻帶半寬

% 2000-2009: TSV = 0.1683 * Ta - 3.9706
y_00 = 0.1683 * x_temp - 3.9706;
ci_00 = 1.96 * 0.025;

% 2010-2020: TSV = 0.1253 * Ta - 3.0133
y_10 = 0.1253 * x_temp - 3.0133;
ci_10 = 1.96 * 0.020;

% (A) 繪製 95% CI 陰影區
fill(ax1, [x_temp, fliplr(x_temp)], [y_80 + ci_80, fliplr(y_80 - ci_80)], ...
    [0.20, 0.50, 0.75], 'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill(ax1, [x_temp, fliplr(x_temp)], [y_00 + ci_00, fliplr(y_00 - ci_00)], ...
    [0.85, 0.45, 0.20], 'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill(ax1, [x_temp, fliplr(x_temp)], [y_10 + ci_10, fliplr(y_10 - ci_10)], ...
    [0.25, 0.65, 0.30], 'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% (B) 繪製中性基準線 (TSV = 0)
yline(ax1, 0, '--k', 'LineWidth', 1.5, 'HandleVisibility', 'off');

% (C) 繪製三年代迴歸主線 (圖例中明確標記包含 95% 信賴區間)
p1 = plot(ax1, x_temp, y_80, '-', 'Color', [0.12, 0.42, 0.68], 'LineWidth', 3.0, ...
          'DisplayName', '1983–1999 (Line & 95% CI)');
p2 = plot(ax1, x_temp, y_00, '-', 'Color', [0.85, 0.35, 0.05], 'LineWidth', 3.0, ...
          'DisplayName', '2000–2009 (Line & 95% CI)');
p3 = plot(ax1, x_temp, y_10, '-', 'Color', [0.20, 0.60, 0.25], 'LineWidth', 3.0, ...
          'DisplayName', '2010–2020 (Line & 95% CI)');

% 座標軸與標籤設定 (字體大小 16、純黑粗體)
xlabel(ax1, 'Indoor Air Temperature (°C)', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
ylabel(ax1, 'Predicted TSV', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
title(ax1, '(a) Shift in Thermal Expectation', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
xlim(ax1, [15, 35]);
ylim(ax1, [-2.5, 2.5]);

% 圖例設定 (字體 14、純白底色、深灰邊框)
lgd1 = legend(ax1, [p1, p2, p3], 'Location', 'northwest', 'FontSize', 14, 'TextColor', 'k');
set(lgd1, 'Color', 'w', 'EdgeColor', [0.6, 0.6, 0.6], 'LineWidth', 1.0);

% -------------------------------------------------------------------------
% 子圖 (b): Evolution of Thermal Sensitivity & Neutrality (雙 Y 軸)
% -------------------------------------------------------------------------
ax2 = subplot(1, 2, 2);

decades = {'1983–1999', '2000–2009', '2010–2020'};
slopes  = [0.2110, 0.1683, 0.1253];
se_vals = [0.0105, 0.0036, 0.0029]; % 表 4.8 實測標準誤
t_neut  = [23.31, 23.60, 24.06];   % 熱中性溫度

% 左 Y 軸：熱敏感度斜率 (柱狀圖)
yyaxis(ax2, 'left');
b = bar(ax2, 1:3, slopes, 0.50, 'FaceColor', 'flat', 'LineWidth', 1.2);
b.CData(1,:) = [0.20, 0.50, 0.75]; % 藍色 (1983-1999)
b.CData(2,:) = [0.85, 0.45, 0.20]; % 橘色 (2000-2009)
b.CData(3,:) = [0.25, 0.65, 0.30]; % 綠色 (2010-2020)
hold(ax2, 'on');

% 加入標準誤誤差棒 (Error Bars)
errorbar(ax2, 1:3, slopes, se_vals, 'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 10);

ylabel(ax2, 'Thermal Sensitivity (TSV/°C)', 'FontSize', 16, 'FontWeight', 'bold');
ylim(ax2, [0, 0.28]);
ax2.YAxis(1).Color = 'k'; % 強制左軸文字為純黑

% 標註數值於柱狀圖上方 (字體 14、單位統一為 TSV/°C)
text(ax2, 1, slopes(1)+0.025, sprintf('0.211\nTSV/°C'), 'HorizontalAlignment', 'center', ...
     'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');
text(ax2, 2, slopes(2)+0.021, sprintf('0.168\nTSV/°C'), 'HorizontalAlignment', 'center', ...
     'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');
text(ax2, 3, slopes(3)+0.021, sprintf('0.125\nTSV/°C'), 'HorizontalAlignment', 'center', ...
     'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');

% 右 Y 軸：熱中性溫度 (折線圖)
yyaxis(ax2, 'right');
p_tneut = plot(ax2, 1:3, t_neut, '-o', 'Color', [0.2, 0.2, 0.2], 'LineWidth', 2.6, ...
    'MarkerSize', 8, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0.1, 0.1, 0.1]);
ylabel(ax2, 'Neutral Temperature (°C)', 'FontSize', 16, 'FontWeight', 'bold');
ylim(ax2, [22.5, 25.0]);
ax2.YAxis(2).Color = 'k'; % 強制右軸文字為純黑

% 格式化子圖 (b) 軸線與刻度 (防止文字黏連)
set(ax2, 'Color', 'w', 'XColor', 'k', 'FontSize', 16, 'LineWidth', 1.2, 'FontName', 'Helvetica');
set(ax2, 'XTick', 1:3, 'XTickLabel', decades);
title(ax2, '(b) Sensitivity & Neutrality Evolution', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
grid(ax2, 'on'); box(ax2, 'on');
set(ax2, 'GridColor', [0.85, 0.85, 0.85], 'GridAlpha', 0.9, 'GridLineStyle', '--');

% -------------------------------------------------------------------------
% 匯出 300 DPI 印刷級圖檔 (強制背景純白)
% -------------------------------------------------------------------------
out_file = fullfile(out_fig_dir, 'Fig4_6_Taiwan_Subtropical_Cross_Decadal_Drift.png');
exportgraphics(fig, out_file, 'Resolution', 300, 'BackgroundColor', 'w');
fprintf('[成功] 圖 4.6 已輸出至：%s\n', out_file);