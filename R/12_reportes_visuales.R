# ============================================================================
# SCRIPT 12 — PRESENTACION PUBLICA, SIN ESTIMAR NI MODIFICAR PRONOSTICOS
# Lo cargan 10/11. HTML y SVG autonomos: sin paquetes, CDN ni servicios nuevos.
# Documentacion publica: docs/REPORTE_VISUAL.md.
# Guia de estudio: se entrega separada para conservarla fuera del repositorio.
# ============================================================================

# 1. Texto seguro, formatos y componentes comunes -----------------------------
op12_esc <- function(x) {
  x <- as.character(x)
  for (par in list(c("&", "&amp;"), c("<", "&lt;"), c(">", "&gt;"), c('"', "&quot;")))
    x <- gsub(par[1], par[2], x, fixed = TRUE)
  x
}
op12_num <- function(x, digitos = 0L, pendiente = "—") {
  vapply(x, function(z) if (!is.finite(z)) pendiente else
    formatC(z, format = "f", digits = digitos, big.mark = ".", decimal.mark = ","), character(1))
}
op12_mes <- function(x, corto = FALSE) {
  meses <- c("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre")
  d <- as.Date(x); m <- meses[as.integer(format(d, "%m"))]
  if (corto) m <- substr(m, 1, 3)
  paste(m, format(d, "%Y"))
}
op12_modelo <- function(x) ifelse(x == "Naive_estacional", "Naïve estacional", "SARIMA")
op12_chip <- function(texto, clase = "") paste0('<span class="chip ', clase, '">', op12_esc(texto), '</span>')
op12_kpi <- function(etiqueta, valor, detalle) paste0('<div class="kpi"><span>', etiqueta,
  '</span><strong>', valor, '</strong><small>', detalle, '</small></div>')
op12_vacio <- function(titulo, texto) paste0('<div class="empty"><span class="empty-mark" aria-hidden="true">↗</span><div><h3>', titulo,
  '</h3><p>', texto, '</p></div></div>')

