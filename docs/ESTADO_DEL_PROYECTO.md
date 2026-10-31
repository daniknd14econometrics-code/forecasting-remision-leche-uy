# Estado del proyecto

Última actualización: 31 de octubre de 2026.

## Situación actual

La obtención y preparación de los datos, su carga y consulta mediante SQLite/SQL, la selección SARIMA y la evaluación histórica del modelo están implementadas y ejecutadas. El script 06 cerró la selección; el 07 comparó el modelo con el naïve estacional y produjo los siguientes doce pronósticos con intervalos. Queda por completar la integración operativa de actualizaciones, seguimiento de errores y GitHub Actions.

El cierre de modelado se publicó en `d6af68f`. La evaluación, pronósticos y documentación se publicaron después en **`e98ed61`** (`Document SARIMA evaluation and publish monthly forecasts`), con 32 archivos cambiados. Daniel comprobó `renv::status()` consistente, envío correcto, árbol limpio y `0 0` después de `git fetch origin`.

También se verificó en GitHub que `main` apunta a `e98ed61edea7f7ee3bffbbb11b12378276e57da6` y contiene los scripts 01–07 y las salidas de la corrida revisada. Esta revisión de README, estado y registro Git es posterior a ese commit; su publicación documental sigue su propio paso de comprobación.

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

Los comandos e interpretación se conservan en [el cierre del modelado](git/04_cierre_sarima_sincronizacion.md) y [el cierre predictivo](git/05_evaluacion_predictiva_sincronizacion.md). No hay que repetir las estimaciones ni los movimientos de resultados anteriores para actualizar documentación.

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

Estos archivos ya almacenan resultados. Lo pendiente no es generar por primera vez pronósticos ni guardarlos en disco, sino integrar su historial y seguimiento mediante SQL y el proceso de actualización.

## Límites que permanecen explícitos

1. No rechazar Ljung–Box no demuestra independencia ni homocedasticidad; la mayor dispersión temprana permanece documentada.
2. Los errores estándar e intervalos de coeficientes son condicionales y aproximados después de seleccionar órdenes y efectos.
3. No rechazar el contraste estructural calibrado no prueba ausencia de cambios de cualquier tipo.
4. La ventaja predictiva observada es por horizonte; no existe evidencia de superioridad general sobre el naïve. La evaluación está condicionada a una especificación elegida con parte de la información posterior a sus orígenes históricos.
5. El script 06 tiene un calendario y una arquitectura fijados para este estudio. Todavía no es el procedimiento automático de actualización con nuevas observaciones.

## Trabajo pendiente del proyecto global

| Orden | Tarea | Situación |
|---|---|---|
| 1 | Registrar corridas y pronósticos mediante SQL/SQLite | Diseñar claves, escritura transaccional y repetición sin duplicados; conservar los archivos ya publicados. |
| 2 | Contrastar pronósticos emitidos con datos nuevos | Vincular por fecha objetivo y mantener el origen; medir errores sin sustituir la predicción anterior. |
| 3 | Integrar actualización y reestimación | Un punto de entrada para descarga/carga, controles, registro, pronósticos y metadatos; sin repetir automáticamente la selección del 06. |
| 4 | Comprobar un segundo ciclo operativo | Ensayo controlado de llegada de datos y segunda ejecución sin duplicados. Tener 297 meses en el 07 no demuestra todavía este ciclo completo. |
| 5 | Definir persistencia y ejecutar GitHub Actions | Resolver qué se conserva entre ejecutores temporales y verificar una ejecución real. |
| 6 | Completar presentación y reproducción final | README y estado coherentes, instrucciones de ejecución y evidencia de actualización operativa/Actions. |

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

## Decisiones que faltan para la operación

Antes de escribir el siguiente módulo se concretará un esquema sencillo de corridas y pronósticos en SQLite, qué identifica una repetición de la misma ejecución y cómo se registran observaciones nuevas o revisadas. La regla operativa debe dejar explícito que el ejercicio actual conserva SARIMA y referencia; no existe una regla híbrida o una sustitución automática ya acordada.

El 07 ya conserva resultados por corrida, pero no escribe en SQLite ni compara automáticamente los nuevos datos con pronósticos previamente emitidos. El 03 reconstruye staging y el SQL actual reconstruye la tabla analítica; no constituyen un historial de publicaciones de la fuente. No hay un script de entrada único ni archivos de workflow en el árbol del commit revisado.

La ampliación ARIMAX con precio y lluvia es una línea posterior. Necesitará datos alineados y una definición de qué regresores se conocen al origen o cómo se pronostican. El rendimiento actual motiva investigarla, pero no demuestra que vaya a mejorar. No se incorpora a las tareas obligatorias inmediatas.

## Revisión documental del cierre

La inspección de `e98ed61` detectó que el README publicado correspondía por error a otro proyecto de fuentes de PTF. Se prepara su sustitución por el README de forecasting actualizado, junto con este estado y la evidencia de Git. Esta corrección no altera código estadístico, resultados ni la decisión de modelado.

## Forma de trabajo que se conserva

**Definir → ejecutar → comprobar → documentar → guardar y sincronizar → continuar.**

- Unidades de trabajo acotadas y revisables; no acumular toda la documentación para el final.
- Código estadístico y explicación en `R/` y `docs/R/`.
- Consultas y documentación SQL en `sql/` y `docs/sql/`.
- Comandos de Windows/Git relacionados con el versionado en `docs/git/`, agrupados por unidad.
- Daniel ejecuta y aprende los pasos de Git, SQL y GitHub con acompañamiento.
- Cada publicación se comprueba; no se afirma que esté sincronizada solo porque los archivos fueron creados.

## Siguiente paso exacto

Publicar la corrección y actualización de README, estado y registro Git con los comandos de la sección 11 de [el cierre predictivo](git/05_evaluacion_predictiva_sincronizacion.md). Después, acordar la unidad de persistencia operativa en SQLite, como siguiente paso acotado. No se reejecutan los modelos para completar esta actualización documental.
