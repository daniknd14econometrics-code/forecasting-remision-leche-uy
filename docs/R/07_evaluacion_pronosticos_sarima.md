# Script 07 — Evaluación histórica y pronóstico de la remisión mensual

## 1. Qué pregunta responde

Este script continúa el modelado cerrado en el script 06. Realiza dos ejercicios:

1. Comparar históricamente el rendimiento predictivo del **SARIMA seleccionado frente a una referencia naïve estacional**, para cada horizonte mensual de 1 a 12.
2. Reestimar el SARIMA con todos los datos disponibles y pronosticar los próximos doce meses desde el último mes observado.

La evaluación no vuelve a elegir órdenes ni busca otros modelos. El SARIMA puede superar a la referencia en unos horizontes y rendir peor en otros. Se informa lo que arrojen los errores; no se fuerza una superioridad.

El pronóstico futuro del SARIMA se prepara por decisión del proyecto. Esa decisión no equivale a afirmar de antemano que será el mejor en todos los horizontes.

## 2. Archivos y ejecución

Guardar los archivos en:

```text
R/07_evaluar_pronosticar_sarima.R
docs/R/07_evaluacion_pronosticos_sarima.md
```

Desde la raíz del proyecto, en RStudio:

```r
source("R/07_evaluar_pronosticar_sarima.R", encoding = "UTF-8")
```

`source()` define las funciones y **ejecuta el script completo**. La última línea crea el objeto `evaluacion07`. No es necesario ejecutar funciones adicionales ni cargar el script 06 en memoria.

Se necesitan estos archivos existentes:

```text
database/forecasting.sqlite
outputs/sarima_box_jenkins/09_cierre_modelado/11_objeto_bloque09.rds
```

El segundo archivo contiene la decisión cerrada del script 06. No se debe sustituir por un objeto de una versión anterior del modelado.

Paquetes utilizados: `DBI`, `RSQLite`, `forecast` y `ggplot2`. El script comprueba su disponibilidad; no instala ni actualiza paquetes. La biblioteca de R del proyecto se administra con `renv`.

## 3. Modelo y referencia

### 3.1. SARIMA heredado del cierre

La especificación seleccionada es:

\[
\operatorname{SARIMA}(2,1,1)(1,0,0)_{12},
\]

sin deriva, con once contrastes mensuales, un TC en febrero de 2006 con \(\delta=0.7\) y un AO en abril de 2004.

El objeto se estimó sobre la primera diferencia de:

\[
x_t=\log\left(\frac{Y_t}{D_t}\right),
\]

donde \(Y_t\) son litros remitidos durante el mes y \(D_t\) es su número de días. Por ello, el ajuste interno tiene órdenes `(2,0,1)(1,0,0)[12]` sobre \(\Delta x_t\). Eso conserva **d=1 en la serie original**.

Se reestiman conjuntamente los parámetros dinámicos, los coeficientes mensuales y las magnitudes de los dos efectos. Sus fechas, tipos y parámetro de decaimiento permanecen fijos.

El TC tiene perfil en log-niveles:

\[
G_t^{TC}=\begin{cases}0,&t<T,\\0.7^{t-T},&t\geq T.\end{cases}
\]

El AO es un pulso igual a uno en abril de 2004 y cero en los demás meses. En la ecuación de \(\Delta x_t\) entran las primeras diferencias de estos perfiles. No se modifican los datos observados.

Los once contrastes mensuales también conservan su ubicación original: describen la estacionalidad de **las diferencias**, no efectos mensuales que se hayan introducido directamente en niveles.

### 3.2. Única referencia: naïve estacional diario

Para horizontes de uno a doce meses, se toma el promedio diario del mismo mes del año anterior y se multiplica por los días del mes futuro:

\[
\widehat Y^{N}_{t+h\mid t}
=D_{t+h}\frac{Y_{t+h-12}}{D_{t+h-12}},\qquad h=1,\ldots,12.
\]

Por ejemplo, un febrero bisiesto no recibe automáticamente los mismos litros totales que un febrero de 28 días. Se conserva el promedio diario de referencia y se ajusta el calendario.

Esto se implementa con `forecast::snaive()` sobre la remisión diaria promedio. Sus pronósticos e intervalos se vuelven a litros mensuales multiplicando por los días futuros.

**No se incorpora otro SARIMA con SMA1 ni otra referencia adicional.**

## 4. Alcance de la evaluación histórica

