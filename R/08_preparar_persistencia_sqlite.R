# ============================================================================
# SCRIPT 08 — PRIMER PASO DE PERSISTENCIA: PREPARAR DOS TABLAS EN SQLITE
# Ejecutar desde la raiz del proyecto:
#   source("R/08_preparar_persistencia_sqlite.R", encoding = "UTF-8")
#
# Crea forecast_ejecuciones y forecast_pronosticos, y comprueba su estructura.
# Todavia no inserta la corrida del 07 ni genera nuevas predicciones.
# No ejecuta 06/07 ni cambia las tablas de datos observados.
# Explicacion: docs/sql/02_persistencia_pronosticos.md
# ============================================================================

preparar_persistencia08 <- function(raiz = getwd()) {
  # 1. Dependencias y rutas --------------------------------------------------
  paquetes <- c("DBI", "RSQLite")
  faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
  if (length(faltan)) stop("Faltan paquetes: ", paste(faltan, collapse = ", "))
  raiz <- normalizePath(raiz, winslash = "/", mustWork = TRUE)
  ruta_bd <- file.path(raiz, "database", "forecasting.sqlite")
  ruta_sql <- file.path(raiz, "sql", "02_crear_tablas_pronosticos.sql")
  if (!file.exists(ruta_bd) || !file.exists(ruta_sql)) {
    stop("Se requieren la base existente y sql/02_crear_tablas_pronosticos.sql. Ejecutar desde la raiz.")
  }

  # 2. Leer este archivo SQL sencillo (sin triggers ni literales con ;) -------
  lineas <- readLines(ruta_sql, encoding = "UTF-8", warn = FALSE)
  lineas <- lineas[!grepl("^\\s*--", lineas)]
  sentencias <- trimws(strsplit(paste(lineas, collapse = "\n"), ";", fixed = TRUE)[[1]])
  sentencias <- sentencias[nzchar(sentencias)]
  if (length(sentencias) != 2L ||
      !all(grepl("^CREATE TABLE IF NOT EXISTS", sentencias))) {
    stop("Se esperaban exclusivamente las dos instrucciones de creacion de tablas.")
  }

  # 3. Conectar a una base existente y activar integridad referencial ---------
  con <- DBI::dbConnect(RSQLite::SQLite(), dbname = ruta_bd)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  if (!DBI::dbExistsTable(con, "analitica_remision_mensual")) {
    stop("La base no contiene la tabla analitica del proyecto.")
  }
  DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
  if (DBI::dbGetQuery(con, "PRAGMA foreign_keys")[[1]][1] != 1L) {
    stop("No se pudo activar el control de claves foraneas.")
  }
  antes <- DBI::dbGetQuery(con, paste(
    "SELECT COUNT(*) AS n, MIN(fecha) AS inicio, MAX(fecha) AS fin,",
    "SUM(remision_litros) AS litros FROM analitica_remision_mensual"
  ))
  esperado <- list(
    forecast_ejecuciones = c("ejecucion_id", "fecha_ejecucion_utc", "inicio_datos",
      "ultimo_dato", "n_observaciones", "horizonte", "version_modelo",
      "especificacion", "carpeta_resultados", "huella_pronosticos"),
    forecast_pronosticos = c("ejecucion_id", "modelo", "origen", "fecha_objetivo",
      "h", "pred_media", "pred_mediana", "inferior80", "superior80", "inferior95", "superior95")
  )

  # 4. Crear ambas tablas como una unidad. Ante error se revierte ------------
  DBI::dbWithTransaction(con, {
    for (sql in sentencias) DBI::dbExecute(con, sql)
    for (tabla in names(esperado)) {
      if (!identical(DBI::dbListFields(con, tabla), esperado[[tabla]])) {
        stop("Estructura distinta en ", tabla, ". No se modifica una tabla existente.")
      }
    }
    relacion <- DBI::dbGetQuery(con, "PRAGMA foreign_key_list(forecast_pronosticos)")
    if (nrow(relacion) != 1L || relacion$table[1] != "forecast_ejecuciones" ||
        relacion$from[1] != "ejecucion_id" || relacion$to[1] != "ejecucion_id") {
      stop("La relacion entre pronosticos y ejecuciones no es la prevista.")
    }
    despues <- DBI::dbGetQuery(con, paste(
      "SELECT COUNT(*) AS n, MIN(fecha) AS inicio, MAX(fecha) AS fin,",
      "SUM(remision_litros) AS litros FROM analitica_remision_mensual"
    ))
    if (!isTRUE(all.equal(antes, despues))) stop("Cambio el control de datos observados.")
  })

  # 5. Verificar y mostrar. En la primera ejecucion se esperan 0 y 0 filas ----
  tablas <- DBI::dbGetQuery(con, paste(
    "SELECT name AS tabla FROM sqlite_master WHERE type = 'table'",
    "AND name IN ('forecast_ejecuciones', 'forecast_pronosticos') ORDER BY name"
  ))
  conteos <- DBI::dbGetQuery(con, paste(
    "SELECT 'forecast_ejecuciones' AS tabla, COUNT(*) AS filas FROM forecast_ejecuciones",
    "UNION ALL SELECT 'forecast_pronosticos', COUNT(*) FROM forecast_pronosticos"
  ))
  violaciones <- DBI::dbGetQuery(con, "PRAGMA foreign_key_check(forecast_pronosticos)")
  if (nrow(violaciones)) stop("Existen pronosticos sin una ejecucion valida.")
  cat("\nPERSISTENCIA 08 — TABLAS PREPARADAS\n")
  print(conteos, row.names = FALSE)
  cat("\nDatos observados conservados:\n")
  print(antes, row.names = FALSE)
  cat("\nNo se cargaron pronosticos ni se reestimaron modelos.\n")
  cat("Siguiente paso: registrar la corrida revisada del 07 con sus doce meses completos.\n")
  invisible(list(tablas = tablas, conteos = conteos, datos_observados = antes,
    ruta_bd = ruta_bd, preparacion_completada = TRUE))
}

# source() ejecuta la preparacion completa y devuelve su comprobacion.
persistencia08 <- preparar_persistencia08()
