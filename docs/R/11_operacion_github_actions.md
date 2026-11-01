# Script 11 — Operación en GitHub Actions y continuidad del historial

Fecha de preparación: 31 de octubre de 2026.
Actualizado el 1 de noviembre de 2026. Estado: dos ejecuciones manuales de Actions y publicación en Pages correctas; recuperación de `operacion` sin inicializar ni duplicar comprobada. Primer disparo del calendario pendiente de observación.

## Qué resuelve

El script 10 ya consulta INALE, compara los datos, reestima cuando corresponde y genera los siguientes doce pronósticos. El 11 lo integra con un entorno temporal de GitHub Actions: recupera el estado anterior, ejecuta ese mismo ciclo y prepara un estado completo para la siguiente ejecución.

No sustituye el 10 ni requiere volver a ejecutar los scripts 06 y 07. El modelo sigue siendo SARIMA(2,1,1)(1,0,0)[12], sin deriva, con once contrastes mensuales, TC de febrero de 2006 (delta 0,7) y AO de abril de 2004. Los coeficientes se reestiman con todos los meses desde enero de 2002 hasta el último observado cuando corresponde una nueva emisión. El naïve estacional sigue siendo la única referencia predictiva.

## Dónde se ejecuta

Ruta del script: `R/11_operacion_github_actions.R`.

El workflow lo llama desde su copia limpia del proyecto:

```r
source("R/11_operacion_github_actions.R", encoding = "UTF-8")
```

No ejecutar ese comando sobre la sesión local habitual que ya tiene SQLite. El 11 verifica que no haya una base local y se detiene antes de sobrescribirla. Para el ciclo local habitual se conserva el comando del script 10.

El workflow prepara dos directorios hermanos:

| Directorio | Contenido | Persistencia |
| --- | --- | --- |
| `codigo/` | Copia de `main`, scripts, cierre y archivos iniciales publicados | Se descarga en cada ejecución |
| `estado/` | Copia de la rama `operacion` | Se recupera y confirma con Git en cada ciclo completo |

Dentro de la rama `operacion`, el subdirectorio `estado/` contiene SQLite y los artefactos que necesita para continuar. El subdirectorio `publico/` contiene exclusivamente los HTML y CSV que se publican en Pages. La repetición del nombre `estado` se debe a que el directorio del ejecutor y la carpeta guardada en la rama tienen funciones diferentes.

Las variables `FORECAST_ESTADO_DIR` y `FORECAST_INICIALIZAR` las establece el workflow. La primera es una ruta absoluta al directorio de la rama operativa. La segunda solo permite el arranque inicial, que el usuario debe indicar en la primera ejecución manual.


El primer arranque no copia la SQLite de Windows, excluida de `main`. Crea una base nueva a partir del Excel publicado y registra exactamente los pronósticos archivados de `20261031_171120_23228`. Para el cierre verificado, eso reproduce los 297 meses y la única emisión que había en la base local después del 10. No busca automáticamente cualquier corrida local más reciente: el arranque está anclado expresamente a esa emisión. A partir de la siguiente ejecución recupera la SQLite guardada en `operacion`, con todo su historial. La recuperación valida integridad y correspondencia de archivos; no implica una nueva selección estadística.

## Entradas y salidas

Entradas: `renv.lock` restaurado; los scripts 08, 09 y 10; ambos archivos SQL existentes; el cierre del 06; los archivos de la corrida `20261031_171120_23228`; el Excel inicial del 29 de octubre de 2026; y, cuando ya existe, el estado guardado en `operacion`.

Salidas: SQLite actualizado; historial de emisiones y originales conservados; controles de cada consulta; reportes de doce meses; MAE y RMSE operativos con sus cantidades de errores; manifiesto de integridad; y archivos listos para publicar en Pages.

El script prepara archivos. El commit, el push y la publicación web los realiza el workflow después de que el script termina correctamente. El éxito del script no equivale por sí solo al éxito de la publicación remota.

## Recorrido completo del código

Se incluye todo el código por bloques, en el mismo orden del script.

```r
# ============================================================================
# SCRIPT 11 — CONTINUIDAD DEL ESTADO Y REPORTES PARA GITHUB ACTIONS
# Lo llama .github/workflows/actualizar_pronosticos.yml desde la raiz.
# FORECAST_ESTADO_DIR: directorio de trabajo de la rama operacion.
# FORECAST_INICIALIZAR=true: solo en la primera ejecucion manual sin estado.
# No modifica ni ejecuta la seleccion del 06 ni el backtesting del 07.
# Documentacion: docs/R/11_operacion_github_actions.md
# ============================================================================
```