op12_css <- function() paste0('
:root{--ink:#173c3a;--muted:#526b68;--teal:#007c80;--orange:#b55b22;--paper:#f6f7f2;--line:#d9e2da;--lime:#dcecb6;--white:#fff;--navy:#213c51}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--paper);color:var(--ink);font:16px/1.6 "Segoe UI",system-ui,sans-serif}a{color:var(--teal);text-underline-offset:4px}a:hover{color:#00595d}button,input{font:inherit}a:focus-visible,button:focus-visible,summary:focus-visible,input:focus-visible{outline:3px solid #af7515;outline-offset:4px}h1,h2,h3,p{margin-top:0}h1{font-size:clamp(32px,4vw,51px);line-height:1.12;letter-spacing:-.035em;font-weight:650;margin-bottom:18px}h2{font-size:25px;line-height:1.25;letter-spacing:-.025em;margin-bottom:10px}h3{font-size:17px;margin-bottom:6px}p{margin-bottom:15px}.wrap{max-width:1260px;margin:auto;padding:0 36px}.masthead{background:var(--ink);color:white}.masthead .wrap{display:flex;align-items:center;justify-content:space-between;gap:24px;min-height:86px}.brand{display:flex;gap:14px;align-items:center;color:white;text-decoration:none;font-weight:650;line-height:1.2}.brand small{display:block;color:#bbd0c9;font-size:12px;letter-spacing:.17em;text-transform:uppercase;font-weight:400;margin-top:6px}.brand svg{width:43px;height:32px}.mastnote{font-size:12px;color:#bbd0c9;text-align:right}.nav{border-bottom:1px solid var(--line);background:white}.nav .wrap{display:flex;gap:30px;overflow-x:auto}.nav a{color:var(--muted);font-size:14px;font-weight:600;white-space:nowrap;text-decoration:none;padding:19px 0 15px;border-bottom:3px solid transparent}.nav a.active{border-color:var(--teal);color:var(--ink)}main{padding-top:42px!important;padding-bottom:50px!important}.eyebrow{font-size:12px;letter-spacing:.13em;font-weight:700;text-transform:uppercase;color:var(--teal);margin-bottom:15px;display:block}.hero{display:grid;grid-template-columns:1fr 310px;gap:55px;margin-bottom:28px}.hero p{color:var(--muted);max-width:740px;font-size:17px}.hero-side{border-left:1px solid var(--line);padding-left:26px;align-self:center}.hero-side p{font-size:13px;margin:9px 0}.hero-side strong{color:var(--ink)}.chip{display:inline-flex;align-items:center;gap:6px;border-radius:4px;background:#e6eee7;padding:4px 9px;color:var(--ink);font-size:12px;font-weight:600}.chip.current{background:var(--lime)}.chip.pending{background:#edf0f2;color:#56636a}.kpis{display:grid;grid-template-columns:repeat(4,1fr);background:white;border:1px solid var(--line);border-radius:10px;margin-bottom:30px}.kpi{padding:20px 22px;min-width:0}.kpi+.kpi{border-left:1px solid var(--line)}.kpi>span{display:block;font-size:12px;color:var(--muted);font-weight:600}.kpi strong{display:block;font-size:29px;letter-spacing:-.04em;line-height:1.4;font-weight:650}.kpi small{display:block;color:var(--muted);font-size:12px}.panel{background:white;border:1px solid var(--line);border-radius:10px;padding:28px;margin-bottom:26px}.section-head{display:flex;justify-content:space-between;gap:24px;align-items:start;margin-bottom:18px}.section-head p,.caption,.note{font-size:13px;color:var(--muted);max-width:900px}.section-head p{margin-bottom:0}.button{display:inline-block;padding:10px 16px;border-radius:5px;text-decoration:none;font-weight:600;font-size:13px;background:var(--ink);color:white;border:1px solid var(--ink);white-space:nowrap}.button:hover{background:#28524e;color:white}.button.secondary{background:transparent;color:var(--ink);border-color:var(--line)}.actions{display:flex;gap:10px;flex-wrap:wrap;align-items:center}.legend{display:flex;gap:18px;flex-wrap:wrap;color:var(--muted);font-size:12px;margin:12px 0}.legend span,.legend label{display:inline-flex;gap:7px;align-items:center}.swatch{width:20px;height:3px;display:inline-block;background:var(--teal)}.swatch.naive{height:0;border-top:3px dashed var(--orange);background:none}.swatch.history{background:#7a9189}.swatch.real{background:var(--navy)}.swatch.band{height:11px;background:#b3d8d6}.legend input{accent-color:var(--teal)}.chart-wrap{overflow-x:auto}.chart{display:block;width:100%;height:auto;min-width:570px}.chart text{fill:var(--muted);font:12px "Segoe UI",system-ui,sans-serif}.chart .grid{stroke:#e7ece6;stroke-width:1}.chart .axis{stroke:#abbcb4;stroke-width:1}.chart [data-layer]{transition:opacity .15s}.caption{margin:12px 0 0}.split{display:grid;grid-template-columns:1fr 1fr;gap:22px}.split .chart{min-width:380px}.notice{border-left:3px solid var(--teal);padding:14px 18px;background:#eef4ee;font-size:13px;color:var(--muted);margin:20px 0}.empty{display:flex;gap:20px;align-items:center;background:#f1f5ed;border:1px dashed #bccfbd;padding:26px;border-radius:7px;margin:15px 0}.empty-mark{font-size:35px;color:var(--teal)}.empty p{color:var(--muted);font-size:14px;margin:0}.empty h3{font-size:19px}.table-wrap{overflow-x:auto}table{border-collapse:collapse;width:100%;font-size:13px;font-variant-numeric:tabular-nums}th{font-size:11px;text-transform:uppercase;letter-spacing:.035em;background:#f1f5ee;color:var(--muted);font-weight:600}th,td{padding:13px 12px;border-bottom:1px solid #e6ece5;text-align:right;white-space:nowrap}th:first-child,td:first-child{text-align:left}tbody tr:hover{background:#f8faf4}td.primary{font-weight:650;color:var(--teal)}caption{text-align:left;padding:8px 0 14px;color:var(--muted);font-size:13px}.table-wrap:focus-visible{outline:2px solid var(--teal)}details{border-top:1px solid var(--line);margin-top:22px;padding-top:18px}summary{cursor:pointer;font-size:14px;font-weight:650}details>div,details>p{margin-top:18px}.archive{display:grid;grid-template-columns:repeat(2,1fr);gap:16px}.emission{padding:22px;border:1px solid var(--line);border-radius:7px;background:white}.emission h3{font-size:22px;margin:12px 0 6px}.emission p{font-size:13px;color:var(--muted);margin-bottom:12px}.emission code{font-size:11px;overflow-wrap:anywhere;white-space:normal}.meta-grid{display:grid;grid-template-columns:1fr 1fr;gap:15px;font-size:13px}.meta-grid dt{color:var(--muted)}.meta-grid dd{margin:2px 0 0;font-weight:600;overflow-wrap:anywhere}.footer{border-top:1px solid var(--line);padding:24px 0 32px;font-size:12px;color:var(--muted)}.footer .wrap{display:flex;justify-content:space-between;gap:25px}.footer p{margin:0;max-width:760px}.screenreader:focus{width:auto;height:auto;clip:auto;z-index:20;background:white;padding:12px}.screenreader{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0)}.divider-label{display:flex;align-items:center;gap:15px;margin:36px 0 18px}.divider-label:after{content:"";height:1px;flex:1;background:var(--line)}code{font-size:.87em}noscript{display:block;color:var(--muted);font-size:12px}
@media(max-width:800px){.wrap{padding:0 18px}.hero{grid-template-columns:1fr;gap:10px}.hero-side{padding:15px 0 0;border-left:0;border-top:1px solid var(--line)}.hero-side .chip{display:table;margin-bottom:10px}.hero-side p{display:block;margin-right:0}.mastnote{display:none}.nav .wrap{gap:24px}.kpis{grid-template-columns:1fr 1fr}.kpi:nth-child(3){border-left:0;border-top:1px solid var(--line)}.kpi:nth-child(4){border-top:1px solid var(--line)}.kpi{padding:16px}.kpi strong{font-size:25px}.split,.archive{grid-template-columns:1fr}.panel{padding:20px 16px}.section-head{flex-wrap:wrap;gap:12px}main{padding-top:28px!important}.footer .wrap{display:block}.footer p{margin-bottom:12px}.meta-grid{grid-template-columns:1fr}}
@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}.chart [data-layer]{transition:none}}@media print{body{background:white}.masthead{background:white;color:var(--ink)}.brand{color:var(--ink)}.nav,.actions,.legend input{display:none}.panel,.kpis{break-inside:avoid}.chart{min-width:0}details{display:block}details>*{display:block!important}.wrap{max-width:none;padding:0}.footer{font-size:10px}}
')

op12_pagina <- function(titulo, cuerpo, activo = "actual", prefijo = "", actualizado = "") {
  destinos <- c(actual = "pronostico_actual.html", historial = "index.html", seguimiento = "metricas_operativas.html", historica = "evaluacion_historica.html")
  nombres <- c(actual = "Pronóstico actual", historial = "Emisiones", seguimiento = "Seguimiento real", historica = "Evaluación histórica")
  nav <- paste(vapply(names(destinos), function(k) paste0('<a ', if (k == activo) 'class="active" aria-current="page" ' else '',
    'href="', prefijo, destinos[[k]], '">', nombres[[k]], '</a>'), character(1)), collapse = "")
  paste0('<!doctype html><html lang="es"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
    '<meta name="description" content="Pronósticos mensuales de remisión de leche en Uruguay. SARIMA, referencia estacional, intervalos y seguimiento de emisiones con datos públicos del INALE.">',
    '<title>', op12_esc(titulo), ' · Remisión Uruguay</title><style>', op12_css(), '</style></head><body>',
    '<a class="screenreader" href="#contenido">Saltar al contenido</a><header class="masthead"><div class="wrap"><a class="brand" href="', prefijo, 'index.html">',
    '<svg viewBox="0 0 44 32" aria-hidden="true"><path d="M2 24L10 18L17 23L25 7L33 13L42 2" fill="none" stroke="#dcecb6" stroke-width="3"/><path d="M2 31H43" stroke="#658a7d"/></svg>',
    '<span>Remisión de leche<small>Uruguay · Datos y pronósticos</small></span></a><div class="mastnote">Datos públicos del INALE<br>Actualización mensual automatizada</div></div></header>',
    '<nav class="nav" aria-label="Navegación principal"><div class="wrap">', nav, '</div></nav><main class="wrap" id="contenido">', cuerpo, '</main>',
    '<footer class="footer"><div class="wrap"><p>Proyecto de Daniel Méndez · <a href="https://www.inale.org/estadisticas/remision-a-planta/">Fuente: INALE</a> · ',
    '<a href="https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy">Código y metodología</a><br>Los intervalos son condicionales al modelo. Las revisiones de la fuente pueden cambiar el seguimiento; los pronósticos emitidos se conservan.</p>',
    '<p>Seguimiento actualizado<br>', op12_esc(actualizado), '</p></div></footer>',
    '<script>document.querySelectorAll("input[data-toggle]").forEach(function(el){el.addEventListener("change",function(){var chart=el.closest("section");chart.querySelectorAll("[data-layer="+el.dataset.toggle+"]").forEach(function(g){g.style.display=el.checked?"":"none";});});});</script></body></html>')
}

