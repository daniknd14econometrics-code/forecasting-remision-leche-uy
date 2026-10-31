# ============================================================================
# 06 — MODELIZACION SARIMA MEDIANTE BOX–JENKINS
# Version revisada: bloques separados y calculos comunes centralizados.
# Aplicacion: remision INALE; desarrollo enero 2002 a septiembre 2025.
#
# USO: source("R/06_modelar_evaluar_sarima.R") ejecuta el recorrido completo
# desde 01 hasta 09, en el orden indicado al final del archivo.
# Ejecutar desde la raiz del proyecto. La ejecucion se encuentra al final.
# El analisis de 06 ya fue revisado. 08 usa el modelo y los efectos actuales.
# El cierre 09 registra la decision final revisada; no genera pronosticos.
# No se instala ningun paquete ni se consulta el periodo de reserva.
#
# REVISION DEL ARCHIVO:
# - Se conserva la evidencia de 01, 02A/B, 03, 04/B, 05, 06/B/C, 07/B/C y 08.
# - Se centralizan CSV, figuras, FAC/FACP, filtros ARMA y busqueda de outliers.
# - Se corrige la ejecucion de 02B: se llama la funcion con bloque01.
# - Auto inicial libre: nueva referencia 01B, separada del analisis manual.
# - Auto condicionado: nueva referencia 08B bajo los mismos d/D y regresores.
# - 05 registra ARMA21+SAR1 como base provisional; 06/07/08 heredan esa decision.
# - 09 guarda ARMA21+SAR1 como principal y ARMA21+SMA1 como contraste.
# - El bootstrap 06C autorizado conserva su algoritmo y semilla originales.
# - No se eliminan resultados negativos que fundamentan decisiones.
#
# La revision de ordenes de 05/08 sustituye las listas anteriores insuficientes.
# SAR1 se conserva como referencia historica; no queda seleccionado por defecto.
# El detector se reinicia bajo el modelo del 05: no reutiliza fechas/tipos antiguos.
# ============================================================================

# BLOQUE 00 — UTILIDADES COMPARTIDAS (sin ejecucion estadistica)

bj_paquetes <- function(paquetes) {
  faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
  if (length(faltan)) stop("Faltan paquetes: ", paste(faltan, collapse = ", "),
        ". Instalarlos en el proyecto con renv antes de continuar.")
  invisible(TRUE)
}

bj_csv <- function(objeto, carpeta, nombre) {
  utils::write.csv(objeto, file.path(carpeta, nombre), row.names = FALSE,
       na = "", fileEncoding = "UTF-8")
}

bj_figura <- function(p, carpeta, nombre, alto, ancho = 11) {
  ggplot2::ggsave(file.path(carpeta, nombre), plot = p, width = ancho,
      height = alto, dpi = 180, bg = "white")
}

bj_juntar <- function(objetos) {
  z <- do.call(rbind, objetos)
  rownames(z) <- NULL
  z
}

bj_lb <- function(r, L, gl = 0L) {
  as.numeric(stats::Box.test(as.numeric(r), lag = L,
          type = "Ljung-Box", fitdf = gl)$p.value)
}

bj_correlaciones <- function(y, metadatos = list(), L = 48L) {
  y <- as.numeric(y)
  L <- min(as.integer(L), length(y) - 2L)
  ac <- as.numeric(stats::acf(y, lag.max = L, plot = FALSE)$acf)[-1L]
  pa <- as.numeric(stats::pacf(y, lag.max = L, plot = FALSE)$acf)
  tabla <- rbind(
    data.frame(tipo = "FAC", rezago = seq_along(ac), valor = ac,
      banda = 1.96 / sqrt(length(y))),
    data.frame(tipo = "FACP", rezago = seq_along(pa), valor = pa,
      banda = 1.96 / sqrt(length(y)))
  )
  for (nm in names(metadatos)) tabla[[nm]] <- metadatos[[nm]]
  tabla[, c(names(metadatos), "tipo", "rezago", "valor", "banda"), drop = FALSE]
}

bj_grafico_corr <- function(tabla, titulo, subtitulo = NULL, nota = NULL,
          ylab = "Correlacion", cortes = c(1, 6, 12, 24, 36, 48)) {
  p <- ggplot2::ggplot(tabla, ggplot2::aes(rezago, valor)) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey60") +
    ggplot2::geom_vline(xintercept = c(12, 24, 36, 48), colour = "grey85", linetype = 3) +
    ggplot2::geom_segment(ggplot2::aes(xend = rezago, yend = 0), colour = "#006D77") +
    ggplot2::geom_line(ggplot2::aes(y = banda), linetype = 2, colour = "grey50") +
    ggplot2::geom_line(ggplot2::aes(y = -banda), linetype = 2, colour = "grey50") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::labs(title = titulo, subtitle = subtitulo, caption = nota,
       x = "Rezago mensual", y = ylab)
  if (!is.null(cortes)) p <- p + ggplot2::scale_x_continuous(breaks = cortes)
  p
}

bj_multiplicar <- function(a, b) {
  z <- numeric(length(a) + length(b) - 1L)
  for (i in seq_along(a)) {
    for (j in seq_along(b)) z[i + j - 1L] <- z[i + j - 1L] + a[i] * b[j]
  }
  z
}

bj_raices_coef <- function(cf, tipo, periodo = 12L) {
  reg <- unname(cf[grep(paste0("^", tipo, "[0-9]+$"), names(cf))])
  est <- unname(cf[grep(paste0("^s", tipo, "[0-9]+$"), names(cf))])
  signo <- if (tipo == "ar") -1 else 1
  estacional <- c(1, rep(0, periodo * length(est)))
  if (length(est)) estacional[1L + periodo * seq_along(est)] <- signo * est
  pol <- bj_multiplicar(c(1, signo * reg), estacional)
  while (length(pol) > 1L && tail(pol, 1L) == 0) pol <- head(pol, -1L)
  if (length(pol) == 1L) complex() else base::polyroot(pol)
}








# ============================================================================
# BLOQUE 01 — Preparacion y exploracion
# Se conservan controles de calendario, muestra, escalas y dispersion.
# ============================================================================