### Bloque 1. Copias exactas y rutas relativas

`op11_ruta_relativa()` rechaza rutas absolutas, componentes `..` y separadores que no corresponden al formato del manifiesto. `op11_copiar()` recorre los archivos, crea sus directorios y compara los MD5 de origen y destino después de copiar. No incorpora directorios completos ni enlaces simbólicos como si fueran archivos.

`file.path()` construye rutas; `dirname()` obtiene el directorio padre; `file.copy()` copia bytes. `tools::md5sum()` permite detectar alteraciones accidentales: aquí se usa como comprobación de integridad, no como firma de autoría o mecanismo de autenticación.

```r
# 1. Copias exactas y rutas relativas -----------------------------------------
op11_ruta_relativa <- function(x) {
  is.character(x) && !anyNA(x) && all(nzchar(x)) &&
    !any(grepl("(^/|^[A-Za-z]:|\\\\|(^|/)\\.\\.(/|$))", x))
}

op11_copiar <- function(origen, destino, archivos) {
  if (!op11_ruta_relativa(archivos)) stop("Ruta de estado no permitida.")
  for (archivo in archivos) {
    desde <- file.path(origen, archivo); hacia <- file.path(destino, archivo)
    if (!file.exists(desde) || dir.exists(desde) || nzchar(Sys.readlink(desde))) {
      stop("Falta un archivo regular del estado: ", archivo)
    }
    dir.create(dirname(hacia), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(desde, hacia, overwrite = TRUE, copy.mode = FALSE) ||
        unname(tools::md5sum(desde)) != unname(tools::md5sum(hacia))) {
      stop("No se pudo copiar sin cambios: ", archivo)
    }
  }
  invisible(archivos)
}
```

### Bloque 2. Cargar el motor del 10 antes de recuperar SQLite

El 10 termina con una llamada que ejecuta todo el ciclo. El 11 necesita sus funciones antes de tener la base recuperada. Por eso usa `parse()` para leer sus expresiones, comprueba exactamente cuál es la última llamada y evalúa todas las expresiones anteriores en un entorno separado.

No se reescriben los filtros, la estimación ni las reglas del 10. Tampoco se elimina su ejecución habitual con `source()`: solo el 11 controla en qué momento lo llama. Si cambia ese punto de entrada, se detiene para revisar la integración.

`new.env()` separa las funciones cargadas; `quote()` representa la llamada esperada sin ejecutarla; `eval()` evalúa las expresiones que definen funciones y configuración.

```r
# 2. Cargar funciones del 10 sin disparar aun su llamada final -----------------
op11_cargar10 <- function(raiz) {
  codigo <- parse(file.path(raiz, "R", "10_actualizar_pronosticos.R"), encoding = "UTF-8")
  llamada <- quote(operacion10 <- ejecutar_ciclo10(config10))
  if (length(codigo) < 2L || !identical(codigo[[length(codigo)]], llamada)) {
    stop("Cambio el punto de entrada del 10: revisar la integracion del 11.")
  }
  ambiente <- new.env(parent = globalenv())
  # Se evalua todo salvo esa llamada; asi podemos recuperar primero SQLite.
  eval(codigo[-length(codigo)], envir = ambiente)
  ambiente
}
```

### Bloque 3. Validar SQLite y sus emisiones

Antes y después del ciclo se abre SQLite, se comprueba su integridad y se verifican las claves foráneas. También se exige que cada emisión tenga 24 pronósticos: doce SARIMA y doce naïve.

Para cada emisión se comprueba el archivo CSV original, su huella registrada, el RDS de modelo y pronósticos, la muestra utilizada y el cierre del modelo. Los valores guardados en SQLite deben reproducir las predicciones originales. El cierre es el archivo binario del bloque 09 del script 06, que permanece en `main`.

`on.exit()` cierra la conexión incluso si aparece un error. Una prueba de integridad correcta no reemplaza estas comparaciones: un archivo SQLite puede ser internamente válido y contener un historial distinto del esperado.

