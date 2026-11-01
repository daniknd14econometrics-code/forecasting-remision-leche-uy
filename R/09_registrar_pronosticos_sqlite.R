# ============================================================================
# SCRIPT 09 — REGISTRAR LA CORRIDA REVISADA DEL 07 EN SQLITE
# Desde la raiz del proyecto:
#   source("R/09_registrar_pronosticos_sqlite.R", encoding = "UTF-8")
# Requiere las tablas creadas por el 08 y los archivos originales de esta corrida.
# Una ejecucion y 12 pronosticos por modelo. No estima ni ejecuta 06/07.
# Repetir una carga identica no duplica ni reemplaza registros.
# Explicacion: docs/DATOS_Y_SQL.md
# ============================================================================

registrar_pronosticos09 <- function(
    raiz = getwd(),
    carpeta_corrida = file.path("outputs", "evaluacion_predictiva",
      "07_sarima_vs_naive", "20261031_171120_23228"),
    version_modelo = "SARIMA_06_v1") {

  # 1. Dependencias y archivos concretos: no se elige otra corrida en silencio --
  for (paquete in c("DBI", "RSQLite")) {
    if (!requireNamespace(paquete, quietly = TRUE)) stop("Falta el paquete ", paquete)
  }
  raiz <- normalizePath(raiz, winslash = "/", mustWork = TRUE)
  carpeta <- normalizePath(file.path(raiz, carpeta_corrida), winslash = "/", mustWork = TRUE)
  if (!startsWith(carpeta, paste0(raiz, "/"))) stop("La corrida debe estar dentro del proyecto.")
  carpeta_relativa <- substring(carpeta, nchar(raiz) + 2L)
  ejecucion_id <- basename(carpeta)
  if (length(version_modelo) != 1L || is.na(version_modelo) || !nzchar(trimws(version_modelo))) {
    stop("Se requiere una version documentada de la especificacion.")
  }
  rutas <- file.path(carpeta, c("00_diseno_evaluacion.csv",
    "10_pronosticos_proximos_12_meses.csv", "16_objeto_evaluacion07.rds"))
  ruta_bd <- file.path(raiz, "database", "forecasting.sqlite")
  if (!all(file.exists(c(rutas, ruta_bd)))) stop("Faltan archivos de la corrida o la base existente.")
  huella <- unname(tools::md5sum(rutas[2]))
  diseno <- utils::read.csv(rutas[1], stringsAsFactors = FALSE, check.names = FALSE,
    fileEncoding = "UTF-8")
  csv <- utils::read.csv(rutas[2], stringsAsFactors = FALSE, check.names = FALSE,
    fileEncoding = "UTF-8")
  objeto <- readRDS(rutas[3])
  futuro <- objeto[["futuro", exact = TRUE]]
  datos <- futuro[["datos_entrenamiento", exact = TRUE]]
  diseno_rds <- objeto[["diseno", exact = TRUE]]
  momento <- objeto[["fecha_ejecucion", exact = TRUE]]
  if (!isTRUE(objeto[["finalizado", exact = TRUE]]) || !is.data.frame(datos) ||
      !is.data.frame(diseno_rds) || !inherits(momento, "POSIXt") ||
      length(momento) != 1L || !is.finite(as.numeric(momento))) {
    stop("El RDS no acredita una corrida finalizada con datos y fecha de ejecucion.")
  }

  # 2. Comprobar el periodo usado por la corrida, no el maximo actual de SQLite -
  fechas_mensuales <- function(x, etiqueta) {
    texto <- as.character(x)
    fechas <- tryCatch(as.Date(texto, format = "%Y-%m-%d"), error = function(e) NA)
    if (anyNA(fechas) || length(fechas) != length(texto) ||
        any(format(fechas, "%Y-%m-%d") != texto) || any(format(fechas, "%d") != "01")) {
      stop("Fechas mensuales invalidas en ", etiqueta)
    }
    fechas
  }
  if (!all(c("fecha", "remision_litros") %in% names(datos)) || !nrow(datos)) {
    stop("El RDS no contiene la historia observada de entrenamiento.")
  }
  fechas <- fechas_mensuales(datos$fecha, "datos de entrenamiento")
  if (fechas[1] != as.Date("2002-01-01") ||
      !identical(as.character(fechas), as.character(seq(fechas[1], by = "month", length.out = nrow(datos)))) ||
      !is.numeric(datos$remision_litros) || any(!is.finite(datos$remision_litros)) ||
      any(datos$remision_litros <= 0)) stop("La historia debe ser mensual, completa y positiva desde enero de 2002.")
  origen <- tail(fechas, 1L)
  columnas_diseno <- c("modelo", "inicio_serie", "fin_serie", "horizonte_max", "fuente_cierre_md5")
  if (nrow(diseno) != 1L || nrow(diseno_rds) != 1L ||
      !all(columnas_diseno %in% names(diseno)) || !all(columnas_diseno %in% names(diseno_rds))) {
    stop("Diseno de evaluacion incompleto.")
  }
  for (campo in columnas_diseno) {
    if (!identical(as.character(diseno[[campo]]), as.character(diseno_rds[[campo]]))) {
      stop("El diseno CSV y el RDS discrepan en ", campo)
    }
  }
  if (is.na(diseno$modelo[1]) || !nzchar(diseno$modelo[1]) ||
      is.na(diseno$horizonte_max[1]) || diseno$horizonte_max[1] != 12L ||
      !identical(as.character(diseno$inicio_serie), as.character(fechas[1])) ||
      !identical(as.character(diseno$fin_serie), as.character(origen))) {
    stop("El periodo o el horizonte del diseno no coincide con el entrenamiento.")
  }

  # 3. Validar las dos trayectorias completas y contrastar CSV frente a RDS -----
  numeros <- c("pred_media", "pred_mediana", "inferior80", "superior80", "inferior95", "superior95")
  columnas_fuente <- c("modelo", "origen", "fecha", "h", numeros)
  normalizar <- function(x) {
    if (!is.data.frame(x) || !all(columnas_fuente %in% names(x)) || nrow(x) != 24L) {
      stop("Se requieren 24 pronosticos y todas sus columnas de origen.")
    }
    x <- x[, columnas_fuente, drop = FALSE]
    x$modelo <- as.character(x$modelo)
    if (anyNA(x$modelo) || !setequal(unique(x$modelo), c("SARIMA", "Naive_estacional"))) {
      stop("Se esperaban exclusivamente SARIMA y Naive_estacional.")
    }
    x$origen <- as.character(fechas_mensuales(x$origen, "origen"))
    x$fecha <- as.character(fechas_mensuales(x$fecha, "fecha objetivo"))
    if (!is.numeric(x$h) || anyNA(x$h) || any(x$h != as.integer(x$h)) ||
        any(x$h < 1L | x$h > 12L)) stop("Horizontes invalidos.")
    x$h <- as.integer(x$h)
    if (any(x$origen != as.character(origen)) || anyDuplicated(x[c("modelo", "h")])) {
      stop("Origen incoherente o claves repetidas.")
    }
    for (modelo in unique(x$modelo)) {
      if (!identical(sort(x$h[x$modelo == modelo]), 1:12)) stop("Falta una trayectoria completa: ", modelo)
    }
    objetivos <- as.character(seq(origen, by = "month", length.out = 13L)[-1L])
    if (any(x$fecha != objetivos[x$h])) stop("Fecha objetivo distinta de origen mas h meses.")
    for (campo in numeros) {
      if (!is.numeric(x[[campo]]) || any(!is.finite(x[[campo]]))) stop("Valores invalidos en ", campo)
      x[[campo]] <- as.double(x[[campo]])
    }
    if (any(x$pred_media <= 0 | x$pred_mediana <= 0) ||
        any(x$inferior95 > x$inferior80 | x$inferior80 > x$superior80 | x$superior80 > x$superior95)) {
      stop("Predicciones no positivas o intervalos mal ordenados.")
    }
    x <- x[order(x$modelo, x$h), , drop = FALSE]
    rownames(x) <- NULL
    x
  }
  iguales <- function(a, b, columnas_numericas = numeros) {
    if (!identical(names(a), names(b)) || nrow(a) != nrow(b)) return(FALSE)
    for (campo in names(a)) {
      if (campo %in% columnas_numericas) {
        if (anyNA(a[[campo]]) || anyNA(b[[campo]]) || any(abs(a[[campo]] - b[[campo]]) > 1e-5)) return(FALSE)
      } else if (!identical(as.character(a[[campo]]), as.character(b[[campo]]))) return(FALSE)
    }
    TRUE
  }
  pred <- normalizar(csv)
  if (!iguales(pred, normalizar(futuro[["pronosticos", exact = TRUE]]))) {
    stop("Los pronosticos CSV no coinciden con los del RDS. No se registra la corrida.")
  }
  if (!identical(huella, unname(tools::md5sum(rutas[2])))) stop("Cambio el archivo durante su lectura.")
  ejecucion <- data.frame(ejecucion_id = ejecucion_id,
    fecha_ejecucion_utc = format(momento, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"),
    inicio_datos = as.character(fechas[1]), ultimo_dato = as.character(origen),
    n_observaciones = as.integer(nrow(datos)), horizonte = 12L, version_modelo = version_modelo,
    especificacion = paste0(diseno$modelo[1], "; log(litros/dias_del_mes)"),
    carpeta_resultados = carpeta_relativa, huella_pronosticos = huella, stringsAsFactors = FALSE)
  names(pred)[names(pred) == "fecha"] <- "fecha_objetivo"
  pred <- cbind(data.frame(ejecucion_id = rep(ejecucion_id, nrow(pred))), pred)

  # 4. Abrir la base preparada y registrar todo en una unica transaccion -------
  con <- DBI::dbConnect(RSQLite::SQLite(), dbname = ruta_bd)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  tablas <- c("analitica_remision_mensual", "forecast_ejecuciones", "forecast_pronosticos")
  if (!all(vapply(tablas, function(x) DBI::dbExistsTable(con, x), logical(1)))) {
    stop("Faltan tablas. Completar primero el script 08.")
  }
  if (!identical(DBI::dbListFields(con, "forecast_ejecuciones"), names(ejecucion)) ||
      !identical(DBI::dbListFields(con, "forecast_pronosticos"), names(pred))) stop("Estructura de tablas incompatible con el 08.")
  DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
  if (DBI::dbGetQuery(con, "PRAGMA foreign_keys")[[1]][1] != 1L) stop("No se activaron las claves foraneas.")
  control_observados <- function() DBI::dbGetQuery(con, paste(
    "SELECT COUNT(*) AS n, MIN(fecha) AS inicio, MAX(fecha) AS fin,",
    "SUM(remision_litros) AS litros FROM analitica_remision_mensual"))
  leer_pronosticos <- function() DBI::dbGetQuery(con, paste(
    "SELECT * FROM forecast_pronosticos WHERE ejecucion_id = ? ORDER BY modelo, h"),
    params = list(ejecucion_id))
  resultado <- DBI::dbWithTransaction(con, {
    antes <- control_observados()
    existente <- DBI::dbGetQuery(con, "SELECT * FROM forecast_ejecuciones WHERE ejecucion_id = ?",
      params = list(ejecucion_id))
    if (nrow(existente)) {
      if (!iguales(ejecucion, existente, character()) || !iguales(pred, leer_pronosticos())) {
        stop("El identificador ya existe con metadatos, archivo o pronosticos distintos. No se reemplaza.")
      }
      estado <- "Ya registrada; sin cambios ni duplicados"
    } else {
      if (nrow(leer_pronosticos())) stop("Existen pronosticos huerfanos con este identificador.")
      DBI::dbAppendTable(con, "forecast_ejecuciones", ejecucion)
      DBI::dbAppendTable(con, "forecast_pronosticos", pred)
      estado <- "Registrada correctamente"
    }
    guardada <- DBI::dbGetQuery(con, "SELECT * FROM forecast_ejecuciones WHERE ejecucion_id = ?",
      params = list(ejecucion_id))
    if (!iguales(ejecucion, guardada, character()) || !iguales(pred, leer_pronosticos())) {
      stop("La lectura de comprobacion no coincide: se revierte toda la carga.")
    }
    if (nrow(DBI::dbGetQuery(con, "PRAGMA foreign_key_check(forecast_pronosticos)"))) {
      stop("Integridad referencial invalida: se revierte la carga.")
    }
    if (!identical(antes, control_observados())) stop("Cambio el control de observados: se revierte la carga.")
    list(estado = estado, datos_observados = antes)
  })

  # 5. Mostrar el registro y los totales, sin generar nuevas predicciones -------
  resumen <- DBI::dbGetQuery(con, paste(
    "SELECT modelo, COUNT(*) AS filas, MIN(h) AS h_min, MAX(h) AS h_max,",
    "MIN(fecha_objetivo) AS desde, MAX(fecha_objetivo) AS hasta",
    "FROM forecast_pronosticos WHERE ejecucion_id = ? GROUP BY modelo ORDER BY modelo"),
    params = list(ejecucion_id))
  conteos <- DBI::dbGetQuery(con, paste(
    "SELECT 'forecast_ejecuciones' AS tabla, COUNT(*) AS filas FROM forecast_ejecuciones",
    "UNION ALL SELECT 'forecast_pronosticos', COUNT(*) FROM forecast_pronosticos"))
  cat("\nREGISTRO 09 — PRONOSTICOS EN SQLITE\n")
  cat("Corrida:", ejecucion_id, "|", resultado$estado, "\n")
  cat("Datos utilizados:", ejecucion$inicio_datos, "a", ejecucion$ultimo_dato,
    "| Meses:", ejecucion$n_observaciones, "\n")
  print(resumen, row.names = FALSE)
  cat("\nTotales de las tablas:\n")
  print(conteos, row.names = FALSE)
  cat("\nDatos observados conservados:\n")
  print(resultado$datos_observados, row.names = FALSE)
  cat("\nSe conservaron los pronosticos originales. No se reestimo ni se ejecuto 06/07.\n")
  invisible(c(resultado, list(ejecucion = ejecucion, resumen = resumen,
    conteos = conteos, registro_completado = TRUE)))
}

# source() registra la corrida indicada en los argumentos predeterminados.
registro09 <- registrar_pronosticos09()
