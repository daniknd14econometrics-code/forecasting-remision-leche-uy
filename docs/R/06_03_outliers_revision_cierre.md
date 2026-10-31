# Script 06 — Outliers, revisión final y cierre (07–09)

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
| 07 | Detección secuencial y reestimación conjunta de outliers | 3686–3867 |
| 08 | Revisión final de órdenes con los efectos ya incorporados | 3868–4198 |
| 08B | Auditor automático condicionado | 4199–4266 |
| 09 | Registro y guardado de la decisión final | 4267–4411 |
| Ejecución | Ejecutor y recorrido completo con source() | 4412–4453 |

## 07 — Detección secuencial y reestimación conjunta de outliers

Los tres bloques usan realmente el modelo elegido en 05. No se reutilizan las firmas detectadas bajo el antiguo SAR1 sin parte regular. El umbral es `C=3.5`, la persistencia TC `delta=0.7` y el máximo operativo de efectos es ocho.

| Tipo | Perfil en el logaritmo en niveles | Interpretación condicional |
|---|---|---|
| AO | Un impulso en una fecha | Desviación puntual de esa observación. |
| LS | Un escalón desde una fecha | Desplazamiento permanente de nivel. |
| TC | `delta^h` desde una fecha | Impacto que se disipa geométricamente. |
| IO | Respuesta acumulada de toda la dinámica ARMA | Innovación extraordinaria que se propaga por el modelo. |

Como el ajuste se hace sobre `diff(x)`, se diferencian esos perfiles antes de agregarlos como regresores. Un AO en niveles no es un único impulso en la diferencia: produce dos contribuciones de signos opuestos. Un LS en niveles se vuelve un impulso en diferencias. No se aplican perfiles propios de un ARMA sin integración ignorando `d=1`.

El scan construye el operador lineal de innovaciones filtrando vectores base. Comprueba que al aplicarlo al componente descontado de meses y efectos reproduce las innovaciones del ajuste. Para cada perfil filtrado `z` obtiene `omega=(z'e)/(z'z)`, error condicional proporcional a `sigma/sqrt(z'z)` y `lambda=omega/se`. Las distintas firmas de una misma fecha son explicaciones alternativas, no eventos para incorporar simultáneamente por haber superado el umbral.

**07** realiza solo la primera búsqueda. **07B** incorpora el máximo admisible y reestima conjuntamente. **07C** vuelve a buscar, incorpora de uno en uno y se detiene si el máximo restante no supera C, hay una situación que requiere revisión o se alcanza el límite. Las fechas ya modeladas se excluyen de nuevas incorporaciones; siguen en las tablas para diagnóstico. Se registran proximidad a extremos, empates, historial, avisos y amplitudes conjuntas. No se borran observaciones ni se reemplaza la serie original.

`bj_continuar_deteccion()` controla ese ciclo. `bj_resumen_eventos()` actualiza amplitudes, errores y razones z. `bj_exportar_outliers()` conserva diagnóstico, scan completo, ranking por fecha, historia, coeficientes, dispersión, figuras y RDS. La ausencia de más firmas sobre C es una regla de parada condicional al modelo y la escala elegidos, no una probabilidad familiar de error del 5%.

Con la nueva base se incorpora **TC febrero 2006**, no el LS de la corrida antigua, y **AO abril 2004**. Después de ambos efectos, el máximo restante es TC mayo 2003 con |lambda|=3.2548, por debajo de 3.5. Los efectos conjuntos quedan aproximadamente 0.161932 y −0.110384; los tres Ljung–Box pasan a no rechazar. Que los errores estándar sean condicionales exige no interpretarlos como si las fechas y tipos hubieran sido fijados antes de observar los datos.

La menor dispersión después de incorporar eventos no elimina toda la mayor volatilidad temprana. El análisis no convierte automáticamente cada diferencia de varianza en un outlier ni cambia el umbral según el tramo.

**Funciones de este tramo:** `bj_resumen_eventos`, `bj_exportar_outliers`, `bj_continuar_deteccion`, `ejecutar_bloque_07`, `ejecutar_bloque_07b`, `ejecutar_bloque_07c`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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


