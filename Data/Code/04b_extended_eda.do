/*==============================================================================
PROYECTO: Evaluación de Impacto Reforma de Pensiones (Bolivia)
ETAPA 04B: Análisis Exploratorio de Datos (Extended EDA) y Descriptivas
AUTOR: Juan José Bedregal

DESCRIPCIÓN:
Genera el set completo de estadísticas descriptivas y gráficos estructurales 
requeridos para la investigación académica. Este script está diseñado de forma 
modular para no sobrecargar el pipeline de Machine Learning.
==============================================================================*/

clear all
set more off
set varabbrev off

* ------------------------------------------------------------------------------
* 0. CONFIGURACIÓN DE DIRECTORIOS (Rutas Relativas Reproducibles DIME)
* ------------------------------------------------------------------------------
global clean   "../Data/Cleaned"
global tabs    "../Outputs/Tables"
global figs    "../Outputs/Figures"

* Cargar la base de datos limpia
use "$clean/PANEL_LISTO_PARA_ML.dta", clear

* A partir de este punto, el análisis gráfico requiere solo a la PEA Ocupada
keep if cond_actividad == 1

*-------------------------------------------------------------------------------
**# 1. TABLAS DE FORMALIZACIÓN POR CATEGORÍAS (Exportación a RTF)
*-------------------------------------------------------------------------------

* Tabla 1.1: Tamaño de Empresa
eststo clear
estpost tabstat afp_pct if reforma == 0 [aw=peso_anual], by(tamano_empresa) statistics(mean) columns(statistics)
eststo pre_tam
estpost tabstat afp_pct if reforma == 1 [aw=peso_anual], by(tamano_empresa) statistics(mean) columns(statistics)
eststo post_tam

esttab pre_tam post_tam using "$tabs/Tablas_Categorias.rtf", replace ///
    cells("mean(fmt(2))") collabels(none) ///
    coeflabels(1 "1 persona" 2 "2 a 5 personas" 3 "6 a 10 personas" ///
               4 "11 a 20 personas" 5 "21 a 30 personas" 6 "31 a 50 personas" ///
               7 "51 a 100 personas" 8 "101 o más personas" Total "Promedio Nacional") ///
    mtitles("Tasa AFP Pre-2010 (%)" "Tasa AFP Post-2010 (%)") ///
    title("Tasa de Formalización por Tamaño de Empresa") label nonumber noobs

* Tabla 1.2: Categoría Ocupacional
eststo clear
estpost tabstat afp_pct if reforma == 0 [aw=peso_anual], by(cat_ocupacional) statistics(mean) columns(statistics)
eststo pre_cat
estpost tabstat afp_pct if reforma == 1 [aw=peso_anual], by(cat_ocupacional) statistics(mean) columns(statistics)
eststo post_cat

esttab pre_cat post_cat using "$tabs/Tablas_Categorias.rtf", append ///
    cells("mean(fmt(2))") collabels(none) ///
    coeflabels(1 "Obrero / Empleado" 2 "Trabajador por Cuenta propia" ///
               3 "Patrón / Empleador" 4 "Cooperativista" 5 "Familiar o Aprendiz" ///
               6 "Empleada/o del hogar" Total "Promedio Nacional") ///
    mtitles("Tasa AFP Pre-2010 (%)" "Tasa AFP Post-2010 (%)") ///
    title("Tasa de Formalización por Categoría Ocupacional") label nonumber noobs

* Tabla 1.3: Tipología Estructural del Hogar
eststo clear
estpost tabstat afp_pct if reforma == 0 [aw=peso_anual], by(tipologia_hogar) statistics(mean) columns(statistics)
eststo pre_tipo
estpost tabstat afp_pct if reforma == 1 [aw=peso_anual], by(tipologia_hogar) statistics(mean) columns(statistics)
eststo post_tipo

esttab pre_tipo post_tipo using "$tabs/Tablas_Categorias.rtf", append ///
    cells("mean(fmt(2))") collabels(none) ///
    coeflabels(1 "Unipersonal" 2 "Nuclear" 3 "Monoparental" 4 "Extendido/Compuesto" Total "Promedio Nacional") ///
    mtitles("Tasa AFP Pre-2010 (%)" "Tasa AFP Post-2010 (%)") ///
    title("Tasa de Formalización por Tipología Estructural del Hogar") label nonumber noobs

