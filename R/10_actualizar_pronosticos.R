# ============================================================================
# SCRIPT 10 — CICLO LOCAL: DATOS ACTUALES Y SIGUIENTES DOCE MESES
# Desde la raiz: source("R/10_actualizar_pronosticos.R", encoding = "UTF-8")
# Conserva SARIMA(2,1,1)(1,0,0)[12], meses, TC200602 y AO200404.
# Reestima coeficientes solo si no hay una emision con los mismos datos y cierre.
# No ejecuta 06/07, no selecciona ordenes y no reemplaza pronosticos pasados.
# Reporte actual: outputs/reportes/pronostico_actual.html (tambien CSV).
# Historial: outputs/reportes/index.html. Reales y diferencias se actualizan.
# Requiere SQLite preparada por 08 y el cierre del 06. No instala paquetes.
# Documentacion: docs/REPRODUCCION_Y_OPERACION.md
# ============================================================================

config10 <- list(
  raiz = getwd(), archivo_local = NULL,
  pagina_inale = "https://www.inale.org/estadisticas/remision-a-planta/",
  ruta_db = file.path("database", "forecasting.sqlite"),
  ruta_cierre = file.path("outputs", "sarima_box_jenkins", "09_cierre_modelado", "11_objeto_bloque09.rds"),
  ruta_sql = file.path("sql", "01_crear_tabla_analitica.sql"),
  ruta_salidas = file.path("outputs", "operacion_mensual"),
  version_modelo = "SARIMA_06_v1", horizonte = 12L,
  niveles_intervalo = c(80, 95), maxit = 2000L, tolerancia_prediccion = 1e-5)

# 1. Nucleo predictivo: mismas funciones de calculo del 07, con prefijo op10.
# Se incluyen aqui para no ejecutar el backtesting ni modificar el script 07.
op10_csv <- function(x, carpeta, archivo) {
  utils::write.csv(x, file.path(carpeta, archivo), row.names = FALSE,
                  fileEncoding = "UTF-8", na = "")
}

op10_juntar <- function(lista) {
  x <- do.call(rbind, lista)
  rownames(x) <- NULL
  x
}

op10_mes_siguiente <- function(fecha, h = 12L) {
  seq(as.Date(fecha), by = "month", length.out = h + 1L)[-1L]
}

op10_dias_mes <- function(fechas) {
  fechas <- as.Date(fechas)
  siguiente <- as.Date(format(fechas + 32, "%Y-%m-01"))
  as.integer(siguiente - fechas)
}

op10_contrastes <- function(fechas) {
  mes <- factor(as.integer(format(as.Date(fechas), "%m")), levels = 1:12)
  X <- stats::model.matrix(~ mes, contrasts.arg = list(mes = stats::contr.sum(12)))
  X <- X[, -1L, drop = FALSE]
  colnames(X) <- paste0("mes_contraste_", 1:11)
  X
}

op10_diseno <- function(fechas, efectos, delta) {
  fechas <- as.Date(fechas)
  n <- length(fechas)
  M <- op10_contrastes(fechas)
  G <- matrix(0, nrow = n, ncol = nrow(efectos),
              dimnames = list(NULL, as.character(efectos$termino)))
  for (j in seq_len(nrow(efectos))) {
    posicion <- match(as.Date(efectos$fecha[j]), fechas)
    if (is.na(posicion)) stop("Un efecto fijo no pertenece al calendario del ajuste.")
    if (efectos$tipo[j] == "AO") {
      G[posicion, j] <- 1
    } else if (efectos$tipo[j] == "TC") {
      G[posicion:n, j] <- delta^(0:(n - posicion))
    } else stop("Este script admite los efectos AO/TC del cierre revisado.")
  }
  # U tiene diferencias iguales a los contrastes M de cada mes. Permite usar
  # el filtro ARIMA integrado sin cambiar la ecuacion estimada sobre Delta x.
  U <- matrix(0, n, 11L, dimnames = list(NULL, colnames(M)))
  U[-1L, ] <- apply(M[-1L, , drop = FALSE], 2L, cumsum)
  Xnivel <- cbind(U, G)
  Xdif <- cbind(M[-1L, , drop = FALSE],
                G[-1L, , drop = FALSE] - G[-n, , drop = FALSE])
  if (max(abs(diff(Xnivel) - Xdif)) > 1e-10) {
    stop("Los disenos de niveles y diferencias no son equivalentes.")
  }
  list(nivel = Xnivel, diferencia = Xdif)
}

op10_raices <- function(fit) {
  cf <- stats::coef(fit)
  menor <- function(polinomio) {
    while (length(polinomio) > 1L && tail(polinomio, 1L) == 0) {
      polinomio <- head(polinomio, -1L)
    }
    if (length(polinomio) == 1L) Inf else min(Mod(base::polyroot(polinomio)))
  }
  # La raiz unitaria original d=1 no forma parte de estas raices de ARMA.
  c(AR_regular = menor(c(1, -cf[c("ar1", "ar2")])),
    AR_estacional = menor(c(1, rep(0, 11L), -cf["sar1"])),
    MA_regular = menor(c(1, cf["ma1"])))
}

op10_cov_valida <- function(fit) {
  V <- fit[["var.coef", exact = TRUE]]
  is.matrix(V) && nrow(V) == length(stats::coef(fit)) &&
    all(is.finite(V)) && all(diag(V) > 0) &&
    isTRUE(tryCatch({ chol(V); TRUE }, error = function(e) FALSE))
}

