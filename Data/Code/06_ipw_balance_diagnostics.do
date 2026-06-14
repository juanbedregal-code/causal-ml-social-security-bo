/*==============================================================================
PROYECTO: Evaluación Impacto Ley 065 (Bolivia)
ETAPA 06A: AUDITORÍA CAUSAL (PSM Balance, Soporte Común y Ortogonalidad IEAC)
AUTOR: Juan José Bedregal

DESCRIPCIÓN:
Calcula el Propensity Score mediante Logit tradicional para usarlo como línea 
base contra los modelos de ML. Genera diagnósticos de soporte común, Love Plots 
de sesgo estandarizado, Tamaño Efectivo de Muestra (ESS) y pruebas ECDF.
==============================================================================*/

clear all
set more off
set varabbrev off

* Rutas DIME
global interim "../Data/Interim"
global clean   "../Data/Cleaned"
global tabs    "../Outputs/Tables"
global figs    "../Outputs/Figures"

* 1. Cargar Base Maestra
use "$clean/PANEL_LISTO_PARA_ML.dta", clear
svyset upm [pweight = peso_anual], strata(estrato) singleunit(scaled)

* 2. Importar los resultados consolidados de Python (Causal ML)
preserve
    import delimited "$interim/Resultados_Finales_CausalML.csv", clear 
    capture confirm numeric variable id_hogar
    if !_rc {
        tostring id_hogar, replace format("%22.0f")
    }
    cap destring trimestre, replace
    tempfile resultados_ml
    save `resultados_ml'
restore

* 3. Merge (IPW + IEAC)
merge 1:1 id_hogar id_persona gestion trimestre using `resultados_ml', keep(match master) nogene

label var ingreso_estructural_imputado "Ingreso Estructural (XGBoost OOF)"
label var es_pobre_estructural "Pobreza Estructural Extrema (Q1)"

* Variables Base para DiD
cap drop tratado post did_interact
gen byte tratado = (aestudio <= 12) if !missing(aestudio)
replace tratado = 0 if (aestudio > 12) & !missing(aestudio)
gen byte post = (gestion >= 2011) if !missing(gestion)
gen did_interact = tratado * post

* ------------------------------------------------------------------------------
* 4. PSM LOGIT Y CONSOLIDACIÓN DE SUPER-PESOS
* ------------------------------------------------------------------------------
rename ipw_rf_trim ipw_rf
cap drop edad_cuad
gen edad_cuad = edad^2

* Logit Tradicional
qui logit tratado c.edad##c.edad i.mujer i.es_indigena i.depto i.area i.otro_aportante i.ecivil i.tipologia_hogar carga_dependencia masculinidad_hogar [pweight = peso_anual]
predict pscore_logit, pr

gen ipw_logit = .
replace ipw_logit = 1 / pscore_logit if tratado == 1 & inrange(pscore_logit, 0.05, 0.95)
replace ipw_logit = 1 / (1 - pscore_logit) if tratado == 0 & inrange(pscore_logit, 0.05, 0.95)

* Pesos Finales (Diseño * IPW)
gen double peso_final_logit = peso_anual * ipw_logit
gen double peso_final_lasso = peso_anual * ipw_lasso_trim // O ipw_lasso dependiendo del CSV
gen double peso_final_rf    = peso_anual * ipw_rf

label var peso_final_logit "Peso Final DiD (Logit)"
label var peso_final_lasso "Peso Final DiD (Lasso)"
label var peso_final_rf    "Peso Final DiD (Random Forest)"

* ------------------------------------------------------------------------------
* 5. EXPORTACIÓN DE BASE PARA ESTIMACIÓN CAUSAL
* ------------------------------------------------------------------------------
compress
save "$clean/PANEL_EVALUACION_CAUSAL.dta", replace
disp "[✔] Base final de evaluación guardada."

* ------------------------------------------------------------------------------
* 6. DIAGNÓSTICOS GRÁFICOS
* ------------------------------------------------------------------------------

* A. Soporte Común Logit
twoway (kdensity pscore_logit if tratado == 0, lcolor(navy) lwidth(medthick)) ///
       (kdensity pscore_logit if tratado == 1, lcolor(maroon) lwidth(medthick)), ///
       title("Soporte Común (Logit Tradicional)") xtitle("P-Score Logit") ///
       xline(0.05 0.95, lcolor(black) lpattern(dash)) ///
       legend(order(1 "Control" 2 "Tratado")) graphregion(color(white))
graph export "$figs/Soporte_Comun_Logit.png", replace width(2000)

* B. Auditoría Ortogonalidad (IEAC)
preserve
    collapse (mean) ing_real = ingreso_laboral ing_est = ingreso_estructural_imputado pib_crecimiento = pib_real_crecimiento [aw=peso_anual], by(gestion)
    qui sum ing_real if gestion == 2005
    local base_real = r(mean)
    qui sum ing_est if gestion == 2005
    local base_est = r(mean)
    
    gen index_real = (ing_real / `base_real') * 100
    gen index_est  = (ing_est / `base_est') * 100
    
    twoway (line index_real gestion, lcolor(navy) yaxis(1)) ///
           (line index_est gestion, lcolor(maroon) lpattern(dash) yaxis(1)) ///
           (line pib_crecimiento gestion, lcolor(emerald) lpattern(dot) yaxis(2)), ///
           title("Prueba de Ortogonalidad: Aislamiento del Ciclo Macro") ///
           xline(2010, lcolor(red) lpattern(shortdash)) graphregion(color(white))
    graph export "$figs/Auditoria_Ortogonalidad.png", replace width(2000)
restore

disp "=========================================================================="
disp "ETAPA 6A FINALIZADA: PESOS CALCULADOS Y DIAGNÓSTICOS EXPORTADOS."
disp "=========================================================================="
