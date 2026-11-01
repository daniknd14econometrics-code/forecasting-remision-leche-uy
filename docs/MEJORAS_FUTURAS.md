# Dos caminos de mejora

La versión actual integra datos públicos, SQL/SQLite, SARIMA, evaluación histórica, pronósticos, persistencia y actualización mediante Actions. Este documento distingue la mejora visual ya implementada y la revisión periódica del modelo todavía propuesta. La segunda no se activa por su inclusión en el repositorio.

ARIMAX se reserva para otro proyecto independiente, desarrollado desde cero.

## 1. Capa visual de Pages

La primera mejora visual está implementada en el módulo 12: portada, trayectoria e intervalos por emisión, diagnóstico del ajuste original, seguimiento con reales vigentes, archivo consultable y gráficos acumulados de error y cobertura con cantidades evaluables. El backtesting del 07 tiene una vista separada y fechada.

La presentación se probó en copias aisladas y en navegador; su publicación se verifica con una corrida de Actions tras incorporar los archivos. El alcance, los comandos y la validación se describen en [Reporte visual](REPORTE_VISUAL.md).

Una consulta sin cambios conserva la emisión. Una revisión puede producir otra desde el mismo origen, por lo que se utiliza el identificador completo. La historia y el ajuste de cada emisión provienen de su artefacto original; los observados revisados pueden modificar el seguimiento, pero no los pronósticos guardados.

Como ampliaciones visuales opcionales quedan filtros para historiales extensos y mapas de error por mes objetivo cuando existan suficientes casos por celda. No son requisitos para la vista actual.

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

La revisión del modelo puede desarrollarse independientemente de la presentación. Antes de comenzarla, revisar el estado real del repositorio y `operacion`, concretar el alcance y mantener pruebas y documentación junto con cada cambio. No se fija un plazo, presupuesto ni obligación de implementar ambas capas.

Referencias metodológicas: Hyndman y Athanasopoulos, [ARIMA](https://otexts.com/fpp3/arima.html) y [diagnóstico y evaluación temporal](https://otexts.com/fpp3/toolbox.html). Estas fuentes no prescriben el calendario propuesto.
