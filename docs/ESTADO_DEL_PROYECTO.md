# Estado del proyecto

Última actualización: 1 de noviembre de 2026.

## Situación actual

El flujo de datos, SQL/SQLite, SARIMA, evaluación histórica, pronósticos a doce meses y ciclo local está implementado. GitHub Actions y Pages se comprobaron en dos ejecuciones manuales: la primera creó el estado operativo y la segunda lo recuperó sin inicializar ni duplicar emisiones. Daniel abrió los reportes públicos y aportó capturas.

La secuencia de publicaciones es: cierre de modelado `d6af68f`; evaluación y pronósticos `e98ed61`; corrección documental `dfbbd31`; persistencia 08/09 `38b950d`; ciclo local 10 y reportes `f667dfc`; automatización 11/Actions `a3c6a4c`; corrección de las descargas de Ubuntu `bb559f0`. Daniel confirmó push correcto, árbol limpio y `0 0` para `bb559f0`. Esta documentación de cierre todavía debe incorporarse a su propio commit.

Estado real verificado: 297 meses hasta septiembre de 2026, una emisión (`20261031_171120_23228`) y 24 pronósticos. No hubo nuevos meses ni revisiones de litros durante las dos consultas remotas. El primer disparo programado y la primera actualización remota con datos nuevos reales aún no se observaron.

## Objetivo y alcance vigentes

Construir un flujo reproducible de pronósticos mensuales de remisión nacional de leche a planta, con datos públicos del INALE, R, SQL/SQLite y Git/GitHub. El proyecto completo deberá evaluar el rendimiento predictivo, producir y almacenar nuevas predicciones, actualizarse con datos incorporados y ejecutar el recorrido mediante GitHub Actions.

Se mantiene el alcance inicial SARIMA frente al naïve estacional. ARIMAX con precio al productor y precipitaciones queda como extensión posible, en este repositorio o en otro, sin decidir ahora su ubicación ni presumir mejora predictiva. No es un requisito para cerrar esta primera aplicación. Machine learning y otras aplicaciones no se incorporan por defecto. No se utilizan bases internas de Conaprole en el repositorio público.

## Trabajo completado y evidencia

