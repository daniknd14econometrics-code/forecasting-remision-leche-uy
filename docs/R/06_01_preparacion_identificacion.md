# Script 06 — Preparación, integración e identificación (00–03)

## Cómo usar esta documentación

Este documento acompaña `R/06_modelar_evaluar_sarima.R`. La numeración 01–09 identifica **bloques internos de ese script**, no otros archivos `R/01...R`, `R/02...R`, etc. Los tres documentos respetan el orden del código y reproducen íntegramente sus tramos correspondientes, sin omitir funciones sustantivas. El código se incluye para estudiar; para ejecutar se utiliza el `.R` completo, no los trozos Markdown de forma aislada.

**Desarrollo:** enero de 2002 a septiembre de 2025, 285 niveles y 284 primeras diferencias. **Variable:** logaritmo del promedio diario de remisión de cada mes, `x_t=log(litros_t/dias_t)`. **Arquitectura final:** d=1, D=0, sin deriva; once contrastes mensuales sobre diferencias y dos efectos definidos en niveles. La muestra posterior no participa en la selección.

La representación final es `Delta x_t = beta'M_t + omega_TC Delta TC_t + omega_AO Delta AO_t + u_t`, con `(1-phi1 L-phi2 L²)(1-Phi L^12)u_t=(1+theta1 L)e_t`. En R se ajusta un ARMA sobre `Delta x` con d=D=0 internos. Diferenciar dos veces por interpretar otra vez la etiqueta original sería un error.

Los números descritos corresponden a las salidas aportadas por el usuario en RStudio. La versión añadida de 09 reutiliza esos ajustes: su ejecución en RStudio todavía debe comprobarse. La revisión local del archivo verificó sintaxis R y conservación de los bloques anteriores; no constituye una nueva ejecución estadística del recorrido.

Las referencias metodológicas del usuario son el capítulo de procesos ARMA, el de modelización ARIMA/SARIMA, el de outliers y los talleres 04B/05B. El bootstrap 06C es una extensión autorizada y se describe como aproximación condicional; no se atribuye literalmente al taller. No se incorporaron nuevas pruebas para redactar estos documentos.

**Documentos:** [1. Preparación, integración e identificación (00–03)](06_01_preparacion_identificacion.md) · [2. Candidatos y cambio estructural (04–06C)](06_02_candidatos_cambio_estructural.md) · [3. Outliers, revisión final y cierre (07–09)](06_03_outliers_revision_cierre.md)

**Versión de código documentada (SHA-256):** `c4e03b150a14bbdc8b77d2eb32b471ea07158ff17fed984a0d15d17f08b1e4e5`.

## Ejecución y objetos

Abrir `forecasting-remision-leche-uy.Rproj` en RStudio. El módulo requiere la base analítica SQLite ya construida por los scripts anteriores. Usa `DBI`, `RSQLite`, `ggplot2`, `forecast`, `uroot`, `urca` y `strucchange`, además de los paquetes base y sus dependencias. El script comprueba disponibilidad; no instala ni actualiza paquetes.

```r
source("R/06_modelar_evaluar_sarima.R")
```

La ejecución completa termina en `bloque09`. Las salidas se escriben bajo `outputs/sarima_box_jenkins/`. `renv::status()` sirve para revisar el entorno; la incorporación de dependencias al lockfile se hace de manera explícita en el repositorio local, no por un efecto oculto de este módulo.

| Etapa | Objeto que produce | Dependencias |
|---|---|---|
| 01 | bloque01 | SQLite de desarrollo |
| 01B, 02A, 02B, 03, 04 | objetos homónimos | bloque01 |
| 04B, 05 | bloque04b, bloque05 | bloque04 |
| 06, 06B | bloque06, bloque06b | bloque01 y bloque05 |
| 06C | bloque06c | bloque06b |
| 07 | bloque07 | bloque01 y bloque05 |
| 07B, 07C | bloque07b, bloque07c | resultado de la etapa anterior |
| 08 | bloque08 | bloque07c y bloque05 |
| 08B | bloque08b | bloque08 |
| 09 | bloque09 | bloque08, bloque08b, bloque01b y bloque06c |