```r
# 3. Validar SQLite y cada emision original, con las funciones del 10 ----------
op11_validar_base <- function(raiz, motor) {
  ruta <- file.path(raiz, "database", "forecasting.sqlite")
  if (!file.exists(ruta)) stop("Falta la base operativa.")
  con <- DBI::dbConnect(RSQLite::SQLite(), ruta)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  if (!identical(DBI::dbGetQuery(con, "PRAGMA integrity_check")[[1]], "ok") ||
      nrow(DBI::dbGetQuery(con, "PRAGMA foreign_key_check"))) stop("SQLite no supera la integridad.")
  tablas <- c("stg_remision_inale", "analitica_remision_mensual", "forecast_ejecuciones", "forecast_pronosticos")
  if (!all(vapply(tablas, function(x) DBI::dbExistsTable(con, x), logical(1)))) stop("Estado SQLite incompleto.")
  emisiones <- DBI::dbGetQuery(con, "SELECT * FROM forecast_ejecuciones ORDER BY ejecucion_id")
  predicciones <- DBI::dbGetQuery(con, "SELECT * FROM forecast_pronosticos ORDER BY ejecucion_id, modelo, h")
  if (!nrow(emisiones) || nrow(predicciones) != 24L * nrow(emisiones) ||
      any(emisiones$version_modelo != "SARIMA_06_v1")) stop("El historial no contiene emisiones completas de la version acordada.")
  cierre_md5 <- unname(tools::md5sum(file.path(raiz, motor$config10$ruta_cierre)))
  for (i in seq_len(nrow(emisiones))) {
    e <- emisiones[i, ]
    if (!op11_ruta_relativa(e$carpeta_resultados)) stop("Ruta de emision invalida.")
    carpeta <- file.path(raiz, e$carpeta_resultados)
    csv <- file.path(carpeta, "10_pronosticos_proximos_12_meses.csv")
    rds <- file.path(carpeta, "15_modelo_y_pronosticos_actuales.rds")
    if (!all(file.exists(c(csv, rds))) ||
        !identical(unname(tools::md5sum(csv)), e$huella_pronosticos)) stop("No se conserva el archivo original de ", e$ejecucion_id)
    paquete <- readRDS(rds)
    if (!identical(as.character(paquete$diseno$fuente_cierre_md5), cierre_md5) ||
        nrow(paquete$datos_entrenamiento) != e$n_observaciones ||
        as.character(max(as.Date(paquete$datos_entrenamiento$fecha))) != e$ultimo_dato) {
      stop("Los artefactos no corresponden al cierre o a los datos de ", e$ejecucion_id)
    }
    esperado <- motor$op10_pred_db(paquete$pronosticos, e$ejecucion_id, as.Date(e$ultimo_dato))
    guardado <- predicciones[predicciones$ejecucion_id == e$ejecucion_id, ]
    rownames(guardado) <- NULL
    if (!motor$op10_igual_registro(esperado, guardado)) stop("SQLite difiere de los pronosticos originales.")
  }
  list(emisiones = emisiones, predicciones = predicciones)
}
```

### Bloque 4. Recuperar el estado

Se lee `manifiesto_md5.csv`, que enumera los archivos necesarios. Las rutas deben pertenecer al conjunto autorizado, los archivos deben existir y todas sus huellas deben coincidir. También se compara el formato del estado y el cierre estadístico con el de `main`.

Solo después de superar esas comprobaciones se copian los archivos al entorno limpio del proyecto y se valida SQLite. Una base ausente, un manifiesto incompleto o una discrepancia no provocan un reinicio automático del historial.

No se utiliza la caché de paquetes ni un artefacto temporal de Actions como almacenamiento permanente de SQLite.

```r
# 4. Recuperar el estado; ante una perdida nunca inicializar en silencio -------
op11_recuperar <- function(raiz, estado_dir, motor) {
  ruta_manifesto <- file.path(estado_dir, "manifiesto_md5.csv")
  if (!file.exists(ruta_manifesto)) stop("La rama operacion existe pero no contiene un manifiesto completo.")
  m <- utils::read.csv(ruta_manifesto, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  if (!identical(names(m), c("archivo", "md5")) || !nrow(m) ||
      !op11_ruta_relativa(m$archivo) || anyDuplicated(m$archivo) ||
      any(!grepl("^[0-9a-f]{32}$", m$md5))) stop("Manifiesto de estado invalido.")
  permitidos <- grepl("^estado/(database/forecasting\\.sqlite$|data/original/[^/]+\\.xlsx?$|outputs/(operacion_mensual/|evaluacion_predictiva/07_sarima_vs_naive/20261031_171120_23228/))", m$archivo)
  if (!all(permitidos) || !"estado/database/forecasting.sqlite" %in% m$archivo) stop("El manifiesto incluye rutas ajenas al estado previsto.")
  rutas <- file.path(estado_dir, m$archivo)
  if (!all(file.exists(rutas)) || any(dir.exists(rutas)) ||
      any(nzchar(Sys.readlink(rutas))) || any(unname(tools::md5sum(rutas)) != m$md5)) {
    stop("El estado guardado esta incompleto o cambio de contenido. No se reinicia el historial.")
  }
  formato <- readLines(file.path(estado_dir, "formato_estado.txt"), warn = FALSE)
  cierre <- readLines(file.path(estado_dir, "modelo_cierre_md5.txt"), warn = FALSE)
  if (!identical(formato, "estado_operativo_v1") ||
      !identical(cierre, unname(tools::md5sum(file.path(raiz, motor$config10$ruta_cierre))))) {
    stop("El formato o el cierre del modelo cambiaron: revisar expresamente antes de migrar el estado.")
  }
  op11_copiar(file.path(estado_dir, "estado"), raiz, sub("^estado/", "", m$archivo))
  op11_validar_base(raiz, motor)
}
```