| Unidad | Estado y evidencia |
|---|---|
| Repositorio | Proyecto RStudio, Git local y remoto público configurados. |
| Datos | Scripts de descarga e inspección; originales INALE fechados y conservados. |
| SQLite y SQL | Scripts de carga y construcción de la tabla analítica ejecutados localmente; documentación disponible. |
| Exploración | Series en litros mensuales, promedio diario y logaritmos; controles y gráficos guardados. |
| Integración | HEGY y revisión ADF/KPSS con meses; decisiones de trabajo d=1, D=0. |
| Identificación y candidatos | Primeras referencias, revisión residual y ampliación de órdenes regulares y anuales. |
| Base previa a efectos | ARMA21+SAR1 elegida explícitamente al final del bloque interno 05. |
| Cambio de trayectoria | Búsqueda descriptiva y SupF convencional, seguidos de calibración I(1) aproximada autorizada; sin quiebre incorporado. |
| Outliers | Búsqueda con la base de 05 y reestimación conjunta; TC febrero 2006 y AO abril 2004. |
| Revisión final | Dieciocho candidatos estimados con los mismos efectos; auditor automático condicionado. |
| Cierre | Bloque 09 ejecutado y objeto final guardado. |
| Documentación del 06 | Tres documentos completos, separados por etapas. |
| Entorno | `renv::snapshot()` actualizado y `renv::status()` sin inconsistencias. |
| Publicación del modelado | Commit `d6af68f` recibido por GitHub; script y salidas comprobados. |
| Evaluación del 07 | 166 orígenes mensuales, ventana expansiva y todos los horizontes 1–12 frente al naïve estacional. |
| Integridad de resultados | 3.984 pronósticos históricos; sin claves duplicadas; MAE reproducido desde los errores. |
| Rendimiento por horizonte | Menor MAE/RMSE del SARIMA a 1–3 meses; del naïve a 4–12 meses. |
| Pronóstico actual | Origen septiembre de 2026; doce meses hasta septiembre de 2027, con intervalos. |
| Persistencia actual | CSV/RDS y gráficos en una carpeta por corrida; no se sobrescriben ejecuciones anteriores. |
| Publicación de evaluación | Commit `e98ed61` recibido y comprobado; sincronización local/remota confirmada. |
| Corrección documental | Commit `dfbbd31` enviado; árbol limpio y sincronización local/remota confirmados por la salida aportada. |
| Preparación de persistencia | Script 08 ejecutado: tablas `forecast_ejecuciones` y `forecast_pronosticos`, inicialmente vacías. |
| Carga inicial de pronósticos | Script 09 ejecutado: una ejecución, 24 filas; doce SARIMA y doce naïve, de octubre de 2026 a septiembre de 2027. |
| Repetición de la carga | Segundo `source()` del 09: `Ya registrada; sin cambios ni duplicados`; totales 1/24 y datos observados conservados. |
| Publicación de persistencia | Commit `38b950d` enviado y verificado en GitHub; árbol local limpio y sincronización confirmada. |
| Ciclo local 10 | Descarga/comprobación real ejecutada en Windows: 297 meses, sin meses nuevos ni revisiones, emisión inicial reconocida y totales 1/24 conservados. |
| Nuevos meses y revisiones | Ensayos en base temporal con un mes ficticio, revisión histórica, repetición sin duplicados y reversión integral ante error. |
| Seguimiento inicial | Consulta de errores emitido–observado implementada; cero errores disponibles en la comprobación real actual. |
| Reporte completo del 10 | Versión ejecutada en Windows: doce filas SARIMA de octubre de 2026 a septiembre de 2027, reales/diferencias pendientes, HTML/CSV e índice por emisión generados; totales 1/24 conservados. |

Los comandos e interpretación se conservan en [el cierre del modelado](git/04_cierre_sarima_sincronizacion.md), [el cierre predictivo](git/05_evaluacion_predictiva_sincronizacion.md), [el registro de persistencia](git/06_persistencia_pronosticos_sincronizacion.md) y [el registro del ciclo local](git/07_actualizacion_local_sincronizacion.md). El ciclo local se publicó después en `f667dfc`; la evidencia de la automatización se conserva en [Git 08](git/08_automatizacion_sincronizacion.md). No hay que repetir estimaciones ni movimientos de resultados anteriores para actualizar documentación.

## Decisiones de modelado cerradas

- Muestra de desarrollo: enero de 2002 a septiembre de 2025, 285 observaciones mensuales en niveles y 284 primeras diferencias.
- Variable transformada: `log(remision_litros / dias_mes)`. El objetivo operativo seguirá expresándose en litros mensuales.
- Diferenciación original: d=1, D=0. El ARMA interno se estima sobre la primera diferencia, con d=D=0 en esa variable ya transformada.
- Sin deriva; once contrastes mensuales en la diferencia.
- Modelo principal: **SARIMA(2,1,1)(1,0,0)[12]**.
- Contraste: **SARIMA(2,1,1)(0,0,1)[12]**, prácticamente empatado y seleccionado por el auditor automático condicionado.
- Efectos: TC en febrero de 2006, con delta=0.7, y AO en abril de 2004. No se sustituyen los datos observados.
- TC mayo de 2003 no incorporado: la firma no superó C=3.5 al finalizar el ciclo con el modelo actual.
- No se recortó la muestra ni se incorporó un cambio determinístico de nivel o pendiente.

La elección queda fijada, con su justificación y limitaciones. El contraste SMA1 pertenece al registro de selección del 06; no participó en la comparación predictiva del 07. No se vuelve a abrir la búsqueda de órdenes por incorporar estos documentos.

## Resultados de referencia del cierre

