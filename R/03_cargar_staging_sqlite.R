# 1. Obtención de los datos inspeccionados -------------------------------

source(
        file.path("R", "02_inspeccionar_datos_inale.R"),
        echo = FALSE
)


# 2. Función para convertir variables numéricas --------------------------

convertir_numerico <- function(x, nombre_variable) {
        resultado <- suppressWarnings(
                as.numeric(x)
        )
        
        if (anyNA(resultado)) {
                filas_problematicas <- which(is.na(resultado))
                
                stop(
                        "No se pudo convertir la variable ",
                        nombre_variable,
                        " en las filas: ",
                        paste(filas_problematicas, collapse = ", "),
                        "."
                )
        }
        
        resultado
}


# 3. Conversión y normalización de variables -----------------------------

remision_litros <- convertir_numerico(
        datos_inale_brutos[["Remisión (litros)"]],
        "remision_litros"
)

remision_kilos_solidos <- convertir_numerico(
        datos_inale_brutos[["Remisión (kilos sólidos)"]],
        "remision_kilos_solidos"
)

grasa_proporcion <- convertir_numerico(
        datos_inale_brutos[["Contenido de Grasa (%)"]],
        "grasa_proporcion"
)

proteina_proporcion <- convertir_numerico(
        datos_inale_brutos[["Contenido de Proteína (%)"]],
        "proteina_proporcion"
)

observacion_origen <- datos_inale_brutos[["Observaciones"]]

observacion_origen[
        is.na(observacion_origen) |
                trimws(observacion_origen) == ""
] <- NA_character_


# 4. Construcción de la tabla provisional --------------------------------

datos_staging <- data.frame(
        fecha_excel = fecha_excel_numerica[filas_mensuales],
        fecha = format(fechas_calendario, "%Y-%m-%d"),
        remision_litros = remision_litros,
        remision_kilos_solidos = remision_kilos_solidos,
        grasa_proporcion = grasa_proporcion,
        proteina_proporcion = proteina_proporcion,
        observacion_origen = observacion_origen,
        archivo_origen = basename(ruta_archivo_original),
        fecha_carga_utc = format(
                Sys.time(),
                tz = "UTC",
                usetz = TRUE
        ),
        stringsAsFactors = FALSE
)

datos_staging <- datos_staging[
        order(datos_staging$fecha),
        ,
        drop = FALSE
]

row.names(datos_staging) <- NULL

message(
        "Tabla provisional preparada: ",
        nrow(datos_staging),
        " filas y ",
        ncol(datos_staging),
        " columnas."
)

str(datos_staging)

message("Primeras dos filas:")
print(
        head(datos_staging, 2),
        row.names = FALSE
)

message("Últimas dos filas:")
print(
        tail(datos_staging, 2),
        row.names = FALSE
)

# 5. Carga de la tabla provisional en SQLite -----------------------------

ruta_base_datos <- file.path(
        raiz_proyecto,
        "database",
        "forecasting.sqlite"
)

dir.create(
        dirname(ruta_base_datos),
        recursive = TRUE,
        showWarnings = FALSE
)

cargar_staging_sqlite <- function(datos, ruta_bd) {
        conexion <- DBI::dbConnect(
                RSQLite::SQLite(),
                dbname = ruta_bd
        )
        
        on.exit(
                DBI::dbDisconnect(conexion),
                add = TRUE
        )
        
        DBI::dbWriteTable(
                conn = conexion,
                name = "stg_remision_inale",
                value = datos,
                overwrite = TRUE,
                row.names = FALSE
        )
        
        resumen <- DBI::dbGetQuery(
                conexion,
                paste(
                        "SELECT",
                        "COUNT(*) AS filas,",
                        "MIN(fecha) AS fecha_min,",
                        "MAX(fecha) AS fecha_max",
                        "FROM stg_remision_inale;"
                )
        )
        
        esquema <- DBI::dbGetQuery(
                conexion,
                "PRAGMA table_info(stg_remision_inale);"
        )
        
        list(
                resumen = resumen,
                esquema = esquema
        )
}

resultado_carga <- cargar_staging_sqlite(
        datos = datos_staging,
        ruta_bd = ruta_base_datos
)

if (resultado_carga$resumen$filas[[1]] != nrow(datos_staging)) {
        stop(
                "La cantidad de filas guardadas en SQLite no coincide ",
                "con la tabla preparada en R."
        )
}

message("Base SQLite creada: ", ruta_base_datos)
message("Resumen de la tabla provisional:")

print(
        resultado_carga$resumen,
        row.names = FALSE
)

message("Esquema creado por SQLite:")

print(
        resultado_carga$esquema,
        row.names = FALSE
)