# 2. SVG: coordenadas numericas independientes del idioma y sin librerias ------
op12_coord <- function(x) formatC(x, format = "f", digits = 2, decimal.mark = ".")
op12_marco <- function(x, y, titulo, etiquetas_x = NULL, etiquetas_y = NULL, alto = 330L) {
  xr <- range(x[is.finite(x)]); yr <- range(y[is.finite(y)])
  if (!all(is.finite(c(xr, yr)))) stop("Un grafico no tiene valores finitos.")
  if (diff(xr) == 0) xr <- xr + c(-.5, .5)
  if (diff(yr) == 0) yr <- yr + c(-1, 1) * max(1, abs(yr[1]) * .05)
  yr <- yr + c(-.08, .12) * diff(yr)
  X <- function(z) 62 + (z - xr[1]) / diff(xr) * 970
  Y <- function(z) alto - 42 - (z - yr[1]) / diff(yr) * (alto - 70)
  ticks <- pretty(yr, n = 5); ticks <- ticks[ticks >= yr[1] & ticks <= yr[2]]
  ylab <- if (is.null(etiquetas_y)) op12_num(ticks, if (diff(yr) < 2) 2L else 0L) else etiquetas_y(ticks)
  grid <- paste0('<line class="grid" x1="62" x2="1032" y1="', op12_coord(Y(ticks)), '" y2="', op12_coord(Y(ticks)), '"/>',
    '<text x="51" y="', op12_coord(Y(ticks) + 4), '" text-anchor="end">', ylab, '</text>', collapse = "")
  xt <- if (is.null(etiquetas_x)) pretty(xr, n = 7) else etiquetas_x$x
  xl <- if (is.null(etiquetas_x)) op12_num(xt) else etiquetas_x$label
  axis <- paste0('<text x="', op12_coord(X(xt)), '" y="', alto - 14, '" text-anchor="middle">', op12_esc(xl), '</text>', collapse = "")
  list(X = X, Y = Y, debut = paste0('<svg class="chart" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 ', alto,
    '" role="img"><title>', op12_esc(titulo), '</title><style>text{fill:#526b68;font:12px Segoe UI,system-ui,sans-serif}.grid{stroke:#e7ece6;stroke-width:1}</style>', grid, axis), fin = '</svg>')
}
op12_linea <- function(m, x, y, color, capa = "", guiones = FALSE, puntos = FALSE, etiquetas = NULL) {
  valido <- is.finite(x) & is.finite(y)
  if (!any(valido)) return("")
  # Cortar en los faltantes; no conectar horizontes sin observaciones.
  grupos <- cumsum(c(TRUE, diff(which(valido)) != 1))
  trozos <- split(which(valido), grupos)
  lineas <- paste(vapply(trozos, function(i) paste0('<polyline fill="none" stroke="', color, '" stroke-width="2.6" ',
    if (guiones) 'stroke-dasharray="7 5" ' else '', 'points="', paste(paste0(op12_coord(m$X(x[i])), ',', op12_coord(m$Y(y[i]))), collapse = " "), '"/>'), character(1)), collapse = "")
  circulos <- if (puntos) paste(vapply(which(valido), function(i) paste0('<circle cx="', op12_coord(m$X(x[i])), '" cy="',
    op12_coord(m$Y(y[i])), '" r="4" fill="', color, '"><title>', op12_esc(if (is.null(etiquetas)) paste(x[i], op12_num(y[i], 2L)) else etiquetas[i]), '</title></circle>'), character(1)), collapse = "") else ""
  paste0('<g', if (nzchar(capa)) paste0(' data-layer="', capa, '"') else '', '>', lineas, circulos, '</g>')
}
op12_leyenda <- function(controles = FALSE, reales = TRUE) {
  if (controles) paste0('<div class="legend"><span><i class="swatch history"></i>Historia conocida al emitir</span>',
    '<label><input type="checkbox" data-toggle="sarima" checked><i class="swatch"></i>SARIMA</label>',
    '<label><input type="checkbox" data-toggle="naive" checked><i class="swatch naive"></i>Naïve estacional</label>',
    '<label><input type="checkbox" data-toggle="bandas" checked><i class="swatch band"></i>Intervalos 80% y 95%</label>',
    if (reales) '<span><i class="swatch real"></i>Real vigente</span>' else '', '</div>') else
    '<div class="legend"><span><i class="swatch"></i>SARIMA</span><span><i class="swatch naive"></i>Naïve estacional</span></div>'
}

