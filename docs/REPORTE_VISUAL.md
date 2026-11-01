# Reporte visual y seguimiento de emisiones

El módulo `R/12_reportes_visuales.R` presenta los resultados que producen los scripts 10/11. Genera HTML y gráficos SVG autónomos con R base, sin instalar paquetes adicionales ni recurrir a CDN, bases remotas o servicios pagos. JavaScript solo controla la visibilidad de capas; las cifras, gráficos y tablas se pueden consultar sin él.

## Vistas y contenido

| Página | Contenido |
|---|---|
| `index.html` | Resumen de la emisión vigente, trayectoria y acceso al archivo de emisiones. |
| `pronostico_actual.html` | Doce pronósticos por modelo, intervalos, reales vigentes, diferencias, CSV y diagnóstico del ajuste original. |
| `emisiones/<id>/reporte.html` | La misma información para la emisión identificada; conserva su historia y pronósticos originales. |
| `metricas_operativas.html` | MAE, RMSE y cobertura de emisiones efectivamente registradas, por modelo y horizonte, con cantidades evaluables. |
| `evaluacion_historica.html` | Referencia fechada del backtesting del 07; se dibuja desde su CSV archivado, sin volver a estimar. |

El diseño comparte navegación, escala en millones de litros en los gráficos, cifras completas en tablas y descargas, y disposición adaptable. Las tablas y gráficos anchos pueden desplazarse horizontalmente en móviles. Los gráficos están incorporados en los HTML; el archivo `trayectoria_original.svg` de cada emisión permite abrir también la vista original por separado.

## Tres tiempos distintos

1. **Información al emitir:** historia y ajuste leídos del RDS que pertenece a esa emisión. La línea histórica utiliza sus últimos 48 meses. El diagnóstico calcula residuos, FAC/FACP y QQ desde el ajuste archivado; no lo reestima.
2. **Predicciones originales:** proceden de los registros conservados en SQLite. El gráfico original excluye observados posteriores y se identifica por emisión, no solo por origen.
3. **Seguimiento vigente:** añade los reales actualmente disponibles en SQLite. Si INALE revisa una observación, pueden cambiar su diferencia y las métricas; la predicción guardada permanece igual.

El reporte se puede regenerar para actualizar su presentación. Con los mismos datos de una emisión, el SVG original es determinista; la conservación sustantiva se apoya en los artefactos y pronósticos archivados y sus controles de integridad.

## Evaluación acumulada

MAE y RMSE usan los errores `real − pronóstico` de cada emisión cuyo mes objetivo ya tenga observado. La cobertura cuenta si ese real está dentro de los límites inclusivos del intervalo. Las consultas mantienen separados los modelos y los horizontes y comprueban que ambos modelos compartan las mismas emisiones y meses objetivo.

Un horizonte sin observados mantiene métricas vacías y muestra un estado pendiente. No se reemplazan faltantes por errores cero ni se conectan puntos a través de horizontes sin datos. Cada punto evaluable incluye su cantidad de casos al pasar el cursor. Dos emisiones desde el mismo origen cuentan como versiones distintas, y los errores de emisiones solapadas no son independientes.

La referencia histórica del 07 permanece separada. Sus órdenes y efectos fueron seleccionados con información hasta septiembre de 2025; el backtesting condicionado no acredita una prueba independiente de todo el proceso de selección. No se mezcla con las métricas operativas ni se recalcula en la consulta mensual.

## Regenerar solo la vista local

Desde la raíz del proyecto, en la consola de RStudio:

```r
source("R/12_reportes_visuales.R", encoding = "UTF-8")
regenerar_reportes12()
```

Abrir `outputs/reportes/index.html` en el navegador. Se requiere una base local preparada y sus artefactos de emisiones. La conexión es de solo lectura: esta función no descarga datos, estima modelos, incorpora observaciones ni registra emisiones. Los HTML, SVG y CSV derivados se escriben en `outputs/reportes/` y una copia de control en `outputs/vista_local_reporte/`.

Para el ciclo operativo normal siguen utilizándose el 10 y el workflow del 11. El 10 carga el 12 al generar reportes; el 11 copia recursivamente todos los archivos públicos, incluidos SVG. El workflow existente ya transporta esa carpeta completa, por lo que no requiere cambios de calendario o permisos.

Una instalación que actualiza el código debe incorporar conjuntamente los scripts 10, 11 y 12. Mantener el 10/11 nuevo sin el 12 hace fallar la generación; no se produce una salida alternativa silenciosa.

## Verificación y publicación

Se comprobó en copias aisladas: caso actual sin errores evaluables, caso con un mes observado y dos emisiones, repetición conservando SQLite, CSV y predicciones, y arranque/recuperación a través del 11 con preparación de la carpeta pública. Se revisaron navegación, controles de capas y lectura del diagnóstico en navegador, además de una vista de 390 píxeles.

La preparación se probó con el runtime R 4.3.3 disponible para estas verificaciones. El entorno operativo del proyecto continúa siendo R 4.6.1 y su `renv.lock`; no se modifican sus dependencias. La ejecución y publicación de esta versión en ese entorno se verifican después de su commit mediante una corrida manual de Actions en `main`, con inicialización desmarcada y comprobación de `actualizar` y `publicar`.

El modelo, los pronósticos emitidos y el calendario conservan su definición previa. La reselección periódica sigue pendiente.

## Vista previa al compartir un enlace

Todas las páginas incluyen metadatos Open Graph en el HTML inicial: título, descripción, URL pública canónica e imagen con URL HTTPS absoluta. La portada estable `assets/portada-proyecto.png` mide 1200 × 630 píxeles y pesa menos de 5 MB. No contiene datos mensuales que puedan quedar desactualizados. Su fuente vectorial se conserva en `assets/portada-proyecto.svg`.

El módulo 12 copia esa imagen a `outputs/reportes/assets/` antes de generar las páginas. La copia recursiva del 11 la transporta a Pages; la regla `*.png -text` preserva sus bytes al guardar la rama operativa. Se verifica que la huella de la copia sea idéntica a la del original.

Después del despliegue, [LinkedIn Post Inspector](https://www.linkedin.com/post-inspector/) permite volver a consultar la URL y refrescar su caché. Luego puede ser necesario volver a agregar el enlace al perfil. La presencia de metadatos e imagen prepara el sitio para la extracción; el aspecto final depende de la sección de LinkedIn y debe comprobarse allí. No se presupone que cambien automáticamente las miniaturas ya guardadas.

Referencia: [requisitos de LinkedIn para compartir una web](https://www.linkedin.com/help/linkedin/answer/a521928/).
