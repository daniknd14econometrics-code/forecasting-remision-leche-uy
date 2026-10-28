# ============================================================================
# Ejecución y validación de la transformación analítica en SQLite
# ============================================================================


# 1. Configuración general ----------------------------------------------------

raiz_proyecto <- normalizePath(
        ".",
        winslash = "/",
        mustWork = TRUE
)

if (basename(raiz_proyecto) != "forecasting-remision-leche-uy") {
        stop(
                "El script debe ejecutarse desde la raíz del proyecto."
        )
}

ruta_base_datos <- file.path(
        raiz_proyecto,
        "database",
        "forecasting.sqlite"
)

ruta_script_sql <- file.path(
        raiz_proyecto,
        "sql",
        "01_crear_tabla_analitica.sql"
)

rutas_necesarias <- c(
        "Base de datos SQLite" = ruta_base_datos,
        "Script SQL" = ruta_script_sql
)

archivos_faltantes <- names(rutas_necesarias)[
        !file.exists(rutas_necesarias)
]

if (length(archivos_faltantes) > 0L) {
        stop(
                "No se encontraron los siguientes elementos: ",
                paste(archivos_faltantes, collapse = ", "),
                "."
        )
}

message("Base de datos: ", ruta_base_datos)
message("Script SQL: ", ruta_script_sql)


# 2. Lectura y separación de las instrucciones SQL ---------------------------

leer_sentencias_sql <- function(ruta_sql) {
        lineas_sql <- readLines(
                ruta_sql,
                warn = FALSE,
                encoding = "UTF-8"
        )
        
        if (length(lineas_sql) == 0L) {
                stop("El archivo SQL está vacío.")
        }
        
        lineas_sql[[1]] <- sub(
                pattern = "^\ufeff",
                replacement = "",
                x = lineas_sql[[1]]
        )
        
        lineas_codigo <- lineas_sql[
                !grepl(
                        pattern = "^\\s*--",
                        x = lineas_sql
                )
        ]
        
        texto_sql <- paste(
                lineas_codigo,
                collapse = "\n"
        )
        
        sentencias_sql <- trimws(
                unlist(
                        strsplit(
                                texto_sql,
                                split = ";",
                                fixed = TRUE
                        ),
                        use.names = FALSE
                )
        )
        
        sentencias_sql <- sentencias_sql[
                nzchar(sentencias_sql)
        ]
        
        if (length(sentencias_sql) == 0L) {
                stop(
                        "No se encontraron instrucciones SQL ejecutables."
                )
        }
        
        sentencias_sql
}


# 3. Ejecución del archivo SQL ------------------------------------------------

ejecutar_archivo_sql <- function(ruta_bd, ruta_sql) {
        conexion <- DBI::dbConnect(
                RSQLite::SQLite(),
                dbname = ruta_bd
        )
        
        on.exit(
                DBI::dbDisconnect(conexion),
                add = TRUE
        )
        
        if (!DBI::dbExistsTable(
                conexion,
                "stg_remision_inale"
        )) {
                stop(
                        "No existe la tabla provisional stg_remision_inale. ",
                        "Debe ejecutarse primero R/03_cargar_staging_sqlite.R."
                )
        }
        
        sentencias_sql <- leer_sentencias_sql(
                ruta_sql
        )
        
        resultados_consultas <- list()
        contador_consultas <- 0L
        
        tryCatch(
                {
                        for (indice in seq_along(sentencias_sql)) {
                                sentencia <- sentencias_sql[[indice]]
                                
                                palabra_inicial <- toupper(
                                        strsplit(
                                                sentencia,
                                                split = "[[:space:]]+"
                                        )[[1]][[1]]
                                )
                                
                                message(
                                        "Ejecutando instrucción ",
                                        indice,
                                        " de ",
                                        length(sentencias_sql),
                                        ": ",
                                        palabra_inicial
                                )
                                
                                produce_resultado <- palabra_inicial %in% c(
                                        "SELECT",
                                        "WITH",
                                        "PRAGMA"
                                )
                                
                                if (produce_resultado) {
                                        contador_consultas <- contador_consultas + 1L
                                        
                                        resultados_consultas[[
                                                contador_consultas
                                        ]] <- DBI::dbGetQuery(
                                                conexion,
                                                sentencia
                                        )
                                } else {
                                        DBI::dbExecute(
                                                conexion,
                                                sentencia
                                        )
                                }
                        }
                },
                error = function(error_sql) {
                        try(
                                DBI::dbRollback(conexion),
                                silent = TRUE
                        )
                        
                        stop(
                                "Falló la ejecución del archivo SQL: ",
                                conditionMessage(error_sql),
                                call. = FALSE
                        )
                }
        )
        
        tabla_analitica_existe <- DBI::dbExistsTable(
                conexion,
                "analitica_remision_mensual"
        )
        
        columnas_analiticas <- if (
                tabla_analitica_existe
        ) {
                DBI::dbListFields(
                        conexion,
                        "analitica_remision_mensual"
                )
        } else {
                character()
        }
        
        list(
                resultados_consultas = resultados_consultas,
                tabla_analitica_existe = tabla_analitica_existe,
                columnas_analiticas = columnas_analiticas
        )
}