# 3. Cada emision usa su historia y su ajuste archivados; reales son actuales --
op12_paquete <- function(raiz, meta) {
  ruta <- normalizePath(file.path(raiz, meta$carpeta_resultados, "15_modelo_y_pronosticos_actuales.rds"), winslash = "/", mustWork = TRUE)
  base <- normalizePath(raiz, winslash = "/", mustWork = TRUE)
  if (!startsWith(ruta, paste0(base, "/"))) stop("Artefacto de reporte fuera del proyecto.")
  p <- readRDS(ruta)
  if (is.null(p$datos_entrenamiento) || is.null(p$modelo_diferencias) ||
      as.character(max(as.Date(p$datos_entrenamiento$fecha))) != meta$ultimo_dato)
    stop("No se encontro la historia y el ajuste originales de la emision.")
  p
}
op12_trayectoria <- function(s, n, paquete, seguimiento = TRUE) {
  d <- tail(paquete$datos_entrenamiento, 48L)
  fechas <- as.Date(c(as.character(d$fecha), as.character(s$fecha_objetivo)))
  x <- as.numeric(fechas); origen <- as.numeric(as.Date(s$origen[1]))
  ys <- c(d$remision_litros, s$inferior95, s$superior95, n$pronostico_litros,
    if (seguimiento) s$real_litros else NULL) / 1e6
  xi <- unique(c(seq.int(1L, length(x), by = 6L), length(x)))
  m <- op12_marco(x, ys, "Historia conocida al emitir, pronosticos a doce meses y seguimiento, en millones de litros",
    list(x = x[xi], label = op12_mes(fechas[xi], TRUE)))
  xf <- as.numeric(as.Date(s$fecha_objetivo)); xp <- c(origen, xf)
  banda <- function(a, b, color) paste0('<polygon fill="', color, '" points="',
    paste(paste0(op12_coord(m$X(c(xf, rev(xf)))), ',', op12_coord(m$Y(c(a, rev(b)) / 1e6))), collapse = " "), '"/>')
  etiqueta <- function(p, modelo) paste(op12_mes(p$fecha_objetivo), modelo, op12_num(p$pronostico_litros), "litros")
  paste0(m$debut, '<g data-layer="bandas">', banda(s$inferior95, s$superior95, '#e1eeeb'), banda(s$inferior80, s$superior80, '#b3d8d6'), '</g>',
    '<line x1="', op12_coord(m$X(origen)), '" x2="', op12_coord(m$X(origen)), '" y1="24" y2="288" stroke="#9aafa4" stroke-dasharray="4 5"/>',
    op12_linea(m, as.numeric(as.Date(d$fecha)), d$remision_litros / 1e6, '#7a9189'),
    op12_linea(m, xp, c(tail(d$remision_litros, 1), n$pronostico_litros) / 1e6, '#b55b22', 'naive', TRUE),
    op12_linea(m, xp, c(tail(d$remision_litros, 1), s$pronostico_litros) / 1e6, '#007c80', 'sarima'),
    op12_linea(m, xf, s$pronostico_litros / 1e6, '#007c80', 'sarima', puntos = TRUE, etiquetas = etiqueta(s, "SARIMA")),
    if (seguimiento) op12_linea(m, xf, s$real_litros / 1e6, '#213c51', puntos = TRUE,
      etiquetas = paste(op12_mes(s$fecha_objetivo), "real vigente", op12_num(s$real_litros), "litros")) else '', m$fin)
}
op12_diagnostico <- function(paquete) {
  e <- as.numeric(stats::residuals(paquete$modelo_diferencias)); e <- e[is.finite(e)]
  if (length(e) < 50L) stop("No hay residuos suficientes en el ajuste archivado.")
  fechas <- tail(as.Date(paquete$datos_entrenamiento$fecha), length(e))
  xi <- unique(round(seq(1, length(e), length.out = 6)))
  m <- op12_marco(as.numeric(fechas), e, "Innovaciones del ajuste original en logaritmos",
    list(x = as.numeric(fechas[xi]), label = format(fechas[xi], "%Y")))
  innov <- paste0(m$debut, op12_linea(m, as.numeric(fechas), e, '#007c80'), m$fin)
  barras <- function(v, titulo) {
    lag <- seq_along(v); b <- 1.96 / sqrt(length(e))
    m <- op12_marco(lag, c(v, -b, b, 0), titulo)
    paste0(m$debut, paste0('<line x1="', op12_coord(m$X(lag)), '" x2="', op12_coord(m$X(lag)),
      '" y1="', op12_coord(m$Y(0)), '" y2="', op12_coord(m$Y(v)), '" stroke="#007c80" stroke-width="3"/>', collapse = ""),
      paste0('<line x1="62" x2="1032" y1="', op12_coord(m$Y(c(-b, b))), '" y2="', op12_coord(m$Y(c(-b, b))), '" stroke="#b55b22" stroke-dasharray="5 5"/>', collapse = ""), m$fin)
  }
  qqx <- stats::qnorm(stats::ppoints(length(e))); qqy <- sort(e)
  m <- op12_marco(qqx, qqy, "QQ normal auxiliar del ajuste original")
  q <- stats::quantile(e, c(.25, .75)); z <- stats::qnorm(c(.25, .75)); pendiente <- diff(q) / diff(z)
  qq <- paste0(m$debut, op12_linea(m, range(qqx), q[1] + pendiente * (range(qqx) - z[1]), '#b55b22'),
    paste0('<circle cx="', op12_coord(m$X(qqx)), '" cy="', op12_coord(m$Y(qqy)), '" r="2" fill="#007c80"/>', collapse = ""), m$fin)
  panel <- function(t, g) paste0('<div><h3>', t, '</h3><div class="chart-wrap">', g, '</div></div>')
  paste0('<div class="split">', panel("Innovaciones · escala logarítmica", innov),
    panel("FAC residual · rezagos mensuales", barras(as.numeric(stats::acf(e, lag.max = 48L, plot = FALSE)$acf)[-1], "FAC residual, excluido rezago cero")),
    panel("FACP residual · rezagos mensuales", barras(as.numeric(stats::pacf(e, lag.max = 48L, plot = FALSE)$acf), "FACP residual")),
    panel("QQ normal · diagnóstico auxiliar", qq), '</div>',
    '<p class="note">Ajuste original de esta emisión, sin reestimarlo para dibujar. Las líneas de FAC/FACP son bandas aproximadas ±1,96/√n; no constituyen una prueba conjunta. El QQ es auxiliar y no garantiza normalidad ni superioridad predictiva.</p>')
}

op12_tabla <- function(p, titulo) {
  filas <- vapply(seq_len(nrow(p)), function(i) {
    z <- p[i, ]; celdas <- c(op12_mes(z$fecha_objetivo), z$h, op12_num(z$pronostico_litros), op12_num(z$real_litros),
      op12_num(z$diferencia_litros), if (is.finite(z$diferencia_pct)) paste0(op12_num(z$diferencia_pct, 2L), "%") else "—",
      paste(op12_num(z$inferior80), "–", op12_num(z$superior80)), paste(op12_num(z$inferior95), "–", op12_num(z$superior95)),
      op12_chip(z$estado, if (is.na(z$real_litros)) "pending" else "current"))
    paste0('<tr>', paste0('<td', ifelse(seq_along(celdas) == 3, ' class="primary"', ''), '>', celdas, '</td>', collapse = ''), '</tr>')
  }, character(1))
  paste0('<div class="table-wrap" tabindex="0" role="region" aria-label="', titulo, '"><table><caption>', titulo, ' · litros mensuales</caption><thead><tr>',
    paste0('<th scope="col">', c("Mes objetivo", "h", "Pronóstico", "Real vigente", "Real − pronóstico", "Diferencia / real", "Intervalo 80%", "Intervalo 95%", "Estado"), '</th>', collapse = ''),
    '</tr></thead><tbody>', paste(filas, collapse = ''), '</tbody></table></div>')
}