La decisión de no incorporar un quiebre se revisó antes de continuar con outliers. La firma que se transmite identifica el ajuste de origen del 05; 06C mantiene su propio simulador y 07 sí utiliza la dinámica del modelo elegido. Definir una dependencia en el mapa no convierte la elección estadística en automática.

## Sintaxis para leer los bloques

`<-` asigna; `$` accede a campos y puede hacer coincidencia parcial; `[[nombre, exact=TRUE]]` exige el nombre exacto. `[filas,columnas,drop=FALSE]` conserva una matriz o tabla cuando se selecciona una sola columna. `seq_len(n)` recorre índices sin generar `1:0` si n es cero. `vapply()` exige un tipo de retorno y detecta resultados inesperados; `lapply()` devuelve listas. `rbind()` apila filas y `cbind()` combina columnas. `%*%` multiplica matrices. `qr()` verifica rango y `chol()` comprueba positividad definida. `stop()` detiene ante inconsistencia, mientras que `invisible()` devuelve un objeto sin imprimirlo automáticamente. `saveRDS()` guarda un objeto R completo y `readRDS()` lo recupera; un CSV no preserva clases, modelos ni toda la estructura de listas.

## Mapa del tramo

| Bloque | Tema | Líneas del script |
|---|---|---|
| 00 | Utilidades compartidas | 1–114 |
| 01 | Preparación y exploración de la muestra de desarrollo | 115–496 |
| 01B | Referencia automática inicial libre | 497–631 |
| 02A | Raíces unitarias estacionales: HEGY | 632–986 |
| 02B | Integración regular: ADF y KPSS con meses | 987–1364 |
| 03 | Identificación de la dinámica estacionaria | 1365–1648 |

## 00 — Utilidades compartidas

Las funciones auxiliares evitan repetir cálculos y formatos en cada etapa. Definir una función con `nombre <- function(...) { ... }` guarda instrucciones; no ejecuta todavía el análisis. Los bloques se llaman al final, cuando ya existen todas las funciones.

| Función | Qué hace y por qué está aquí |
|---|---|
| `bj_paquetes` | Comprueba dependencias con `requireNamespace`; un paquete faltante detiene la ejecución. No instala nada ni altera `renv.lock`. |
| `bj_csv`, `bj_figura` | Exportan tablas sin nombres de fila y figuras con dimensiones explícitas. Centralizar estas operaciones conserva nombres y formatos entre bloques. |
| `bj_juntar` | Combina listas de tablas; permite acumular resultados en bucles sin confundir cada intento con un modelo distinto. |
| `bj_lb` | Calcula Ljung–Box con el horizonte y los grados de libertad indicados; devuelve una referencia diagnóstica, no una certificación de independencia. |
| `bj_correlaciones` | Genera FAC/FACP, excluye el rezago cero y adjunta metadatos del candidato o tramo. Las bandas son individuales y aproximadas. |
| `bj_grafico_corr` | Grafica esas tablas en rezagos mensuales; el mismo formato facilita comparar candidatos. |
| `bj_multiplicar`, `bj_raices_coef` | Construyen los polinomios regulares y estacionales completos y calculan sus raíces; incluyen los productos multiplicativos. |

En un ARMA estacionario, las raíces del polinomio AR deben quedar fuera del círculo unitario; para invertibilidad se exige lo mismo al polinomio MA. Se inspeccionan módulos de raíces, no que cada coeficiente individual sea menor que uno. La raíz regular impuesta por `(1-L)` se trata por separado: estas funciones describen la parte ARMA estacionaria.

**Funciones de este tramo:** `bj_paquetes`, `bj_csv`, `bj_figura`, `bj_juntar`, `bj_lb`, `bj_correlaciones`, `bj_grafico_corr`, `bj_multiplicar`, `bj_raices_coef`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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