ejecutar_bloque_01 <- function() {

  # 1. Configuracion ----------------------------------------------------------

  paquetes <- c("DBI", "RSQLite", "ggplot2")

  faltan <- paquetes[
    !vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)
  ]

  if (length(faltan) > 0L) {
    stop("Faltan paquetes: ", paste(faltan, collapse = ", "))
  }

  raiz <- normalizePath(".", winslash = "/", mustWork = TRUE)

  if (basename(raiz) != "forecasting-remision-leche-uy") {
    stop("Abri el proyecto forecasting-remision-leche-uy en RStudio.")
  }

  corte <- as.Date("2025-09-01")
  ruta_db <- file.path(raiz, "database", "forecasting.sqlite")

  if (!file.exists(ruta_db)) {
    stop("No existe database/forecasting.sqlite.")
  }

  carpeta <- file.path(
    raiz, "outputs", "sarima_box_jenkins", "01_exploracion"
  )

  # 2. Lectura: solamente datos del periodo de desarrollo ---------------------

  leer_desarrollo <- function() {

    con <- DBI::dbConnect(
      RSQLite::SQLite(),
      dbname = ruta_db,
      flags = RSQLite::SQLITE_RO
    )

    on.exit(DBI::dbDisconnect(con), add = TRUE)

    DBI::dbGetQuery(
      con,
      "SELECT fecha, remision_litros
       FROM analitica_remision_mensual
       WHERE fecha <= ?
       ORDER BY fecha",
      params = list(as.character(corte))
    )
  }

  datos <- leer_desarrollo()

  if (nrow(datos) == 0L) {
    stop("La consulta no devolvio observaciones.")
  }

  datos$fecha <- as.Date(datos$fecha)

  # 3. Controles de integridad -------------------------------------------------

  if (anyNA(datos$fecha)) {
    stop("Existen fechas faltantes o no interpretables.")
  }

  if (anyDuplicated(datos$fecha) > 0L) {
    stop("Existen fechas duplicadas.")
  }

  if (any(format(datos$fecha, "%d") != "01")) {
    stop("Las fechas deben corresponder al primer dia de cada mes.")
  }

  calendario <- seq(
    min(datos$fecha),
    max(datos$fecha),
    by = "month"
  )

  if (!identical(datos$fecha, calendario)) {
    stop("La serie tiene meses faltantes o un calendario irregular.")
  }

  if (max(datos$fecha) != corte) {
    stop("El periodo de desarrollo no llega al corte establecido.")
  }

  if (!is.numeric(datos$remision_litros)) {
    stop("remision_litros debe ser numerica.")
  }

  if (any(!is.finite(datos$remision_litros)) ||
      any(datos$remision_litros <= 0)) {
    stop("Existen valores faltantes, no finitos o no positivos.")
  }

  # 4. Variables para explorar -------------------------------------------------
  #
  # La media diaria sigue siendo una serie de frecuencia mensual.
  # Dividir por dias corrige la distinta duracion de los meses,
  # pero no elimina necesariamente la estacionalidad.

  siguiente_mes <- as.Date(
    format(datos$fecha + 32, "%Y-%m-01")
  )

  datos$dias_mes <- as.integer(siguiente_mes - datos$fecha)

  datos$remision_diaria <- datos$remision_litros / datos$dias_mes
  datos$log_diaria <- log(datos$remision_diaria)

  datos$anio <- as.integer(format(datos$fecha, "%Y"))
  datos$mes <- as.integer(format(datos$fecha, "%m"))

  # 5. Tablas descriptivas -----------------------------------------------------

  variables <- c(
    "remision_litros",
    "remision_diaria",
    "log_diaria"
  )

  resumen <- do.call(rbind, lapply(variables, function(v) {

    y <- datos[[v]]

    data.frame(
      variable = v,
      n = length(y),
      minimo = min(y),
      media = mean(y),
      mediana = stats::median(y),
      maximo = max(y),
      desviacion_estandar = stats::sd(y)
    )
  }))

  anual <- do.call(
    rbind,
    lapply(split(datos, datos$anio), function(z) {

      data.frame(
        anio = z$anio[1],
        meses = nrow(z),
        completo = nrow(z) == 12L,
        media_mensual = mean(z$remision_litros),
        sd_mensual = stats::sd(z$remision_litros),
        media_diaria = mean(z$remision_diaria),
        sd_diaria = stats::sd(z$remision_diaria),
        media_log_diaria = mean(z$log_diaria),
        sd_log_diaria = stats::sd(z$log_diaria)
      )
    })
  )

  rownames(anual) <- NULL
  anios_completos <- anual$anio[anual$completo]

  if (length(anios_completos) < 3L) {
    stop("Hay menos de tres anios completos para la exploracion anual.")
  }

  # Perfil mensual: solo anios completos.
  #
  # Restamos la media anual del logaritmo para visualizar el perfil
  # dentro del anio sin confundirlo tanto con diferencias de nivel
  # entre anios. Es un recurso descriptivo, no la transformacion
  # que utilizaremos automaticamente para estimar el SARIMA.

  perfil <- datos[datos$anio %in% anios_completos, ]

  perfil$desvio_log_anual <- perfil$log_diaria -
    ave(perfil$log_diaria, perfil$anio, FUN = mean)

  nombres_meses <- c(
    "Ene", "Feb", "Mar", "Abr", "May", "Jun",
    "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"
  )

  perfil$mes_nombre <- factor(
    perfil$mes,
    levels = 1:12,
    labels = nombres_meses
  )

  # 6. Grafico de las tres escalas ---------------------------------------------

  etiquetas <- c(
    "Remision mensual (millones de litros)",
    "Remision media diaria (millones de litros)",
    "Logaritmo de la remision media diaria"
  )

  escalas <- rbind(
    data.frame(
      fecha = datos$fecha,
      escala = etiquetas[1],
      valor = datos$remision_litros / 1e6
    ),
    data.frame(
      fecha = datos$fecha,
      escala = etiquetas[2],
      valor = datos$remision_diaria / 1e6
    ),
    data.frame(
      fecha = datos$fecha,
      escala = etiquetas[3],
      valor = datos$log_diaria
    )
  )

  escalas$escala <- factor(escalas$escala, levels = etiquetas)

  p1 <- ggplot2::ggplot(
    escalas,
    ggplot2::aes(x = fecha, y = valor)
  ) +
    ggplot2::geom_line(colour = "#006D77", linewidth = 0.5) +
    ggplot2::facet_wrap(
      ~ escala,
      ncol = 1,
      scales = "free_y"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::labs(
      title = "Remision: niveles y transformacion candidata",
      subtitle = paste("Periodo de desarrollo hasta", corte),
      x = NULL,
      y = NULL,
      caption = "Cada panel tiene su propia escala vertical."
    )

  # 7. Grafico del perfil mensual ----------------------------------------------

  p2 <- ggplot2::ggplot(
    perfil,
    ggplot2::aes(x = mes_nombre, y = desvio_log_anual)
  ) +
    ggplot2::geom_hline(
      yintercept = 0,
      colour = "grey60",
      linetype = 2
    ) +
    ggplot2::geom_boxplot(
      fill = "#83C5BE",
      outlier.shape = NA
    ) +
    ggplot2::geom_point(
      position = ggplot2::position_jitter(
        width = 0.12,
        height = 0,
        seed = 601
      ),
      alpha = 0.45,
      size = 1.3
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::labs(
      title = "Perfil mensual de la remision media diaria",
      subtitle = "Desvios del logaritmo respecto de su media anual",
      x = NULL,
      y = "Desvio logaritmico",
      caption = paste(
        "Solo anios completos. Los puntos representan observaciones;",
        "no constituyen una clasificacion de outliers."
      )
    )

  # 8. Grafico de nivel y dispersion anual -------------------------------------
  #
  # La desviacion estandar dentro del anio mezcla estacionalidad,
  # cambios de nivel y fluctuaciones irregulares.
  # Este grafico orienta la exploracion; no es un test de varianza.

  ac <- anual[anual$completo, ]

  dispersion <- rbind(
    data.frame(
      anio = ac$anio,
      escala = "Remision mensual",
      media = ac$media_mensual / 1e6,
      sd = ac$sd_mensual / 1e6
    ),
    data.frame(
      anio = ac$anio,
      escala = "Remision media diaria",
      media = ac$media_diaria / 1e6,
      sd = ac$sd_diaria / 1e6
    )
  )

  p3 <- ggplot2::ggplot(
    dispersion,
    ggplot2::aes(x = media, y = sd)
  ) +
    ggplot2::geom_point(colour = "#006D77", size = 2) +
    ggplot2::geom_text(
      ggplot2::aes(label = anio),
      vjust = -0.7,
      size = 3,
      check_overlap = TRUE
    ) +
    ggplot2::facet_wrap(~ escala, scales = "free") +
    ggplot2::scale_y_continuous(
      expand = ggplot2::expansion(mult = c(0.05, 0.15))
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::labs(
      title = "Nivel y dispersion dentro de cada anio",
      subtitle = "Cada punto representa un anio completo",
      x = "Media anual de las observaciones mensuales (millones)",
      y = "Desviacion estandar dentro del anio (millones)",
      caption = "Relacion descriptiva: no determina por si sola la transformacion."
    )

  # 9. Guardar resultados ------------------------------------------------------

  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)

  guardar_csv <- function(objeto, nombre) bj_csv(objeto, carpeta, nombre)

  guardar_csv(datos, "01_datos_desarrollo.csv")
  guardar_csv(resumen, "02_resumen_variables.csv")
  guardar_csv(anual, "03_resumen_anual.csv")
  guardar_csv(perfil, "04_perfil_mensual.csv")

  guardar_figura <- function(p, nombre, alto) bj_figura(p, carpeta, nombre, alto, ancho = 11)

  guardar_figura(p1, "01_series_escalas.png", alto = 9)
  guardar_figura(p2, "02_perfil_mensual.png", alto = 6)
  guardar_figura(p3, "03_nivel_dispersion.png", alto = 6)

  capture.output(
    utils::sessionInfo(),
    file = file.path(carpeta, "05_sessionInfo.txt")
  )

  # 10. Resultados en consola y objeto para continuar --------------------------

  cat("\nBLOQUE 1 COMPLETADO\n")
  cat("Periodo:", as.character(min(datos$fecha)), "a",
      as.character(max(datos$fecha)), "\n")
  cat("Observaciones mensuales:", nrow(datos), "\n")
  cat("Anios completos:", length(anios_completos), "\n")
  cat("Calendario: mensual, sin huecos ni duplicados.\n")
  cat("Valores: positivos y finitos.\n")
  cat("No se leyeron valores posteriores al corte.\n")

  cat("\nRESUMEN DE VARIABLES\n")
  print(resumen, row.names = FALSE, digits = 6)

  cat("\nRESUMEN ANUAL\n")
  print(anual, row.names = FALSE, digits = 6)

  cat("\nResultados guardados en:\n", carpeta, "\n")
  cat("\nPENDIENTE: revisar transformacion, variabilidad y perfil mensual.\n")
  cat("Todavia no se decidieron d, D ni los ordenes AR/MA.\n")

  print(p1)
  print(p2)
  print(p3)

  invisible(list(
    corte = corte,
    datos = datos,
    resumen = resumen,
    anual = anual,
    perfil = perfil,
    figuras = list(escalas = p1, mensual = p2, dispersion = p3),
    carpeta = carpeta
  ))
}


# ============================================================================
# BLOQUE 01B — AUTO.ARIMA COMO REFERENCIA INICIAL LIBRE
# Referencia exploratoria sobre log diario, sin meses ni outliers prefijados.
# Elige d/D y dinamica dentro de limites explicitos. No decide el modelo manual.
# La auditoria comparable con meses y efectos se realiza al final, en 08B.
# Fuente: taller 05B (auto.arima auditor) y documentacion oficial de forecast.
# https://pkg.robjhyndman.com/forecast/reference/auto.arima.html
# ============================================================================

bj_ajustar_auto <- function(y, X = NULL, condicionado = FALSE) {
  bj_paquetes("forecast")
  # Limites de orden del auditor del taller: p/q hasta 2, P/Q hasta 1.
  # Busqueda no stepwise, sin aproximacion de los criterios, misma ML.
  args <- list(
    y = y, max.p = 2L, max.q = 2L, max.P = 1L, max.Q = 1L,
    max.order = 5L, max.d = 2L, max.D = 1L, seasonal = TRUE,
    stepwise = FALSE, approximation = FALSE, ic = "aicc", method = "ML",
    allowmean = !condicionado, allowdrift = !condicionado,
    lambda = NULL, parallel = FALSE, trace = FALSE
  )
  if (condicionado) {
    # y ya esta diferenciado: d=0/D=0 aqui equivale a d=1/D=0 original.
    args$d <- 0L
    args$D <- 0L
    args$stationary <- TRUE
    args$xreg <- as.matrix(X)
  } else {
    args$d <- NA_integer_
    args$D <- NA_integer_
    args$test <- "kpss"
    args$seasonal.test <- "seas"
  }
  avisos <- character()
  fit <- withCallingHandlers(do.call(forecast::auto.arima, args), warning = function(w) {
    avisos <<- c(avisos, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  if (!is.null(fit$code) && fit$code != 0L) stop("auto.arima no convergio.")
  if (any(!is.finite(stats::coef(fit))) || !is.finite(fit$sigma2) || fit$sigma2 <= 0) {
    stop("auto.arima devolvio parametros no validos.")
  }
  # Guardar datos/regresores concretos evita depender de expresiones locales
  # en fit$call cuando se reutilice este modelo mas adelante.
  if ("x" %in% names(fit$call)) fit$call$x <- y
  if ("y" %in% names(fit$call)) fit$call$y <- y
  fit$call[[1L]] <- quote(forecast::auto.arima)
  fit$x <- y
  if (!is.null(X)) { fit$call$xreg <- as.matrix(X); fit$xreg <- as.matrix(X) }
  a <- as.integer(fit$arma)
  d_original <- if (condicionado) 1L else a[6L]
  D_original <- if (condicionado) 0L else a[7L]
  e <- as.numeric(stats::residuals(fit))
  if (any(!is.finite(e))) stop("Innovaciones no finitas en auto.arima.")
  k <- length(stats::coef(fit)) + 1L
  n_ic <- length(y) - a[6L] - 12L * a[7L]
  ll <- as.numeric(stats::logLik(fit))
  df <- sum(a[1:4])
  V <- fit$var.coef
  Vok <- is.matrix(V) && nrow(V) == length(stats::coef(fit)) &&
    all(is.finite(V)) && all(diag(V) > 0)
  if (Vok) Vok <- tryCatch({ chol(V); TRUE }, error = function(e) FALSE)
  rAR <- bj_raices_coef(stats::coef(fit), "ar", a[5L])
  rMA <- bj_raices_coef(stats::coef(fit), "ma", a[5L])
  minimo <- function(z) if (length(z)) min(Mod(z)) else Inf
  resumen <- data.frame(
    candidato = if (condicionado) "auto_condicionado" else "auto_inicial_libre",
    modelo_nivel = sprintf("(%d,%d,%d)(%d,%d,%d)[12]", a[1L], d_original, a[2L],
          a[3L], D_original, a[4L]),
    incluye_media = "intercept" %in% names(stats::coef(fit)),
    incluye_deriva = "drift" %in% names(stats::coef(fit)),
    n_niveles = if (condicionado) length(y) + 1L else length(y),
    n_para_IC = n_ic, parametros_con_varianza = k,
    matriz_cov_valida = Vok, raiz_AR_minima = minimo(rAR), raiz_MA_minima = minimo(rMA),
    AICc = -2 * ll + 2 * k + 2 * k * (k + 1) / (n_ic - k - 1),
    BIC = -2 * ll + log(n_ic) * k, sigma_innovacion = sqrt(mean(e^2)),
    LB12 = bj_lb(e, 12L, df), LB24 = bj_lb(e, 24L, df), LB36 = bj_lb(e, 36L, df),
    version_forecast = as.character(utils::packageVersion("forecast")),
    avisos = paste(unique(avisos), collapse = " | "), stringsAsFactors = FALSE
  )
  ajustes <- data.frame(
    parametro = c("p/q maximos", "P/Q maximos", "max.order", "criterio", "stepwise",
       "approximation", "method", "regresores", "d y D", "seleccion d", "seleccion D"),
    valor = c("2 / 2", "1 / 1", "5", "AICc", "FALSE", "FALSE", "ML",
      if (condicionado) paste(ncol(X), "regresores: meses y efectos de 08") else "Ninguno",
      if (condicionado) "0/0 sobre Delta log: 1/0 en niveles" else "Elegidos por el algoritmo",
      if (condicionado) "Fijado" else "KPSS",
      if (condicionado) "Fijado" else "Fuerza estacional (seas); no es HEGY")
  )
  se <- if (Vok) sqrt(diag(V)) else rep(NA_real_, length(stats::coef(fit)))
  coeficientes <- data.frame(termino = names(stats::coef(fit)),
          estimacion = unname(stats::coef(fit)), se_condicional = unname(se))
  list(modelo = fit, resumen = resumen, coeficientes = coeficientes,
       configuracion = ajustes, avisos = avisos, condicionado = condicionado,
       serie = y, regresores = X)
}

ejecutar_bloque_01b <- function(bloque01) {
  datos <- bloque01$datos
  if (nrow(datos) != 285L || any(!is.finite(datos$log_diaria)) ||
      max(as.Date(datos$fecha)) != as.Date("2025-09-01")) stop("Muestra de 01 no valida.")
  x <- stats::ts(datos$log_diaria, start = c(2002, 1), frequency = 12)
  cat("\nAUTO.ARIMA INICIAL: referencia exploratoria; puede tardar.\n")
  salida <- bj_ajustar_auto(x)
  carpeta <- file.path(dirname(bloque01$carpeta), "01b_auto_arima_inicial")
  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
  bj_csv(salida$resumen, carpeta, "01_modelo_elegido.csv")
  bj_csv(salida$configuracion, carpeta, "02_configuracion.csv")
  bj_csv(salida$coeficientes, carpeta, "03_coeficientes.csv")
  bj_csv(data.frame(fecha = datos$fecha,
        innovacion = as.numeric(stats::residuals(salida$modelo))),
   carpeta, "04_innovaciones.csv")
  writeLines(c(
    "Referencia automatica inicial sobre log diario y toda la muestra de desarrollo.",
    "Sin efectos mensuales ni outliers introducidos manualmente; d/D se eligen automaticamente.",
    "Los limites dinamicos p/q<=2, P/Q<=1 y max.order=5 proceden del auditor del taller 05B.",
    "seas selecciona D por fuerza estacional; no equivale al contraste HEGY del bloque 02A.",
    "No usar sus IC para ordenar junto al manual si difieren diferencias, regresores o muestra efectiva.",
    "El auditor 08B permite la comparacion manteniendo la arquitectura manual.",
    "Su eleccion no sustituye identificacion, estimacion y validacion Box-Jenkins."
  ), file.path(carpeta, "05_alcance.txt"))
  writeLines(capture.output(utils::sessionInfo()), file.path(carpeta, "06_sessionInfo.txt"))
  salida$fechas <- as.Date(datos$fecha)
  salida$carpeta <- carpeta
  saveRDS(salida, file.path(carpeta, "07_objeto_01b.rds"))
  cat("\nBLOQUE 01B — REFERENCIA AUTOMATICA INICIAL\n")
  print(salida$resumen, row.names = FALSE, digits = 6)
  cat("Referencia libre; no se modifica ninguna decision manual.\n")
  if (length(salida$avisos)) cat("Avisos:", paste(salida$avisos, collapse = " | "), "\n")
  cat("Resultados en:\n", carpeta, "\n")
  invisible(salida)
}




# ============================================================================
# BLOQUE 02A — Raices unitarias estacionales
# HEGY y sensibilidad a meses/rezagos; no fija D automaticamente.
# ============================================================================


ejecutar_bloque_02a <- function(bloque01) {

  # 1. Dependencias y datos ----------------------------------------------------

  paquetes <- c("uroot", "ggplot2")

  faltan <- paquetes[
    !vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)
  ]

  if (length(faltan) > 0L) {
    stop("Faltan paquetes: ", paste(faltan, collapse = ", "))
  }

  datos <- bloque01$datos

  if (!all(c("fecha", "log_diaria") %in% names(datos))) {
    stop("bloque01 no contiene las variables necesarias.")
  }

  if (any(!is.finite(datos$log_diaria))) {
    stop("La variable log_diaria contiene valores no finitos.")
  }

  if (max(datos$fecha) != bloque01$corte) {
    stop("El periodo no coincide con el corte del bloque 1.")
  }

  x <- stats::ts(
    datos$log_diaria,
    start = c(
      as.integer(format(datos$fecha[1], "%Y")),
      as.integer(format(datos$fecha[1], "%m"))
    ),
    frequency = 12
  )

  carpeta <- file.path(
    dirname(bloque01$carpeta),
    "02a_raices_estacionales"
  )

  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)

  guardar_csv <- function(objeto, nombre) bj_csv(objeto, carpeta, nombre)

  guardar_figura <- function(p, nombre, alto) bj_figura(p, carpeta, nombre, alto, ancho = 11)

  # 2. Representaciones exploratorias -----------------------------------------
  #
  # Las diferencias son alternativas que vamos a observar.
  # Construirlas NO significa haber decidido utilizarlas.
  #
  # La diferencia a 12 meses tambien contiene el factor (1-L).
  # No la interpretamos como una transformacion exclusivamente estacional.

  etiquetas <- c(
    "Log diario: sin diferencias",
    "Diferencia regular: x[t] - x[t-1]",
    "Diferencia estacional: x[t] - x[t-12]"
  )

  series <- list(
    as.numeric(x),
    as.numeric(diff(x)),
    as.numeric(diff(x, lag = 12))
  )

  names(series) <- etiquetas

  fechas <- list(
    datos$fecha,
    datos$fecha[-1],
    datos$fecha[-seq_len(12)]
  )

  transformaciones <- do.call(
    rbind,
    lapply(seq_along(series), function(i) {
      data.frame(
        fecha = fechas[[i]],
        representacion = etiquetas[i],
        valor = series[[i]]
      )
    })
  )

  transformaciones$representacion <- factor(
    transformaciones$representacion,
    levels = etiquetas
  )

  p1 <- ggplot2::ggplot(
    transformaciones,
    ggplot2::aes(fecha, valor)
  ) +
    ggplot2::geom_line(colour = "#006D77", linewidth = 0.5) +
    ggplot2::facet_wrap(
      ~ representacion,
      ncol = 1,
      scales = "free_y"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::labs(
      title = "Serie y diferencias candidatas",
      subtitle = "Exploracion: todavia no se eligen d ni D",
      x = NULL,
      y = NULL
    )

  # FAC/FACP en rezagos mensuales, excluyendo el rezago cero.
  # Las bandas son referencias individuales aproximadas bajo ruido blanco.

  correlograma <- function(y, nombre) bj_correlaciones(y, list(representacion = nombre))

  correlogramas <- do.call(
    rbind,
    lapply(names(series), function(nm) {
      correlograma(series[[nm]], nm)
    })
  )

  correlogramas$representacion <- factor(
    correlogramas$representacion,
    levels = etiquetas
  )

  p2 <- bj_grafico_corr(correlogramas,
    "FAC y FACP de las representaciones exploratorias",
    subtitulo = "No identificar ordenes antes de establecer estacionariedad",
    nota = "Bandas individuales orientativas; no validan estacionariedad.") +
    ggplot2::facet_grid(representacion ~ tipo)


  # 3. Especificaciones HEGY ---------------------------------------------------
  #
  # deterministic = c(constante, tendencia, indicadores estacionales).
  #
  # Hasta 24 rezagos de la variable dependiente de la regresion auxiliar.
  # AIC/BIC seleccionan entre 0 y 24, con muestra comun para compararlos.
  #
  # Estos rezagos NO son los ordenes AR/MA del futuro SARIMA.
  # Si aparece autocorrelacion residual o seleccion en el limite,
  # revisaremos el contraste antes de interpretar sus conclusiones.

  especificaciones <- list(
    principal_AIC = list(
      det = c(1, 1, 1),
      criterio = "AIC",
      descripcion = "Constante + tendencia + meses"
    ),
    principal_BIC = list(
      det = c(1, 1, 1),
      criterio = "BIC",
      descripcion = "Constante + tendencia + meses"
    ),
    sin_meses_AIC = list(
      det = c(1, 1, 0),
      criterio = "AIC",
      descripcion = "Constante + tendencia"
    ),
    sin_meses_BIC = list(
      det = c(1, 1, 0),
      criterio = "BIC",
      descripcion = "Constante + tendencia"
    )
  )

  K <- 24L

  frecuencias <- c(
    "t_1" = "Cero: raiz regular",
    "t_2" = "Pi: periodo de 2 meses",
    "F_3:4" = "Pi/6: periodo de 12 meses",
    "F_5:6" = "Pi/3: periodo de 6 meses",
    "F_7:8" = "Pi/2: periodo de 4 meses",
    "F_9:10" = "2Pi/3: periodo de 3 meses",
    "F_11:12" = "5Pi/6: periodo de 2.4 meses",
    "F_2:12" = "Conjunto de raices estacionales",
    "F_1:12" = "Conjunto de todas las raices"
  )

  # Ljung-Box como señal auxiliar orientativa.
  # fitdf=0: no se presenta como una prueba calibrada especificamente
  # para la regresion HEGY ni se utiliza para elegir automaticamente D.

  lb_orientativo <- function(r, L) bj_lb(r, L, 0L)

  resultados <- list()
  diagnosticos <- list()
  objetos <- list()
  acf_auxiliares <- list()

  # 4. Ejecutar contrastes y registrar advertencias ----------------------------

  for (nm in names(especificaciones)) {

    sp <- especificaciones[[nm]]
    avisos <- character()

    cat("\nCalculando HEGY:", nm, "\n")

    fit <- tryCatch(
      withCallingHandlers(
        uroot::hegy.test(
          x,
          deterministic = sp$det,
          lag.method = sp$criterio,
          maxlag = K,
          pvalue = "RS"
        ),
        warning = function(w) {
          avisos <<- c(avisos, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) {
        stop(
          "Fallo HEGY en ", nm, ": ", conditionMessage(e),
          call. = FALSE
        )
      }
    )

    objetos[[nm]] <- fit

    estadisticos <- fit$statistics
    pv <- as.numeric(fit$pvalues)
    pruebas <- names(estadisticos)

    if (is.null(pruebas) ||
        length(pv) != length(estadisticos)) {
      stop("Formato inesperado en los resultados HEGY: ", nm)
    }

    resultados[[nm]] <- data.frame(
      especificacion = nm,
      prueba = pruebas,
      frecuencia = unname(frecuencias[pruebas]),
      estadistico = as.numeric(estadisticos),
      p_value = pv,
      rechaza_H0_5pct = ifelse(
        is.finite(pv),
        pv < 0.05,
        NA
      ),
      k_auxiliar = as.integer(fit$lag.order)
    )

    r <- as.numeric(stats::residuals(fit$fitted.model))

    if (any(!is.finite(r))) {
      stop("Residuos auxiliares no finitos en: ", nm)
    }

    diagnosticos[[nm]] <- data.frame(
      especificacion = nm,
      deterministico = sp$descripcion,
      criterio = sp$criterio,
      kmax = K,
      k_elegido = as.integer(fit$lag.order),
      en_limite = fit$lag.order == K,
      n_auxiliar = length(r),
      LB24_orientativo = lb_orientativo(r, 24),
      LB36_orientativo = lb_orientativo(r, 36),
      valores_p_finitos = all(is.finite(pv)),
      avisos = paste(unique(avisos), collapse = " | ")
    )

    ac <- as.numeric(
      stats::acf(r, lag.max = 48, plot = FALSE)$acf
    )[-1]

    acf_auxiliares[[nm]] <- data.frame(
      especificacion = nm,
      rezago = seq_along(ac),
      valor = ac,
      banda = 1.96 / sqrt(length(r))
    )
  }

  resultados <- do.call(rbind, resultados)
  diagnosticos <- do.call(rbind, diagnosticos)
  acf_auxiliares <- do.call(rbind, acf_auxiliares)

  rownames(resultados) <- NULL
  rownames(diagnosticos) <- NULL
  rownames(acf_auxiliares) <- NULL

  # 5. FAC de los residuos de las regresiones HEGY -----------------------------

  p3 <- bj_grafico_corr(acf_auxiliares,
    "Autocorrelacion residual de las auxiliares HEGY",
    subtitulo = "Revisar las auxiliares antes de interpretar los contrastes",
    nota = "Bandas orientativas; no constituyen una prueba conjunta.", ylab = "FAC") +
    ggplot2::facet_wrap(~ especificacion, ncol = 2)


  # 6. Guardar y mostrar ------------------------------------------------------

  guardar_csv(transformaciones, "01_transformaciones.csv")
  guardar_csv(resultados, "02_hegy_resultados.csv")
  guardar_csv(diagnosticos, "03_hegy_diagnosticos.csv")
  guardar_csv(correlogramas, "04_correlogramas.csv")
  guardar_csv(acf_auxiliares, "05_acf_auxiliares.csv")

  guardar_figura(p1, "01_series_diferencias.png", alto = 9)
  guardar_figura(p2, "02_fac_facp_transformaciones.png", alto = 10)
  guardar_figura(p3, "03_acf_auxiliares_hegy.png", alto = 7)

  capture.output(
    utils::sessionInfo(),
    file = file.path(carpeta, "06_sessionInfo.txt")
  )

  cat("\nDIAGNOSTICO DE LAS REGRESIONES AUXILIARES\n")
  print(diagnosticos, row.names = FALSE, digits = 4)

  cat("\nHEGY: RESULTADOS POR FRECUENCIA\n")
  print(resultados, row.names = FALSE, digits = 5)

  cat("\nLECTURA:\n")
  cat("- H0: presencia de la raiz o del conjunto de raices indicado.\n")
  cat("- Un p pequeno aporta evidencia contra esa H0.\n")
  cat("- No rechazar no demuestra que la raiz exista.\n")
  cat("- Un rechazo conjunto no implica rechazar cada raiz individual.\n")
  cat("- k_auxiliar NO es el orden AR del SARIMA.\n")
  cat("- Los diagnosticos auxiliares deben revisarse antes de concluir.\n")

  cat("\nBLOQUE 2A COMPLETADO\n")
  cat("Resultados en:\n", carpeta, "\n")
  cat("PENDIENTE: interpretar la evidencia; no se han fijado d ni D.\n")

  print(p1)
  print(p2)
  print(p3)

  invisible(list(
    x = x,
    corte = bloque01$corte,
    resultados = resultados,
    diagnosticos = diagnosticos,
    objetos_hegy = objetos,
    transformaciones = transformaciones,
    carpeta = carpeta
  ))
}


# ============================================================================
# BLOQUE 02B — Integracion regular con efectos mensuales
# ADF/KPSS y diagnosticos auxiliares; la ejecucion correcta recibe bloque01.
# ============================================================================


ejecutar_bloque_02b <- function(bloque01) {

  # 1. Datos y configuracion ---------------------------------------------------

  paquetes <- c("urca", "ggplot2")

  faltan <- paquetes[
    !vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)
  ]

  if (length(faltan)) {
    stop("Faltan paquetes: ", paste(faltan, collapse = ", "))
  }

  datos <- bloque01$datos

  if (!all(c("fecha", "log_diaria", "mes") %in% names(datos))) {
    stop("Faltan variables del bloque 1.")
  }

  if (any(!is.finite(datos$log_diaria)) ||
      max(datos$fecha) != bloque01$corte) {
    stop("Datos invalidos o corte distinto al acordado.")
  }

  x <- datos$log_diaria

  casos <- list(
    niveles_tendencia_meses = list(
      y = x,
      meses = datos$mes,
      tendencia = TRUE
    ),
    niveles_constante_meses = list(
      y = x,
      meses = datos$mes,
      tendencia = FALSE
    ),
    diferencia_constante_meses = list(
      y = diff(x),
      meses = datos$mes[-1],
      tendencia = FALSE
    )
  )

  K <- 24L

  carpeta <- file.path(
    dirname(bloque01$carpeta),
    "02b_integracion_regular"
  )

  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)

  guardar_csv <- function(objeto, nombre) bj_csv(objeto, carpeta, nombre)

  # 2. Regresion ADF con indicadores mensuales --------------------------------
  #
  # Delta y[t] =
  #   constante + rho*y[t-1] + tendencia opcional
  #   + indicadores mensuales
  #   + rezagos de Delta y[t] + error.
  #
  # K permite usar una muestra comun al comparar AIC/BIC.
  # Luego se reestima cada orden usando todas sus observaciones disponibles.

  auxiliar_adf <- function(y, meses, tendencia, k, K = k) {

    n <- length(y)
    dy <- diff(y)
    t <- seq.int(K + 2L, n)

    dat <- data.frame(
      dy = dy[t - 1L],
      yl = y[t - 1L],
      mes = factor(meses[t], levels = 1:12)
    )

    if (tendencia) {
      dat$tendencia <- t
    }

    if (k > 0L) {
      for (j in seq_len(k)) {
        dat[[paste0("d", j)]] <- dy[t - j - 1L]
      }
    }

    stats::lm(dy ~ ., data = dat)
  }

  # Diagnostico orientativo, igual que en el bloque 2A.
  # No se usa como selector automatico de d.
  # fitdf=0 no calibra especificamente la distribucion para esta auxiliar.

  lb_orientativo <- function(r, L) bj_lb(r, L, 0L)

  grillas <- list()
  selecciones <- list()
  fits_elegidos <- list()
  acf_elegidas <- list()

  # 3. Seleccion de rezagos auxiliares por AIC y BIC ---------------------------

  for (nm in names(casos)) {

    cat("\nADF:", nm, "\n")

    caso <- casos[[nm]]

    tipo <- if (caso$tendencia) "trend" else "drift"
    tau <- if (caso$tendencia) "tau3" else "tau2"

    # ur.df aporta las tablas de referencia no estandar.
    # El estadistico que evaluamos se calcula en nuestra regresion
    # ampliada con indicadores mensuales.

    referencia <- urca::ur.df(
      caso$y,
      type = tipo,
      lags = 0,
      selectlags = "Fixed"
    )

    criticos <- referencia@cval[tau, ]

    g <- do.call(
      rbind,
      lapply(0:K, function(k) {

        comun <- auxiliar_adf(
          caso$y, caso$meses, caso$tendencia,
          k = k, K = K
        )

        completo <- auxiliar_adf(
          caso$y, caso$meses, caso$tendencia,
          k = k
        )

        co <- summary(completo)$coefficients

        # Estadistico sobre rho, no su p ordinario de regresion.
        estadistico <- unname(co["yl", "t value"])

        r <- stats::residuals(completo)

        data.frame(
          caso = nm,
          k = k,
          n_comun = stats::nobs(comun),
          AIC_comun = stats::AIC(comun),
          BIC_comun = stats::BIC(comun),
          n_final = stats::nobs(completo),
          ADF = estadistico,
          critico_1 = unname(criticos["1pct"]),
          critico_5 = unname(criticos["5pct"]),
          critico_10 = unname(criticos["10pct"]),
          rechaza_raiz_5pct =
            estadistico < unname(criticos["5pct"]),
          LB24_orientativo = lb_orientativo(r, 24),
          LB36_orientativo = lb_orientativo(r, 36)
        )
      })
    )

    ka <- g$k[which.min(g$AIC_comun)]
    kb <- g$k[which.min(g$BIC_comun)]

    g$seleccion_AIC <- g$k == ka
    g$seleccion_BIC <- g$k == kb

    grillas[[nm]] <- g

    for (criterio in c("AIC", "BIC")) {

      k <- if (criterio == "AIC") ka else kb
      id <- paste(nm, criterio, sep = "__")

      fila <- g[g$k == k, , drop = FALSE]
      fila$criterio <- criterio
      fila$en_limite <- k == K

      selecciones[[id]] <- fila

      fit <- auxiliar_adf(
        caso$y, caso$meses, caso$tendencia,
        k = k
      )

      fits_elegidos[[id]] <- fit

      r <- as.numeric(stats::residuals(fit))

      ac <- as.numeric(
        stats::acf(r, lag.max = 48, plot = FALSE)$acf
      )[-1]

      acf_elegidas[[id]] <- data.frame(
        caso = nm,
        criterio = criterio,
        rezago = seq_along(ac),
        valor = ac,
        banda = 1.96 / sqrt(length(r))
      )
    }
  }

  grilla <- do.call(rbind, grillas)
  seleccion <- do.call(rbind, selecciones)
  acf_auxiliares <- do.call(rbind, acf_elegidas)

  rownames(grilla) <- NULL
  rownames(seleccion) <- NULL
  rownames(acf_auxiliares) <- NULL

  # 4. KPSS con los mismos componentes determinísticos -------------------------
  #
  # Primero estimamos:
  # y[t] = constante + meses + tendencia opcional + residuo.
  #
  # El estadistico KPSS utiliza las sumas acumuladas de esos residuos
  # y una estimacion Bartlett de su varianza de largo plazo.
  #
  # short/long son anchos de banda, NO ordenes AR.
  # Los valores criticos proceden de las tablas mu/tau de urca.

  resultados_kpss <- list()

  for (nm in names(casos)) {

    caso <- casos[[nm]]
    y <- caso$y
    n <- length(y)

    dat <- data.frame(
      y = y,
      mes = factor(caso$meses, levels = 1:12)
    )

    if (caso$tendencia) {
      dat$tendencia <- seq_len(n)
    }

    fit_det <- stats::lm(y ~ ., data = dat)
    r <- as.numeric(stats::residuals(fit_det))

    eta <- sum(cumsum(r)^2) / n^2
    tipo <- if (caso$tendencia) "tau" else "mu"

    for (banda in c("short", "long")) {

      multiplicador <- if (banda == "short") 4 else 12
      L <- as.integer(trunc(multiplicador * (n / 100)^0.25))

      var_lp <- sum(r^2) / n

      if (L > 0L) {
        for (j in seq_len(L)) {
          cov_j <- sum(r[(j + 1L):n] * r[1L:(n - j)]) / n
          peso <- 1 - j / (L + 1)
          var_lp <- var_lp + 2 * peso * cov_j
        }
      }

      if (!is.finite(var_lp) || var_lp <= 0) {
        stop("Varianza de largo plazo invalida en KPSS: ", nm)
      }

      estadistico <- eta / var_lp

      # Solo recuperamos las tablas de referencia de urca.
      ref <- urca::ur.kpss(
        y,
        type = tipo,
        lags = banda
      )

      cv <- ref@cval[1, ]

      resultados_kpss[[paste(nm, banda, sep = "__")]] <- data.frame(
        caso = nm,
        banda = banda,
        ancho_banda = L,
        KPSS = estadistico,
        critico_1 = unname(cv["1pct"]),
        critico_5 = unname(cv["5pct"]),
        critico_10 = unname(cv["10pct"]),
        rechaza_estacionariedad_5pct =
          estadistico > unname(cv["5pct"]),
        varianza_largo_plazo = var_lp
      )
    }
  }

  kpss <- do.call(rbind, resultados_kpss)
  rownames(kpss) <- NULL

  # 5. FAC residual de las auxiliares ADF seleccionadas -------------------------

  p <- bj_grafico_corr(acf_auxiliares,
    "Diagnostico de las regresiones auxiliares ADF",
    subtitulo = "Todas incluyen efectos mensuales",
    nota = "Bandas orientativas; no constituyen una prueba conjunta.", ylab = "FAC") +
    ggplot2::facet_grid(caso ~ criterio)


  # 6. Guardar y presentar -----------------------------------------------------

  guardar_csv(grilla, "01_adf_sensibilidad_rezagos.csv")
  guardar_csv(seleccion, "02_adf_seleccion.csv")
  guardar_csv(kpss, "03_kpss_resultados.csv")
  guardar_csv(acf_auxiliares, "04_acf_auxiliares.csv")

  ggplot2::ggsave(
    filename = file.path(carpeta, "01_acf_auxiliares_adf.png"),
    plot = p,
    width = 12,
    height = 10,
    dpi = 180,
    bg = "white"
  )

  capture.output(
    utils::sessionInfo(),
    file = file.path(carpeta, "05_sessionInfo.txt")
  )

  cat("\nADF: REZAGOS SELECCIONADOS Y DIAGNOSTICO\n")

  columnas <- c(
    "caso", "criterio", "k", "en_limite", "n_final",
    "ADF", "critico_5", "rechaza_raiz_5pct",
    "LB24_orientativo", "LB36_orientativo"
  )

  print(
    seleccion[, columnas],
    row.names = FALSE,
    digits = 5
  )

  cat("\nKPSS CON EFECTOS MENSUALES\n")
  print(kpss, row.names = FALSE, digits = 5)

  cat("\nLECTURA\n")
  cat("- ADF: estadistico mas negativo que el critico => rechazo de raiz.\n")
  cat("- KPSS: estadistico mayor que el critico => rechazo de estacionariedad.\n")
  cat("- Los valores criticos son aproximaciones de referencia.\n")
  cat("- Revisar sensibilidad a rezagos, determinísticos y ancho de banda.\n")
  cat("- Los rezagos auxiliares no son los ordenes AR del modelo.\n")
  cat("- No interpretar los p ordinarios de lm como p del contraste ADF.\n")

  cat("\nBLOQUE 2B COMPLETADO\n")
  cat("Resultados en:\n", carpeta, "\n")
  cat("D=0 sigue siendo la decision provisional del bloque 2A.\n")
  cat("PENDIENTE: interpretar estos resultados antes de elegir d.\n")

  print(p)

  invisible(list(
    seleccion_adf = seleccion,
    grilla_adf = grilla,
    kpss = kpss,
    auxiliares_adf = fits_elegidos,
    acf_auxiliares = acf_auxiliares,
    D_provisional = 0L,
    carpeta = carpeta
  ))
}


# ============================================================================
# BLOQUE 03 — Identificacion inicial de la dinamica
# Perfil mensual descriptivo, deriva y FAC/FACP antes de estimar ARMA.
# ============================================================================


ejecutar_bloque_03 <- function(bloque01) {

  # 1. Datos y configuracion ---------------------------------------------------

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Falta el paquete ggplot2.")
  }

  datos <- bloque01$datos

  if (!all(c("fecha", "log_diaria", "mes") %in% names(datos))) {
    stop("Faltan variables del bloque 1.")
  }

  if (any(!is.finite(datos$log_diaria)) ||
      max(datos$fecha) != bloque01$corte) {
    stop("Datos invalidos o corte distinto al acordado.")
  }

  carpeta <- file.path(
    dirname(bloque01$carpeta),
    "03_identificacion_dinamica"
  )

  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)

  guardar_csv <- function(objeto, nombre) bj_csv(objeto, carpeta, nombre)

  guardar_figura <- function(p, nombre, alto) bj_figura(p, carpeta, nombre, alto, ancho = 12)

  # 2. Primera diferencia -----------------------------------------------------

  z <- data.frame(
    fecha = datos$fecha[-1],
    mes = datos$mes[-1],
    diferencia_log = diff(datos$log_diaria)
  )

  z$mes_factor <- factor(z$mes, levels = 1:12)

  if (any(table(z$mes_factor) == 0L)) {
    stop("Faltan meses para estimar el perfil mensual.")
  }

  # 3. Ajuste descriptivo del perfil mensual -----------------------------------
  #
  # Estimamos una media de Delta x para cada mes.
  #
  # Cada media mensual combina:
  #   deriva + cambio estacional respecto del mes anterior.
  #
  # Para separarlos imponemos que los doce cambios estacionales sumen cero.
  # La deriva descriptiva es, por tanto, la media simple de las doce medias.
  #
  # Damos igual peso a los doce meses para que la descomposicion no dependa
  # de que algunos meses tengan una observacion mas que otros.
  #
  # No usamos los errores estandar ordinarios de lm para decidir deriva.

  ajuste_mensual <- stats::lm(
    diferencia_log ~ 0 + mes_factor,
    data = z
  )

  medias_mensuales <- unname(stats::coef(ajuste_mensual))

  if (length(medias_mensuales) != 12L ||
      any(!is.finite(medias_mensuales))) {
    stop("No se pudieron estimar las doce medias mensuales.")
  }

  deriva_descriptiva <- mean(medias_mensuales)

  cambios_estacionales <- medias_mensuales -
    deriva_descriptiva

  z$cambio_estacional <- cambios_estacionales[z$mes]

  # Conserva la deriva descriptiva, removiendo solo el perfil mensual.
  z$diferencia_ajustada <- z$diferencia_log -
    z$cambio_estacional

  # Remueve tambien la deriva para estudiar la dependencia alrededor de cero.
  z$componente_dinamico <- as.numeric(
    stats::residuals(ajuste_mensual)
  )

  nombres_meses <- c(
    "Ene", "Feb", "Mar", "Abr", "May", "Jun",
    "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"
  )

  perfil <- data.frame(
    mes = 1:12,
    nombre_mes = nombres_meses,
    n = as.integer(table(z$mes_factor)),
    media_diferencia_log = medias_mensuales,
    deriva_descriptiva = deriva_descriptiva,
    cambio_estacional = cambios_estacionales
  )

  # Estos cambios NO son los efectos mensuales en niveles.
  # Ejemplo: el cambio de octubre representa s_octubre - s_septiembre.

  # 4. Serie antes y despues del ajuste mensual -------------------------------

  etiquetas <- c(
    "Primera diferencia del log diario",
    "Primera diferencia ajustada por perfil mensual"
  )

  series_grafico <- rbind(
    data.frame(
      fecha = z$fecha,
      serie = etiquetas[1],
      valor = z$diferencia_log
    ),
    data.frame(
      fecha = z$fecha,
      serie = etiquetas[2],
      valor = z$diferencia_ajustada
    )
  )

  series_grafico$serie <- factor(
    series_grafico$serie,
    levels = etiquetas
  )

  p1 <- ggplot2::ggplot(
    series_grafico,
    ggplot2::aes(fecha, valor)
  ) +
    ggplot2::geom_hline(
      yintercept = deriva_descriptiva,
      colour = "#B45309",
      linetype = 2
    ) +
    ggplot2::geom_line(
      colour = "#006D77",
      linewidth = 0.5
    ) +
    ggplot2::facet_wrap(~ serie, ncol = 1) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::labs(
      title = "Primera diferencia y ajuste mensual provisional",
      subtitle = "Ambos paneles utilizan la misma escala vertical",
      x = NULL,
      y = "Diferencia logaritmica",
      caption = "La linea discontinua representa la deriva descriptiva."
    )

  # 5. FAC/FACP antes y despues del ajuste -------------------------------------

  series <- list(
    "Primera diferencia sin ajuste mensual" = z$diferencia_log,
    "Componente dinamico tras ajuste mensual" = z$componente_dinamico
  )

  correlograma <- function(y, nombre) bj_correlaciones(y, list(serie = nombre))

  correlogramas <- do.call(
    rbind,
    lapply(names(series), function(nm) {
      correlograma(series[[nm]], nm)
    })
  )

  correlogramas$serie <- factor(
    correlogramas$serie,
    levels = names(series)
  )

  p2 <- bj_grafico_corr(correlogramas,
    "Identificacion: dependencia antes y despues del ajuste mensual",
    nota = "El perfil fue estimado; las bandas no son una prueba conjunta.") +
    ggplot2::facet_grid(serie ~ tipo)


  # Detalle de los primeros doce rezagos.
  # La FACP de cada rezago condiciona por todos los rezagos anteriores.

  detalle <- correlogramas[
    correlogramas$serie == names(series)[2] &
      correlogramas$rezago <= 12,
  ]

  p3 <- bj_grafico_corr(detalle,
    "Componente dinamico: primeros doce rezagos",
    nota = "No agregar un parametro por cada barra fuera de banda.", cortes = 1:12) +
    ggplot2::facet_wrap(~ tipo, ncol = 2)


  # 6. Tablas para inspeccion --------------------------------------------------

  dinamica <- correlogramas[
    correlogramas$serie == names(series)[2],
  ]

  seleccion_rezagos <- dinamica[
    dinamica$rezago %in% c(1:6, 11:13, 23:25, 35:37, 48),
    c("tipo", "rezago", "valor", "banda")
  ]

  resumen <- data.frame(
    concepto = c(
      "d de trabajo",
      "D de trabajo",
      "Observaciones en primeras diferencias",
      "Deriva descriptiva en logaritmos por mes",
      "Suma de cambios estacionales",
      "Estado de la deriva",
      "Estado de los ordenes AR/MA"
    ),
    valor = c(
      "1",
      "0",
      as.character(nrow(z)),
      format(deriva_descriptiva, digits = 10),
      format(sum(cambios_estacionales), digits = 6),
      "Pendiente de evaluacion conjunta con la dinamica",
      "Pendientes de lectura de FAC/FACP"
    )
  )

  z$mes_factor <- NULL

  guardar_csv(z, "01_serie_identificacion.csv")
  guardar_csv(perfil, "02_perfil_mensual_diferencias.csv")
  guardar_csv(correlogramas, "03_fac_facp.csv")
  guardar_csv(resumen, "04_resumen_decisiones.csv")

  guardar_figura(p1, "01_serie_ajustada.png", alto = 7)
  guardar_figura(p2, "02_fac_facp_comparacion.png", alto = 8)
  guardar_figura(p3, "03_fac_facp_detalle.png", alto = 5)

  cat("\nBLOQUE 3: IDENTIFICACION DINAMICA\n")
  cat("d de trabajo = 1; D de trabajo = 0.\n")
  cat("Observaciones:", nrow(z), "\n")

  cat(
    "Deriva descriptiva:",
    format(deriva_descriptiva, digits = 7),
    "unidades logaritmicas por mes.\n"
  )

  cat("\nPERFIL MENSUAL DE LAS DIFERENCIAS\n")
  print(perfil, row.names = FALSE, digits = 5)

  cat("\nFAC/FACP DEL COMPONENTE DINAMICO: REZAGOS DE INTERES\n")
  print(seleccion_rezagos, row.names = FALSE, digits = 5)

  cat("\nINTERPRETACION PENDIENTE\n")
  cat("- Examinar cortes, decaimientos y patrones estacionales.\n")
  cat("- Proponer pocos candidatos, fundamentados en esos patrones.\n")
  cat("- Las barras aisladas pueden aparecer por azar.\n")
  cat("- Los residuos del ajuste mensual todavia no son innovaciones.\n")
  cat("- Deriva y efectos mensuales se reestimaran junto con el ARMA.\n")

  cat("\nResultados guardados en:\n", carpeta, "\n")

  print(p1)
  print(p2)
  print(p3)

  invisible(list(
    datos = z,
    perfil = perfil,
    deriva_descriptiva = deriva_descriptiva,
    ajuste_mensual_preliminar = ajuste_mensual,
    correlogramas = correlogramas,
    d = 1L,
    D = 0L,
    carpeta = carpeta
  ))
}


# ============================================================================
# BLOQUE 04 — Primeros candidatos y evaluacion de deriva
# Referencia, SAR1 y SMA1 con/sin deriva: parte necesaria de la decision.
# ============================================================================


ejecutar_bloque_04 <- function(bloque01) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Falta ggplot2.")
  }

  datos <- bloque01$datos

  if (any(!is.finite(datos$log_diaria)) ||
      max(datos$fecha) != bloque01$corte) {
    stop("Datos invalidos o corte distinto al acordado.")
  }

  fechas <- datos$fecha[-1]
  dy <- diff(datos$log_diaria)
  n <- length(dy)

  y <- stats::ts(
    dy,
    start = c(
      as.integer(format(fechas[1], "%Y")),
      as.integer(format(fechas[1], "%m"))
    ),
    frequency = 12
  )

  # Once contrastes mensuales con suma cero.
  # La media de los doce efectos mensuales es cero.
  # include.mean=TRUE permite una deriva; FALSE la fija en cero.

  mes <- factor(
    as.integer(format(fechas, "%m")),
    levels = 1:12
  )

  X <- stats::model.matrix(
    ~ mes,
    contrasts.arg = list(mes = stats::contr.sum(12))
  )[, -1, drop = FALSE]

  colnames(X) <- paste0("mes_contraste_", 1:11)

  estructuras <- data.frame(
    estructura = c("Referencia", "SAR1", "SMA1"),
    P = c(0L, 1L, 0L),
    Q = c(0L, 0L, 1L),
    modelo_nivel = c(
      "(0,1,0)(0,0,0)[12]",
      "(0,1,0)(1,0,0)[12]",
      "(0,1,0)(0,0,1)[12]"
    )
  )

  carpeta <- file.path(
    dirname(bloque01$carpeta),
    "04_primeros_candidatos"
  )

  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)

  guardar_csv <- function(objeto, nombre) bj_csv(objeto, carpeta, nombre)

  lb <- function(r, L, gl) bj_lb(r, L, gl)

  # Para estos candidatos hay como maximo un coeficiente SAR o SMA.
  # Sus doce raices tienen el mismo modulo.

  modulo_raiz <- function(cf, nombre) {
    if (!nombre %in% names(cf)) return(Inf)
    b <- abs(unname(cf[nombre]))
    if (b == 0) return(Inf)
    b^(-1 / 12)
  }

  fits <- list()
  diagnosticos <- list()
  coeficientes <- list()
  residuos <- list()
  acf_residual <- list()
  perfiles <- list()

  for (i in seq_len(nrow(estructuras))) {

    sp <- estructuras[i, ]

    for (deriva in c(FALSE, TRUE)) {

      id <- paste0(
        sp$estructura,
        if (deriva) "_con_deriva" else "_sin_deriva"
      )

      cat("\nEstimando:", id, "\n")

      avisos <- character()

      fit <- tryCatch(
        withCallingHandlers(
          stats::arima(
            y,
            order = c(0L, 0L, 0L),
            seasonal = list(
              order = c(sp$P, 0L, sp$Q),
              period = 12
            ),
            xreg = X,
            include.mean = deriva,
            method = "ML",
            optim.control = list(maxit = 1000)
          ),
          warning = function(w) {
            avisos <<- c(avisos, conditionMessage(w))
            invokeRestart("muffleWarning")
          }
        ),
        error = function(e) {
          stop(
            "Fallo en ", id, ": ", conditionMessage(e),
            call. = FALSE
          )
        }
      )

      cf <- stats::coef(fit)

      if (any(!is.finite(cf)) ||
          !is.finite(fit$sigma2) ||
          fit$sigma2 <= 0) {
        stop("El ajuste devolvio parametros invalidos: ", id)
      }

      fits[[id]] <- fit

      # k incluye coeficientes y varianza de innovaciones.
      ll <- stats::logLik(fit)
      k <- as.integer(attr(ll, "df"))

      aic <- stats::AIC(fit)
      aicc <- if (n > k + 1L) {
        aic + 2 * k * (k + 1) / (n - k - 1)
      } else {
        NA_real_
      }

      se <- sqrt(diag(fit$var.coef))
      r <- as.numeric(stats::residuals(fit))

      raiz_ar <- modulo_raiz(cf, "sar1")
      raiz_ma <- modulo_raiz(cf, "sma1")

      mu <- if ("intercept" %in% names(cf)) {
        unname(cf["intercept"])
      } else {
        0
      }

      se_mu <- if ("intercept" %in% names(cf)) {
        unname(se["intercept"])
      } else {
        NA_real_
      }

      diagnosticos[[id]] <- data.frame(
        candidato = id,
        modelo_nivel = sp$modelo_nivel,
        deriva = deriva,
        convergio = isTRUE(fit$code == 0L),
        matriz_cov_finita = all(is.finite(fit$var.coef)),
        raiz_AR = raiz_ar,
        raiz_MA = raiz_ma,
        estacionario_AR = raiz_ar > 1,
        invertible_MA = raiz_ma > 1,
        parametros_con_varianza = k,
        AICc = aicc,
        BIC = stats::BIC(fit),
        sigma_innovacion = sqrt(fit$sigma2),
        deriva_estimada = mu,
        error_estandar_deriva = se_mu,
        LB12 = lb(r, 12, sp$P + sp$Q),
        LB24 = lb(r, 24, sp$P + sp$Q),
        LB36 = lb(r, 36, sp$P + sp$Q),
        avisos = paste(unique(avisos), collapse = " | ")
      )

      coeficientes[[id]] <- data.frame(
        candidato = id,
        termino = names(cf),
        estimacion = unname(cf),
        error_estandar = unname(se),
        limite_95_inferior = unname(cf - 1.96 * se),
        limite_95_superior = unname(cf + 1.96 * se)
      )

      residuos[[id]] <- data.frame(
        candidato = id,
        fecha = fechas,
        residuo = r
      )

      ac <- as.numeric(
        stats::acf(r, lag.max = 48, plot = FALSE)$acf
      )[-1]

      acf_residual[[id]] <- data.frame(
        candidato = id,
        rezago = seq_along(ac),
        valor = ac,
        banda = 1.96 / sqrt(n)
      )

      # Recuperar los doce cambios estacionales de suma cero.
      beta <- cf[colnames(X)]
      C <- stats::contr.sum(12)
      efecto <- as.numeric(C %*% beta)

      perfiles[[id]] <- data.frame(
        candidato = id,
        mes = 1:12,
        cambio_estacional = efecto,
        deriva = mu,
        cambio_medio_total = mu + efecto
      )
    }
  }

  juntar <- bj_juntar

  diagnosticos <- juntar(diagnosticos)
  coeficientes <- juntar(coeficientes)
  residuos <- juntar(residuos)
  acf_residual <- juntar(acf_residual)
  perfiles <- juntar(perfiles)

  p1 <- ggplot2::ggplot(
    residuos,
    ggplot2::aes(fecha, residuo)
  ) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey60") +
    ggplot2::geom_line(colour = "#006D77", linewidth = 0.4) +
    ggplot2::facet_wrap(~ candidato, ncol = 2) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::labs(
      title = "Residuos de los primeros candidatos",
      x = NULL,
      y = "Residuo",
      caption = "Escala comun para comparar dispersion y episodios de mala adaptacion."
    )

  p2 <- bj_grafico_corr(acf_residual, "FAC residual de los primeros candidatos",
    nota = "Revisar patrones y Ljung-Box conjuntamente.", ylab = "FAC") +
    ggplot2::facet_wrap(~ candidato, ncol = 2)


  guardar_csv(diagnosticos, "01_diagnosticos.csv")
  guardar_csv(coeficientes, "02_coeficientes.csv")
  guardar_csv(residuos, "03_residuos.csv")
  guardar_csv(acf_residual, "04_acf_residual.csv")
  guardar_csv(perfiles, "05_perfiles_mensuales.csv")

  ggplot2::ggsave(
    file.path(carpeta, "01_residuos.png"),
    plot = p1,
    width = 12, height = 9, dpi = 180, bg = "white"
  )

  ggplot2::ggsave(
    file.path(carpeta, "02_acf_residual.png"),
    plot = p2,
    width = 12, height = 9, dpi = 180, bg = "white"
  )

  cat("\nDIAGNOSTICOS\n")
  print(diagnosticos, row.names = FALSE, digits = 5)

  cat("\nPARAMETROS DINAMICOS Y DERIVA\n")

  mostrar <- coeficientes$termino %in%
    c("sar1", "sma1", "intercept")

  print(
    coeficientes[mostrar, ],
    row.names = FALSE,
    digits = 5
  )

  cat("\nNOTAS\n")
  cat("- intercept representa la deriva porque estimamos sobre Delta x.\n")
  cat("- Los intervalos de coeficientes son aproximaciones de Wald.\n")
  cat("- Ljung-Box utiliza ajuste por parametros dinamicos; es aproximado.\n")
  cat("- Los AICc comparan la misma serie y el mismo periodo.\n")
  cat("- No se selecciono automaticamente un ganador.\n")
  cat("- Si queda estructura residual, revisaremos los candidatos.\n")
  cat("\nResultados en:\n", carpeta, "\n")

  print(p1)
  print(p2)

  invisible(list(
    modelos = fits,
    diagnosticos = diagnosticos,
    coeficientes = coeficientes,
    residuos = residuos,
    perfiles = perfiles,
    fechas = fechas,
    serie_diferenciada = y,
    regresores = X,
    d_original = 1L,
    D_original = 0L,
    carpeta = carpeta
  ))
}


