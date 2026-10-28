# ============================================================================
# Preparación y exploración inicial de la serie de remisión de leche
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

if (!requireNamespace(
        "ggplot2",
        quietly = TRUE
)) {
        stop(
                "El paquete ggplot2 no está instalado. ",
                "Debe instalarse antes de ejecutar este script."
        )
}

ruta_base_datos <- file.path(
        raiz_proyecto,
        "database",
        "forecasting.sqlite"
)

carpeta_figuras <- file.path(
        raiz_proyecto,
        "outputs",
        "figures"
)

carpeta_tablas <- file.path(
        raiz_proyecto,
        "outputs",
        "tables"
)

if (!file.exists(ruta_base_datos)) {
        stop(
                "No se encontró la base database/forecasting.sqlite. ",
                "Debe ejecutarse primero el proceso de carga y transformación."
        )
}

dir.create(
        carpeta_figuras,
        recursive = TRUE,
        showWarnings = FALSE
)

dir.create(
        carpeta_tablas,
        recursive = TRUE,
        showWarnings = FALSE
)


# 2. Lectura de la tabla analítica --------------------------------------------

leer_tabla_analitica <- function(ruta_bd) {
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
                "analitica_remision_mensual"
        )) {
                stop(
                        "No existe la tabla analitica_remision_mensual. ",
                        "Debe ejecutarse primero R/04_ejecutar_sql_analitico.R."
                )
        }
        
        DBI::dbGetQuery(
                conexion,
                paste(
                        "SELECT",
                        "fecha,",
                        "anio,",
                        "mes,",
                        "remision_litros,",
                        "remision_millones_litros,",
                        "remision_kilos_solidos,",
                        "grasa_porcentaje,",
                        "proteina_porcentaje,",
                        "observacion_origen,",
                        "archivo_origen,",
                        "fecha_carga_utc",
                        "FROM analitica_remision_mensual",
                        "ORDER BY fecha;"
                )
        )
}

datos_serie <- leer_tabla_analitica(
        ruta_base_datos
)


# 3. Validación de la información leída ---------------------------------------

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
        names(datos_serie),
        columnas_esperadas
)) {
        stop(
                "Las columnas leídas desde SQLite no coinciden ",
                "con la estructura esperada."
        )
}

datos_serie$fecha <- as.Date(
        datos_serie$fecha
)

if (anyNA(datos_serie$fecha)) {
        stop(
                "Una o más fechas no pudieron convertirse al tipo Date."
        )
}

datos_serie <- datos_serie[
        order(datos_serie$fecha),
        ,
        drop = FALSE
]

row.names(datos_serie) <- NULL

if (anyDuplicated(datos_serie$fecha) > 0L) {
        stop(
                "La tabla contiene fechas duplicadas."
        )
}

fechas_esperadas <- seq(
        from = min(datos_serie$fecha),
        to = max(datos_serie$fecha),
        by = "month"
)

if (
        length(fechas_esperadas) != nrow(datos_serie) ||
        !identical(
                datos_serie$fecha,
                fechas_esperadas
        )
) {
        stop(
                "Las fechas no forman una secuencia mensual completa."
        )
}

if (
        anyNA(datos_serie$remision_litros) ||
        any(datos_serie$remision_litros <= 0)
) {
        stop(
                "La remisión mensual contiene valores ausentes ",
                "o no positivos."
        )
}


# 4. Ajuste por cantidad de días del mes --------------------------------------

primer_dia_mes_siguiente <- as.Date(
        format(
                datos_serie$fecha + 32,
                "%Y-%m-01"
        )
)

datos_serie$dias_mes <- as.integer(
        primer_dia_mes_siguiente -
                datos_serie$fecha
)

if (
        anyNA(datos_serie$dias_mes) ||
        any(
                !datos_serie$dias_mes %in%
                c(28L, 29L, 30L, 31L)
        )
) {
        stop(
                "No fue posible calcular correctamente ",
                "la cantidad de días de uno o más meses."
        )
}

datos_serie$remision_litros_dia <-
        datos_serie$remision_litros /
        datos_serie$dias_mes

datos_serie$remision_millones_dia <-
        datos_serie$remision_litros_dia /
        1000000

datos_serie$log_remision_litros_dia <- log(
        datos_serie$remision_litros_dia
)


# 5. Creación de los objetos de serie temporal --------------------------------

inicio_serie <- c(
        datos_serie$anio[[1]],
        datos_serie$mes[[1]]
)

serie_remision_mensual <- stats::ts(
        datos_serie$remision_millones_litros,
        start = inicio_serie,
        frequency = 12
)

serie_remision_diaria <- stats::ts(
        datos_serie$remision_millones_dia,
        start = inicio_serie,
        frequency = 12
)

serie_log_remision_diaria <- stats::ts(
        datos_serie$log_remision_litros_dia,
        start = inicio_serie,
        frequency = 12
)

