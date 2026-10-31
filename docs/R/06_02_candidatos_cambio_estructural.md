# Script 06 — Candidatos y cambio estructural (04–06C)

## Cómo usar esta documentación

Este documento acompaña `R/06_modelar_evaluar_sarima.R`. La numeración 01–09 identifica **bloques internos de ese script**, no otros archivos `R/01...R`, `R/02...R`, etc. Los tres documentos respetan el orden del código y reproducen íntegramente sus tramos correspondientes, sin omitir funciones sustantivas. El código se incluye para estudiar; para ejecutar se utiliza el `.R` completo, no los trozos Markdown de forma aislada.

**Desarrollo:** enero de 2002 a septiembre de 2025, 285 niveles y 284 primeras diferencias. **Variable:** logaritmo del promedio diario de remisión de cada mes, `x_t=log(litros_t/dias_t)`. **Arquitectura final:** d=1, D=0, sin deriva; once contrastes mensuales sobre diferencias y dos efectos definidos en niveles. La muestra posterior no participa en la selección.

La representación final es `Delta x_t = beta'M_t + omega_TC Delta TC_t + omega_AO Delta AO_t + u_t`, con `(1-phi1 L-phi2 L²)(1-Phi L^12)u_t=(1+theta1 L)e_t`. En R se ajusta un ARMA sobre `Delta x` con d=D=0 internos. Diferenciar dos veces por interpretar otra vez la etiqueta original sería un error.

Los números descritos corresponden a las salidas aportadas por el usuario en RStudio. La versión añadida de 09 reutiliza esos ajustes: su ejecución en RStudio todavía debe comprobarse. La revisión local del archivo verificó sintaxis R y conservación de los bloques anteriores; no constituye una nueva ejecución estadística del recorrido.

Las referencias metodológicas del usuario son el capítulo de procesos ARMA, el de modelización ARIMA/SARIMA, el de outliers y los talleres 04B/05B. El bootstrap 06C es una extensión autorizada y se describe como aproximación condicional; no se atribuye literalmente al taller. No se incorporaron nuevas pruebas para redactar estos documentos.

**Documentos:** [1. Preparación, integración e identificación (00–03)](06_01_preparacion_identificacion.md) · [2. Candidatos y cambio estructural (04–06C)](06_02_candidatos_cambio_estructural.md) · [3. Outliers, revisión final y cierre (07–09)](06_03_outliers_revision_cierre.md)

**Versión de código documentada (SHA-256):** `c4e03b150a14bbdc8b77d2eb32b471ea07158ff17fed984a0d15d17f08b1e4e5`.

## Mapa del tramo

| Bloque | Tema | Líneas del script |
|---|---|---|
| 04 | Primeros candidatos y evaluación de deriva | 1649–1967 |
| 04B | Revisión residual por tramos y auxiliares de comparación | 1968–2277 |
| 05 | Ampliación regular y elección de base provisional | 2278–2809 |
| 06 | Cambio de trayectoria: búsqueda descriptiva de fecha desconocida | 2810–3223 |
| 06B | SupF convencional del taller | 3224–3438 |
| 06C | Calibración bootstrap condicional y conexión con 05 | 3439–3685 |

## 04 — Primeros candidatos y evaluación de deriva

Se estima sobre `diff(x)` con frecuencia 12. Once contrastes de suma cero representan los meses: cada mes de enero a noviembre tiene su columna y diciembre toma −1 en las once columnas. Esto evita confundir un perfil anual estable con una constante global.

Se comparan seis ajustes: referencia sin ARMA, SAR1 y SMA1, cada uno con y sin deriva. `include.mean=TRUE` sobre la primera diferencia permite una media que representa crecimiento medio mensual; `FALSE` lo fija en cero. No hay un término de deriva obligatorio en todo ARMA o SARIMA: es un componente determinístico cuya interpretación depende de la diferenciación y de la parametrización.

Los criterios se calculan sobre la misma variable, muestra y ML. Se guardan convergencia, matriz de covarianzas, raíces, parámetros y residuos. Las raíces se comparan en la parte estacionaria; que haya `d=1` en niveles no exige una raíz AR de módulo uno en la diferencia.

