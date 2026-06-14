/*==============================================================================
PROYECTO: Evaluación Impacto Ley 065 (Bolivia)
ETAPA 07: ESTIMACIÓN CAUSAL Y MECANISMOS (D-D, D-D-D, Event Studies)
AUTOR: Juan José Bedregal

DESCRIPCIÓN:
Ejecuta la totalidad del modelo econométrico causal utilizando los pesos 
doblemente robustos generados. Incluye todos los mecanismos causales: Impacto 
Global, Pension Solidaria, Bono Madre, Anticipación, y Escape vs Exclusión.
==============================================================================*/

clear all
set more off
set varabbrev off

global clean   "../Data/Cleaned"
global tabs    "../Outputs/Tables"
global figs    "../Outputs/Figures"

* 1. Cargar Base Maestra
use "$clean/PANEL_EVALUACION_CAUSAL.dta", clear
svyset upm [pweight = peso_anual], strata(estrato) singleunit(scaled)

* Definición global de controles
global controles "c.edad##c.edad i.mujer i.es_indigena i.area c.tamano_hogar c.ninos_menores_12 i.otro_aportante i.ecivil i.tipologia_hogar carga_dependencia masculinidad_hogar"

* ==============================================================================
**# NIVEL 1: IMPACTO CAUSAL GLOBAL LEY 065 (DiD DOBLEMENTE ROBUSTO)
* ==============================================================================
eststo m_logit: reghdfe afp did_interact $controles c.gestion#1.tratado [pweight = peso_final_logit], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
outreg2 [m_logit] using "$tabs/Impacto_Global_Ley065.doc", replace word keep(did_interact) ctitle("Logit") addtext(Tendencia Grupo, SI, FE Depto-Año, SI, FE Sector, SI) title("Impacto Global Ley 065 sobre la Formalidad (DiD Doblemente Robusto)") dec(4)

eststo m_lasso: reghdfe afp did_interact $controles c.gestion#1.tratado [pweight = peso_final_lasso], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
outreg2 [m_lasso] using "$tabs/Impacto_Global_Ley065.doc", append word keep(did_interact) ctitle("Lasso") addtext(Tendencia Grupo, SI, FE Depto-Año, SI, FE Sector, SI) dec(4)

eststo m_rf: reghdfe afp did_interact $controles c.gestion#1.tratado [pweight = peso_final_rf], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
outreg2 [m_rf] using "$tabs/Impacto_Global_Ley065.doc", append word keep(did_interact) ctitle("Random Forest") addtext(Tendencia Grupo, SI, FE Depto-Año, SI, FE Sector, SI) dec(4)

* ==============================================================================
**# NIVEL 1B: ESTUDIO DE EVENTOS (DINÁMICA Y TENDENCIAS PARALELAS)
* ==============================================================================
cap drop tendencia_tratado
gen tendencia_tratado = (gestion - 2009) * tratado

cap drop ev_*
local anios_es 2005 2008 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024
foreach a of local anios_es {
    gen ev_`a' = (gestion == `a') * tratado
}

eststo es_logit: reghdfe afp ev_* tendencia_tratado $controles [pweight = peso_final_logit], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
outreg2 [es_logit] using "$tabs/EventStudy_Ley065.doc", replace word ctitle("Logit") keep(ev_* tendencia_tratado) addtext(Tendencia Grupo, SI, FE Depto-Año, SI) dec(4)

eststo es_lasso: reghdfe afp ev_* tendencia_tratado $controles [pweight = peso_final_lasso], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
outreg2 [es_lasso] using "$tabs/EventStudy_Ley065.doc", append word ctitle("Lasso") keep(ev_* tendencia_tratado) addtext(Tendencia Grupo, SI, FE Depto-Año, SI) dec(4)

eststo es_rf: reghdfe afp ev_* tendencia_tratado $controles [pweight = peso_final_rf], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
outreg2 [es_rf] using "$tabs/EventStudy_Ley065.doc", append word ctitle("Random Forest") keep(ev_* tendencia_tratado) addtext(Tendencia Grupo, SI, FE Depto-Año, SI) dec(4)

coefplot (es_logit, msymbol(O) mcolor(gs10) ciopts(lcolor(gs10)) label("Logit")) ///
         (es_lasso, msymbol(T) mcolor(navy) ciopts(lcolor(navy)) label("Lasso / Ridge")) ///
         (es_rf,    msymbol(D) mcolor(maroon) ciopts(lcolor(maroon)) label("Random Forest")), ///
         vertical keep(ev_*) rename(ev_([0-9]+) = "\1", regex) /// 
         yline(0, lcolor(black) lpattern(solid)) xline(2.5, lcolor(red) lpattern(dash) lwidth(medthick)) ///
         title("Estudio de Eventos: Impacto Dinámico de la Ley 065", size(medlarge)) ///
         ytitle("Efecto Neto sobre Formalidad (pp)") xtitle("Año (Gestión)") graphregion(color(white)) legend(position(6) rows(1))
