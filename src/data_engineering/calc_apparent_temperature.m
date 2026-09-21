function [AT_steadman, AT_mod] = calc_apparent_temperature(Ta_degC, e_hPa, Vel_mps)
% CALC_APPARENT_TEMPERATURE 計算傳統 Steadman 與當代副熱帶修正型體感溫度 (°C)

% 1. Steadman (1984) 通用體感溫度
AT_steadman = Ta_degC + 0.33 .* e_hPa - 0.70 .* Vel_mps - 4.00;

% 2. 當代副熱帶室內微氣候修正型體感溫度
AT_mod = Ta_degC + 0.18 .* e_hPa - 1.25 .* Vel_mps - 2.10;
end