Los órdenes, transformaciones y efectos del SARIMA fueron elegidos utilizando datos hasta septiembre de 2025. El backtesting vuelve a años anteriores manteniendo esa especificación.

En cada origen se estiman los coeficientes exclusivamente con las observaciones anteriores o iguales a ese origen. No se utilizan los valores futuros para calcularlos. Sin embargo, la elección previa de la especificación sigue utilizando información posterior a muchos de los orígenes históricos.

Por eso el nombre correcto es **evaluación retrospectiva condicionada a la especificación seleccionada**. Es un ejercicio útil para estudiar cómo habría pronosticado esa especificación reestimada a lo largo del tiempo. No constituye una evaluación independiente de todo el proceso que eligió el modelo.

Esta distinción también se aplica al forecasting clásico. No invalida el ejercicio acordado: delimita qué conclusión permiten sus resultados. No se pretende reproducir en cada origen el largo procedimiento de selección del script 06.

Además, se utiliza la versión actualmente almacenada de los datos. Si INALE revisó observaciones pasadas, no se reconstruye aquí la base tal como se publicaba en cada fecha histórica.

## 5. Diseño fijado antes de observar los resultados

| Elemento | Decisión |
| --- | --- |
| Variable evaluada | Litros totales mensuales observados |
| Modelo principal | SARIMA seleccionado en el cierre 09 del script 06 |
| Referencia | Naïve estacional sobre promedio diario |
| Inicio de la serie | Enero de 2002 |
| Primer entrenamiento | Enero de 2002 a diciembre de 2011: 120 observaciones en niveles |
| Primer origen | Diciembre de 2011 |
| Ventana | Expansiva: conserva el inicio y agrega un mes en cada origen |
| Frecuencia de reestimación | Mensual |
| Horizontes | Todos: 1, 2, 3, ..., 12 meses |
| Último origen | Último mes observado menos doce meses |
| Pronóstico puntual evaluado | Media predictiva en litros |
| Métrica principal | MAE |
| Complementos | RMSE, WAPE y sesgo |
| Intervalos | 80% y 95%; cobertura, amplitud y score de intervalo |
| Desglose estacional | Por mes objetivo y por cruce mes objetivo × horizonte |

Los diez años iniciales proporcionan historia suficiente para estimar los coeficientes fijos de esta arquitectura y contienen ambos eventos atípicos. Es una elección operativa del diseño, no una regla universal que imponga el teórico.

### Mismos orígenes en los doce horizontes

Cada origen debe tener **doce meses posteriores observados**. Así, todos los horizontes y ambos modelos se comparan sobre el mismo conjunto de orígenes.

Con datos hasta septiembre de 2025, el último origen es septiembre de 2024 y se obtienen 154 orígenes. Con datos hasta septiembre de 2026, el último origen es septiembre de 2025 y se obtienen 166. El script calcula el número a partir de SQLite.

Este criterio deja fuera del backtesting los orígenes más recientes que todavía no tienen doce resultados observables, aunque ya permitan evaluar algunos horizontes cortos. Se adopta para mantener un soporte común. El pronóstico futuro desde el último dato se realiza igualmente en el segundo ejercicio.

### Qué significa una fila

Un pronóstico realizado en diciembre de 2011 para enero de 2012 tiene `h=1`. El emitido desde el mismo origen para diciembre de 2012 tiene `h=12`.

Cuando se avanza al origen enero de 2012, se incorpora la observación de enero al entrenamiento y se vuelven a producir doce pronósticos. La estimación se actualiza, pero la especificación permanece fija.

## 6. Qué hace cada bloque del código

### Bloque 01 — Configuración y utilidades

`config07` reúne rutas, primer origen, horizonte, niveles de intervalo y tolerancias numéricas. Las rutas son relativas al directorio del proyecto; no hay rutas personales de Windows incrustadas.

Las funciones auxiliares construyen calendarios, días por mes, contrastes y perfiles AO/TC. Los nombres tienen prefijo `ev07_` para evitar colisiones con el script 06.

`ev07_diseno()` devuelve dos matrices equivalentes: regresores de diferencias y regresores de niveles. Comprueba que la primera diferencia de la segunda coincida con la primera.

`ev07_raices()` examina por separado las raíces del AR regular, AR estacional y MA regular. Para estos factores multiplicativos, comprobar cada uno comprueba también la admisibilidad del polinomio completo. La raíz unitaria original de d=1 no se confunde con las raíces estacionarias de la parte ARMA.