```

</details>

## 01 — Preparación y exploración de la muestra de desarrollo

**Entrada:** `database/forecasting.sqlite`, tabla `analitica_remision_mensual`. **Salida principal:** `bloque01`, con los datos preparados y las rutas de resultados.

1. Comprueba paquetes, raíz del proyecto y existencia de SQLite. `normalizePath()` fija una ruta válida; `file.path()` evita construir rutas con separadores específicos de Windows.
2. Abre SQLite en modo de lectura. La consulta SQL usa `WHERE fecha <= ?` con `params`: el corte se aplica antes de traer los datos a R. `on.exit()` garantiza cerrar la conexión incluso si falla la consulta.
3. Convierte fechas y exige un calendario mensual continuo, sin duplicados, fechas faltantes ni remisiones no positivas. No se imputan meses ni se corrigen datos silenciosamente.
4. Calcula días de cada mes por diferencia de fechas y divide litros mensuales por esos días. Después aplica logaritmo natural. La variable continúa teniendo **una observación por mes**: “diaria” significa promedio diario del mes.
5. Construye gráficos de evolución, estacionalidad y resúmenes. Separar litros mensuales, promedio diario y logaritmo permite distinguir duración del mes, estacionalidad y cambios relativos.
6. Guarda tablas, figuras, información de sesión y el objeto que alimenta los siguientes bloques. El recorrido no debe usar observaciones posteriores a septiembre de 2025.

La normalización por días no elimina por sí misma la estacionalidad productiva. El logaritmo convierte cambios multiplicativos en diferencias aditivas; una primera diferencia logarítmica aproxima una tasa de variación, pero no es un número de litros.

**Funciones de este tramo:** `ejecutar_bloque_01`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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


```

</details>

## 01B — Referencia automática inicial libre

`bj_ajustar_auto()` concentra la configuración de los dos auditores automáticos; `ejecutar_bloque_01b()` lo llama sobre el logaritmo en niveles y exporta la referencia inicial.

En 01B, el algoritmo puede elegir `d` y `D`, permite media/deriva cuando corresponde y no recibe los contrastes mensuales ni los efectos atípicos de la selección manual. Usa KPSS para la diferenciación regular y `seas` para la diferenciación estacional. `seas` se basa en fuerza estacional y **no es HEGY**. Se limita a `p,q <= 2`, `P,Q <= 1` y suma de órdenes dinámicos de hasta cinco, con `stepwise=FALSE`, `approximation=FALSE`, ML y AICc.

`do.call()` ejecuta una función con una lista de argumentos. `withCallingHandlers()` recoge advertencias sin perder su texto; `muffleWarning` evita que se impriman repetidamente, pero no borra el registro. Se estabilizan los datos almacenados en `fit$call`, `fit$x` y `fit$xreg` para no depender de variables locales al reutilizar el objeto.

La tabla incluye especificación, criterios de información, raíces, covarianzas, sigma y Ljung–Box. Esta referencia muestra qué produciría una búsqueda automática antes del análisis manual. Si elige otras diferencias o una muestra efectiva distinta, sus AICc/BIC no se mezclan en un único ranking con los manuales. La comparación verdaderamente condicionada aparece en 08B.

**Funciones de este tramo:** `bj_ajustar_auto`, `ejecutar_bloque_01b`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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




```

</details>

## 02A — Raíces unitarias estacionales: HEGY

**Entrada:** `bloque01`. **Pregunta:** ¿la persistencia estacional requiere una diferencia estacional, o puede representarse con componentes determinísticos y dinámica estacionaria?

Se comparan gráficamente el logaritmo, su primera diferencia regular y su diferencia a doce meses. Son representaciones exploratorias: calcularlas no significa decidir utilizarlas. El operador `1-L^12` también contiene el factor `1-L`; no representa solamente frecuencias estacionales.

HEGY separa la raíz de frecuencia cero de las distintas frecuencias estacionales. El script ejecuta constante+tendencia+meses como especificación principal y constante+tendencia sin meses como sensibilidad, cada una con selección de rezagos por AIC y BIC hasta 24. `deterministic=c(1,1,1)` activa esos tres grupos y `pvalue="RS"` solicita la aproximación de superficie de respuesta del paquete.

El bucle conserva estadísticos, valores p, orden auxiliar elegido, advertencias y FAC de las auxiliares. Se inspecciona si la elección llega al límite de rezagos y si persiste autocorrelación. Los rezagos de HEGY son correcciones auxiliares para el contraste; no fijan `p` ni `q` del futuro SARIMA. Ljung–Box se informa como orientativo con `fitdf=0`.

La decisión de trabajo que usa el recorrido posterior es `D=0`; el bloque conserva la evidencia para revisarla y no aplica una regla automática de “un valor p → un D”. Una estacionalidad fuerte y repetida no demuestra una raíz unitaria estacional.

**Funciones de este tramo:** `ejecutar_bloque_02a`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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


```

