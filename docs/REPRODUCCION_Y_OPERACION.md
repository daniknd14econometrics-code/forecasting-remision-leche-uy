# Reproducción y operación

## Entorno

El proyecto registra **R 4.6.1** y las versiones de paquetes en `renv.lock`. Requiere Git para clonar el repositorio y conexión a internet para restaurar dependencias o consultar INALE. RStudio es una opción para trabajar localmente; Actions utiliza `Rscript` en Ubuntu 24.04.

```bash
git clone https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy.git
cd forecasting-remision-leche-uy
```

Abrir el proyecto `.Rproj` o iniciar R desde esa raíz y ejecutar:

```r
renv::restore()
renv::status()
```

La carpeta debe llamarse `forecasting-remision-leche-uy`: los scripts iniciales comprueban ese nombre. No se necesita inicializar otra vez renv ni generar un lockfile nuevo para reproducir el entorno registrado. En Linux pueden ser necesarias bibliotecas de sistema para instalar paquetes desde código fuente.

## 1. Consultar resultados existentes

Las tablas y gráficos de referencia están en `outputs/evaluacion_predictiva/07_sarima_vs_naive/20261031_171120_23228/`. El cierre de desarrollo está en `outputs/sarima_box_jenkins/09_cierre_modelado/`.

Para inspeccionar el objeto de cierre desde R:

```r
cierre <- readRDS(
  "outputs/sarima_box_jenkins/09_cierre_modelado/11_objeto_bloque09.rds"
)
cierre$decision
cierre$comparacion
```

