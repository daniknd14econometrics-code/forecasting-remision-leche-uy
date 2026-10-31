# Estado del proyecto

Última actualización: 31 de octubre de 2026.

## Situación actual

La obtención y preparación de los datos, su carga y consulta mediante SQLite/SQL y la selección de un modelo SARIMA de desarrollo están implementadas. El script 06 se ejecutó hasta su bloque interno 09 y guardó la decisión final. La evaluación predictiva del modelo actual y la automatización siguen pendientes.

El cierre de modelado se publicó en el commit `d6af68f` (`Finalize Box-Jenkins SARIMA modeling and documentation`). Después de ese envío, el usuario comprobó una carpeta de trabajo limpia y un recuento `0 0` entre `HEAD` y `origin/main`.

Este documento, el README actualizado y el registro `docs/git/04_cierre_sarima_sincronizacion.md` completan ahora la unidad documental. Corresponden a una unidad posterior al commit histórico `d6af68f`; su publicación se comprueba con los comandos del registro de Git.

## Objetivo y alcance vigentes

Construir un flujo reproducible de pronósticos mensuales de remisión nacional de leche a planta, con datos públicos del INALE, R, SQL/SQLite y Git/GitHub. El proyecto completo deberá evaluar el rendimiento predictivo, producir y almacenar nuevas predicciones, actualizarse con datos incorporados y ejecutar el recorrido mediante GitHub Actions.

Se mantiene el alcance inicial SARIMA. ARIMAX y variables externas quedan para una etapa posterior; machine learning y otras aplicaciones no se incorporan a este trabajo por defecto. No se utilizan bases internas de Conaprole en el repositorio público.

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

El detalle de los comandos y de su interpretación se conserva en [el registro de sincronización](git/04_cierre_sarima_sincronizacion.md). No hay que repetir el modelado ni los movimientos de resultados anteriores para publicar documentación.

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

La elección queda fijada para la siguiente etapa, con su justificación y limitaciones. No se vuelve a abrir la búsqueda de órdenes por incorporar estos documentos.

## Resultados de referencia del cierre

| Ajuste | AICc | BIC | Ljung–Box 12 / 24 / 36 |
|---|---:|---:|---|
| ARMA21+SAR1, principal | −991.986 | −928.886 | 0.413 / 0.246 / 0.385 |
| ARMA21+SMA1, contraste y auditor condicionado | −992.051 | −928.951 | 0.334 / 0.210 / 0.315 |

La diferencia AICc aproximada de 0.065 no se interpreta como superioridad predictiva. Las alternativas ARMA22 con mejores IC presentaron factores casi comunes y raíces muy próximas al círculo unitario; conservaron rechazo en Ljung–Box a 12 meses y no se eligieron como principal.

En cambio estructural, el SupF convencional fue 73.7206, con p convencional aproximadamente 2.896e−15. Bajo el simulador I(1) estimado de 06C, el p bootstrap fue 0.164 y el crítico al 5% aproximadamente 121.832, con 999 réplicas. La decisión operativa fue no incorporar un quiebre de trayectoria; no equivale a demostrar estabilidad ni a decidir el orden de integración. La calibración se conserva con su alcance condicional y aproximado.

Los números anteriores describen ajuste y diagnóstico dentro del desarrollo. No son métricas de error predictivo fuera de muestra.

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

## Límites que permanecen explícitos

1. No rechazar Ljung–Box no demuestra independencia ni homocedasticidad; la mayor dispersión temprana permanece documentada.
2. Los errores estándar e intervalos de coeficientes son condicionales y aproximados después de seleccionar órdenes y efectos.
3. No rechazar el contraste estructural calibrado no prueba ausencia de cambios de cualquier tipo.
4. Cerrar la selección de desarrollo no demuestra que el modelo supere a un benchmark en pronóstico.
5. El script 06 tiene un calendario y una arquitectura fijados para este estudio. Todavía no es el procedimiento automático de actualización con nuevas observaciones.

## Trabajo pendiente del proyecto global

| Orden | Tarea | Situación |
|---|---|---|
| 1 | Diseñar la evaluación predictiva | Falta fijar orígenes, horizontes, muestra, reglas de aprendizaje, benchmarks y métricas antes de ejecutarla. |
| 2 | Implementar y ejecutar la evaluación temporal | No realizada para el cierre actual. |
| 3 | Producir pronósticos e intervalos en litros mensuales | Pendiente. |
| 4 | Almacenar predicciones, métricas y metadatos de ejecuciones | Pendiente. |
| 5 | Integrar un punto de entrada y probar actualización con datos nuevos | Pendiente. |
| 6 | Configurar y comprobar GitHub Actions | Pendiente, después de verificar el proceso local. |

## Base metodológica de la evaluación que sigue

Se utilizarán los materiales aportados por el usuario, revisando qué corresponde aplicar a esta serie nacional:

| Material | Responsabilidad |
|---|---|
| Taller 05B, ARIMA/SARIMA de flujo completo | Implementación de pseudo-orígenes, benchmarks, métricas, retransformación y evaluación de incertidumbre. |
| Capítulo de función de forecasting | Interpretación de la trayectoria condicional, componentes permanentes/transitorios e incertidumbre según el horizonte. No reemplaza la comparación fuera de muestra. |
| Capítulo transversal de evaluación | Cronología, conjunto de información, separación de selección/evaluación/operación, métricas por horizonte e intervalos. |

Se trasladará la lógica, no las fechas del taller, sus coeficientes, el ganador, una ventana de 84 meses o ponderaciones particulares sin justificarlos para este proyecto.

Antes de programar se precisará qué se evalúa: una especificación fijada al cerrar el desarrollo o una regla completa de selección y detección que se reaprende en cada origen. Volver a estimar coeficientes no elimina la información futura si las decisiones de arquitectura se tomaron usando observaciones posteriores a un pseudo-origen. Tampoco se denominará test intacto a un período consultado en etapas anteriores. Estas distinciones deben resolverse en el diseño, sin reabrir por inercia todo el modelado ya cerrado.

La vuelta del logaritmo a litros, la media frente a la mediana, la acumulación de diferencias y la incertidumbre del total agregado requieren un tratamiento coherente con el modelo. No se impondrán métricas ni nuevos contrastes antes de discutir el uso del pronóstico.

## Forma de trabajo que se conserva

**Definir → ejecutar → comprobar → documentar → guardar y sincronizar → continuar.**

- Unidades de trabajo acotadas y revisables; no acumular toda la documentación para el final.
- Código estadístico y explicación en `R/` y `docs/R/`.
- Consultas y documentación SQL en `sql/` y `docs/sql/`.
- Comandos de Windows/Git relacionados con el versionado en `docs/git/`, agrupados por unidad.
- Daniel ejecuta y aprende los pasos de Git, SQL y GitHub con acompañamiento.
- Cada publicación se comprueba; no se afirma que esté sincronizada solo porque los archivos fueron creados.

## Siguiente paso exacto

Cerrar la publicación de esta unidad documental con el procedimiento de `docs/git/04_cierre_sarima_sincronizacion.md` y presentar el diseño de evaluación basado en los tres materiales. Acordar ese diseño antes de escribir el siguiente script estadístico. No se repite el modelado para actualizar documentación.