# ============================================================================
# BLOQUE 04B — Revision de residuos por tramos
# Diagnostico descriptivo de dependencia y dispersion; no reestima por tramos.
# ============================================================================


ejecutar_bloque_04b <- function(bloque04) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Falta ggplot2.")
  }

  ids <- c("SAR1_sin_deriva", "SMA1_sin_deriva")

  if (!all(ids %in% names(bloque04$modelos))) {
    stop("Faltan los ajustes requeridos del bloque 4.")
  }

  fechas <- bloque04$fechas
  anio <- as.integer(format(fechas, "%Y"))

  tramo <- cut(
    anio,
    breaks = c(2001, 2009, 2017, 2025),
    labels = c("2002-2009", "2010-2017", "2018-2025"),
    right = TRUE
  )

  if (anyNA(tramo)) {
    stop("Hay fechas fuera de los tramos descriptivos previstos.")
  }

  carpeta <- file.path(
    dirname(bloque04$carpeta),
    "04b_revision_residual"
  )

  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)

  guardar_csv <- function(objeto, nombre) bj_csv(objeto, carpeta, nombre)

  correlaciones <- function(r, candidato, periodo, L) bj_correlaciones(r, list(candidato = candidato, periodo = periodo), L)

  globales <- list()
  parciales <- list()
  dispersion <- list()

  for (id in ids) {

    r <- as.numeric(
      stats::residuals(bloque04$modelos[[id]])
    )

    if (length(r) != length(fechas) ||
        any(!is.finite(r))) {
      stop("Residuos invalidos en: ", id)
    }

    globales[[id]] <- correlaciones(
      r, id, "Desarrollo completo", L = 48
    )

    for (periodo in levels(tramo)) {

      ind <- which(tramo == periodo)
      rr <- r[ind]
      clave <- paste(id, periodo, sep = "__")

      dispersion[[clave]] <- data.frame(
        candidato = id,
        periodo = periodo,
        inicio = min(fechas[ind]),
        fin = max(fechas[ind]),
        n = length(rr),
        media_residual = mean(rr),
        desviacion_estandar = stats::sd(rr)
      )

      parciales[[clave]] <- correlaciones(
        rr, id, periodo, L = 24
      )
    }
  }

  juntar <- bj_juntar

  globales <- juntar(globales)
  parciales <- juntar(parciales)
  dispersion <- juntar(dispersion)

  dibujar <- function(tabla, titulo) {
    bj_grafico_corr(tabla, titulo, cortes = NULL,
      nota = "La estimacion y la dispersion variable limitan las bandas orientativas.")
  }

  p1 <- dibujar(
    globales,
    "FAC y FACP residual: candidatos estacionales sin deriva"
  ) +
    ggplot2::facet_grid(candidato ~ tipo) +
    ggplot2::scale_x_continuous(
      breaks = c(1, 6, 12, 24, 36, 48)
    )

  # Para facilitar la lectura por tramos, mostramos el SAR.
  # El CSV conserva tambien los resultados del SMA.
  #
  # Son subconjuntos de residuos de un ajuste sobre todo desarrollo.
  # No son modelos reestimados por tramo ni una evaluacion predictiva.

  parciales_sar <- parciales[
    parciales$candidato == "SAR1_sin_deriva",
  ]

  p2 <- dibujar(
    parciales_sar,
    "SAR sin deriva: dependencia residual por tramos"
  ) +
    ggplot2::facet_grid(periodo ~ tipo) +
    ggplot2::scale_x_continuous(
      breaks = c(1, 3, 6, 9, 12, 18, 24)
    )

  guardar_csv(globales, "01_fac_facp_global.csv")
  guardar_csv(parciales, "02_fac_facp_tramos.csv")
  guardar_csv(dispersion, "03_dispersion_tramos.csv")

  ggplot2::ggsave(
    file.path(carpeta, "01_fac_facp_global.png"),
    plot = p1,
    width = 12, height = 7,
    dpi = 180, bg = "white"
  )

  ggplot2::ggsave(
    file.path(carpeta, "02_fac_facp_tramos_sar.png"),
    plot = p2,
    width = 12, height = 9,
    dpi = 180, bg = "white"
  )

  cat("\nDISPERSION Y MEDIA RESIDUAL POR TRAMOS\n")
  print(dispersion, row.names = FALSE, digits = 5)

  interes <- globales[
    globales$rezago %in% c(1:12, 18, 24, 36, 48),
    c("candidato", "tipo", "rezago", "valor", "banda")
  ]

  cat("\nCORRELACIONES RESIDUALES DE INTERES\n")
  print(interes, row.names = FALSE, digits = 5)

  cat("\nPENDIENTE\n")
  cat("- Identificar que dependencia persiste fuera del rezago anual.\n")
  cat("- Examinar si el patron es parecido entre tramos.\n")
  cat("- Fundamentar la siguiente ampliacion de la dinamica.\n")
  cat("- No se ha elegido un modelo final.\n")
  cat("\nResultados en:\n", carpeta, "\n")

  print(p1)
  print(p2)

  invisible(list(
    globales = globales,
    tramos = parciales,
    dispersion = dispersion,
    carpeta = carpeta
  ))
}


# ============================================================================
# Candidatos de 05/08: la dependencia anual sigue siendo una hipotesis abierta
# entre SAR(1) y SMA(1). Se varia la parte regular sin privilegiar una de ellas.
# Es una comparacion acotada acordada para corregir la revision insuficiente;
# no una lista de ordenes que el teorico obligue a estimar en cualquier serie.
bj_candidatos_ordenes <- function(bloque) {
  regular <- data.frame(
    regular = c("Ninguno", "AR1", "AR2", "MA1", "MA2", "ARMA11",
                "ARMA21", "ARMA12", "ARMA22"),
    p = c(0L, 1L, 2L, 0L, 0L, 1L, 2L, 1L, 2L),
    q = c(0L, 0L, 0L, 1L, 2L, 1L, 1L, 2L, 2L),
    etapa = c("Referencia", rep("Revision basica", 5), rep("Ampliacion mixta", 3)),
    fundamento_regular = c(
      "Referencia sin dependencia regular: debe contrastarse, no darse por definitiva",
      "Persistencia regular de un retardo; comprobar si explica la dependencia corta",
      "Dos retardos AR; permite oscilaciones sin exigir un pico grande en el primer retardo",
      "Un retardo MA; alternativa a explicar la dependencia corta con AR",
      "Dos retardos MA ante identificacion regular sin corte inequivoco",
      "Mezcla minima AR/MA; revisar precision y posibles factores casi comunes",
      "Extension de ARMA11 por el lado AR si las alternativas simples son insuficientes",
      "Extension de ARMA11 por el lado MA si las alternativas simples son insuficientes",
      "Extension mixta de mayor complejidad; exige mejora y parametros identificables"
    ), stringsAsFactors = FALSE
  )
  filas <- lapply(seq_len(nrow(regular)), function(i) {
    do.call(rbind, lapply(c("SAR1", "SMA1"), function(est) {
      r <- regular[i, ]
      nombre <- if (r$regular == "Ninguno") {
        if (bloque == "05") paste0(est, "_sin_deriva") else
          if (est == "SAR1") "SAR1_referencia" else "SMA1_alternativo"
      } else paste0(r$regular, "_", est, if (bloque == "05") "_sin_deriva" else "")
      data.frame(candidato = nombre, regular = r$regular, etapa = r$etapa,
        p = r$p, q = r$q, P = as.integer(est == "SAR1"), Q = as.integer(est == "SMA1"),
        modelo_nivel = sprintf("(%d,1,%d)(%d,0,%d)[12]", r$p, r$q,
          as.integer(est == "SAR1"), as.integer(est == "SMA1")),
        fundamento = paste(r$fundamento_regular, "; alternativa anual", est),
        stringsAsFactors = FALSE)
    }))
  })
  bj_juntar(filas)
}