op12_reporte <- function(s, n, meta, corte, actualizado, paquete, prefijo = "", actual = TRUE) {
  id <- as.character(meta$ejecucion_id); carpeta <- paste0(prefijo, 'emisiones/', id, '/')
  conocidos <- sum(is.finite(s$real_litros))
  cuerpo <- paste0('<div class="hero"><div><span class="eyebrow">', if (actual) 'Emisión vigente' else 'Archivo de emisiones', '</span>',
    '<h1>Pronóstico mensual<br>de remisión de leche.</h1><p>Doce meses de proyección, una referencia estacional y un seguimiento que se completa con cada dato publicado.</p></div>',
    '<aside class="hero-side">', op12_chip(if (actual) "Emisión actual" else "Emisión archivada", "current"),
    '<p>Datos al emitir<br><strong>', op12_mes(meta$ultimo_dato), '</strong></p><p>Observados vigentes hasta<br><strong>', op12_mes(corte), '</strong></p></aside></div>',
    '<div class="kpis">', op12_kpi("Primer mes pronosticado", paste0(op12_num(s$pronostico_litros[1] / 1e6, 1L), ' M L'), op12_mes(s$fecha_objetivo[1])),
    op12_kpi("Intervalo del primer mes · 95%", paste0(op12_num(s$inferior95[1] / 1e6, 1L), '–', op12_num(s$superior95[1] / 1e6, 1L)), 'Millones de litros · SARIMA'),
    op12_kpi("Horizonte", '12 meses', paste(op12_mes(s$fecha_objetivo[1], TRUE), '–', op12_mes(tail(s$fecha_objetivo, 1), TRUE))),
    op12_kpi("Seguimiento disponible", paste0(conocidos, ' / 12'), paste(12 - conocidos, 'meses pendientes')), '</div>',
    '<section class="panel"><div class="section-head"><div><span class="eyebrow">Trayectoria e incertidumbre</span><h2>Lo observado y lo que viene</h2><p>Millones de litros por mes · últimos cuatro años de historia al emitir.</p></div><div class="actions"><a class="button secondary" download href="', carpeta, 'sarima.csv">Descargar SARIMA · CSV</a></div></div>',
    op12_leyenda(TRUE, conocidos > 0), '<div class="chart-wrap">', op12_trayectoria(s, n, paquete), '</div>',
    '<p class="caption">La línea vertical separa la historia de los pronósticos. Banda oscura: 80%; banda clara: 95%. Los puntos muestran el valor SARIMA al pasar el cursor. La referencia naïve repite el promedio diario del mismo mes del año anterior, ajustado por días.</p>',
    '<noscript>El gráfico y las tablas funcionan sin JavaScript; los controles de visibilidad requieren activarlo.</noscript>',
    if (!conocidos) op12_vacio("El seguimiento todavía está por comenzar", "Esta emisión aún no tiene meses objetivo con un valor real publicado. Los pronósticos y sus intervalos ya están disponibles; los errores se completarán cuando llegue cada observado.") else
      '<div class="notice">Los reales corresponden a la versión vigente del INALE. La historia que se conocía al emitir y las predicciones originales permanecen identificadas con esta emisión.</div>', '</section>',
    '<section class="panel"><div class="section-head"><div><span class="eyebrow">Detalle por mes</span><h2>Pronóstico y seguimiento</h2><p>SARIMA · cifras redondeadas al litro. El CSV conserva la precisión original.</p></div></div>', op12_tabla(s, 'SARIMA'),
    '<p class="note">Diferencia = real − pronóstico: positiva indica subpredicción. Porcentaje = 100 × diferencia / real. Los pendientes no equivalen a cero.</p>',
    '<details><summary>Comparar con el naïve estacional · doce meses</summary><div class="actions"><a class="button secondary" download href="', carpeta, 'naive_estacional.csv">Descargar naïve · CSV</a></div>', op12_tabla(n, 'Naïve estacional'), '</details></section>',
    '<section class="panel"><span class="eyebrow">Trazabilidad</span><h2>Qué hay detrás de esta emisión</h2><dl class="meta-grid">',
    '<div><dt>Identificador</dt><dd><code>', op12_esc(id), '</code></dd></div><div><dt>Generada</dt><dd>', op12_esc(meta$fecha_ejecucion_utc), '</dd></div>',
    '<div><dt>Datos usados al emitir</dt><dd>', op12_mes(meta$inicio_datos), ' – ', op12_mes(meta$ultimo_dato), ' · ', meta$n_observaciones, ' meses</dd></div>',
    '<div><dt>Versión</dt><dd>', op12_esc(meta$version_modelo), '</dd></div></dl><p class="note">', op12_esc(meta$especificacion), '</p>',
    '<details><summary>Ver diagnóstico del ajuste original</summary>', op12_diagnostico(paquete), '</details>',
    '<details><summary>Información original y límites de lectura</summary><p class="note">Cada emisión conserva la historia, el ajuste y los doce pronósticos con los que se produjo. El reporte añade los observados vigentes sin cambiar esas predicciones. Las revisiones pueden generar otra emisión desde el mismo origen: el identificador distingue las versiones. Los intervalos no incorporan incertidumbre de selección, parámetros ni futuros eventos desconocidos.</p>',
    '<div class="actions"><a class="button secondary" href="', carpeta, 'trayectoria_original.svg">Abrir gráfico original · SVG</a></div></details></section>')
  op12_pagina('Pronóstico mensual', cuerpo, if (actual) 'actual' else 'historial', prefijo, actualizado)
}

