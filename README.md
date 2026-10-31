# Forecasting de la remisión de leche en Uruguay

Proyecto en R para construir, evaluar y actualizar pronósticos de la remisión mensual de leche a plantas industriales en Uruguay, con datos públicos del Instituto Nacional de la Leche (INALE).

Integra descarga y preparación de datos, SQL/SQLite, modelado SARIMA, evaluación predictiva histórica, pronósticos a doce meses, documentación pedagógica y control de versiones con Git/GitHub. La integración operativa de actualizaciones y GitHub Actions siguen pendientes.

## Estado actual

Actualización: 31 de octubre de 2026.

| Componente | Estado |
|---|---|
| Descarga y conservación de archivos originales INALE | Implementado. |
| Carga en SQLite y tabla analítica mediante SQL | Implementado y ejecutado localmente. |
| Exploración y controles de la serie | Implementados. |
| Modelado mediante Box–Jenkins | Selección cerrada en el script 06. |
| Diagnósticos, comparación de candidatos y efectos atípicos | Resultados guardados y publicados. |
| Documentación de R, SQL y Git | Disponible, incluido el registro de comandos del cierre. |
| Dependencias de R | Registradas en `renv.lock`; comprobación local sin inconsistencias. |
| Evaluación histórica del SARIMA frente al naïve estacional | Ejecutada: 166 orígenes mensuales, horizontes 1–12; alcance condicionado a la especificación elegida. |
| Próximos doce pronósticos e intervalos | Generados desde septiembre de 2026; guardados en CSV/RDS. |
| Historial operativo de pronósticos y errores en SQLite | Pendiente. Las carpetas de resultados actuales sí conservan cada corrida. |
| Ejecución integrada y actualización automatizada | Pendiente. |
| GitHub Actions | Pendiente. |

El modelado y la evaluación están publicados en el commit [e98ed61](https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy/commit/e98ed61edea7f7ee3bffbbb11b12378276e57da6). Se comprobó localmente árbol limpio y `0 0` entre `HEAD` y `origin/main`, y se verificó el commit en GitHub. Esta actualización documental se prepara después de esa comprobación; no se da por publicada por estar escrita.

## Objetivo del proyecto completo

Construir un flujo reproducible que permita obtener datos del INALE, conservar cada descarga original fechada, preparar la información con R y SQL, estimar y diagnosticar modelos, evaluar sus pronósticos respetando el orden temporal, producir nuevas predicciones y registrar resultados e historial de ejecuciones. Una vez comprobado el proceso local, se incorporará su ejecución mediante GitHub Actions.

La primera etapa se concentra en SARIMA para una serie mensual. Queda abierta una extensión ARIMAX con precio al productor y precipitaciones, en este proyecto o en otro; no se presupone que mejore los pronósticos ni se exige para cerrar esta etapa. Machine learning, datos sintéticos y nuevas aplicaciones no forman parte de este desarrollo inicial.

## Datos y representación

- Fuente: archivos públicos de remisión a planta del INALE, conservados en `data/original/`.
- Variable objetivo operativa: litros de remisión mensual.
- Serie utilizada para el modelado: `x_t = log(litros_t / dias_del_mes_t)`.
- Dividir por días corrige la duración del mes; sigue existiendo una observación por mes.
- Muestra de desarrollo del script 06: enero de 2002 a septiembre de 2025, 285 niveles y 284 primeras diferencias.
- El script 06 consulta SQLite con ese corte; no utiliza las observaciones posteriores en esta selección.
- La ejecución del script 07 utiliza datos hasta septiembre de 2026: 297 meses en niveles.

El backtesting del 07 es histórico y condicionado: reestima coeficientes en cada origen, conservando órdenes y efectos seleccionados con datos hasta septiembre de 2025. No es una prueba independiente del procedimiento completo de selección. Se utiliza la versión actual de las observaciones, sin reconstruir las publicaciones históricas de la base.

## Modelo seleccionado y evaluación realizada

Principal: **SARIMA(2,1,1)(1,0,0)[12]**, sin deriva, con once contrastes mensuales y dos efectos atípicos: TC en febrero de 2006, con decaimiento 0.7, y AO en abril de 2004.