### Bloque 02 — Lectura y controles

Se lee SQLite en modo de solo lectura y se consulta `analitica_remision_mensual`, conservando la muestra desde enero de 2002 hasta el último dato disponible.

Se comprueba que las fechas sean primeros días de mes, consecutivas, sin repetidos, y que los litros sean positivos y finitos. No se imputan meses automáticamente.

Después se verifica que el segmento enero de 2002–septiembre de 2025 reproduzca la serie logarítmica guardada en el cierre. También se reproducen sus regresores. Si los datos o el objeto corresponden a otra versión, se detiene la ejecución para evitar mezclar decisiones y bases distintas.

### Bloque 03 — Reestimación por origen

Se estima el mismo ARMA sobre \(\Delta x_t\), mediante máxima verosimilitud, con los regresores correspondientes al entrenamiento.

Se utilizan varios valores iniciales para reducir la dependencia de un óptimo local. Los inicios genéricos utilizan únicamente el entrenamiento actual. Desde el segundo origen también se puede utilizar como inicio el ajuste del origen anterior, que ya pertenece al pasado.

**Nunca se utiliza el vector de coeficientes estimado hasta 2025 para inicializar los primeros orígenes históricos.**

Se registran convergencia, verosimilitud, raíces, covarianzas, avisos y errores de cada intento. Entre los ajustes convergentes y admisibles se conserva el de mayor verosimilitud.

La matriz de covarianzas de parámetros se registra como diagnóstico. Un problema en ella impide interpretar los errores estándar de coeficientes, pero no se oculta ni se confunde automáticamente con imposibilidad de obtener pronósticos con parámetros fijos.

Si ningún inicio produce un ajuste admisible, se guarda el registro y se detiene el ejercicio. No se elimina silenciosamente ese origen ni se cambia su SARIMA por otro modelo.

### Bloque 04 — Pronósticos e intervalos en litros

El ajuste heredado está en diferencias. Para pronosticar niveles logarítmicos, las medias de las diferencias se acumulan desde el último nivel observado.

La incertidumbre requiere más cuidado: **no se pueden sumar las varianzas de los pronósticos de diferencias**, porque sus errores tienen covarianzas entre horizontes.

El código representa la misma ecuación en niveles mediante `stats::arima()` con d=1 y **todos sus coeficientes fijos** a los del ajuste sobre diferencias. La varianza de innovaciones también conserva la del ajuste original. Este objeto sirve de filtro integrado para `predict.Arima()`; no estima un modelo adicional.

Los once contrastes se acumulan únicamente para obtener los regresores equivalentes en niveles. Los perfiles AO/TC ya están definidos en niveles. El código comprueba en cada origen que la media obtenida con el filtro integrado coincida, dentro de tolerancia numérica, con acumular los pronósticos de diferencias.

`predict.Arima()` calcula los errores estándar de predicción en log-niveles mediante el filtro de Kalman. Luego se realiza la transformación a litros.

Si el pronóstico de log-remisión diaria tiene media \(\mu_h\) y varianza \(v_h\), bajo la distribución predictiva normal utilizada:

\[
\operatorname{Mediana}(Y_{t+h}\mid\mathcal F_t)=D_{t+h}\exp(\mu_h),
\]

\[
\operatorname{Media}(Y_{t+h}\mid\mathcal F_t)=D_{t+h}\exp(\mu_h+v_h/2).
\]

La segunda expresión es el pronóstico puntual evaluado. Se conserva la mediana como información auxiliar, no como un tercer competidor.

El MAE y el RMSE se calculan sobre esa misma media. La media es el objetivo usual bajo pérdida cuadrática; la mediana sería óptima para pérdida absoluta bajo el modelo. Se informa esta diferencia sin cambiar el objetivo después de observar los errores.

Los límites predictivos se obtienen transformando los cuantiles normales de log-remisión diaria y multiplicando por los días del mes. No se multiplica un intervalo de diferencias para convertirlo directamente en uno de niveles.

Los intervalos del naïve proceden de `snaive()`. Si alguno tuviera límite inferior negativo, se conserva y queda visible: no se recorta de forma que altere artificialmente su cobertura.

### Bloque 05 — Bucle histórico

Para cada origen, `ev07_backtesting()`:

1. Extrae el entrenamiento desde enero de 2002 hasta ese origen.
2. Construye solamente el calendario y los días de los doce meses futuros.
3. Reestima los coeficientes del SARIMA fijo.
4. Genera los doce pronósticos del SARIMA y de la referencia.
5. Incorpora después los valores observados y calcula sus errores.
6. Guarda pronósticos, coeficientes, diagnósticos e intentos de estimación.