# Varios inicios de una MISMA especificacion controlan optimos locales.
# Los parametros mensuales/efectos se reestiman conjuntamente en cada intento.
bj_estimar_candidato <- function(y, X, sp, beta_inicial, estacional_inicial) {
  xnames <- colnames(X)
  beta <- unname(beta_inicial[xnames])
  if (length(beta) != ncol(X) || any(!is.finite(beta))) stop("Inicio de regresores no valido.")
  est <- min(0.8, max(-0.8, as.numeric(estacional_inicial)))
  if (length(est) != 1L || !is.finite(est)) est <- 0.2
  basico <- c(rep(0, sp$p + sp$q), rep(est, sp$P + sp$Q), beta)
  inicios <- list(por_defecto = NULL, regular_nulo = basico)
  if (sp$p > 0L && sp$q > 0L) {
    ar <- c(0.4, rep(-0.1, sp$p - 1L))
    ma <- c(-0.3, rep(0.05, sp$q - 1L))
    inicios <- list(por_defecto = NULL,
      AR_positivo = c(ar, ma, rep(est, sp$P + sp$Q), beta),
      AR_negativo = c(-ar, -ma, rep(est, sp$P + sp$Q), beta))
  }
  intentos <- list(); ajustes <- list()
  for (etiqueta in names(inicios)) {
    avisos <- character()
    cat("\nEstimando:", sp$candidato, "| inicio:", etiqueta, "\n")
    args <- list(x = y, order = c(sp$p, 0L, sp$q),
      seasonal = list(order = c(sp$P, 0L, sp$Q), period = 12),
      xreg = X, include.mean = FALSE, method = "ML",
      optim.control = list(maxit = 2000))
    if (!is.null(inicios[[etiqueta]])) args$init <- inicios[[etiqueta]]
    f <- tryCatch(withCallingHandlers(do.call(stats::arima, args),
      warning = function(w) {
        avisos <<- c(avisos, conditionMessage(w)); invokeRestart("muffleWarning")
      }), error = function(e) list(error_ordenes = conditionMessage(e)))
    fallo <- !is.null(f$error_ordenes)
    correcto <- !fallo && isTRUE(f$code == 0L) &&
      all(is.finite(stats::coef(f))) && is.finite(f$sigma2) && f$sigma2 > 0
    ll <- if (!fallo) as.numeric(stats::logLik(f)) else NA_real_
    correcto <- correcto && is.finite(ll)
    intentos[[length(intentos) + 1L]] <- data.frame(candidato = sp$candidato,
      inicio = etiqueta, convergio = correcto, logLik = ll,
      avisos = paste(unique(avisos), collapse = " | "),
      error = if (fallo) f$error_ordenes else "", stringsAsFactors = FALSE)
    if (correcto) ajustes[[etiqueta]] <- f
  }
  if (!length(ajustes)) return(list(modelo = NULL, intentos = bj_juntar(intentos)))
  ll <- vapply(ajustes, function(f) as.numeric(stats::logLik(f)), numeric(1))
  elegido <- names(ajustes)[which.max(ll)]
  f <- ajustes[[elegido]]
  f$call[[1L]] <- quote(stats::arima)
  f$call$x <- y; f$call$xreg <- X
  list(modelo = f, inicio_elegido = elegido, intentos = bj_juntar(intentos))
}

# Resume evidencia para la decision humana. Ningun p aislado selecciona modelo.
bj_revision_ordenes <- function(diagnosticos, especificaciones) {
  d <- diagnosticos
  m <- match(d$candidato, especificaciones$candidato)
  if (anyNA(m)) stop("Diagnostico sin especificacion de ordenes.")
  s <- especificaciones[m, ]
  numerico <- d$convergio & d$matriz_cov_valida &
    d$estacionario_AR & d$invertible_MA & is.finite(d$AICc) & is.finite(d$BIC)
  lb <- as.matrix(d[, c("LB12", "LB24", "LB36")])
  completos <- apply(lb, 1L, function(z) all(is.finite(z)))
  rechazos <- rowSums(lb < 0.05, na.rm = TRUE)
  sin_rechazo <- numerico & completos & rechazos == 0L
  delta_aicc <- delta_bic <- rep(NA_real_, nrow(d))
  for (i in seq_len(nrow(d))) {
    j <- which(s$p == 0L & s$q == 0L & s$P == s$P[i] & s$Q == s$Q[i])
    if (length(j) == 1L) {
      delta_aicc[i] <- d$AICc[i] - d$AICc[j]
      delta_bic[i] <- d$BIC[i] - d$BIC[j]
    }
  }
  tabla <- data.frame(candidato = d$candidato, etapa = s$etapa,
    modelo_nivel = d$modelo_nivel, admisible_numerico = numerico,
    delta_AICc_vs_anual = delta_aicc, delta_BIC_vs_anual = delta_bic,
    horizontes_LB_con_rechazo = rechazos,
    sin_rechazo_LB_en_12_24_36 = sin_rechazo,
    requiere_revision_residual = !sin_rechazo, stringsAsFactors = FALSE)
  fallidos <- setdiff(especificaciones$candidato, d$candidato)
  estado <- data.frame(candidatos_previstos = nrow(especificaciones),
    candidatos_estimados = nrow(d), candidatos_sin_ajuste = length(fallidos),
    admisibles_numericos = sum(numerico),
    sin_rechazo_LB_orientativo = sum(sin_rechazo),
    decision_revisada = FALSE, modelo_seleccionado = NA_character_,
    estado = if (!any(sin_rechazo))
      "Ningun candidato combina admisibilidad numerica y ausencia de rechazo LB en los tres horizontes; revisar identificacion"
      else "Hay candidatos para examen conjunto de residuos, precision y parsimonia; aun no hay seleccion",
    stringsAsFactors = FALSE)
  cat("\nREVISION DE ORDENES: MEJORA FRENTE A CADA REFERENCIA ANUAL\n")
  print(tabla, row.names = FALSE, digits = 5)
  cat("\nESTADO DE LA DECISION\n"); print(estado, row.names = FALSE)
  if (length(fallidos)) cat("Sin ajuste convergente:", paste(fallidos, collapse = ", "), "\n")
  cat("Los delta negativos favorecen la ampliacion respecto a su SAR1 o SMA1 sin parte regular.\n")
  cat("Ausencia de rechazo LB no confirma ruido blanco ni sustituye FAC/FACP y precision.\n")
  cat("No reducir la decision a un coeficiente individual, al menor AICc o a un valor p.\n")
  list(comparacion = tabla, estado = estado, fallidos = fallidos)
}


# BLOQUE 05 — Ampliacion regular ANTES de outliers
# Se conserva: sus resultados no son redundantes con la revision posterior del 08.
# ============================================================================


# ============================================================================
# DECISION DEL 05 Y OPERADORES GENERALES PARA EL MODELO ELEGIDO
# Se conserva el detector clasico del capitulo/taller 04B: firmas, maximo,
# reestimacion conjunta y nueva busqueda. El filtro ya no presupone SAR puro.
# ============================================================================
bj_dinamicos <- function(fit) {
  cf <- stats::coef(fit)
  cf[grep("^(ar|ma|sar|sma)[0-9]+$", names(cf))]
}

bj_especificacion_fit <- function(fit, candidato = "Base_05") {
  a <- as.integer(fit$arma)
  if (length(a) != 7L || a[5L] != 12L || any(a[6:7] != 0L)) {
    stop("Se requiere ARMA mensual sobre Delta log, con d=1/D=0 originales.")
  }
  data.frame(candidato = candidato, p = a[1L], q = a[2L], P = a[3L], Q = a[4L],
    modelo_nivel = sprintf("(%d,1,%d)(%d,0,%d)[12]", a[1L], a[2L], a[3L], a[4L]),
    stringsAsFactors = FALSE)
}

bj_validar_arma <- function(fit, X = NULL) {
  cf <- stats::coef(fit); V <- fit$var.coef
  if (!isTRUE(fit$code == 0L) || any(!is.finite(cf)) ||
      !is.finite(fit$sigma2) || fit$sigma2 <= 0 ||
      !is.matrix(V) || nrow(V) != length(cf) || any(!is.finite(V)) || any(diag(V) <= 0)) {
    stop("Ajuste sin convergencia, precision o varianza validas.")
  }
  tryCatch(chol(V), error = function(e) stop("Covarianzas no definidas positivas."))
  for (tipo in c("ar", "ma")) {
    z <- bj_raices_coef(cf, tipo)
    if (length(z) && min(Mod(z)) <= 1 + 1e-8) stop("Raices fuera de admisibilidad: ", tipo)
  }
  if (!is.null(X) && (!all(colnames(X) %in% names(cf)) ||
      !setequal(names(cf), c(names(bj_dinamicos(fit)), colnames(X))))) {
    stop("El ajuste y sus regresores no corresponden al mismo modelo sin deriva.")
  }
  invisible(TRUE)
}

bj_firma_05 <- function(bloque05) {
  if (is.null(bloque05$modelo_seleccionado) || is.null(bloque05$modelo_base)) {
    stop("El bloque 05 no tiene una decision registrada. No usar la referencia del 04.")
  }
  paste(bloque05$modelo_seleccionado,
    paste(as.integer(bloque05$modelo_base$arma), collapse = ","),
    paste(sprintf("%.17g", stats::coef(bloque05$modelo_base)), collapse = ","), sep = "|")
}

bj_registrar_decision_05 <- function(z, candidato = "ARMA21_SAR1_sin_deriva") {
  f <- z$modelos[[candidato]]
  if (is.null(f)) stop("No se obtuvo el modelo elegido en 05: ", candidato)
  bj_validar_arma(f, z$regresores)
  sp <- z$especificaciones[z$especificaciones$candidato == candidato, , drop = FALSE]
  d <- z$diagnosticos[z$diagnosticos$candidato == candidato, , drop = FALSE]
  if (nrow(sp) != 1L || nrow(d) != 1L) stop("Decision 05 no identificada.")
  z$modelo_seleccionado <- candidato; z$modelo_base <- f
  z$especificacion_seleccionada <- sp
  z$decision <- data.frame(candidato = candidato, modelo_nivel = sp$modelo_nivel,
    estado = "Base provisional para 06/07; ordenes sujetos a revision en 08",
    fundamento = paste(
      "ARMA21+SAR1 mejora AICc aproximadamente 10 puntos frente a SAR1 y reduce autocorrelacion;",
      "BIC practicamente empatado, coeficientes identificables y raices fuera del circulo unitario.",
      "Alternativas ARMA21+SMA1 y ARMA12 permanecen en 08.",
      "No elegir ARMA22+SMA1 solo por IC: factores AR/MA casi comunes y proximos al circulo unitario.",
      "Su mejor intento convergio sin aviso; el aviso NaN pertenecia a otro inicio."
    ), LB12 = d$LB12, LB24 = d$LB24, LB36 = d$LB36,
    validacion_residual_plena = FALSE, stringsAsFactors = FALSE)
  z$firma05 <- bj_firma_05(z)
  z$estado_decision$decision_revisada <- TRUE
  z$estado_decision$modelo_seleccionado <- candidato
  z$estado_decision$estado <- "Base provisional elegida; dependencia residual pendiente de revisar con efectos y ordenes"
  bj_csv(z$decision, z$carpeta, "11_decision_modelo.csv")
  bj_csv(z$estado_decision, z$carpeta, "08_estado_decision.csv")
  saveRDS(z, file.path(z$carpeta, "09_objeto_bloque05.rds"))
  cat("\nDECISION DEL BLOQUE 05: BASE PROVISIONAL PARA CONTINUAR\n")
  print(z$decision, row.names = FALSE)
  z
}

bj_contexto_05 <- function(bloque05) {
  bj_validar_arma(bloque05$modelo_base, bloque05$regresores)
  firma <- bj_firma_05(bloque05)
  if (!identical(firma, bloque05$firma05)) stop("El modelo del 05 cambio despues de registrar la decision.")
  list(decision = bloque05$decision, firma05 = firma,
    especificacion = bloque05$especificacion_seleccionada,
    modelo_id = bloque05$modelo_seleccionado)
}

# Filtro de innovaciones con parametros fijos: mismo operador ya comprobado
# en 08. stats::arima conserva su inicializacion estacionaria. No se aproxima
# el filtro infinito ni se descartan observaciones iniciales.
bj_filtrar_fijo <- function(z, fit, inicio = c(2002, 2)) {
  sp <- bj_especificacion_fit(fit)
  f <- stats::arima(stats::ts(as.numeric(z), start = inicio, frequency = 12),
    order = c(sp$p, 0L, sp$q),
    seasonal = list(order = c(sp$P, 0L, sp$Q), period = 12),
    include.mean = FALSE, fixed = unname(bj_dinamicos(fit)),
    transform.pars = FALSE, method = "ML")
  as.numeric(stats::residuals(f))
}

bj_pol_arma <- function(fit) {
  cf <- stats::coef(fit)
  ar <- unname(cf[grep("^ar[0-9]+$", names(cf))])
  ma <- unname(cf[grep("^ma[0-9]+$", names(cf))])
  est <- function(prefijo, signo) {
    z <- unname(cf[grep(paste0("^", prefijo, "[0-9]+$"), names(cf))])
    p <- c(1, rep(0, 12L * length(z)))
    if (length(z)) p[1L + 12L * seq_along(z)] <- signo * z
    p
  }
  list(AR = bj_multiplicar(c(1, -ar), est("sar", -1)),
       MA = bj_multiplicar(c(1, ma), est("sma", 1)))
}

bj_perfil_arma <- function(n, index, tipo, fit, delta = 0.7) {
  h <- 0:(n - index)
  valores <- switch(tipo, AO = as.numeric(h == 0L), LS = rep(1, length(h)), TC = delta^h,
    IO = {
      pol <- bj_pol_arma(fit)
      respuesta <- if (length(h) == 1L) 1 else
        c(1, stats::ARMAtoMA(ar = -pol$AR[-1L], ma = pol$MA[-1L], lag.max = length(h) - 1L))
      cumsum(respuesta) # Psi de Delta log y acumulacion por el d=1 original.
    }, stop("Tipo de outlier desconocido."))
  g <- numeric(n); g[index:n] <- valores; g
}

bj_eventos_vacios <- function() {
  data.frame(orden = integer(), index = integer(), fecha = as.Date(character()), tipo = character(),
    termino = character(), lambda_incorporacion = numeric(), omega_scan = numeric(), stringsAsFactors = FALSE)
}

bj_diseno_efectos <- function(fechas, Xmes, eventos, fit, delta) {
  n <- length(fechas)
  G <- matrix(numeric(), nrow = n, ncol = 0L)
  if (nrow(eventos)) {
    G <- vapply(seq_len(nrow(eventos)), function(j)
      bj_perfil_arma(n, eventos$index[j], eventos$tipo[j], fit, delta), numeric(n))
    colnames(G) <- eventos$termino
  }
  X <- cbind(Xmes, G[-1L, , drop = FALSE] - G[-n, , drop = FALSE])
  if (qr(X)$rank < ncol(X)) stop("Meses y efectos colineales.")
  list(X = X, G = G)
}

bj_scan_arma <- function(fit, fechas, dy, X, C, delta, excluir = integer()) {
  bj_validar_arma(fit, X)
  n <- length(fechas); m <- length(dy); cf <- stats::coef(fit)
  e <- as.numeric(stats::residuals(fit)); sigma <- sqrt(fit$sigma2)
  if (m != n - 1L || nrow(X) != m || any(!is.finite(e))) stop("Serie o innovaciones no validas.")
  u <- as.numeric(dy) - as.numeric(X %*% cf[colnames(X)])
  # Matriz del mismo filtro lineal, obtenida aplicandolo a impulsos unitarios.
  # Permite filtrar las 4*(n-1) firmas en una sola multiplicacion matricial.
  W <- vapply(seq_len(m), function(j) {
    z <- numeric(m); z[j] <- 1; bj_filtrar_fijo(z, fit, stats::start(dy))
  }, numeric(m))
  error <- max(abs(as.numeric(W %*% u) - e))
  if (!is.finite(error) || error > 1e-6) stop("El filtro general no reproduce las innovaciones del modelo.")
  meta <- expand.grid(index = 2:n, tipo = c("AO", "IO", "LS", "TC"), stringsAsFactors = FALSE)
  G <- vapply(seq_len(nrow(meta)), function(j)
    bj_perfil_arma(n, meta$index[j], meta$tipo[j], fit, delta), numeric(n))
  Z <- W %*% (G[-1L, , drop = FALSE] - G[-n, , drop = FALSE])
  den <- colSums(Z^2)
  if (any(!is.finite(den)) || any(den <= 1e-12)) stop("Firma no identificable en el detector.")
  omega <- as.numeric(crossprod(e, Z)) / den
  se <- sigma / sqrt(den); lambda <- omega / se
  ans <- data.frame(index = meta$index, fecha = fechas[meta$index], tipo = meta$tipo,
    omega_log = omega, se_condicional = se, lambda = lambda, abs_lambda = abs(lambda),
    supera_C = abs(lambda) >= C, fecha_ya_modelada = meta$index %in% excluir,
    cerca_del_inicio = meta$index <= 13L, cerca_del_final = n - meta$index < 13L,
    stringsAsFactors = FALSE)
  ans <- ans[order(-ans$abs_lambda, ans$index, ans$tipo), ]
  attr(ans, "discrepancia_filtro") <- error
  ans
}

bj_reestimar_eventos <- function(dy, fechas, Xmes, eventos, fit_inicial, sp, delta) {
  actual <- fit_inicial; historia <- list()
  for (it in 1:5) {
    diseno <- bj_diseno_efectos(fechas, Xmes, eventos, actual, delta)
    beta <- stats::setNames(rep(0, ncol(diseno$X)), colnames(diseno$X))
    cf <- stats::coef(actual); comunes <- intersect(names(beta), names(cf)); beta[comunes] <- cf[comunes]
    nuevos <- setdiff(eventos$termino, names(cf))
    if (length(nuevos)) beta[nuevos] <- eventos$omega_scan[match(nuevos, eventos$termino)]
    anual <- cf[intersect(c("sar1", "sma1"), names(cf))]
    nuevo <- bj_estimar_candidato(dy, diseno$X, sp, beta,
      if (length(anual)) unname(anual[1L]) else 0.2)
    historia[[it]] <- nuevo$intentos
    if (is.null(nuevo$modelo)) stop("Ningun inicio convergio al reestimar efectos.")
    f <- nuevo$modelo; bj_validar_arma(f, diseno$X)
    # IO depende de toda la dinamica. Se contrasta su perfil generado, no solo sar1.
    siguiente <- bj_diseno_efectos(fechas, Xmes, eventos, f, delta)
    error_perfil <- if (nrow(eventos)) max(abs(siguiente$G - diseno$G)) else 0
    if (!any(eventos$tipo == "IO") || error_perfil < 1e-6) {
      f$xreg <- diseno$X
      return(list(modelo = f, X = diseno$X, G = diseno$G,
        error_perfil_IO = error_perfil, intentos = bj_juntar(historia)))
    }
    actual <- f
  }
  stop("El perfil IO no convergio en las cinco actualizaciones del procedimiento.")
}

bj_diag_arma <- function(fit, etiqueta) {
  sp <- bj_especificacion_fit(fit); e <- as.numeric(stats::residuals(fit))
  cf <- stats::coef(fit); k <- length(cf) + 1L; n <- length(e)
  ll <- as.numeric(stats::logLik(fit)); gl <- sp$p + sp$q + sp$P + sp$Q
  minimo <- function(z) if (length(z)) min(Mod(z)) else Inf
  data.frame(modelo = etiqueta, modelo_nivel = sp$modelo_nivel,
    AICc = -2 * ll + 2 * k + 2 * k * (k + 1) / (n - k - 1), BIC = -2 * ll + log(n) * k,
    sigma_innovacion = sqrt(mean(e^2)), fitdf_LB = gl,
    raiz_AR_minima = minimo(bj_raices_coef(cf, "ar")), raiz_MA_minima = minimo(bj_raices_coef(cf, "ma")),
    LB12 = bj_lb(e, 12, gl), LB24 = bj_lb(e, 24, gl), LB36 = bj_lb(e, 36, gl),
    stringsAsFactors = FALSE)
}