graph export "$figs/EventStudy_Comparativo_Purgado.png", replace width(2500)

* ==============================================================================
**# NIVEL 2A: DDD - EFECTO ANTICIPACIÓN JUBILACIÓN (HOMBRES)
* ==============================================================================
preserve
    keep if mujer == 0
    keep if edad >= 38 & edad <= 57
    gen byte cohorte_ant = (edad >= 48)

    eststo ddd_ant_logit: reghdfe afp i.tratado##i.post##i.cohorte_ant $controles tendencia_tratado [pweight = peso_final_logit], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
    outreg2 [ddd_ant_logit] using "$tabs/DDD_Edad_Anticipacion.doc", replace word ctitle("Logit") addtext(FE Depto-Año, SI) drop(*0b* *1o*) title("Triple Diferencia: Reducción Edad Jubilación (Hombres)") dec(4)

    eststo ddd_ant_lasso: reghdfe afp i.tratado##i.post##i.cohorte_ant $controles tendencia_tratado [pweight = peso_final_lasso], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
    outreg2 [ddd_ant_lasso] using "$tabs/DDD_Edad_Anticipacion.doc", append word ctitle("Lasso") addtext(FE Depto-Año, SI) drop(*0b* *1o*) dec(4)

    eststo ddd_ant_rf: reghdfe afp i.tratado##i.post##i.cohorte_ant $controles tendencia_tratado [pweight = peso_final_rf], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
    outreg2 [ddd_ant_rf] using "$tabs/DDD_Edad_Anticipacion.doc", append word ctitle("Random Forest") addtext(FE Depto-Año, SI) drop(*0b* *1o*) dec(4)
restore

* ==============================================================================
**# NIVEL 2B: DDD - PENSIÓN SOLIDARIA (USANDO EL IEAC)
* ==============================================================================
eststo ddd_sol_logit: reghdfe afp i.tratado##i.post##i.es_pobre_estructural $controles tendencia_tratado [pweight = peso_final_logit], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
outreg2 [ddd_sol_logit] using "$tabs/DDD_Pension_Solidaria_Full.doc", replace word ctitle("Logit") drop(*0b* *1o*) title("Triple Diferencia: Pensión Solidaria sobre Pobres Estructurales (IEAC)") dec(4)

eststo ddd_sol_lasso: reghdfe afp i.tratado##i.post##i.es_pobre_estructural $controles tendencia_tratado [pweight = peso_final_lasso], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
outreg2 [ddd_sol_lasso] using "$tabs/DDD_Pension_Solidaria_Full.doc", append word ctitle("Lasso") drop(*0b* *1o*) dec(4)

eststo ddd_sol_rf: reghdfe afp i.tratado##i.post##i.es_pobre_estructural $controles tendencia_tratado [pweight = peso_final_rf], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
outreg2 [ddd_sol_rf] using "$tabs/DDD_Pension_Solidaria_Full.doc", append word ctitle("Random Forest") drop(*0b* *1o*) dec(4)

* ------------------------------------------------------------------------------
* EVENT STUDY DDD: PENSIÓN SOLIDARIA (DINÁMICO)
* ------------------------------------------------------------------------------
local anios_es 2005 2008 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024
cap drop ev_ddd_*
global vars_es_ddd ""
foreach a of local anios_es {
    gen ev_ddd_`a' = (gestion == `a') * tratado * es_pobre_estructural
    global vars_es_ddd "$vars_es_ddd ev_ddd_`a'"
}

eststo es_ddd_logit: reghdfe afp $vars_es_ddd $vars_event_study i.es_pobre_estructural##ib2009.gestion i.tratado##i.es_pobre_estructural tendencia_tratado $controles [pweight = peso_final_logit], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
eststo es_ddd_lasso: reghdfe afp $vars_es_ddd $vars_event_study i.es_pobre_estructural##ib2009.gestion i.tratado##i.es_pobre_estructural tendencia_tratado $controles [pweight = peso_final_lasso], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
eststo es_ddd_rf: reghdfe afp $vars_es_ddd $vars_event_study i.es_pobre_estructural##ib2009.gestion i.tratado##i.es_pobre_estructural tendencia_tratado $controles [pweight = peso_final_rf], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)

coefplot (es_ddd_logit, msymbol(O) mcolor(gs10) ciopts(lcolor(gs10)) label("Logit")) ///
         (es_ddd_lasso, msymbol(T) mcolor(navy) ciopts(lcolor(navy)) label("Lasso / Ridge")) ///
         (es_ddd_rf,    msymbol(D) mcolor(maroon) ciopts(lcolor(maroon)) label("Random Forest")), ///
    vertical keep(ev_ddd_*) rename(ev_ddd_([0-9]+) = "\1", regex) ///
    yline(0, lcolor(black)) xline(2.5, lcolor(red) lpattern(dash)) ///
    title("Event Study DDD: Impacto Dinámico de la Pensión Solidaria", size(medlarge)) ///
    ytitle("Efecto Neto en Formalización (pp)") xtitle("Año") graphregion(color(white)) legend(position(6) rows(1))