**Lectura que motivó continuar:** la deriva no aportaba una mejora defendible; los modelos anuales mejoraban la referencia, pero conservaban dependencia residual. Por eso se continúa sin deriva y se amplía la parte regular. Este bloque es una primera comparación, no la selección final.

**Funciones de este tramo:** `ejecutar_bloque_04`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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


```

</details>

## 04B — Revisión residual por tramos y auxiliares de comparación

El bloque usa SAR1 y SMA1 sin deriva como referencias históricas del 04. Divide los residuos en 2002–2009, 2010–2017 y 2018–2025, resume medias y desviaciones, y genera FAC/FACP globales y por tramos. Los tramos son descriptivos: no constituyen fechas de quiebre estimadas ni nuevas muestras de entrenamiento.

La mayor dispersión temprana y los patrones residuales justifican investigar; no identifican por sí solos un cambio de nivel, de pendiente o de varianza. Que los patrones por tramos no sean idénticos exige prudencia con una sola dinámica, pero no permite recortar la serie por intuición.

Después de la función 04B aparecen tres utilidades utilizadas en 05 y 08:

| Función | Funcionamiento |
|---|---|
| `bj_candidatos_ordenes` | Construye las nueve configuraciones regulares cruzadas con SAR1/SMA1; asigna nombres, órdenes y etapa. La lista explícita evita omisiones y hace reproducible la comparación. |
| `bj_estimar_candidato` | Prueba valores iniciales distintos, recoge convergencia, logLik, errores y advertencias, y conserva el mejor ajuste convergente. Un intento no equivale a un candidato adicional. |
| `bj_revision_ordenes` | Alinea diagnósticos y especificaciones con `match`, calcula mejoras de AICc/BIC frente a cada referencia anual y cuenta rechazos de Ljung–Box. Informa el estado; no escoge automáticamente el ganador. |

La grilla regular es `(0,0),(1,0),(2,0),(0,1),(0,2),(1,1),(2,1),(1,2),(2,2)`: 18 candidatos al cruzarla con las dos estructuras anuales. Es una revisión acotada para este caso, no un mandato universal de Box–Jenkins ni una competencia de pronósticos. La admisibilidad numérica tampoco garantiza una especificación estable o bien identificada cerca del círculo unitario.

**Funciones de este tramo:** `ejecutar_bloque_04b`, `bj_candidatos_ordenes`, `bj_estimar_candidato`, `bj_revision_ordenes`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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


```

</details>

## 05 — Ampliación regular y elección de base provisional

**Entrada:** los ajustes de 04; **salida:** `bloque05` con los 18 candidatos y una decisión explícita de base provisional. La revisión de 04B orienta la lectura pero el ejecutor no la pasa como argumento, porque los datos necesarios ya están en 04.

La revisión recorre AR(1), AR(2), MA(1), MA(2) y las cuatro combinaciones mixtas, siempre frente a referencias SAR1/SMA1 y manteniendo `d=1,D=0`, meses y ausencia de deriva. Antes de los outliers se fija **ARMA21+SAR1** para que el estudio posterior no siga usando la antigua referencia anual sin parte regular.

Se comparan ML, AICc, BIC, RMS de innovaciones, precisión, convergencia, raíces y FAC/FACP. En estos criterios `k` incluye coeficientes dinámicos, regresores y varianza; con `n` observaciones y logLik `ell`, `AICc=-2ell+2k+2k(k+1)/(n-k-1)` y `BIC=-2ell+k log(n)`. La sigma mostrada es `sqrt(mean(e^2))` para mantener una convención común con `forecast`; no se compara sin aclaración con una varianza corregida por grados de libertad.

`bj_registrar_decision_05()` registra la elección revisada, no calcula un ganador automático por menor AICc. La base mejoraba la dependencia y el AICc respecto de SAR1, pero aún presentaba rechazo residual en algunos horizontes: sigue siendo provisional para 06/07. Los ARMA22 con factores casi comunes y raíces muy próximas al círculo unitario no se eligen únicamente por mejores IC.

La decisión incluye una firma construida con nombre, órdenes y coeficientes a precisión alta. `bj_contexto_05()` y las verificaciones siguientes impiden mezclar efectos de la antigua base SAR1 con la nueva base ARMA21. La firma identifica el ajuste de origen; no pretende ser una prueba estadística.