ejecutar_bloque_05 <- function(bloque04) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Falta ggplot2.")
  }

  y <- bloque04$serie_diferenciada
  X <- bloque04$regresores
  fechas <- bloque04$fechas
  n <- length(y)

  if (nrow(X) != n || length(fechas) != n ||
      any(!is.finite(y)) || any(!is.finite(X))) {
    stop("Datos o regresores invalidos.")
  }

  carpeta <- file.path(
    dirname(bloque04$carpeta),
    "05_ampliacion_regular"
  )

  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)

  guardar_csv <- function(objeto, nombre) bj_csv(objeto, carpeta, nombre)

  # Recuperar las referencias sin reestimarlas.

  ids_base <- c("SAR1_sin_deriva", "SMA1_sin_deriva")

  if (!all(ids_base %in% names(bloque04$modelos))) {
    stop("Faltan las referencias del bloque 4.")
  }

  fits <- bloque04$modelos[ids_base]

  especificaciones <- bj_candidatos_ordenes("05")
  guardar_csv(especificaciones, "00_especificaciones.csv")
  cat("\nBLOQUE 05 — REVISION AMPLIADA DE ORDENES REGULARES\n")
  cat("Dos referencias anuales, diez ampliaciones basicas y seis mixtas de segundo nivel.\n")
  cat("Mismos datos, meses, d=1/D=0 y ausencia de deriva; antes de outliers.\n")
  print(especificaciones[, c("candidato", "etapa", "modelo_nivel")], row.names = FALSE)
  avisos <- setNames(rep("", nrow(especificaciones)), especificaciones$candidato)
  intentos <- lapply(ids_base, function(id) data.frame(candidato = id,
    inicio = "Reutilizado_04", convergio = isTRUE(fits[[id]]$code == 0L),
    logLik = as.numeric(stats::logLik(fits[[id]])), avisos = "", error = ""))
  for (i in which(!especificaciones$candidato %in% ids_base)) {
    sp <- especificaciones[i, ]
    base <- fits[[if (sp$P == 1L) ids_base[1L] else ids_base[2L]]]
    anual <- if (sp$P == 1L) "sar1" else "sma1"
    nuevo <- bj_estimar_candidato(y, X, sp, stats::coef(base), stats::coef(base)[anual])
    intentos[[length(intentos) + 1L]] <- nuevo$intentos
    if (!is.null(nuevo$modelo)) fits[[sp$candidato]] <- nuevo$modelo
    avisos[sp$candidato] <- paste(unique(nuevo$intentos$avisos[nzchar(nuevo$intentos$avisos)]), collapse = " | ")
  }
  intentos <- bj_juntar(intentos)

  # 2. Raices de los polinomios AR y MA multiplicativos -------------------------
  #
  # Se excluye la diferencia regular ya aplicada.
  # Convencion de R: AR con signo negativo, MA con signo positivo.

  multiplicar <- bj_multiplicar

  obtener_raices <- function(cf, tipo) bj_raices_coef(cf, tipo)

  minimo <- function(z) {
    if (length(z)) min(z) else Inf
  }

  lb <- function(r, L, gl) bj_lb(r, L, gl)

  diagnosticos <- list()
  coeficientes <- list()
  raices <- list()
  residuos <- list()
  correlaciones <- list()

  # 3. Diagnosticar todos los candidatos convergentes -----------------------------------------

  for (i in seq_len(nrow(especificaciones))) {

    sp <- especificaciones[i, ]
    id <- sp$candidato
    fit <- fits[[id]]
    if (is.null(fit)) next
    cf <- stats::coef(fit)
    V <- fit$var.coef
    Vok <- is.matrix(V) && nrow(V) == length(cf) && ncol(V) == length(cf) &&
      all(is.finite(V)) && all(diag(V) > 0)
    if (Vok) Vok <- tryCatch({ chol(V); TRUE }, error = function(e) FALSE)
    se <- if (Vok) sqrt(diag(V)) else stats::setNames(rep(NA_real_, length(cf)), names(cf))

    if (any(!is.finite(cf)) ||
        !is.finite(fit$sigma2) || fit$sigma2 <= 0) {
      stop("Parametros invalidos en: ", id)
    }

    ar <- obtener_raices(cf, "ar")
    ma <- obtener_raices(cf, "ma")

    distancia <- if (length(ar) && length(ma)) {
      min(Mod(outer(ar, ma, "-")))
    } else {
      NA_real_
    }

    r <- as.numeric(stats::residuals(fit))
    k <- as.integer(attr(stats::logLik(fit), "df"))
    gl <- sp$p + sp$q + sp$P + sp$Q

    aicc <- stats::AIC(fit) +
      2 * k * (k + 1) / (n - k - 1)

    diagnosticos[[id]] <- data.frame(
      candidato = id,
      modelo_nivel = sp$modelo_nivel,
      convergio = isTRUE(fit$code == 0L),
      matriz_cov_finita = all(is.finite(fit$var.coef)),
      matriz_cov_valida = Vok,
      estacionario_AR = minimo(Mod(ar)) > 1 + 1e-8,
      invertible_MA = minimo(Mod(ma)) > 1 + 1e-8,
      parametros_con_varianza = k,
      fitdf_LB = gl,
      logLik = as.numeric(stats::logLik(fit)),
      raiz_AR_minima = minimo(Mod(ar)),
      raiz_MA_minima = minimo(Mod(ma)),
      distancia_AR_MA = distancia,
      distancia_MA_a_mas_uno = if (length(ma)) {
        min(Mod(ma - 1))
      } else {
        NA_real_
      },
      AICc = aicc,
      BIC = stats::BIC(fit),
      sigma_innovacion = sqrt(mean(r^2)),
      LB12 = lb(r, 12, gl),
      LB24 = lb(r, 24, gl),
      LB36 = lb(r, 36, gl),
      avisos = unname(avisos[id])
    )

    coeficientes[[id]] <- data.frame(
      candidato = id,
      termino = names(cf),
      estimacion = unname(cf),
      error_estandar = unname(se),
      limite_95_inferior = unname(cf - 1.96 * se),
      limite_95_superior = unname(cf + 1.96 * se)
    )

    for (tipo in c("AR", "MA")) {

      zz <- if (tipo == "AR") ar else ma

      if (length(zz)) {
        raices[[paste(id, tipo, sep = "__")]] <- data.frame(
          candidato = id,
          tipo = tipo,
          real = Re(zz),
          imaginaria = Im(zz),
          modulo = Mod(zz),
          angulo = Arg(zz)
        )
      }
    }

    residuos[[id]] <- data.frame(
      candidato = id,
      fecha = fechas,
      residuo = r
    )

    ac <- as.numeric(
      stats::acf(r, lag.max = 48, plot = FALSE)$acf
    )[-1]

    pa <- as.numeric(
      stats::pacf(r, lag.max = 48, plot = FALSE)$acf
    )

    correlaciones[[id]] <- rbind(
      data.frame(
        candidato = id,
        tipo = "FAC",
        rezago = seq_along(ac),
        valor = ac,
        banda = 1.96 / sqrt(n)
      ),
      data.frame(
        candidato = id,
        tipo = "FACP",
        rezago = seq_along(pa),
        valor = pa,
        banda = 1.96 / sqrt(n)
      )
    )
  }

  juntar <- bj_juntar

  diagnosticos <- juntar(diagnosticos)
  coeficientes <- juntar(coeficientes)
  raices <- juntar(raices)
  residuos <- juntar(residuos)
  correlaciones <- juntar(correlaciones)
  revision <- bj_revision_ordenes(diagnosticos, especificaciones)

  # 4. Graficos ---------------------------------------------------------------

  p1 <- bj_grafico_corr(correlaciones,
    "Ampliacion regular: FAC y FACP residual",
    nota = "Revisar patrones, raices y parametros conjuntamente.") +
    ggplot2::facet_grid(candidato ~ tipo)


  p2 <- ggplot2::ggplot(
    residuos,
    ggplot2::aes(fecha, residuo)
  ) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey60") +
    ggplot2::geom_line(colour = "#006D77", linewidth = 0.4) +
    ggplot2::facet_wrap(~ candidato, ncol = 2) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::labs(
      title = "Residuos de referencias y nuevos candidatos",
      x = NULL,
      y = "Residuo"
    )

  guardar_csv(diagnosticos, "01_diagnosticos.csv")
  guardar_csv(coeficientes, "02_coeficientes.csv")
  guardar_csv(raices, "03_raices.csv")
  guardar_csv(correlaciones, "04_fac_facp_residual.csv")
  guardar_csv(residuos, "05_residuos.csv")
  guardar_csv(intentos, "06_intentos_estimacion.csv")
  guardar_csv(revision$comparacion, "07_revision_ordenes.csv")
  guardar_csv(revision$estado, "08_estado_decision.csv")
  writeLines(c(
    "Revision correctiva: el analisis anterior de dos ampliaciones no cubria suficientemente AR/MA regular.",
    "Se conservan referencias SAR1/SMA1 y se contrastan AR1, AR2, MA1, MA2 y ARMA11 con ambas.",
    "ARMA21, ARMA12 y ARMA22 son ampliaciones mixtas adicionales: su complejidad debe justificarse.",
    "El teorico orienta identificacion, estimacion y validacion; no exige esta lista en cualquier serie.",
    "Los mismos criterios se aplican a todas las alternativas. No hay ganador automatico.",
    "La ausencia de un corte claro o de un primer retardo grande no demuestra p=q=0.",
    "Ljung-Box orienta la revision; sus valores p no son confirmatorios tras comparar especificaciones.",
    "Sigma_innovacion se presenta como raiz del promedio de innovaciones al cuadrado, sin correccion de grados de libertad.",
    "FAC/FACP, precision, raices, cancelaciones y dispersion deben revisarse junto a AICc/BIC.",
    "No se selecciona un modelo ni se cambia automaticamente la base de los bloques posteriores.",
    "Al final se registra la decision provisional del 05 antes de ejecutar los siguientes bloques."
  ), file.path(carpeta, "10_alcance.txt"))

  ggplot2::ggsave(
    file.path(carpeta, "01_fac_facp_residual.png"),
    plot = p1,
    width = 12, height = max(12, 1.5 * nrow(diagnosticos)),
    dpi = 180, bg = "white"
  )

  ggplot2::ggsave(
    file.path(carpeta, "02_residuos.png"),
    plot = p2,
    width = 12, height = max(7, 1.8 * ceiling(nrow(diagnosticos) / 2)),
    dpi = 180, bg = "white"
  )

  cat("\nDIAGNOSTICOS\n")
  print(diagnosticos, row.names = FALSE, digits = 5)

  dinamicos <- grepl(
    "^(ar|ma|sar|sma)[0-9]+$",
    coeficientes$termino
  )

  cat("\nCOEFICIENTES DINAMICOS\n")
  print(
    coeficientes[dinamicos, ],
    row.names = FALSE,
    digits = 5
  )

  cat("\nLECTURA PENDIENTE\n")
  cat("- Verificar convergencia, estacionariedad e invertibilidad.\n")
  cat("- Examinar si la ampliacion reduce la dependencia residual.\n")
  cat("- Revisar parametros poco precisos y cancelaciones AR/MA.\n")
  cat("- Una raiz MA proxima a +1 requiere revisar la diferenciacion.\n")
  cat("- No cerrar el modelo solamente por AICc o Ljung-Box.\n")
  cat("- La variacion de dispersion sigue pendiente de explicacion.\n")
  cat("\nResultados en:\n", carpeta, "\n")

  print(p1)
  print(p2)

  salida <- list(
    modelos = fits,
    especificaciones = especificaciones,
    diagnosticos = diagnosticos,
    coeficientes = coeficientes,
    raices = raices,
    residuos = residuos,
    correlaciones = correlaciones,
    intentos = intentos, revision_ordenes = revision$comparacion,
    estado_decision = revision$estado, modelo_seleccionado = NULL,
    serie_diferenciada = y, regresores = as.matrix(X), fechas = fechas,
    carpeta = carpeta
  )
  salida <- bj_registrar_decision_05(salida)
  invisible(salida)
}


# ============================================================================
# BLOQUE 06 — Cambio estructural: parte descriptiva
# Perfiles de nivel, pendiente y ambos. Inferencia y limites en 06B/06C.
# ============================================================================


ejecutar_bloque_06_trayectoria <- function(bloque01, trim = 0.15) {

  # ------------------------------------------------------------------------
  # 1. Datos
  # ------------------------------------------------------------------------

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Se necesita ggplot2.")
  }

  datos <- bloque01$datos

  if (!all(c("fecha", "log_diaria") %in% names(datos))) {
    stop("bloque01$datos debe contener fecha y log_diaria.")
  }

  fechas <- as.Date(datos$fecha)
  y <- as.numeric(datos$log_diaria)
  n <- length(y)

  if (
    n < 60L ||
    anyNA(fechas) ||
    any(!is.finite(y)) ||
    anyDuplicated(fechas)
  ) {
    stop("Revisar muestra, fechas o valores.")
  }

  calendario <- seq(
    from = fechas[1L],
    by = "month",
    length.out = n
  )

  if (!identical(as.character(fechas), as.character(calendario))) {
    stop("La serie debe estar ordenada y sin huecos mensuales.")
  }

  if (max(fechas) > as.Date("2025-09-01")) {
    stop("Hay observaciones posteriores al corte de desarrollo.")
  }

  if (
    length(trim) != 1L ||
    !is.finite(trim) ||
    trim <= 0 ||
    trim >= 0.5
  ) {
    stop("trim debe estar entre 0 y 0.5.")
  }

  # Parte descriptiva; las partes 06B y 06C tienen sus propias salidas.
  carpeta <- file.path(
    dirname(bloque01$carpeta),
    "06_cambio_estructural_final"
  )

  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)

  guardar <- function(objeto, archivo) {
    utils::write.csv(
      objeto,
      file.path(carpeta, archivo),
      row.names = FALSE,
      fileEncoding = "UTF-8"
    )
  }

  t <- seq_len(n)

  mes <- factor(
    as.integer(format(fechas, "%m")),
    levels = 1:12
  )

  M <- stats::model.matrix(
    ~ mes,
    contrasts.arg = list(mes = stats::contr.sum(12))
  )[, -1L, drop = FALSE]

  X0 <- cbind(
    constante = 1,
    tendencia = t,
    M
  )

  ajustar <- function(X) {

    fit <- stats::lm.fit(X, y)

    if (
      fit$rank != ncol(X) ||
      any(!is.finite(fit$coefficients))
    ) {
      stop("Problema de rango o estimacion.")
    }

    names(fit$coefficients) <- colnames(X)
    fit
  }

  referencia <- ajustar(X0)
  SSR0 <- sum(referencia$residuals^2)

  candidatos <- seq.int(
    max(3L, ceiling(trim * n)),
    min(n - 3L, floor((1 - trim) * n))
  )

  modelos <- c("A_nivel", "B_pendiente", "C_ambos")

  # Definiciones del taller:
  # TB es la ultima observacion anterior al cambio.
  # DU = 1(t > TB).
  # DT = max(t - TB, 0).
  crear_cambio <- function(modelo, TB) {

    DU <- as.numeric(t > TB)
    DT <- pmax(t - TB, 0)

    switch(
      modelo,
      A_nivel = cbind(DU = DU),
      B_pendiente = cbind(DT = DT),
      C_ambos = cbind(DU = DU, DT = DT)
    )
  }

  # ------------------------------------------------------------------------
  # 2. Perfiles SSR y ajustes en las fechas de minimo SSR
  # ------------------------------------------------------------------------

  perfiles <- list()
  resumen <- list()
  ajustes <- list()
  estimaciones <- list()
  mejores <- list()

  for (modelo in modelos) {

    SSR <- vapply(
      candidatos,
      function(TB) {

        U <- crear_cambio(modelo, TB)
        fit <- ajustar(cbind(X0, U))

        sum(fit$residuals^2)
      },
      numeric(1)
    )

    j <- which.min(SSR)
    TB <- candidatos[j]

    U <- crear_cambio(modelo, TB)
    X <- cbind(X0, U)

    fit <- ajustar(X)
    b <- fit$coefficients

    cambio_nivel <- if ("DU" %in% names(b)) {
      unname(b["DU"])
    } else {
      0
    }

    cambio_pendiente <- if ("DT" %in% names(b)) {
      unname(b["DT"])
    } else {
      0
    }

    pendiente_previa <- unname(b["tendencia"])
    pendiente_posterior <- pendiente_previa + cambio_pendiente

    perfiles[[modelo]] <- data.frame(
      modelo = modelo,
      TB_index = candidatos,
      ultima_fecha_previa = fechas[candidatos],
      primera_fecha_posterior = fechas[candidatos + 1L],
      SSR = SSR,
      SSR_relativo_referencia = SSR / SSR0
    )

    resumen[[modelo]] <- data.frame(
      modelo = modelo,
      ultima_fecha_previa = fechas[TB],
      primera_fecha_posterior = fechas[TB + 1L],
      SSR_referencia = SSR0,
      SSR_candidato = SSR[j],
      reduccion_SSR_pct = 100 * (1 - SSR[j] / SSR0),
      desplazamiento_intercepto_log = cambio_nivel,
      pendiente_previa_log_mensual = pendiente_previa,
      pendiente_posterior_log_mensual = pendiente_posterior,
      cambio_pendiente_log_mensual = cambio_pendiente,
      interpretacion = "Descriptiva; no confirma un quiebre"
    )

    ajustes[[modelo]] <- data.frame(
      modelo = modelo,
      fecha = fechas,
      observado = y,
      ajustado = as.numeric(X %*% b)
    )

    estimaciones[[modelo]] <- data.frame(
      modelo = modelo,
      termino = names(b),
      estimacion = as.numeric(b)
    )

    mejores[[modelo]] <- list(
      TB_index = TB,
      fit = fit
    )
  }

  perfiles <- do.call(rbind, perfiles)
  resumen <- do.call(rbind, resumen)
  ajustes <- do.call(rbind, ajustes)
  estimaciones <- do.call(rbind, estimaciones)

  rownames(perfiles) <- NULL
  rownames(resumen) <- NULL
  rownames(ajustes) <- NULL
  rownames(estimaciones) <- NULL

  ajuste_referencia <- data.frame(
    modelo = "Referencia_sin_quiebre",
    fecha = fechas,
    observado = y,
    ajustado = as.numeric(X0 %*% referencia$coefficients)
  )

  ajustes <- rbind(ajuste_referencia, ajustes)

  # ------------------------------------------------------------------------
  # 3. Registro del cierre
  #
  # No se compara el menor SSR entre modelos para declarar un ganador:
  # agregar parametros puede mejorar mecanicamente el ajuste.
  # ------------------------------------------------------------------------

  cierre <- data.frame(
    inicio = min(fechas),
    fin = max(fechas),
    observaciones = n,
    trim = trim,
    procedimiento = "Perfiles SSR de los modelos A, B y C",
    alcance = "Exploratorio y descriptivo",
    conclusion_estadistica = "No concluyente sobre existencia de quiebre",
    quiebre_incorporado = FALSE,
    decision_operativa = paste(
      "Continuar con la referencia sin quiebre;",
      "no interpretar esta decision como prueba de estabilidad"
    ),
    bootstrap_anterior = "No utilizado",
    p_supF = NA_real_,
    motivo_sin_p = paste(
      "No aplicar inferencia convencional sobre",
      "la regresion en niveles con ruido integrado"
    ),
    d_D = "Se conservan las decisiones de trabajo anteriores"
  )

  guardar(perfiles, "01_perfiles_SSR.csv")
  guardar(resumen, "02_fechas_y_cambios_descriptivos.csv")
  guardar(ajustes, "03_ajustes.csv")
  guardar(estimaciones, "04_coeficientes_descriptivos.csv")
  guardar(cierre, "05_cierre_bloque.csv")

  # ------------------------------------------------------------------------
  # 4. Graficos
  # ------------------------------------------------------------------------

  g1 <- ggplot2::ggplot(
    perfiles,
    ggplot2::aes(
      x = primera_fecha_posterior,
      y = SSR_relativo_referencia
    )
  ) +
    ggplot2::geom_line(
      colour = "#00747A",
      linewidth = 0.6
    ) +
    ggplot2::geom_vline(
      data = resumen,
      ggplot2::aes(
        xintercept = primera_fecha_posterior
      ),
      colour = "#C45100",
      linetype = "dashed"
    ) +
    ggplot2::facet_wrap(~ modelo, ncol = 1) +
    ggplot2::labs(
      title = "Cambio estructural: perfiles SSR",
      subtitle = "Efectos mensuales constantes; fecha desconocida",
      x = "Primera observacion posterior al cambio candidato",
      y = "SSR / SSR de referencia",
      caption = paste(
        "Las lineas verticales indican minimos descriptivos.",
        "No constituyen confirmacion estadistica de un quiebre."
      )
    ) +
    ggplot2::theme_minimal(base_size = 12)

  g2 <- ggplot2::ggplot(
    ajustes,
    ggplot2::aes(x = fecha)
  ) +
    ggplot2::geom_line(
      ggplot2::aes(y = observado),
      colour = "grey55",
      linewidth = 0.4
    ) +
    ggplot2::geom_line(
      ggplot2::aes(y = ajustado),
      colour = "#00747A",
      linewidth = 0.6
    ) +
    ggplot2::facet_wrap(~ modelo, ncol = 1) +
    ggplot2::labs(
      title = "Trayectoria estable y ajustes con cambio candidato",
      subtitle = "Logaritmo de la remision media diaria",
      x = NULL,
      y = "Logaritmo",
      caption = paste(
        "Gris: observado. Verde: ajuste con efectos mensuales.",
        "Ajustes descriptivos; no son modelos finales de forecasting."
      )
    ) +
    ggplot2::theme_minimal(base_size = 12)

  ggplot2::ggsave(
    file.path(carpeta, "01_perfiles_SSR.png"),
    g1,
    width = 11,
    height = 9,
    dpi = 150
  )

  ggplot2::ggsave(
    file.path(carpeta, "02_ajustes_descriptivos.png"),
    g2,
    width = 11,
    height = 11,
    dpi = 150
  )

  utils::capture.output(
    utils::sessionInfo(),
    file = file.path(carpeta, "06_sessionInfo.txt")
  )

  # ------------------------------------------------------------------------
  # 5. Consola y objeto
  # ------------------------------------------------------------------------

  cat("\nBLOQUE 06 — REVISION DE CAMBIO ESTRUCTURAL\n")
  cat("Periodo:", format(min(fechas)), "a", format(max(fechas)), "\n")
  cat("Observaciones:", n, "\n\n")

  print(
    resumen[
      ,
      c(
        "modelo",
        "primera_fecha_posterior",
        "reduccion_SSR_pct",
        "desplazamiento_intercepto_log",
        "cambio_pendiente_log_mensual"
      )
    ],
    row.names = FALSE,
    digits = 6
  )

  cat(
    "\nCIERRE\n",
    "- Las fechas y magnitudes son descriptivas.\n",
    "- No se declara un quiebre por minimizar SSR.\n",
    "- No se reutiliza el valor p del bootstrap anterior.\n",
    "- No hay una conclusion estadistica de ausencia de cambio.\n",
    "- Decision operativa: continuar sin incorporar un quiebre confirmado.\n",
    "- Se conservan d y D como decisiones de trabajo anteriores.\n",
    sep = ""
  )

  cat("\nResultados guardados en:\n", carpeta, "\n")

  invisible(
    list(
      perfiles = perfiles,
      resumen_descriptivo = resumen,
      ajustes = ajustes,
      coeficientes_descriptivos = estimaciones,
      mejores_ajustes_descriptivos = mejores,
      referencia = referencia,
      cierre = cierre,
      carpeta = carpeta
    )
  )
}


# ============================================================================
# BLOQUE 06B — SupF convencional del taller
# Referencia convencional; no se interpreta como calibrada bajo I(1).
# ============================================================================