op10_estimar <- function(entrenamiento, efectos, delta, cfg, anterior = NULL) {
  n <- nrow(entrenamiento)
  diseno <- op10_diseno(entrenamiento$fecha, efectos, delta)
  y <- stats::ts(diff(entrenamiento$log_diaria), start = c(2002, 2), frequency = 12)
  X <- diseno$diferencia
  if (qr(X)$rank != ncol(X)) stop("Regresores colineales en el origen.")
  beta <- unname(stats::lm.fit(X, as.numeric(y))$coefficients)
  # Todos los inicios usan este entrenamiento o el origen anterior. Nunca se
  # inicializan los origenes historicos con coeficientes estimados hasta 2025.
  inicios <- list(por_defecto = NULL,
                  AR_positivo = c(0.4, -0.1, -0.3, 0.2, beta),
                  AR_negativo = c(-0.4, 0.1, 0.3, 0.2, beta))
  if (!is.null(anterior)) inicios <- c(list(origen_anterior = unname(stats::coef(anterior))), inicios)
  ajustes <- vector("list", length(inicios)); registro <- vector("list", length(inicios))
  for (j in seq_along(inicios)) {
    avisos <- character(); error <- ""
    f <- tryCatch(withCallingHandlers(
      stats::arima(y, order = c(2L, 0L, 1L),
                   seasonal = list(order = c(1L, 0L, 0L), period = 12L),
                   xreg = X, include.mean = FALSE, method = "ML",
                   init = inicios[[j]], optim.control = list(maxit = cfg$maxit)),
      warning = function(w) { avisos <<- c(avisos, conditionMessage(w)); invokeRestart("muffleWarning") }),
      error = function(e) { error <<- conditionMessage(e); NULL })
    ll <- if (is.null(f)) NA_real_ else as.numeric(stats::logLik(f))
    raices <- if (is.null(f)) rep(NA_real_, 3L) else op10_raices(f)
    convergio <- !is.null(f) && isTRUE(f$code == 0L)
    admisible <- convergio && is.finite(ll) && all(is.finite(stats::coef(f))) &&
      is.finite(f$sigma2) && f$sigma2 > 0 && all(raices > 1 + 1e-8)
    registro[[j]] <- data.frame(origen = max(entrenamiento$fecha), inicio = names(inicios)[j],
      convergio = convergio, admisible = admisible, logLik = ll,
      raiz_AR_regular = raices[1L], raiz_AR_estacional = raices[2L],
      raiz_MA_regular = raices[3L], matriz_cov_valida = !is.null(f) && op10_cov_valida(f),
      avisos = paste(unique(avisos), collapse = " | "), error = error,
      stringsAsFactors = FALSE, row.names = NULL)
    if (admisible) ajustes[[j]] <- f
  }
  intentos <- op10_juntar(registro)
  aptos <- which(intentos$admisible)
  if (!length(aptos)) return(list(modelo = NULL, intentos = intentos))
  mejor <- aptos[which.max(intentos$logLik[aptos])]
  fit <- ajustes[[mejor]]
  fit$x <- y; fit$xreg <- X; fit$call$x <- y; fit$call$xreg <- X
  list(modelo = fit, diseno = diseno, intentos = intentos,
       inicio_elegido = intentos$inicio[mejor])
}

op10_pronosticar_sarima <- function(ajuste, entrenamiento, calendario, efectos, delta, cfg) {
  fit <- ajuste$modelo
  n <- nrow(entrenamiento); h <- nrow(calendario)
  fechas <- c(entrenamiento$fecha, calendario$fecha)
  diseno <- op10_diseno(fechas, efectos, delta)
  Xn <- diseno$nivel[seq_len(n), , drop = FALSE]
  Xf <- diseno$nivel[n + seq_len(h), , drop = FALSE]
  Xdf <- diseno$diferencia[(n - 1L) + seq_len(h), , drop = FALSE]
  if (!identical(colnames(Xn), colnames(fit$xreg))) stop("Regresores futuros fuera de orden.")

  # Filtro integrado con TODOS los parametros FIJOS a los estimados sobre
  # Delta log. No se estima un segundo SARIMA ni se cambia de especificacion.
  # predict.Arima calcula la varianza de log-niveles mediante KalmanForecast;
  # sumar varianzas de diferencias omitiria sus covarianzas y seria incorrecto.
  x <- stats::ts(entrenamiento$log_diaria, start = c(2002, 1), frequency = 12)
  filtro <- stats::arima(x, order = c(2L, 1L, 1L),
    seasonal = list(order = c(1L, 0L, 0L), period = 12L),
    xreg = Xn, include.mean = FALSE, fixed = unname(stats::coef(fit)),
    transform.pars = FALSE, method = "ML")
  filtro$sigma2 <- fit$sigma2
  filtro$x <- x; filtro$xreg <- Xn; filtro$call$x <- x; filtro$call$xreg <- Xn
  p <- stats::predict(filtro, n.ahead = h, newxreg = Xf, se.fit = TRUE)
  pd <- stats::predict(fit, n.ahead = h, newxreg = Xdf, se.fit = TRUE)
  mu <- as.numeric(p$pred); se <- as.numeric(p$se)
  reconstruida <- tail(entrenamiento$log_diaria, 1L) + cumsum(as.numeric(pd$pred))
  discrepancia <- max(abs(mu - reconstruida))
  if (any(!is.finite(c(mu, se))) || any(se <= 0) ||
      discrepancia > cfg$tolerancia_prediccion ||
      max(abs(stats::coef(filtro) - stats::coef(fit))) > 1e-12) {
    stop("No se reproduce el pronostico integrado con parametros fijos.")
  }
  dias <- calendario$dias_mes
  z80 <- stats::qnorm(0.90); z95 <- stats::qnorm(0.975)
  tabla <- data.frame(fecha = calendario$fecha, h = seq_len(h), modelo = "SARIMA",
    pred_media = dias * exp(mu + 0.5 * se^2), pred_mediana = dias * exp(mu),
    inferior80 = dias * exp(mu - z80 * se), superior80 = dias * exp(mu + z80 * se),
    inferior95 = dias * exp(mu - z95 * se), superior95 = dias * exp(mu + z95 * se),
    media_log_diaria = mu, se_log_diaria = se)
  list(tabla = tabla, filtro = filtro, regresores_futuros = Xf,
       discrepancia_acumulacion = discrepancia)
}

op10_pronosticar_naive <- function(entrenamiento, calendario) {
  diaria <- stats::ts(entrenamiento$remision_diaria, start = c(2002, 1), frequency = 12)
  p <- forecast::snaive(diaria, h = nrow(calendario), level = c(80, 95))
  dias <- calendario$dias_mes
  valores <- as.numeric(p$mean) * dias
  # Referencia: promedio diario del mismo mes del anio anterior por dias futuros.
  comprobacion <- tail(entrenamiento$remision_diaria, 12L)[seq_len(nrow(calendario))] * dias
  if (max(abs(valores - comprobacion)) > 1e-5) stop("No se reproduce el naive estacional diario.")
  data.frame(fecha = calendario$fecha, h = seq_len(nrow(calendario)),
    modelo = "Naive_estacional", pred_media = valores, pred_mediana = valores,
    inferior80 = as.numeric(p$lower[, "80%"]) * dias,
    superior80 = as.numeric(p$upper[, "80%"]) * dias,
    inferior95 = as.numeric(p$lower[, "95%"]) * dias,
    superior95 = as.numeric(p$upper[, "95%"]) * dias,
    media_log_diaria = NA_real_, se_log_diaria = NA_real_)
}

op10_coeficientes <- function(fit, origen, ejercicio) {
  cf <- stats::coef(fit)
  se <- if (op10_cov_valida(fit)) sqrt(diag(fit$var.coef)) else rep(NA_real_, length(cf))
  data.frame(ejercicio = ejercicio, origen = origen, termino = names(cf),
             estimacion = unname(cf), se_condicional = unname(se))
}

op10_diagnostico <- function(ajuste, entrenamiento, discrepancia, ejercicio) {
  fit <- ajuste$modelo; e <- as.numeric(stats::residuals(fit)); r <- op10_raices(fit)
  lb <- vapply(c(12L, 24L, 36L), function(L)
    stats::Box.test(e, lag = L, type = "Ljung-Box", fitdf = 4L)$p.value, numeric(1L))
  data.frame(ejercicio = ejercicio, origen = max(entrenamiento$fecha),
    n_niveles = nrow(entrenamiento), inicio_elegido = ajuste$inicio_elegido,
    logLik = as.numeric(stats::logLik(fit)), sigma_innovacion = sqrt(fit$sigma2),
    raiz_AR_regular = unname(r[1L]), raiz_AR_estacional = unname(r[2L]),
    raiz_MA_regular = unname(r[3L]), matriz_cov_valida = op10_cov_valida(fit),
    LB12_orientativo = lb[1L], LB24_orientativo = lb[2L], LB36_orientativo = lb[3L],
    discrepancia_acumulacion = discrepancia)
}