if (
        length(serie_remision_mensual) !=
        nrow(datos_serie) ||
        length(serie_remision_diaria) !=
        nrow(datos_serie) ||
        length(serie_log_remision_diaria) !=
        nrow(datos_serie)
) {
        stop(
                "La longitud de los objetos ts no coincide ",
                "con la cantidad de observaciones."
        )
}

if (
        stats::frequency(serie_remision_mensual) != 12 ||
        stats::frequency(serie_remision_diaria) != 12 ||
        stats::frequency(serie_log_remision_diaria) != 12
) {
        stop(
                "La frecuencia de una o más series no es mensual."
        )
}


# 6. Tabla de auditoría de la serie -------------------------------------------

auditoria_serie <- data.frame(
        indicador = c(
                "Observaciones",
                "Fecha inicial",
                "Fecha final",
                "Frecuencia anual",
                "Meses faltantes",
                "Fechas duplicadas",
                "Mínimo de días por mes",
                "Máximo de días por mes"
        ),
        valor = c(
                as.character(nrow(datos_serie)),
                as.character(min(datos_serie$fecha)),
                as.character(max(datos_serie$fecha)),
                as.character(
                        stats::frequency(
                                serie_remision_mensual
                        )
                ),
                "0",
                "0",
                as.character(min(datos_serie$dias_mes)),
                as.character(max(datos_serie$dias_mes))
        ),
        stringsAsFactors = FALSE
)


# 7. Resumen descriptivo -------------------------------------------------------

resumir_serie <- function(nombre_serie, valores) {
        cuantiles <- stats::quantile(
                valores,
                probs = c(0.25, 0.75),
                names = FALSE,
                na.rm = TRUE
        )
        
        data.frame(
                serie = nombre_serie,
                observaciones = length(valores),
                minimo = min(valores),
                primer_cuartil = cuantiles[[1]],
                media = mean(valores),
                mediana = stats::median(valores),
                tercer_cuartil = cuantiles[[2]],
                maximo = max(valores),
                desviacion_estandar = stats::sd(valores),
                stringsAsFactors = FALSE
        )
}

resumen_descriptivo <- rbind(
        resumir_serie(
                "Remisión mensual: millones de litros",
                datos_serie$remision_millones_litros
        ),
        resumir_serie(
                "Remisión media diaria: millones de litros",
                datos_serie$remision_millones_dia
        ),
        resumir_serie(
                "Logaritmo de la remisión media diaria",
                datos_serie$log_remision_litros_dia
        )
)

row.names(resumen_descriptivo) <- NULL


# 8. Perfil estacional descriptivo --------------------------------------------

perfil_estacional <- stats::aggregate(
        cbind(
                remision_millones_litros,
                remision_millones_dia
        ) ~ mes,
        data = datos_serie,
        FUN = mean
)

nombres_meses <- c(
        "Enero",
        "Febrero",
        "Marzo",
        "Abril",
        "Mayo",
        "Junio",
        "Julio",
        "Agosto",
        "Septiembre",
        "Octubre",
        "Noviembre",
        "Diciembre"
)

perfil_estacional$nombre_mes <-
        nombres_meses[
                perfil_estacional$mes
        ]

perfil_estacional <- perfil_estacional[
        ,
        c(
                "mes",
                "nombre_mes",
                "remision_millones_litros",
                "remision_millones_dia"
        )
]


# 9. Guardado de tablas --------------------------------------------------------

ruta_auditoria <- file.path(
        carpeta_tablas,
        "01_auditoria_serie.csv"
)

ruta_resumen <- file.path(
        carpeta_tablas,
        "02_resumen_descriptivo_serie.csv"
)

ruta_perfil <- file.path(
        carpeta_tablas,
        "03_perfil_estacional.csv"
)

utils::write.csv(
        auditoria_serie,
        file = ruta_auditoria,
        row.names = FALSE,
        fileEncoding = "UTF-8"
)

utils::write.csv(
        resumen_descriptivo,
        file = ruta_resumen,
        row.names = FALSE,
        fileEncoding = "UTF-8"
)

utils::write.csv(
        perfil_estacional,
        file = ruta_perfil,
        row.names = FALSE,
        fileEncoding = "UTF-8"
)


# 10. Gráfico de remisión mensual y diaria ------------------------------------

datos_grafico_escalas <- rbind(
        data.frame(
                fecha = datos_serie$fecha,
                valor = datos_serie$remision_millones_litros,
                serie = "Remisión mensual",
                stringsAsFactors = FALSE
        ),
        data.frame(
                fecha = datos_serie$fecha,
                valor = datos_serie$remision_millones_dia,
                serie = "Remisión media diaria",
                stringsAsFactors = FALSE
        )
)

