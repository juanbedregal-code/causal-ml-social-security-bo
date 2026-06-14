# Causal Machine Learning & PSM: Pension Reform Impact Evaluation in Bolivia 🇧🇴

![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Stata](https://img.shields.io/badge/Stata-1E4D8C?style=for-the-badge&logo=stata&logoColor=white)
![Machine Learning](https://img.shields.io/badge/Machine_Learning-IPW-F7931E?style=for-the-badge)
![Causal Inference](https://img.shields.io/badge/Causal_Inference-DiD_%7C_PSM-276DC3?style=for-the-badge)

## 📌 Project Overview
This repository contains the replication package for the impact evaluation of the Pension Reform in Bolivia. The methodological approach bridges **Causal Machine Learning** and traditional Econometrics. 

Specifically, it utilizes ML algorithms (Random Forest, Lasso/Ridge) to compute highly accurate Inverse Probability Weights (IPW) and Propensity Scores, followed by a Propensity Score Matching combined with a Difference-in-Differences (PSM-DiD) estimator to evaluate the causal effect of the social security reform on socioeconomic outcomes.

## 📂 DIME-Standard Directory Structure
This project strictly follows the reproducibility standards defined by the World Bank's DIME Analytics team.

```text
causal-ml-social-security-bo/
├── Data/
│   ├── Raw/               # Encuestas originales (.sav) e IPC/PIB bruto
│   ├── Interim/           # Diccionarios de metadatos, brechas de producto (CSV), paneles pre-ML
│   └── Cleaned/           # Base final con pesos IPW lista para Triple DiD
├── Code/
│   ├── 01_metadata_extraction.py     # 🐍 Python: Extracción de encuestas y metadatos
│   ├── 02_survey_harmonization.do    # 📊 Stata: Armonización 2005-2025 y deflactación (IPC)
│   ├── 03_macro_filters.py           # 🐍 Python: Brechas de producto (HP, BK, CF filters)
│   ├── 04_data_merging_eda.do        # 📊 Stata: Merge macro-micro, limpieza y EDA
│   ├── 05_causal_ml_ipw.ipynb        # 🐍 Python (Colab): Optuna, Lasso/Ridge, RF, cálculo de IEAC e IPW
│   └── 06_psm_did_analysis.do        # 📊 Stata: Balance tests, DiD, Triple DiD (DDD), Event Studies
├── Outputs/
│   ├── Tables/            # Tablas de regresión (DiD, DDD) y Balance
│   └── Figures/           # Love plots, Trayectorias IEAC, Common Support
└── requirements.txt
```

## ⚖️ Polyglot Methodological Workflow (Python & Stata)
This project features a complex, institution-grade pipeline that seamlessly integrates macroeconomic data, microdata harmonization, and machine learning:

1. 🐍 **Data Engineering & Metadata (Python):** Ingestion of `.sav`/`.dta` Household Surveys. Automated generation and consolidation of metadata dictionaries for variable selection.
2. 📊 **Microdata Harmonization (Stata):** Harmonization of 20 years of Annual Household Surveys (2005-2015) and Quarterly Employment Surveys (2016-2025). Real wage calculation via regional CPI deflation.
3. 🐍 **Macroeconomic Filtering (Python):** Seasonal adjustment of quarterly GDP. Calculation of output gaps using Hodrick-Prescott (HP), Baxter-King (BK), and Christiano-Fitzgerald (CF) filters.
4. 📊 **Macro-Micro Integration & EDA (Stata):** Merging output gaps with individual-level microdata. Subsetting algorithms (age brackets, formal sector exclusion) and Exploratory Data Analysis.
5. 🐍 **Causal Machine Learning (Python / Colab):** Training of Lasso/Ridge and Random Forest models via Bayesian optimization (`Optuna` with 50-10,000 trials). Calculation of Inverse Probability Weights (IPW) and Structurally Adjusted Income over Cycle (IEAC) as exogenous variables.
6. 📊 **Causal Inference & Robustness (Stata):** Covariate balance testing (Love plots). Global DiD, Event Studies, and Triple Differences (DDD) exploiting age cohorts, IEAC quartiles, motherhood status, and business cycle vs. employment sectors. Execution of Placebo tests.

## 📊 Mapping of Exhibits (Results)

| Exhibit | Description | Generating Script | Output File |
|---------|-------------|-------------------|-------------|
| **Figure 1** | Propensity Score Overlap (Common Support) | `04_psm_did_estimation.do` | `Outputs/Figures/ps_overlap.png` |
| **Table 1** | Covariate Balance Test (Before/After Matching) | `04_psm_did_estimation.do` | `Outputs/Tables/balance_table.md` |
| **Table 2** | PSM-DiD Treatment Effect (ATT) | `04_psm_did_estimation.do` | `Outputs/Tables/did_results.md` |

*(Insert your main Common Support PNG graph here)*
<!-- Example: <img src="Outputs/Figures/ps_overlap.png" width="600"> -->

*(Insert your DiD Results Markdown Table here)*
<!-- Example:
| Estimator | Coefficient | Std. Error | P-Value |
|-----------|-------------|------------|---------|
| PSM-DiD   | 0.045**     | (0.012)    | 0.003   |
-->

## 💾 Data and Code Availability Statement (DCAS)
Following the Social Science Data Editors (SSDE) guidelines:
- **Raw Data:** The microdata comes from the Bolivian National Institute of Statistics (INE). Due to size constraints, raw data is not uploaded. Researchers can download the public Household Surveys, Prices Index and GDP from [INE's official portal](https://www.ine.gob.bo).
- **Execution:** To replicate the study, place the raw `.sav`/`.csv` files in `Data/Raw/` and run the scripts in sequential order (01 to 04).

## 💻 Computational Requirements
- **Hardware:** Google Colab Pro / GPU (CUDA) recommended for the Machine Learning pipeline. Standard 16GB RAM machine for Stata operations.
- **Python:** Version 3.9+ (Packages: `optuna`, `xgboost`, `scikit-learn`, `pandas`).
- **Stata:** Version 16+ (Required user-written commands: `reghdfe`, `coefplot`, `outreg2`).
- **Wall-clock time:** ~10 hours (600 minutes) due to aggressive Bayesian Optimization (Optuna) in the Causal ML pipeline (up to 10,000 trials). Stata estimation takes ~15 minutes.
---
*Created by [Juan José Bedregal](https://github.com/juanbedregal-code)*