Separar el calendario futuro de los valores observados facilita verificar que estos últimos se usan para evaluar, no para pronosticar.

Se muestra progreso cada doce orígenes. El tiempo depende del equipo y de la optimización en cada ventana; no debe interpretarse una pausa entre mensajes como una solicitud de intervención.

Al terminar se comprueba que ambos modelos tengan exactamente doce horizontes y el mismo número de observaciones por horizonte.

### Bloque 06 — Métricas

Se define:

\[
e_{t,h}=Y_{t+h}-\widehat Y_{t+h\mid t}.
\]

Un error positivo significa que se pronosticó menos de lo observado.

| Medida | Cálculo e interpretación |
| --- | --- |
| MAE | Promedio de \(|e|\), en litros. Error absoluto típico; menor es mejor. |
| RMSE | Raíz del promedio de \(e^2\), en litros. Penaliza más los errores grandes. |
| WAPE | \(100\sum|e|/\sum|Y|\). Error absoluto como porcentaje del volumen observado. |
| Sesgo en litros | Promedio de \(e\). Positivo: subpredicción; negativo: sobrepredicción. |
| Sesgo porcentual | \(100\sum e/\sum Y\). |
| Cobertura | Porcentaje de observaciones dentro del intervalo del 80% o 95%. |
| Amplitud | Promedio de la distancia entre límites; debe leerse junto con cobertura. |
| Score de intervalo | Penaliza amplitud y observaciones fuera de los límites. Menor es mejor. |

Para un intervalo \([L,U]\) de nivel \(1-\alpha\), el score es:

\[
IS_\alpha=(U-L)+\frac{2}{\alpha}(L-Y)\mathbf1(Y<L)
                     +\frac{2}{\alpha}(Y-U)\mathbf1(Y>U).
\]

Las métricas se calculan por modelo y horizonte, sin mezclar h=1 con h=12. Se exportan además por mes del año objetivo y por mes objetivo × horizonte. Estos desgloses tienen menos casos; la columna `n` permite valorar su soporte.

La tabla comparativa utiliza:

\[
\operatorname{MejoraMAE}_h=100\left(1-\frac{MAE_h^{SARIMA}}{MAE_h^{naive}}\right).
\]

Un porcentaje positivo favorece al SARIMA; negativo favorece al naïve. Se informa también la mejora del RMSE. No se elige automáticamente un ganador global ni se cambia a otra métrica para favorecer a un modelo.

### Bloque 07 — Pronóstico desde el último dato

Este ejercicio ya no retiene doce meses para evaluar: utiliza todos los datos actuales para estimar los coeficientes y genera los siguientes doce meses de calendario.

La tabla contiene `origen`, `fecha` objetivo, `h`, modelo, media, mediana e intervalos. Los valores `observado` y `error` quedan vacíos porque esos resultados todavía no se conocen.

El SARIMA se identifica como pronóstico del modelo seleccionado; el naïve se conserva como referencia. La comparación histórica se presenta antes y permite contextualizar su rendimiento.

El modelo reestimado se diagnostica con innovaciones, FAC/FACP y Ljung–Box orientativo en 12/24/36 meses. Un problema diagnóstico queda registrado: no se resuelve aquí eligiendo automáticamente órdenes nuevos.

### Bloques 08 y 09 — Archivos, gráficos y cierre de ejecución

Se crean gráficos, tablas y objetos RDS. Cada corrida utiliza una carpeta distinta:

```text
outputs/evaluacion_predictiva/07_sarima_vs_naive/AAAAMMDD_HHMMSS_id/
```

Las corridas anteriores permanecen disponibles. Se guarda una copia de los datos utilizados, el diseño, el identificador MD5 del RDS de cierre y `sessionInfo()`.

El objeto de memoria se llama `evaluacion07`, para no sobreescribir `bloque07`, que en el script 06 corresponde a la búsqueda de outliers.

## 7. Archivos producidos

