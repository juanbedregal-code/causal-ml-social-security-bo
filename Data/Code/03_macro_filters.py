"""
==============================================================================
PROYECTO: Evaluación de Impacto Reforma de Pensiones (Bolivia)
ETAPA 03: Desestacionalización del PIB y Cálculo de Brecha de Producto
AUTOR: Juan José Bedregal
DESCRIPCIÓN: 
Este script importa el PIB trimestral, aplica desestacionalización (STL) 
y calcula la brecha de producto mediante tres filtros distintos: 
Hodrick-Prescott (HP), Baxter-King (BK) y Christiano-Fitzgerald (CF).
Genera gráficos de robustez y exporta los datos para su empalme en Stata.
==============================================================================
"""

import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from statsmodels.tsa.seasonal import STL
from statsmodels.tsa.filters.hp_filter import hpfilter
from statsmodels.tsa.filters.bk_filter import bkfilter
from statsmodels.tsa.filters.cf_filter import cffilter
import warnings
warnings.filterwarnings("ignore")

# -----------------------------------------------------------------------------
# 1. CONFIGURACIÓN DE DIRECTORIOS (Rutas DIME)
# -----------------------------------------------------------------------------
DIR_RAW = os.path.join('..', 'Data', 'Raw')
DIR_INTERIM = os.path.join('..', 'Data', 'Interim')
DIR_FIG = os.path.join('..', 'Outputs', 'Figures')

os.makedirs(DIR_INTERIM, exist_ok=True)
os.makedirs(DIR_FIG, exist_ok=True)

archivo = os.path.join(DIR_RAW, "pib_ine_bo.xlsx")

# -----------------------------------------------------------------------------
# 2. CARGA Y PREPARACIÓN DE DATOS
# -----------------------------------------------------------------------------
print("[+] Cargando serie macroeconómica...")
df = pd.read_excel(archivo, sheet_name="Hoja2")
df.columns = df.columns.str.lower()

cols_num = ['gestion', 'trimestre', 'pib_real', 'pib_nominal']
for col in cols_num:
    df[col] = pd.to_numeric(df[col], errors='coerce')

# Índice temporal trimestral
df['fecha'] = pd.PeriodIndex(year=df['gestion'], quarter=df['trimestre'], freq='Q')
df = df.set_index('fecha')

# Crecimiento interanual y logaritmos
df['pib_real_crecimiento'] = ((df['pib_real'] / df['pib_real'].shift(4)) - 1) * 100
df['pib_nominal_crecimiento'] = ((df['pib_nominal'] / df['pib_nominal'].shift(4)) - 1) * 100
df['ln_pib_real'] = np.log(df['pib_real'])
df['ln_pib_nominal'] = np.log(df['pib_nominal'])

# -----------------------------------------------------------------------------
# 3. DESESTACIONALIZACIÓN (MÉTODO STL)
# -----------------------------------------------------------------------------
print("[+] Aplicando Desestacionalización STL...")
# PIB Real
stl_real = STL(df['ln_pib_real'].dropna(), period=4, robust=True).fit()
df['factor_est_real'] = stl_real.seasonal
df['ln_pib_real_sa'] = df['ln_pib_real'] - df['factor_est_real'] 

# PIB Nominal
stl_nom = STL(df['ln_pib_nominal'].dropna(), period=4, robust=True).fit()
df['factor_est_nom'] = stl_nom.seasonal
df['ln_pib_nom_sa'] = df['ln_pib_nominal'] - df['factor_est_nom'] 

# -----------------------------------------------------------------------------
# 4. CÁLCULO DE BRECHAS DE PRODUCTO (HP, BK, CF)
# -----------------------------------------------------------------------------
print("[+] Calculando Filtros de Paso de Banda (HP, BK, CF)...")

# A. Hodrick-Prescott (lambda = 7185, Rodríguez 2007)
ciclo_real, _ = hpfilter(df['ln_pib_real_sa'].dropna(), lamb=7185)
df['brecha_real'] = ciclo_real * 100 
ciclo_nom, _ = hpfilter(df['ln_pib_nom_sa'].dropna(), lamb=7185)
df['brecha_nom'] = ciclo_nom * 100 

# B. Baxter-King (Business Cycles: 4.5 a 32 trimestres, K=12)
ciclo_bk = bkfilter(df['ln_pib_real_sa'].dropna(), low=4.5, high=32, K=12)
df['brecha_bk'] = ciclo_bk * 100

# C. Christiano-Fitzgerald (Asimétrico)
ciclo_cf, _ = cffilter(df['ln_pib_real_sa'].dropna(), low=4.5, high=32, drift=True)
df['brecha_cf'] = ciclo_cf * 100

# -----------------------------------------------------------------------------
# 5. GENERACIÓN Y EXPORTACIÓN DE GRÁFICOS DE ROBUSTEZ
# -----------------------------------------------------------------------------
plt.figure(figsize=(14, 6))
fechas_graf = df.index.to_timestamp()

plt.plot(fechas_graf, df['brecha_real'], label='Hodrick-Prescott (λ=7185)', color='navy', linewidth=2)
plt.plot(fechas_graf, df['brecha_cf'], label='Christiano-Fitzgerald (Asimétrico)', color='maroon', linestyle='--', linewidth=1.5)
plt.plot(fechas_graf, df['brecha_bk'], label='Baxter-King (Simétrico, K=12)', color='darkgreen', linestyle='-.', linewidth=1.5)

plt.axhline(0, color='black', linewidth=1.2)
plt.title('Robustez de la Brecha de Producto (PIB Real): Comparativa de Filtros', fontsize=14, y=1.05)
plt.suptitle('(Confirmación de consistencia cíclica)', fontsize=10, y=.88)
plt.xlabel('Periodo (Trimestral)')
plt.ylabel('Brecha del Producto (%)')
plt.axvspan(pd.to_datetime('2020-01-01'), pd.to_datetime('2020-12-31'), color='gray', alpha=0.2, label='Shock COVID-19')
plt.legend(loc='lower center', bbox_to_anchor=(0.5, -0.2), ncol=4, frameon=True)
plt.grid(True, alpha=0.3)
plt.tight_layout()

# Exportar gráfico institucional
ruta_grafico = os.path.join(DIR_FIG, 'Grafico_Robustez_Brechas_Macro.png')
plt.savefig(ruta_grafico, dpi=300, bbox_inches='tight')
print(f"[✔] Gráfico de robustez guardado en: {ruta_grafico}")

# -----------------------------------------------------------------------------
# 6. EXPORTACIÓN DE DATASET MACRO PARA STATA
# -----------------------------------------------------------------------------
cols_export = [
    'gestion', 'trimestre', 'pib_real', 'pib_nominal', 'pib_real_crecimiento', 
    'pib_nominal_crecimiento', 'ln_pib_real_sa', 'ln_pib_nom_sa', 
    'brecha_real', 'brecha_nom', 'brecha_bk', 'brecha_cf'
]

df_export = df[cols_export].reset_index(drop=True)
ruta_csv = os.path.join(DIR_INTERIM, 'pib_brecha.csv')
df_export.to_csv(ruta_csv, index=False)
print(f"[✔] Dataset macro exportado exitosamente a: {ruta_csv}")