# 4. Portada: resumen vigente y archivo consultable ---------------------------
op12_indice <- function(emisiones, emision_actual, actual, paquete, corte, actualizado) {
  tarjetas <- vapply(seq_len(nrow(emisiones)), function(i) {
    e <- emisiones[i, ]; paste0('<article class="emission">', op12_chip(if (e$ejecucion_id == emision_actual) 'Actual' else 'Archivada', if (e$ejecucion_id == emision_actual) 'current' else ''),
      '<h3>Origen: ', op12_mes(e$ultimo_dato), '</h3><p>Emitida: ', op12_esc(e$fecha_ejecucion_utc), '<br>', e$n_observaciones, ' meses de datos · 12 meses por modelo</p>',
      '<p><code>', op12_esc(e$ejecucion_id), '</code></p><a class="button secondary" href="emisiones/', op12_esc(e$ejecucion_id), '/reporte.html">Consultar emisión →</a></article>')
  }, character(1))
  s <- actual$sarima; n <- actual$naive
  cuerpo <- paste0('<div class="hero"><div><span class="eyebrow">Pronósticos · Uruguay</span><h1>Remisión de leche.<br>Pronósticos a doce meses.</h1>',
    '<p>Remisión mensual de leche a plantas industriales. Proyecciones a doce meses con SARIMA y una referencia estacional, a partir de datos públicos del INALE.</p><div class="actions"><a class="button" href="pronostico_actual.html">Explorar pronóstico actual →</a><a class="button secondary" href="metricas_operativas.html">Ver seguimiento real</a></div></div>',
    '<aside class="hero-side">', op12_chip('Actualización mensual', 'current'), '<p>Datos disponibles hasta<br><strong>', op12_mes(corte), '</strong></p><p>Modelo operativo<br><strong>SARIMA + referencia estacional</strong></p></aside></div>',
    '<div class="kpis">', op12_kpi('Primer mes de la emisión vigente', paste0(op12_num(s$pronostico_litros[1] / 1e6, 1L), ' M L'), op12_mes(s$fecha_objetivo[1])),
    op12_kpi('Horizonte de cada emisión', '12 meses', 'Pronósticos SARIMA y naïve'), op12_kpi('Emisiones conservadas', nrow(emisiones), 'Cada versión mantiene sus predicciones'),
    op12_kpi('Observados de la emisión vigente', paste0(sum(is.finite(s$real_litros)), ' / 12'), 'Se completa al publicarse cada mes'), '</div>',
    '<section class="panel"><div class="section-head"><div><span class="eyebrow">Una vista del pronóstico actual</span><h2>El ciclo estacional, hacia adelante</h2><p>Millones de litros · emisión con datos hasta ', op12_mes(actual$meta$ultimo_dato), '.</p></div><a class="button secondary" href="pronostico_actual.html">Abrir detalle →</a></div>',
    op12_leyenda(TRUE, any(is.finite(s$real_litros))), '<div class="chart-wrap">', op12_trayectoria(s, n, paquete), '</div><p class="caption">SARIMA con intervalos condicionales del 80% y 95%. Se conservan los pronósticos originales; los reales se incorporan al seguimiento cuando están disponibles.</p></section>',
    '<div class="divider-label"><h2 id="emisiones">Archivo de emisiones</h2></div><p class="note">Consultar qué se pronosticó desde cada origen y cómo se compara con los valores reales vigentes. Una revisión puede producir versiones distintas desde el mismo origen.</p><div class="archive">', paste(tarjetas, collapse = ''), '</div>',
    '<div class="notice"><strong>Dos evaluaciones, dos preguntas.</strong> El seguimiento real mide los pronósticos efectivamente emitidos. La evaluación histórica reconstruye ejercicios pasados condicionados al modelo seleccionado. Sus resultados se presentan por separado.</div>')
  op12_pagina('Emisiones y pronósticos', cuerpo, 'historial', actualizado = actualizado)
}

