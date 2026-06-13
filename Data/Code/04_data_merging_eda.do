/*==============================================================================
PROYECTO: Evaluación de Impacto Reforma de Pensiones (Bolivia)
ETAPA 04: Integración Macro-Micro (IPC, PIB), EDA y Exportación para ML
AUTOR: Juan José Bedregal

DESCRIPCIÓN:
Este script une el IPC departamental y las brechas de producto calculadas en 
Python con el panel microeconómico. Filtra la muestra analítica (PEA Ocupada) 
y exporta las estadísticas descriptivas para la tesis, y la base limpia para ML.
==============================================================================*/

clear all
set more off
set varabbrev off

* ------------------------------------------------------------------------------
* 0. CONFIGURACIÓN DE DIRECTORIOS (Rutas Relativas Reproducibles DIME)
* ------------------------------------------------------------------------------
global raw     "../Data/Raw"
global interim "../Data/Interim"
global clean   "../Data/Cleaned"
global tabs    "../Outputs/Tables"
global figs    "../Outputs/Figures"

/*==============================================================================
  FASE 1: RETROPOLACIÓN Y EMPALME DEL IPC DEPARTAMENTAL
==============================================================================*/

preserve
    import delimited "$raw/ipc_departamental.csv", clear varnames(1)
    
    * Parche Formatos (String a Numeric)
    cap destring _all, replace dpcomma force
    cap destring _all, replace force

    * Obtener el IPC Nacional (Base retrospectiva)
    qui sum ipc_nac if gestion == 2005 & trimestre == 4
    local nac_05 = r(mean)
    qui sum ipc_nac if gestion == 2008 & trimestre == 4
    local nac_08 = r(mean)
    
    local ratio_retro = `nac_05' / `nac_08'
    
    * Retropolación para los 9 departamentos (2005-Q4)
    forvalues i = 1/9 {
        qui sum ipc_`i' if gestion == 2008 & trimestre == 4
        local dep_08 = r(mean)
        qui replace ipc_`i' = `dep_08' * `ratio_retro' if gestion == 2005 & trimestre == 4
    }
    
    reshape long ipc_, i(gestion trimestre ipc_nac) j(depto)
    rename ipc_ ipc_depto
    
    sort gestion trimestre depto
    tempfile ipc_listo
    save `ipc_listo'
restore

* Merge con microdatos y Deflactación
use "$interim/PANEL_MICRO_2005_2025.dta", clear
merge m:1 gestion trimestre depto using `ipc_listo', keep(match master) nogene

gen ingreso_laboral_real = (ingreso_laboral / ipc_depto) * 100
label var ingreso_laboral_real "Ingreso Laboral Real (Deflactado, IPC Depto)"
drop ingreso_laboral
rename ingreso_laboral_real ingreso_laboral
save "$interim/PANEL_MICRO_DEFLACTADO.dta", replace

/*==============================================================================
  FASE 2: INCORPORACIÓN DEL PIB Y CÁLCULO DE LA BRECHA DE PRODUCTO
==============================================================================*/

import delimited "$interim/pib_brecha.csv", clear stringcols(_all) 
destring _all, replace force 

gen t_q = yq(gestion, trimestre)
format t_q %tq
tsset t_q

label variable pib_real "PIB Real (Trimestral)"
label variable brecha_real "Brecha PIB Real (Hodrick-Prescott, %)"
label variable brecha_bk "Brecha PIB Real (Baxter-King, %)"
label variable brecha_cf "Brecha PIB Real (Christiano-Fitzgerald, %)"

twoway (line brecha_real t_q, lcolor(navy) lwidth(medium)) ///
       (line brecha_cf t_q, lcolor(maroon) lwidth(medium) lpattern(dash)), ///
       yline(0, lcolor(black) lpattern(solid)) ///
       title("Brecha de Producto: Hodrick-Prescott vs Christiano-Fitzgerald") ///
       xtitle("Periodo (Trimestral)") ytitle("Desviación de la tendencia (%)") ///
       legend(label(1 "Brecha PIB Real (HP)") label(2 "Brecha PIB Real (CF)") position(6) rows(1)) ///
       graphregion(color(white)) name(g_brechas_final, replace)
graph export "$figs/Stata_Brechas_Macro.png", as(png) replace

keep gestion trimestre pib_real pib_nominal pib_real_crecimiento pib_nominal_crecimiento ln_pib_real_sa ln_pib_nom_sa brecha_real brecha_nom brecha_bk brecha_cf
tempfile macro_nacional
save `macro_nacional'

/*==============================================================================
  FASE 3: EMPALME FINAL Y DELIMITACIÓN DE LA BASE PARA ML
==============================================================================*/

use "$interim/PANEL_MICRO_DEFLACTADO.dta", clear
merge m:1 gestion trimestre using `macro_nacional'
drop if _merge == 1 
drop _merge

* Filtros Base Universales
keep if edad > 24 & edad <= 65
drop if ocupacion == 0

* Dummy de Reforma (Ley 065 - Dic 2010)
capture drop reforma
gen byte reforma = (gestion > 2010)
label define lbl_ref 0 "Pre-Reforma (2005-2010)" 1 "Post-Reforma (2011-2025)", replace
label values reforma lbl_ref

gen t_q = yq(gestion, trimestre)
format t_q %tq

* Adecuación para ML
gen byte mujer_pct = mujer * 100
gen indigena_pct = es_indigena * 100
gen afp_pct = afp * 100
capture rename brecha_real brecha_hp
capture rename brecha_cf brecha_real

replace sector_economico = . if sector_economico == 89 | sector_economico == 99

compress
save "$clean/PANEL_LISTO_PARA_ML.dta", replace

/*==============================================================================
  FASE 4: ESTADÍSTICAS DESCRIPTIVAS (EXPORTACIÓN)
==============================================================================*/

* Inventario
preserve
    gen obs_total = 1
    gen obs_ocupados = (cond_actividad == 1)
    collapse (sum) obs_total obs_ocupados, by(gestion trimestre)
    gen pct_ocupados = (obs_ocupados / obs_total) * 100
    export excel "$tabs/Tablas_Iniciales.xlsx", sheet("Tabla_Inventario") sheetreplace firstrow(variables)
restore

* Tablas Descriptivas Laborales (PEA Ocupada)
keep if cond_actividad == 1
svyset upm [pweight=peso_anual], strata(estrato) singleunit(scaled)

gen byte sub_pre   = (reforma == 0)
gen byte sub_post  = (reforma == 1)
gen byte sub_total = 1

global vars_analisis afp mujer edad aestudio es_indigena madre_hogar ///
                     ninos_menores_12 tamano_hogar otro_aportante ///
                     i.ecivil i.tipologia_hogar carga_dependencia ///
                     educ_jefe masculinidad_hogar ///
                     ingreso_laboral horas_trabajadas brecha_real
					 
eststo clear
eststo pre_ref:   svy, subpop(sub_pre):   mean $vars_analisis
eststo post_ref:  svy, subpop(sub_post):  mean $vars_analisis
eststo total_ref: svy, subpop(sub_total): mean $vars_analisis

esttab pre_ref post_ref total_ref using "$tabs/Tabla_Descriptivas.rtf", replace ///
    cells("b(fmt(2)) se(fmt(2) par)") ///
    stats(N, fmt(%18.0gc) labels("N (Observaciones)")) ///
    mtitles("Pre-Reforma" "Post-Reforma" "Muestra Total") ///
    title("Estadísticas Descriptivas (PEA Ocupada 25-65 años)") ///
    label nonumber unstack noobs width(100%)

* Gráfico: Efecto Aseguramiento
preserve
    collapse (mean) afp_pct [aw=peso_anual], by(gestion otro_aportante)
    reshape wide afp_pct, i(gestion) j(otro_aportante)
    
    twoway (line afp_pct1 gestion, lcolor(forest_green) lwidth(medthick) msymbol(O)) ///
           (line afp_pct0 gestion, lcolor(sienna) lwidth(medthick) msymbol(D) lpattern(dash)), ///
        xline(2010, lcolor(black) lpattern(dash)) ///
        title("Formalidad según 'Otro Aportante' en el Hogar") ///
        legend(label(1 "Sí hay otro aportante") label(2 "No hay") rows(1)) ///
        xtitle("Año") ytitle("% de Afiliación a AFP") graphregion(color(white))
    graph export "$figs/Grafico_Otro_Aportante.png", as(png) replace
restore

disp "=========================================================================="
disp "INTEGRACIÓN MACRO-MICRO, EDA Y EXPORTACIONES COMPLETADAS."
disp "=========================================================================="