ejecutar_bloque_06b_trayectoria <- function(bloque01, trim = 0.15) {

  if (!requireNamespace("strucchange", quietly = TRUE)) {
    stop(
      'Falta strucchange. Ejecuta renv::install("strucchange") ',
      "y luego vuelve a ejecutar este bloque."
    )
  }

  if (!is.numeric(trim) || length(trim) != 1L ||
      !is.finite(trim) || trim <= 0 || trim >= 0.5) {
    stop("trim debe estar entre 0 y 0.5.")
  }

  datos <- bloque01$datos

  if (!all(c("fecha", "log_diaria") %in% names(datos))) {
    stop("bloque01$datos debe contener fecha y log_diaria.")
  }

  fechas <- as.Date(datos$fecha)
  y <- as.numeric(datos$log_diaria)

  calendario <- seq(
    as.Date("2002-01-01"),
    as.Date("2025-09-01"),
    by = "month"
  )

  if (!identical(as.character(fechas), as.character(calendario))) {
    stop("Se esperaba la muestra mensual completa: enero 2002 a septiembre 2025.")
  }

  if (length(y) != length(fechas) || any(!is.finite(y))) {
    stop("La variable debe tener un valor finito por mes.")
  }

  if (is.null(bloque01$carpeta)) {
    stop("Falta bloque01$carpeta para ubicar las salidas.")
  }

  n <- length(y)
  dat <- data.frame(y = y, t = seq_len(n))

  # tb identifica la ultima observacion del tramo previo.
  # La primera observacion posterior al cambio es tb + 1.
  lo <- as.integer(ceiling(trim * n))
  hi <- as.integer(floor((1 - trim) * n))
  candidatos <- seq.int(lo, hi)

  # Misma especificacion y funciones que en el taller.
  fs <- strucchange::Fstats(
    y ~ t,
    data = dat,
    from = lo,
    to = hi
  )

  contraste <- strucchange::sctest(fs, type = "supF")

  valores <- as.numeric(fs$Fstats)

  if (length(valores) != length(candidatos) ||
      any(!is.finite(valores))) {
    stop("El perfil supF no coincide con las fechas candidatas.")
  }

  posicion <- which.max(valores)
  tb <- candidatos[posicion]

  # Umbral convencional para el maximo, no para un Chow aislado.
  critico_5 <- as.numeric(
    strucchange::boundary(fs, alpha = 0.05)
  )[1L]

  perfil <- data.frame(
    tb_index = candidatos,
    ultima_fecha_previa = fechas[candidatos],
    primera_fecha_posterior = fechas[candidatos + 1L],
    estadistico_paquete = valores
  )

  resultado <- data.frame(
    modelo = "Constante + tendencia; sin indicadores mensuales",
    n = n,
    trim = trim,
    fechas_evaluadas = length(candidatos),
    supF_paquete = unname(contraste$statistic[1L]),
    critico_convencional_5pct = critico_5,
    p_convencional = unname(contraste$p.value),
    rechazo_convencional_5pct = contraste$p.value < 0.05,
    ultima_fecha_previa = fechas[tb],
    primera_fecha_posterior = fechas[tb + 1L]
  )

  # Ajustes para examinar los residuos.
  # La fecha se eligio con estos mismos datos:
  # no interpretar los p ordinarios de este lm como evidencia del quiebre.
  dat$DU <- as.integer(dat$t > tb)
  dat$DT <- pmax(dat$t - tb, 0)

  ajuste_nulo <- stats::lm(y ~ t, data = dat)
  ajuste_quiebre <- stats::lm(y ~ t + DU + DT, data = dat)

  residuos <- data.frame(
    fecha = fechas,
    sin_quiebre = as.numeric(stats::residuals(ajuste_nulo)),
    con_quiebre_candidato = as.numeric(stats::residuals(ajuste_quiebre))
  )

  carpeta <- file.path(
    dirname(bloque01$carpeta),
    "06b_supF_convencional"
  )
  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)

  utils::write.csv(
    resultado, file.path(carpeta, "01_resultado.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    perfil, file.path(carpeta, "02_perfil_supF.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    residuos, file.path(carpeta, "03_residuos.csv"),
    row.names = FALSE
  )

  notas <- c(
    "Referencia: taller_03B_cambio_estructural.R, funcion run_supF.",
    "Modelo: log_diaria ~ t; sin indicadores mensuales.",
    "H0: constante y pendiente estables.",
    "H1: cambia al menos uno de esos coeficientes.",
    "El p convencional contempla la busqueda entre fechas.",
    "No corrige por errores I(1), autocorrelacion ni estacionalidad.",
    "No es una cota del p correctamente calibrado.",
    "La fecha candidata no constituye por si sola un quiebre confirmado.",
    "No se modificaron d, D ni la muestra."
  )
  writeLines(notas, file.path(carpeta, "04_alcance.txt"))
  writeLines(
    capture.output(utils::sessionInfo()),
    file.path(carpeta, "05_sessionInfo.txt")
  )

  grDevices::png(
    file.path(carpeta, "01_supF_y_fac_residual.png"),
    width = 1600, height = 1500, res = 160
  )

  tryCatch({
    graphics::par(mfrow = c(3, 1), mar = c(4, 4, 3, 1))

    graphics::plot(
      perfil$primera_fecha_posterior,
      perfil$estadistico_paquete,
      type = "l", col = "#007C83",
      xlab = "Primera observacion posterior al cambio candidato",
      ylab = "Estadistico del paquete",
      main = "SupF convencional: constante y tendencia"
    )
    graphics::abline(h = critico_5, lty = 2, col = "grey40")
    graphics::abline(
      v = as.numeric(fechas[tb + 1L]),
      lty = 3, col = "#C05A00"
    )

    stats::acf(
      residuos$sin_quiebre, lag.max = 48,
      main = "FAC residual: modelo sin quiebre"
    )
    stats::acf(
      residuos$con_quiebre_candidato, lag.max = 48,
      main = "FAC residual: modelo con quiebre candidato"
    )
  }, finally = grDevices::dev.off())

  salida <- list(
    resultado = resultado,
    perfil = perfil,
    Fstats = fs,
    contraste = contraste,
    ajuste_nulo = ajuste_nulo,
    ajuste_quiebre = ajuste_quiebre,
    residuos = residuos,
    carpeta = carpeta
  )

  saveRDS(salida, file.path(carpeta, "06_objeto_06b.rds"))

  cat("\nBLOQUE 06B — SUPF CONVENCIONAL\n")
  cat("Periodo:", as.character(min(fechas)), "a",
      as.character(max(fechas)), "\n\n")
  print(resultado, row.names = FALSE, digits = 6)

  cat("\np convencional:",
      format.pval(contraste$p.value, digits = 4), "\n")
  cat("\nLECTURA\n")
  cat("- Rechazo convencional no equivale a quiebre confirmado.\n")
  cat("- Un rechazo conjunto no demuestra que cambien ambos coeficientes.\n")
  cat("- Revisar la FAC residual y las limitaciones registradas.\n")
  cat("- d, D y la muestra permanecen como decisiones anteriores.\n")
  cat("\nResultados en:\n", carpeta, "\n")

  invisible(salida)
}


# ============================================================================
# BLOQUE 06C — Calibracion aproximada condicional a I(1)
# Adaptacion sieve-wild expresamente autorizada; no replica literal de un test publicado.
# Referencia general: Lee (2011), sec. 4; algoritmo diferente.
# https://media.economics.uconn.edu/working/2011-05.pdf
# ============================================================================


ejecutar_bloque_06c_trayectoria <- function(bloque06b, B = 999L,
        pmax = 24L, semilla = 631062026L) {
  if (length(B) != 1L || !is.finite(B) || B < 199 || B != round(B)) {
    stop("B debe ser un entero de al menos 199; se recomienda 999.")
  }
  if (length(pmax) != 1L || !is.finite(pmax) ||
      pmax < 1 || pmax != round(pmax)) stop("pmax debe ser un entero positivo.")
  B <- as.integer(B)
  pmax <- as.integer(pmax)
  y <- as.numeric(stats::model.response(stats::model.frame(bloque06b$ajuste_nulo)))
  fechas <- as.Date(bloque06b$residuos$fecha)
  esperadas <- seq(as.Date("2002-01-01"), as.Date("2025-09-01"), by = "month")
  if (!identical(as.character(fechas), as.character(esperadas)) ||
      length(y) != length(fechas) || any(!is.finite(y))) {
    stop("Se requiere el bloque 06B con la muestra completa 2002-01 a 2025-09.")
  }
  n <- length(y)
  t <- seq_len(n)
  tb <- as.integer(bloque06b$perfil$tb_index)
  if (!identical(tb, seq.int(min(tb), max(tb))) ||
      min(tb) < 3L || max(tb) > n - 3L) stop("Fechas candidatas invalidas.")

  # Calculo rapido por proyecciones OLS. Es el mismo estadistico del paquete:
  # ganancia_SSR / (SSR_no_restringido / (n - 4)), sin dividir por dos.
  q0 <- qr(cbind(1, t))
  Q1 <- Q2 <- matrix(NA_real_, nrow = length(tb), ncol = n)
  for (j in seq_along(tb)) {
    U <- cbind(as.integer(t > tb[j]), base::pmax(t - tb[j], 0))
    Q <- qr.Q(qr(qr.resid(q0, U)))
    Q1[j, ] <- Q[, 1L]
    Q2[j, ] <- Q[, 2L]
  }
  perfil_supF <- function(z) {
    r <- qr.resid(q0, z)
    ss0 <- sum(r^2)
    ganancia <- as.numeric(Q1 %*% r)^2 + as.numeric(Q2 %*% r)^2
    ss1 <- ss0 - ganancia
    if (any(ss1 <= 0) || any(!is.finite(ss1))) stop("SSR no valido en el supF.")
    (n - 4L) * ganancia / ss1
  }
  observado <- perfil_supF(y)
  referencia <- bloque06b$perfil$estadistico_paquete
  if (length(referencia) != length(observado) ||
      max(abs(observado - referencia)) > 1e-7 * max(1, abs(referencia))) {
    stop("No se pudo reproducir el perfil completo del bloque 06B.")
  }
  Tobs <- max(observado)
  cat("Perfil completo del 06B reproducido correctamente.\n")

  # Modelo nulo: Delta y_t = constante + meses + AR(p) + innovacion_t.
  # AIC compara todos los p sobre exactamente las mismas observaciones.
  dy <- diff(y)
  nd <- length(dy)
  if (nd - pmax <= 12L + pmax + 10L) stop("pmax excesivo para esta muestra.")
  mes <- as.integer(format(fechas[-1L], "%m"))
  M <- cbind(constante = 1, outer(mes, 2:12, "==") * 1)
  colnames(M) <- c("constante", sprintf("mes_%02d", 2:12))
  L <- vapply(seq_len(pmax), function(k) {
    c(rep(NA_real_, k), head(dy, -k))
  }, numeric(nd))
  diseno <- function(p, ii) {
    if (p == 0L) M[ii, , drop = FALSE] else
      cbind(M[ii, , drop = FALSE], L[ii, seq_len(p), drop = FALSE])
  }
  comun <- seq.int(pmax + 1L, nd)
  tabla_AIC <- do.call(rbind, lapply(0:pmax, function(p) {
    X <- diseno(p, comun)
    a <- stats::lm.fit(X, dy[comun])
    if (a$rank != ncol(X)) stop("Regresion auxiliar sin rango completo.")
    data.frame(p = p, n_comun = length(comun),
         AIC_comun = length(comun) * log(mean(a$residuals^2)) +
           2 * (a$rank + 1L))
  }))
  p <- tabla_AIC$p[which.min(tabla_AIC$AIC_comun)]
  ii <- seq.int(p + 1L, nd)
  X <- diseno(p, ii)
  ajuste <- stats::lm.fit(X, dy[ii])
  beta <- ajuste$coefficients
  if (ajuste$rank != ncol(X) || any(!is.finite(beta))) stop("Ajuste auxiliar invalido.")
  ar <- if (p > 0L) tail(beta, p) else numeric(0)
  raiz <- if (p > 0L) min(Mod(polyroot(c(1, -ar)))) else Inf
  e <- ajuste$residuals
  lb24 <- stats::Box.test(e, lag = 24, type = "Ljung-Box", fitdf = 0)$p.value
  lb36 <- stats::Box.test(e, lag = 36, type = "Ljung-Box", fitdf = 0)$p.value
  diagnostico <- data.frame(
    p = p, n_ajuste = length(ii), raiz_AR_minima = raiz,
    LB24_orientativo = lb24, LB36_orientativo = lb36,
    p_en_limite = p == pmax
  )
  carpeta <- file.path(dirname(bloque06b$carpeta), "06c_bootstrap_supF")
  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(diagnostico, file.path(carpeta, "01_simulador.csv"), row.names = FALSE)
  utils::write.csv(tabla_AIC, file.path(carpeta, "02_AIC_auxiliar.csv"), row.names = FALSE)
  cat("\nSIMULADOR NULO\n")
  print(diagnostico, row.names = FALSE, digits = 6)
  if (raiz <= 1 + 1e-6 || lb24 < 0.05 || lb36 < 0.05 || p == pmax) {
    stop("El simulador requiere revision: no se inicio el bootstrap.")
  }

  # LB es orientativo, con fitdf=0; no acredita por si solo la validez del bootstrap.
  # Los multiplicadores N(0,1) no suponen innovaciones originales normales.
  # Mantienen E*(e_t*)=0 y Var*(e_t*)=e_t^2 en cada fecha.
  e <- (e - mean(e)) * sqrt(length(e) / (length(e) - ajuste$rank))
  deterministico <- as.numeric(M %*% beta[seq_len(ncol(M))])
  set.seed(semilla)
  Tstar <- numeric(B)
  fechas_star <- integer(B)
  inicio <- Sys.time()
  cat("\nIniciando", B, "replicas bootstrap...\n")
  for (b in seq_len(B)) {
    entrada <- deterministico[ii] + e * stats::rnorm(length(e))
    simulada <- if (p > 0L) {
      c(dy[seq_len(p)], as.numeric(stats::filter(
        entrada, filter = ar, method = "recursive", init = rev(dy[seq_len(p)])
      )))
    } else entrada
    ys <- c(y[1L], y[1L] + cumsum(simulada))
    v <- perfil_supF(ys)
    Tstar[b] <- max(v)
    fechas_star[b] <- tb[which.max(v)]
    if (b == 1L || b %% 100L == 0L || b == B) {
      cat("Replica", b, "de", B, "| minutos:",
          round(as.numeric(difftime(Sys.time(), inicio, units = "mins")), 2), "\n")
      utils::flush.console()
    }
  }
  pb <- (1 + sum(Tstar >= Tobs)) / (B + 1)
  critico <- as.numeric(stats::quantile(Tstar, 0.95, type = 1))
  resumen <- data.frame(
    supF_observado = Tobs,
    p_convencional_06b = bloque06b$resultado$p_convencional,
    critico_boot_5pct = critico, p_bootstrap_condicional_I1 = pb,
    error_MC_aproximado = sqrt(pb * (1 - pb) / B),
    rechazo_boot_condicional_5pct = pb < 0.05,
    primera_fecha_candidata_observada = fechas[tb[which.max(observado)] + 1L],
    replicas = B, p_simulador = p, semilla = semilla
  )
  replicas <- data.frame(replica = seq_len(B), supF = Tstar,
          primera_fecha_candidata = fechas[fechas_star + 1L])
  notas <- c(
    "Calibracion bootstrap aproximada, condicional a una representacion I(1).",
    "No es una replica literal de un algoritmo publicado ni una prueba robusta I(0)/I(1).",
    "Estadistico y fechas candidatas identicos a los del bloque 06B.",
    "El modelo del contraste sigue siendo y ~ t, sin indicadores mensuales.",
    "El SIMULADOR si incluye meses estables y AR sobre diferencias, sin quiebre.",
    "AR auxiliar elegido una vez por AIC con muestra comun; no es orden del SARIMA.",
    "Inicializacion condicional: primer nivel y primeras p diferencias observadas.",
    "Wild bootstrap de innovaciones; la dependencia AR y su orden se mantienen fijos.",
    "No se remuestrean los meses ni se fija la fecha candidata observada.",
    "Ljung-Box orientativo con fitdf=0; no valida el tamano del contraste.",
    "Error Monte Carlo no incluye incertidumbre por especificacion del simulador.",
    "Las fechas simuladas bajo H0 NO son un intervalo de confianza del quiebre.",
    "No rechazar no demuestra ausencia de quiebre. No se modifican d, D ni la muestra."
  )
  utils::write.csv(resumen, file.path(carpeta, "03_resumen.csv"), row.names = FALSE)
  utils::write.csv(replicas, file.path(carpeta, "04_replicas.csv"), row.names = FALSE)
  utils::write.csv(data.frame(fecha = fechas[ii + 1L], innovacion = e),
       file.path(carpeta, "05_innovaciones_simulador.csv"), row.names = FALSE)
  writeLines(notas, file.path(carpeta, "06_alcance.txt"))
  writeLines(capture.output(utils::sessionInfo()), file.path(carpeta, "07_sessionInfo.txt"))
  grDevices::png(file.path(carpeta, "01_distribucion_bootstrap.png"),
        width = 1500, height = 900, res = 150)
  tryCatch({
    graphics::hist(Tstar, breaks = "FD", col = "#83C4BD", border = "white",
          main = "SupF bajo la representacion I(1) sin quiebre",
          xlab = "Estadistico supF", xlim = range(c(Tstar, Tobs, critico)))
    graphics::abline(v = Tobs, col = "#BC5500", lwd = 2)
    graphics::abline(v = critico, lty = 2, lwd = 2)
    graphics::legend("topright", c("Observado", "Percentil bootstrap 95%"),
         col = c("#BC5500", "black"), lty = c(1, 2), lwd = 2, bty = "n")
  }, finally = grDevices::dev.off())
  salida <- list(resumen = resumen, diagnostico = diagnostico,
        tabla_AIC = tabla_AIC, replicas = replicas, carpeta = carpeta,
        coeficientes_simulador = beta, innovaciones = e, p = p,
        primeras_diferencias = dy[seq_len(p)], primer_nivel = y[1L])
  saveRDS(salida, file.path(carpeta, "08_objeto_06c.rds"))
  cat("\nBLOQUE 06C — RESULTADOS CONDICIONALES A I(1)\n")
  print(resumen, row.names = FALSE, digits = 6)
  cat("\nInterpretacion pendiente bajo la representacion nula estimada.\n")
  cat("No se incorporo automaticamente un quiebre.\n")
  cat("Resultados en:\n", carpeta, "\n")
  invisible(salida)
}


# ============================================================================
# ============================================================================
# BLOQUE 06: MISMO CONTRASTE DE TRAYECTORIA, CON DECISION 05 EXPLICITA
# El supF no es un contraste de estabilidad de coeficientes ARMA. Su auxiliar
# nula se estima para calibrar la prueba; su orden no es el orden del forecast.
# Se conserva ese procedimiento autorizado, sin sustituirlo por otro contraste.
# ============================================================================
bj_muestra_05 <- function(bloque01, bloque05) {
  ctx <- bj_contexto_05(bloque05)
  y <- as.numeric(bloque01$datos$log_diaria)
  if (length(y) != length(bloque05$serie_diferenciada) + 1L ||
      max(abs(diff(y) - as.numeric(bloque05$serie_diferenciada))) > 1e-10 ||
      !identical(as.character(bloque01$datos$fecha[-1L]), as.character(bloque05$fechas))) {
    stop("La muestra del 05 no corresponde al bloque 01.")
  }
  ctx
}

bj_guardar_contexto_06 <- function(z, ctx, archivo_rds) {
  z$origen05 <- ctx
  bj_csv(ctx$decision, z$carpeta, "00_modelo_elegido_05.csv")
  writeLines(c(
    paste("Modelo provisional elegido en 05:", ctx$modelo_id),
    "La pregunta del 06 sigue siendo cambio de nivel/pendiente de fecha desconocida en la trayectoria.",
    "No es una prueba de estabilidad de coeficientes ARMA ni usa el viejo SAR1 como base del forecast.",
    "La calibracion 06C conserva su auxiliar nula I(1) propia; el orden auxiliar no reemplaza al modelo del 05.",
    "Se mantienen algoritmo, muestra, semilla y alcance condicional del contraste autorizado.",
    "No se incorpora un quiebre automaticamente ni se traslada una fecha candidata a los outliers."
  ), file.path(z$carpeta, "00_dependencia_y_alcance_05.txt"))
  saveRDS(z, file.path(z$carpeta, archivo_rds))
  cat("Modelo de trabajo heredado del 05:", ctx$modelo_id, "\n")
  z
}

ejecutar_bloque_06 <- function(bloque01, bloque05, trim = 0.15) {
  ctx <- bj_muestra_05(bloque01, bloque05)
  z <- ejecutar_bloque_06_trayectoria(bloque01, trim)
  invisible(bj_guardar_contexto_06(z, ctx, "07_objeto_bloque06.rds"))
}

ejecutar_bloque_06b <- function(bloque01, bloque05, trim = 0.15) {
  ctx <- bj_muestra_05(bloque01, bloque05)
  z <- ejecutar_bloque_06b_trayectoria(bloque01, trim)
  invisible(bj_guardar_contexto_06(z, ctx, "06_objeto_06b.rds"))
}

ejecutar_bloque_06c <- function(bloque06b, B = 999L, pmax = 24L, semilla = 631062026L) {
  if (is.null(bloque06b$origen05$firma05)) stop("06B carece de la decision del 05; no reutilizar la corrida antigua.")
  # Argumentos originales preservados; el simulador sigue siendo el de la prueba.
  z <- ejecutar_bloque_06c_trayectoria(bloque06b, B = B, pmax = pmax, semilla = semilla)
  invisible(bj_guardar_contexto_06(z, bloque06b$origen05, "08_objeto_06c.rds"))
}


# ============================================================================
# BLOQUES 07 / 07B / 07C — DETECTOR CON EL MODELO ELEGIDO EN 05
# Fechas y tipos se vuelven a buscar; no se heredan LS/AO de la corrida antigua.
# ============================================================================
bj_resumen_eventos <- function(eventos, fit, C) {
  cf <- stats::coef(fit); se <- sqrt(diag(fit$var.coef))
  eventos$omega_final <- unname(cf[eventos$termino])
  eventos$se_condicional <- unname(se[eventos$termino])
  eventos$z_condicional <- eventos$omega_final / eventos$se_condicional
  eventos$abs_z_menor_C <- abs(eventos$z_condicional) < C
  eventos
}

bj_exportar_outliers <- function(z, etapa) {
  subcarpeta <- switch(etapa, "07" = "07_outliers_modelo05",
    "07B" = "07b_reestimacion_modelo05", "07C" = "07c_ciclo_modelo05")
  carpeta <- file.path(z$carpeta_raiz, subcarpeta)
  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
  z$carpeta <- carpeta
  z$efectos <- bj_resumen_eventos(z$efectos, z$modelo_provisional, z$umbral)
  e <- as.numeric(stats::residuals(z$modelo_provisional))
  cf <- stats::coef(z$modelo_provisional); se <- sqrt(diag(z$modelo_provisional$var.coef))
  z$coeficientes <- data.frame(termino = names(cf), estimacion = unname(cf),
    se_condicional = unname(se), z_condicional = unname(cf / se))
  z$diagnostico <- bj_diag_arma(z$modelo_provisional, paste("Tras", etapa))
  z$candidatos_restantes <- z$scan[!z$scan$fecha_ya_modelada & z$scan$supera_C, , drop = FALSE]
  elegibles <- z$scan[!z$scan$fecha_ya_modelada, , drop = FALSE]
  z$maximo_restante <- utils::head(elegibles, 1L)
  z$historial <- if (length(z$historia_lista)) bj_juntar(z$historia_lista) else
    data.frame(paso = integer(), fecha = as.Date(character()), tipo = character(),
      lambda = numeric(), abs_lambda = numeric(), incorporado = logical(), decision = character())
  ranking <- do.call(rbind, lapply(split(z$scan, z$scan$index), function(a) {
    b <- a[which.max(a$abs_lambda), , drop = FALSE]
    data.frame(index = b$index, fecha = b$fecha, tipo_maximo = b$tipo,
      max_abs_lambda = b$abs_lambda, supera_C = b$supera_C)
  }))
  ranking <- ranking[order(-ranking$max_abs_lambda), ]
  z$ranking <- ranking; z$candidatos <- ranking[ranking$supera_C, , drop = FALSE]
  z$dispersion <- do.call(rbind, lapply(list(c(2002, 2009), c(2010, 2017), c(2018, 2025)), function(a) {
    anio <- as.integer(format(z$fechas[-1L], "%Y")); ii <- which(anio >= a[1L] & anio <= a[2L])
    data.frame(tramo = paste(a, collapse = "-"), n = length(ii),
      media_residual = mean(e[ii]), desviacion_estandar = stats::sd(e[ii]))
  }))
  residuos <- data.frame(fecha = z$fechas[-1L], innovacion_base = as.numeric(stats::residuals(z$modelo_base)),
    innovacion_actual = e)
  tablas <- list("00_decision_origen_05.csv" = z$origen05$decision,
    "01_diagnostico.csv" = z$diagnostico, "02_scan_completo.csv" = z$scan,
    "03_candidatos_por_fecha.csv" = z$candidatos, "04_ranking_por_fecha.csv" = ranking,
    "05_dispersion_por_tramos.csv" = z$dispersion, "06_innovaciones.csv" = residuos,
    "07_configuracion.csv" = data.frame(C = z$umbral, delta_TC = z$delta_TC,
      modelo_origen = z$origen05$modelo_id, modelo_nivel = z$especificacion_base$modelo_nivel,
      efectos_actuales = nrow(z$efectos), discrepancia_filtro = attr(z$scan, "discrepancia_filtro")),
    "08_historial.csv" = z$historial, "09_efectos_conjuntos.csv" = z$efectos,
    "10_coeficientes.csv" = z$coeficientes, "11_comparacion_modelos.csv" = z$comparacion)
  for (nm in names(tablas)) bj_csv(tablas[[nm]], carpeta, nm)
  if (length(z$intentos_lista)) bj_csv(bj_juntar(z$intentos_lista), carpeta, "15_intentos_estimacion.csv")
  writeLines(c(
    paste("Modelo de partida elegido en 05:", z$origen05$modelo_id),
    paste("Motivo de parada:", z$motivo_parada),
    "Se conserva el detector clasico del capitulo/taller 04B; se generaliza el operador al ARMA elegido.",
    "El mismo filtro de innovaciones con parametros fijos se aplica a datos y firmas AO/IO/LS/TC.",
    "Se comprueba su reproduccion de las innovaciones; no se usa el filtro SAR puro anterior.",
    "Un maximo cada vez; reestimacion conjunta de AR/MA, meses y todos los efectos.",
    "El perfil IO usa el polinomio ARMA completo y se actualiza hasta cinco veces, como en el taller.",
    "Ninguna fecha ni tipo anterior se impone: el resultado puede tener cero, uno o varios efectos.",
    "Se mantienen C=3.5, delta TC=0.7, d=1/D=0, ausencia de deriva y muestra completa.",
    "Las fechas ya modeladas no compiten como eventos nuevos; no se reclasifican automaticamente.",
    "No se alteran datos observados. Las puntuaciones y Wald son condicionales, no p confirmatorios.",
    "Ljung-Box descuenta todos los parametros dinamicos p+q+P+Q.",
    "Un LS provisional no confirma el cambio estructural del bloque 06.",
    "El 08 revisara ordenes con los efectos que realmente surjan de esta corrida."
  ), file.path(carpeta, "12_alcance.txt"))
  writeLines(capture.output(utils::sessionInfo()), file.path(carpeta, "13_sessionInfo.txt"))
  grDevices::png(file.path(carpeta, "01_busqueda_por_tipo.png"), width = 1600, height = 1500, res = 160)
  tryCatch({
    graphics::par(mfrow = c(4, 1), mar = c(3, 4, 2, 1))
    for (tp in c("AO", "IO", "LS", "TC")) {
      a <- z$scan[z$scan$tipo == tp, ]; a <- a[order(a$index), ]
      graphics::plot(a$fecha, a$abs_lambda, type = "l", col = "#007C83",
        ylim = c(0, max(z$umbral + 0.5, z$scan$abs_lambda)), ylab = "|lambda|", xlab = "",
        main = paste(tp, "—", z$especificacion_base$modelo_nivel))
      graphics::abline(h = z$umbral, lty = 2, col = "#B45700")
      if (nrow(z$efectos)) graphics::abline(v = as.numeric(z$efectos$fecha), lty = 3, col = "grey60")
    }
  }, finally = grDevices::dev.off())
  grDevices::png(file.path(carpeta, "02_residuos_fac_facp.png"), width = 1700, height = 1000, res = 160)
  tryCatch({
    graphics::par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
    graphics::plot(z$fechas[-1L], residuos$innovacion_base, type = "l", xlab = "Fecha", ylab = "Innovacion", main = "Base elegida en 05")
    graphics::plot(z$fechas[-1L], e, type = "l", col = "#007C83", xlab = "Fecha", ylab = "Innovacion", main = paste("Tras", etapa))
    stats::acf(e, lag.max = 48, main = "FAC residual"); stats::pacf(e, lag.max = 48, main = "FACP residual")
  }, finally = grDevices::dev.off())
  archivo <- switch(etapa, "07" = "11_objeto_bloque07.rds", "07B" = "10_objeto_bloque07b.rds", "07C" = "14_objeto_bloque07c.rds")
  saveRDS(z, file.path(carpeta, archivo))
  cat("\nBLOQUE", etapa, "— MODELO HEREDADO DEL 05\n")
  print(z$diagnostico, row.names = FALSE, digits = 6)
  cat("Motivo de parada:", z$motivo_parada, "\n")
  cat("\nEFECTOS CONJUNTOS PROVISIONALES\n"); print(z$efectos, row.names = FALSE, digits = 6)
  cat("\nSIGUIENTE MAXIMO EN FECHAS NO MODELADAS\n"); print(z$maximo_restante, row.names = FALSE, digits = 6)
  cat("\nCOMPARACION DE AJUSTES\n"); print(z$comparacion, row.names = FALSE, digits = 6)
  cat("Resultados en:\n", carpeta, "\n")
  z
}

