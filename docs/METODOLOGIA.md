# Metodología de modelización y evaluación

## Objetivo y representación

Se pronostica la remisión nacional mensual de leche a planta en Uruguay, expresada en litros. Se busca una trayectoria de doce meses, con incertidumbre y comparación frente a una referencia estacional.

Para separar duración del mes y nivel de remisión se modela:

\[
x_t=\log(Y_t/D_t),
\]

donde \(Y_t\) son litros mensuales y \(D_t\), días del mes. Sigue existiendo una observación mensual. La transformación no elimina por sí sola la estacionalidad.

El desarrollo del script 06 utiliza enero de 2002–septiembre de 2025: 285 niveles y 284 primeras diferencias. La evaluación archivada del 07 utiliza observados hasta septiembre de 2026.

## Identificación y selección Box–Jenkins

El desarrollo incluye exploración gráfica, revisión de integración regular y estacional, FAC/FACP, estimación de candidatos parsimoniosos y diagnóstico residual. Se utilizan HEGY, ADF y KPSS como evidencia junto con las demás propiedades de la serie; la representación de trabajo final es **d=1, D=0**.

Se contrastan componentes regulares y anuales y se revisan ampliaciones de órdenes cuando la dependencia residual lo justifica. La comparación considera AICc/BIC bajo bases compatibles, convergencia, precisión, raíces de los polinomios completos, factores casi comunes, FAC/FACP y Ljung–Box. El menor criterio de información no determina por sí solo la decisión.

Una referencia automática libre y otra condicionada al mismo tratamiento de integración y regresores complementan el análisis manual. La segunda no constituye una nueva elección de diferenciación. La selección final conserva un principal y un contraste prácticamente empatados; no se traduce ese empate en una afirmación de precisión predictiva.

## Especificación final

**SARIMA(2,1,1)(1,0,0)[12]**, sin deriva, con once contrastes mensuales en diferencias, un efecto transitorio TC en febrero de 2006 con decaimiento 0,7 y un efecto aditivo AO en abril de 2004.

La representación ajustada es:

\[
\Delta x_t=\beta'M_t+\omega_{TC}\Delta TC_t+\omega_{AO}\Delta AO_t+u_t,
\]

\[
(1-\phi_1L-\phi_2L^2)(1-\Phi L^{12})u_t=(1+\theta_1L)e_t.
\]

Los perfiles TC y AO se definen en niveles y se diferencian antes de incorporarlos. Los contrastes mensuales describen la estacionalidad de las diferencias. En R se estima un ARMA con d=D=0 sobre esa variable ya diferenciada; volver a aplicar d=1 implicaría diferenciar dos veces.

Los efectos se detectan mediante un recorrido secuencial y se reestiman conjuntamente con la dinámica. No se sustituyen ni eliminan las observaciones originales. Tras incorporar los efectos se revisan de nuevo los órdenes. El contraste final sustituye SAR1 por SMA1 y permanece en el registro del desarrollo, pero no se incluye en la evaluación predictiva del 07.

## Cambio de trayectoria y diagnóstico

Se realizó una búsqueda de cambio determinístico de trayectoria y un SupF convencional. Dada la representación I(1), se añadió una calibración bootstrap aproximada y condicional: SupF observado 73,7206, crítico al 5% 121,832 y p bootstrap 0,164, con 999 réplicas. La decisión fue continuar sin incorporar ese quiebre.

Ese resultado no demuestra ausencia de cualquier cambio estructural, no decide el orden de integración ni acredita estabilidad de varianza o parámetros. El alcance del simulador y de la calibración es condicional.

En el ajuste de desarrollo principal, Ljung–Box no rechazó en los rezagos diagnósticos 12, 24 y 36. Se examinaron asimismo raíces, dispersión por tramos y distribución residual. Los candidatos con mejores criterios de información y factores casi comunes no se adoptaron solo por su ajuste. Persisten mayor dispersión temprana y limitaciones de inferencia posteriores a la selección.

El cierre reproducible se conserva en [el objeto y las tablas del bloque 09](../outputs/sarima_box_jenkins/09_cierre_modelado/).

## Referencia estacional

Se utiliza el promedio diario del mismo mes del año anterior, multiplicado por los días del mes objetivo:

\[
\widehat Y^{N}_{t+h\mid t}=D_{t+h}\frac{Y_{t+h-12}}{D_{t+h-12}},\qquad h=1,\ldots,12.
\]

Se implementa con `forecast::snaive()` sobre el promedio diario. La reconversión respeta, por ejemplo, la distinta duración de febrero bisiesto.

## Evaluación temporal

El script 07 aplica una ventana expansiva con entrenamiento inicial enero de 2002–diciembre de 2011. Reestima coeficientes en 166 orígenes, de diciembre de 2011 a septiembre de 2025, y calcula doce horizontes por origen con observados hasta septiembre de 2026. Se utilizan los mismos orígenes y casos en ambos modelos: **3.984 predicciones históricas**.

La métrica principal fijada es MAE; RMSE es complementaria. Se evalúa la media predictiva en litros. La reversión del logaritmo utiliza la corrección lognormal \(D_{t+h}\exp(\mu_h+v_h/2)\); la mediana es \(D_{t+h}\exp(\mu_h)\). Se conserva la incertidumbre integrada y se verifican la acumulación y reconversión.

También se calculan sesgo, cobertura, ancho y puntuaciones de intervalos, además de desgloses por horizonte y mes objetivo. Los resultados se presentan en [Resultados](RESULTADOS.md).

### Alcance de la evidencia

La especificación y las fechas/tipos de efectos se eligieron con información hasta septiembre de 2025, posterior a muchos orígenes históricos del backtesting. Aunque los coeficientes se reestiman en cada origen, **la selección no se repite ni queda anidada dentro de cada entrenamiento**. Por ello se trata de una evaluación histórica condicionada a una especificación seleccionada, no de una prueba independiente de todo el procedimiento de selección.

Se utiliza la versión archivada de las observaciones, sin reconstruir las publicaciones que estaban disponibles en cada fecha. Los intervalos son condicionales a la especificación y no incorporan toda la incertidumbre de selección. Los errores de horizontes solapados no son observaciones independientes. No se han añadido pruebas formales de igualdad de precisión ni intervalos para totales anuales.

## Operación posterior

Los scripts 10/11 mantienen la transformación, los órdenes y los efectos del cierre. Con meses nuevos o revisiones de litros reestiman sus coeficientes con toda la historia desde enero de 2002 y emiten doce meses completos. Se conserva el naïve y se registra cada emisión.

El seguimiento posterior utiliza pronósticos efectivamente archivados y observados vigentes. Se distingue del backtesting del 07. No hay reselección anual ni sustitución automática del SARIMA; ambas quedan planteadas en [Mejoras futuras](MEJORAS_FUTURAS.md).