| Ajuste | AICc | BIC | Ljung–Box 12 / 24 / 36 |
|---|---:|---:|---|
| ARMA21+SAR1, principal | −991.986 | −928.886 | 0.413 / 0.246 / 0.385 |
| ARMA21+SMA1, contraste y auditor condicionado | −992.051 | −928.951 | 0.334 / 0.210 / 0.315 |

La diferencia AICc aproximada de 0.065 no se interpreta como superioridad predictiva. Las alternativas ARMA22 con mejores IC presentaron factores casi comunes y raíces muy próximas al círculo unitario; conservaron rechazo en Ljung–Box a 12 meses y no se eligieron como principal.

En cambio estructural, el SupF convencional fue 73.7206, con p convencional aproximadamente 2.896e−15. Bajo el simulador I(1) estimado de 06C, el p bootstrap fue 0.164 y el crítico al 5% aproximadamente 121.832, con 999 réplicas. La decisión operativa fue no incorporar un quiebre de trayectoria; no equivale a demostrar estabilidad ni a decidir el orden de integración. La calibración se conserva con su alcance condicional y aproximado.

Los números anteriores describen ajuste y diagnóstico dentro del desarrollo. No son métricas de error predictivo fuera de muestra.

## Evaluación predictiva completada

La corrida `20261031_171120_23228` utiliza datos de enero de 2002 a septiembre de 2026: 297 meses. El entrenamiento inicial termina en diciembre de 2011. Los 166 orígenes llegan hasta septiembre de 2025 para disponer de doce observaciones futuras en cada uno. Se mantienen los mismos orígenes en ambos modelos y en todos los horizontes.

Se reestiman coeficientes, conservando órdenes, transformación y fechas/tipos de efectos seleccionados con información hasta septiembre de 2025. Es una evaluación retrospectiva condicionada a esa especificación, no una validación independiente de toda la selección. No se recrean las versiones de datos publicadas en cada fecha histórica.

| h | MAE SARIMA, millones de litros | MAE naïve, millones de litros |
|---:|---:|---:|
| 1 | 4,92 | 9,16 |
| 2 | 7,10 | 9,15 |
| 3 | 8,68 | 9,10 |
| 4 | 9,54 | 9,04 |
| 5 | 10,18 | 8,96 |
| 6 | 10,57 | 9,00 |
| 7 | 10,46 | 9,04 |
| 8 | 10,23 | 9,10 |
| 9 | 9,89 | 9,22 |
| 10 | 9,87 | 9,33 |
| 11 | 9,70 | 9,26 |
| 12 | 9,54 | 9,20 |

El SARIMA reduce MAE en 46,35% a un mes, 22,37% a dos y 4,60% a tres. El naïve obtiene menor MAE y RMSE en 4–12. La mayor desventaja SARIMA en MAE aparece a seis meses: 17,39%; a doce es 3,70%. No se impone un ganador global ni se da por validada una regla que cambie de modelo por horizonte después de observar esta tabla.

El desglose mensual muestra sesgos que se compensan en el promedio general. Los intervalos SARIMA del 95% cubren el 100% de los resultados a horizontes 6–12 y son amplios. Cada combinación mes–horizonte tiene 13 o 14 observaciones. Estos resultados se describen en [el Markdown del 07](R/07_evaluacion_pronosticos_sarima.md), sección 13.

El ajuste actual con 297 meses presenta raíces admisibles, covarianzas válidas y Ljung–Box orientativo 0,343 / 0,199 / 0,242 en 12/24/36. Los avisos de algunos intentos históricos se revisaron frente a otros inicios convergentes. No se detectó un fallo que exigiera repetir la corrida.

Por decisión del proyecto se guardaron los doce pronósticos SARIMA de octubre de 2026 a septiembre de 2027 y la referencia. La elección para este ejercicio no se presenta como superioridad histórica general.

## Artefactos para continuar

El directorio de cierre es:

```text
outputs/sarima_box_jenkins/09_cierre_modelado/
```

Contiene decisión, comparación, coeficientes, efectos, innovaciones, regresores, resultado estructural, diagnóstico, límites e información de sesión. El objeto de continuidad es:

```text
11_objeto_bloque09.rds
```

Se puede recuperar sin volver a ejecutar los bloques de estimación:

```r
cierre <- readRDS(
  "outputs/sarima_box_jenkins/09_cierre_modelado/11_objeto_bloque09.rds"
)
cierre$decision
cierre$principal$diagnostico
```

La base SQLite es un resultado generado localmente y está excluida de Git. Los scripts y sus documentos permiten reconstruirla. Las salidas antiguas del flujo `sarima_base` y backtesting quedaron conservadas fuera del repositorio, en la carpeta local vecina `forecasting-remision-leche-uy_resultados_anteriores`; no se confunden con las actuales ni se consideran una copia remota publicada.

Los artefactos de evaluación y pronóstico actuales están en:

```text
outputs/evaluacion_predictiva/07_sarima_vs_naive/20261031_171120_23228/
```

Entradas de continuidad principales:

- `10_pronosticos_proximos_12_meses.csv`: predicciones emitidas desde septiembre de 2026, con origen, objetivo, horizonte, modelo e intervalos.
- `15_modelo_y_pronosticos_actuales.rds`: modelos, datos, regresores y pronósticos actuales.
- `16_objeto_evaluacion07.rds`: evaluación histórica y resultados de la corrida.
- `00_diseno_evaluacion.csv` y `17_sessionInfo.txt`: diseño, huella del cierre y versiones.

Estos archivos ya almacenan resultados y la corrida futura también quedó registrada en SQLite mediante el 09. El 10 ya conecta la comprobación de información, estimación condicional, generación y registro. En la ejecución real no correspondió emitir otra vez: los datos seguían iguales y las tablas conservaron una ejecución y 24 pronósticos.

Las dos salidas locales del 09 conservaron 297 meses, del 2002-01-01 al 2026-09-01, con suma de 44.046.232.078 litros. La segunda ejecución reconoció la carga previa. El procedimiento, la estructura de tablas y las comprobaciones están explicados en [persistencia de pronósticos](sql/02_persistencia_pronosticos.md).

La ejecución local del 10 quedó registrada en:

```text
outputs/operacion_mensual/op10_20261031_192032004458Z_23228/
```

Informó cero meses nuevos, cero revisiones de litros, ninguna reestimación, actualización analítica `FALSE` y cero errores todavía observables. La documentación del [script 10](R/10_actualizacion_pronosticos.md) distingue esta evidencia real de las pruebas con datos ficticios hechas en una base temporal separada.

La mejora de reportes también se ejecutó en Windows y produjo otro control:

```text
outputs/operacion_mensual/op10_20261031_195334646465Z_23228/
```

La salida mostró las doce fechas objetivo del SARIMA con reales/diferencias `NA` y estado `Pendiente`, e informó `outputs/reportes/pronostico_actual.html` y `outputs/reportes/index.html`. El reporte actual también tiene CSV y cada emisión conserva su reporte de doce meses, cuyo seguimiento se actualiza cuando llegan observados. Se mantuvieron los 297 meses y una ejecución con 24 pronósticos, sin reestimar ni actualizar los datos. No se interpretan valores ausentes como errores cero. La unidad y sus reportes se publicaron después en `f667dfc`; el estado operativo remoto conservó esos mismos pronósticos en las consultas verificadas.

## Límites que permanecen explícitos

1. No rechazar Ljung–Box no demuestra independencia ni homocedasticidad; la mayor dispersión temprana permanece documentada.
2. Los errores estándar e intervalos de coeficientes son condicionales y aproximados después de seleccionar órdenes y efectos.
3. No rechazar el contraste estructural calibrado no prueba ausencia de cambios de cualquier tipo.
4. La ventaja predictiva observada es por horizonte; no existe evidencia de superioridad general sobre el naïve. La evaluación está condicionada a una especificación elegida con parte de la información posterior a sus orígenes históricos.
5. El script 06 conserva el diseño de desarrollo. La actualización automática usa 10/11 y mantiene esa especificación; no reselecciona órdenes ni efectos en cada consulta.