bj_continuar_deteccion <- function(z, nuevas_maximas, max_outliers = 8L) {
  incorporados <- 0L
  repeat {
    elegibles <- z$scan[!z$scan$fecha_ya_modelada, , drop = FALSE]
    if (!nrow(elegibles)) { z$motivo_parada <- "Sin fechas elegibles"; break }
    top <- elegibles[1L, , drop = FALSE]
    motivo <- if (top$abs_lambda < z$umbral) "Maximo restante por debajo de C" else
      if (nrow(z$efectos) >= max_outliers) "Limite total de efectos; requiere revision" else
      if (sum(abs(elegibles$abs_lambda - top$abs_lambda) < 1e-10) > 1L) "Empate en el maximo; requiere revision" else
      if (top$cerca_del_inicio || top$cerca_del_final) "Candidato proximo a un extremo; requiere revision" else ""
    h <- data.frame(paso = length(z$historia_lista) + 1L, fecha = top$fecha, tipo = top$tipo,
      lambda = top$lambda, abs_lambda = top$abs_lambda, incorporado = FALSE, decision = motivo)
    if (nzchar(motivo)) {
      z$historia_lista[[length(z$historia_lista) + 1L]] <- h; z$motivo_parada <- motivo; break
    }
    if (incorporados >= nuevas_maximas) { z$motivo_parada <- "Primera incorporacion completada; continuar en 07C"; break }
    orden <- nrow(z$efectos) + 1L
    nuevo <- data.frame(orden = orden, index = top$index, fecha = top$fecha, tipo = top$tipo,
      termino = paste0("OUT", orden, "_", top$tipo, "_", format(top$fecha, "%Y%m")),
      lambda_incorporacion = top$lambda, omega_scan = top$omega_log, stringsAsFactors = FALSE)
    columnas <- names(bj_eventos_vacios())
    eventos <- rbind(z$efectos[, columnas, drop = FALSE], nuevo)
    re <- bj_reestimar_eventos(z$serie_diferenciada, z$fechas, z$regresores_mensuales,
      eventos, z$modelo_provisional, z$especificacion_base, z$delta_TC)
    z$modelo_provisional <- re$modelo; z$regresores_con_efectos <- re$X; z$efectos <- eventos
    z$intentos_lista[[length(z$intentos_lista) + 1L]] <- re$intentos
    z$modelos[[paste0("efectos_", orden)]] <- re$modelo
    z$comparacion <- rbind(z$comparacion, bj_diag_arma(re$modelo, paste("Con", orden, "efectos")))
    h$incorporado <- TRUE; h$decision <- "Incorporado provisionalmente; reestimacion conjunta"
    z$historia_lista[[length(z$historia_lista) + 1L]] <- h
    cat("\nIncorporado:", as.character(top$fecha), top$tipo, "|lambda| =", round(top$abs_lambda, 5), "\n")
    z$scan <- bj_scan_arma(re$modelo, z$fechas, z$serie_diferenciada, re$X,
      z$umbral, z$delta_TC, eventos$index)
    z$scans[[length(z$scans) + 1L]] <- z$scan
    incorporados <- incorporados + 1L
  }
  z
}

ejecutar_bloque_07 <- function(bloque01, bloque05, umbral = 3.5, delta_tc = 0.7) {
  origen <- bj_contexto_05(bloque05)
  fechas <- as.Date(bloque01$datos$fecha); y <- as.numeric(bloque01$datos$log_diaria)
  dy <- bloque05$serie_diferenciada; X <- as.matrix(bloque05$regresores)
  if (length(dy) != length(y) - 1L || max(abs(as.numeric(dy) - diff(y))) > 1e-10 ||
      !identical(as.character(fechas[-1L]), as.character(bloque05$fechas)) ||
      nrow(X) != length(dy) || ncol(X) != 11L || !is.finite(umbral) || umbral <= 0 ||
      !is.finite(delta_tc) || delta_tc <= 0 || delta_tc >= 1) stop("Datos o configuracion del 05 no validos.")
  fit <- bloque05$modelo_base
  scan <- bj_scan_arma(fit, fechas, dy, X, umbral, delta_tc)
  z <- list(modelo_base = fit, modelo_provisional = fit, origen05 = origen,
    especificacion_base = bloque05$especificacion_seleccionada,
    serie_log = y, fechas = fechas, serie_diferenciada = dy,
    regresores_mensuales = X, regresores_con_efectos = X,
    efectos = bj_eventos_vacios(), scan = scan, scans = list(scan),
    umbral = umbral, delta_TC = delta_tc, d_original = 1L, D_original = 0L,
    historia_lista = list(), intentos_lista = list(), modelos = list(base05 = fit),
    comparacion = bj_diag_arma(fit, "Base elegida en 05, sin outliers"),
    motivo_parada = "Primera busqueda; todavia sin efectos incorporados",
    carpeta_raiz = dirname(bloque01$carpeta))
  invisible(bj_exportar_outliers(z, "07"))
}

ejecutar_bloque_07b <- function(bloque07) {
  if (is.null(bloque07$origen05$firma05)) stop("07 no procede del modelo elegido en 05; no reutilizar resultados antiguos.")
  z <- bj_continuar_deteccion(bloque07, nuevas_maximas = 1L)
  z$modelo_07b <- z$modelo_provisional
  invisible(bj_exportar_outliers(z, "07B"))
}

ejecutar_bloque_07c <- function(bloque07b, max_outliers = 8L) {
  if (is.null(bloque07b$origen05$firma05)) stop("07B no procede del modelo elegido en 05.")
  if (length(max_outliers) != 1L || !is.finite(max_outliers) ||
      max_outliers < 1L || max_outliers != as.integer(max_outliers)) stop("Limite de efectos no valido.")
  z <- bj_continuar_deteccion(bloque07b, nuevas_maximas = max_outliers, max_outliers = max_outliers)
  invisible(bj_exportar_outliers(z, "07C"))
}


# ============================================================================
# BLOQUE 08 — Revision final DESPUES de outliers
# Mismas familias pequenas reestimadas con los efectos; diagnostico conjunto.
# ============================================================================


ejecutar_bloque_08 <- function(bloque07c, bloque05) {
  origen <- bj_contexto_05(bloque05)
  if (!identical(bloque07c$origen05$firma05, origen$firma05)) {
    stop("07C no proviene de la decision actual del 05. No reutilizar outliers de la corrida anterior.")
  }
  # 1. Recuperar la representacion y comprobar que continua el flujo acordado.
  fechas <- as.Date(bloque07c$fechas)
  y <- as.numeric(bloque07c$serie_log)
  dy <- bloque07c$serie_diferenciada
  X <- as.matrix(bloque07c$regresores_con_efectos)
  Xmes <- as.matrix(bloque07c$regresores_mensuales)
  eventos <- bloque07c$efectos
  fit_ref <- bloque07c$modelo_provisional
  calendario <- seq(as.Date("2002-01-01"), as.Date("2025-09-01"), by = "month")
  if (!identical(as.character(fechas), as.character(calendario)) ||
      length(y) != length(fechas) || any(!is.finite(y)) ||
      length(dy) != length(y) - 1L || any(!is.finite(dy)) ||
      max(abs(as.numeric(dy) - diff(y))) > 1e-10 || stats::frequency(dy) != 12) {
    stop("Se requiere la muestra y la serie diferenciada mensual de 07C.")
  }
  if (!all(eventos$termino %in% colnames(X)) || nrow(X) != length(dy) ||
      ncol(X) != ncol(Xmes) + nrow(eventos) || ncol(Xmes) != 11L ||
      any(!is.finite(X)) || qr(X)$rank < ncol(X)) {
    stop("Los meses y los efectos no corresponden al resultado actual de 07C.")
  }
  bj_validar_arma(fit_ref, X)
  n <- length(dy)
  cf_ref <- stats::coef(fit_ref)
  u_ref <- as.numeric(dy) - as.numeric(X %*% cf_ref[colnames(X)])
  e_ref <- as.numeric(stats::residuals(fit_ref))
  if (max(abs(bj_filtrar_fijo(u_ref, fit_ref, stats::start(dy)) - e_ref)) > 1e-6) {
    stop("No se reproducen las innovaciones del modelo heredado de 07C.")
  }
  # 2. Revisar nuevamente TODAS las alternativas de 05 bajo los efectos de 07C.
  # No se presupone que el ganador antes de efectos sea el ganador posterior.
  especificaciones <- bj_candidatos_ordenes("08")
  sp_ref <- bj_especificacion_fit(fit_ref)
  j_ref <- which(especificaciones$p == sp_ref$p & especificaciones$q == sp_ref$q &
    especificaciones$P == sp_ref$P & especificaciones$Q == sp_ref$Q)
  if (length(j_ref) != 1L) stop("El orden elegido en 05 no esta en los candidatos de 08.")
  id_ref <- especificaciones$candidato[j_ref]
  especificaciones$referencia_heredada_05 <- especificaciones$candidato == id_ref
  carpeta <- file.path(dirname(bloque07c$carpeta), "08_revision_final_dinamica")
  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(especificaciones, file.path(carpeta, "00_especificaciones.csv"), row.names = FALSE)
  cat("\nBLOQUE 08 — REVISION FINAL DE LA DINAMICA\n")
  cat("Muestra completa; d=1, D=0, sin deriva;", nrow(eventos), "efectos y once contrastes mensuales.\n")
  cat("Referencia heredada de 05/07C:", id_ref, "\n")
  print(especificaciones[, c("candidato", "modelo_nivel")], row.names = FALSE)

  # 3. Comparar con la referencia realmente elegida y reestimada en 07C.
  modelos <- stats::setNames(list(fit_ref), id_ref)
  disenos <- stats::setNames(list(X), id_ref)
  intentos <- list(data.frame(candidato = id_ref, inicio = "Reutilizado_07C_modelo05",
    convergio = TRUE, logLik = as.numeric(stats::logLik(fit_ref)), avisos = "", error = ""))
  for (i in which(especificaciones$candidato != id_ref)) {
    sp <- especificaciones[i, ]
    nuevo <- tryCatch(bj_reestimar_eventos(dy, fechas, Xmes, eventos, fit_ref,
      sp, bloque07c$delta_TC), error = function(e) list(error = conditionMessage(e)))
    # Extraccion exacta: nuevo$error haria coincidencia parcial con
    # error_perfil_IO=0 y confundiria un ajuste correcto con un fallo.
    fallo <- nuevo[["error", exact = TRUE]]
    if (!is.null(fallo)) {
      intentos[[length(intentos) + 1L]] <- data.frame(candidato = sp$candidato,
        inicio = "Reestimacion_con_efectos", convergio = FALSE, logLik = NA_real_,
        avisos = "", error = as.character(fallo))
    } else {
      modelos[[sp$candidato]] <- nuevo$modelo; disenos[[sp$candidato]] <- nuevo$X
      intentos[[length(intentos) + 1L]] <- nuevo$intentos
    }
  }
  intentos <- bj_juntar(intentos)
  if (length(modelos) < 2L) {
    bj_csv(intentos, carpeta, "06_intentos_estimacion.csv")
    stop("08 no comparo alternativas: revisar 06_intentos_estimacion.csv. No interpretar la referencia como seleccion final.")
  }

  # 4. Polinomios completos, incluidos productos regular por estacional.
  # Las raices corresponden a la parte estacionaria: no incluyen (1-L).
  multiplicar <- bj_multiplicar
  raices_de <- function(polinomio) {
    ultimo <- max(which(abs(polinomio) > 1e-12))
    if (ultimo == 1L) return(complex())
    base::polyroot(polinomio[1:ultimo])
  }
  minimo <- function(z) if (length(z)) min(Mod(z)) else Inf
  resumenes <- list(); coefs <- list(); raices <- list(); acfs <- list()
  dispersiones <- list(); tc <- list(); residuos <- list()
  fecha_tc <- as.Date("2003-05-01")
  g_tc <- numeric(length(y))
  index_tc <- match(fecha_tc, fechas)
  g_tc[index_tc:length(y)] <- bloque07c$delta_TC^(0:(length(y) - index_tc))
  anio <- as.integer(format(fechas[-1L], "%Y"))
  tramo <- cut(anio, c(2001, 2009, 2017, 2025),
        labels = c("2002-2009", "2010-2017", "2018-2025"))
  for (nombre in names(modelos)) {
    fit <- modelos[[nombre]]
    sp <- especificaciones[especificaciones$candidato == nombre, ]
    cf <- stats::coef(fit); V <- fit$var.coef
    Xfit <- disenos[[nombre]]
    Vok <- is.matrix(V) && nrow(V) == length(cf) && ncol(V) == length(cf) &&
      all(is.finite(V)) && all(diag(V) > 0)
    if (Vok) Vok <- tryCatch({ chol(V); TRUE }, error = function(e) FALSE)
    se <- if (Vok) sqrt(diag(V)) else stats::setNames(rep(NA_real_, length(cf)), names(cf))
    ar <- unname(cf[grep("^ar[0-9]+$", names(cf))])
    ma <- unname(cf[grep("^ma[0-9]+$", names(cf))])
    sar <- unname(cf[grep("^sar[0-9]+$", names(cf))])
    sma <- unname(cf[grep("^sma[0-9]+$", names(cf))])
    A <- c(1, -ar); M <- c(1, ma)
    AS <- if (length(sar)) c(1, rep(0, 11L), -sar) else 1
    MS <- if (length(sma)) c(1, rep(0, 11L), sma) else 1
    AR <- multiplicar(A, AS); MA <- multiplicar(M, MS)
    rAR <- raices_de(AR); rMA <- raices_de(MA)
    rA <- raices_de(A); rM <- raices_de(M)
    estacionario <- minimo(rAR) > 1 + 1e-8
    invertible <- minimo(rMA) > 1 + 1e-8
    e <- as.numeric(stats::residuals(fit))
    if (length(e) != n || any(!is.finite(e))) stop("Innovaciones no validas: ", nombre)
    residuos[[nombre]] <- e
    k <- length(cf) + 1L
    ll <- as.numeric(stats::logLik(fit))
    df_dinamica <- sp$p + sp$q + sp$P + sp$Q
    lb <- vapply(c(12L, 24L, 36L), function(h) {
      stats::Box.test(e, lag = h, type = "Ljung-Box", fitdf = df_dinamica)$p.value
    }, numeric(1))
    dist_regular <- if (length(rA) && length(rM)) min(abs(outer(rA, rM, "-"))) else NA_real_
    correlacion_ar_ma <- if (Vok && all(c("ar1", "ma1") %in% names(cf))) {
      V["ar1", "ma1"] / sqrt(V["ar1", "ar1"] * V["ma1", "ma1"])
    } else NA_real_
    resumenes[[nombre]] <- data.frame(
      candidato = nombre, modelo_nivel = sp$modelo_nivel,
      n = n, convergio = fit$code == 0L,
      parametros_con_varianza = k, matriz_cov_valida = Vok,
      raiz_AR_minima = minimo(rAR), raiz_MA_minima = minimo(rMA),
      estacionario_AR = estacionario, invertible_MA = invertible,
      distancia_regular_AR_MA = dist_regular,
      correlacion_ar1_ma1 = correlacion_ar_ma,
      distancia_MA_a_mas_uno = if (length(rMA)) min(abs(rMA - 1)) else NA_real_,
      AICc = -2 * ll + 2 * k + 2 * k * (k + 1) / (n - k - 1),
      BIC = -2 * ll + log(n) * k, sigma_innovacion = sqrt(mean(e^2)),
      logLik = ll,
      LB12 = lb[1L], LB24 = lb[2L], LB36 = lb[3L],
      fitdf_LB = df_dinamica, alguno_LB_menor_005 = any(lb < 0.05)
    )
    coefs[[nombre]] <- data.frame(
      candidato = nombre, termino = names(cf), estimacion = unname(cf),
      se_condicional = unname(se[names(cf)]),
      limite_95_inferior = unname(cf - stats::qnorm(0.975) * se[names(cf)]),
      limite_95_superior = unname(cf + stats::qnorm(0.975) * se[names(cf)])
    )
    for (operador in c("AR", "MA")) {
      z <- if (operador == "AR") rAR else rMA
      if (length(z)) raices[[length(raices) + 1L]] <- data.frame(
        candidato = nombre, operador = operador, real = Re(z), imaginaria = Im(z), modulo = Mod(z)
      )
    }
    acfs[[nombre]] <- data.frame(
      candidato = nombre, rezago = 1:48,
      FAC = as.numeric(stats::acf(e, lag.max = 48, plot = FALSE)$acf)[-1L],
      FACP = as.numeric(stats::pacf(e, lag.max = 48, plot = FALSE)$acf),
      banda_orientativa = stats::qnorm(0.975) / sqrt(n)
    )
    dispersiones[[nombre]] <- do.call(rbind, lapply(levels(tramo), function(tp) {
      ii <- which(tramo == tp)
      data.frame(candidato = nombre, tramo = tp, n = length(ii),
           media = mean(e[ii]), desviacion_estandar = stats::sd(e[ii]))
    }))

    # 5. Seguimiento de la UNICA señal limitrofe ya identificada en 07C.
    # Se aplica el operador del candidato con parametros fijos a los datos
    # y al perfil TC. No es otra estimacion de parametros ni un nuevo detector.
    # No se incorpora TC ni se buscan nuevas fechas durante esta comparacion.
    if (estacionario && invertible) {
      dinamicos <- grep("^(ar|ma|sar|sma)[0-9]+$", names(cf), value = TRUE)
      filtrar <- function(z) {
        f <- stats::arima(
          stats::ts(as.numeric(z), start = stats::start(dy), frequency = 12),
          order = c(sp$p, 0L, sp$q),
          seasonal = list(order = c(sp$P, 0L, sp$Q), period = 12),
          include.mean = FALSE, fixed = unname(cf[dinamicos]),
          transform.pars = FALSE, method = "ML"
        )
        as.numeric(stats::residuals(f))
      }
      u <- as.numeric(dy) - as.numeric(Xfit %*% cf[colnames(Xfit)])
      err_filtro <- max(abs(filtrar(u) - e))
      if (!is.finite(err_filtro) || err_filtro > 1e-6) {
        stop("El filtro con parametros fijos no reproduce innovaciones: ", nombre)
      }
      z <- filtrar(diff(g_tc)); den <- sum(z^2)
      w <- sum(z * e) / den; s <- sqrt(fit$sigma2 / den)
      tc[[nombre]] <- data.frame(
        candidato = nombre, fecha = fecha_tc, tipo = "TC", delta = bloque07c$delta_TC,
        omega_scan = w, lambda_condicional = w / s,
        C = bloque07c$umbral, supera_C = abs(w / s) >= bloque07c$umbral,
        incorporado = any(eventos$index == index_tc & eventos$tipo == "TC"),
        fecha_ya_modelada = index_tc %in% eventos$index, discrepancia_filtro = err_filtro
      )
    }
  }

  # 6. Tablas para la decision: no ordenar ni seleccionar automaticamente.
  diagnosticos <- do.call(rbind, resumenes)
  revision <- bj_revision_ordenes(diagnosticos, especificaciones)
  coeficientes <- do.call(rbind, coefs)
  dinamicos <- coeficientes[grepl("^(ar|ma|sar|sma)[0-9]+$", coeficientes$termino), ]
  efectos <- coeficientes[coeficientes$termino %in% eventos$termino, ]
  acf_residual <- do.call(rbind, acfs)
  dispersion <- do.call(rbind, dispersiones)
  tabla_raices <- do.call(rbind, raices)
  seguimiento_tc <- if (length(tc)) do.call(rbind, tc) else data.frame()
  identificacion <- data.frame(fecha = fechas[-1L],
            componente_dinamico_07c = u_ref, innovacion_07c = e_ref)
  tabla_residuos <- data.frame(fecha = fechas[-1L], as.data.frame(residuos))
  tablas <- list(
    "01_diagnosticos.csv" = diagnosticos, "02_coeficientes_dinamicos.csv" = dinamicos,
    "03_efectos_outliers.csv" = efectos, "04_fac_facp_residual.csv" = acf_residual,
    "05_identificacion.csv" = identificacion, "06_intentos_estimacion.csv" = intentos,
    "07_dispersion_por_tramos.csv" = dispersion, "08_raices.csv" = tabla_raices,
    "09_TC_limite.csv" = seguimiento_tc, "10_coeficientes_completos.csv" = coeficientes,
    "11_residuos.csv" = tabla_residuos,
    "15_revision_ordenes.csv" = revision$comparacion,
    "16_estado_decision.csv" = revision$estado
  )
  for (nm in names(tablas)) utils::write.csv(tablas[[nm]], file.path(carpeta, nm), row.names = FALSE)
  notas <- c(
    "Fundamento: capitulos 01, 03D y 04B; pocos candidatos, estimacion y diagnostico conjunto.",
    "Comparacion acotada y explicita: referencias, alternativas regulares basicas y ampliaciones mixtas; sin evaluacion predictiva.",
    "Los cortes de FAC/FACP no identifican inequivocamente un orden regular; ampliaciones tentativas.",
    "Se retoman AR1, AR2, MA1, MA2 y ARMA11 con SAR1/SMA1; se agregan ARMA21, ARMA12 y ARMA22 como ampliaciones.",
    "Se registran varios inicios de cada especificacion; los fallos no se ocultan ni se confunden con evidencia contra el orden.",
    "Referencia elegida en 05 y reestimada en 07C; no se sustituye por el viejo SAR puro.",
    "Los efectos son los detectados en esta corrida. No se exigen LS/AO ni fechas prefijadas.",
    "Si hay IO, su perfil se actualiza con los coeficientes de cada candidato; inferencia y ajuste son condicionales a ese procedimiento.",
    "Misma variable, muestra efectiva y regresores: AICc/BIC comparables dentro de esta lista.",
    "Sigma_innovacion es raiz del promedio de innovaciones al cuadrado: convencion comun con el auditor.",
    "Los errores estandar e intervalos son condicionales y aproximados tras seleccionar outliers.",
    "Las raices excluyen (1-L), pues describen la dinamica estacionaria de Delta log.",
    "No aplicar umbral universal a distancias entre raices ni a correlaciones entre estimadores.",
    "Ljung-Box descuenta p+q+P+Q. Es aproximado con regresores estimados, seleccion y dispersion variable.",
    "Los tres horizontes LB se leen conjuntamente con FAC/FACP; no elegir el p mas conveniente.",
    "TC mayo 2003 se conserva solo como seguimiento historico. Se informa si su fecha ya fue modelada en esta corrida.",
    "El seguimiento historico no impone la ausencia de TC ni sustituye el scan actualizado de 07C.",
    "La mayor dispersion temprana se conserva como diagnostico; no se introduce otro modelo de varianza.",
    "No se modifica muestra, d=1, D=0, ausencia de deriva ni fechas/tipos incorporados.",
    "No se declara modelo final automaticamente. Elegir con evidencia de parametros, raices y residuos.",
    "Si todos conservan autocorrelacion, no informar diagnostico aprobado ni que el menor AICc la resuelve."
  )
  writeLines(notas, file.path(carpeta, "12_alcance.txt"))
  writeLines(capture.output(utils::sessionInfo()), file.path(carpeta, "13_sessionInfo.txt"))

  # 7. Figuras con ejes de retardos mensuales y sin el pico trivial de rezago 0.
  correlograma <- function(z, parcial = FALSE, titulo = "") {
    v <- if (parcial) as.numeric(stats::pacf(z, lag.max = 48, plot = FALSE)$acf) else
      as.numeric(stats::acf(z, lag.max = 48, plot = FALSE)$acf)[-1L]
    limite <- max(0.2, ceiling(10 * max(abs(v))) / 10)
    graphics::plot(1:48, v, type = "h", ylim = c(-limite, limite),
          xlab = "Rezago mensual", ylab = if (parcial) "FACP" else "FAC", main = titulo)
    graphics::abline(h = 0, col = "grey50")
    graphics::abline(h = c(-1, 1) * stats::qnorm(0.975) / sqrt(length(z)), lty = 2, col = "grey50")
    graphics::abline(v = c(12, 24, 36, 48), lty = 3, col = "grey80")
  }
  grDevices::png(file.path(carpeta, "01_identificacion_ajustada.png"), width = 1700, height = 1100, res = 160)
  tryCatch({
    graphics::par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
    correlograma(u_ref, FALSE, "Componente ajustado por meses y efectos: FAC")
    correlograma(u_ref, TRUE, "Componente ajustado por meses y efectos: FACP")
    correlograma(e_ref, FALSE, paste(id_ref, "heredado: FAC"))
    correlograma(e_ref, TRUE, paste(id_ref, "heredado: FACP"))
  }, finally = grDevices::dev.off())
  grDevices::png(file.path(carpeta, "02_fac_facp_candidatos.png"), width = 1700, height = 400 * length(modelos), res = 160)
  tryCatch({
    graphics::par(mfrow = c(length(modelos), 2), mar = c(3, 4, 2, 1))
    for (nombre in names(modelos)) {
      correlograma(residuos[[nombre]], FALSE, paste(nombre, "— FAC"))
      correlograma(residuos[[nombre]], TRUE, paste(nombre, "— FACP"))
    }
  }, finally = grDevices::dev.off())
  grDevices::png(file.path(carpeta, "03_residuos_y_qq.png"), width = 1700, height = 400 * length(modelos), res = 160)
  tryCatch({
    graphics::par(mfrow = c(length(modelos), 2), mar = c(3, 4, 2, 1))
    yr <- range(unlist(residuos))
    for (nombre in names(modelos)) {
      e <- residuos[[nombre]]
      graphics::plot(fechas[-1L], e, type = "l", col = "#007C83", ylim = yr,
            xlab = "Fecha", ylab = "Innovacion", main = nombre)
      graphics::abline(h = 0, col = "grey65")
      stats::qqnorm(e, main = paste(nombre, "— QQ auxiliar"), pch = 16, cex = 0.45)
      stats::qqline(e, col = "#B45700")
    }
  }, finally = grDevices::dev.off())
  salida <- list(
    especificaciones = especificaciones, modelos = modelos, diagnosticos = diagnosticos,
    origen05 = origen, referencia_heredada = id_ref, regresores_por_modelo = disenos,
    coeficientes = coeficientes, coeficientes_dinamicos = dinamicos, efectos = efectos,
    eventos = eventos, intentos = intentos, dispersion = dispersion, raices = tabla_raices,
    acf_residual = acf_residual, seguimiento_tc = seguimiento_tc,
    serie_log = y, fechas = fechas, serie_diferenciada = dy,
    regresores = X, regresores_mensuales = Xmes, d_original = 1L, D_original = 0L,
    umbral = bloque07c$umbral, delta_TC = bloque07c$delta_TC,
    revision_ordenes = revision$comparacion, estado_decision = revision$estado,
    modelo_seleccionado = NULL, carpeta = carpeta
  )
  saveRDS(salida, file.path(carpeta, "14_objeto_bloque08.rds"))
  cat("\nDIAGNOSTICOS DE RAICES Y PRECISION\n")
  print(diagnosticos[, c("candidato", "matriz_cov_valida", "raiz_AR_minima", "raiz_MA_minima",
          "distancia_regular_AR_MA", "correlacion_ar1_ma1")], row.names = FALSE, digits = 6)
  cat("\nAJUSTE Y AUTOCORRELACION RESIDUAL\n")
  print(diagnosticos[, c("candidato", "AICc", "BIC", "sigma_innovacion", "LB12", "LB24", "LB36")], row.names = FALSE, digits = 6)
  cat("\nCOEFICIENTES DINAMICOS\n"); print(dinamicos, row.names = FALSE, digits = 6)
  cat("\nEFECTOS ATIPICOS: REESTIMACION CONJUNTA\n"); print(efectos, row.names = FALSE, digits = 6)
  cat("\nTC MAYO 2003: SEGUIMIENTO DE LA SENAL LIMITROFE, SIN INCORPORAR\n")
  print(seguimiento_tc, row.names = FALSE, digits = 6)
  if (any(!intentos$convergio) || any(nzchar(intentos$avisos))) {
    cat("\nINTENTOS CON PROBLEMAS O AVISOS\n")
    print(intentos[!intentos$convergio | nzchar(intentos$avisos), ], row.names = FALSE)
  }
  cat("\nNo se ha seleccionado automaticamente el modelo final.\n")
  cat("DECISION PENDIENTE: revisar el conjunto ampliado frente al modelo heredado del 05.\n")
  cat("Revisar coeficientes, raices, residuos y senal TC conjuntamente.\n")
  cat("Resultados en:\n", carpeta, "\n")
  invisible(salida)
}


