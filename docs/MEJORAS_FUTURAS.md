# Dos caminos de mejora

La versión actual integra datos públicos, SQL/SQLite, SARIMA, evaluación histórica, pronósticos, persistencia y actualización mediante Actions. Este documento plantea dos ampliaciones opcionales. No están implementadas ni se activan por su inclusión en el repositorio.

ARIMAX se reserva para otro proyecto independiente, desarrollado desde cero.

## 1. Capa visual de Pages

**Objetivo:** añadir gráficos que permitan comprender cada emisión y el desempeño acumulado, aprovechando los datos y ajustes ya archivados.

| Contenido | Comportamiento propuesto |
|---|---|
| Trayectoria e intervalos por emisión | Crear un gráfico con cada nueva emisión y conservarlo asociado a su identificador. |
| Diagnóstico del ajuste | Guardar residuos, FAC/FACP y otros diagnósticos junto al modelo que produjo la emisión. |
| Seguimiento de emisiones anteriores | Incorporar observados sin recalcular ni sobrescribir sus pronósticos originales. |
| Evaluación operativa acumulada | Graficar errores y cobertura por modelo/horizonte, indicando casos comunes y cantidades evaluables. |

Los gráficos históricos del 07 quedarían como referencia del estudio original. Sus MAE/RMSE y coberturas provienen de un backtesting con muchos orígenes, no de la precisión ya observada de la emisión inicial.

Una consulta sin novedades no debería crear otra emisión. Una revisión de datos puede producir otra desde el mismo origen, por lo que el archivo gráfico debe identificarse por emisión y no solamente por mes. Los observados revisados pueden modificar el seguimiento, pero no los pronósticos guardados.

La implementación requiere generar imágenes, conservarlas y ajustar los HTML y la copia de archivos que recibe Pages. Debe probarse una nueva emisión, el llenado de observados de la anterior, la repetición sin duplicados y el acceso al historial. El gráfico acumulado debe distinguir valores pendientes de errores cero.

## 2. Revisión periódica del modelo

**Objetivo:** volver a evaluar la adecuación de la especificación sin confundir revisión con cambio obligatorio. Hoy la actualización reestima coeficientes de la misma especificación; no reselecciona órdenes o efectos cada año.

| Momento | Alcance propuesto, sujeto a definición |
|---|---|
| Cada actualización mensual | Mantener el ciclo vigente y actualizar el seguimiento. |
| Tras doce meses nuevos desde la última revisión | Revisar identificación, candidatos parsimoniosos, diagnóstico y desempeño predictivo. |
| Cada cinco años | Hacer una revisión más profunda que incluya el análisis formal de cambios estructurales. |
| Ante deterioro persistente | Evaluar si corresponde adelantar la revisión. |

El plazo quinquenal es una preferencia de diseño, no una regla estadística universal. Deben definirse el punto de partida, las demoras de publicación y las revisiones extensas de la historia que no agregan meses.

La revisión anual reutilizaría los componentes Box–Jenkins del 06 con fechas y reglas explícitas: examinar la serie y el ajuste, proponer pocos candidatos justificados, comprobar admisibilidad y diagnóstico y contrastar sus pronósticos frente al modelo vigente y al naïve. AICc requiere bases comparables y el diagnóstico residual no acredita superioridad predictiva.

Antes de programar deben fijarse muestra de estimación, período de validación, horizontes, pérdida, mejora mínima, criterio de estabilidad y señales de revisión anticipada. También debe decidirse si se publica una recomendación o se permite sustitución automática bajo reglas verificadas.

La comparación debe respetar la información disponible en cada origen, incluida la selección de efectos. Los datos usados para elegir un candidato no constituyen una prueba independiente de esa misma selección. Un año de emisiones aporta aproximadamente doce errores a un mes y apenas uno a doce meses bajo una secuencia regular; el seguimiento inicial no basta para decidir sobre horizontes largos.

El 06 actual conserva el desarrollo con corte en septiembre de 2025. Programar su ejecución sin cambios no implementa por sí solo esta revisión. Deben adaptarse la coordinación y la persistencia 10/11 para validar varias versiones de modelo y registrar su entrada en operación, preservando todas las emisiones anteriores.

La ampliación se consideraría comprobada tras ensayar conservación del modelo, sustitución de versión, repetición sin duplicados y activación anual/quinquenal/anticipada con datos controlados fuera del estado público, y verificar el flujo en Actions.

## Cómo retomarlos

Los dos caminos pueden desarrollarse por separado. Antes de comenzar, revisar el estado real del repositorio y `operacion`, concretar el alcance y mantener pruebas y documentación junto con cada cambio. No se fija un plazo, presupuesto ni obligación de implementar ambas capas.

Referencias metodológicas: Hyndman y Athanasopoulos, [ARIMA](https://otexts.com/fpp3/arima.html) y [diagnóstico y evaluación temporal](https://otexts.com/fpp3/toolbox.html). Estas fuentes no prescriben el calendario propuesto.