op10_futuro <- function(base, cfg, anterior) {
  entrenamiento <- base$datos
  origen <- max(entrenamiento$fecha)
  calendario <- data.frame(fecha = op10_mes_siguiente(origen, cfg$horizonte))
  calendario$dias_mes <- op10_dias_mes(calendario$fecha)
  a <- op10_estimar(entrenamiento, base$efectos, base$delta, cfg, anterior)
  if (is.null(a$modelo)) return(list(modelo = NULL, intentos = a$intentos))
  s <- op10_pronosticar_sarima(a, entrenamiento, calendario, base$efectos, base$delta, cfg)
  p <- rbind(s$tabla, op10_pronosticar_naive(entrenamiento, calendario))
  p$origen <- origen
  p$papel <- ifelse(p$modelo == "SARIMA", "Pronostico_del_modelo_seleccionado", "Referencia")
  p$observado <- NA_real_; p$error <- NA_real_
  list(modelo = a$modelo, filtro_integrado = s$filtro,
       regresores_futuros = s$regresores_futuros, tabla = p,
       coeficientes = op10_coeficientes(a$modelo, origen, "Pronostico_futuro"),
       diagnosticos = op10_diagnostico(a, entrenamiento, s$discrepancia_acumulacion, "Pronostico_futuro"),
       intentos = a$intentos)
}

# 2. Obtener y conservar una copia de la fuente antes de tocar SQLite ----------
op10_fuente <- function(cfg, raiz) {
  carpeta <- file.path(raiz, "data", "original")
  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
  temporal <- tempfile(fileext = ".xls")
  on.exit(unlink(temporal), add = TRUE)
  if (!is.null(cfg$archivo_local)) {
    # Solo para una copia indicada expresamente; util en reproduccion y pruebas.
    entrada <- normalizePath(cfg$archivo_local, winslash = "/", mustWork = TRUE)
    extension <- tolower(tools::file_ext(entrada))
    if (!extension %in% c("xls", "xlsx")) stop("La fuente local debe ser Excel.")
    if (!file.copy(entrada, temporal)) stop("No se pudo leer la copia local.")
    url <- paste0("Archivo local explicito: ", basename(entrada))
  } else {
    anterior <- getOption("timeout")
    options(timeout = max(120, anterior))
    on.exit(options(timeout = anterior), add = TRUE)
    html <- tempfile(fileext = ".html")
    on.exit(unlink(html), add = TRUE)
    utils::download.file(cfg$pagina_inale, html, mode = "wb", quiet = TRUE,
      headers = c("Cache-Control" = "no-cache"))
    texto <- paste(readLines(html, encoding = "UTF-8", warn = FALSE), collapse = "\n")
    patron <- "https?://[^\"'[:space:]<>]+\\.xlsx?(\\?[^\"'[:space:]<>]*)?"
    enlaces <- unique(regmatches(texto, gregexpr(patron, texto, perl = TRUE, ignore.case = TRUE))[[1]])
    if (length(enlaces) != 1L) stop("La pagina INALE debe contener un unico enlace Excel. Revisar la fuente.")
    url <- gsub("&amp;", "&", enlaces[1], fixed = TRUE)
    extension <- if (grepl("\\.xlsx($|\\?)", url, ignore.case = TRUE)) "xlsx" else "xls"
    utils::download.file(url, temporal, mode = "wb", quiet = TRUE,
      headers = c("Cache-Control" = "no-cache"))
  }
  if (!file.exists(temporal) || is.na(file.info(temporal)$size) || file.info(temporal)$size == 0) {
    stop("La descarga o copia esta vacia.")
  }
  huella <- unname(tools::md5sum(temporal))
  previos <- list.files(carpeta, pattern = "^remision_a_planta_inale_.*\\.xlsx?$", full.names = TRUE)
  iguales <- previos[unname(tools::md5sum(previos)) == huella]
  if (length(iguales)) ruta <- sort(iguales)[1] else {
    marca <- format(Sys.time(), tz = "UTC", format = "%Y-%m-%d_%H%M%S")
    ruta <- file.path(carpeta, paste0("remision_a_planta_inale_", marca, "_", substr(huella, 1, 12), ".", extension))
    if (file.exists(ruta) || !file.copy(temporal, ruta, overwrite = FALSE)) stop("No se pudo conservar el original.")
  }
  list(ruta = ruta, url = url, md5 = huella)
}

# 3. Leer el mismo rectangulo y unidades que 02/03; validar antes de escribir ---
op10_leer_excel <- function(fuente) {
  if (!"Listado Datos" %in% readxl::excel_sheets(fuente$ruta)) stop("Falta la hoja Listado Datos.")
  tabla <- readxl::read_excel(fuente$ruta,
    range = cellranger::cell_limits(c(5, 2), c(NA, 7), sheet = "Listado Datos"),
    col_types = "text", na = c("", "NA"), trim_ws = TRUE)
  esperadas <- c("Fecha", "Remisión (litros)", "Remisión (kilos sólidos)",
    "Contenido de Grasa (%)", "Contenido de Proteína (%)", "Observaciones")
  if (!identical(names(tabla), esperadas)) stop("Cambio la estructura de columnas de INALE.")
  fechas_excel <- suppressWarnings(as.numeric(tabla$Fecha))
  mensuales <- !is.na(fechas_excel)
  tabla <- tabla[mensuales, , drop = FALSE]
  fechas_excel <- fechas_excel[mensuales]
  fechas <- as.Date(fechas_excel, origin = "1899-12-30")
  numero <- function(x) {
    y <- suppressWarnings(as.numeric(x))
    if (any(!is.finite(y))) stop("Hay valores numericos vacios o invalidos en la fuente.")
    y
  }
  obs <- as.character(tabla$Observaciones)
  obs[is.na(obs) | trimws(obs) == ""] <- NA_character_
  staging <- data.frame(fecha_excel = fechas_excel, fecha = as.character(fechas),
    remision_litros = numero(tabla[[2]]), remision_kilos_solidos = numero(tabla[[3]]),
    grasa_proporcion = numero(tabla[[4]]), proteina_proporcion = numero(tabla[[5]]),
    observacion_origen = obs, archivo_origen = basename(fuente$ruta),
    fecha_carga_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), stringsAsFactors = FALSE)
  staging <- staging[order(staging$fecha), , drop = FALSE]
  rownames(staging) <- NULL
  fechas <- as.Date(staging$fecha)
  if (!length(fechas) || anyNA(fechas) || anyDuplicated(fechas) ||
      any(format(fechas, "%d") != "01") || min(fechas) != as.Date("2002-01-01") ||
      !identical(as.character(fechas), as.character(seq(min(fechas), max(fechas), by = "month")))) {
    stop("Se requiere la serie mensual completa y sin duplicados desde enero de 2002.")
  }
  if (any(staging$remision_litros <= 0 | staging$remision_kilos_solidos <= 0) ||
      any(staging$grasa_proporcion < 0 | staging$grasa_proporcion > 0.1) ||
      any(staging$proteina_proporcion < 0 | staging$proteina_proporcion > 0.1)) {
    stop("Hay volumenes no positivos o proporciones incompatibles con las unidades originales.")
  }
  datos <- staging[, c("fecha", "remision_litros")]
  datos$fecha <- fechas
  datos$dias_mes <- op10_dias_mes(fechas)
  datos$remision_diaria <- datos$remision_litros / datos$dias_mes
  datos$log_diaria <- log(datos$remision_diaria)
  list(staging = staging, datos = datos)
}

