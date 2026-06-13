"""
==============================================================================
PROYECTO: Evaluación de Impacto Reforma de Pensiones (Bolivia)
ETAPA 01: Extracción Masiva de Metadatos (Encuestas de Hogares)
AUTOR: Juan José Bedregal
DESCRIPCIÓN: 
Este script extrae, consolida y formatea los metadatos (etiquetas de variables 
y valores) de 20 años de Encuestas de Hogares (INE) y la Encuesta Continua 
de Empleo (ECE). Exporta diccionarios unificados en CSV para revisión.
==============================================================================
"""

import os
import pandas as pd
import numpy as np
import pyreadstat

# -----------------------------------------------------------------------------
# 1. CONFIGURACIÓN DE DIRECTORIOS (Estándar DIME)
# -----------------------------------------------------------------------------
# El script asume que se ejecuta desde la carpeta 'Code/'. 
# Subimos un nivel (..) para acceder a 'Data/'
DIR_RAW = os.path.join('..', 'Data', 'Raw')
DIR_INTERIM = os.path.join('..', 'Data', 'Interim')

os.makedirs(DIR_INTERIM, exist_ok=True)

# -----------------------------------------------------------------------------
# 2. PROCESAMIENTO DE ARCHIVOS ORIGINALES (.sav)
# -----------------------------------------------------------------------------
periodo_de_analisis = ['2005', '2008', '2009', '2011', '2012', '2013', '2014', '2015']
lista_df_meta = []

print("Iniciando extracción de metadatos de archivos .sav...")

for periodo in periodo_de_analisis:
    nombre_archivo = f'EH_{periodo}.sav'
    ruta_archivo = os.path.join(DIR_RAW, nombre_archivo)
    
    try:
        # Extraemos variables y etiquetas directamente
        df, meta = pyreadstat.read_sav(ruta_archivo, metadataonly=True, apply_value_formats=False)
        var_labels = meta.column_names_to_labels
        df_meta = pd.DataFrame(list(var_labels.items()), columns=['variable', 'descripcion']).reset_index(drop=True)
        
        df_meta['dtype'] = df.dtypes.astype(str).values
        
        # Mapeo de códigos y etiquetas de valor
        value_labels = getattr(meta, "variable_value_labels", {}) or {}
        df_meta['codigos_etiquetas'] = df_meta['variable'].map(
            lambda v: [{"codigo": c, "etiqueta": e} for c, e in value_labels.get(v, {}).items()]
        )
        df_meta['periodo'] = periodo
        lista_df_meta.append(df_meta)
        print(f" [+] Procesado: {periodo} ({len(df_meta)} variables)")
        
    except FileNotFoundError:
        print(f" [!] ADVERTENCIA: Archivo {nombre_archivo} no encontrado. Saltando {periodo}.")
    except Exception as e:
        print(f" [X] ERROR en {periodo}: {e}. Saltando.")

if lista_df_meta:
    df_meta_completo = pd.concat(lista_df_meta, ignore_index=True)
else:
    df_meta_completo = pd.DataFrame()

# -----------------------------------------------------------------------------
# 3. PROCESAMIENTO DE ARCHIVOS REPARADOS (.dta)
# -----------------------------------------------------------------------------
print("\nIniciando extracción de metadatos de archivos reparados (.dta)...")
periodos_reparados = ['2008', '2015']

for periodo in periodos_reparados:
    nombre_archivo = f'EH_{periodo}_limpia.dta'
    ruta_archivo = os.path.join(DIR_RAW, nombre_archivo)
    
    try:
        df, meta = pyreadstat.read_dta(ruta_archivo)
        var_labels = meta.column_names_to_labels
        df_meta = pd.DataFrame(var_labels, index=[0]).T.reset_index()
        df_meta.columns = ['variable', 'descripcion']
        df_meta['dtype'] = [str(i) for i in df.dtypes]
        
        value_labels = getattr(meta, "variable_value_labels", {}) or {}
        df_meta['codigos_etiquetas'] = df_meta['variable'].map(
            lambda v: [{"codigo": c, "etiqueta": e} for c, e in value_labels.get(v, {}).items()]
        )
        df_meta['periodo'] = periodo
        df_meta_completo = pd.concat([df_meta_completo, df_meta], ignore_index=True)
        print(f" [+] Procesado Reparado: {periodo}")
        
    except FileNotFoundError:
        print(f" [!] Archivo no encontrado: {nombre_archivo}")

# Asignación de columna de origen
df_meta_completo['archivo_origen'] = df_meta_completo['periodo'].apply(
    lambda x: f'EH_{x}_limpia.dta' if x in periodos_reparados else f'EH_{x}.sav'
)

# Exportar metadatos generales
ruta_salida_1 = os.path.join(DIR_INTERIM, 'metadata_2015.csv')
df_meta_completo.to_csv(ruta_salida_1, index=False, encoding='utf-8-sig')
print(f"\n=> Metadatos EH exportados exitosamente a: {ruta_salida_1}")

# -----------------------------------------------------------------------------
# 4. EXTRACCIÓN DE METADATOS: ENCUESTA CONTINUA DE EMPLEO (ECE)
# -----------------------------------------------------------------------------
print("\nProcesando Encuesta Continua de Empleo (ECE)...")
nombre_archivo_ece = 'ECE_4T15_3T25.dta'
ruta_ece = os.path.join(DIR_RAW, nombre_archivo_ece)

try:
    try:
        df, meta = pyreadstat.read_dta(ruta_ece, metadataonly=True, apply_value_formats=False)
    except Exception as e:
        print(f" [!] Ajustando codificación para {nombre_archivo_ece}...")
        df, meta = pyreadstat.read_dta(ruta_ece, encoding="latin1", apply_value_formats=False)
        
    var_labels = meta.column_names_to_labels
    df_meta_ece = pd.DataFrame(var_labels, index=[0]).T.reset_index()
    df_meta_ece.columns = ['variable', 'descripcion']
    df_meta_ece['dtype'] = [str(i) for i in df.dtypes]
    
    value_labels = getattr(meta, "variable_value_labels", {}) or {}
    df_meta_ece['codigos_etiquetas'] = df_meta_ece['variable'].map(
        lambda v: [{"codigo": c, "etiqueta": e} for c, e in value_labels.get(v, {}).items()]
    )
    df_meta_ece['periodo'] = '2016-2025'
    
    # Consolidación final
    df_meta_final = pd.concat([df_meta_completo, df_meta_ece], ignore_index=True)
    ruta_salida_2 = os.path.join(DIR_INTERIM, 'metadata_EH_ECE_consolidada.csv')
    df_meta_final.to_csv(ruta_salida_2, index=False, encoding='utf-8-sig')
    print(f"=> Metadatos ECE exportados exitosamente a: {ruta_salida_2}")

except FileNotFoundError:
    print(f" [X] Archivo no encontrado: {nombre_archivo_ece}")

print("\n[✔] PIPELINE DE EXTRACCIÓN DE METADATOS COMPLETADO.")