| Utilidades definidas aquí | Papel en la continuación |
|---|---|
| `bj_dinamicos`, `bj_especificacion_fit` | Extraen coeficientes dinámicos y traducen `fit$arma` a órdenes y etiqueta en niveles. Internamente se estima d=0 sobre la serie ya diferenciada. |
| `bj_validar_arma` | Comprueba convergencia, parámetros y covarianzas finitos, positividad de la covarianza con Cholesky, raíces admisibles y correspondencia exacta de regresores. |
| `bj_firma_05`, `bj_registrar_decision_05`, `bj_contexto_05` | Fijan, guardan y verifican la base elegida. El RDS permite recuperar esa decisión sin reconstruirla a mano. |
| `bj_filtrar_fijo` | Obtiene innovaciones con parámetros dinámicos fijados mediante el filtro ARMA de `stats::arima`. Se usa también para los perfiles de intervención. |
| `bj_pol_arma` | Multiplica factores regulares y estacionales; un IO debe usar toda la dinámica, no solo el término anual. |
| `bj_perfil_arma`, `bj_eventos_vacios`, `bj_diseno_efectos` | Definen perfiles AO/LS/TC/IO en niveles y agregan sus diferencias a los meses. Permiten cero o varios efectos. |
| `bj_scan_arma` | Filtra todos los perfiles con parámetros fijos, estima amplitudes condicionales y ordena firmas por valor absoluto; comprueba que el filtro reproduce las innovaciones. |
| `bj_reestimar_eventos` | Reestima conjuntamente dinámica, meses y efectos; actualiza el perfil IO, si existe, hasta cinco veces y verifica su convergencia. |
| `bj_diag_arma` | Produce un resumen comparable de IC, raíces, RMS y Ljung–Box con `fitdf=p+q+P+Q`. |

Varias utilidades de outliers se definen antes de 05 por organización del código, pero la detección no se ejecuta hasta 07. No deben confundirse definición y ejecución. Los resultados de 05 no incorporan intervenciones del futuro ni efectos elegidos en 07.

**Funciones de este tramo:** `bj_dinamicos`, `bj_especificacion_fit`, `bj_validar_arma`, `bj_firma_05`, `bj_registrar_decision_05`, `bj_contexto_05`, `bj_filtrar_fijo`, `bj_pol_arma`, `bj_perfil_arma`, `bj_eventos_vacios`, `bj_diseno_efectos`, `bj_scan_arma`, `bj_reestimar_eventos`, `bj_diag_arma`, `ejecutar_bloque_05`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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


```

</details>

## 06 — Cambio de trayectoria: búsqueda descriptiva de fecha desconocida

La pregunta es si cambia el nivel, la pendiente o ambos en alguna fecha interior de la muestra completa. No es una prueba de raíz unitaria frente a estacionariedad con quiebre y no decide `d`.

Se compara una trayectoria sin quiebre con tres formas: desplazamiento de nivel, cambio continuo de pendiente y ambos. Para cada fecha candidata se construyen los indicadores correspondientes, se estima la regresión, se guarda SSR y se elige el mínimo. El recorte `trim=0.15` evita buscar cambios demasiado cerca de los extremos. Los efectos mensuales se mantienen en esta exploración descriptiva.

Un indicador `DU_t=1(t>=T)` permite un salto; una rampa que empieza en cero en la primera fecha posterior permite un cambio continuo de pendiente. Usar otra convención desplaza el intercepto de la parametrización: por eso el script informa **primera observación posterior**, no una fecha sin definición.

Se guardan fechas, perfiles de SSR, magnitudes, trayectoria ajustada y residuos. La reducción de SSR mide ajuste dentro de muestra; no es evidencia estadística suficiente tras buscar la fecha. Los coeficientes posteriores a esa búsqueda se leen descriptivamente.

La evidencia observada sitúa el nivel en octubre de 2010, la pendiente en mayo de 2013 y ambos en abril de 2011. Las fechas difieren porque son formas distintas; no prueban tres cambios ni identifican una causa tecnológica. No se fija 2013 de antemano ni se recorta la muestra.

**Funciones de este tramo:** `ejecutar_bloque_06_trayectoria`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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


```

