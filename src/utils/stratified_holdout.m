function [train_idx, val_idx] = stratified_holdout(labels, train_ratio, seed)
% STRATIFIED_HOLDOUT 純原生分層留出法抽樣演算法 (Zero-Toolbox Dependency)
% 功能：依據類別標籤進行等比例分層切分，嚴格防止資料外洩
% 輸入：
%   labels      : 標籤向量 (N x 1，可為數值、字元或字串)
%   train_ratio : 訓練集比例 (例如 0.8)
%   seed        : 隨機種子 (確保實驗確定性可重現)
% 輸出：
%   train_idx   : 訓練集樣本之邏輯索引或列索引
%   val_idx     : 驗證集樣本之邏輯索引或列索引

if nargin >= 3 && ~isempty(seed)
    rng(seed);
end

if iscell(labels) || isstring(labels)
    unique_classes = unique(labels);
else
    unique_classes = unique(labels(~isnan(labels)));
end

n_samples = length(labels);
is_train = false(n_samples, 1);

for c = 1:length(unique_classes)
    cls = unique_classes(c);
    if iscell(labels) || isstring(labels)
        cls_indices = find(strcmp(labels, cls));
    else
        cls_indices = find(labels == cls);
    end

    n_cls = length(cls_indices);
    n_train_cls = round(n_cls * train_ratio);

    % 原生隨機排列
    shuffled_cls_idx = cls_indices(randperm(n_cls));
    train_chosen = shuffled_cls_idx(1:n_train_cls);

    is_train(train_chosen) = true;
end

train_idx = find(is_train);
val_idx = find(~is_train);

end