```

</details>

## 08 — Revisión final de órdenes con los efectos ya incorporados

**Entradas:** `bloque07c` y `bloque05`. Primero se exige la misma firma de origen; se verifica calendario, `diff(x)`, frecuencia, rango y diseño. Se reproduce el filtro de la referencia heredada para evitar cambiar silenciosamente la representación.

Se repiten los 18 candidatos manteniendo muestra, meses, ausencia de deriva y las fechas/tipos de 07C. El ARMA21+SAR1 heredado se reutiliza; los otros 17 se reestiman conjuntamente con efectos y meses, con varios inicios. Si hubiese IO, su perfil se actualiza con cada dinámica. Esto responde a la pregunta pertinente: después de descontar efectos, ¿siguen justificados los órdenes regulares anteriores?

El manejador `tryCatch()` devuelve un elemento `error` solo si falla. **Se extrae con `nuevo[["error", exact=TRUE]]`**. Usar `nuevo$error` permitiría coincidencia parcial con `error_perfil_IO=0`, confundiría el éxito con un fallo y descartaría todas las alternativas. La versión corregida evita esa ambigüedad. Se detiene si no se compararon alternativas; 09 exige además que la comparación prevista esté completa.

Para cada candidato se guarda precisión, raíces de los polinomios completos, distancias entre raíces regulares AR/MA, correlación estimada ar1/ma1, AICc/BIC, RMS, Ljung–Box, FAC/FACP, residuos, QQ y dispersión por tramos. Las distancias se interpretan junto con las raíces, sin un umbral universal que convierta un ajuste automáticamente en bueno o malo. Una matriz válida y convergencia tampoco descartan casi cancelación.

Se sigue la firma histórica TC mayo 2003 sin agregarla. En todos los modelos queda por debajo de C. Se guardan además todos los coeficientes, no solo los que parecían significativos.

| Candidato | AICc observado | BIC observado | LB12 / LB24 / LB36 |
|---|---:|---:|---|
| ARMA21+SAR1 | −991.986 | −928.886 | 0.413 / 0.246 / 0.385 |
| ARMA21+SMA1 | −992.051 | −928.951 | 0.334 / 0.210 / 0.315 |
| ARMA12+SAR1 | −990.590 | −927.490 | 0.260 / 0.223 / 0.328 |
| ARMA22+SMA1 | −1000.005 | −933.553 | 0.036 / 0.134 / 0.414 |

Los ARMA22 mejoran ambos IC, pero tienen raíces AR y MA de módulo aproximadamente 1.0002 y 1.00002, factores casi comunes, y conservan rechazo en LB12. La decisión revisada mantiene ARMA21+SAR1 como principal; el equivalente SMA1 queda como contraste prácticamente empatado (diferencia AICc≈0.065). No se interpreta ese empate como superioridad predictiva. Los AR/MA más simples también se evaluaron; no se omitieron porque una barra inicial fuera pequeña.

El estado “decisión pendiente” impreso aquí pertenece a la comparación anterior al cierre: el bloque no escoge automáticamente. 09 registra la decisión revisada. No se informa aprobación plena de independencia ni de homocedasticidad; se cierra la búsqueda dentro de la arquitectura y muestra estudiadas.

**Funciones de este tramo:** `ejecutar_bloque_08`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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


```

</details>

## 08B — Auditor automático condicionado

La función automática recibe exactamente la primera diferencia y los regresores del análisis manual, con `d=0,D=0` internos, `stationary=TRUE`, sin media ni deriva. Eso equivale al `d=1,D=0` original, no a una nueva decisión de integración. Usa ML, AICc, búsqueda no stepwise ni aproximada y los límites ya declarados en 01B.

La búsqueda del auditor permite `P` y `Q` hasta uno, sujetos al límite de orden total; por eso no se afirma que su espacio coincida exactamente con las 18 alternativas manuales. Se controla la arquitectura y se comparan resultados. Si existieran perfiles IO, se actualizan al cambiar los órdenes; no es necesario para los efectos TC y AO de esta corrida.

El auditor elige ARMA21+SMA1, reproduce el ajuste manual equivalente y queda prácticamente empatado con el principal SAR1. Este acuerdo ofrece una referencia adicional de búsqueda/estimación; no sustituye el análisis manual ni añade información fuera de muestra. Los IC pueden compararse con los de 08 porque se mantienen transformación, muestra, ML y regresores pertinentes. No se mezclan con el auto inicial libre si difieren esas condiciones.

La sigma informada vuelve a ser RMS de las innovaciones. El `sigma2` propio del paquete `forecast` puede usar otra corrección; emplear una convención explícita evita atribuir al modelo una diferencia que solo procede del denominador de la varianza.

**Funciones de este tramo:** `ejecutar_bloque_08b`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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