# 5. Seguimiento real: mismos casos para los dos modelos y pendientes como NA --
op12_calcular_metricas <- function(con) {
  m <- DBI::dbGetQuery(con, paste('SELECT p.modelo, p.h, COUNT(a.remision_litros) AS n_errores,',
    'AVG(ABS(a.remision_litros-p.pred_media)) AS MAE_litros,',
    'AVG((a.remision_litros-p.pred_media)*(a.remision_litros-p.pred_media)) AS MSE_litros',
    'FROM forecast_pronosticos p LEFT JOIN analitica_remision_mensual a ON a.fecha=p.fecha_objetivo GROUP BY p.modelo,p.h ORDER BY p.modelo,p.h'))
  if (nrow(m) != 24L) stop('Se requieren doce horizontes de los dos modelos.')
  m$RMSE_litros <- sqrt(m$MSE_litros); m$MSE_litros <- NULL
  m$estado <- ifelse(m$n_errores == 0L, 'Sin observaciones evaluables', 'Con observaciones')
  cobertura <- DBI::dbGetQuery(con, paste('SELECT p.modelo,p.h,COUNT(a.remision_litros) AS n_errores,',
    'AVG(CASE WHEN a.remision_litros IS NOT NULL THEN CASE WHEN a.remision_litros BETWEEN p.inferior80 AND p.superior80 THEN 100.0 ELSE 0.0 END END) AS cobertura80,',
    'AVG(CASE WHEN a.remision_litros IS NOT NULL THEN CASE WHEN a.remision_litros BETWEEN p.inferior95 AND p.superior95 THEN 100.0 ELSE 0.0 END END) AS cobertura95',
    'FROM forecast_pronosticos p LEFT JOIN analitica_remision_mensual a ON a.fecha=p.fecha_objetivo GROUP BY p.modelo,p.h ORDER BY p.modelo,p.h'))
  # La comparacion exige exactamente los mismos objetivos y emisiones.
  pares <- DBI::dbGetQuery(con, paste('SELECT ejecucion_id,fecha_objetivo,h,COUNT(*) AS n,COUNT(DISTINCT modelo) AS modelos',
    'FROM forecast_pronosticos GROUP BY ejecucion_id,fecha_objetivo,h HAVING COUNT(*)!=2 OR COUNT(DISTINCT modelo)!=2'))
  if (nrow(pares)) stop('Los modelos no comparten los mismos casos de comparacion.')
  list(metricas = m, cobertura = cobertura)
}
op12_comparacion <- function(m, campo, titulo, porcentaje = FALSE, referencia = NULL) {
  y <- m[[campo]] / if (porcentaje) 1 else 1e6
  if (!any(is.finite(y))) return(op12_vacio('Aún no hay errores evaluables', 'El gráfico se completará al llegar los observados. No se muestran errores iguales a cero en lugar de datos faltantes.'))
  marco <- op12_marco(1:12, c(0, y, referencia), titulo, list(x = 1:12, label = 1:12))
  capas <- vapply(c('SARIMA', 'Naive_estacional'), function(modelo) {
    z <- m[m$modelo == modelo, ]; z <- z[order(z$h), ]; valores <- z[[campo]] / if (porcentaje) 1 else 1e6
    op12_linea(marco, z$h, valores, if (modelo == 'SARIMA') '#007c80' else '#b55b22', guiones = modelo != 'SARIMA', puntos = TRUE,
      etiquetas = paste(op12_modelo(modelo), 'h =', z$h, op12_num(valores, 2L), if (porcentaje) '%' else 'millones de litros', '· n =', z$n_errores))
  }, character(1))
  linea <- if (!is.null(referencia)) paste0('<line x1="62" x2="1032" y1="', op12_coord(marco$Y(referencia)), '" y2="', op12_coord(marco$Y(referencia)), '" stroke="#8c9e95" stroke-dasharray="5 5"/>') else ''
  paste0('<div class="chart-wrap">', marco$debut, linea, paste(capas, collapse = ''), marco$fin, '</div>')
}
op12_metricas <- function(con, raiz, actualizado) {
  datos <- op12_calcular_metricas(con); m <- datos$metricas; c <- datos$cobertura
  carpeta <- file.path(raiz, 'outputs', 'reportes')
  utils::write.csv(m, file.path(carpeta, 'metricas_operativas.csv'), row.names = FALSE, na = '', fileEncoding = 'UTF-8')
  utils::write.csv(c, file.path(carpeta, 'cobertura_operativa.csv'), row.names = FALSE, na = '', fileEncoding = 'UTF-8')
  n <- sum(m$n_errores[m$modelo == 'SARIMA'])
  filas <- paste0('<tr><td>', op12_modelo(m$modelo), '</td><td>', m$h, '</td><td>', m$n_errores, '</td><td>',
    op12_num(m$MAE_litros, pendiente = 'Pendiente'), '</td><td>', op12_num(m$RMSE_litros, pendiente = 'Pendiente'), '</td><td>',
    op12_num(c$cobertura80, 1L, 'Pendiente'), '</td><td>', op12_num(c$cobertura95, 1L, 'Pendiente'), '</td></tr>')
  cuerpo <- paste0('<div class="hero"><div><span class="eyebrow">Evaluación de la operación</span><h1>Del pronóstico emitido<br>al resultado observado.</h1><p>Errores de las emisiones conservadas, comparados con la versión vigente de los datos del INALE. Cada horizonte se evalúa cuando llega su mes objetivo.</p></div>',
    '<aside class="hero-side">', op12_chip(if (n) paste(n, 'casos por modelo') else 'Esperando observados', if (n) 'current' else 'pending'),
    '<p>Comparación<br><strong>Mismas emisiones y meses objetivo</strong></p></aside></div>',
    if (!n) op12_vacio('Todavía no hay resultados para evaluar', 'No llegó un observado para los meses pronosticados. Las métricas quedan pendientes y los gráficos aparecerán automáticamente cuando haya casos disponibles.') else
      '<div class="notice">Los horizontes tienen distinta cantidad de casos. Una métrica con pocos errores es inestable; consultá n antes de comparar. Las emisiones solapadas no son observaciones independientes.</div>',
    '<section class="panel"><div class="section-head"><div><span class="eyebrow">Precisión por horizonte</span><h2>¿Qué tan cerca estuvo cada modelo?</h2><p>Menor error es mejor · millones de litros · horizonte en meses.</p></div><a class="button secondary" download href="metricas_operativas.csv">Descargar métricas · CSV</a></div>',
    op12_leyenda(), '<div class="split"><div><h3>MAE · error absoluto medio</h3>', op12_comparacion(m, 'MAE_litros', 'MAE real por horizonte'),
    '</div><div><h3>RMSE · penaliza errores grandes</h3>', op12_comparacion(m, 'RMSE_litros', 'RMSE real por horizonte'), '</div></div></section>',
    '<section class="panel"><span class="eyebrow">Incertidumbre</span><h2>Cobertura de los intervalos</h2><p class="note">Porcentaje de reales dentro de cada intervalo. La línea discontinua marca el nivel nominal; con pocos casos la cobertura puede variar mucho.</p>',
    op12_leyenda(), '<div class="split"><div><h3>Intervalo del 80%</h3>', op12_comparacion(c, 'cobertura80', 'Cobertura real del intervalo 80%', TRUE, 80),
    '</div><div><h3>Intervalo del 95%</h3>', op12_comparacion(c, 'cobertura95', 'Cobertura real del intervalo 95%', TRUE, 95), '</div></div><a download href="cobertura_operativa.csv">Descargar cobertura · CSV</a></section>',
    '<section class="panel"><h2>Casos y métricas completas</h2><div class="table-wrap" tabindex="0" role="region" aria-label="Métricas completas"><table><caption>MAE y RMSE en litros; cobertura en porcentaje. n cuenta casos por emisión, modelo y horizonte.</caption>',
    '<thead><tr><th>Modelo</th><th>h</th><th>n evaluable</th><th>MAE</th><th>RMSE</th><th>Cobertura 80%</th><th>Cobertura 95%</th></tr></thead><tbody>', paste(filas, collapse = ''), '</tbody></table></div>',
    '<div class="notice">Dos versiones emitidas desde el mismo origen se cuentan como pronósticos distintos. Las revisiones de los observados pueden cambiar los errores y coberturas. Esta página no incluye predicciones retrospectivas del script 07.</div></section>')
  writeLines(op12_pagina('Seguimiento real', cuerpo, 'seguimiento', actualizado = actualizado), file.path(carpeta, 'metricas_operativas.html'), useBytes = TRUE)
  invisible(m)
}

