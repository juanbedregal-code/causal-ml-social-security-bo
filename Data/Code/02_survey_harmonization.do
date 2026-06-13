/*==============================================================================
PROYECTO: Evaluación de Impacto Reforma de Pensiones (Bolivia)
ETAPA 02: Armonización de Microdatos y Construcción del Panel (2005 - 2025)
AUTOR: Juan José Bedregal

DESCRIPCIÓN:
Construcción de Panel Pooled Cross-Section a partir de las Encuestas de Hogares 
(EH) y la Encuesta Continua de Empleo (ECE).
 
AJUSTES METODOLÓGICOS: 
 - Armonización Cat. Ocupacional (Umbral de 5 trab. para Patrones).
 - Cálculo manual de horas trabajadas (EH 2013).
 - Construcción algorítmica de tipología de hogar y carga de dependencia.
==============================================================================*/

clear all
set more off
set varabbrev off

* ------------------------------------------------------------------------------
* 0. CONFIGURACIÓN DE DIRECTORIOS (Rutas Relativas Reproducibles)
* ------------------------------------------------------------------------------
* Asume que el directorio de trabajo actual (pwd) es la carpeta "Code"
* Si el usuario ejecuta el Do-file desde 'Code/', estas rutas relativas no fallarán.

global raw     "../Data/Raw"
global interim "../Data/Interim"
global clean   "../Data/Cleaned"

/*==============================================================================
  FASE 1: EXTRACCIÓN ENCUESTAS DE HOGARES (EH 2005 - 2015)
==============================================================================*/

*-------------------------------------------------------------------------------
**# AÑO 2005
*-------------------------------------------------------------------------------
import spss using "$raw/EH_2005.sav", case(lower) clear

drop edad // Limpieza manual solicitada
gen gestion = 2005
gen peso_anual = factor
gen byte trimestre = 4
rename folio id_hogar
rename nro1 id_persona
capture rename id01 depto
capture rename departamento depto

recode s1_02 (1=0) (2=1) (else=.), gen(genero)
gen edad = s1_03
replace edad = . if edad >= 99 | edad < 0