# ============================================================================
# BLOQUE 08B — AUDITOR AUTO.ARIMA BAJO LA MISMA ARQUITECTURA MANUAL
# Misma Delta log, muestra, 11 meses y efectos actuales; sin media/deriva adicional.
# Solo audita p/q/P/Q dentro de los limites del taller. IC aqui comparables.
# ============================================================================

ejecutar_bloque_08b <- function(bloque08) {
  y <- bloque08$serie_diferenciada
  X <- as.matrix(bloque08$regresores)
  if (length(y) != 284L || nrow(X) != length(y) || ncol(X) != 11L + nrow(bloque08$eventos) ||
      any(!is.finite(y)) || any(!is.finite(X)) || qr(X)$rank < ncol(X)) {
    stop("Se requiere la arquitectura de datos y regresores del bloque 08.")
  }
  cat("\nAUTO.ARIMA CONDICIONADO: auditoria de p/q/P/Q; puede tardar.\n")
  salida <- NULL
  for (it_IO in 1:5) {
    salida <- bj_ajustar_auto(y, X, condicionado = TRUE)
    if (!any(bloque08$eventos$tipo == "IO")) break
    xn <- bj_diseno_efectos(bloque08$fechas, bloque08$regresores_mensuales,
      bloque08$eventos, salida$modelo, bloque08$delta_TC)$X
    if (max(abs(xn - X)) < 1e-6) break
    if (it_IO == 5L) stop("El perfil IO del auditor no convergio; revisar antes del cierre.")
    X <- xn
  }
  carpeta <- file.path(dirname(bloque08$carpeta), "08b_auto_arima_condicionado")
  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
  columnas <- c("candidato", "modelo_nivel", "AICc", "BIC", "sigma_innovacion", "LB12", "LB24", "LB36")
  comparacion <- rbind(bloque08$diagnosticos[, columnas], salida$resumen[, columnas])
  bj_csv(comparacion, carpeta, "01_comparacion_manual_auto.csv")
  bj_csv(salida$configuracion, carpeta, "02_configuracion.csv")
  bj_csv(salida$coeficientes, carpeta, "03_coeficientes.csv")
  bj_csv(data.frame(fecha = bloque08$fechas[-1L],
        innovacion = as.numeric(stats::residuals(salida$modelo))),
   carpeta, "04_innovaciones.csv")
  corr <- bj_correlaciones(stats::residuals(salida$modelo))
  bj_csv(corr, carpeta, "05_fac_facp.csv")
  p <- bj_grafico_corr(corr, "Auto.arima condicionado: FAC/FACP residual",
      nota = "Misma arquitectura manual; la eleccion automatica requiere diagnostico.") +
    ggplot2::facet_wrap(~ tipo, ncol = 2)
  bj_figura(p, carpeta, "01_fac_facp.png", alto = 5)
  writeLines(c(
    "Auditor del taller 05B: solo selecciona ordenes estacionarios con arquitectura fijada.",
    "d=0/D=0 en Delta log equivale al d=1/D=0 original, no a eliminar la diferenciacion.",
    "Misma muestra efectiva, regresores, ausencia de deriva y maxima verosimilitud.",
    "Los coeficientes mensuales y de los efectos se reestiman con la dinamica automatica.",
    "AICc/BIC son comparables con los candidatos manuales de 08 bajo estos condicionamientos.",
    "No se escoge automaticamente el principal ni se hace evaluacion fuera de muestra.",
    "No se repite deteccion de outliers ni se modifica la muestra.",
    "Ljung-Box es aproximado tras estimacion, seleccion de efectos y dispersion variable."
  ), file.path(carpeta, "06_alcance.txt"))
  writeLines(capture.output(utils::sessionInfo()), file.path(carpeta, "07_sessionInfo.txt"))
  salida$comparacion <- comparacion
  salida$origen05 <- bloque08$origen05
  salida$regresores <- X
  salida$carpeta <- carpeta
  saveRDS(salida, file.path(carpeta, "08_objeto_08b.rds"))
  cat("\nBLOQUE 08B — AUDITOR AUTOMATICO CONDICIONADO\n")
  print(comparacion, row.names = FALSE, digits = 6)
  cat("\nComprobaciones numericas del auditor:\n")
  print(salida$resumen[, c("matriz_cov_valida", "raiz_AR_minima", "raiz_MA_minima")],
  row.names = FALSE, digits = 6)
  cat("\nCoeficientes del auditor:\n")
  print(salida$coeficientes, row.names = FALSE, digits = 6)
  if (length(salida$avisos)) cat("Avisos:", paste(salida$avisos, collapse = " | "), "\n")
  cat("No se sustituye automaticamente la decision manual.\nResultados en:\n", carpeta, "\n")
  invisible(salida)
}

# ============================================================================
# BLOQUE 09 — REGISTRO Y GUARDADO DE LA DECISION FINAL REVISADA
# No estima modelos ni produce pronosticos. Reutiliza 08 y registra el cierre.
# ============================================================================

ejecutar_bloque_09 <- function(bloque08, bloque08b, bloque01b, bloque06c) {
  principal <- "ARMA21_SAR1"
  contraste <- "ARMA21_SMA1"
  if (length(bloque08$modelos) != nrow(bloque08$especificaciones) ||
      !all(c(principal, contraste) %in% names(bloque08$modelos))) {
    stop("El cierre requiere la comparacion completa de 08, incluidos SAR1 y SMA1 con ARMA21.")
  }
  if (!identical(bloque08$origen05$firma05, bloque06c$origen05$firma05) ||
      !identical(bloque08$origen05$firma05, bloque08b$origen05$firma05)) {
    stop("Los resultados de 06C, 08 y 08B no pertenecen a la misma decision del 05.")
  }
  r06 <- bloque06c$resumen
  if (nrow(r06) != 1L || !is.finite(r06$p_bootstrap_condicional_I1) ||
      !identical(r06$rechazo_boot_condicional_5pct, FALSE)) {
    stop("Cambio el resultado de 06C respecto del cierre revisado: requiere lectura antes de exportar.")
  }
  fechas <- as.Date(bloque08$fechas)
  esperadas <- seq(as.Date("2002-01-01"), as.Date("2025-09-01"), by = "month")
  if (!identical(as.character(fechas), as.character(esperadas))) {
    stop("El cierre revisado corresponde a enero 2002-septiembre 2025.")
  }
  eventos <- bloque08$eventos
  firmas <- paste(as.character(eventos$fecha), eventos$tipo)
  if (!setequal(firmas, c("2006-02-01 TC", "2004-04-01 AO")) || nrow(eventos) != 2L) {
    stop("Las fechas o tipos de efectos difieren de los revisados: no exportar una decision anterior.")
  }

  # Congelar datos concretos para que el RDS no dependa de variables locales
  # referidas por fit$call. No se reestiman coeficientes ni innovaciones.
  empaquetar <- function(id) {
    f <- bloque08$modelos[[id]]
    X <- as.matrix(bloque08$regresores_por_modelo[[id]])
    bj_validar_arma(f, X)
    f$x <- bloque08$serie_diferenciada
    f$xreg <- X
    f$call$xreg <- X
    if ("x" %in% names(f$call)) f$call$x <- bloque08$serie_diferenciada
    if ("y" %in% names(f$call)) f$call$y <- bloque08$serie_diferenciada
    ev <- bj_resumen_eventos(eventos, f, bloque08$umbral)
    diseno <- bj_diseno_efectos(fechas, bloque08$regresores_mensuales,
      ev, f, bloque08$delta_TC)
    if (max(abs(X - diseno$X)) > 1e-6) stop("No se reproduce el diseno de ", id)
    list(candidato = id, modelo = f, especificacion = bj_especificacion_fit(f, id),
      serie_diferenciada = bloque08$serie_diferenciada,
      regresores = X, regresores_mensuales = bloque08$regresores_mensuales,
      perfiles_en_niveles = diseno$G, efectos = ev,
      diagnostico = bj_diag_arma(f, id))
  }
  p <- empaquetar(principal)
  alternativo <- empaquetar(contraste)
  lb <- unname(unlist(p$diagnostico[1L, c("LB12", "LB24", "LB36")], use.names = FALSE))
  if (any(!is.finite(lb)) || any(lb < 0.05)) {
    stop("Cambio el diagnostico residual principal respecto del resultado revisado. Revisar antes de cerrar.")
  }
  a <- bloque08b$resumen
  claves <- c("candidato", "modelo_nivel", "AICc", "BIC", "sigma_innovacion", "LB12", "LB24", "LB36")
  comparacion <- rbind(p$diagnostico[, c("modelo", setdiff(claves, "candidato"))],
    alternativo$diagnostico[, c("modelo", setdiff(claves, "candidato"))])
  names(comparacion)[1L] <- "candidato"
  comparacion <- rbind(comparacion, a[, claves])
  comparacion$papel <- c("Principal decidido", "Contraste anual equivalente", "Auditor condicionado")
  razon <- paste(
    "Decision revisada con los 18 candidatos estimados en 08.",
    "Se mantiene ARMA21+SAR1: ajuste admisible, cuatro parametros dinamicos e innovaciones sin rechazo LB en 12/24/36.",
    "ARMA21+SMA1 queda como contraste: mejora de IC minima, sin una superioridad predictiva demostrada.",
    "Las alternativas ARMA22 mejoran IC pero presentan factores AR/MA casi comunes y proximos al circulo unitario",
    "y rechazo LB a 12 meses; no se eligen como principal.",
    "La eleccion corresponde al desarrollo y diagnostico, no a una competencia predictiva fuera de muestra."
  )
  decision <- data.frame(candidato = principal, modelo_nivel = p$especificacion$modelo_nivel,
    inicio = min(fechas), corte = max(fechas), n_niveles = length(fechas),
    n_diferencias = length(p$serie_diferenciada), d = 1L, D = 0L,
    deriva = FALSE, contrastes_mensuales = ncol(p$regresores_mensuales),
    n_efectos = nrow(p$efectos), cambio_trayectoria_incorporado = FALSE,
    seleccion_modelado_cerrada = TRUE, validacion_predictiva_realizada = FALSE,
    fundamento = razon, stringsAsFactors = FALSE)
  cf <- stats::coef(p$modelo)
  se <- sqrt(diag(p$modelo$var.coef))
  parametros <- data.frame(termino = names(cf), estimacion = unname(cf),
    se_condicional = unname(se), limite_95_inferior = unname(cf - 1.96 * se),
    limite_95_superior = unname(cf + 1.96 * se))
  carpeta <- file.path(dirname(bloque08$carpeta), "09_cierre_modelado")
  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
  notas <- c(
    razon,
    "x es log(remision_litros/dias_mes), una observacion por mes.",
    "El objeto ARMA se estimo sobre diff(x), con d=0 y D=0 internos: equivale a d=1 y D=0 originales.",
    "Los once contrastes mensuales describen cambios estacionales en diff(x); no confundirlos con efectos en niveles.",
    "Los perfiles TC/AO se definen en niveles y sus primeras diferencias se incluyen como regresores.",
    "TC usa delta=0.7 y decae desde febrero 2006; AO afecta abril 2004. Los datos observados no se sustituyen.",
    "No se incorpora cambio de trayectoria de 2011-2013: 06C no rechazo bajo su calibracion I(1) condicional.",
    "Ese resultado no demuestra estabilidad y depende del simulador nulo estimado.",
    "Ljung-Box no rechaza en los tres horizontes, pero no demuestra independencia ni varianza constante.",
    "Se conserva como limitacion la mayor dispersion residual del tramo temprano.",
    "Intervalos de coeficientes condicionales y aproximados tras seleccionar ordenes, fechas y tipos de outliers.",
    "No se repite deteccion ni se ajusta otro modelo en 09. Los 18 candidatos quedan en los resultados de 08.",
    "No se leyo el periodo posterior a septiembre 2025 ni se generaron pronosticos.",
    "La evaluacion predictiva y sus comparaciones con benchmarks pertenecen a la siguiente etapa del proyecto.",
    "Al pronosticar habra que construir regresores futuros, acumular diferencias y volver a litros respetando dias del mes.",
    "No interpretar exp(pronostico log) automaticamente como media predictiva en litros.",
    "La referencia auto inicial tiene arquitectura libre y no se mezcla con estos modelos en un ranking por IC."
  )
  salida <- list(
    version_cierre = 1L, fecha_ejecucion = Sys.time(),
    decision = decision, modelo_seleccionado = principal,
    modelo_principal = p$modelo, principal = p, contraste = alternativo,
    comparacion = comparacion, coeficientes = parametros,
    efectos = p$efectos, fechas = fechas, serie_log = bloque08$serie_log,
    serie_diferenciada = p$serie_diferenciada, regresores = p$regresores,
    transformacion = list(definicion = "log(remision_litros/dias_mes)",
      frecuencia = 12L, d_original = 1L, D_original = 0L, deriva = FALSE,
      primer_log = bloque08$serie_log[1L], ultimo_log = tail(bloque08$serie_log, 1L),
      delta_TC = bloque08$delta_TC, C = bloque08$umbral),
    origen05 = bloque08$origen05, cambio_estructural = r06,
    auto_condicionado = bloque08b, auto_inicial_libre = bloque01b,
    seleccion_modelado_cerrada = TRUE, validacion_predictiva_realizada = FALSE,
    notas = notas, carpeta = carpeta)
  bj_csv(decision, carpeta, "01_decision_final.csv")
  bj_csv(comparacion, carpeta, "02_principal_contraste_auto.csv")
  bj_csv(parametros, carpeta, "03_coeficientes_principal.csv")
  bj_csv(p$efectos, carpeta, "04_efectos_principal.csv")
  bj_csv(data.frame(fecha = fechas[-1L], innovacion = as.numeric(stats::residuals(p$modelo))),
    carpeta, "05_innovaciones_principal.csv")
  bj_csv(data.frame(fecha = fechas[-1L], p$regresores, check.names = FALSE),
    carpeta, "06_regresores_principal.csv")
  bj_csv(r06, carpeta, "07_resultado_cambio_estructural.csv")
  bj_csv(p$diagnostico, carpeta, "08_diagnostico_principal.csv")
  writeLines(notas, file.path(carpeta, "09_decision_y_limites.txt"))
  writeLines(capture.output(utils::sessionInfo()), file.path(carpeta, "10_sessionInfo.txt"))
  saveRDS(salida, file.path(carpeta, "11_objeto_bloque09.rds"))
  cat("\nBLOQUE 09 — SELECCION DE MODELADO CERRADA\n")
  print(decision[, setdiff(names(decision), "fundamento")], row.names = FALSE)
  print(comparacion, row.names = FALSE, digits = 6)
  cat("Se guardaron modelos, datos de desarrollo, regresores, efectos y decision.\n")
  cat("Sin nuevas estimaciones ni pronosticos. Evaluacion predictiva pendiente.\n")
  cat("Resultados en:\n", carpeta, "\n")
  invisible(salida)
}


# ============================================================================
# EJECUCION POR BLOQUES Y DEPENDENCIAS
# El recorrido completo se ejecuta al final, una vez definidas las funciones.
# ============================================================================

ejecutar_bloques_06 <- function(ids = "01", entorno = .GlobalEnv) {
  mapa <- list(
    "01" = character(), "01B" = "bloque01", "02A" = "bloque01", "02B" = "bloque01",
    "03" = "bloque01", "04" = "bloque01", "04B" = "bloque04", "05" = "bloque04",
    "06" = c("bloque01", "bloque05"), "06B" = c("bloque01", "bloque05"), "06C" = "bloque06b",
    "07" = c("bloque01", "bloque05"), "07B" = "bloque07", "07C" = "bloque07b",
    "08" = c("bloque07c", "bloque05"), "08B" = "bloque08",
    "09" = c("bloque08", "bloque08b", "bloque01b", "bloque06c")
  )
  ids <- toupper(as.character(ids))
  if (!length(ids) || any(!ids %in% names(mapa))) stop("Identificador de bloque no valido.")
  for (id in ids) {
    dependencias <- mapa[[id]]
    faltan <- dependencias[!vapply(dependencias, exists, logical(1), envir = entorno, inherits = FALSE)]
    if (length(faltan)) stop("Para ", id, " faltan objetos: ", paste(faltan, collapse = ", "),
          ". Ejecutar su bloque previo o recuperar su RDS.")
    args <- if (length(dependencias)) mget(dependencias, envir = entorno, inherits = FALSE) else list()
    if (any(vapply(args, is.function, logical(1)))) {
      stop("Una dependencia contiene una funcion, no resultados: revisar su ejecucion.")
    }
    nombre_funcion <- paste0("ejecutar_bloque_", tolower(id))
    resultado <- do.call(get(nombre_funcion, mode = "function"), args)
    assign(paste0("bloque", tolower(id)), resultado, envir = entorno)
  }
  invisible(TRUE)
}

# ============================================================================
# EJECUCION CON source(): RECORRIDO COMPLETO HASTA 09
# ============================================================================
# El cierre 09 reutiliza los resultados y registra la decision revisada con el usuario.
cat("\nSCRIPT 06 — EJECUCION COMPLETA DESDE 01 HASTA 09\n")
ejecutar_bloques_06(c(
  "01", "01B", "02A", "02B", "03", "04", "04B", "05",
  "06", "06B", "06C", "07", "07B", "07C", "08", "08B", "09"
))
cat("\nSCRIPT 06 — MODELADO CERRADO; EVALUACION PREDICTIVA PENDIENTE\n")