El ajuste se estima como un ARMA sobre la primera diferencia del logaritmo del promedio diario. Los contrastes mensuales se incluyen en esa diferencia; los perfiles de los efectos se definen en niveles y se diferencian antes de agregarlos como regresores. Las observaciones originales no se sustituyen.

El script 06 conserva un contraste SMA1 y auditorías automáticas para documentar la selección. **La comparación predictiva del 07 incluye solamente el SARIMA principal y el naïve estacional**, ajustado por días del mes; no añade esos otros candidatos.

En el principal, Ljung–Box no rechazó en los horizontes diagnósticos 12, 24 y 36; esto no prueba independencia ni varianza constante. La mayor dispersión residual temprana permanece documentada. No se incorporó un cambio determinístico de trayectoria: el contraste calibrado de 06C no rechazó bajo su representación nula I(1), con alcance expresamente condicional y aproximado.

El registro del cierre se encuentra en `outputs/sarima_box_jenkins/09_cierre_modelado/`. Su objeto `11_objeto_bloque09.rds` conserva ajuste, contraste, regresores, efectos, datos de desarrollo, transformación y decisión. La evaluación posterior se guarda separadamente en `outputs/evaluacion_predictiva/`.

El backtesting utiliza ventana expansiva, primer entrenamiento enero de 2002–diciembre de 2011 y 166 orígenes entre diciembre de 2011 y septiembre de 2025. Ambos modelos tienen doce resultados observados por origen: 3.984 registros históricos. La métrica principal fijada es MAE; RMSE es complementaria. Se evalúa la media predictiva en litros, con la corrección lognormal correspondiente.

| Horizonte mensual | MAE SARIMA, millones de litros | MAE naïve, millones de litros |
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

SARIMA obtiene menor MAE y RMSE a 1–3 meses; el naïve, a 4–12. La reducción del MAE del SARIMA es 46,35% a un mes, 22,37% a dos y 4,60% a tres. No se atribuye superioridad general ni se construye después una regla híbrida presentada como si ya estuviera validada.

Se observan diferencias por mes objetivo y bandas SARIMA conservadoras a horizontes largos. El diagnóstico residual del ajuste actual es aceptable en los controles realizados, pero eso no garantiza menor error frente a una referencia.

## Pronósticos guardados y seguimiento

La corrida revisada es:

```text
outputs/evaluacion_predictiva/07_sarima_vs_naive/20261031_171120_23228/
```

Contiene predicciones históricas, métricas por horizonte y mes, diagnósticos, coeficientes, avisos, gráficos y pronósticos futuros para **octubre de 2026–septiembre de 2027**, emitidos desde septiembre de 2026. Se conserva el SARIMA para ese ejercicio por decisión del proyecto, junto con la referencia; no se afirma que sea el ganador histórico a todos los horizontes.

Cada ejecución crea otra carpeta y conserva origen, fecha objetivo y horizonte. Todavía falta el mecanismo que incorpore las observaciones nuevas, las compare con pronósticos emitidos previamente y guarde sus errores de forma operativa en SQLite.

## Scripts y conexión entre etapas

| Archivo | Responsabilidad |
|---|---|
| `R/01_descargar_datos_inale.R` | Descarga y conservación del archivo original fechado. |
| `R/02_inspeccionar_datos_inale.R` | Inspección de la estructura del archivo público. |
| `R/03_cargar_staging_sqlite.R` | Carga inicial en SQLite. |
| `R/04_ejecutar_sql_analitico.R` | Construcción y controles de la tabla analítica. |
| `R/05_preparar_explorar_serie.R` | Preparación y exploración de la serie. |
| `R/06_modelar_evaluar_sarima.R` | Recorrido Box–Jenkins y guardado de la selección de desarrollo. |
| `R/07_evaluar_pronosticar_sarima.R` | Backtesting histórico condicionado, comparación con naïve estacional y próximos doce pronósticos. |