op10_misma_serie <- function(a, b) {
  is.data.frame(a) && is.data.frame(b) &&
    all(c("fecha", "remision_litros") %in% names(a)) &&
    all(c("fecha", "remision_litros") %in% names(b)) &&
    identical(as.character(a$fecha), as.character(b$fecha)) &&
    all(is.finite(a$remision_litros)) && all(is.finite(b$remision_litros)) &&
    all(abs(as.numeric(a$remision_litros) - as.numeric(b$remision_litros)) <= 1e-5)
}

op10_cambios <- function(antes, datos) {
  if (length(setdiff(as.character(antes$fecha), as.character(datos$fecha)))) {
    stop("La fuente perdio meses previamente almacenados. No se acorta la historia.")
  }
  i <- match(as.character(datos$fecha), as.character(antes$fecha))
  anterior <- antes$remision_litros[i]
  nuevo <- is.na(i)
  revision <- !nuevo & abs(anterior - datos$remision_litros) > 1e-5
  filas <- which(nuevo | revision)
  data.frame(fecha = datos$fecha[filas],
    tipo = ifelse(nuevo[filas], "nuevo_mes", "revision_litros"),
    litros_anteriores = anterior[filas], litros_actuales = datos$remision_litros[filas])
}

op10_mismos_campos <- function(a, b) {
  if (nrow(a) != nrow(b) || !identical(names(a), names(b))) return(FALSE)
  all(vapply(names(a), function(nm) {
    if (is.numeric(b[[nm]])) {
      tolerancia <- if (grepl("porcentaje", nm)) 1e-10 else 1e-5
      all(is.finite(a[[nm]])) && all(abs(a[[nm]] - b[[nm]]) <= tolerancia)
    } else identical(as.character(a[[nm]]), as.character(b[[nm]]))
  }, logical(1)))
}

# 4. Conservar la especificacion del cierre, incluso ante revisiones de datos --
op10_cierre <- function(cfg, raiz, datos) {
  ruta <- file.path(raiz, cfg$ruta_cierre)
  c <- readRDS(ruta)
  fit <- c[["modelo_principal", exact = TRUE]]
  efectos <- c[["efectos", exact = TRUE]]
  if (!isTRUE(c[["seleccion_modelado_cerrada", exact = TRUE]]) ||
      !identical(c[["modelo_seleccionado", exact = TRUE]], "ARMA21_SAR1") ||
      !identical(as.integer(fit$arma), c(2L, 1L, 1L, 0L, 12L, 0L, 0L)) ||
      "intercept" %in% names(stats::coef(fit)) || nrow(efectos) != 2L ||
      !setequal(paste(efectos$fecha, efectos$tipo), c("2006-02-01 TC", "2004-04-01 AO")) ||
      !isTRUE(all.equal(c$transformacion$delta_TC, 0.7))) stop("El cierre no contiene la especificacion acordada.")
  if (max(datos$fecha) < max(as.Date(c$fechas))) stop("La fuente termina antes de la muestra de desarrollo.")
  X <- op10_diseno(as.Date(c$fechas), efectos, 0.7)$diferencia
  if (!isTRUE(all.equal(unname(X), unname(as.matrix(c$principal$regresores)), tolerance = 1e-10))) {
    stop("No se reproduce el diseno determinista del cierre.")
  }
  list(efectos = efectos, delta = 0.7, huella = unname(tools::md5sum(ruta)))
}

# 5. Validar el registro y localizar una emision ya hecha con estos datos -------
op10_pred_db <- function(p, id, origen) {
  columnas <- c("modelo", "origen", "fecha", "h", "pred_media", "pred_mediana",
    "inferior80", "superior80", "inferior95", "superior95")
  if (!is.data.frame(p) || nrow(p) != 24L || !all(columnas %in% names(p))) stop("Trayectoria incompleta.")
  p <- p[, columnas]
  if (anyNA(p[, 1:4]) || !setequal(unique(p$modelo), c("SARIMA", "Naive_estacional")) ||
      anyDuplicated(p[c("modelo", "h")]) || !is.numeric(p$h) ||
      any(p$h != as.integer(p$h)) || any(p$h < 1L | p$h > 12L)) stop("Claves de pronostico invalidas.")
  for (m in unique(p$modelo)) if (!identical(sort(as.integer(p$h[p$modelo == m])), 1:12)) stop("Faltan horizontes.")
  for (nm in columnas[5:10]) {
    if (!is.numeric(p[[nm]]) || any(!is.finite(p[[nm]]))) stop("Pronosticos no finitos.")
    p[[nm]] <- as.double(p[[nm]])
  }
  objetivos <- as.character(op10_mes_siguiente(origen, 12L))
  if (any(as.character(p$origen) != as.character(origen)) ||
      any(as.character(p$fecha) != objetivos[p$h]) || any(p$pred_media <= 0 | p$pred_mediana <= 0) ||
      any(p$inferior95 > p$inferior80 | p$inferior80 > p$superior80 | p$superior80 > p$superior95)) stop("Trayectoria incoherente.")
  p$origen <- as.character(p$origen); p$fecha <- as.character(p$fecha); p$h <- as.integer(p$h)
  names(p)[3] <- "fecha_objetivo"
  p <- cbind(data.frame(ejecucion_id = rep(id, 24L)), p)
  p <- p[order(p$modelo, p$h), ]; rownames(p) <- NULL
  p
}

op10_igual_registro <- function(a, b) {
  if (!identical(names(a), names(b)) || nrow(a) != nrow(b)) return(FALSE)
  all(vapply(names(a), function(nm) {
    if (is.numeric(a[[nm]])) all(is.finite(b[[nm]])) && all(abs(a[[nm]] - b[[nm]]) <= 1e-5)
    else identical(as.character(a[[nm]]), as.character(b[[nm]]))
  }, logical(1)))
}

