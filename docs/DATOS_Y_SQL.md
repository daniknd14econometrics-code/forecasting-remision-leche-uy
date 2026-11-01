# Datos, preparación y persistencia en SQLite

## Fuente y cobertura

La fuente es la [estadística pública de remisión a planta del INALE](https://www.inale.org/estadisticas/remision-a-planta/), Uruguay. El proyecto utiliza el Excel enlazado desde esa página. Las copias originales se conservan fechadas en `data/original/`.

El archivo de referencia `remision_a_planta_inale_2026-10-29.xls` contiene 297 observaciones mensuales, de enero de 2002 a septiembre de 2026. Ese corte describe el estudio archivado; la operación posterior consulta nuevas publicaciones y posibles revisiones. No se utilizan datos internos de Conaprole.

La variable objetivo es la **remisión mensual en litros**. El archivo también proporciona kilos de sólidos, composición y observaciones que se conservan como información de origen.

## Responsabilidades de R y SQL

| Componente | Responsabilidad |
|---|---|
| `R/01_descargar_datos_inale.R` | Localiza el Excel en la página oficial y conserva una copia fechada. |
| `R/02_inspeccionar_datos_inale.R` | Selecciona la copia con fecha más reciente, verifica las hojas esperadas y lee el rectángulo tabular. |
| `R/03_cargar_staging_sqlite.R` | Ejecuta la inspección, normaliza variables y carga la tabla provisional. |
| `R/04_ejecutar_sql_analitico.R` | Ejecuta el SQL analítico y comprueba sus resultados. |
| `sql/01_crear_tabla_analitica.sql` | Construye la tabla mensual, aplica restricciones y consulta controles. |
| Scripts 08/09 y `sql/02_crear_tablas_pronosticos.sql` | Preparan la persistencia e importan la emisión inicial archivada. |
| Scripts 10/11 | Mantienen datos, pronósticos y continuidad del estado durante la operación. |

R interpreta la estructura particular del Excel; SQL transforma y valida las tablas. Las fechas seriales de Excel se convierten con origen `1899-12-30`. Se excluyen las filas no tabulares y se comprueba la conversión numérica; las observaciones mensuales no se imputan ni se sustituyen para mejorar el ajuste.

## Tablas

Base local: `database/forecasting.sqlite`.

| Tabla | Unidad y claves | Contenido |
|---|---|---|
| `stg_remision_inale` | Una fila por registro mensual leído | Fecha, litros, sólidos, proporciones de grasa/proteína, observaciones, archivo y momento de carga. |
| `analitica_remision_mensual` | Una fila por mes; `fecha` primaria y combinación año/mes única | Variables preparadas, millones de litros, composición porcentual y trazabilidad. |
| `forecast_ejecuciones` | Una fila por emisión; `ejecucion_id` primario | Fecha de emisión, período utilizado, especificación, versión, carpeta y huella del archivo de pronósticos. |
| `forecast_pronosticos` | Una fila por emisión/modelo/horizonte | Origen, mes objetivo, media, mediana e intervalos del 80% y 95%. |

La clave de pronósticos es `(ejecucion_id, modelo, h)`, con una clave foránea a `forecast_ejecuciones`. Cada emisión completa incluye doce horizontes por modelo: 24 filas para SARIMA y naïve.

## Transformaciones y controles

La tabla analítica deriva año y mes de la fecha, divide litros entre un millón para una escala auxiliar y multiplica las proporciones de composición por cien. Conserva los valores de origen y su trazabilidad.

Se verifican fechas válidas al inicio del mes, unicidad, continuidad mensual, litros y sólidos positivos, composición dentro de los límites definidos y correspondencia del número de filas. La consulta de continuidad utiliza `LAG(fecha)` y contrasta cada registro con el mes siguiente al anterior. El ejecutor R comprueba los resultados y detiene el proceso ante inconsistencias.

Los pronósticos requieren horizontes enteros 1–12, mes objetivo igual a origen más horizonte, campos numéricos válidos e intervalos ordenados. El registro inicial compara CSV y RDS antes de confirmar la carga y admite repetición idéntica sin duplicar ni reemplazar registros.

## Actualización y trazabilidad

El ciclo 10 distingue meses nuevos, revisiones de litros y cambios en otros campos. Los meses nuevos o revisiones de litros generan una emisión cuando corresponde; cambios exclusivamente de composición u observaciones pueden actualizar datos sin reestimar la trayectoria.

La tabla analítica contiene la versión vigente de las observaciones. Cada emisión conserva los datos utilizados y sus artefactos. Los errores se consultan comparando pronósticos archivados con los observados vigentes, por lo que una revisión de INALE puede modificar el seguimiento.

La actualización de datos y el registro de una nueva emisión se coordinan en una transacción SQLite. El guardado de archivos, el commit de la rama operativa y la publicación web son etapas posteriores separadas: no constituyen una única transacción.

## Persistencia local y remota

SQLite está excluida de `main` mediante `.gitignore`. En Actions se conserva explícitamente en `operacion`, junto con los Excel y artefactos necesarios para continuar el historial. La rama es pública, al igual que el repositorio; Pages recibe el paquete de reportes HTML/CSV.

La recuperación verifica la integridad SQLite, las claves foráneas, las huellas de archivos y la correspondencia de las predicciones con los originales. Ante un estado incompleto o un cierre de modelo incompatible, se detiene en lugar de reiniciar silenciosamente el historial.

Para ejecutar el proyecto o recuperar un estado, consultar [Reproducción y operación](REPRODUCCION_Y_OPERACION.md). La transformación estadística se explica en [Metodología](METODOLOGIA.md).