# 6. Referencia historica fechada; no recalcular el backtesting ----------------
op12_historica <- function(raiz, actualizado) {
  ruta <- file.path(raiz, 'outputs', 'evaluacion_predictiva', '07_sarima_vs_naive', '20261031_171120_23228')
  archivo <- file.path(ruta, '03_metricas_por_horizonte.csv')
  if (!file.exists(archivo)) stop('Falta el CSV archivado de la evaluacion historica.')
  m <- utils::read.csv(archivo, stringsAsFactors = FALSE)
  # Nombres del artefacto 07 se adaptan solo para presentar, no para evaluar.
  if (!all(c('modelo', 'h', 'MAE', 'RMSE', 'n', 'cobertura80_pct', 'cobertura95_pct') %in% names(m))) stop('Cambio el esquema de las metricas historicas.')
  m$n_errores <- m$n; m$MAE_litros <- m$MAE; m$RMSE_litros <- m$RMSE
  m$cobertura80 <- m$cobertura80_pct; m$cobertura95 <- m$cobertura95_pct
  filas <- paste0('<tr><td>', op12_modelo(m$modelo), '</td><td>', m$h, '</td><td>', m$n, '</td><td>',
    op12_num(m$MAE / 1e6, 2L), '</td><td>', op12_num(m$RMSE / 1e6, 2L), '</td><td>',
    op12_num(m$cobertura80, 1L), '</td><td>', op12_num(m$cobertura95, 1L), '</td></tr>')
  cuerpo <- paste0('<div class="hero"><div><span class="eyebrow">Referencia archivada · script 07</span><h1>El desempeño histórico,<br>con sus límites a la vista.</h1><p>Comparación retrospectiva entre SARIMA y naïve estacional, con ventanas expansivas y horizontes de uno a doce meses.</p></div><aside class="hero-side">',
    op12_chip('Backtesting condicionado'), '<p>Muestra de referencia<br><strong>Datos hasta septiembre de 2026</strong></p><p>166 orígenes<br><strong>Diciembre 2011 – septiembre 2025</strong></p></aside></div>',
    '<div class="notice"><strong>No es el seguimiento real de las emisiones.</strong> La especificación se seleccionó con datos hasta septiembre de 2025 y se mantuvo al reconstruir los orígenes anteriores. Por eso esta comparación no es una prueba independiente del proceso completo de selección. Tampoco reconstruye las publicaciones históricas de los observados.</div>',
    '<section class="panel"><span class="eyebrow">Comparación por horizonte</span><h2>La ventaja cambia con el plazo</h2><p class="note">SARIMA obtuvo menor MAE y RMSE a 1–3 meses; el naïve, a 4–12. Millones de litros; menor es mejor.</p>',
    op12_leyenda(), '<div class="split"><div><h3>MAE</h3>', op12_comparacion(m, 'MAE_litros', 'MAE del backtesting condicionado'), '</div><div><h3>RMSE</h3>',
    op12_comparacion(m, 'RMSE_litros', 'RMSE del backtesting condicionado'), '</div></div></section>',
    '<section class="panel"><span class="eyebrow">Intervalos en la evaluación histórica</span><h2>¿Cuántos reales quedaron dentro?</h2><p class="note">Porcentaje de cobertura por horizonte. La línea discontinua indica el nivel nominal. Los intervalos muy amplios pueden cubrir más y resultar menos informativos.</p>',
    op12_leyenda(), '<div class="split"><div><h3>Intervalo del 80%</h3>', op12_comparacion(m, 'cobertura80', 'Cobertura historica 80%', TRUE, 80),
    '</div><div><h3>Intervalo del 95%</h3>', op12_comparacion(m, 'cobertura95', 'Cobertura historica 95%', TRUE, 95), '</div></div>',
    '<details><summary>Consultar valores y tamaños de muestra</summary><div class="table-wrap" tabindex="0" role="region" aria-label="Resultados históricos completos"><table><caption>MAE y RMSE en millones de litros; coberturas en porcentaje.</caption>',
    '<thead><tr><th>Modelo</th><th>h</th><th>n</th><th>MAE</th><th>RMSE</th><th>Cobertura 80%</th><th>Cobertura 95%</th></tr></thead><tbody>', paste(filas, collapse = ''), '</tbody></table></div></details></section>',
    '<section class="panel"><h2>Cómo leer esta referencia</h2><p>Los coeficientes se reestimaron en cada origen, conservando la especificación cerrada. MAE fue la métrica principal; RMSE, complementaria. Los resultados ayudan a entender los límites del modelo y no justifican afirmar superioridad general del SARIMA.</p>',
    '<p>Esta referencia permanece fechada. La consulta mensual produce nuevas emisiones y completa su seguimiento; no vuelve a ejecutar el backtesting del 07 para actualizar estos gráficos.</p><a class="button secondary" href="https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy/blob/main/docs/RESULTADOS.md">Consultar resultados y límites →</a></section>')
  writeLines(op12_pagina('Evaluación histórica', cuerpo, 'historica', actualizado = actualizado), file.path(raiz, 'outputs', 'reportes', 'evaluacion_historica.html'), useBytes = TRUE)
}

# 7. Vista local: regenerar la presentacion sin descargar ni ejecutar el ciclo --
regenerar_reportes12 <- function(raiz = getwd()) {
  for (p in c('DBI', 'RSQLite', 'forecast')) if (!requireNamespace(p, quietly = TRUE)) stop('Falta ', p, '; restaurar renv.')
  raiz <- normalizePath(raiz, winslash = '/', mustWork = TRUE)
  codigo <- parse(file.path(raiz, 'R', '10_actualizar_pronosticos.R'), encoding = 'UTF-8')
  if (!identical(codigo[[length(codigo)]], quote(operacion10 <- ejecutar_ciclo10(config10))))
    stop('Cambio el punto de entrada del 10; revisar la integracion.')
  motor <- new.env(parent = globalenv()); eval(codigo[-length(codigo)], motor)
  base <- file.path(raiz, 'database', 'forecasting.sqlite')
  if (!file.exists(base)) stop('Falta SQLite local. Esta funcion no la crea ni recupera estado remoto.')
  # Conexion SQLite de solo lectura: la vista no puede cambiar datos ni registros.
  con <- DBI::dbConnect(RSQLite::SQLite(), base, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  id <- DBI::dbGetQuery(con, paste('SELECT ejecucion_id FROM forecast_ejecuciones',
    'ORDER BY ultimo_dato DESC,fecha_ejecucion_utc DESC,ejecucion_id DESC LIMIT 1'))$ejecucion_id
  if (length(id) != 1L) stop('No hay una emision registrada.')
  carpeta <- file.path(raiz, 'outputs', 'vista_local_reporte')
  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
  resultado <- motor$op10_generar_reportes(con, raiz, id, carpeta)
  cat('Reporte regenerado sin descargar, estimar ni registrar emisiones.\nAbrir:', resultado$indice, '\n')
  invisible(resultado)
}