```

</details>

## 09 — Registro y guardado de la decisión final

Este bloque **no estima candidatos, no repite el scan y no genera pronósticos**. Registra la elección revisada con el usuario y guarda los objetos necesarios para la siguiente etapa.

1. Exige comparación completa en 08, presencia de principal y contraste, la misma firma de origen en 06C/08/08B y el resultado no rechazado de 06C. Si el resultado cambia, detiene la exportación en vez de presentar una decisión antigua como si se hubiera vuelto a revisar.
2. Verifica el calendario y que los efectos sean los revisados: TC febrero 2006 y AO abril 2004. No elige eventos nuevos en esta etapa.
3. `empaquetar()` toma el ajuste ya estimado, valida su diseño, guarda datos concretos en la llamada y reproduce perfiles y regresores. Esto facilita recuperar el objeto sin variables temporales de otra función.
4. Revisa que el principal conserve el diagnóstico residual leído y construye una tabla de principal, contraste y auditor. No escoge el menor AICc automáticamente.
5. Guarda decisión, coeficientes e intervalos condicionales, efectos, innovaciones, regresores, resultado estructural, límites e información de sesión. El RDS contiene también los ajustes de contraste y las referencias automáticas, la serie de desarrollo, transformación y origen.

| Archivo de `09_cierre_modelado/` | Contenido |
|---|---|
| `01_decision_final.csv` | Especificación principal, muestra, diferenciación, determinísticos, efectos y fundamento. |
| `02_principal_contraste_auto.csv` | Comparación que acompaña la decisión. |
| `03_coeficientes_principal.csv` | Estimaciones e incertidumbre condicional aproximada. |
| `04_efectos_principal.csv` | Fechas, tipos, amplitudes y diagnóstico de los efectos elegidos. |
| `05_innovaciones_principal.csv` | Innovaciones fechadas del principal. |
| `06_regresores_principal.csv` | Once contrastes y diferencias de los perfiles TC/AO. |
| `07_resultado_cambio_estructural.csv` | Resultado condicional de 06C, sin confundirlo con prueba de estabilidad. |
| `08_diagnostico_principal.csv` | IC, raíces, sigma y Ljung–Box. |
| `09_decision_y_limites.txt`, `10_sessionInfo.txt` | Decisión, alcance y entorno de ejecución. |
| `11_objeto_bloque09.rds` | Conjunto recuperable mediante `readRDS()`, con principal, contraste, datos y metadatos. |

`seleccion_modelado_cerrada=TRUE` significa que terminó esta selección sobre desarrollo. `validacion_predictiva_realizada=FALSE` impide confundir ese cierre con haber demostrado el mejor pronóstico. La mayor dispersión temprana, la selección previa de fechas y los límites de 06C permanecen explícitos.

El objeto principal es un ARMA sobre diferencias. En la futura etapa predictiva habrá que construir regresores futuros, acumular diferencias para volver al logaritmo en niveles y recuperar litros considerando días del mes y el estimando deseado. `exp()` de un pronóstico logarítmico no es automáticamente la media predictiva en litros.

**Funciones de este tramo:** `ejecutar_bloque_09`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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


```

</details>

## Ejecución — Ejecutor y recorrido completo con source()

El mapa declara las dependencias reales. `mget()` recupera los objetos necesarios del entorno, `do.call()` llama a la función y `assign()` guarda su resultado con nombre `bloqueXX`. `inherits=FALSE` impide tomar por accidente una variable homónima de otro entorno. Se rechaza una dependencia que contenga una función en vez de resultados.

`source("R/06_modelar_evaluar_sarima.R")` define todo y ejecuta el recorrido completo desde 01 hasta 09. No se carga silenciosamente un RDS antiguo ni se restringe `source()` a 08/08B. La ejecución parcial sigue disponible con `ejecutar_bloques_06(c("..."))` cuando las dependencias ya existen y corresponden a la corrida actual.

Para recuperar un cierre guardado en otra sesión:

```r
cierre <- readRDS("outputs/sarima_box_jenkins/09_cierre_modelado/11_objeto_bloque09.rds")
cierre$decision
cierre$principal$diagnostico
```

No hay que ejecutar `source()` solo para leer ese RDS: `source()` vuelve a recorrer el análisis completo. Al cerrar esta fase no se modifica la muestra reservada ni se inicia la evaluación predictiva.

**Funciones de este tramo:** `ejecutar_bloques_06`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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
```

</details>

## Qué queda cerrado y qué sigue

La selección del modelo de desarrollo queda cerrada: ARMA21+SAR1 como principal, ARMA21+SMA1 como contraste, TC febrero 2006 y AO abril 2004, sin deriva ni cambio determinístico de trayectoria incorporado. La muestra completa se conserva. Los gráficos y tablas de 08 documentan las alternativas; 09 conserva la decisión y los objetos.

Queda pendiente comprobar la ejecución de 09 en RStudio, registrar el entorno reproducible y sincronizar estos archivos con el repositorio local y GitHub. La evaluación predictiva no se inició en este cierre. Solo después de documentación y sincronización se revisará la situación global y la siguiente etapa del proyecto.

La longitud del script responde a preguntas diferentes: 03 identifica; 04 compara referencias y deriva; 04B describe residuos; 05 amplía antes de intervenciones; 06 estudia trayectoria; 07 busca efectos; 08 revisa órdenes con efectos; 08B audita automáticamente; 09 registra. 01B y 08B tampoco son duplicados: el primero es libre y el segundo condicionado. Las utilidades compartidas evitan repetir cálculos; no se eliminó evidencia relevante solo para acortar el archivo.