### Bloque 5. Inicialización única

La primera vez no existe una rama operativa. El script reconstruye la tabla analítica usando el Excel ya publicado `remision_a_planta_inale_2026-10-29.xls`, el lector del 10 y el SQL analítico existente. Antes compara esa serie con los datos del pronóstico original del 07.

Después ejecuta los scripts 08 y 09 para crear las tablas de pronósticos y registrar exactamente la corrida revisada. No calcula nuevamente el backtesting ni vuelve a estimar la emisión inicial.

Esta inicialización produce la misma información observada y los mismos pronósticos que se registraron localmente. No pretende copiar de forma idéntica todos los bytes del archivo SQLite de Windows: algunos sellos de carga y la huella del CSV de trabajo pueden depender del entorno. A partir del primer estado guardado sí se recuperan los mismos archivos, con sus bytes y huellas conservados.

El nombre concreto del Excel y el identificador de corrida son deliberados: el arranque debe corresponder a una emisión revisada, no elegir silenciosamente cualquier archivo reciente.

```r
# 5. Arranque unico desde los datos y pronosticos historicos publicados --------
op11_inicializar <- function(raiz, motor) {
  excel <- file.path(raiz, "data", "original", "remision_a_planta_inale_2026-10-29.xls")
  carpeta07 <- file.path(raiz, "outputs", "evaluacion_predictiva", "07_sarima_vs_naive", "20261031_171120_23228")
  if (!file.exists(excel)) stop("Falta el Excel original de la emision inicial.")
  preparado <- motor$op10_leer_excel(list(ruta = excel))
  referencia <- readRDS(file.path(carpeta07, "15_modelo_y_pronosticos_actuales.rds"))
  if (!motor$op10_misma_serie(preparado$datos, referencia$datos_entrenamiento)) {
    stop("La fuente inicial no reproduce los datos de los pronosticos originales.")
  }
  dir.create(file.path(raiz, "database"), showWarnings = FALSE)
  con <- DBI::dbConnect(RSQLite::SQLite(), file.path(raiz, "database", "forecasting.sqlite"))
  tryCatch(DBI::dbWithTransaction(con, motor$op10_actualizar_tablas(con, preparado$staging,
    file.path(raiz, "sql", "01_crear_tabla_analitica.sql"))), finally = DBI::dbDisconnect(con))
  # Reutilizar los scripts 08/09: crean tablas y registran exactamente la corrida revisada.
  sys.source(file.path(raiz, "R", "08_preparar_persistencia_sqlite.R"), envir = motor)
  sys.source(file.path(raiz, "R", "09_registrar_pronosticos_sqlite.R"), envir = motor)
  op11_validar_base(raiz, motor)
}
```

### Bloque 6. MAE y RMSE del seguimiento real

La consulta hace un `LEFT JOIN` entre los pronósticos registrados y los observados actuales, por fecha objetivo. Agrupa por modelo y horizonte. `COUNT(a.remision_litros)` cuenta únicamente errores evaluables; `AVG()` ignora los valores ausentes.

Se calcula MAE como el promedio del error absoluto y RMSE como la raíz del promedio del error al cuadrado. Ambos se expresan en litros. No hay pruebas de significación ni selección automática de modelos en este bloque.

Cuando no llegó ningún mes objetivo, la cantidad es cero y las métricas son `NA`; los CSV dejan las celdas vacías y el HTML dice “Pendiente”. No se rellenan con cero.

Se conservan doce filas por modelo, para los horizontes 1 a 12. Si una revisión de datos genera dos emisiones para un mismo origen, ambas permanecen en el historial y cuentan como pronósticos distintos. La cantidad de errores no debe confundirse con observaciones independientes. Las revisiones posteriores de INALE pueden cambiar los errores calculados contra el observado vigente.

Este seguimiento solo incluye emisiones registradas en SQLite. Los 166 orígenes del backtesting condicionado del 07 no se mezclan con estos errores operativos.

