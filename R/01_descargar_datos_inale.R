# 1. Configuración general -----------------------------------------------

raiz_proyecto <- normalizePath(
        ".",
        winslash = "/",
        mustWork = TRUE
)

if (basename(raiz_proyecto) != "forecasting-remision-leche-uy") {
        stop("El script debe ejecutarse desde la raíz del proyecto.")
}

pagina_inale <- paste0(
        "https://www.inale.org/estadisticas/",
        "remision-a-planta/"
)

carpeta_original <- file.path(
        raiz_proyecto,
        "data",
        "original"
)

fecha_descarga <- Sys.Date()

dir.create(
        carpeta_original,
        recursive = TRUE,
        showWarnings = FALSE
)

message("Proyecto: ", raiz_proyecto)
message("Fuente oficial: ", pagina_inale)
message("Carpeta de destino: ", carpeta_original)
message("Fecha de ejecución: ", fecha_descarga)

# 2. Localización del archivo Excel --------------------------------------

archivo_html_temporal <- tempfile(fileext = ".html")

download.file(
        url = pagina_inale,
        destfile = archivo_html_temporal,
        mode = "wb",
        quiet = TRUE
)

html_inale <- paste(
        readLines(
                archivo_html_temporal,
                warn = FALSE,
                encoding = "UTF-8"
        ),
        collapse = "\n"
)

patron_excel <- "https?://[^\"'[:space:]<>]+\\.xlsx?"

coincidencias <- regmatches(
        html_inale,
        gregexpr(
                pattern = patron_excel,
                text = html_inale,
                ignore.case = TRUE,
                perl = TRUE
        )
)[[1]]

enlaces_excel <- unique(coincidencias)

if (length(enlaces_excel) != 1L) {
        stop(
                "Se esperaba encontrar un único archivo Excel en la página de INALE, ",
                "pero se encontraron: ",
                length(enlaces_excel),
                "."
        )
}

url_excel <- enlaces_excel[[1]]

unlink(archivo_html_temporal)

message("Archivo Excel localizado: ", url_excel)


# 3. Descarga de la copia original ---------------------------------------

extension_excel <- if (
        grepl("\\.xlsx$", url_excel, ignore.case = TRUE)
) {
        ".xlsx"
} else {
        ".xls"
}

nombre_archivo <- paste0(
        "remision_a_planta_inale_",
        format(fecha_descarga, "%Y-%m-%d"),
        extension_excel
)

ruta_archivo_original <- file.path(
        carpeta_original,
        nombre_archivo
)

if (!file.exists(ruta_archivo_original)) {
        download.file(
                url = url_excel,
                destfile = ruta_archivo_original,
                mode = "wb",
                quiet = FALSE
        )
        
        message("Archivo descargado: ", ruta_archivo_original)
} else {
        message("La copia original ya existe: ", ruta_archivo_original)
}

tamano_archivo <- file.info(ruta_archivo_original)$size

if (is.na(tamano_archivo) || tamano_archivo <= 0) {
        stop("El archivo descargado no existe o está vacío.")
}

message(
        "Tamaño del archivo: ",
        format(
                tamano_archivo,
                big.mark = ".",
                decimal.mark = ",",
                scientific = FALSE,
                trim = TRUE
        ),
        " bytes"
)


