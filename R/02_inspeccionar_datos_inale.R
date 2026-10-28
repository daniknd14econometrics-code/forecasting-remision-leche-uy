# 1. Localización de la copia original más reciente ----------------------

raiz_proyecto <- normalizePath(
        ".",
        winslash = "/",
        mustWork = TRUE
)

if (basename(raiz_proyecto) != "forecasting-remision-leche-uy") {
        stop("El script debe ejecutarse desde la raíz del proyecto.")
}

carpeta_original <- file.path(
        raiz_proyecto,
        "data",
        "original"
)

patron_archivo <- paste0(
        "^remision_a_planta_inale_",
        "[0-9]{4}-[0-9]{2}-[0-9]{2}",
        "\\.xlsx?$"
)

archivos_originales <- list.files(
        path = carpeta_original,
        pattern = patron_archivo,
        full.names = TRUE,
        ignore.case = TRUE
)

if (length(archivos_originales) == 0L) {
        stop("No se encontró ninguna copia original de los datos de INALE.")
}

ruta_archivo_original <- sort(
        archivos_originales,
        decreasing = TRUE
)[[1]]

message("Archivo seleccionado: ", ruta_archivo_original)


# 2. Identificación y validación de las hojas ----------------------------

hojas_excel <- readxl::excel_sheets(
        path = ruta_archivo_original
)

hojas_principales <- c(
        "Remisión a planta",
        "Composición de la leche",
        "Listado Datos"
)

hojas_faltantes <- setdiff(
        hojas_principales,
        hojas_excel
)

if (length(hojas_faltantes) > 0L) {
        stop(
                "Faltan las siguientes hojas esperadas: ",
                paste(hojas_faltantes, collapse = ", "),
                "."
        )
}

message(
        "Hojas encontradas: ",
        paste(hojas_excel, collapse = " | ")
)


# 3. Vista preliminar de la hoja Listado Datos ---------------------------

vista_listado_datos <- readxl::read_excel(
        path = ruta_archivo_original,
        sheet = "Listado Datos",
        col_names = FALSE,
        n_max = 15
)

print(
        vista_listado_datos,
        n = Inf,
        width = Inf
)

# 4. Lectura del rectángulo de datos -------------------------------------

tabla_listado_texto <- readxl::read_excel(
        path = ruta_archivo_original,
        range = cellranger::cell_limits(
                ul = c(5, 2),
                lr = c(NA, 7),
                sheet = "Listado Datos"
        ),
        col_types = "text",
        na = c("", "NA"),
        trim_ws = TRUE
)

fecha_excel_numerica <- suppressWarnings(
        as.numeric(tabla_listado_texto$Fecha)
)

filas_mensuales <- !is.na(fecha_excel_numerica)

datos_inale_brutos <- tabla_listado_texto[
        filas_mensuales,
        ,
        drop = FALSE
]

fechas_calendario <- as.Date(
        fecha_excel_numerica[filas_mensuales],
        origin = "1899-12-30"
)

message(
        "Observaciones mensuales válidas: ",
        nrow(datos_inale_brutos),
        "."
)

message(
        "Periodo disponible: ",
        min(fechas_calendario),
        " a ",
        max(fechas_calendario),
        "."
)

message(
        "Filas no tabulares excluidas: ",
        sum(!filas_mensuales),
        "."
)

message("Primeras tres observaciones:")
print(
        head(datos_inale_brutos, 3),
        n = Inf,
        width = Inf
)

message("Últimas tres observaciones:")
print(
        tail(datos_inale_brutos, 3),
        n = Inf,
        width = Inf
)