*-------------------------------------------------------------------------------
**# 2. GRÁFICOS TEMPORALES Y ESTRUCTURALES (Exportación a PNG)
*-------------------------------------------------------------------------------

**# Gráfico 2.1: Evolución Global
preserve
    collapse (mean) afp_pct[pweight=factor_exp], by(t_q)
    twoway (line afp_pct t_q, lcolor(navy) lwidth(medium) cmissing(y)), ///
        xline(203, lcolor(red) lpattern(dash)) ///
        title("Evolución de la Tasa de Formalización (Bolivia 2005-2025)") ///
        xtitle("Año-Trimestre") ytitle("Porcentaje (%)") xlabel(180(20)260) legend(off)
    graph export "$figs/Grafico_Formalizacion_Global.png", as(png) replace
restore

**# Gráfico 2.2: Brecha de Formalización por Género
preserve
    collapse (mean) afp_pct [pweight=factor_exp], by(t_q genero)
    twoway (line afp_pct t_q if genero==0, lcolor(blue) cmissing(y)) ///
           (line afp_pct t_q if genero==1, lcolor(red) cmissing(y)), ///
        xline(203, lcolor(black) lpattern(dash)) ///
        title("Tasa de Formalización por Género") ///
        legend(label(1 "Hombres") label(2 "Mujeres")) ///
        xtitle("Año-Trimestre") ytitle("% Aportantes AFP")
    graph export "$figs/Grafico_Brecha_Genero.png", as(png) replace
restore

**# Gráfico 2.3: Brecha de Producto vs Formalización
preserve
    collapse (mean) afp_pct brecha_real, by(t_q)
    twoway (bar brecha_real t_q, yaxis(1) fcolor(gs14) lcolor(gs12)) ///
           (line afp_pct t_q, yaxis(2) lcolor(dknavy) lwidth(medium) cmissing(y)), ///
        xline(203, lcolor(red)) ///
        title("Formalidad y Ciclo Económico") ///
        ytitle("Brecha de Producto", axis(1)) ytitle("Tasa de Formalización %", axis(2)) ///
        legend(label(1 "Brecha de Producto (Filtro CF)") label(2 "Tasa AFP"))
    graph export "$figs/Grafico_Brecha_vs_AFP.png", as(png) replace
restore

**# Gráfico 2.4: Evolución por Deciles de Ingreso
preserve
    keep if ingreso_laboral > 0 & ingreso_laboral != .
	gquantiles decile_ingreso = ingreso_laboral [aweight=factor_exp], xtile nq(10) by(t_q)
	gen afp_d1    = afp_pct if decile_ingreso == 1
    gen afp_d2    = afp_pct if decile_ingreso == 2
    gen afp_d9    = afp_pct if decile_ingreso == 9
    gen afp_d10   = afp_pct if decile_ingreso == 10
    gen afp_media = afp_pct
    
    collapse (mean) afp_d1 afp_d2 afp_d9 afp_d10 afp_media [pweight=factor_exp], by(t_q)
    twoway (line afp_d1 t_q, lcolor(eltblue) lwidth(medthick) cmissing(y)) ///
           (line afp_d2 t_q, lcolor(blue) lwidth(medthick) cmissing(y)) ///
           (line afp_d9 t_q, lcolor(orange) lwidth(medthick) cmissing(y)) ///
           (line afp_d10 t_q, lcolor(red) lwidth(medthick) cmissing(y)) ///
           (line afp_media t_q, lcolor(black) lpattern(dash) lwidth(thick) cmissing(y)), ///
        xline(203, lcolor(gs8) lpattern(dash)) ///
        title("Formalización por Deciles de Ingreso Laboral") ///
        legend(order(1 "D1 (Más pobres)" 2 "D2" 3 "D9" 4 "D10 (Más ricos)" 5 "Media") rows(2)) ///
        xtitle("Año-Trimestre") ytitle("% Aportantes AFP") xlabel(180(20)260)
    graph export "$figs/Grafico_Deciles_Ingresos.png", as(png) replace