</details>

## 06B — SupF convencional del taller

`ejecutar_bloque_06b_trayectoria()` aplica el SupF convencional sobre `x ~ t`, con constante y tendencia, **sin indicadores mensuales en esa regresión**. Reproduce la formulación convencional del taller, distinta de la exploración mensual de 06.

`strucchange::Fstats()` calcula la secuencia de estadísticas para las fechas permitidas; `sctest(...,type="supF")` compara su máximo con la distribución convencional. Se identifica la última fecha previa y la primera posterior al máximo, se registra el perfil entero y se inspeccionan los residuos con y sin el quiebre candidato.

En la ejecución observada: SupF=73.7206, crítico convencional al 5%=11.5527, p convencional aproximadamente 2.896e−15 y primera fecha posterior junio de 2011. El rechazo conjunto no demuestra que cambien ambos coeficientes; evalúa la estabilidad de la regresión en conjunto.

La persistencia e integración de la serie, junto con el fuerte patrón residual, impiden interpretar ese p convencional como una medida calibrada para nuestra representación I(1). No sabemos corregirlo multiplicándolo por un factor ni afirmar una dirección universal de sesgo. 06B conserva una comparación convencional transparente; 06C estudia el mismo estadístico bajo una representación nula explícita.

**Funciones de este tramo:** `ejecutar_bloque_06b_trayectoria`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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


```

</details>

## 06C — Calibración bootstrap condicional y conexión con 05

Esta extensión fue autorizada explícitamente. Es una **calibración aproximada condicionada a un simulador I(1)**, no una prueba robusta simultáneamente a I(0)/I(1), ni una reproducción literal de un algoritmo del taller.

1. Recupera el modelo sin quiebre y las mismas fechas de 06B. Calcula eficientemente el perfil SupF y verifica que reproduce el perfil del paquete, no solo su máximo.
2. Ajusta bajo la nula una representación de las diferencias con meses estables y AR auxiliar. Compara órdenes hasta 24 por AIC en muestra común. En la ejecución revisada elige AR(22), que no se traslada al SARIMA.
3. Centra y escala las innovaciones del simulador y las multiplica por normales independientes de media cero y varianza uno. Así la varianza condicional de cada innovación simulada conserva el cuadrado de la innovación de esa fecha. Esto no exige normalidad original, pero sí supone que este esquema y el AR representan suficientemente la nula.
4. Conserva el primer nivel y las primeras diferencias necesarias como condiciones iniciales, simula recursivamente las demás diferencias y acumula para obtener niveles I(1), sin quiebre determinístico.
5. En cada una de 999 réplicas vuelve a buscar el máximo entre las mismas fechas. El orden y los coeficientes del simulador se mantienen fijos. No fija la fecha observada como si fuera conocida.
6. Calcula el p de cola derecha con corrección `(1+numero de replicas >= observado)/(B+1)`, el percentil 95% y el error Monte Carlo aproximado. Las fechas simuladas bajo la nula no son un intervalo de confianza de una fecha de quiebre.

Resultado revisado: p=0.164; crítico=121.832 frente a SupF=73.7206; error Monte Carlo≈0.0117. No está cerca del umbral 0.05. La decisión operativa es continuar sin incorporar un cambio determinístico de trayectoria. Esto **no demuestra ausencia de cambios**, no decide la raíz regular y no prueba estabilidad de varianza o de parámetros ARMA.

Al final se definen los envoltorios `ejecutar_bloque_06`, `06b` y `06c`, más `bj_muestra_05` y `bj_guardar_contexto_06`. Comprueban que los datos y la firma de 05 corresponden al recorrido actual y guardan ese contexto. **El contraste no usa ARMA21+SAR1 como su proceso de errores**: conserva la regresión de trayectoria y su propio simulador nulo AR(22). Heredar la decisión de 05 aquí significa mantener trazabilidad, no sustituir el simulador por el modelo del forecast.

**Funciones de este tramo:** `ejecutar_bloque_06c_trayectoria`, `bj_muestra_05`, `bj_guardar_contexto_06`, `ejecutar_bloque_06`, `ejecutar_bloque_06b`, `ejecutar_bloque_06c`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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


```

</details>