Consultar los artefactos no requiere repetir estimaciones. El reporte operativo más reciente está en [Pages](https://daniknd14econometrics-code.github.io/forecasting-remision-leche-uy/pronostico_actual.html); los ejemplos versionados en `main` corresponden a las emisiones archivadas allí.

## 2. Reconstruir la base local desde la fuente archivada

Realizar esta preparación en un clon limpio o una copia de trabajo destinada a la reproducción. Los scripts 03/04 reconstruyen tablas; no son una operación de sincronización de una base que ya tenga historial.

El archivo archivado `data/original/remision_a_planta_inale_2026-10-29.xls` reproduce el corte del estudio. El script 02 elige el original con fecha más reciente dentro de `data/original/`: para esta reproducción no debe haber allí descargas posteriores que desplacen ese archivo.

```r
source("R/03_cargar_staging_sqlite.R", encoding = "UTF-8")
source("R/04_ejecutar_sql_analitico.R", encoding = "UTF-8")
```

El 03 ejecuta el 02 y carga `stg_remision_inale`. El 04 ejecuta `sql/01_crear_tabla_analitica.sql` y comprueba las validaciones. Con la fuente archivada se esperan 297 meses, de enero de 2002 a septiembre de 2026. El 05 permite repetir la exploración:

```r
source("R/05_preparar_explorar_serie.R", encoding = "UTF-8")
```

Para obtener la publicación actual del INALE se puede ejecutar `R/01_descargar_datos_inale.R`. Esa descarga puede cambiar el corte o revisar observaciones; no debe confundirse con una reproducción exacta del estudio archivado.

## 3. Preparar la operación local con el cierre archivado

Conservar el cierre 06 y la corrida original del 07 incluidos en el repositorio. Tras reconstruir la base con 03/04, preparar las tablas de pronósticos e importar esa emisión:

```r
source("R/08_preparar_persistencia_sqlite.R", encoding = "UTF-8")
source("R/09_registrar_pronosticos_sqlite.R", encoding = "UTF-8")
```

El registro inicial se refiere expresamente a `20261031_171120_23228`: una emisión y 24 pronósticos. No elige la carpeta más reciente ni estima el modelo. Repetir una carga idéntica conserva los registros existentes.

El punto de entrada para las consultas posteriores es:

```r
source("R/10_actualizar_pronosticos.R", encoding = "UTF-8")
```

| Información encontrada | Comportamiento |
|---|---|
| Mismos datos y trayectoria completa compatible | Conserva la emisión; actualiza controles y reportes. |
| Mes nuevo o revisión de litros | Actualiza datos y reestima la misma especificación con toda la historia; registra doce horizontes por modelo. |
| Cambio solo en otros campos de origen | Puede actualizar las tablas sin generar otra trayectoria. |
| Datos, cierre o estado inválidos | Se detiene y deja evidencia del fallo. |

Reportes locales: `outputs/reportes/pronostico_actual.html`, `outputs/reportes/index.html` y sus CSV. Los controles de cada consulta se guardan en `outputs/operacion_mensual/`. Una carpeta de control nueva no equivale necesariamente a otra emisión en SQLite.

## 4. Repetir el desarrollo y la evaluación histórica

Este recorrido es distinto de operar con el cierre archivado. Utilizar una copia separada del proyecto y su base reconstruida, conservando los originales de referencia.

```r
source("R/06_modelar_evaluar_sarima.R", encoding = "UTF-8")
source("R/07_evaluar_pronosticar_sarima.R", encoding = "UTF-8")
```

El 06 ejecuta su desarrollo completo, incluidos diagnósticos, efectos y calibración bootstrap; puede requerir más tiempo. Su numeración interna 01–09 no corresponde a los archivos 01–09 de `R/`. El 07 ejecuta el backtesting y crea otra carpeta de resultados con su identificador.

Repetir 06 puede generar un objeto de cierre con otra huella. El sistema operativo comprueba esa huella para reconocer emisiones compatibles: no se debe reemplazar el cierre de una base operativa existente y esperar que su historial sea compatible automáticamente. El 09 predeterminado continúa apuntando a la corrida original; incorporar un nuevo cierre o cambiar de especificación requiere una migración explícita, no ejecutar otra vez el arranque inicial.

## 5. Ejecución en GitHub Actions

El workflow es [`.github/workflows/actualizar_pronosticos.yml`](../.github/workflows/actualizar_pronosticos.yml). Su calendario consulta el día 1 a las 09:17, zona `Europe/Madrid`. También admite ejecución manual; no se activa por cada push.

Para una consulta manual del repositorio ya inicializado:

1. Abrir **Actions → Actualizar pronosticos mensuales → Run workflow**.
2. Seleccionar `main` y dejar **desmarcada** la inicialización.
3. Revisar que terminen correctamente `actualizar` y `publicar`.

Para una instalación nueva en otro repositorio, habilitar Pages con **Settings → Pages → Source: GitHub Actions** y marcar la inicialización solo en el primer arranque, si la rama operativa nunca existió. El workflow usa permisos explícitos y el token temporal de GitHub; no requiere incorporar un token personal al repositorio.

El ejecutor temporal descarga `main`, recupera `operacion`, prepara R y renv, ejecuta el 11, confirma el estado en Git y publica los reportes. El 11 recupera la base antes de llamar al ciclo 10. En el primer arranque construye la base desde el Excel y las predicciones originales publicados; en los siguientes recupera la base operativa guardada. No repite 06/07.

La concurrencia impide dos escrituras simultáneas. La preparación de R tiene un límite de 15 minutos y el trabajo de actualización, de 45. El workflow configura descargas desde el archivo oficial de Ubuntu por HTTPS y limita reintentos y esperas, tras un bloqueo de `apt-get update` observado en la primera prueba. Si falla, revisar el paso concreto antes de cambiar el modelo o prolongar las esperas.

El script 11 exige un checkout limpio sin SQLite y directorios separados preparados por el workflow. No debe ejecutarse directamente sobre la base local habitual; para esa operación se utiliza el 10.

## 6. Estado remoto, reportes y recuperación

| Ubicación | Función |
|---|---|
| `main` | Código y evidencia archivada del desarrollo y evaluación. |
| `operacion/estado/` | SQLite, originales y artefactos para continuar el historial; ruta dentro de esa rama. |
| `operacion/publico/` | HTML/CSV preparados para Pages. |
| `operacion/ultima_comprobacion.csv` | Fecha de consulta, commit utilizado, identificador de Actions y resumen del ciclo. |
| Pages | Reporte vigente, historial y métricas. |

El commit del estado se guarda antes de publicar Pages. Si falla la publicación, la base puede estar actualizada mientras la web conserva el reporte anterior. No borrar ni reinicializar `operacion` para resolver ese caso.

Si falla R antes del guardado remoto, consultar la evidencia de la ejecución. Una pérdida o alteración del estado debe resolverse recuperando una versión válida y coherente, no creando un historial nuevo. Los errores de integridad o incompatibilidad del cierre requieren revisar sus causas.

La operación local y remota no se sincronizan entre sí automáticamente. Para continuar localmente desde el estado remoto es necesario recuperar SQLite y todos los archivos de su manifiesto como una unidad, en una copia preparada. Un `git pull` de `main` no descarga ese estado a la base local.

La programación puede sufrir demoras y, en repositorios públicos, deshabilitarse por inactividad según las reglas del servicio. Revisar la pestaña Actions y `ultima_comprobacion.csv`; la ausencia de una nueva emisión no demuestra por sí sola que se haya consultado la fuente.

## 7. Mapa de scripts

| Etapa | Scripts |
|---|---|
| Descarga, inspección y base | 01–04 |
| Exploración | 05 |
| Desarrollo de la especificación | 06 |
| Evaluación histórica y trayectoria inicial | 07 |
| Persistencia y registro inicial | 08–09 |
| Operación local | 10 |
| Recuperación y respaldo para Actions | 11 |

Los fundamentos se presentan en [Metodología](METODOLOGIA.md), las tablas en [Datos y SQL](DATOS_Y_SQL.md) y la evidencia en [Resultados](RESULTADOS.md).