## Trabajo pendiente del proyecto global

| Tarea | Situación |
|---|---|
| Publicar este cierre documental | Cinco documentos actualizados y preparados; commit/push aún no ejecutados. |
| Primer disparo del calendario | Mensual, día 1 a las 09:17 de Madrid; pendiente de observación. Las dos pruebas realizadas fueron manuales. |
| Primer nuevo mes o revisión real en Actions | No apareció durante las consultas verificadas. Las ramas de actualización se probaron con datos simulados en un entorno separado. |
| Acumular errores de pronóstico reales | MAE/RMSE y cantidades por modelo/horizonte implementados y publicados; valores pendientes hasta que existan observados. |

Persistencia, arranque, recuperación, ausencia de duplicados y publicación están comprobados. La vigilancia del calendario y la llegada de datos son seguimiento operativo, no tareas adicionales de modelado.

## Base metodológica de la evaluación realizada

Se utilizaron los materiales aportados por el usuario, adaptados a esta serie nacional:

| Material | Responsabilidad |
|---|---|
| Taller 05B, ARIMA/SARIMA de flujo completo | Implementación de pseudo-orígenes, benchmarks, métricas, retransformación y evaluación de incertidumbre. |
| Capítulo de función de forecasting | Interpretación de la trayectoria condicional, componentes permanentes/transitorios e incertidumbre según el horizonte. No reemplaza la comparación fuera de muestra. |
| Capítulo transversal de evaluación | Cronología, conjunto de información, separación de selección/evaluación/operación, métricas por horizonte e intervalos. |

Se trasladó la lógica, no las fechas del taller, sus coeficientes, el ganador, una ventana de 84 meses o ponderaciones particulares. La configuración específica y su alcance están documentados en el 07.

Se acordó evaluar la especificación fijada, reestimando sus coeficientes en cada origen. No se repite la búsqueda de órdenes, quiebres u outliers. Esta decisión y su limitación retrospectiva quedaron explícitas antes de ejecutar la evaluación. No se denomina test intacto al conjunto histórico utilizado.

Se verificaron acumulación de diferencias, varianza predictiva integrada y vuelta a litros: la media es días × exp(mu + varianza/2), mientras la mediana es días × exp(mu). No se añadieron contrastes de precisión ni bandas para totales anuales.

## Operación definida y continuidad

El esquema inicial quedó concretado en 08/09 y el 10 ya lo conecta con la comprobación de datos nuevos o revisados y nuevas emisiones. Una emisión equivalente requiere la misma historia, cierre y registro completo. Si cambia la historia de litros se prepara otra emisión, incluso desde el mismo último mes; se conserva la anterior. La regla operativa mantiene SARIMA y referencia; no existe una regla híbrida o sustitución automática acordada.

Cada nueva emisión utilizará toda la historia desde enero de 2002 hasta el último mes observado, reestimará los coeficientes de la misma especificación seleccionada y generará doce meses completos. No se repetirá mensualmente todo el análisis del 06 ni el backtesting completo del 07. La revisión periódica de la especificación se documentará aparte; no se implementó una reselección automática.

El 10 es el punto de entrada operativo local; no repite 06/07. Reutiliza las transformaciones SQL existentes dentro de una transacción junto con el registro de una nueva emisión. Guarda por separado las comparaciones con observados vigentes. La tabla analítica representa la versión actual, mientras que originales y datos de cada corrida preservan su información de origen. El workflow de GitHub Actions ya ejecuta el 11, conserva SQLite y los artefactos en `operacion` y publica los reportes mediante Pages. La base local sigue excluida de `main`; no se confunde esa exclusión con la persistencia explícita de la rama operativa. Las dos ejecuciones manuales verificaron arranque y recuperación sin duplicados.