restore

**# Gráfico 2.5: Madres vs Otras mujeres
preserve
    keep if mujer == 1
    collapse (mean) afp_pct [aw=peso_anual], by(gestion madre_hogar)
    reshape wide afp_pct, i(gestion) j(madre_hogar)
    graph bar (mean) afp_pct1 afp_pct0, over(gestion, label(angle(45) labsize(small))) ///
        bar(1, color(maroon)) bar(2, color(gs10)) ///
        legend(label(1 "Mujeres: Madres Jefas/Cónyuges") label(2 "Otras mujeres") rows(2) size(small)) ///
        title("Evolución de la Formalidad Femenina", size(medium)) ///
        ytitle("% de Afiliación a la AFP") yline(0, lcolor(black)) graphregion(color(white))
    graph export "$figs/Grafico_Madres_Formalidad.png", as(png) replace
restore

**# Gráfico 2.6: Kernel Density de Ingresos (Pre vs Post)
preserve
    keep if ingreso_laboral > 0 & ingreso_laboral < 15000 
    gen ln_y = ln(ingreso_laboral)
	twoway (kdensity ln_y if reforma==0 [aw=peso_anual], lcolor(gs10) lpattern(dash)) ///
		   (kdensity ln_y if reforma==1 [aw=peso_anual], lcolor(blue)), ///
		title("Distribución del Logaritmo del Ingreso Laboral Real") ///
		legend(label(1 "Pre-2010") label(2 "Post-2010")) ///
		xtitle("Log(Ingreso Laboral Real Deflactado)") ytitle("Densidad")
    graph export "$figs/Grafico_Kernel_Ingresos.png", as(png) replace
restore

**# Gráfico 2.7: Perfil Edad-Aporte (Life-Cycle)
preserve
    collapse (mean) afp_pct [pweight=peso_anual], by(edad reforma)
    twoway (lowess afp_pct edad if reforma==0, lcolor(gs10)) ///
           (lowess afp_pct edad if reforma==1, lcolor(dknavy)), ///
        title("Ciclo de Vida del Aporte Jubilatorio") ///
        xtitle("Edad") ytitle("% Probabilidad de Aportar") ///
        legend(label(1 "Pre-Reforma") label(2 "Post-Reforma"))
    graph export "$figs/Grafico_Ciclo_Vida.png", as(png) replace
restore

**# Gráfico 2.8: Pobreza de Tiempo (Carga de Dependencia)
preserve
    gen byte dep_tramo = .
    replace dep_tramo = 1 if carga_dependencia == 0
    replace dep_tramo = 2 if carga_dependencia > 0 & carga_dependencia <= 0.5
    replace dep_tramo = 3 if carga_dependencia > 0.5 & carga_dependencia <= 1
    replace dep_tramo = 4 if carga_dependencia > 1 & carga_dependencia <= 2
    replace dep_tramo = 5 if carga_dependencia > 2 & carga_dependencia != .
    
    collapse (mean) afp_pct [aw=peso_anual], by(dep_tramo reforma)
    reshape wide afp_pct, i(dep_tramo) j(reforma)
    
    graph bar (mean) afp_pct0 afp_pct1, over(dep_tramo, relabel(1 "Cero (Sólo adultos)" 2 "Baja (<=0.5)" 3 "Media (0.5-1)" 4 "Alta (1-2)" 5 "Muy Alta (>2)")) ///
        bar(1, color(gs10)) bar(2, color(maroon)) ///
        legend(label(1 "Pre-2010") label(2 "Post-2010") rows(1)) ///
        title("Formalidad según Carga de Dependencia del Hogar") ///
        ytitle("% de Afiliación a la AFP") graphregion(color(white))
    graph export "$figs/Grafico_Carga_Dependencia.png", as(png) replace
restore

disp "=========================================================================="
disp "ANÁLISIS EXPLORATORIO DE DATOS EXTENDIDO FINALIZADO."
disp "Gráficos guardados en Outputs/Figures/"
disp "=========================================================================="