```r
# 6. Metricas del seguimiento real, distintas del backtesting del 07 -----------
op11_metricas <- function(raiz) {
  con <- DBI::dbConnect(RSQLite::SQLite(), file.path(raiz, "database", "forecasting.sqlite"))
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  m <- DBI::dbGetQuery(con, paste(
    "SELECT p.modelo, p.h, COUNT(a.remision_litros) AS n_errores,",
    "AVG(ABS(a.remision_litros - p.pred_media)) AS MAE_litros,",
    "AVG((a.remision_litros - p.pred_media) * (a.remision_litros - p.pred_media)) AS MSE_litros",
    "FROM forecast_pronosticos p LEFT JOIN analitica_remision_mensual a ON a.fecha = p.fecha_objetivo",
    "GROUP BY p.modelo, p.h ORDER BY p.modelo, p.h"))
  if (nrow(m) != 24L) stop("Se requieren los doce horizontes de los dos modelos.")
  m$RMSE_litros <- sqrt(m$MSE_litros); m$MSE_litros <- NULL
  m$estado <- ifelse(m$n_errores == 0L, "Sin observaciones evaluables", "Con observaciones")
  carpeta <- file.path(raiz, "outputs", "reportes")
  utils::write.csv(m, file.path(carpeta, "metricas_operativas.csv"), row.names = FALSE, na = "", fileEncoding = "UTF-8")
  numero <- function(x) ifelse(is.na(x), "Pendiente", format(round(x), big.mark = ".", decimal.mark = ",", scientific = FALSE, trim = TRUE))
  filas <- paste0("<tr><td>", m$modelo, "</td><td>", m$h, "</td><td>", m$n_errores,
    "</td><td>", numero(m$MAE_litros), "</td><td>", numero(m$RMSE_litros), "</td></tr>")
  html <- paste0('<!doctype html><html lang="es"><meta charset="UTF-8"><title>Seguimiento predictivo real</title>',
    '<style>body{max-width:1000px;margin:35px auto;padding:0 18px;font:16px/1.6 system-ui;color:#162d36}',
    'table{border-collapse:collapse;width:100%}th,td{border-bottom:1px solid #ddd;padding:8px;text-align:right}',
    'th:first-child,td:first-child{text-align:left}</style><h1>Seguimiento predictivo real</h1>',
    '<p><a href="index.html">Historial</a> · <a href="pronostico_actual.html">Reporte actual</a> · ',
    '<a href="metricas_operativas.csv">Descargar CSV</a></p>',
    '<p>MAE y RMSE en litros, por modelo y horizonte (1 a 12 meses). Solo se incluyen pronósticos registrados cuyo mes objetivo ya tiene un observado.</p>',
    '<p>Sin observados, las métricas permanecen vacías; cero errores evaluables no significa error de predicción cero. ',
    'Se cuentan emisiones: dos versiones emitidas para un mismo origen se conservan como pronósticos distintos. ',
    'Los observados son la versión vigente del INALE; sus revisiones pueden cambiar estas métricas. ',
    'Este seguimiento no incluye las predicciones retrospectivas del script 07.</p>',
    '<table><thead><tr><th>Modelo</th><th>Horizonte</th><th>Errores evaluables</th><th>MAE</th><th>RMSE</th></tr></thead><tbody>',
    paste(filas, collapse = "\n"), '</tbody></table></html>')
  writeLines(html, file.path(carpeta, "metricas_operativas.html"), useBytes = TRUE)
  m
}
```

### Bloque 7. Guardar el estado y preparar los reportes públicos

Se copian SQLite, los Excel originales, cuatro artefactos necesarios de la emisión inicial y los controles completos del ciclo 10. El manifiesto se genera con las huellas de las copias y se comprueba otra vez antes de devolver el control al workflow.

`.gitattributes` declara `estado/** -text` después de las reglas generales. Ese orden evita que Git convierta los saltos de línea CRLF/LF de archivos cuyas huellas ya están registradas. Las conversiones de texto no deben invalidar el historial al pasar entre Windows y Linux.

A `publico/` se copian los reportes HTML y CSV, no SQLite ni los modelos RDS. El índice incorpora un enlace al resumen de métricas. La base de la rama operativa sigue siendo pública porque el repositorio lo es y contiene únicamente información pública y resultados de este proyecto.

`ultima_comprobacion.csv` registra la hora UTC, el commit de código, el identificador de Actions, la emisión vigente y si hubo nuevos meses, revisiones o una emisión nueva. La ejecución mensual sin novedades también actualiza el control de consulta, aunque no agrega pronósticos a SQLite.

