# Subtropical Thermal Comfort Analysis & Temporal Deep Learning Framework

本儲存庫為工程博士學位論文之核心代碼庫，專注於亞熱帶氣候區建築熱環境巨觀模型與微觀穿戴生理時序深度學習預測模型之研究。

## 專案環境與依賴需求
- 軟體平台：MATLAB R2026a (或 R2022b 以上版本)
- 設計原則：**Zero-Toolbox Dependency**（底層矩陣運算解耦商業統計工具箱）
- 初始化方式：開啟 MATLAB 後，於命令視窗執行 `startup.m` 自動掛載全部目錄。

## 目錄架構拓樸
- `data/`：數據儲存拓樸（原始數據請存放於 `data/raw/`，中繼張量生成於 `data/processed/`）。
- `src/`：底層自編核心數學庫（包含數據工程、自適應聚焦損失 AFL、麥克尼馬檢定及分層抽樣工具）。
- `pipelines/`：具執行依賴編號之高階自動化管線。
  - `ch4_environmental_baseline/`：第四章 ASHRAE 巨觀環境模型管線 (run_01 至 run_05)。
  - `ch5_physiological_temporal/`：第五章 NTUT 微觀生理時序模型管線 (run_01 與 run_02)。
- `outputs/`：成果輸出資產。
  - `figures/`：300 DPI IEEE 期刊規格圖表 (Fig 4.1 至 Fig 4.10)。
  - `tables/`：跨範式比較統計報表 (Table 4.11 至 Table 5.1)。

## 數據獲取與配置指南
鑑於版權與資料集規模，原始資料不直接包含於 Git 追蹤中：
1. **ASHRAE Global Thermal Comfort Database II (v2.1.0)**：請自官方 Dryad 倉庫下載 `db_measurements_v2.1.0.csv` 與 `db_metadata.csv` 置入 `data/raw/`。
2. **NTUT 微觀生理實驗母表**：請將 `2022_CHEN_Raw.csv`（陳乙賢受控衝擊協定）與 `2022_SHEN_Raw.csv`（沈以塘動態運動協定）置入 `data/raw/`。
