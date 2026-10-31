# ============================================================================
# SCRIPT 07 — EVALUACION HISTORICA Y PRONOSTICOS MENSUALES
# Proyecto: forecasting-remision-leche-uy
#
# Ejecutar desde la raiz del proyecto:
#   source("R/07_evaluar_pronosticar_sarima.R", encoding = "UTF-8")
#
# Dos ejercicios distintos:
# 1. Backtesting historico mensual, ventana expansiva y horizontes 1:12.
# 2. Reestimacion con todos los datos disponibles y siguientes doce meses.
#
# Solo se comparan SARIMA seleccionado y naive estacional ajustado por dias.
# La especificacion del SARIMA procede del cierre 09 del script 06. No se
# repiten seleccion de ordenes, busqueda de quiebres ni deteccion de outliers.
#
# ALCANCE: evaluacion retrospectiva CONDICIONADA a la especificacion elegida
# usando enero 2002-septiembre 2025. Reestimar con historia previa a cada origen
# evita usar valores futuros al ajustar coeficientes, pero no convierte aquella
# seleccion en una prueba independiente. Este alcance tambien rige en forecasting.
#
# Fundamento: taller 05B; capitulo Funcion de forecast; capitulo transversal
# Evaluacion de forecasting. Explicacion completa: docs/R/07_evaluacion_pronosticos_sarima.md.
# No instala paquetes, no modifica SQLite y no ejecuta el script 06 ni Git.
# ============================================================================

# ============================================================================
# BLOQUE 01 — CONFIGURACION Y UTILIDADES
# ============================================================================

config07 <- list(
  raiz = getwd(),
  ruta_db = file.path("database", "forecasting.sqlite"),
  ruta_cierre = file.path("outputs", "sarima_box_jenkins", "09_cierre_modelado",
                         "11_objeto_bloque09.rds"),
  ruta_salidas = file.path("outputs", "evaluacion_predictiva", "07_sarima_vs_naive"),
  primer_origen = as.Date("2011-12-01"),
  horizonte = 12L,
  niveles_intervalo = c(80, 95),
  maxit = 2000L,
  progreso_cada = 12L,
  tolerancia_datos = 1e-9,
  tolerancia_prediccion = 1e-5
)

ev07_csv <- function(x, carpeta, archivo) {
  utils::write.csv(x, file.path(carpeta, archivo), row.names = FALSE,
                  fileEncoding = "UTF-8", na = "")
}

ev07_juntar <- function(lista) {
  x <- do.call(rbind, lista)
  rownames(x) <- NULL
  x
}

ev07_mes_siguiente <- function(fecha, h = 12L) {
  seq(as.Date(fecha), by = "month", length.out = h + 1L)[-1L]
}

ev07_dias_mes <- function(fechas) {
  fechas <- as.Date(fechas)
  siguiente <- as.Date(format(fechas + 32, "%Y-%m-01"))
  as.integer(siguiente - fechas)
}

ev07_contrastes <- function(fechas) {
  mes <- factor(as.integer(format(as.Date(fechas), "%m")), levels = 1:12)
  X <- stats::model.matrix(~ mes, contrasts.arg = list(mes = stats::contr.sum(12)))
  X <- X[, -1L, drop = FALSE]
  colnames(X) <- paste0("mes_contraste_", 1:11)
  X
}