| Archivo | Contenido |
| --- | --- |
| `00_diseno_evaluacion.csv` | Decisiones, fechas, número de orígenes, versiones y huella del cierre |
| `00_alcance_y_lectura.txt` | Alcance y límites del ejercicio |
| `01_datos_utilizados.csv` | Serie efectivamente utilizada, días y transformaciones |
| `02_predicciones_backtesting.csv` | Un registro por origen, fecha objetivo, horizonte y modelo |
| `03_metricas_por_horizonte.csv` | 24 filas: dos modelos × doce horizontes |
| `04_comparacion_SARIMA_naive.csv` | Doce filas de comparación por horizonte |
| `05_metricas_por_mes_objetivo.csv` | Desglose por mes del año pronosticado, agregando horizontes |
| `06_metricas_por_mes_objetivo_y_horizonte.csv` | Desglose conjunto por mes del año y horizonte |
| `07_ajustes_por_origen.csv` | Convergencia seleccionada, raíces, covarianzas y diagnósticos |
| `08_coeficientes_por_origen.csv` | Trayectoria de los coeficientes reestimados |
| `09_intentos_estimacion_backtesting.csv` | Todos los inicios, incluidos avisos y fallos |
| `10_pronosticos_proximos_12_meses.csv` | Doce meses futuros de SARIMA y referencia |
| `11_coeficientes_ajuste_actual.csv` | Parámetros reestimados con toda la historia |
| `12_diagnostico_ajuste_actual.csv` | Diagnóstico numérico y residual del ajuste actual |
| `13_intentos_estimacion_actual.csv` | Inicios del ajuste actual |
| `14_innovaciones_ajuste_actual.csv` | Innovaciones del ajuste actual |
| `15_modelo_y_pronosticos_actuales.rds` | Modelos, datos, regresores y pronósticos actuales |
| `16_objeto_evaluacion07.rds` | Resultado completo de la corrida |
| `17_sessionInfo.txt` | Sesión y paquetes utilizados |

Gráficos:

```text
01_MAE_RMSE_por_horizonte.png
02_mejora_MAE_por_horizonte.png
03_pronosticos_proximos_12_meses.png
04_cobertura_intervalos_por_horizonte.png
05_MAE_mes_objetivo_y_horizonte.png
06_diagnostico_ajuste_actual.png
```

Los archivos que comienzan por `99_` solo aparecen ante determinados fallos y no equivalen a una evaluación terminada.

## 8. Límites de los intervalos y de la comparación

Los intervalos son condicionales a parámetros estimados y regresores conocidos. No incorporan toda la incertidumbre de selección de órdenes o de outliers, ni futuros cambios estructurales o futuras observaciones atípicas desconocidas.

La dispersión residual más alta en el tramo temprano sigue siendo una limitación relevante. Las coberturas históricas, amplitudes y scores ayudan a comprobar cómo funcionaron efectivamente las bandas; una cobertura nominal no garantiza una cobertura empírica equivalente.

Los errores de pronósticos con orígenes y horizontes próximos pueden solaparse. Por eso el script no añade pruebas de precisión ni trata los errores como observaciones independientes para construir intervalos de confianza de las métricas.

No se infiere una banda anual sumando límites mensuales. El ejercicio solicitado es mensual, con horizontes de uno a doce meses.

## 9. Qué revisar después de ejecutarlo

Primero, comprobar que aparezca el mensaje final de ejecución completa y que ambos modelos conserven el mismo número de orígenes. Después revisar:

1. La comparación de MAE y RMSE en los doce horizontes.
2. Si hay meses del año sistemáticamente más difíciles y cuántas observaciones sostienen cada resultado.
3. Sesgo, cobertura y amplitud de intervalos.
4. Diagnósticos del ajuste actual y avisos de estimación.
5. Las doce predicciones futuras, su origen y sus intervalos.

La salida no modifica el modelo cerrado en 06. Si aparecen resultados que requieran una decisión nueva, se discuten explícitamente; no se reabre automáticamente todo el modelado.

## 10. Retomar el flujo del repositorio

El orden de trabajo continúa siendo: definir → ejecutar → comprobar → documentar → registrar en Git → avanzar.

Una vez revisados los resultados en la computadora del proyecto, comprobar las dependencias en R:

```r
renv::status()
```

Si el estado es consistente, no hace falta generar otro `snapshot()` por rutina. Si informa paquetes utilizados y no registrados, revisar y actualizar el lockfile según el flujo habitual.

Los comandos de Windows y Git de esta unidad, su explicación y las verificaciones de publicación se concentran en [el registro del cierre predictivo](../git/05_evaluacion_predictiva_sincronizacion.md). El script R no los ejecuta. No se da por publicado el trabajo hasta comprobar el envío, el árbol de trabajo y la relación con `origin/main`.