# 4. Ejecución de la transformación ------------------------------------------

ejecucion_sql <- ejecutar_archivo_sql(
        ruta_bd = ruta_base_datos,
        ruta_sql = ruta_script_sql
)


# 5. Identificación de los controles devueltos por SQL ------------------------

if (
        length(ejecucion_sql$resultados_consultas) != 3L
) {
        stop(
                "Se esperaban tres consultas de control, pero se obtuvieron ",
                length(ejecucion_sql$resultados_consultas),
                "."
        )
}

control_filas <- ejecucion_sql$resultados_consultas[[1]]
control_valores <- ejecucion_sql$resultados_consultas[[2]]
control_continuidad <- ejecucion_sql$resultados_consultas[[3]]


# 6. Validación de la estructura de la tabla ----------------------------------

if (!ejecucion_sql$tabla_analitica_existe) {
        stop(
                "La tabla analitica_remision_mensual no fue creada."
        )
}

columnas_esperadas <- c(
        "fecha",
        "anio",
        "mes",
        "remision_litros",
        "remision_millones_litros",
        "remision_kilos_solidos",
        "grasa_porcentaje",
        "proteina_porcentaje",
        "observacion_origen",
        "archivo_origen",
        "fecha_carga_utc"
)

if (!identical(
        ejecucion_sql$columnas_analiticas,
        columnas_esperadas
)) {
        stop(
                "Las columnas de la tabla analítica no coinciden ",
                "con la estructura esperada."
        )
}


# 7. Validación de la cantidad de filas ---------------------------------------

columnas_control_filas <- c(
        "filas_staging",
        "filas_analiticas",
        "control_filas",
        "fecha_min",
        "fecha_max"
)

if (
        nrow(control_filas) != 1L ||
        !all(
                columnas_control_filas %in%
                names(control_filas)
        )
) {
        stop(
                "La consulta de control de filas no tiene ",
                "la estructura esperada."
        )
}

if (
        as.character(
                control_filas$control_filas[[1]]
        ) != "OK"
) {
        stop(
                "La cantidad de filas de las tablas provisional ",
                "y analítica no coincide."
        )
}


# 8. Validación de valores imposibles -----------------------------------------

columnas_control_valores <- c(
        "fechas_nulas",
        "fechas_duplicadas",
        "valores_no_positivos",
        "porcentajes_invalidos"
)

if (
        nrow(control_valores) != 1L ||
        !all(
                columnas_control_valores %in%
                names(control_valores)
        )
) {
        stop(
                "La consulta de control de valores no tiene ",
                "la estructura esperada."
        )
}

conteos_problemas <- vapply(
        control_valores[
                1,
                columnas_control_valores,
                drop = FALSE
        ],
        function(variable) {
                as.numeric(variable[[1]])
        },
        numeric(1)
)

if (
        anyNA(conteos_problemas) ||
        any(conteos_problemas != 0)
) {
        stop(
                "La tabla analítica contiene valores inválidos. ",
                "Revise la consulta de control."
        )
}


# 9. Validación de la continuidad mensual -------------------------------------

if (nrow(control_continuidad) != 0L) {
        stop(
                "La serie contiene uno o más meses faltantes."
        )
}


# 10. Presentación de los resultados ------------------------------------------

message("")
message("Control 1: cantidad de filas y periodo")

print(
        control_filas,
        row.names = FALSE
)

message("")
message("Control 2: valores inválidos")

print(
        control_valores,
        row.names = FALSE
)

message("")
message("Control 3: continuidad mensual")

if (nrow(control_continuidad) == 0L) {
        message(
                "No se encontraron meses faltantes."
        )
} else {
        print(
                control_continuidad,
                row.names = FALSE
        )
}

message("")
message(
        "Tabla analítica creada y validada correctamente: ",
        "analitica_remision_mensual"
)