La ampliación ARIMAX con precio y lluvia es una línea posterior. Necesitará datos alineados y una definición de qué regresores se conocen al origen o cómo se pronostican. El rendimiento actual motiva investigarla, pero no demuestra que vaya a mejorar. No se incorpora a las tareas obligatorias inmediatas.

## Revisión documental del cierre

La inspección de `e98ed61` detectó que el README correspondía por error a otro proyecto de fuentes de PTF; se corrigió en `dfbbd31`. La persistencia se publicó en `38b950d`, el ciclo 10 en `f667dfc` y la automatización en `a3c6a4c`. La corrección del bloqueo de descargas de Ubuntu se publicó en `bb559f0`.

Esta entrega actualiza README, estado y las guías de R 11, GitHub Actions y Git 08 con la evidencia real. El YAML completo de la guía refleja los 131 renglones del workflow corregido. No cambia código estadístico ni resultados del 06/07.

## Evidencia de Actions y publicación

Verificación del 1 de noviembre de 2026, con código `bb559f0`:

| Ejecución de Actions | Resultado | Evidencia |
|---|---|---|
| [41257750531](https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy/actions/runs/41257750531) | Cancelada a los 45 minutos | Bloqueo en `apt-get update`, durante la preparación de R; no ejecutó el ciclo R ni escribió estado remoto. |
| [41262543730](https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy/actions/runs/41262543730) | `actualizar` y `publicar` correctos | Inicialización explícita desde los archivos publicados; 297 meses, una emisión y 24 pronósticos; sin novedades de INALE. |
| [41262927931](https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy/actions/runs/41262927931) | `actualizar` y `publicar` correctos | `FORECAST_INICIALIZAR=false`; recuperó `operacion`, conservó la misma emisión y 24 pronósticos, sin reestimar ni duplicar. |

La primera ejecución correcta guardó `operacion` en `a4327b1`; la segunda avanzó a `6ea765f`. Su control quedó en `ultima_comprobacion.csv`, a las 01:54:38 UTC del 1 de noviembre de 2026 (02:54:38 en Madrid): origen septiembre de 2026, 297 meses, emisión `20261031_171120_23228`, cero meses nuevos, cero revisiones y cero errores evaluables. Son consultas reales a INALE; no se añadieron meses simulados al estado publicado.

Daniel abrió el reporte público, el historial y las métricas y aportó capturas. Los reales y las diferencias continúan pendientes porque no se dispone de observados para octubre de 2026 en adelante. MAE y RMSE pendientes no equivalen a errores cero.

El calendario mensual está configurado para el día 1 a las 09:17, zona `Europe/Madrid`. Estas comprobaciones fueron manuales: el primer disparo programado y la primera actualización con nuevos datos reales permanecen pendientes de observación.

## Forma de trabajo que se conserva

**Definir → ejecutar → comprobar → documentar → guardar y sincronizar → continuar.**

- Unidades de trabajo acotadas y revisables; no acumular toda la documentación para el final.
- Código estadístico y explicación en `R/` y `docs/R/`.
- Consultas y documentación SQL en `sql/` y `docs/sql/`.
- Comandos de Windows/Git relacionados con el versionado en `docs/git/`, agrupados por unidad.
- Daniel ejecuta y aprende los pasos de Git, SQL y GitHub con acompañamiento.
- Cada publicación se comprueba; no se afirma que esté sincronizada solo porque los archivos fueron creados.

## Siguiente paso exacto

Reemplazar los cinco documentos del ZIP de cierre en sus rutas y revisar `git status` y `git diff`. Publicar únicamente esa documentación después del punto de control guiado. No hace falta volver a ejecutar R ni otra prueba manual de Actions para este cambio documental. El primer disparo programado y el primer observado nuevo real se documentarán cuando ocurran.