# Perfiles deterministas del cierre: AO es un pulso; TC decae con delta.
# Los perfiles se definen en log-niveles. En la ecuacion de diferencias entra
# diff(perfil). No se corrige, reemplaza o elimina ningun dato observado.
ev07_diseno <- function(fechas, efectos, delta) {
  fechas <- as.Date(fechas)
  n <- length(fechas)
  M <- ev07_contrastes(fechas)
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

ev07_raices <- function(fit) {
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

ev07_cov_valida <- function(fit) {
  V <- fit[["var.coef", exact = TRUE]]
  is.matrix(V) && nrow(V) == length(stats::coef(fit)) &&
    all(is.finite(V)) && all(diag(V) > 0) &&
    isTRUE(tryCatch({ chol(V); TRUE }, error = function(e) FALSE))
}

# ============================================================================
# BLOQUE 02 — CIERRE DEL 06, DATOS Y CALENDARIO
# ============================================================================

ev07_leer <- function(cfg) {
  requeridos <- c("DBI", "RSQLite", "forecast", "ggplot2")
  faltan <- requeridos[!vapply(requeridos, requireNamespace, logical(1L), quietly = TRUE)]
  if (length(faltan)) stop("Faltan paquetes del proyecto: ", paste(faltan, collapse = ", "),
                          ". Resolver las dependencias antes de ejecutar 07.")
  raiz <- normalizePath(cfg$raiz, winslash = "/", mustWork = TRUE)
  db <- file.path(raiz, cfg$ruta_db)
  rc <- file.path(raiz, cfg$ruta_cierre)
  if (!file.exists(db) || !file.exists(rc)) {
    stop("Ejecutar desde la raiz del proyecto. Se requieren SQLite y el RDS del cierre 09 del script 06.")
  }
  cierre <- readRDS(rc)
  if (!isTRUE(cierre[["seleccion_modelado_cerrada", exact = TRUE]]) ||
      !identical(cierre[["modelo_seleccionado", exact = TRUE]], "ARMA21_SAR1")) {
    stop("El RDS no contiene el cierre ARMA21_SAR1 acordado.")
  }
  fit <- cierre[["modelo_principal", exact = TRUE]]
  if (!identical(as.integer(fit$arma), c(2L, 1L, 1L, 0L, 12L, 0L, 0L)) ||
      "intercept" %in% names(stats::coef(fit))) {
    stop("El modelo del cierre no es el ARMA21+SAR1 sin deriva sobre Delta log.")
  }
  efectos <- cierre[["efectos", exact = TRUE]]
  if (nrow(efectos) != 2L || !setequal(paste(efectos$fecha, efectos$tipo),
                                      c("2006-02-01 TC", "2004-04-01 AO"))) {
    stop("Los efectos del cierre difieren de TC febrero 2006 y AO abril 2004.")
  }
  delta <- cierre$transformacion$delta_TC
  if (length(delta) != 1L || !is.finite(delta) || abs(delta - 0.7) > 1e-12) {
    stop("El TC debe conservar delta=0.7.")
  }
  f06 <- as.Date(cierre$fechas)
  if (!identical(as.character(f06), as.character(seq(as.Date("2002-01-01"),
                                   as.Date("2025-09-01"), by = "month")))) {
    stop("El cierre recibido corresponde a otra muestra de desarrollo.")
  }
  con <- DBI::dbConnect(RSQLite::SQLite(), dbname = db, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  datos <- DBI::dbGetQuery(con,
    "SELECT fecha, remision_litros FROM analitica_remision_mensual WHERE fecha >= ? ORDER BY fecha",
    params = list(as.character(min(f06))))
  datos$fecha <- as.Date(datos$fecha)
  if (!nrow(datos) || anyNA(datos$fecha) || anyDuplicated(datos$fecha) ||
      any(format(datos$fecha, "%d") != "01")) stop("Calendario vacio, repetido o invalido.")
  calendario <- seq(min(f06), max(datos$fecha), by = "month")
  if (!identical(as.character(datos$fecha), as.character(calendario))) {
    stop("Faltan meses o el inicio difiere del cierre 06; no se imputan datos automaticamente.")
  }
  if (!is.numeric(datos$remision_litros) || any(!is.finite(datos$remision_litros)) ||
      any(datos$remision_litros <= 0)) stop("La remision debe ser numerica, finita y positiva.")
  datos$dias_mes <- ev07_dias_mes(datos$fecha)
  datos$remision_diaria <- datos$remision_litros / datos$dias_mes
  datos$log_diaria <- log(datos$remision_diaria)
  i06 <- match(f06, datos$fecha)
  if (anyNA(i06) || max(abs(datos$log_diaria[i06] - as.numeric(cierre$serie_log))) >
      cfg$tolerancia_datos) {
    stop("SQLite no reproduce los datos de desarrollo del cierre 06. Revisar posibles revisiones de la fuente.")
  }
  diseno <- ev07_diseno(f06, efectos, delta)
  X06 <- as.matrix(cierre$principal$regresores)
  if (!identical(dim(diseno$diferencia), dim(X06)) ||
      !identical(colnames(diseno$diferencia), colnames(X06)) ||
      max(abs(diseno$diferencia - X06)) > 1e-10) {
    stop("No se reproduce el diseno mensual y de efectos del cierre 06.")
  }
  if (cfg$horizonte != 12L || !identical(cfg$niveles_intervalo, c(80, 95))) {
    stop("Este diseno esta fijado para todos los horizontes 1:12 e intervalos 80/95%.")
  }
  primero <- match(as.Date(cfg$primer_origen), datos$fecha)
  if (is.na(primero) || primero < 120L || primero > nrow(datos) - cfg$horizonte ||
      any(as.Date(efectos$fecha) > as.Date(cfg$primer_origen))) {
    stop("El primer origen requiere diez anios, ambos efectos pasados y doce meses evaluables.")
  }
  list(raiz = raiz, cierre = cierre, datos = datos, efectos = efectos,
       delta = delta, origenes = seq.int(primero, nrow(datos) - cfg$horizonte),
       archivo_cierre = rc, archivo_db = db)
}

# ============================================================================
# BLOQUE 03 — REESTIMACION DEL MISMO MODELO EN CADA ORIGEN
# ============================================================================

ev07_estimar <- function(entrenamiento, efectos, delta, cfg, anterior = NULL) {
  n <- nrow(entrenamiento)
  diseno <- ev07_diseno(entrenamiento$fecha, efectos, delta)
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
    raices <- if (is.null(f)) rep(NA_real_, 3L) else ev07_raices(f)
    convergio <- !is.null(f) && isTRUE(f$code == 0L)
    admisible <- convergio && is.finite(ll) && all(is.finite(stats::coef(f))) &&
      is.finite(f$sigma2) && f$sigma2 > 0 && all(raices > 1 + 1e-8)
    registro[[j]] <- data.frame(origen = max(entrenamiento$fecha), inicio = names(inicios)[j],
      convergio = convergio, admisible = admisible, logLik = ll,
      raiz_AR_regular = raices[1L], raiz_AR_estacional = raices[2L],
      raiz_MA_regular = raices[3L], matriz_cov_valida = !is.null(f) && ev07_cov_valida(f),
      avisos = paste(unique(avisos), collapse = " | "), error = error,
      stringsAsFactors = FALSE, row.names = NULL)
    if (admisible) ajustes[[j]] <- f
  }
  intentos <- ev07_juntar(registro)
  aptos <- which(intentos$admisible)
  if (!length(aptos)) return(list(modelo = NULL, intentos = intentos))
  mejor <- aptos[which.max(intentos$logLik[aptos])]
  fit <- ajustes[[mejor]]
  fit$x <- y; fit$xreg <- X; fit$call$x <- y; fit$call$xreg <- X
  list(modelo = fit, diseno = diseno, intentos = intentos,
       inicio_elegido = intentos$inicio[mejor])
}

# ============================================================================
# BLOQUE 04 — PRONOSTICOS, ACUMULACION Y VUELTA A LITROS
# ============================================================================

ev07_pronosticar_sarima <- function(ajuste, entrenamiento, calendario, efectos, delta, cfg) {
  fit <- ajuste$modelo
  n <- nrow(entrenamiento); h <- nrow(calendario)
  fechas <- c(entrenamiento$fecha, calendario$fecha)
  diseno <- ev07_diseno(fechas, efectos, delta)
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

ev07_pronosticar_naive <- function(entrenamiento, calendario) {
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

ev07_coeficientes <- function(fit, origen, ejercicio) {
  cf <- stats::coef(fit)
  se <- if (ev07_cov_valida(fit)) sqrt(diag(fit$var.coef)) else rep(NA_real_, length(cf))
  data.frame(ejercicio = ejercicio, origen = origen, termino = names(cf),
             estimacion = unname(cf), se_condicional = unname(se))
}

ev07_diagnostico <- function(ajuste, entrenamiento, discrepancia, ejercicio) {
  fit <- ajuste$modelo; e <- as.numeric(stats::residuals(fit)); r <- ev07_raices(fit)
  lb <- vapply(c(12L, 24L, 36L), function(L)
    stats::Box.test(e, lag = L, type = "Ljung-Box", fitdf = 4L)$p.value, numeric(1L))
  data.frame(ejercicio = ejercicio, origen = max(entrenamiento$fecha),
    n_niveles = nrow(entrenamiento), inicio_elegido = ajuste$inicio_elegido,
    logLik = as.numeric(stats::logLik(fit)), sigma_innovacion = sqrt(fit$sigma2),
    raiz_AR_regular = unname(r[1L]), raiz_AR_estacional = unname(r[2L]),
    raiz_MA_regular = unname(r[3L]), matriz_cov_valida = ev07_cov_valida(fit),
    LB12_orientativo = lb[1L], LB24_orientativo = lb[2L], LB36_orientativo = lb[3L],
    discrepancia_acumulacion = discrepancia)
}

# ============================================================================
# BLOQUE 05 — BACKTESTING HISTORICO POR ORIGENES MENSUALES
# ============================================================================

ev07_backtesting <- function(base, cfg, carpeta) {
  datos <- base$datos; origenes <- base$origenes; H <- cfg$horizonte
  predicciones <- ajustes <- parametros <- intentos <- vector("list", length(origenes))
  anterior <- NULL; inicio <- Sys.time()
  cat("\nBACKTESTING HISTORICO CONDICIONADO\n")
  cat("Primer origen:", as.character(datos$fecha[origenes[1L]]),
      "| Ultimo:", as.character(datos$fecha[tail(origenes, 1L)]),
      "| Origenes:", length(origenes), "| Horizontes: 1 a 12\n")
  for (j in seq_along(origenes)) {
    i <- origenes[j]
    entrenamiento <- datos[seq_len(i), , drop = FALSE]
    # La funcion predictiva recibe solamente fechas y dias futuros. Los valores
    # observados de esos meses se incorporan DESPUES para calcular los errores.
    futuro <- data.frame(fecha = datos$fecha[i + seq_len(H)])
    futuro$dias_mes <- ev07_dias_mes(futuro$fecha)
    a <- ev07_estimar(entrenamiento, base$efectos, base$delta, cfg, anterior)
    intentos[[j]] <- a$intentos
    if (is.null(a$modelo)) {
      ev07_csv(ev07_juntar(intentos[seq_len(j)]), carpeta, "99_intentos_hasta_fallo.csv")
      if (j > 1L) ev07_csv(ev07_juntar(predicciones[seq_len(j - 1L)]), carpeta,
                           "99_predicciones_parciales_no_son_evaluacion_completa.csv")
      stop("Ningun inicio produjo ajuste admisible en ", datos$fecha[i],
           ". Se guardaron los intentos; no se omite el origen ni se cambia de modelo.")
    }
    s <- ev07_pronosticar_sarima(a, entrenamiento, futuro, base$efectos, base$delta, cfg)
    p <- rbind(s$tabla, ev07_pronosticar_naive(entrenamiento, futuro))
    p$origen <- datos$fecha[i]
    p$observado <- datos$remision_litros[match(p$fecha, datos$fecha)]
    p$error <- p$observado - p$pred_media
    p$anio_objetivo <- as.integer(format(p$fecha, "%Y"))
    p$mes_objetivo <- as.integer(format(p$fecha, "%m"))
    predicciones[[j]] <- p[, c("origen", "fecha", "h", "modelo", "observado", "pred_media",
      "pred_mediana", "error", "inferior80", "superior80", "inferior95", "superior95",
      "media_log_diaria", "se_log_diaria", "anio_objetivo", "mes_objetivo")]
    ajustes[[j]] <- ev07_diagnostico(a, entrenamiento, s$discrepancia_acumulacion, "Backtesting")
    parametros[[j]] <- ev07_coeficientes(a$modelo, datos$fecha[i], "Backtesting")
    anterior <- a$modelo
    if (j == 1L || j %% cfg$progreso_cada == 0L || j == length(origenes)) {
      cat("Origen", j, "de", length(origenes), "|", as.character(datos$fecha[i]),
          "| minutos:", round(as.numeric(difftime(Sys.time(), inicio, units = "mins")), 2), "\n")
      flush.console()
    }
  }
  p <- ev07_juntar(predicciones)
  if (nrow(p) != length(origenes) * H * 2L ||
      any(table(p$h, p$modelo) != length(origenes)) || any(!is.finite(p$pred_media))) {
    stop("La evaluacion no conserva los mismos origenes y doce horizontes en ambos modelos.")
  }
  list(predicciones = p, diagnosticos = ev07_juntar(ajustes),
       coeficientes = ev07_juntar(parametros), intentos = ev07_juntar(intentos),
       ultimo_modelo = anterior)
}

# ============================================================================
# BLOQUE 06 — METRICAS POR HORIZONTE Y MES DEL ANIO
# ============================================================================

ev07_metricas <- function(z) {
  e <- z$observado - z$pred_media
  score <- function(inf, sup, alpha) {
    mean(sup - inf + (2 / alpha) * (inf - z$observado) * (z$observado < inf) +
           (2 / alpha) * (z$observado - sup) * (z$observado > sup))
  }
  data.frame(n = nrow(z), MAE = mean(abs(e)), RMSE = sqrt(mean(e^2)),
    WAPE_pct = 100 * sum(abs(e)) / sum(abs(z$observado)),
    sesgo_litros = mean(e), sesgo_pct = 100 * sum(e) / sum(z$observado),
    cobertura80_pct = 100 * mean(z$observado >= z$inferior80 & z$observado <= z$superior80),
    cobertura95_pct = 100 * mean(z$observado >= z$inferior95 & z$observado <= z$superior95),
    ancho80_litros = mean(z$superior80 - z$inferior80),
    ancho95_litros = mean(z$superior95 - z$inferior95),
    score_intervalo80 = score(z$inferior80, z$superior80, 0.20),
    score_intervalo95 = score(z$inferior95, z$superior95, 0.05))
}

ev07_agrupar_metricas <- function(p, columnas) {
  clave <- do.call(interaction, c(p[columnas], list(drop = TRUE, lex.order = TRUE)))
  ev07_juntar(lapply(split(p, clave), function(z)
    cbind(z[1L, columnas, drop = FALSE], ev07_metricas(z), row.names = NULL)))
}

ev07_comparacion <- function(metricas) {
  a <- metricas[metricas$modelo == "SARIMA", ]
  b <- metricas[metricas$modelo == "Naive_estacional", ]
  b <- b[match(a$h, b$h), ]
  if (anyNA(b$h) || any(a$n != b$n)) stop("Comparacion con diferente soporte.")
  data.frame(h = a$h, n_origenes = a$n, MAE_SARIMA = a$MAE, MAE_naive = b$MAE,
    mejora_MAE_pct = ifelse(b$MAE > 0, 100 * (1 - a$MAE / b$MAE), NA_real_),
    RMSE_SARIMA = a$RMSE, RMSE_naive = b$RMSE,
    mejora_RMSE_pct = ifelse(b$RMSE > 0, 100 * (1 - a$RMSE / b$RMSE), NA_real_),
    menor_MAE = ifelse(abs(a$MAE - b$MAE) <= 1e-8 * pmax(1, a$MAE, b$MAE),
                       "Empate_numerico", ifelse(a$MAE < b$MAE, "SARIMA", "Naive_estacional")))
}

# ============================================================================
# BLOQUE 07 — REESTIMACION ACTUAL Y SIGUIENTES DOCE MESES
# ============================================================================

ev07_futuro <- function(base, cfg, anterior) {
  entrenamiento <- base$datos
  origen <- max(entrenamiento$fecha)
  calendario <- data.frame(fecha = ev07_mes_siguiente(origen, cfg$horizonte))
  calendario$dias_mes <- ev07_dias_mes(calendario$fecha)
  a <- ev07_estimar(entrenamiento, base$efectos, base$delta, cfg, anterior)
  if (is.null(a$modelo)) return(list(modelo = NULL, intentos = a$intentos))
  s <- ev07_pronosticar_sarima(a, entrenamiento, calendario, base$efectos, base$delta, cfg)
  p <- rbind(s$tabla, ev07_pronosticar_naive(entrenamiento, calendario))
  p$origen <- origen
  p$papel <- ifelse(p$modelo == "SARIMA", "Pronostico_del_modelo_seleccionado", "Referencia")
  p$observado <- NA_real_; p$error <- NA_real_
  list(modelo = a$modelo, filtro_integrado = s$filtro,
       regresores_futuros = s$regresores_futuros, tabla = p,
       coeficientes = ev07_coeficientes(a$modelo, origen, "Pronostico_futuro"),
       diagnosticos = ev07_diagnostico(a, entrenamiento, s$discrepancia_acumulacion, "Pronostico_futuro"),
       intentos = a$intentos)
}

# ============================================================================
# BLOQUE 08 — GRAFICOS Y ARCHIVOS REPRODUCIBLES
# ============================================================================

ev07_graficos <- function(base, metricas, comparacion, por_mes_h, futuro, carpeta) {
  colores <- c(SARIMA = "#007C83", Naive_estacional = "#C45B13")
  guardar <- function(p, nombre, ancho = 10, alto = 6) {
    ggplot2::ggsave(file.path(carpeta, nombre), p, width = ancho, height = alto, dpi = 160, bg = "white")
  }
  tema <- ggplot2::theme_minimal(base_size = 11)
  largo <- rbind(data.frame(metricas[, c("h", "modelo")], metrica = "MAE", valor = metricas$MAE / 1e6),
                 data.frame(metricas[, c("h", "modelo")], metrica = "RMSE", valor = metricas$RMSE / 1e6))
  p <- ggplot2::ggplot(largo, ggplot2::aes(h, valor, colour = modelo)) +
    ggplot2::geom_line() + ggplot2::geom_point() + ggplot2::facet_wrap(~ metrica, scales = "free_y") +
    ggplot2::scale_colour_manual(values = colores) + ggplot2::scale_x_continuous(breaks = 1:12) + tema +
    ggplot2::labs(title = "SARIMA frente a naive estacional: horizontes 1 a 12",
      subtitle = "Backtesting historico condicionado a la especificacion seleccionada",
      x = "Horizonte mensual", y = "Millones de litros", colour = NULL)
  guardar(p, "01_MAE_RMSE_por_horizonte.png")
  p <- ggplot2::ggplot(comparacion, ggplot2::aes(h, mejora_MAE_pct)) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey50") +
    ggplot2::geom_col(fill = "#007C83") + ggplot2::scale_x_continuous(breaks = 1:12) + tema +
    ggplot2::labs(title = "Mejora del MAE del SARIMA respecto al naive estacional",
      subtitle = "Positivo favorece SARIMA; negativo favorece naive. Cada barra conserva todos los origenes.",
      x = "Horizonte mensual", y = "Reduccion del MAE (%)")
  guardar(p, "02_mejora_MAE_por_horizonte.png")
  historia <- tail(base$datos, 48L)
  f <- futuro$tabla[futuro$tabla$modelo == "SARIMA", ]
  p <- ggplot2::ggplot() +
    ggplot2::geom_ribbon(data = f, ggplot2::aes(fecha, ymin = inferior95 / 1e6,
      ymax = superior95 / 1e6), fill = "#007C83", alpha = 0.12) +
    ggplot2::geom_ribbon(data = f, ggplot2::aes(fecha, ymin = inferior80 / 1e6,
      ymax = superior80 / 1e6), fill = "#007C83", alpha = 0.23) +
    ggplot2::geom_line(data = historia, ggplot2::aes(fecha, remision_litros / 1e6), colour = "grey35") +
    ggplot2::geom_line(data = futuro$tabla, ggplot2::aes(fecha, pred_media / 1e6,
      colour = modelo, linetype = modelo)) + ggplot2::scale_colour_manual(values = colores) +
    ggplot2::scale_linetype_manual(values = c(SARIMA = "solid", Naive_estacional = "dashed")) + tema +
    ggplot2::labs(title = "Pronosticos desde el ultimo mes observado",
      subtitle = paste("Origen:", max(base$datos$fecha), "| Bandas SARIMA: 80% y 95% condicionales"),
      x = NULL, y = "Millones de litros", colour = NULL, linetype = NULL)
  guardar(p, "03_pronosticos_proximos_12_meses.png", 11, 6)
  largo <- rbind(data.frame(metricas[, c("h", "modelo")], nivel = "80%", cobertura = metricas$cobertura80_pct),
                 data.frame(metricas[, c("h", "modelo")], nivel = "95%", cobertura = metricas$cobertura95_pct))
  p <- ggplot2::ggplot(largo, ggplot2::aes(h, cobertura, colour = modelo)) +
    ggplot2::geom_hline(data = data.frame(nivel = c("80%", "95%"), nominal = c(80, 95)),
      ggplot2::aes(yintercept = nominal), linetype = 2, colour = "grey50") +
    ggplot2::geom_line() + ggplot2::geom_point() + ggplot2::facet_wrap(~ nivel) +
    ggplot2::scale_colour_manual(values = colores) + ggplot2::scale_x_continuous(breaks = 1:12) + tema +
    ggplot2::labs(title = "Cobertura historica de los intervalos", x = "Horizonte mensual",
                  y = "Observaciones dentro del intervalo (%)", colour = NULL)
  guardar(p, "04_cobertura_intervalos_por_horizonte.png")
  p <- ggplot2::ggplot(por_mes_h, ggplot2::aes(h, factor(mes_objetivo), fill = MAE / 1e6)) +
    ggplot2::geom_tile() + ggplot2::facet_wrap(~ modelo) +
    ggplot2::scale_x_continuous(breaks = 1:12) +
    ggplot2::scale_fill_gradient(low = "#F0F7F7", high = "#00575E") + tema +
    ggplot2::labs(title = "MAE por horizonte y mes del anio pronosticado",
      subtitle = "Consultar n en la tabla; cada celda tiene menos observaciones que el resultado por horizonte.",
      x = "Horizonte mensual", y = "Mes objetivo (1=enero)", fill = "Millones\nde litros")
  guardar(p, "05_MAE_mes_objetivo_y_horizonte.png", 11, 6)
  # Innovaciones y dispersion del ajuste actual: diagnostico, sin nuevos tests.
  fit <- futuro$modelo
  innov <- data.frame(fecha = base$datos$fecha[-1L], innovacion = as.numeric(stats::residuals(fit)))
  ev07_csv(innov, carpeta, "14_innovaciones_ajuste_actual.csv")
  grDevices::png(file.path(carpeta, "06_diagnostico_ajuste_actual.png"), width = 1500, height = 1000, res = 140)
  tryCatch({
    graphics::par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
    graphics::plot(innov$fecha, innov$innovacion, type = "l", xlab = "Fecha", ylab = "Innovacion",
                   main = "SARIMA reestimado: innovaciones")
    graphics::abline(h = 0, col = "grey60")
    stats::acf(innov$innovacion, lag.max = 48, main = "FAC residual", xlab = "Rezago mensual")
    stats::pacf(innov$innovacion, lag.max = 48, main = "FACP residual", xlab = "Rezago mensual")
    stats::qqnorm(innov$innovacion, main = "QQ auxiliar"); stats::qqline(innov$innovacion, col = "#C45B13")
  }, finally = grDevices::dev.off())
}

# ============================================================================
# BLOQUE 09 — EJECUCION COMPLETA Y RESUMEN
# ============================================================================

ejecutar_script_07 <- function(cfg = config07) {
  base <- ev07_leer(cfg)
  id <- paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_", Sys.getpid())
  carpeta <- file.path(base$raiz, cfg$ruta_salidas, id)
  if (dir.exists(carpeta)) stop("Ya existe la carpeta de esta ejecucion; no se sobrescribe.")
  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
  diseno <- data.frame(
    ejercicio = "Backtesting_historico_condicionado_a_especificacion_seleccionada",
    modelo = "SARIMA(2,1,1)(1,0,0)[12]; sin deriva; 11 contrastes; TC200602 y AO200404",
    referencia = "Naive estacional sobre promedio diario; reconversion con dias del mes futuro",
    inicio_serie = min(base$datos$fecha), fin_serie = max(base$datos$fecha),
    corte_usado_para_elegir_especificacion = max(as.Date(base$cierre$fechas)),
    primer_origen = base$datos$fecha[base$origenes[1L]],
    ultimo_origen = base$datos$fecha[tail(base$origenes, 1L)],
    n_origenes_por_horizonte = length(base$origenes), horizonte_min = 1L, horizonte_max = 12L,
    ventana = "Expansiva; avanza un mes; reestimacion conjunta en cada origen",
    metrica_principal = "MAE", metrica_complementaria = "RMSE",
    pronostico_puntual_evaluado = "Media predictiva en litros",
    error = "observado - pred_media; positivo significa subprediccion",
    seleccion_independiente_del_periodo_evaluado = FALSE,
    fuente_cierre_md5 = unname(tools::md5sum(base$archivo_cierre)),
    version_R = as.character(getRversion()),
    version_forecast = as.character(utils::packageVersion("forecast")))
  notas <- c(
    "Evaluacion historica condicionada a la especificacion elegida con datos hasta septiembre 2025.",
    "Ordenes, transformacion y fechas/tipos de efectos se mantienen fijos; coeficientes se reestiman en cada origen.",
    "Esta eleccion retrospectiva no es una prueba independiente del procedimiento de seleccion completo.",
    "Ambos modelos utilizan los mismos origenes y targets; cada origen dispone de doce resultados observados.",
    "No se utilizan valores posteriores al origen para estimar coeficientes ni construir predictores.",
    "No se reproducen versiones historicas de la base: se usan las observaciones actualmente almacenadas.",
    "Los contrastes mensuales actuan sobre Delta log; AO/TC entran como diferencias de perfiles en log-niveles.",
    "Media SARIMA en litros = dias*exp(mu_log+var_log/2); mediana = dias*exp(mu_log).",
    "Los intervalos usan incertidumbre de innovaciones, parametros estimados fijos y regresores conocidos.",
    "No incorporan incertidumbre de seleccion, de parametros, futuras revisiones ni futuros outliers desconocidos.",
    "La mayor dispersion residual temprana puede afectar la calibracion de los intervalos; revisar cobertura y ancho.",
    "Las bandas del naive estacional proceden de snaive sobre promedio diario; no se truncan limites negativos.",
    "Errores de distintos horizontes/origenes pueden solaparse. No se presentan tests de precision ni errores iid.",
    "Resultados por mes objetivo y horizonte tienen menor n: interpretar como desglose descriptivo.",
    "Mejora_MAE_pct positiva favorece SARIMA; negativa favorece naive. No se fuerza un ganador global.",
    "El pronostico futuro del SARIMA se presenta por decision del proyecto, sin atribuir superioridad no observada.",
    "El modelo del cierre 06 no se modifica; su copia se usa para verificar arquitectura, diseno y datos.",
    "Cada ejecucion crea otra carpeta. Se conservan origen, fecha objetivo y horizonte para seguimiento posterior."
  )
  ev07_csv(diseno, carpeta, "00_diseno_evaluacion.csv")
  ev07_csv(base$datos, carpeta, "01_datos_utilizados.csv")
  writeLines(notas, file.path(carpeta, "00_alcance_y_lectura.txt"), useBytes = TRUE)
  cat("\nSCRIPT 07 — SARIMA SELECCIONADO FRENTE A NAIVE ESTACIONAL\n")
  cat("Datos:", as.character(min(base$datos$fecha)), "a", as.character(max(base$datos$fecha)), "\n")
  cat("No se repite la seleccion del 06. Media predictiva en litros; MAE principal.\n")
  bt <- ev07_backtesting(base, cfg, carpeta)
  metricas <- ev07_agrupar_metricas(bt$predicciones, c("modelo", "h"))
  metricas <- metricas[order(metricas$h, metricas$modelo), ]
  por_mes <- ev07_agrupar_metricas(bt$predicciones, c("modelo", "mes_objetivo"))
  por_mes_h <- ev07_agrupar_metricas(bt$predicciones, c("modelo", "h", "mes_objetivo"))
  comparacion <- ev07_comparacion(metricas)
  comparacion <- comparacion[order(comparacion$h), ]
  ev07_csv(bt$predicciones, carpeta, "02_predicciones_backtesting.csv")
  ev07_csv(metricas, carpeta, "03_metricas_por_horizonte.csv")
  ev07_csv(comparacion, carpeta, "04_comparacion_SARIMA_naive.csv")
  ev07_csv(por_mes, carpeta, "05_metricas_por_mes_objetivo.csv")
  ev07_csv(por_mes_h, carpeta, "06_metricas_por_mes_objetivo_y_horizonte.csv")
  ev07_csv(bt$diagnosticos, carpeta, "07_ajustes_por_origen.csv")
  ev07_csv(bt$coeficientes, carpeta, "08_coeficientes_por_origen.csv")
  ev07_csv(bt$intentos, carpeta, "09_intentos_estimacion_backtesting.csv")
  cat("\nReestimando con todos los datos para pronosticar los siguientes doce meses...\n")
  futuro <- ev07_futuro(base, cfg, bt$ultimo_modelo)
  if (is.null(futuro$modelo)) {
    ev07_csv(futuro$intentos, carpeta, "99_intentos_ajuste_actual_fallido.csv")
    stop("No se obtuvo ajuste actual admisible. El backtesting completo queda guardado.")
  }
  ev07_csv(futuro$tabla, carpeta, "10_pronosticos_proximos_12_meses.csv")
  ev07_csv(futuro$coeficientes, carpeta, "11_coeficientes_ajuste_actual.csv")
  ev07_csv(futuro$diagnosticos, carpeta, "12_diagnostico_ajuste_actual.csv")
  ev07_csv(futuro$intentos, carpeta, "13_intentos_estimacion_actual.csv")
  ev07_graficos(base, metricas, comparacion, por_mes_h, futuro, carpeta)
  paquete_futuro <- list(modelo_diferencias = futuro$modelo,
    filtro_integrado_parametros_fijos = futuro$filtro_integrado,
    regresores_futuros = futuro$regresores_futuros, efectos = base$efectos,
    delta_TC = base$delta, datos_entrenamiento = base$datos,
    pronosticos = futuro$tabla, diseno = diseno, notas = notas)
  saveRDS(paquete_futuro, file.path(carpeta, "15_modelo_y_pronosticos_actuales.rds"))
  resultado <- list(configuracion = cfg, diseno = diseno, notas = notas,
    predicciones_backtesting = bt$predicciones, metricas_por_horizonte = metricas,
    comparacion = comparacion, metricas_por_mes = por_mes, metricas_por_mes_y_horizonte = por_mes_h,
    ajustes_por_origen = bt$diagnosticos, coeficientes_por_origen = bt$coeficientes,
    intentos_backtesting = bt$intentos, futuro = paquete_futuro, carpeta = carpeta,
    finalizado = TRUE, fecha_ejecucion = Sys.time())
  saveRDS(resultado, file.path(carpeta, "16_objeto_evaluacion07.rds"))
  writeLines(capture.output(utils::sessionInfo()), file.path(carpeta, "17_sessionInfo.txt"))
  cat("\nCOMPARACION POR HORIZONTE — MAE Y RMSE EN LITROS\n")
  print(comparacion, row.names = FALSE, digits = 6)
  cat("\nPRONOSTICO FUTURO DEL SARIMA — LITROS MENSUALES\n")
  print(futuro$tabla[futuro$tabla$modelo == "SARIMA",
    c("origen", "fecha", "h", "pred_media", "inferior80", "superior80", "inferior95", "superior95")],
    row.names = FALSE, digits = 7)
  cat("\nDIAGNOSTICO DEL AJUSTE ACTUAL\n")
  print(futuro$diagnosticos, row.names = FALSE, digits = 6)
  if (any(!bt$diagnosticos$matriz_cov_valida) || !futuro$diagnosticos$matriz_cov_valida) {
    cat("ATENCION: hay ajustes con covarianzas de parametros no validas; consultar diagnosticos.\n")
  }
  if (any(bt$intentos$avisos != "") || any(futuro$intentos$avisos != "")) {
    cat("Se registraron avisos en algunos inicios; consultar los archivos de intentos.\n")
  }
  cat("\nFinalizo la evaluacion historica condicionada y el pronostico futuro.\n")
  cat("No se declara una validacion independiente de la seleccion ni un ganador global automatico.\n")
  cat("Resultados en:\n", normalizePath(carpeta, winslash = "/"), "\n")
  invisible(resultado)
}

# source() ejecuta TODO el script. No borra objetos anteriores de RStudio.
# evaluacion07 evita sobreescribir bloque07, que en el script 06 es outliers.
evaluacion07 <- ejecutar_script_07(config07)