```r
# 7. Guardar un estado completo y preparar exclusivamente los reportes publicos
op11_guardar <- function(raiz, estado_dir, motor, resultado, metricas) {
  inicial <- file.path("outputs", "evaluacion_predictiva", "07_sarima_vs_naive", "20261031_171120_23228")
  originales <- list.files(file.path(raiz, "data", "original"), pattern = "\\.xlsx?$", full.names = FALSE)
  controles <- list.files(file.path(raiz, "outputs", "operacion_mensual"), recursive = TRUE, full.names = FALSE)
  archivos <- c("database/forecasting.sqlite", file.path("data/original", originales),
    file.path(inicial, c("00_diseno_evaluacion.csv", "10_pronosticos_proximos_12_meses.csv",
      "15_modelo_y_pronosticos_actuales.rds", "16_objeto_evaluacion07.rds")),
    file.path("outputs/operacion_mensual", controles))
  archivos <- sort(unique(gsub("\\\\", "/", archivos)))
  op11_copiar(raiz, file.path(estado_dir, "estado"), archivos)
  # -text evita conversiones CRLF/LF en los archivos que tienen huellas registradas.
  writeLines(c("*.csv text eol=lf", "*.txt text eol=lf", "publico/** text eol=lf", "estado/** -text"),
    file.path(estado_dir, ".gitattributes"))
  writeLines("estado_operativo_v1", file.path(estado_dir, "formato_estado.txt"))
  writeLines(unname(tools::md5sum(file.path(raiz, motor$config10$ruta_cierre))),
    file.path(estado_dir, "modelo_cierre_md5.txt"))
  manifiesto <- data.frame(archivo = paste0("estado/", archivos),
    md5 = unname(tools::md5sum(file.path(estado_dir, "estado", archivos))))
  utils::write.csv(manifiesto, file.path(estado_dir, "manifiesto_md5.csv"), row.names = FALSE, fileEncoding = "UTF-8")
  publico <- file.path(estado_dir, "publico")
  dir.create(publico, showWarnings = FALSE)
  reportes <- list.files(file.path(raiz, "outputs", "reportes"), recursive = TRUE, full.names = FALSE)
  op11_copiar(file.path(raiz, "outputs", "reportes"), publico, reportes)
  indice <- file.path(publico, "index.html")
  html <- paste(readLines(indice, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  html <- sub("<h1>Emisiones de pronósticos</h1>", paste0('<h1>Emisiones de pronósticos</h1>',
    '<p><a href="metricas_operativas.html">MAE y RMSE del seguimiento real</a></p>'), html, fixed = TRUE)
  writeLines(html, indice, useBytes = TRUE)
  writeLines("", file.path(publico, ".nojekyll"))
  control <- data.frame(comprobacion_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    commit_codigo = Sys.getenv("GITHUB_SHA", unset = "prueba_local"),
    corrida_actions = Sys.getenv("GITHUB_RUN_ID", unset = "prueba_local"),
    origen = as.character(resultado$origen), meses = resultado$n_observaciones,
    emision_actual = resultado$ejecucion_pronostico, emision_nueva = resultado$emision_nueva,
    meses_nuevos = resultado$nuevos_meses, revisiones_litros = resultado$revisiones_litros,
    errores_evaluables = sum(metricas$n_errores), stringsAsFactors = FALSE)
  utils::write.csv(control, file.path(estado_dir, "ultima_comprobacion.csv"), row.names = FALSE, fileEncoding = "UTF-8")
  writeLines(c("# Estado operativo del forecasting de remision de leche", "",
    "Esta rama la actualiza el workflow mensual. El codigo y la documentacion se mantienen en main.", "",
    "- estado/: SQLite y archivos necesarios para continuar el historial.",
    "- publico/: reportes HTML/CSV que publica GitHub Pages; no contiene SQLite.",
    "- manifiesto_md5.csv: control de integridad de los archivos de estado.",
    "- ultima_comprobacion.csv: fecha, codigo utilizado y resultado del ultimo ciclo.", "",
    "No modificar a mano, borrar ni reinicializar esta rama para resolver un error.",
    "La base de esta rama contiene exclusivamente datos publicos y resultados del proyecto."),
    file.path(estado_dir, "README.md"))
  # Comprobar otra vez los bytes guardados antes de que el workflow haga commit.
  if (any(unname(tools::md5sum(file.path(estado_dir, manifiesto$archivo))) != manifiesto$md5)) stop("El respaldo no reproduce los archivos confirmados.")
  invisible(control)
}
```

### Bloque 8. Coordinación y punto de entrada

Primero se verifican dependencias y directorios separados. Si hay una base local, el script se detiene para no sobrescribirla. Si existe un estado completo, lo recupera; si no existe, solo admite la inicialización expresamente habilitada sobre un directorio nuevo.