Aunque el nombre histórico del archivo 06 contiene “evaluar”, su versión actual compara ajuste y diagnósticos dentro del desarrollo. No ejecuta la evaluación predictiva fuera de muestra del modelo cerrado. Las salidas del antiguo recorrido `sarima_base` y backtesting se conservaron localmente fuera del repositorio para no mezclarlas con las actuales.

## Reproducción local

1. Clonar el repositorio y abrir `forecasting-remision-leche-uy.Rproj` en RStudio.
2. Recuperar el entorno de paquetes con `renv::restore()` y revisar `renv::status()`.
3. Preparar la base SQLite mediante los scripts de descarga, inspección, carga y SQL, siguiendo sus documentos en `docs/R/` y `docs/sql/`. La base generada no está versionada: `.gitignore` excluye `database/*.sqlite` y sus archivos auxiliares.
4. Para repetir la ejecución histórica, conservar como referencia el archivo original fechado `remision_a_planta_inale_2026-10-29.xls`; una descarga posterior puede contener revisiones de la fuente.
5. Una vez disponible la tabla `analitica_remision_mensual`, ejecutar desde la raíz del proyecto:

```r
source("R/06_modelar_evaluar_sarima.R")
```

`source()` ejecuta el recorrido completo de los bloques internos 01–09 del módulo 06. La numeración interna no debe confundirse con los nombres de los otros scripts de la carpeta `R/`.

Para consultar el cierre guardado sin volver a estimar:

```r
cierre <- readRDS(
  "outputs/sarima_box_jenkins/09_cierre_modelado/11_objeto_bloque09.rds"
)
cierre$decision
cierre$comparacion
```

Con la tabla SQLite preparada y el cierre del 06 disponible, ejecutar la evaluación y el pronóstico:

```r
source("R/07_evaluar_pronosticar_sarima.R", encoding = "UTF-8")
```

`source()` ejecuta todo el 07 y crea `evaluacion07`. No hace falta repetir el 06 para consultar sus resultados o ejecutar el 07 con un cierre válido. El 07 comprueba que los datos de desarrollo coincidan con el cierre; si una descarga revisa ese tramo, requiere una revisión explícita antes de continuar.

Todavía no existe un punto de entrada que automatice el proyecto completo. El script 06 conserva fechas y decisiones del estudio y el 07 ejecuta evaluación y pronóstico como una unidad. No sustituyen aún el futuro procedimiento operativo de actualización.

## Documentación de estudio

La explicación acompaña cada unidad ejecutada: objetivo, código o comandos, sintaxis, decisiones, resultados y comprobaciones. No se limita al código estadístico; también se documentan SQL, Windows, Git y GitHub.

- [Preparación, integración e identificación del script 06](docs/R/06_01_preparacion_identificacion.md).
- [Candidatos y cambio estructural](docs/R/06_02_candidatos_cambio_estructural.md).
- [Outliers, revisión final y cierre](docs/R/06_03_outliers_revision_cierre.md).
- [Evaluación, pronósticos y resultados del script 07](docs/R/07_evaluacion_pronosticos_sarima.md).
- [Flujo general de Git](docs/git/00_flujo_general_git.md).
- [Registro de Windows, renv y sincronización del cierre](docs/git/04_cierre_sarima_sincronizacion.md).
- [Publicación del script 07 y comprobaciones de Git](docs/git/05_evaluacion_predictiva_sincronizacion.md).
- [Estado detallado y siguiente paso](docs/ESTADO_DEL_PROYECTO.md).

El flujo de trabajo se mantiene: definir → ejecutar → comprobar → documentar → guardar y sincronizar → continuar.

## Próxima etapa

Completar el funcionamiento operativo sin reabrir el modelado: registrar corridas y predicciones en SQLite, incorporar observaciones nuevas y medir los errores de pronósticos ya emitidos, integrar el flujo local y después verificar una ejecución real con GitHub Actions. El [estado del proyecto](docs/ESTADO_DEL_PROYECTO.md) separa lo completado, las decisiones abiertas y la siguiente unidad.

Los materiales originales orientan la metodología; no se publican aquí sus bases internas ni se trasladan automáticamente sus fechas, coeficientes, ponderaciones o conclusiones al caso nacional del INALE.

## Autor

Daniel Méndez.