op10_buscar_emision <- function(con, raiz, datos, cfg, cierre) {
  candidatas <- DBI::dbGetQuery(con, paste(
    "SELECT * FROM forecast_ejecuciones WHERE ultimo_dato = ?",
    "AND version_modelo = ? ORDER BY fecha_ejecucion_utc DESC, ejecucion_id DESC"),
    params = list(as.character(max(datos$fecha)), cfg$version_modelo))
  for (i in seq_len(nrow(candidatas))) {
    e <- candidatas[i, ]
    carpeta <- normalizePath(file.path(raiz, e$carpeta_resultados), winslash = "/", mustWork = TRUE)
    if (!startsWith(carpeta, paste0(raiz, "/"))) stop("Ruta de una emision previa fuera del proyecto.")
    ruta <- file.path(carpeta, "15_modelo_y_pronosticos_actuales.rds")
    if (!file.exists(ruta)) stop("Falta el artefacto de una emision previa: ", ruta)
    paquete <- readRDS(ruta)
    if (!op10_misma_serie(paquete$datos_entrenamiento, datos) ||
        !identical(as.character(paquete$diseno$fuente_cierre_md5), cierre$huella)) next
    csv <- file.path(carpeta, "10_pronosticos_proximos_12_meses.csv")
    if (!file.exists(csv) || !identical(unname(tools::md5sum(csv)), e$huella_pronosticos)) stop("Cambio el archivo de una emision registrada.")
    p <- op10_pred_db(paquete$pronosticos, e$ejecucion_id, max(datos$fecha))
    guardado <- DBI::dbGetQuery(con, "SELECT * FROM forecast_pronosticos WHERE ejecucion_id = ? ORDER BY modelo, h",
      params = list(e$ejecucion_id))
    if (!op10_igual_registro(p, guardado) || e$n_observaciones != nrow(datos) || e$horizonte != 12L) {
      stop("La emision previa no reproduce el registro completo de SQLite.")
    }
    return(list(ejecucion = e, paquete = paquete))
  }
  NULL
}

# 6. SQL analitico existente, dentro de la misma transaccion de la actualizacion
op10_actualizar_tablas <- function(con, staging, ruta_sql) {
  lineas <- readLines(ruta_sql, encoding = "UTF-8", warn = FALSE)
  lineas[1] <- sub("^\ufeff", "", lineas[1])
  codigo <- paste(lineas[!grepl("^\\s*--", lineas)], collapse = "\n")
  sentencias <- trimws(strsplit(codigo, ";", fixed = TRUE)[[1]])
  sentencias <- sentencias[nzchar(sentencias)]
  # El SQL original tiene BEGIN/COMMIT; aqui los administra dbWithTransaction.
  sentencias <- sentencias[!grepl("^(BEGIN TRANSACTION|COMMIT)$", sentencias, ignore.case = TRUE)]
  DBI::dbWriteTable(con, "stg_remision_inale", staging, overwrite = TRUE, row.names = FALSE)
  controles <- list()
  for (sql in sentencias) {
    if (grepl("^(SELECT|WITH)\\b", sql, ignore.case = TRUE)) controles[[length(controles) + 1L]] <- DBI::dbGetQuery(con, sql)
    else DBI::dbExecute(con, sql)
  }
  if (length(controles) != 3L || !identical(controles[[1]]$control_filas, "OK") ||
      controles[[1]]$filas_analiticas != nrow(staging) ||
      anyNA(controles[[2]]) || any(as.matrix(controles[[2]]) != 0) || nrow(controles[[3]]) != 0L) {
    stop("Fallaron controles SQL: se revierte la actualizacion.")
  }
  controles
}

# 6B. Reportes de doce meses: conservar filas futuras y actualizar observados ---
op10_html_reporte <- function(sarima, naive, meta, corte, actualizado,
    enlace_indice = "index.html") {
  escapar <- function(x) {
    x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    gsub('"', "&quot;", x, fixed = TRUE)
  }
  numero <- function(x, digitos = 0L) {
    if (is.na(x)) return("&mdash;")
    formatC(x, format = "f", digits = digitos, big.mark = ".", decimal.mark = ",")
  }
  mes <- function(x) {
    meses <- c("enero", "febrero", "marzo", "abril", "mayo", "junio",
      "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre")
    x <- as.Date(x)
    paste(meses[as.integer(format(x, "%m"))], format(x, "%Y"))
  }
  tabla <- function(p) {
    filas <- vapply(seq_len(nrow(p)), function(i) {
      z <- p[i, ]
      intervalo <- function(a, b) paste(numero(a), "&ndash;", numero(b))
      celdas <- c(escapar(mes(z$fecha_objetivo)), z$h, numero(z$pronostico_litros),
        numero(z$real_litros), numero(z$diferencia_litros),
        if (is.na(z$diferencia_pct)) "&mdash;" else paste0(numero(z$diferencia_pct, 2L), "%"),
        intervalo(z$inferior80, z$superior80), intervalo(z$inferior95, z$superior95),
        paste0('<span class="estado ', if (is.na(z$real_litros)) "pendiente" else "observado", '">', escapar(z$estado), '</span>'))
      paste0("<tr>", paste0("<td>", celdas, "</td>", collapse = ""), "</tr>")
    }, character(1))
    paste0('<div class="tabla"><table><thead><tr>', paste0("<th>",
      c("Mes objetivo", "h", "Pronóstico (litros)", "Real (litros)", "Real − pronóstico",
        "Diferencia (%)", "Intervalo 80%", "Intervalo 95%", "Estado"),
      "</th>", collapse = ""), "</tr></thead><tbody>", paste(filas, collapse = "\n"), "</tbody></table></div>")
  }
  nav <- if (is.null(enlace_indice)) "" else paste0('<nav><a href="', escapar(enlace_indice), '">Consultar todas las emisiones</a></nav>')
  paste0('<!doctype html><html lang="es"><head><meta charset="UTF-8">',
    '<meta name="viewport" content="width=device-width,initial-scale=1"><title>Pronósticos de remisión de leche</title>',
    '<style>body{margin:0;background:#f4f7f9;color:#162d36;font:15px/1.5 system-ui,Segoe UI,sans-serif}',
    'main{max-width:1600px;margin:32px auto;padding:0 24px}header,.panel,details{background:white;border:1px solid #dce5e9;border-radius:12px;padding:22px;margin-bottom:20px}',
    '.marca{color:#007c83;font-size:13px;font-weight:700;letter-spacing:.05em}h1{font-size:29px;line-height:1.2;margin:10px 0 14px}h2{font-size:20px;margin:0 0 8px}',
    '.meta{color:#47616b;margin:5px 0}.resumen{display:flex;gap:12px;flex-wrap:wrap;margin-top:16px}.dato{background:#edf5f5;border-radius:8px;padding:8px 14px}',
    '.tabla{overflow-x:auto}table{width:100%;border-collapse:collapse;white-space:nowrap;font-size:13px;font-variant-numeric:tabular-nums}',
    'th{background:#edf5f5;font-size:12px;color:#244d55}th,td{padding:12px 10px;border-bottom:1px solid #e6edef;text-align:right}th:first-child,td:first-child{text-align:left}',
    'tbody tr:nth-child(even){background:#fafcfc}.estado{padding:3px 8px;border-radius:15px;font-size:12px}.pendiente{background:#f0f2f4;color:#53636c}.observado{background:#dff2eb;color:#176348}',
    '.nota,footer{font-size:13px;color:#526973}code{overflow-wrap:anywhere}a{color:#006d75}nav{margin-top:16px}summary{cursor:pointer;font-weight:600}',
    '@media(max-width:700px){main{padding:0 10px;margin:12px auto}header,.panel,details{padding:14px}h1{font-size:23px}}</style></head><body><main>',
    '<header><div class="marca">REMISIÓN DE LECHE · URUGUAY</div><h1>Pronóstico y seguimiento de doce meses</h1>',
    '<p class="meta">Pronóstico emitido con datos hasta <strong>', escapar(mes(meta$ultimo_dato)), '</strong>.</p>',
    '<p class="meta">Observados disponibles hasta ', escapar(mes(corte)), ' · Seguimiento actualizado: ', escapar(actualizado), '.</p>',
    '<p class="meta">Emisión: <code>', escapar(meta$ejecucion_id), '</code> · Generada: ', escapar(meta$fecha_ejecucion_utc), '.</p>',
    '<div class="resumen"><span class="dato">12 meses completos</span><span class="dato">', sum(!is.na(sarima$real_litros)),
    ' observados</span><span class="dato">', sum(is.na(sarima$real_litros)), ' pendientes</span></div>', nav, '</header>',
    '<section class="panel"><h2>SARIMA seleccionado</h2><p class="nota">', escapar(meta$especificacion), '</p>', tabla(sarima),
    '<p class="nota">Diferencia = real − pronóstico; positiva indica subpredicción. Diferencia (%) = 100 × diferencia / real. ',
    'Las celdas pendientes se completan cuando llega el observado. Importes mostrados redondeados al litro; el CSV conserva la precisión.</p></section>',
    '<details><summary>Ver referencia naïve estacional · doce meses</summary>', tabla(naive), '</details>',
    '<footer>Fuente de observados: INALE, versión vigente en SQLite al actualizar este reporte. Los pronósticos originales se conservan. ',
    'Si INALE revisa un observado, su diferencia puede cambiar. Los intervalos son condicionales al modelo; no incluyen futuros eventos desconocidos.</footer>',
    '</main></body></html>')
}