Cada actualización futura de la base puede volver a ejecutar el script y conservar otra corrida. La automatización de cargas, el registro de predicciones en SQLite y la comparación operativa entre distintas corridas son etapas posteriores, no funcionalidades que se den por implementadas aquí.

## 11. Fundamento y decisiones de implementación

Los materiales del proyecto sustentan la separación entre estimación, función de pronóstico, evaluación por orígenes y reestimación operativa:

- `taller_05B_arima_sarima_flujo_completo.R`: pronóstico en distintas escalas, vuelta a litros, errores, métricas e intervalos.
- `capitulo_05_funcion_forecast_sarima.tex`: pronósticos condicionados a la información del origen y acumulación de incertidumbre.
- `capitulo_transversal_evaluacion_forecasting.tex`: orígenes, ventanas, horizontes, referencias, métricas y alcance de la evaluación.

El taller contempla procedimientos más amplios que pueden volver a identificar modelos dentro de cada origen. Aquí se conserva la especificación cerrada, por decisión explícita, y se declara el alcance condicional. Los diez años iniciales, el avance mensual y el soporte común son decisiones del diseño de este proyecto, no citas literales del material.

La representación integrada con coeficientes fijos es una adaptación algebraica para respetar que el script 06 estimó sobre diferencias. Se verifica su equivalencia numérica; no se añade un bootstrap, una prueba nueva ni otro método de selección.

Documentación oficial de las funciones utilizadas:

