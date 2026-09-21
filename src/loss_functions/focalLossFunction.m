function [loss, gradients] = focalLossFunction(dlnet, dlX, Y, alpha, gamma)
% FOCALLOSSFUNCTION 多類別 alpha-Balanced 自適應聚焦損失函數 (Adaptive Focal Loss)
% 遵循最新 IEEE 與國際頂刊之標準機器學習架構，適用於 dlnetwork 搭配 dlfeval 自動微分
%
% 數學表達式：
%   Loss = - mean( sum( alpha_t .* (1 - pt).^gamma .* log(pt) ) )
%
% 輸入參數：
%   dlnet - dlnetwork 神經網路物件
%   dlX   - 輸入特徵張量 (維度: 特徵數 x 批次大小, 格式標註 'CB')
%   Y     - 真實目標 One-Hot 編碼標籤 (維度: 類別數 7 x 批次大小)
%   alpha - 類別平衡權重 (純量 1.0，或維度為 7x1 / 1x7 之類別樣本倒數頻率向量)
%   gamma - 困難樣本聚焦指數 (常規預設值設為 1.5 或 2.0)
%
% 輸出參數：
%   loss      - 當前批次之純量損失值 (可微 dlarray)
%   gradients - 損失函數對神經網路可學習參數 (Learnables) 之自動微分梯度

    % 1. 預設參數防呆賦值
    if nargin < 4 || isempty(alpha), alpha = single(1.0); end
    if nargin < 5 || isempty(gamma), gamma = single(1.5); end

    % 2. 模型前向推論傳播 (Softmax 機率向量，維度: 類別數 7 x 批次大小)
    dlYPred = forward(dlnet, dlX);
    
    % 3. 真實標籤張量化
    Y_dl = dlarray(single(Y));
    
    % 4. 提取真實目標類別之後驗預測機率 pt (維度: 1 x 批次大小)
    pt = sum(dlYPred .* Y_dl, 1);
    
    % 5. 數值下溢防護：避免 log(0) 產生非數值 (NaN) 或負無限大 (-Inf)
    eps_val = single(1e-7);
    pt = max(min(pt, 1.0 - eps_val), eps_val);
    
    % 6. 類別平衡權重 alpha 廣播對齊 (維度: 1 x 批次大小)
    if isscalar(alpha)
        alpha_t = single(alpha);
    else
        % alpha 為多類別權重向量時，沿類別維度提取各樣本真實標籤之對應權重
        alpha_dl = dlarray(single(alpha(:)));
        alpha_t = sum(alpha_dl .* Y_dl, 1);
    end
    
    % 7. 動態調制因子與聚焦損失核心運算
    modulating_factor = (1.0 - pt) .^ gamma;
    loss_batch = -alpha_t .* modulating_factor .* log(pt);
    
    % 8. 批次全域純量平均
    loss = mean(loss_batch, 'all');
    
    % 9. 計算自動微分梯度 (反向傳播)
    gradients = dlgradient(loss, dlnet.Learnables);
end