Después llama al ciclo 10 con su configuración vigente, valida la base resultante y comprueba que las predicciones anteriores sigan iguales. Finalmente calcula las métricas y prepara el respaldo completo.

`archivo_local` es un argumento para pruebas controladas fuera de Actions. No se ofrece como entrada del workflow y se rechaza si `GITHUB_ACTIONS=true`. De ese modo, la ejecución publicada consulta la fuente real y no admite que una prueba sustituya accidentalmente a INALE.

La última línea ejecuta la función al usar `source()`, igual que los otros scripts. En GitHub Actions las variables y la copia limpia ya están preparadas cuando se alcanza esa línea.

```r
# 8. Punto de entrada: primero recuperar, despues ejecutar 10 y guardar --------
ejecutar_operacion11 <- function(raiz = getwd(), estado_dir = Sys.getenv("FORECAST_ESTADO_DIR"),
    inicializar = identical(Sys.getenv("FORECAST_INICIALIZAR"), "true"), archivo_local = NULL) {
  for (p in c("DBI", "RSQLite", "readxl", "cellranger", "forecast")) {
    if (!requireNamespace(p, quietly = TRUE)) stop("Falta la dependencia ", p, "; restaurar renv.")
  }
  raiz <- normalizePath(raiz, winslash = "/", mustWork = TRUE)
  if (!nzchar(estado_dir) || !dir.exists(estado_dir)) stop("FORECAST_ESTADO_DIR debe indicar un directorio preparado para la rama operacion.")
  estado_dir <- normalizePath(estado_dir, winslash = "/", mustWork = TRUE)
  if (identical(estado_dir, raiz) || startsWith(estado_dir, paste0(raiz, "/")) ||
      startsWith(raiz, paste0(estado_dir, "/"))) stop("El estado debe estar en un directorio separado del checkout de codigo.")
  if (file.exists(file.path(raiz, "database", "forecasting.sqlite"))) {
    stop("Este punto de entrada requiere un checkout limpio sin SQLite. No sobrescribe tu base local; usa el script 10 para la operacion local.")
  }
  if (!is.null(archivo_local) && identical(Sys.getenv("GITHUB_ACTIONS"), "true")) stop("Actions no admite una fuente de prueba local.")
  anterior_wd <- getwd(); on.exit(setwd(anterior_wd), add = TRUE); setwd(raiz)
  motor <- op11_cargar10(raiz)
  hay_estado <- file.exists(file.path(estado_dir, "manifiesto_md5.csv"))
  cat("\nSCRIPT 11 — OPERACION EN GITHUB ACTIONS\n")
  if (hay_estado) {
    cat("Recuperando el estado confirmado de la rama operacion...\n")
    antes <- op11_recuperar(raiz, estado_dir, motor)
  } else {
    restos <- list.files(estado_dir, all.files = TRUE, no.. = TRUE)
    if (!inicializar || any(!restos %in% c(".git"))) stop("No hay un estado valido. La inicializacion solo se admite expresamente en un directorio nuevo; no se reinicia el historial.")
    cat("Inicializacion unica desde los archivos publicados; sin ejecutar 06/07.\n")
    antes <- op11_inicializar(raiz, motor)
  }
  cfg <- motor$config10; cfg$raiz <- raiz; cfg$archivo_local <- archivo_local
  resultado <- motor$ejecutar_ciclo10(cfg)
  if (!isTRUE(resultado$finalizado)) stop("El ciclo 10 no finalizo.")
  despues <- op11_validar_base(raiz, motor)
  viejas <- despues$predicciones[despues$predicciones$ejecucion_id %in% antes$emisiones$ejecucion_id, ]
  rownames(viejas) <- NULL
  if (!motor$op10_igual_registro(antes$predicciones, viejas)) stop("Cambio una prediccion anterior: no se publica el estado.")
  metricas <- op11_metricas(raiz)
  control <- op11_guardar(raiz, estado_dir, motor, resultado, metricas)
  cat("\nEstado completo preparado. El workflow debe confirmar y publicar la rama operacion.\n")
  cat("Emisiones:", nrow(despues$emisiones), "| Pronosticos:", nrow(despues$predicciones), "\n")
  cat("Reporte publico preparado; la publicacion real requiere el paso GitHub Pages.\n")
  print(metricas, row.names = FALSE)
  invisible(list(finalizado = TRUE, operacion10 = resultado, control = control, metricas = metricas))
}

# source() ejecuta la unidad completa en el directorio preparado por el workflow.
operacion11 <- ejecutar_operacion11()
```

## Comprobaciones realizadas y alcance de la evidencia

Pruebas realizadas en un entorno temporal, separado del repositorio del usuario:

