/*==============================================================================
PROYECTO: Evaluación Impacto Ley 065 (Bolivia)
ETAPA 06B: ESTIMACIÓN CAUSAL (DiD, Triples Diferencias, Event Studies y Placebos)
AUTOR: Juan José Bedregal

DESCRIPCIÓN:
Ejecuta los modelos econométricos causales utilizando los pesos doblemente 
robustos (IPW de ML + Diseño Muestral) generados en la Etapa 6A.
Incluye controles de efectos fijos de Alta Dimensionalidad (reghdfe).
==============================================================================*/

clear all
set more off
set varabbrev off

* Rutas DIME
global clean   "../Data/Cleaned"
global tabs    "../Outputs/Tables"
global figs    "../Outputs/Figures"

* 1. Cargar Base Ponderada
use "$clean/PANEL_EVALUACION_CAUSAL.dta", clear

* Definición global de controles
global controles "c.edad##c.edad i.mujer i.es_indigena i.area c.tamano_hogar c.ninos_menores_12 i.otro_aportante i.ecivil i.tipologia_hogar carga_dependencia masculinidad_hogar"

* ==============================================================================
* NIVEL 1: IMPACTO CAUSAL GLOBAL (DiD)
* ==============================================================================
disp "Ejecutando Modelos Globales..."

eststo m_logit: reghdfe afp did_interact $controles c.gestion#1.tratado [pweight = peso_final_logit], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
outreg2 [m_logit] using "$tabs/Impacto_Global.doc", replace word keep(did_interact) ctitle("Logit") title("Impacto Global Ley 065") dec(4)

eststo m_lasso: reghdfe afp did_interact $controles c.gestion#1.tratado [pweight = peso_final_lasso], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
outreg2 [m_lasso] using "$tabs/Impacto_Global.doc", append word keep(did_interact) ctitle("Lasso") dec(4)

eststo m_rf: reghdfe afp did_interact $controles c.gestion#1.tratado [pweight = peso_final_rf], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
outreg2 [m_rf] using "$tabs/Impacto_Global.doc", append word keep(did_interact) ctitle("Random Forest") dec(4)

* ==============================================================================
* NIVEL 1B: EVENT STUDY DINÁMICO
* ==============================================================================
cap drop tendencia_tratado
gen tendencia_tratado = (gestion - 2009) * tratado

local anios_es 2005 2008 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024
cap drop ev_*
foreach a of local anios_es {
    gen ev_`a' = (gestion == `a') * tratado
}

eststo es_rf: reghdfe afp ev_* tendencia_tratado $controles [pweight = peso_final_rf], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)

coefplot (es_rf, msymbol(D) mcolor(maroon) ciopts(lcolor(maroon)) label("Random Forest")), ///
         vertical keep(ev_*) rename(ev_([0-9]+) = "\1", regex) /// 
         yline(0, lcolor(black) lpattern(solid)) xline(2.5, lcolor(red) lpattern(dash) lwidth(medthick)) ///
         title("Impacto Dinámico de la Ley 065 (Event Study)") xtitle("Año") graphregion(color(white))
graph export "$figs/EventStudy_Impacto_Dinamico.png", replace width(2000)

* ==============================================================================
* NIVEL 2A: TRIPLES DIFERENCIAS (DDD) - PENSIÓN SOLIDARIA (IEAC)
* ==============================================================================
disp "Ejecutando Modelos DDD..."

eststo ddd_sol_rf: reghdfe afp i.tratado##i.post##i.es_pobre_estructural $controles tendencia_tratado [pweight = peso_final_rf], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
outreg2 [ddd_sol_rf] using "$tabs/DDD_Pension_Solidaria.doc", replace word ctitle("Random Forest") drop(*0b* *1o*) title("Triple Diferencia: Pensión Solidaria sobre Pobres Estructurales") dec(4)

* ==============================================================================
* NIVEL 3: PRUEBAS DE FALSIFICACIÓN (PLACEBOS)
* ==============================================================================
disp "Ejecutando Placebos..."

preserve
    xtile q_est_local = ingreso_estructural_imputado [pweight=peso_final_rf], n(4)
    keep if q_est_local == 3 | q_est_local == 4
    gen byte fake_q1 = (q_est_local == 3)
    
    eststo pla_sol: reghdfe afp i.tratado##i.post##i.fake_q1 $controles c.gestion#1.tratado [pweight = peso_final_rf], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
    outreg2 [pla_sol] using "$tabs/Placebos.doc", replace word ctitle("Placebo Solidaria (Q3)") drop(*0b* *1o*) title("Pruebas Placebo (Efecto Nulo Esperado)") dec(4)
restore

disp "=========================================================================="
disp "ETAPA 6B FINALIZADA: ESTIMACIONES CAUSALES GUARDADAS EN /Outputs/Tables/"
disp "=========================================================================="