op10_generar_reportes <- function(con, raiz, emision_actual, carpeta_control) {
  seguimiento <- DBI::dbGetQuery(con, paste(
    "SELECT p.ejecucion_id, p.modelo, p.origen, p.fecha_objetivo, p.h, p.pred_media,",
    "p.inferior80, p.superior80, p.inferior95, p.superior95,",
    "a.remision_litros AS observado, a.remision_litros - p.pred_media AS error",
    "FROM forecast_pronosticos p LEFT JOIN analitica_remision_mensual a ON a.fecha = p.fecha_objetivo",
    "ORDER BY p.ejecucion_id, p.modelo, p.h"))
  emisiones <- DBI::dbGetQuery(con, paste(
    "SELECT * FROM forecast_ejecuciones ORDER BY ultimo_dato DESC, fecha_ejecucion_utc DESC, ejecucion_id DESC"))
  if (!nrow(emisiones) || !emision_actual %in% emisiones$ejecucion_id) stop("No existe la emision actual para reportar.")
  corte <- DBI::dbGetQuery(con, "SELECT MAX(fecha) AS fecha FROM analitica_remision_mensual")$fecha[1]
  actualizado <- format(Sys.time(), tz = "UTC", format = "%Y-%m-%d %H:%M:%S UTC")
  directorio <- file.path(raiz, "outputs", "reportes")
  dir.create(directorio, recursive = TRUE, showWarnings = FALSE)
  exportar <- function(p, modelo) {
    z <- p[p$modelo == modelo, ]; z <- z[order(z$h), ]
    if (nrow(z) != 12L || !identical(as.integer(z$h), 1:12)) stop("El reporte requiere doce meses por modelo.")
    data.frame(fecha_objetivo = z$fecha_objetivo, h = z$h,
      pronostico_litros = z$pred_media, real_litros = z$observado,
      diferencia_litros = z$error, diferencia_pct = 100 * z$error / z$observado,
      inferior80 = z$inferior80, superior80 = z$superior80,
      inferior95 = z$inferior95, superior95 = z$superior95,
      estado = ifelse(is.na(z$observado), "Pendiente", "Observado"),
      origen = z$origen, ejecucion_id = z$ejecucion_id, stringsAsFactors = FALSE)
  }
  enlaces <- character(nrow(emisiones)); actual <- NULL
  for (i in seq_len(nrow(emisiones))) {
    meta <- emisiones[i, ]; id <- meta$ejecucion_id
    if (!grepl("^[A-Za-z0-9_-]+$", id)) stop("Identificador de emision incompatible con el directorio de reportes.")
    p <- seguimiento[seguimiento$ejecucion_id == id, ]
    if (nrow(p) != 24L || anyDuplicated(p[c("modelo", "h")]) ||
        !setequal(p$modelo, c("SARIMA", "Naive_estacional"))) stop("Registro incompleto para el reporte de ", id)
    sarima <- exportar(p, "SARIMA"); naive <- exportar(p, "Naive_estacional")
    carpeta <- file.path(directorio, "emisiones", id)
    dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
    op10_csv(sarima, carpeta, "sarima.csv"); op10_csv(naive, carpeta, "naive_estacional.csv")
    writeLines(op10_html_reporte(sarima, naive, meta, corte, actualizado, "../../index.html"),
      file.path(carpeta, "reporte.html"), useBytes = TRUE)
    enlaces[i] <- paste0('<li><a href="emisiones/', id, '/reporte.html">Origen ', meta$ultimo_dato,
      ' · ', id, '</a>', if (id == emision_actual) ' <strong>· Actual</strong>' else '', '</li>')
    if (id == emision_actual) {
      actual <- list(sarima = sarima, naive = naive, meta = meta)
      op10_csv(sarima, directorio, "pronostico_actual.csv")
      op10_csv(naive, directorio, "naive_actual.csv")
      op10_csv(sarima, carpeta_control, "04_reporte_sarima_actual.csv")
      writeLines(op10_html_reporte(sarima, naive, meta, corte, actualizado),
        file.path(directorio, "pronostico_actual.html"), useBytes = TRUE)
      writeLines(op10_html_reporte(sarima, naive, meta, corte, actualizado, "../../reportes/index.html"),
        file.path(carpeta_control, "04_reporte_sarima_actual.html"), useBytes = TRUE)
    }
  }
  writeLines(paste0('<!doctype html><html lang="es"><meta charset="UTF-8"><title>Emisiones de pronósticos</title>',
    '<style>body{max-width:1100px;margin:40px auto;padding:0 20px;font:16px/1.8 system-ui;color:#162d36}a{color:#006d75}</style>',
    '<h1>Emisiones de pronósticos</h1><p><a href="pronostico_actual.html">Abrir reporte actual</a></p>',
    '<p>Cada enlace conserva doce meses por modelo y muestra los observados disponibles al actualizar el reporte.</p><ul>',
    paste(enlaces, collapse = "\n"), '</ul><p>Seguimiento actualizado: ', actualizado, '</p></html>'),
    file.path(directorio, "index.html"), useBytes = TRUE)
  op10_csv(seguimiento, carpeta_control, "03_seguimiento_emitido_vs_observado.csv")
  list(seguimiento = seguimiento, actual = actual,
    ruta = file.path(directorio, "pronostico_actual.html"),
    indice = file.path(directorio, "index.html"), corte = corte, actualizado = actualizado)
}