| Caso | Resultado observado |
| --- | --- |
| Inicialización con el Excel y los RDS reales publicados | 297 meses; una emisión y 24 pronósticos originales |
| Recuperación en un directorio nuevo, mismos datos | Sin reestimación; una emisión y 24 pronósticos |
| Incorporación de octubre de 2026 simulado, solo para la prueba | 298 meses; dos emisiones y 48 pronósticos |
| Seguimiento de la primera emisión al llegar ese mes simulado | Un error evaluable por modelo a h=1; MAE y RMSE coinciden con el error absoluto esperado |
| Repetición de la información ampliada | No duplica la segunda emisión |
| Predicciones de la primera emisión después de ampliar la muestra | Se conservan sin alteración |
| Archivo de estado alterado | Se rechaza antes de recuperar la base |
| Ausencia de estado sin inicialización habilitada | Se detiene; no reinicia el historial |
| Ejecución sobre un directorio con SQLite | Se detiene; no sobrescribe la base local |
| Commit y clon Git locales, con `core.autocrlf=true` y un archivo CRLF | Conserva todas las huellas; la recuperación posterior no agrega emisiones |

El mes simulado y las bases de prueba no se incluyen en la entrega ni se publican. La prueba del núcleo R se hizo con el runtime técnico disponible (R 4.3.3 y forecast 8.21.1); el workflow prepara R 4.6.1 y las versiones de `renv.lock`. La compatibilidad operativa del entorno remoto se confirmó después en las dos ejecuciones manuales descritas abajo, con R 4.6.1 y restauración de renv correcta.

Verificación del 1 de noviembre de 2026, con código `bb559f0`:

| Ejecución de Actions | Resultado | Evidencia |
|---|---|---|
| [41257750531](https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy/actions/runs/41257750531) | Cancelada a los 45 minutos | Bloqueo en `apt-get update`, durante la preparación de R; no ejecutó el ciclo R ni escribió estado remoto. |
| [41262543730](https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy/actions/runs/41262543730) | `actualizar` y `publicar` correctos | Inicialización explícita desde los archivos publicados; 297 meses, una emisión y 24 pronósticos; sin novedades de INALE. |
| [41262927931](https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy/actions/runs/41262927931) | `actualizar` y `publicar` correctos | `FORECAST_INICIALIZAR=false`; recuperó `operacion`, conservó la misma emisión y 24 pronósticos, sin reestimar ni duplicar. |

La primera ejecución correcta guardó `operacion` en `a4327b1`; la segunda avanzó a `6ea765f`. Su control quedó en `ultima_comprobacion.csv`, a las 01:54:38 UTC del 1 de noviembre de 2026 (02:54:38 en Madrid): origen septiembre de 2026, 297 meses, emisión `20261031_171120_23228`, cero meses nuevos, cero revisiones y cero errores evaluables. Son consultas reales a INALE; no se añadieron meses simulados al estado publicado.

Daniel abrió el reporte público, el historial y las métricas y aportó capturas. Los reales y las diferencias continúan pendientes porque no se dispone de observados para octubre de 2026 en adelante. MAE y RMSE pendientes no equivalen a errores cero.

El calendario mensual está configurado para el día 1 a las 09:17, zona `Europe/Madrid`. Estas comprobaciones fueron manuales: el primer disparo programado y la primera actualización con nuevos datos reales permanecen pendientes de observación.

## Límites y recuperación

SQLite confirma datos y pronósticos mediante la transacción del 10. El guardado de archivos, el commit y Pages son pasos separados; no se afirma que formen una única transacción.

Si el ciclo R falla antes del commit, se conserva el estado remoto anterior. Si el estado se publica en `operacion` pero falla Pages, el estado actualizado queda conservado y la web puede seguir mostrando la versión anterior hasta que se repita la publicación. No borrar la rama ni inicializar otra vez para resolver un error.

Para sincronizar una copia local con la operación remota habrá que recuperar tanto SQLite como los archivos del manifiesto. No copiar solamente la base. El script 10 local continúa siendo utilizable, pero una ejecución local no sube automáticamente su estado a la rama operativa.

El cambio de especificación o versión del modelo exige una revisión expresa y una migración documentada. No se programa una nueva selección automática del 06.

## Documentos relacionados

- `docs/R/10_actualizacion_pronosticos.md`: ciclo local, estimación y reportes.
- `docs/sql/02_persistencia_pronosticos.md`: estructura SQLite y registro inicial.
- `docs/github_actions/01_actualizacion_mensual.md`: workflow completo y activación.
- `docs/git/08_automatizacion_sincronizacion.md`: publicación del código y puntos de control.