graph export "$figs/EventStudy_DDD_Pension_Solidaria.png", replace width(2500)

* ==============================================================================
**# NIVEL 2C: DDD - BONO MADRE (MUJERES)
* ==============================================================================
preserve
    keep if mujer == 1
    eststo ddd_madre_logit: reghdfe afp i.tratado##i.post##i.madre_hogar $controles tendencia_tratado [pweight = peso_final_logit], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
    outreg2 [ddd_madre_logit] using "$tabs/DDD_Bono_Madre.doc", replace word ctitle("Logit") drop(*0b* *1o*) title("Triple Diferencia: Bono por Hijo (Madres vs No Madres)") dec(4)

    eststo ddd_madre_lasso: reghdfe afp i.tratado##i.post##i.madre_hogar $controles tendencia_tratado [pweight = peso_final_lasso], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
    outreg2 [ddd_madre_lasso] using "$tabs/DDD_Bono_Madre.doc", append word ctitle("Lasso") drop(*0b* *1o*) dec(4)

    eststo ddd_madre_rf: reghdfe afp i.tratado##i.post##i.madre_hogar $controles tendencia_tratado [pweight = peso_final_rf], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
    outreg2 [ddd_madre_rf] using "$tabs/DDD_Bono_Madre.doc", append word ctitle("Random Forest") drop(*0b* *1o*) dec(4)
restore

* ==============================================================================
**# NIVEL 3: INTERACCIÓN MACRO (ESCAPE VS EXCLUSIÓN) - SOLO RANDOM FOREST
* ==============================================================================
cap drop segmento_laboral
gen byte segmento_laboral = .
replace segmento_laboral = 1 if cat_ocupacional == 1 | cat_ocupacional == 6 // Asalariados
replace segmento_laboral = 2 if cat_ocupacional == 2 | cat_ocupacional == 3 // Independientes

preserve
    keep if segmento_laboral == 1
    eststo es_exclu: reghdfe afp ev_* tendencia_tratado $controles [pweight = peso_final_rf], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
restore
preserve
    keep if segmento_laboral == 2
    eststo es_escape: reghdfe afp ev_* tendencia_tratado $controles [pweight = peso_final_rf], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
restore

coefplot (es_exclu, msymbol(O) mcolor(navy) ciopts(lcolor(navy)) label("Asalariados (Exclusión)")) ///
         (es_escape, msymbol(D) mcolor(maroon) ciopts(lcolor(maroon)) label("Independientes (Escape)")), ///
         vertical keep(ev_*) rename(ev_([0-9]+) = "\1", regex) ///
         yline(0, lcolor(black) lpattern(solid)) xline(2.5, lcolor(red) lpattern(dash) lwidth(medthick)) ///
         title("Dinámica de Segmentos Laborales (Event Study)", size(medlarge)) ///
         ytitle("Diferencia Purgada en Formalización (pp)") xtitle("Año") graphregion(color(white)) legend(position(6) rows(1))
graph export "$figs/EventStudy_Segmentos_Laborales.png", replace width(2500)

* ==============================================================================
**# FASE FINAL: PRUEBAS DE FALSIFICACIÓN (PLACEBO FAKE GROUPS)
* ==============================================================================
preserve
    xtile q_est_local = ingreso_estructural_imputado [pweight=peso_final_rf], n(4)
    keep if q_est_local == 3 | q_est_local == 4
    gen byte fake_q1 = (q_est_local == 3)
    eststo pla_sol: reghdfe afp i.tratado##i.post##i.fake_q1 $controles c.gestion#1.tratado [pweight = peso_final_rf], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
    outreg2 [pla_sol] using "$tabs/Placebos_FakeGroups.doc", replace word ctitle("Placebo Solidaria (Q3)") drop(*0b* *1o*) title("Pruebas Placebo: Grupos Falsos") dec(4)
restore

preserve
    keep if mujer == 0 
    gen byte padre_hogar = (ninos_menores_12 > 0) 
    eststo pla_madre: reghdfe afp i.tratado##i.post##i.padre_hogar c.edad##c.edad i.es_indigena i.area c.tamano_hogar [pweight = peso_final_rf], absorb(depto#gestion sector_economico) vce(cluster depto#tratado)
    outreg2 [pla_madre] using "$tabs/Placebos_FakeGroups.doc", append word ctitle("Placebo Madres (Hombres Padres)") drop(*0b* *1o*) dec(4)
restore

disp "=========================================================================="
disp "ETAPA 07: ESTIMACIÓN CAUSAL Y MECANISMOS FINALIZADA EXITOSAMENTE."
disp "=========================================================================="
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
