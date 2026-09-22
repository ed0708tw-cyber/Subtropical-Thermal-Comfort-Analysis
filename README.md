# Subtropical Thermal Comfort Analysis & Temporal Deep Learning Framework

This repository hosts the official codebase for the Ph.D. dissertation on human thermal comfort prediction in the subtropical climate zone. The framework bridges macroscopic environmental modeling (ASHRAE Global Thermal Comfort Database II) and microscopic physiological temporal representation learning (NTUT Chamber Database).

## System Environment & Architectural Highlights
- **Platform**: MATLAB R2026a (Compatible with R2022b or later).
- **Core Principle**: **Zero-Toolbox Dependency** (All statistical moments, stratified sampling, and focal loss functions are implemented using native matrix linear algebra).
- **Initialization**: Launch MATLAB and execute `startup.m` to automatically register all dependent subdirectories.

## Repository Directory Topology
```text
Thermal_Comfort_PhD/
├── startup.m                   % Auto-path mounting and project setup
├── data/                       % Data management topology
│   ├── raw/                    % Local raw CSV datasets (Ignored by Git)
│   └── processed/              % Harmonized tensors and MAT caches (Ignored by Git)
├── src/                        % Native algorithmic and mathematical kernel libraries
│   ├── data_engineering/      % Apparent temperature, Tetens vapor pressure
│   ├── loss_functions/        % Adaptive Focal Loss (AFL) functions
│   ├── metrics/               % McNemar paired test with Yates's correction
│   └── utils/                 % Native stratified holdout and metric calculators
├── pipelines/                  % End-to-end execution pipelines
│   ├── ch4_environmental_baseline/     % Chapter 4 ASHRAE environmental pipelines
│   └── ch5_physiological_temporal/     % Chapter 5 NTUT physiological temporal pipelines
└── outputs/
    ├── figures/                % 300 DPI high-resolution figures (Generated on demand)
    └── tables/                 % Standardized CSV evaluation tables (Table 4.11 - 5.1)