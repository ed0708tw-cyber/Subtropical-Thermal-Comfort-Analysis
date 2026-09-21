function [p_val, chi2_stat, b, c] = mcnemar_test_yates(y_true, y_pred_A, y_pred_B)
% MCNEMAR_TEST_YATES 執行帶有葉慈連續性校正 (Yates's Correction) 的配對麥克尼馬檢定
%
% 數學表達式：
%   chi2 = (|b - c| - 1)^2 / (b + c),   自由度 df = 1
%
% 輸入參數：
%   y_true    - 驗證集真實標籤向量 (N x 1)
%   y_pred_A  - 模型 A 離散預測標籤向量 (N x 1)
%   y_pred_B  - 模型 B 離散預測標籤向量 (N x 1)
%
% 輸出參數：
%   p_val     - 雙尾檢定 p 值 (P-value)
%   chi2_stat - 帶連續性校正之卡方統計量
%   b         - 模型 A 正確但模型 B 錯誤之不一致樣本數 (Discordant pair: A+/B-)
%   c         - 模型 A 錯誤但模型 B 正確之不一致樣本數 (Discordant pair: A-/B+)

y_true   = y_true(:);
y_pred_A = y_pred_A(:);
y_pred_B = y_pred_B(:);

correct_A = (y_pred_A == y_true);
correct_B = (y_pred_B == y_true);

% 提取不一致配對計數
b = sum(correct_A & ~correct_B);
c = sum(~correct_A & correct_B);

if (b + c) == 0
    chi2_stat = 0.0;
    p_val = 1.0;
else
    % 帶葉慈連續性校正之卡方統計量
    chi2_stat = (abs(b - c) - 1)^2 / (b + c);
    p_val = chi2cdf(chi2_stat, 1, 'upper');
end
end