recode s1_10 (1/6=1) (7=0) (else=.), gen(es_indigena)
gen aestudio = aoesc
recode niv_ed_d (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (6=7) (else=.), gen(nivel_educativo)
recode s1_11 (1=1) (2=2) (3=3) (4=4) (5=5) (6=6) (else=.), gen(ecivil)
recode s4_76b (1=1) (2=0) (else=.), gen(afp)
gen byte afp_detalle = .

gen ocupacion = cob_ag
replace ocupacion = . if ocupacion < 0 | ocupacion > 9
gen ingreso_laboral = y_lab_t1a
gen horas_trabajadas = hrs_tot

recode s4_22 (1=1) (2=2) (3=4) (4=5) (else=.), gen(contrato)
gen factor_exp = factor
recode urb_rur (1=1) (2=0) (else=.), gen(area)
recode condact (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (else=.), gen(cond_actividad)

gen cat_ocupacional = .
replace cat_ocupacional = 1 if s4_21 == 1 | s4_21 == 2
replace cat_ocupacional = 2 if s4_21 == 3
replace cat_ocupacional = 3 if s4_21 == 5
replace cat_ocupacional = 2 if s4_21 == 4 & s4_26 <= 5 & s4_26 != .
replace cat_ocupacional = 3 if s4_21 == 4 & (s4_26 > 5 | s4_26 == .)
replace cat_ocupacional = 4 if s4_21 == 6
replace cat_ocupacional = 5 if s4_21 == 7
replace cat_ocupacional = 6 if s4_21 == 8

rename s1_05 parentesco
gen num_trabajadores = s4_26

* Mapeo del sector económico CAEB-98 (0-16) al CAEB-ECE (0-20)
gen sector_economico = .
replace sector_economico = 0 if inlist(caeb_ag, 0, 1)
replace sector_economico = 1 if caeb_ag == 2
replace sector_economico = 2 if caeb_ag == 3
replace sector_economico = 3 if caeb_ag == 4
replace sector_economico = 5 if caeb_ag == 5
replace sector_economico = 6 if caeb_ag == 6
replace sector_economico = 8 if caeb_ag == 7
replace sector_economico = 7 if caeb_ag == 8
replace sector_economico = 10 if caeb_ag == 9
replace sector_economico = 11 if caeb_ag == 10
replace sector_economico = 14 if caeb_ag == 11
replace sector_economico = 15 if caeb_ag == 12
replace sector_economico = 16 if caeb_ag == 13
replace sector_economico = 18 if caeb_ag == 14
replace sector_economico = 19 if caeb_ag == 15
replace sector_economico = 20 if caeb_ag == 16

keep gestion trimestre depto id_hogar id_persona genero edad es_indigena aestudio nivel_educativo ecivil afp afp_detalle ocupacion ingreso_laboral horas_trabajadas contrato factor_exp peso_anual upm estrato area cond_actividad cat_ocupacional parentesco num_trabajadores sector_economico
save "$interim/tmp_2005.dta", replace

*-------------------------------------------------------------------------------
**# AÑO 2008
*-------------------------------------------------------------------------------
use "$raw/EH_2008_limpia.dta", clear
rename _all, lower

drop ecivil 
gen gestion = 2008
gen byte trimestre = 4
rename nroper id_persona
gen peso_anual = factor
* Inferencia de departamento mediante el primer dígito del folio
gen byte depto = real(substr(folio, 1, 1))
rename folio id_hogar

recode s1_03 (1=0) (2=1) (else=.), gen(genero)
gen edad = s1_04
replace edad = . if edad >= 99 | edad < 0

recode s1_12 (1/6=1) (7=0) (else=.), gen(es_indigena)
gen aestudio = e
recode niv_ed_d (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (6=7) (else=.), gen(nivel_educativo)
recode s1_11 (1=1) (2=2) (3=3) (4=4) (5=5) (6=6) (else=.), gen(ecivil)
recode s5_58b (1=1) (2=0) (else=.), gen(afp)
gen byte afp_detalle = .

gen ocupacion = cob_op1
replace ocupacion = . if ocupacion < 0 | ocupacion > 9
gen ingreso_laboral = ylabf
gen horas_trabajadas = hrstot

recode s5_28 (1=1) (2=2) (3=4) (4=5) (else=.), gen(contrato)
gen factor_exp = factor
recode urb_rur (1=1) (2=0) (else=.), gen(area)
recode condact1 (1=1) (2=2) (3=3) (4=4) (5=5) (else=.), gen(cond_actividad)

gen cat_ocupacional = .
replace cat_ocupacional = 1 if s5_21 == 1 | s5_21 == 2
replace cat_ocupacional = 2 if s5_21 == 3
replace cat_ocupacional = 3 if s5_21 == 5
replace cat_ocupacional = 2 if s5_21 == 4 & s5_27 <= 5 & s5_27 != .
replace cat_ocupacional = 3 if s5_21 == 4 & (s5_27 > 5 | s5_27 == .)
replace cat_ocupacional = 4 if s5_21 == 6
replace cat_ocupacional = 5 if s5_21 == 7
replace cat_ocupacional = 6 if s5_21 == 8

rename s1_06 parentesco
gen num_trabajadores = s5_27

* Mapeo del sector económico CPAEB (1-17) al CAEB-ECE (0-20)
gen sector_economico = .
replace sector_economico = 0 if inlist(cpaeb_ac, 1, 2)
replace sector_economico = 1 if cpaeb_ac == 3
replace sector_economico = 2 if cpaeb_ac == 4
replace sector_economico = 3 if cpaeb_ac == 5
replace sector_economico = 5 if cpaeb_ac == 6
replace sector_economico = 6 if cpaeb_ac == 7
replace sector_economico = 8 if cpaeb_ac == 8
replace sector_economico = 7 if cpaeb_ac == 9
replace sector_economico = 10 if cpaeb_ac == 10
replace sector_economico = 11 if cpaeb_ac == 11
replace sector_economico = 14 if cpaeb_ac == 12
replace sector_economico = 15 if cpaeb_ac == 13
replace sector_economico = 16 if cpaeb_ac == 14
replace sector_economico = 18 if cpaeb_ac == 15
replace sector_economico = 19 if cpaeb_ac == 16
replace sector_economico = 20 if cpaeb_ac == 17

keep gestion trimestre depto id_hogar id_persona genero edad es_indigena aestudio nivel_educativo ecivil afp afp_detalle ocupacion ingreso_laboral horas_trabajadas contrato factor_exp peso_anual upm estrato area cond_actividad cat_ocupacional parentesco num_trabajadores sector_economico
save "$interim/tmp_2008.dta", replace

*-------------------------------------------------------------------------------
**# AÑO 2009
*-------------------------------------------------------------------------------
import spss using "$raw/EH_2009.sav", case(lower) clear

drop ecivil 
gen gestion = 2009
gen byte trimestre = 4
rename nro id_persona
gen peso_anual = factor
gen byte depto = real(substr(folio, 1, 1))
rename folio id_hogar
rename id09 upm
rename estrat_e estrato
recode s1_03 (1=0) (2=1) (else=.), gen(genero)
gen edad = s1_04
replace edad = . if edad >= 99 | edad < 0

recode s1_14 (1/6=1) (7=0) (else=.), gen(es_indigena)
gen aestudio = e
recode niv_ed_d (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (6=7) (else=.), gen(nivel_educativo)
recode s1_13 (1=1) (2=2) (3=3) (4=4) (5=5) (6=6) (else=.), gen(ecivil)
recode s5_58b (1=1) (2=0) (else=.), gen(afp)
gen byte afp_detalle = .

gen ocupacion = cob_op1
replace ocupacion = . if ocupacion < 0 | ocupacion > 9
gen ingreso_laboral = ylabf
gen horas_trabajadas = hrstot

recode s5_28 (1=1) (2=2) (3=4) (4=5) (else=.), gen(contrato)
gen factor_exp = factor
recode urb_rur (1=1) (2=0) (else=.), gen(area)
recode condact1 (1=1) (2=2) (3=3) (4=4) (5=5) (else=.), gen(cond_actividad)

gen cat_ocupacional = .
replace cat_ocupacional = 1 if s5_21 == 1 | s5_21 == 2
replace cat_ocupacional = 2 if s5_21 == 3
replace cat_ocupacional = 3 if s5_21 == 5
replace cat_ocupacional = 2 if s5_21 == 4 & s5_27 <= 5 & s5_27 != .
replace cat_ocupacional = 3 if s5_21 == 4 & (s5_27 > 5 | s5_27 == .)
replace cat_ocupacional = 4 if s5_21 == 6
replace cat_ocupacional = 5 if s5_21 == 7
replace cat_ocupacional = 6 if s5_21 == 8

rename s1_08 parentesco
gen num_trabajadores = s5_27

* Mapeo del sector económico (1-17) al CAEB-ECE (0-20)
gen sector_economico = .
replace sector_economico = 0 if inlist(acprin_r, 1, 2)
replace sector_economico = 1 if acprin_r == 3
replace sector_economico = 2 if acprin_r == 4
replace sector_economico = 3 if acprin_r == 5
replace sector_economico = 5 if acprin_r == 6
replace sector_economico = 6 if acprin_r == 7
replace sector_economico = 8 if acprin_r == 8
replace sector_economico = 7 if acprin_r == 9
replace sector_economico = 10 if acprin_r == 10
replace sector_economico = 11 if acprin_r == 11
replace sector_economico = 14 if acprin_r == 12
replace sector_economico = 15 if acprin_r == 13
replace sector_economico = 16 if acprin_r == 14
replace sector_economico = 18 if acprin_r == 15
replace sector_economico = 19 if acprin_r == 16
replace sector_economico = 20 if acprin_r == 17

keep gestion trimestre depto id_hogar id_persona genero edad es_indigena aestudio nivel_educativo ecivil afp afp_detalle ocupacion ingreso_laboral horas_trabajadas contrato factor_exp peso_anual upm estrato area cond_actividad cat_ocupacional parentesco num_trabajadores sector_economico
save "$interim/tmp_2009.dta", replace

*-------------------------------------------------------------------------------
**# AÑO 2011
*-------------------------------------------------------------------------------
import spss using "$raw/EH_2011.sav", case(lower) clear

gen gestion = 2011
gen byte trimestre = 4
rename folio id_hogar
rename nro1a id_persona
capture rename id01 depto
capture rename departamento depto
gen peso_anual = factor
destring estrato, replace ignore(" ")
recode s1_03 (1=0) (2=1) (else=.), gen(genero)
gen edad = s1_04
replace edad = . if edad >= 99 | edad < 0

gen es_indigena = .
replace es_indigena = 0 if cods2_05 == "88"
replace es_indigena = 1 if cods2_05 != "88" & cods2_05 != "99" & cods2_05 != ""

gen aestudio = e
recode niv_ed_d (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (6=7) (else=.), gen(nivel_educativo)
recode ecivil (1=1) (2=2) (3=3) (4=4) (6=6) (else=.), gen(ecivil_std)
drop ecivil
rename ecivil_std ecivil
recode s5_59b (1=1) (2=0) (else=.), gen(afp)
gen byte afp_detalle = .

gen ocupacion = cob_op
replace ocupacion = . if ocupacion < 0 | ocupacion > 9
gen ingreso_laboral = ylab
gen horas_trabajadas = tothrs

recode s5_28 (1=1) (2=2) (3=4) (4=5) (else=.), gen(contrato)
gen factor_exp = factor
recode area (1=1) (2=0) (else=.), gen(area_std)
drop area
rename area_std area
recode condact (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (else=.), gen(cond_actividad)

gen cat_ocupacional = .
replace cat_ocupacional = 1 if s5_21 == 1 | s5_21 == 2
replace cat_ocupacional = 2 if s5_21 == 3
replace cat_ocupacional = 3 if s5_21 == 5
replace cat_ocupacional = 2 if s5_21 == 4 & s5_27 <= 5 & s5_27 != .
replace cat_ocupacional = 3 if s5_21 == 4 & (s5_27 > 5 | s5_27 == .)
replace cat_ocupacional = 4 if s5_21 == 6
replace cat_ocupacional = 5 if s5_21 == 7
replace cat_ocupacional = 6 if s5_21 == 8

rename s1_08 parentesco
gen num_trabajadores = s5_27
gen sector_economico = caeb_op  // Ya está en formato 0-20

keep gestion trimestre depto id_hogar id_persona genero edad es_indigena aestudio nivel_educativo ecivil afp afp_detalle ocupacion ingreso_laboral horas_trabajadas contrato factor_exp peso_anual upm estrato area cond_actividad cat_ocupacional parentesco num_trabajadores sector_economico
save "$interim/tmp_2011.dta", replace

*-------------------------------------------------------------------------------
**# AÑO 2012
*-------------------------------------------------------------------------------
import spss using "$raw/EH_2012.sav", case(lower) clear

gen gestion = 2012
gen byte trimestre = 4
rename folio id_hogar
rename nro1a id_persona
capture rename id01 depto
capture rename departamento depto
gen peso_anual = factor
destring estrato, replace ignore(" ")

recode s1_03 (1=0) (2=1) (else=.), gen(genero)
gen edad = s1_04
replace edad = . if edad >= 99 | edad < 0

recode s2_05a (1=1) (2/3=0) (else=.), gen(es_indigena)
gen aestudio = e
recode niv_ed_d (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (6=7) (else=.), gen(nivel_educativo)
recode s1_13 (1=1) (2=2) (3=3) (4=4) (6=6) (else=.), gen(ecivil)

recode s5_59b (1=1) (2=0) (else=.), gen(afp)
gen byte afp_detalle = .

gen ocupacion = cob_op
replace ocupacion = . if ocupacion < 0 | ocupacion > 9
gen ingreso_laboral = ylab
gen horas_trabajadas = tothrs

recode s5_28 (1=1) (2=2) (3=4) (4=5) (else=.), gen(contrato)
gen factor_exp = factor
recode area (1=1) (2=0) (else=.), gen(area_std)
drop area
rename area_std area
recode condact (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (else=.), gen(cond_actividad)

gen cat_ocupacional = .
replace cat_ocupacional = 1 if s5_21 == 1 | s5_21 == 2
replace cat_ocupacional = 2 if s5_21 == 3
replace cat_ocupacional = 3 if s5_21 == 5
replace cat_ocupacional = 2 if s5_21 == 4 & s5_27 <= 5 & s5_27 != .
replace cat_ocupacional = 3 if s5_21 == 4 & (s5_27 > 5 | s5_27 == .)
replace cat_ocupacional = 4 if s5_21 == 6
replace cat_ocupacional = 5 if s5_21 == 7
replace cat_ocupacional = 6 if s5_21 == 8

rename s1_08 parentesco
gen num_trabajadores = s5_27
gen sector_economico = caeb_op1 
replace sector_economico = . if sector_economico == 99 // Limpiamos la categoría NS/NR

keep gestion trimestre depto id_hogar id_persona genero edad es_indigena aestudio nivel_educativo ecivil afp afp_detalle ocupacion ingreso_laboral horas_trabajadas contrato factor_exp peso_anual upm estrato area cond_actividad cat_ocupacional parentesco num_trabajadores sector_economico
save "$interim/tmp_2012.dta", replace

*-------------------------------------------------------------------------------
**# AÑO 2013 (Cálculo manual de horas)
*-------------------------------------------------------------------------------
import spss using "$raw/EH_2013.sav", case(lower) clear

gen gestion = 2013
gen byte trimestre = 4
rename folio id_hogar
rename nro2a id_persona
capture rename id01 depto
capture rename departamento depto
gen peso_anual = factor
destring estrato, replace ignore(" ")

recode s2_02 (1=0) (2=1) (else=.), gen(genero)
gen edad = s2_03
replace edad = . if edad >= 99 | edad < 0

recode s3_02a (1=1) (2/3=0) (else=.), gen(es_indigena)
gen aestudio = e
recode niv_ed (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (6/7=7) (else=.), gen(nivel_educativo)
recode s2_10 (1=1) (2=2) (3=3) (4=4) (5=5) (6=6) (else=.), gen(ecivil)
recode s6_52b (1=1) (2=0) (else=.), gen(afp)
gen byte afp_detalle = .

gen ocupacion = cob_op
replace ocupacion = . if ocupacion < 0 | ocupacion > 9
gen ingreso_laboral = ylab

* Horas
replace s6_22   = . if s6_22   == 9
replace s6_23h  = . if s6_23h  == 99
replace s6_23m  = . if s6_23m  == 99
replace s6_39a  = . if s6_39a  == 9
replace s6_39b1 = . if s6_39b1 == 99
replace s6_39b2 = . if s6_39b2 == 99
replace s6_23m  = 0 if s6_23m  == . & s6_23h  != .
replace s6_39b2 = 0 if s6_39b2 == . & s6_39b1 != .

gen hrs_dia_op = s6_23h + (s6_23m / 60)
gen hrs_sem_op = hrs_dia_op * s6_22
gen hrs_dia_os = s6_39b1 + (s6_39b2 / 60)
gen hrs_sem_os = hrs_dia_os * s6_39a
egen horas_trabajadas = rowtotal(hrs_sem_op hrs_sem_os), missing

recode s6_21 (1=1) (2=2) (3=4) (5=5) (else=.), gen(contrato)
gen factor_exp = factor
recode area (1=1) (2=0) (else=.), gen(area_std)
drop area
rename area_std area
recode condact (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (else=.), gen(cond_actividad)

gen cat_ocupacional = .
replace cat_ocupacional = 1 if s6_16 == 1 | s6_16 == 2
replace cat_ocupacional = 2 if s6_16 == 3
replace cat_ocupacional = 3 if s6_16 == 5
replace cat_ocupacional = 2 if s6_16 == 4 & s6_20 <= 5 & s6_20 != .
replace cat_ocupacional = 3 if s6_16 == 4 & (s6_20 > 5 | s6_20 == .)
replace cat_ocupacional = 4 if s6_16 == 6
replace cat_ocupacional = 5 if s6_16 == 7
replace cat_ocupacional = 6 if s6_16 == 8

rename s2_05 parentesco
gen num_trabajadores = s6_20
capture gen sector_economico = caeb_op
capture gen sector_economico = caeb_op1

keep gestion trimestre depto id_hogar id_persona genero edad es_indigena aestudio nivel_educativo ecivil afp afp_detalle ocupacion ingreso_laboral horas_trabajadas contrato factor_exp peso_anual upm estrato area cond_actividad cat_ocupacional parentesco num_trabajadores sector_economico
save "$interim/tmp_2013.dta", replace

*-------------------------------------------------------------------------------
**# AÑO 2014
*-------------------------------------------------------------------------------
import spss using "$raw/EH_2014.sav", case(lower) clear

gen gestion = 2014
gen byte trimestre = 4
rename folio id_hogar
rename nro id_persona
capture rename id01 depto
capture rename departamento depto
gen peso_anual = factor
recode s2a_02 (1=0) (2=1) (else=.), gen(genero)
gen edad = s2a_03
replace edad = . if edad >= 99 | edad < 0

recode s3a_02a (1=1) (2/3=0) (else=.), gen(es_indigena)
gen aestudio = e
recode niv_ed (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (7=7) (else=.), gen(nivel_educativo)
recode s2a_10 (1=1) (2=2) (3=3) (4=4) (5=5) (6=6) (else=.), gen(ecivil)
recode s6g_52b (1=1) (2=0) (else=.), gen(afp)
gen byte afp_detalle = .

gen ocupacion = cob_op
replace ocupacion = . if ocupacion < 0 | ocupacion > 9
gen ingreso_laboral = ylab
gen horas_trabajadas = tothrs

recode s6b_21 (1=1) (2=2) (3=4) (5=5) (else=.), gen(contrato)
gen factor_exp = factor
recode urbrur (1=1) (2=0) (else=.), gen(area)
recode condact (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (else=.), gen(cond_actividad)

gen cat_ocupacional = .
replace cat_ocupacional = 1 if s6b_16 == 1 | s6b_16 == 2
replace cat_ocupacional = 2 if s6b_16 == 3
replace cat_ocupacional = 3 if s6b_16 == 5
replace cat_ocupacional = 2 if s6b_16 == 4 & s6b_20 <= 5 & s6b_20 != .
replace cat_ocupacional = 3 if s6b_16 == 4 & (s6b_20 > 5 | s6b_20 == .)
replace cat_ocupacional = 4 if s6b_16 == 6
replace cat_ocupacional = 5 if s6b_16 == 7
replace cat_ocupacional = 6 if s6b_16 == 8

rename s2a_05 parentesco
capture gen num_trabajadores = s6b_20 
gen sector_economico = caeb_op

keep gestion trimestre depto id_hogar id_persona genero edad es_indigena aestudio nivel_educativo ecivil afp afp_detalle ocupacion ingreso_laboral horas_trabajadas contrato factor_exp peso_anual upm estrato area cond_actividad cat_ocupacional parentesco num_trabajadores sector_economico
save "$interim/tmp_2014.dta", replace

*-------------------------------------------------------------------------------
**# AÑO 2015 (EH Anual)
*-------------------------------------------------------------------------------
use "$raw/EH_2015_limpia.dta", clear
rename _all, lower

gen gestion = 2015
gen byte trimestre = 4
rename folio id_hogar
rename nro id_persona
capture rename departamento depto
gen peso_anual = factor
destring estrato, replace ignore(" ")

recode s2a_02 (1=0) (2=1) (else=.), gen(genero)
gen edad = s2a_03
replace edad = . if edad >= 99 | edad < 0

recode s3a_2a (1=1) (2/3=0) (else=.), gen(es_indigena)
gen aestudio = e
recode niv_ed_d (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (7=7) (else=.), gen(nivel_educativo)
recode s2a_10 (1=1) (2=2) (3=3) (4=4) (5=5) (6=6) (else=.), gen(ecivil)
recode s6g_52b (1=1) (2=0) (else=.), gen(afp)
gen byte afp_detalle = .

gen ocupacion = cob_op
replace ocupacion = . if ocupacion < 0 | ocupacion > 9
gen ingreso_laboral = ylab
gen horas_trabajadas = tothrs

recode s6b_17 (1=1) (2=2) (3=3) (4=4) (5=5) (else=.), gen(contrato)
gen factor_exp = factor
recode area (1=1) (2=0) (else=.), gen(area_std)
drop area
rename area_std area
recode condact (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (else=.), gen(cond_actividad)

gen cat_ocupacional = .
replace cat_ocupacional = 1 if s6b_16 == 1 | s6b_16 == 2
replace cat_ocupacional = 2 if s6b_16 == 3
replace cat_ocupacional = 3 if s6b_16 == 5
replace cat_ocupacional = 2 if s6b_16 == 4 & s6b_21 <= 5 & s6b_21 != .
replace cat_ocupacional = 3 if s6b_16 == 4 & (s6b_21 > 5 | s6b_21 == .)
replace cat_ocupacional = 4 if s6b_16 == 6
replace cat_ocupacional = 5 if s6b_16 == 7
replace cat_ocupacional = 6 if s6b_16 == 8

rename s2a_05 parentesco
capture gen num_trabajadores = s6b_20 
capture gen num_trabajadores = s6b_21 
gen sector_economico = caeb_op

keep gestion trimestre depto id_hogar id_persona genero edad es_indigena aestudio nivel_educativo ecivil afp afp_detalle ocupacion ingreso_laboral horas_trabajadas contrato factor_exp peso_anual upm estrato area cond_actividad cat_ocupacional parentesco num_trabajadores sector_economico
save "$interim/tmp_2015.dta", replace

/*==============================================================================
  FASE 2: EXTRACCIÓN ENCUESTA CONTINUA DE EMPLEO (ECE 2016 - 2025)
==============================================================================*/

use "$raw/ECE_4T15_3T25.dta", clear
rename _all, lower

* Eliminación del cuarto trimestre 2015 para evitar traslape con EH Anual
drop if gestion == 2015

* Identificadores
tostring id_hogar, replace format(%15.0g)

recode s1_02 (1=0) (2=1) (else=.), gen(genero)
gen edad = s1_03a
replace edad = . if edad >= 99 | edad < 0

recode s1_17 (1=1) (2=0) (else=.), gen(es_indigena)

* Reconstrucción de Años de Estudio (Corrección del 70% de missings)
rename aestudio aestudio_1
gen aestudio = e
gen byte aestudio_calc = 0
replace aestudio_calc = s1_07b if inlist(s1_07a, 21, 31, 41)
replace aestudio_calc = 5 + s1_07b if s1_07a == 22
replace aestudio_calc = 6 + s1_07b if s1_07a == 42
replace aestudio_calc = 8 + s1_07b if inlist(s1_07a, 23, 32)
replace aestudio_calc = 12 + s1_07b if inlist(s1_07a, 71, 72, 73, 77, 78, 79)
replace aestudio_calc = 16 if inlist(s1_07a, 74, 75, 76)
replace aestudio = aestudio_calc if missing(aestudio) & s1_07a != . & s1_07a != 998 & s1_07a != 999

recode niv_ed (0=0) (1=1) (2=2) (3=3) (4=4) (5=5) (7=7) (else=.), gen(nivel_educativo)
recode s1_16 (1=1) (2=2) (3=3) (4=4) (5=5) (6=6) (else=.), gen(ecivil)

recode s2_64 (1=1) (2=0) (else=.), gen(afp)
gen afp_detalle = s2_64a

gen ocupacion = cob_op
replace ocupacion = . if ocupacion < 0 | ocupacion > 9
gen ingreso_laboral = ylab
gen horas_trabajadas = tothrs

recode s2_21 (1=1) (2=2) (3=3) (4=4) (5=5) (else=.), gen(contrato)
gen factor_exp = fact_trim          
gen peso_anual = fact_trim / 4      // Peso estabilizado para el DiD Anual
recode area (1=1) (2=0) (else=.), gen(area_std)
drop area
rename area_std area

* Condición de Actividad (Forzando 0 para menores de 14)
gen cond_actividad = condact
replace cond_actividad = 0 if edad < 14
replace cond_actividad = . if cond_actividad > 5

* Categoría Ocupacional ECE (Armonizada)
gen cat_ocupacional = .
replace cat_ocupacional = 1 if s2_18 == 1
replace cat_ocupacional = 2 if s2_18 == 2
replace cat_ocupacional = 3 if s2_18 == 3
replace cat_ocupacional = 4 if s2_18 == 4
replace cat_ocupacional = 5 if s2_18 == 5 | s2_18 == 6
replace cat_ocupacional = 6 if s2_18 == 7

* Armonización de Parentesco (Mapeo ECE -> EH)
recode s1_05 (1=1) (2=2) (3 4 15=3) (5=4) (7 8 16=5) (9=6) (10=7) (6=8) (11 12=9) (13=10) (14=11) (else=.), gen(parentesco)

gen num_trabajadores = s2_26
gen sector_economico = caeb_op

keep gestion trimestre depto id_hogar id_persona genero edad es_indigena aestudio nivel_educativo ecivil afp afp_detalle ocupacion ingreso_laboral horas_trabajadas contrato factor_exp peso_anual upm estrato area cond_actividad cat_ocupacional parentesco num_trabajadores sector_economico
save "$interim/tmp_ece.dta", replace

/*==============================================================================
  FASE 3: CONSOLIDACIÓN FINAL E INGENIERÍA DE CARACTERÍSTICAS
==============================================================================*/

use "$interim/tmp_2005.dta", clear
append using "$interim/tmp_2008.dta"
append using "$interim/tmp_2009.dta"
append using "$interim/tmp_2011.dta"
append using "$interim/tmp_2012.dta"
append using "$interim/tmp_2013.dta"
append using "$interim/tmp_2014.dta"
append using "$interim/tmp_2015.dta"
append using "$interim/tmp_ece.dta"

*-------------------------------------------------------------------------------
* 3.1. VARIABLES DERIVADAS PARA EL PSM (Adaptadas a ECE)
*-------------------------------------------------------------------------------

gen byte mujer = (genero == 1)

* 1. Tamaño de la Empresa
gen byte tamano_empresa = .
replace tamano_empresa = 1 if num_trabajadores == 1
replace tamano_empresa = 2 if num_trabajadores >= 2 & num_trabajadores <= 5
replace tamano_empresa = 3 if num_trabajadores >= 6 & num_trabajadores <= 10
replace tamano_empresa = 4 if num_trabajadores >= 11 & num_trabajadores <= 20
replace tamano_empresa = 5 if num_trabajadores >= 21 & num_trabajadores <= 30
replace tamano_empresa = 6 if num_trabajadores >= 31 & num_trabajadores <= 50
replace tamano_empresa = 7 if num_trabajadores >= 51 & num_trabajadores <= 100
replace tamano_empresa = 8 if num_trabajadores > 100 & num_trabajadores != .

* 2. Niños menores de 12 años y Tamaño del Hogar
gen byte nino_var = (edad < 12)
bysort gestion trimestre depto id_hogar: egen ninos_menores_12 = total(nino_var)
drop nino_var

bysort gestion trimestre depto id_hogar: egen tamano_hogar = count(id_persona)

* 3. Presencia de otro aportante
bysort gestion trimestre depto id_hogar: egen total_afp = total(afp)
gen byte otro_aportante = (total_afp - afp > 0) if total_afp != .
drop total_afp

* 4. Identificador de Madres
gen byte es_hijo = (parentesco == 3)
bysort gestion trimestre depto id_hogar: egen hogar_tiene_hijos = max(es_hijo)
gen byte madre_hogar = 0
replace madre_hogar = 1 if mujer == 1 & inlist(parentesco, 1, 2) & hogar_tiene_hijos == 1
drop es_hijo hogar_tiene_hijos

* 5. Tipología del Hogar Estructural
gen byte aux_conyuge = (parentesco == 2)
gen byte aux_hijo    = (parentesco == 3)
gen byte aux_otros = (parentesco > 3 & parentesco < 11) if !missing(parentesco)

bysort id_hogar: egen tiene_conyuge = max(aux_conyuge)
bysort id_hogar: egen tiene_hijos   = max(aux_hijo)
bysort id_hogar: egen tiene_otros   = max(aux_otros)
bysort id_hogar: egen total_miembros = count(id_persona)

gen byte tipologia_hogar = .
replace tipologia_hogar = 1 if total_miembros == 1
replace tipologia_hogar = 2 if tiene_conyuge == 1 & tiene_otros == 0
replace tipologia_hogar = 3 if tiene_conyuge == 0 & tiene_hijos == 1 & tiene_otros == 0
replace tipologia_hogar = 4 if tiene_otros == 1

label define lbl_tipo_hogar 1 "Unipersonal" 2 "Nuclear" 3 "Monoparental" 4 "Extendido/Compuesto"
label values tipologia_hogar lbl_tipo_hogar
drop aux_conyuge aux_hijo aux_otros tiene_conyuge tiene_hijos tiene_otros total_miembros

* 6. Carga de Dependencia Demográfica
gen byte aux_dependiente = (edad < 12 | edad > 65) if edad != .
gen byte aux_productivo  = (edad >= 12 & edad <= 65) if edad != .

bysort id_hogar: egen tot_dependientes = total(aux_dependiente)
bysort id_hogar: egen tot_productivos  = total(aux_productivo)

gen carga_dependencia = tot_dependientes / tot_productivos
replace carga_dependencia = tot_dependientes if tot_productivos == 0
drop aux_dependiente aux_productivo tot_dependientes tot_productivos

* 7. Índice de Masculinidad del Hogar
gen byte aux_hombre_pet = (mujer == 0 & edad >= 15 & edad <= 65) if edad != .
gen byte aux_adulto_pet = (edad >= 15 & edad <= 65) if edad != .

bysort id_hogar: egen tot_hombres_pet = total(aux_hombre_pet)
bysort id_hogar: egen tot_adultos_pet = total(aux_adulto_pet)

gen float masculinidad_hogar = tot_hombres_pet / tot_adultos_pet
replace masculinidad_hogar = 0 if tot_adultos_pet == 0 & !missing(tot_hombres_pet)
drop aux_hombre_pet aux_adulto_pet tot_hombres_pet tot_adultos_pet

*-------------------------------------------------------------------------------
* 3.2. ETIQUETADO Y EXPORTACIÓN
*-------------------------------------------------------------------------------
label variable id_hogar         "Identificador único del hogar"
label variable id_persona       "Identificador único de persona (dentro del hogar)"
label variable gestion          "Año de la Encuesta"
label variable trimestre        "Trimestre de Encuesta (EH=4, ECE=1 a 4)"
label variable ingreso_laboral  "Ingreso Laboral Total (Mensualizado)"
label variable horas_trabajadas "Horas Trabajadas a la Semana (Op+Os)"
label variable tipologia_hogar  "Tipología Estructural del Hogar"
label variable carga_dependencia "Ratio de Dependencia Demográfica del Hogar"
label variable masculinidad_hogar "Proporción de Hombres en Edad de Trabajar (15-65)"

* Se guarda el panel consolidado en la carpeta de resultados intermedios
compress
save "$interim/PANEL_MICRO_2005_2025.dta", replace

* Limpieza de archivos temporales
erase "$interim/tmp_2005.dta"
erase "$interim/tmp_2008.dta"
erase "$interim/tmp_2009.dta"
erase "$interim/tmp_2011.dta"
erase "$interim/tmp_2012.dta"
erase "$interim/tmp_2013.dta"
erase "$interim/tmp_2014.dta"
erase "$interim/tmp_2015.dta"
erase "$interim/tmp_ece.dta"

disp "=========================================================================="
disp "PANEL POOLED CROSS-SECTION CREADO EXITOSAMENTE"
disp "=========================================================================="
