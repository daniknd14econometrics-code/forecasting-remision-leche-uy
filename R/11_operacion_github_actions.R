# ============================================================================
# SCRIPT 11 — CONTINUIDAD DEL ESTADO Y REPORTES PARA GITHUB ACTIONS
# Lo llama .github/workflows/actualizar_pronosticos.yml desde la raiz.
# FORECAST_ESTADO_DIR: directorio de trabajo de la rama operacion.
# FORECAST_INICIALIZAR=true: solo en la primera ejecucion manual sin estado.
# No modifica ni ejecuta la seleccion del 06 ni el backtesting del 07.
# Documentacion: docs/REPRODUCCION_Y_OPERACION.md
# ============================================================================

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
