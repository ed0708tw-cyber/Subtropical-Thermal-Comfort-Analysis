function metrics_struct = calc_confusion_metrics(y_true_num, y_pred_cont, classes_scale)
% CALC_CONFUSION_METRICS 同步計算連續距離誤差與 7 階離散混淆矩陣評估指標
%
% 輸入參數：
%   y_true_num    - 真實熱感覺投票數值向量 (-3 到 +3)
%   y_pred_cont   - 模型預測之連續輸出數值向量
%   classes_scale - 評估尺度標籤陣列 (預設: -3:3)
%
% 輸出參數：
%   metrics_struct - 包含 RMSE, Accuracy, Recall, Precision, Macro-F1 之結構體

if nargin < 3 || isempty(classes_scale)
    classes_scale = -3:3;
end

y_t = double(y_true_num(:));
y_c = double(y_pred_cont(:));

% 1. 連續距離誤差指標計算
rmse_val = sqrt(mean((y_t - y_c).^2));
mse_val  = mean((y_t - y_c).^2);
mae_val  = mean(abs(y_t - y_c));

% 2. 離散化映射至標準 7 階整數尺度 (-3, -2, -1, 0, 1, 2, 3)
min_cls = min(classes_scale);
max_cls = max(classes_scale);
y_d = max(min(round(y_c), max_cls), min_cls);

% 3. 整體分類準確率 (Accuracy, %)
acc_pct = mean(y_d == y_t) * 100.0;

% 4. 7 階各類別召回率 (Recall) 與精確率 (Precision) 計算
num_classes = length(classes_scale);
recalls = zeros(num_classes, 1);
precisions = zeros(num_classes, 1);

for idx = 1:num_classes
    cls = classes_scale(idx);
    tp = sum(y_d == cls & y_t == cls);
    fn = sum(y_d ~= cls & y_t == cls);
    fp = sum(y_d == cls & y_t ~= cls);

    % 防呆：避免分母為 0 產生 NaN
    if (tp + fn) > 0
        recalls(idx) = tp / (tp + fn);
    else
        recalls(idx) = 0.0;
    end

    if (tp + fp) > 0
        precisions(idx) = tp / (tp + fp);
    else
        precisions(idx) = 0.0;
    end
end

% 5. 提取極端不適召回率 (TSV = -3 為第 1 類, TSV = +3 為第 7 類)
rec_neg3_pct = recalls(1) * 100.0;
rec_pos3_pct = recalls(end) * 100.0;

% 6. 計算巨觀指標 (Macro-Precision, Macro-Recall, Macro-F1)
macro_precision = mean(precisions);
macro_recall    = mean(recalls);

if (macro_precision + macro_recall) > 0
    macro_f1 = 2.0 * (macro_precision * macro_recall) / (macro_precision + macro_recall);
else
    macro_f1 = 0.0;
end

% 7. 打包輸出結構體
metrics_struct = struct(...
    'RMSE', rmse_val, ...
    'MSE', mse_val, ...
    'MAE', mae_val, ...
    'Accuracy_Pct', acc_pct, ...
    'Recall_Neg3_Pct', rec_neg3_pct, ...
    'Recall_Pos3_Pct', rec_pos3_pct, ...
    'Macro_Precision', macro_precision, ...
    'Macro_Recall', macro_recall, ...
    'Macro_F1', macro_f1, ...
    'Class_Recalls', recalls, ...
    'Class_Precisions', precisions);
end