grafico_escalas <- ggplot2::ggplot(
        datos_grafico_escalas,
        ggplot2::aes(
                x = fecha,
                y = valor
        )
) +
        ggplot2::geom_line(
                colour = "#006D77",
                linewidth = 0.65
        ) +
        ggplot2::facet_wrap(
                ~ serie,
                ncol = 1,
                scales = "free_y"
        ) +
        ggplot2::labs(
                title = "Remisión de leche a plantas industriales",
                subtitle = paste(
                        "Comparación entre el total mensual y la intensidad media diaria.",
                        "Uruguay, 2002–2026."
                ),
                x = NULL,
                y = "Millones de litros"
        ) +
        ggplot2::theme_minimal(
                base_size = 11
        ) +
        ggplot2::theme(
                panel.grid.minor =
                        ggplot2::element_blank(),
                plot.title =
                        ggplot2::element_text(
                                face = "bold"
                        )
        )


# 11. Gráfico del perfil estacional -------------------------------------------

grafico_estacional <- ggplot2::ggplot(
        perfil_estacional,
        ggplot2::aes(
                x = mes,
                y = remision_millones_dia
        )
) +
        ggplot2::geom_line(
                colour = "#BB3E03",
                linewidth = 0.9
        ) +
        ggplot2::geom_point(
                colour = "#BB3E03",
                size = 2.5
        ) +
        ggplot2::scale_x_continuous(
                breaks = 1:12,
                labels = substr(
                        nombres_meses,
                        1,
                        3
                )
        ) +
        ggplot2::labs(
                title = "Perfil estacional de la remisión media diaria",
                subtitle = paste(
                        "Promedio histórico por mes.",
                        "La corrección por días no elimina la estacionalidad productiva."
                ),
                x = "Mes",
                y = "Millones de litros por día"
        ) +
        ggplot2::theme_minimal(
                base_size = 11
        ) +
        ggplot2::theme(
                panel.grid.minor =
                        ggplot2::element_blank(),
                plot.title =
                        ggplot2::element_text(
                                face = "bold"
                        )
        )


# 12. Mapa de la evolución estacional -----------------------------------------

datos_serie$mes_factor <- factor(
        datos_serie$mes,
        levels = 1:12,
        labels = substr(
                nombres_meses,
                1,
                3
        )
)

datos_serie$anio_factor <- factor(
        datos_serie$anio,
        levels = rev(
                sort(
                        unique(datos_serie$anio)
                )
        )
)

grafico_mapa <- ggplot2::ggplot(
        datos_serie,
        ggplot2::aes(
                x = mes_factor,
                y = anio_factor,
                fill = remision_millones_dia
        )
) +
        ggplot2::geom_tile(
                colour = "white",
                linewidth = 0.15
        ) +
        ggplot2::scale_fill_gradient(
                low = "#E9F2F2",
                high = "#005F73"
        ) +
        ggplot2::labs(
                title = "Evolución de la remisión media diaria",
                subtitle = "La intensidad del color representa millones de litros por día.",
                x = "Mes",
                y = "Año",
                fill = "Millones\nde litros\ndiarios"
        ) +
        ggplot2::theme_minimal(
                base_size = 10
        ) +
        ggplot2::theme(
                panel.grid =
                        ggplot2::element_blank(),
                plot.title =
                        ggplot2::element_text(
                                face = "bold"
                        )
        )


# 13. Guardado de gráficos -----------------------------------------------------

ruta_grafico_escalas <- file.path(
        carpeta_figuras,
        "01_remision_mensual_vs_diaria.png"
)

ruta_grafico_estacional <- file.path(
        carpeta_figuras,
        "02_perfil_estacional_remision_diaria.png"
)

ruta_grafico_mapa <- file.path(
        carpeta_figuras,
        "03_mapa_estacional_remision_diaria.png"
)

ggplot2::ggsave(
        filename = ruta_grafico_escalas,
        plot = grafico_escalas,
        width = 11,
        height = 7,
        units = "in",
        dpi = 300
)

ggplot2::ggsave(
        filename = ruta_grafico_estacional,
        plot = grafico_estacional,
        width = 10,
        height = 6,
        units = "in",
        dpi = 300
)

ggplot2::ggsave(
        filename = ruta_grafico_mapa,
        plot = grafico_mapa,
        width = 11,
        height = 8,
        units = "in",
        dpi = 300
)


# 14. Presentación de resultados ----------------------------------------------

message("")
message("Auditoría de la serie:")

print(
        auditoria_serie,
        row.names = FALSE
)

message("")
message("Resumen descriptivo:")

print(
        resumen_descriptivo,
        row.names = FALSE
)

message("")
message("Perfil estacional medio:")

print(
        perfil_estacional,
        row.names = FALSE
)

message("")
message("Tablas guardadas en: ", carpeta_tablas)
message("Gráficos guardados en: ", carpeta_figuras)

message("")
message(
        "Preparación y exploración inicial ",
        "completadas correctamente."
)