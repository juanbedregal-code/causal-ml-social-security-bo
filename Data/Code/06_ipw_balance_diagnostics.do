/*==============================================================================
PROYECTO: Evaluación Impacto Ley 065 (Bolivia)
ETAPA 06: AUDITORÍA CAUSAL (PSM Balance, ESS y Ortogonalidad IEAC)
AUTOR: Juan José Bedregal

DESCRIPCIÓN:
Calcula el P-Score Logit, super-pesos, diagnósticos de soporte común y ECDF.
Utiliza bucles automatizados de alta eficiencia (foreach) para calcular 
las matrices de sesgo estandarizado (Love Plots), el Tamaño Efectivo 
de Muestra (Kish) y la exportación de tablas de balance a Excel.
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

* 2. Importar los resultados consolidados de Python
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
cap drop tratado
gen byte tratado = (aestudio <= 12) if !missing(aestudio)
replace tratado = 0 if (aestudio > 12) & !missing(aestudio)

cap drop post
gen byte post = (gestion >= 2011) if !missing(gestion)
gen did_interact = tratado * post

* ==============================================================================
**# 4. PROPENSITY SCORE MATCHING: LOGIT BASE Y PESOS FINALES
* ==============================================================================
rename ipw_rf_trim ipw_rf
cap drop edad_cuad
gen edad_cuad = edad^2

* Estimar Logit
qui logit tratado c.edad##c.edad i.mujer i.es_indigena i.depto i.area i.otro_aportante i.ecivil i.tipologia_hogar carga_dependencia masculinidad_hogar [pweight = peso_anual]
predict pscore_logit, pr

gen ipw_logit = .
replace ipw_logit = 1 / pscore_logit if tratado == 1 & inrange(pscore_logit, 0.05, 0.95)
replace ipw_logit = 1 / (1 - pscore_logit) if tratado == 0 & inrange(pscore_logit, 0.05, 0.95)

* Pesos Finales (Diseño * IPW)
gen double peso_final_logit = peso_anual * ipw_logit
gen double peso_final_lasso = peso_anual * ipw_lasso_trim 
gen double peso_final_rf    = peso_anual * ipw_rf

label var peso_final_logit "Peso Final DiD (Logit)"
label var peso_final_lasso "Peso Final DiD (Lasso)"
label var peso_final_rf    "Peso Final DiD (Random Forest)"

* Exportar Base Causal Final
compress
save "$clean/PANEL_EVALUACION_CAUSAL.dta", replace

* ==============================================================================
**# 5. MATRICES DE BALANCE Y LOVE PLOT (BUCLE AUTOMATIZADO)
* ==============================================================================
local vars edad edad_cuad mujer es_indigena area tamano_hogar ninos_menores_12 otro_aportante carga_dependencia tipologia_hogar masculinidad_hogar ecivil
local var_labels "Edad" "Edad^2" "Mujer" "Indígena" "Área Urbana" "Tamaño Hogar" "Niños < 12" "Otro Aportante" "Carga Dependencia" "Tipología Hogar" "Masculinidad Hogar" "Estado Civil"
local n_vars : word count `vars'

matrix B_logit = J(1, `n_vars', .)
matrix B_lasso = J(1, `n_vars', .)
matrix B_rf    = J(1, `n_vars', .)
matrix colnames B_logit = `vars'
matrix colnames B_lasso = `vars'
matrix colnames B_rf    = `vars'

local models logit lasso rf
local sheets "Logit" "Lasso" "Random_Forest"

* Bucle Maestro: Calcula Sesgo, Llena Matrices y Exporta a Excel hoja por hoja
local m = 1
foreach mod of local models {
    local sheet : word `m' of `sheets'
    putexcel set "$tabs/Anexos_PSTEST.xlsx", sheet("`sheet'") modify
    putexcel A1="Variable" B1="Media Tratados" C1="Media Controles" D1="% Bias"
    
    local i = 1
    local row = 2
    foreach v of local vars {
        local lbl : word `i' of `var_labels'
        
        * Varianza Base (Original)
        qui sum `v' [aw=peso_anual] if tratado == 1
        local v1 = r(Var)
        qui sum `v' [aw=peso_anual] if tratado == 0
        local sd_base = sqrt((`v1' + r(Var)) / 2)
        
        * Medias Ponderadas por Modelo
        qui sum `v' [aw=peso_final_`mod'] if tratado == 1
        local m1 = r(mean)
        qui sum `v' [aw=peso_final_`mod'] if tratado == 0
        local m0 = r(mean)
        
        * Sesgo Estandarizado
        local bias = 100 * (`m1' - `m0') / `sd_base'
        
        * Llenar Matriz y Excel
        matrix B_`mod'[1, `i'] = `bias'
        putexcel A`row'="`lbl'" B`row'=`m1' C`row'=`m0' D`row'=`bias'
        
        local i = `i' + 1
        local row = `row' + 1
    }
    local m = `m' + 1
}

* Gráfico Love Plot
coefplot (matrix(B_logit), msymbol(O) msize(medlarge) mcolor(gs10) label("Logit Tradicional")) ///
         (matrix(B_lasso), msymbol(T) msize(medlarge) mcolor(navy) label("Lasso / Ridge")) ///
         (matrix(B_rf), msymbol(D) msize(medlarge) mcolor(maroon) label("Random Forest")), ///
         noci title("Torneo de Pesos: Balance de Covariables", size(medlarge)) ///
         subtitle("Sesgo Estandarizado entre Tratados y Controles", size(medium)) ///
         xline(0, lpattern(solid) lcolor(black)) xline(-5 5, lpattern(dash) lcolor(red)) ///
         xtitle("Sesgo Estandarizado (%)") graphregion(color(white)) legend(position(6) rows(1))
graph export "$figs/LovePlot_Definitivo.png", replace width(2000)

* ==============================================================================
**# 6. TAMAÑO EFECTIVO DE MUESTRA (ESS - KISH) (BUCLE AUTOMATIZADO)
* ==============================================================================
matrix ESS = J(3, 3, .)
matrix rownames ESS = "Logit" "Lasso" "RF"
matrix colnames ESS = "Tratado" "Control" "Total"

local i = 1
foreach mod of local models {
    * Tratados
    qui sum peso_final_`mod' if tratado == 1
    local sum_w = r(sum)
    qui gen double w2 = peso_final_`mod'^2 if tratado == 1
    qui sum w2
    matrix ESS[`i', 1] = (`sum_w'^2) / r(sum)
    drop w2
    
    * Controles
    qui sum peso_final_`mod' if tratado == 0
    local sum_w = r(sum)
    qui gen double w2 = peso_final_`mod'^2 if tratado == 0
    qui sum w2
    matrix ESS[`i', 2] = (`sum_w'^2) / r(sum)
    drop w2
    
    * Total
    qui sum peso_final_`mod'
    local sum_w = r(sum)
    qui gen double w2 = peso_final_`mod'^2
    qui sum w2
    matrix ESS[`i', 3] = (`sum_w'^2) / r(sum)
    drop w2
    
    local i = `i' + 1
}

putexcel set "$tabs/Anexos_PSTEST.xlsx", sheet("Resumen_ESS") modify
putexcel A1 = "Modelo" B1 = "ESS Tratado" C1 = "ESS Control" D1 = "ESS Total"
putexcel A2 = matrix(ESS), rownames

matrix ESS_Total = ESS[1..3, 3]' 
matrix colnames ESS_Total = "Logit Tradicional" "Lasso / Ridge" "Random Forest"

coefplot (matrix(ESS_Total)), vertical recast(bar) barwidth(0.5) fcolor(navy) lcolor(black) ///
    title("Tamaño Efectivo de Muestra (ESS de Kish)", size(medlarge)) ///
    ytitle("Observaciones Efectivas Poblacionales") yscale(range(0)) ///
    ylabel(0(50000)200000, format(%12.0fc)) mlabel(@b) mlabposition(12) mlabsize(vsmall) format(%12.0fc) ///
    graphregion(color(white)) noci
graph export "$figs/Comparativa_ESS_Final.png", replace width(2000)

* ==============================================================================
**# 7. GRÁFICOS ADICIONALES (ECDF, SOPORTE LOGIT Y ORTOGONALIDAD IEAC)
* ==============================================================================
* Ordenamos la base por edad para que el comando cumul trace curvas perfectas
sort edad 

* --- 1. LOGIT TRADICIONAL ---
cap drop c_t_logit c_c_logit
qui cumul edad if tratado == 1 [aw=peso_final_logit], gen(c_t_logit)
qui cumul edad if tratado == 0 [aw=peso_final_logit], gen(c_c_logit)

twoway (line c_t_logit edad if tratado == 1, sort lcolor(red) lwidth(medium)) ///
       (line c_c_logit edad if tratado == 0, sort lcolor(blue) lpattern(dash) lwidth(medium)), ///
       title("A. Logit Tradicional", size(medium)) ///
       xtitle("Edad") ytitle("Probabilidad Acumulada") legend(off) name(g_logit, replace) ///
       graphregion(color(white))

* --- 2. LASSO / RIDGE ---
cap drop c_t_lasso c_c_lasso
qui cumul edad if tratado == 1 [aw=peso_final_lasso], gen(c_t_lasso)
qui cumul edad if tratado == 0 [aw=peso_final_lasso], gen(c_c_lasso)

twoway (line c_t_lasso edad if tratado == 1, sort lcolor(red) lwidth(medium)) ///
       (line c_c_lasso edad if tratado == 0, sort lcolor(blue) lpattern(dash) lwidth(medium)), ///
       title("B. Lasso / Ridge", size(medium)) ///
       xtitle("Edad") ytitle("Probabilidad Acumulada") legend(off) name(g_lasso, replace) ///
       graphregion(color(white))

* --- 3. RANDOM FOREST CALIBRADO ---
cap drop c_t_rf c_c_rf
qui cumul edad if tratado == 1 [aw=peso_final_rf], gen(c_t_rf)
qui cumul edad if tratado == 0 [aw=peso_final_rf], gen(c_c_rf)

twoway (line c_t_rf edad if tratado == 1, sort lcolor(red) lwidth(medium)) ///
       (line c_c_rf edad if tratado == 0, sort lcolor(blue) lpattern(dash) lwidth(medium)), ///
       title("C. Random Forest", size(medium)) ///
       xtitle("Edad") ytitle("Probabilidad Acumulada") legend(off) name(g_rf, replace) ///
       graphregion(color(white))

* --- 4. COMBINACIÓN DE LOS TRES PANELES ECDF ---
graph combine g_logit g_lasso g_rf, ///
    cols(3) iscale(0.8) xcommon ycommon ///
    title("Comparativa de Balance en Distribución Acumulada de Edad", size(medlarge)) ///
    subtitle("Tratados (Línea Roja) vs Controles Ponderados (Línea Azul Discontinua)", size(small)) ///
    note("Nota: El balance estructural es perfecto cuando las líneas roja y azul se superponen.") ///
    graphregion(color(white)) name(ECDF_Combinado, replace)

graph export "$salida/ECDF_Comparativo_Edad.png", name(ECDF_Combinado) replace width(2500)

* Limpieza de variables auxiliares
drop c_t_logit c_c_logit c_t_lasso c_c_lasso c_t_rf c_c_rf

* ==============================================================================
**# FASE A: AUDITORÍA DEL INGRESO ESTRUCTURAL AJUSTADO POR CICLO (IEAC)
* ==============================================================================

* AUDITORÍA 3: EL EXAMEN DE ORTOGONALIDAD
preserve
    collapse (mean) ing_real = ingreso_laboral ///
                    ing_est = ingreso_estructural_imputado ///
                    pib_crecimiento = pib_real_crecimiento ///
             [aw=peso_anual], by(gestion)
             
    * Anclaje explícito al año 2005
    qui sum ing_real if gestion == 2005
    local base_real = r(mean)
    qui sum ing_est if gestion == 2005
    local base_est = r(mean)
    
    gen index_real = (ing_real / `base_real') * 100
    gen index_est  = (ing_est / `base_est') * 100
    
    twoway (line index_real gestion, lcolor(navy) lwidth(medthick) yaxis(1)) ///
           (line index_est gestion, lcolor(maroon) lwidth(medthick) lpattern(dash) yaxis(1)) ///
           (line pib_crecimiento gestion, lcolor(emerald) lwidth(medthick) lpattern(dot) yaxis(2)), ///
           title("Prueba de Ortogonalidad: Aislamiento del Ciclo Macro", size(medlarge)) ///
           subtitle("Ingresos (Índice 2005=100) vs. Crecimiento PIB (%)", size(medium)) ///
           ytitle("Índice de Ingresos", axis(1)) ///
           ytitle("Crecimiento PIB Real (%)", axis(2)) ///
           xtitle("Año (Gestión)") ///
           legend(order(1 "Ingreso Real Observado" 2 "Ingreso Estructural (IEAC)" 3 "Crecimiento PIB (Eje Derecho)") position(6) rows(1) size(small)) ///
           xline(2010, lcolor(red) lpattern(shortdash)) ///
           graphregion(color(white))

    graph export "$salida/Auditoria3_Ortogonalidad_Corregido.png", replace width(2500)
restore

* AUDITORÍA 4: COMPOSICIÓN DEL GRUPO SOLIDARIO (Q1)
tab es_pobre_estructural mujer, row nofreq
tab es_pobre_estructural area, row nofreq
tab es_pobre_estructural es_indigena, row nofreq

disp "=========================================================================="
disp "ETAPA 06: AUDITORÍA CAUSAL FINALIZADA EXITOSAMENTE."
disp "=========================================================================="