# 7. Flujo completo: preparar, estimar si corresponde, confirmar y mostrar ------
ejecutar_ciclo10 <- function(cfg = config10) {
  requeridos <- c("DBI", "RSQLite", "readxl", "cellranger", "forecast")
  faltan <- requeridos[!vapply(requeridos, requireNamespace, logical(1), quietly = TRUE)]
  if (length(faltan)) stop("Faltan dependencias del proyecto: ", paste(faltan, collapse = ", "))
  raiz <- normalizePath(cfg$raiz, winslash = "/", mustWork = TRUE)
  ruta_bd <- file.path(raiz, cfg$ruta_db)
  if (!all(file.exists(c(ruta_bd, file.path(raiz, cfg$ruta_cierre), file.path(raiz, cfg$ruta_sql))))) {
    stop("Se requieren la base existente, el cierre del 06 y sql/01_crear_tabla_analitica.sql.")
  }
  if (cfg$horizonte != 12L || !identical(cfg$niveles_intervalo, c(80, 95)) ||
      !identical(cfg$version_modelo, "SARIMA_06_v1")) stop("Configuracion distinta de la especificacion operativa acordada.")
  bloqueo <- file.path(dirname(ruta_bd), "operacion10.lock")
  if (!dir.create(bloqueo, showWarnings = FALSE)) stop("Existe operacion10.lock: otra ejecucion o un cierre interrumpido. Revisar antes de continuar.")
  on.exit(unlink(bloqueo, recursive = TRUE), add = TRUE)
  writeLines(paste("PID", Sys.getpid(), "UTC", format(Sys.time(), tz = "UTC", usetz = TRUE)), file.path(bloqueo, "propietario.txt"))
  id <- paste0("op10_", gsub("\\.", "", format(Sys.time(), tz = "UTC", format = "%Y%m%d_%H%M%OS6Z")), "_", Sys.getpid())
  carpeta_relativa <- file.path(cfg$ruta_salidas, id)
  carpeta <- file.path(raiz, carpeta_relativa)
  if (dir.exists(carpeta) || !dir.create(carpeta, recursive = TRUE)) stop("No se pudo crear la carpeta de control.")
  completado <- FALSE; confirmado_bd <- FALSE
  on.exit(if (!completado) writeLines(if (confirmado_bd)
    "SQLITE_CONFIRMADO: fallo una salida posterior; revisar SQLite antes de repetir. No duplicar la emision."
    else "NO_CONFIRMADO_EN_SQLITE: consultar el error de consola; las escrituras de esta transaccion no se confirmaron.",
    file.path(carpeta, "00_estado.txt")), add = TRUE)
  cat("\nSCRIPT 10 — ACTUALIZACION LOCAL Y TRAYECTORIA A DOCE MESES\n")
  cat("Comprobando la fuente; se conserva la especificacion del 06.\n")
  fuente <- op10_fuente(cfg, raiz)
  preparado <- op10_leer_excel(fuente)
  datos <- preparado$datos; staging <- preparado$staging
  cierre <- op10_cierre(cfg, raiz, datos)
  op10_csv(data.frame(archivo = basename(fuente$ruta), url = fuente$url, md5 = fuente$md5,
    comprobacion_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)), carpeta, "00_fuente.csv")
  op10_csv(datos, carpeta, "01_datos_utilizados.csv")
  con <- DBI::dbConnect(RSQLite::SQLite(), dbname = ruta_bd)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
  DBI::dbExecute(con, "PRAGMA busy_timeout = 5000")
  if (!all(vapply(c("stg_remision_inale", "analitica_remision_mensual", "forecast_ejecuciones", "forecast_pronosticos"),
      function(t) DBI::dbExistsTable(con, t), logical(1)))) stop("Faltan tablas iniciales: completar 03/04 y 08.")
  antes <- DBI::dbGetQuery(con, "SELECT * FROM analitica_remision_mensual ORDER BY fecha")
  cambios <- op10_cambios(antes, datos)
  op10_csv(cambios, carpeta, "02_cambios_remision.csv")
  # Comparar tambien solidos, composicion y observaciones; ignorar sellos de carga.
  comparable <- data.frame(fecha = staging$fecha, remision_litros = staging$remision_litros,
    remision_kilos_solidos = staging$remision_kilos_solidos,
    grasa_porcentaje = staging$grasa_proporcion * 100,
    proteina_porcentaje = staging$proteina_proporcion * 100,
    observacion_origen = staging$observacion_origen, stringsAsFactors = FALSE)
  if (!all(names(comparable) %in% names(antes))) stop("La tabla analitica no tiene la estructura inicial esperada.")
  actualizar <- !op10_mismos_campos(antes[, names(comparable)], comparable)
  previa <- op10_buscar_emision(con, raiz, datos, cfg, cierre)
  emitir <- is.null(previa)
  cat("Datos:", as.character(min(datos$fecha)), "a", as.character(max(datos$fecha)), "| Meses:", nrow(datos), "\n")
  cat("Meses nuevos:", sum(cambios$tipo == "nuevo_mes"), "| Meses con revision de litros:", sum(cambios$tipo == "revision_litros"), "\n")
  if (emitir) {
    cat("Reestimando el mismo SARIMA con toda la historia disponible...\n")
    base <- list(datos = datos, efectos = cierre$efectos, delta = cierre$delta)
    f <- op10_futuro(base, cfg, anterior = NULL)
    op10_csv(f$intentos, carpeta, "13_intentos_estimacion_actual.csv")
    if (is.null(f$modelo) || !op10_cov_valida(f$modelo)) stop("No se obtuvo ajuste con convergencia, raices y covarianzas validas. No se actualiza SQLite.")
    p <- op10_pred_db(f$tabla, id, max(datos$fecha))
    diseno <- data.frame(ejercicio = "Emision_operativa_modelo_fijo",
      modelo = "SARIMA(2,1,1)(1,0,0)[12]; sin deriva; 11 contrastes; TC200602 y AO200404",
      inicio_serie = min(datos$fecha), fin_serie = max(datos$fecha), horizonte_max = 12L,
      fuente_cierre_md5 = cierre$huella, version_modelo = cfg$version_modelo)
    op10_csv(diseno, carpeta, "00_diseno_operacion.csv")
    op10_csv(f$tabla, carpeta, "10_pronosticos_proximos_12_meses.csv")
    op10_csv(f$coeficientes, carpeta, "11_coeficientes_ajuste_actual.csv")
    op10_csv(f$diagnosticos, carpeta, "12_diagnostico_ajuste_actual.csv")
    paquete <- list(modelo_diferencias = f$modelo, filtro_integrado_parametros_fijos = f$filtro_integrado,
      regresores_futuros = f$regresores_futuros, efectos = cierre$efectos, delta_TC = cierre$delta,
      datos_entrenamiento = datos, pronosticos = f$tabla, diseno = diseno,
      notas = c("Especificacion fija; coeficientes reestimados con toda la historia.",
        "Intervalos condicionales: no incluyen incertidumbre de parametros, seleccion ni nuevos eventos.",
        "Las revisiones de la fuente se incorporan al ajuste actual; las emisiones pasadas se conservan."))
    saveRDS(paquete, file.path(carpeta, "15_modelo_y_pronosticos_actuales.rds"))
    ejecucion <- data.frame(ejecucion_id = id,
      fecha_ejecucion_utc = format(Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"),
      inicio_datos = as.character(min(datos$fecha)), ultimo_dato = as.character(max(datos$fecha)),
      n_observaciones = as.integer(nrow(datos)), horizonte = 12L, version_modelo = cfg$version_modelo,
      especificacion = paste0(diseno$modelo, "; log(litros/dias_del_mes)"),
      carpeta_resultados = gsub("\\\\", "/", carpeta_relativa),
      huella_pronosticos = unname(tools::md5sum(file.path(carpeta, "10_pronosticos_proximos_12_meses.csv"))))
    if (!identical(DBI::dbListFields(con, "forecast_ejecuciones"), names(ejecucion)) ||
        !identical(DBI::dbListFields(con, "forecast_pronosticos"), names(p))) stop("Estructura de persistencia incompatible.")
  } else {
    id_emision <- previa$ejecucion$ejecucion_id
    cat("Ya existe una trayectoria completa con estos mismos datos y cierre:", id_emision, "\n")
  }
  DBI::dbWithTransaction(con, {
    if (!identical(antes, DBI::dbGetQuery(con, "SELECT * FROM analitica_remision_mensual ORDER BY fecha"))) stop("La base cambio durante el calculo. Reintentar con los datos actuales.")
    if (actualizar) op10_actualizar_tablas(con, staging, file.path(raiz, cfg$ruta_sql))
    comprobacion <- DBI::dbGetQuery(con, "SELECT fecha, remision_litros FROM analitica_remision_mensual ORDER BY fecha")
    if (!op10_misma_serie(comprobacion, datos)) stop("SQLite no reproduce la serie validada: se revierte.")
    if (emitir) {
      DBI::dbAppendTable(con, "forecast_ejecuciones", ejecucion)
      DBI::dbAppendTable(con, "forecast_pronosticos", p)
      guardada <- DBI::dbGetQuery(con, "SELECT * FROM forecast_pronosticos WHERE ejecucion_id = ? ORDER BY modelo, h", params = list(id))
      if (!op10_igual_registro(p, guardada)) stop("El registro de pronosticos no coincide: se revierte.")
    }
    if (nrow(DBI::dbGetQuery(con, "PRAGMA foreign_key_check(forecast_pronosticos)"))) stop("Fallo la integridad referencial: se revierte.")
  })
  confirmado_bd <- TRUE
  emision_id <- if (emitir) id else id_emision
  # Reportes completos incluso sin datos nuevos. LEFT JOIN conserva los futuros.
  reportes <- op10_generar_reportes(con, raiz, emision_id, carpeta)
  seguimiento <- reportes$seguimiento
  n_errores <- sum(!is.na(seguimiento$observado))
  conteos <- DBI::dbGetQuery(con, paste(
    "SELECT 'forecast_ejecuciones' AS tabla, COUNT(*) AS filas FROM forecast_ejecuciones",
    "UNION ALL SELECT 'forecast_pronosticos', COUNT(*) FROM forecast_pronosticos"))
  resultado <- list(finalizado = TRUE, fecha_ejecucion = Sys.time(), emision_nueva = emitir,
    ejecucion_pronostico = emision_id, actualizo_tabla_analitica = actualizar,
    nuevos_meses = sum(cambios$tipo == "nuevo_mes"), revisiones_litros = sum(cambios$tipo == "revision_litros"),
    origen = max(datos$fecha), n_observaciones = nrow(datos), fuente = fuente,
    conteos = conteos, n_errores_disponibles = n_errores, carpeta = carpeta,
    reporte_sarima = reportes$actual$sarima, ruta_reporte = reportes$ruta,
    indice_reportes = reportes$indice)
  saveRDS(resultado, file.path(carpeta, "16_objeto_operacion10.rds"))
  writeLines(capture.output(utils::sessionInfo()), file.path(carpeta, "17_sessionInfo.txt"))
  writeLines(if (emitir) "COMPLETADO: nueva emision registrada en SQLite." else "COMPLETADO: misma informacion; sin otra emision.", file.path(carpeta, "00_estado.txt"))
  completado <- TRUE
  cat("\nRESULTADO DEL CICLO 10\n")
  cat(if (emitir) "Nueva trayectoria registrada.\n" else "No se reestimo ni se duplicaron pronosticos.\n")
  cat("Actualizacion de tablas de datos:", actualizar, "| Ejecucion de pronosticos:", emision_id, "\n")
  print(conteos, row.names = FALSE)
  cat("Errores disponibles frente a observados actuales:", n_errores, "\n")
  cat("\nREPORTE SARIMA — DOCE MESES, REAL Y DIFERENCIA\n")
  print(reportes$actual$sarima[, c("fecha_objetivo", "h", "pronostico_litros", "real_litros", "diferencia_litros", "estado")],
    row.names = FALSE, digits = 7)
  cat("\nAbrir reporte:", normalizePath(reportes$ruta, winslash = "/"), "\n")
  cat("Historial de emisiones:", normalizePath(reportes$indice, winslash = "/"), "\n")
  if (emitir) {
    print(f$diagnosticos, row.names = FALSE, digits = 6)
    if (any(f$intentos$avisos != "")) cat("Hay avisos de algunos inicios; consultar 13_intentos_estimacion_actual.csv.\n")
    if (any(unlist(f$diagnosticos[c("LB12_orientativo", "LB24_orientativo", "LB36_orientativo")]) < 0.05)) cat("ATENCION: revisar dependencia residual; no se cambia automaticamente de modelo.\n")
  }
  cat("Control y artefactos en:", normalizePath(carpeta, winslash = "/"), "\n")
  invisible(resultado)
}

# source() ejecuta el ciclo completo. Una carpeta de control no siempre implica
# una nueva emision: SQLite solo agrega otra cuando corresponde pronosticar.
operacion10 <- ejecutar_ciclo10(config10)