</details>

## 02B — Integración regular: ADF y KPSS con meses

**Entrada:** `bloque01`. Se evalúan tres representaciones: niveles con tendencia y meses; niveles con constante y meses; primera diferencia con constante y meses.

En ADF se estima `Delta y[t] = constante + rho*y[t-1] + tendencia opcional + meses + rezagos de Delta y + error`. La hipótesis nula sobre `rho` es raíz unitaria. `auxiliar_adf()` construye las columnas de rezagos respetando los índices temporales. AIC y BIC se comparan sobre una muestra común con `K=24`; luego el orden elegido se reestima con las observaciones que efectivamente permite ese orden. Así el criterio no recompensa un candidato porque descarte meses distintos.

`urca::ur.df()` suministra valores críticos de referencia; la regresión mensual se construye explícitamente. Esos valores no deben presentarse como una calibración exacta de cualquier extensión. Los residuos de las auxiliares se inspeccionan con FAC y Ljung–Box orientativo.

KPSS plantea la hipótesis nula complementaria de estacionariedad alrededor de los determinísticos especificados. Primero se retiran constante, meses y tendencia opcional; después se calculan las sumas acumuladas de residuos y su varianza de largo plazo con ponderación Bartlett. `short` y `long` son anchos de banda, no órdenes autorregresivos. Se emplean las tablas de referencia `mu/tau` de `urca` y se registra su carácter aproximado.

La lectura conjunta respalda la decisión de trabajo posterior `d=1`. Ni el rechazo de KPSS ni el no rechazo de ADF prueban por sí solos integración. Las hipótesis, sensibilidad a rezagos y residuos deben leerse conjuntamente. Los bloques posteriores usan esa decisión explícita y no vuelven a elegirla por optimización de AICc.

**Funciones de este tramo:** `ejecutar_bloque_02b`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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


```

</details>

## 03 — Identificación de la dinámica estacionaria

Se calcula `z=diff(x)` y se ajustan doce medias mensuales mediante `lm(diferencia_log ~ 0 + mes_factor)`. `0 +` elimina la constante y deja un coeficiente por mes. La deriva **descriptiva** es la media simple de esas doce medias; dar igual peso a los meses evita que los meses con una observación adicional alteren esa definición.

Al restar la deriva de cada media se obtienen doce cambios estacionales que suman cero. Restar únicamente esos cambios conserva la deriva; usar los residuos del ajuste mensual retira ambas partes y permite inspeccionar dependencia alrededor de cero. Esos residuos todavía no son innovaciones de un ARMA estimado.

La FAC/FACP antes y después del ajuste permite distinguir la repetición del perfil mensual de la dependencia estocástica. Se miran rezagos cortos y anuales, cortes y decaimientos, sin agregar un parámetro por cada barra que cruza una banda. Las bandas individuales tampoco equivalen a una prueba conjunta.

**Decisión:** comenzar con referencias parsimoniosas, sin declarar nula para siempre la parte regular. La revisión amplia de AR/MA debe hacerse en 05 y repetirse después de efectos en 08. Una FAC de rezago uno pequeña no autoriza omitir MA(1), MA(2) o modelos mixtos en toda la investigación. Deriva y meses se reestiman conjuntamente con la dinámica en el siguiente bloque.

**Funciones de este tramo:** `ejecutar_bloque_03`.

<details>
<summary>Código completo de este tramo del script</summary>

```r
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


```

</details>