- [R: arima](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/arima.html).
- [R: predict.Arima](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/predict.arima.html).
- [forecast: naïve y seasonal naïve](https://pkg.robjhyndman.com/forecast/reference/naive.html).

Este Markdown describe el diseño, el código y, en la sección 13, los resultados de la ejecución local revisada. La prueba técnica previa de la sección 12 se conserva diferenciada de la ejecución efectiva del proyecto.

## 12. Verificación previa a la entrega

Se comprobó la sintaxis y se ejecutó el procedimiento completo en un entorno de prueba con R 4.3.3 y `forecast` 8.21.1. Se utilizaron los datos de desarrollo publicados hasta septiembre de 2025 y un objeto de cierre de prueba reconstruido con los coeficientes y efectos publicados. No se ejecutó sobre la computadora de Windows ni sobre su SQLite actualizado.

La ejecución completó 154 orígenes, 3.696 filas históricas —154 × 12 × 2—, las 24 filas de métricas por horizonte y los doce meses futuros de ambos modelos. También se comprobaron el calendario bisiesto, las fórmulas de métricas, la equivalencia de los pronósticos integrados y su reproducción al recargar el RDS guardado.

Esta verificación valida la ejecución del código con esa muestra. No sustituye la corrida del proyecto con sus datos actuales y las versiones de paquetes registradas en `renv.lock`, ni constituye una interpretación anticipada de sus resultados.

## 13. Ejecución local y resultados revisados — 31 de octubre de 2026

### 13.1. Evidencia de ejecución

Daniel ejecutó en RStudio:

```r
source("C:/Users/dani-/repos/forecasting-remision-leche-uy/R/07_evaluar_pronosticar_sarima.R")
```

La ejecución terminó y guardó sus resultados en:

```text
outputs/evaluacion_predictiva/07_sarima_vs_naive/20261031_171120_23228/
```

Se revisaron los CSV y gráficos entregados en `evaluacion_predictiva.zip`, además de la salida de consola. El diseño y la sesión registran R 4.6.1 y `forecast` 9.0.2. Esta es la ejecución efectiva de Windows; no debe confundirse con la prueba de la sección 12.

| Elemento comprobado | Resultado |
|---|---|
| Datos actuales | Enero de 2002–septiembre de 2026, 297 meses |
| Selección previa de especificación | Datos hasta septiembre de 2025 |
| Primer origen histórico | Diciembre de 2011 |
| Último origen histórico | Septiembre de 2025 |
| Orígenes procesados | 166, uno por mes |
| Horizontes de cada origen | Todos, de 1 a 12 |
| Modelos comparados | SARIMA seleccionado y naïve estacional diario |
| Filas históricas | 3.984 = 166 × 12 × 2 |
| Duplicados origen–objetivo–horizonte–modelo | Ninguno |
| Observaciones por modelo y horizonte | 166 |
| Pronóstico futuro | Octubre de 2026–septiembre de 2027 |

Los saltos que muestra la consola son avisos de progreso cada doce orígenes: no se omitieron los meses intermedios. Se recalculó el MAE desde los errores guardados y coincide con la tabla exportada, salvo redondeo de almacenamiento.

### 13.2. Rendimiento por horizonte

MAE y RMSE en **millones de litros**. Mejora positiva favorece al SARIMA; negativa favorece al naïve.

| h | MAE SARIMA | MAE naïve | Mejora MAE SARIMA (%) | RMSE SARIMA | RMSE naïve |
|---:|---:|---:|---:|---:|---:|
| 1 | 4,92 | 9,16 | 46,35 | 6,06 | 11,63 |
| 2 | 7,10 | 9,15 | 22,37 | 9,00 | 11,58 |
| 3 | 8,68 | 9,10 | 4,60 | 10,72 | 11,51 |
| 4 | 9,54 | 9,04 | -5,49 | 11,81 | 11,43 |
| 5 | 10,18 | 8,96 | -13,66 | 12,57 | 11,31 |
| 6 | 10,57 | 9,00 | -17,39 | 12,80 | 11,37 |
| 7 | 10,46 | 9,04 | -15,69 | 12,61 | 11,42 |
| 8 | 10,23 | 9,10 | -12,41 | 12,33 | 11,48 |
| 9 | 9,89 | 9,22 | -7,30 | 12,11 | 11,60 |
| 10 | 9,87 | 9,33 | -5,85 | 12,06 | 11,72 |
| 11 | 9,70 | 9,26 | -4,77 | 11,84 | 11,66 |
| 12 | 9,54 | 9,20 | -3,70 | 11,80 | 11,63 |

El SARIMA obtiene menores errores en horizontes 1–3; el naïve, en 4–12. La ventaja del SARIMA es considerable a uno y dos meses y pequeña a tres. La mayor desventaja en MAE aparece a seis meses, con 17,39% más error que la referencia; a doce meses es 3,70%.

El RMSE coincide en qué modelo tiene menor error en cada horizonte. Estas diferencias son resultados descriptivos del backtesting: no se añadieron pruebas de significación de precisión predictiva.

**Decisión de lectura:** conservar y comunicar el rendimiento por horizonte. No atribuir al SARIMA superioridad general sobre el naïve ni convertir después de observar la tabla una regla híbrida por horizontes en un procedimiento ya validado.

### 13.3. Diferencias por mes del año

El desglose confirma que el error depende del mes objetivo. A seis meses, por ejemplo, el SARIMA tiende a subpredecir entre mayo y agosto y a sobrepredecir en octubre y noviembre. Recordar que error positivo significa observado mayor que pronosticado.

En ese horizonte, el sesgo medio es aproximadamente +9,9 millones en mayo, +9,7 en junio, +10,9 en julio y +12,0 en agosto; en octubre es −7,5 millones y en noviembre −11,7. El promedio general puede ocultar estas diferencias porque los signos se compensan.

Cada combinación mes–horizonte tiene 13 o 14 observaciones, no 166 observaciones independientes. La tabla que agrega horizontes por mes sí acumula 166 registros por modelo y mes, pero incluye pronósticos de distintos horizontes y objetivos que se repiten. Para estudiar anticipación y estacionalidad conjuntamente corresponde consultar `06_metricas_por_mes_objetivo_y_horizonte.csv`.

No se modifica el modelo a partir de este desglose en el cierre actual. Se registra como una limitación predictiva y una pregunta para extensiones futuras.

### 13.4. Intervalos

Las bandas SARIMA del 95% contienen el 100% de los resultados históricos en horizontes 6–12. A doce meses su ancho promedio es aproximadamente **70,7 millones de litros**, frente a **53,7 millones** del naïve, cuya cobertura es 97,6%.

La cobertura elevada debe leerse junto con la amplitud: las bandas SARIMA resultaron conservadoras en esos horizontes. Su score de intervalo al 95% también es mayor —peor— que el del naïve a seis y doce meses. A un mes, el SARIMA tiene bandas mucho más estrechas y un menor score que la referencia.

Se mantiene la limitación de la dispersión temprana más alta. La evaluación no identifica por sí sola una causa única de la cobertura elevada. Tampoco se reemplazan ahora los intervalos por una calibración distinta.

### 13.5. Estimación y diagnóstico actual

Los 166 ajustes históricos elegidos presentan matrices de covarianzas válidas y raíces admisibles. Hubo avisos `Se han producido NaNs` en 24 de los 663 intentos de optimización. Cinco ajustes elegidos proceden de intentos que emitieron ese aviso; en esos mismos orígenes existen otros inicios sin el aviso con log-verosimilitudes prácticamente idénticas, con diferencias inferiores a 0,000002.

El aviso queda registrado, pero los resultados revisados no muestran un fallo numérico que exija repetir la corrida. Para el ajuste actual, los cuatro inicios convergen a verosimilitudes prácticamente iguales, sin esos avisos y con covarianzas válidas.

| Diagnóstico actual, origen septiembre de 2026 | Valor |
|---|---:|
| Observaciones en niveles | 297 |
| Desviación de innovaciones, escala log-diaria | 0,0390644 |
| Raíz AR regular mínima | 1,45722 |
| Raíz AR estacional mínima | 1,12818 |
| Raíz MA regular mínima | 1,10174 |
| Ljung–Box orientativo, 12 meses | 0,34299 |
| Ljung–Box orientativo, 24 meses | 0,19868 |
| Ljung–Box orientativo, 36 meses | 0,24155 |

No rechazar Ljung–Box no demuestra independencia ni superioridad predictiva. Los diagnósticos del ajuste y la comparación de errores cumplen funciones distintas.

### 13.6. Pronóstico futuro guardado

Origen: septiembre de 2026. Media e intervalos del SARIMA, en **millones de litros**. Los límites son predictivos al 95%, condicionales a los supuestos indicados en el documento. Los CSV conservan cifras completas y bandas del 80% y 95%.

| Mes objetivo | h | Media | Límite inferior 95% | Límite superior 95% |
|---|---:|---:|---:|---:|
| 2026-10 | 1 | 246,35 | 228,02 | 265,75 |
| 2026-11 | 2 | 226,45 | 201,90 | 253,15 |
| 2026-12 | 3 | 208,41 | 181,66 | 237,96 |
| 2027-01 | 4 | 184,63 | 158,64 | 213,65 |
| 2027-02 | 5 | 147,41 | 125,42 | 172,13 |
| 2027-03 | 6 | 160,79 | 135,81 | 189,01 |
| 2027-04 | 7 | 164,48 | 138,15 | 194,36 |
| 2027-05 | 8 | 179,74 | 150,24 | 213,31 |
| 2027-06 | 9 | 184,51 | 153,60 | 219,80 |
| 2027-07 | 10 | 198,68 | 164,78 | 237,49 |
| 2027-08 | 11 | 213,51 | 176,46 | 256,01 |
| 2027-09 | 12 | 229,92 | 189,41 | 276,51 |

Se conservan estos pronósticos del SARIMA por la decisión acordada y también los de la referencia. No se afirma que el SARIMA sea el de menor error histórico a todos esos horizontes. La llegada de observaciones nuevas permitirá contrastar estos pronósticos concretos sin sustituirlos por pronósticos reestimados posteriormente.

### 13.7. Cierre y posible extensión ARIMAX

Quedan completadas la ejecución y revisión de la evaluación histórica condicionada y la producción de doce pronósticos futuros. La selección SARIMA del script 06 permanece cerrada. Su utilidad predictiva observada se concentra en el corto plazo; el naïve conserva mejor rendimiento en horizontes 4–12 de esta evaluación.

Los resultados aportan una razón para dejar abierta una extensión con **precio de la leche al productor y precipitaciones**. No prueban que esas variables expliquen los errores ni que añadirlas vaya a mejorar el pronóstico. Un ARIMAX debe justificar disponibilidad, rezagos, cobertura y la información realmente conocida en cada origen, y compararse mediante evaluación temporal con las referencias actuales.

Las realizaciones futuras de precio y lluvia no pueden utilizarse como si se conocieran al pronosticar. Cuando sea necesario, deberán utilizarse rezagos disponibles, pronósticos de regresores o escenarios claramente identificados.

Se mantiene abierta la decisión de desarrollar esa extensión posteriormente en este mismo proyecto o en otro que trabaje esta serie desde el inicio con ARIMAX. No se incorpora ahora al código ni se convierte en requisito para cerrar esta etapa SARIMA.

La publicación de esta unidad y su comprobación se documentan en [el registro de Git](../git/05_evaluacion_predictiva_sincronizacion.md). Crear este Markdown no equivale a haber realizado el commit o sincronizado el repositorio. Después de comprobar esa publicación se revisará el estado global y las tareas de actualización, persistencia operativa y automatización que siguen pendientes.
