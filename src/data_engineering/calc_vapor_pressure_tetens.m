function e_hPa = calc_vapor_pressure_tetens(Ta_degC, RH_pct)
% CALC_VAPOR_PRESSURE_TETENS 依據 Tetens 經驗公式計算實際蒸發水氣壓 (hPa)
% Ta_degC : 空氣乾球溫度 (°C)
% RH_pct  : 空氣相對濕度 (0 ~ 100 %)

% 1. 計算飽和水氣壓 e_sat (hPa)
e_sat_hPa = 6.1078 .* exp((17.27 .* Ta_degC) ./ (Ta_degC + 237.3));

% 2. 計算實際蒸發水氣壓 e (hPa)
e_hPa = (RH_pct ./ 100.0) .* e_sat_hPa;
end