# Preparación y exploración inicial de la serie mensual

## Objetivo

Este documento explica cómo se lee desde SQLite la tabla `analitica_remision_mensual`, cómo se construyen los objetos de serie temporal y cómo se realiza una primera exploración descriptiva.

El script se encuentra en:

```text
R/05_preparar_explorar_serie.R
```

La fuente utilizada por el script es:

```text
database/forecasting.sqlite
└── analitica_remision_mensual
```

En esta etapa todavía no se estima ningún modelo SARIMA.

## Relación con el taller 05B

El taller original 05B distingue entre:

- el total remitido durante un mes;
- la intensidad media remitida por día.

Esta distinción es importante porque los meses tienen diferente duración.

Por ejemplo, aunque la intensidad productiva fuera idéntica, un mes de 31 días podría mostrar una remisión total superior a la de febrero simplemente porque contiene más días.

Por ese motivo se construye:

```text
remisión media diaria =
remisión mensual / cantidad de días del mes
```

Posteriormente, un pronóstico de intensidad diaria puede volver a expresarse como total mensual multiplicándolo por la cantidad de días del mes pronosticado.

La corrección por días no elimina necesariamente la estacionalidad productiva. Solamente elimina una diferencia mecánica de calendario.

## Variables preparadas

El script conserva o construye tres representaciones principales:

1. `remision_millones_litros`: total mensual.
2. `remision_millones_dia`: intensidad media diaria.
3. `log_remision_litros_dia`: logaritmo de la intensidad diaria.

Todavía no se elige definitivamente cuál será modelada. Esa decisión requerirá examinar tendencia, varianza, estacionalidad, integración y desempeño predictivo.

## 1. Configuración general

### Código

```r
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
```

### Explicación general

Se identifica la carpeta principal y se comprueba que el script se ejecute dentro del proyecto.

### Explicación línea por línea

- `"."` representa la carpeta de trabajo actual.
- `normalizePath()` obtiene su ruta completa.
- `winslash = "/"` normaliza las barras.
- `mustWork = TRUE` exige que la carpeta exista.
- `basename()` recupera el nombre final.
- `stop()` interrumpe el proceso si no coincide.

## 2. Comprobación de `ggplot2`

### Código

```r
if (!requireNamespace(
  "ggplot2",
  quietly = TRUE
)) {
  stop(
    "El paquete ggplot2 no está instalado. ",
    "Debe instalarse antes de ejecutar este script."
  )
}
```

### Explicación

- `requireNamespace()` comprueba si el paquete está disponible.
- `quietly = TRUE` evita mensajes innecesarios.
- `!` invierte la condición.
- El script no instala paquetes automáticamente.
- Si falta `ggplot2`, se detiene y solicita su instalación.

Esta separación evita que un script analítico modifique el entorno sin intervención del usuario.

## 3. Definición de rutas y carpetas

### Código

```r
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
```

### Explicación

Se definen:

- la base SQLite;
- la carpeta de gráficos;
- la carpeta de tablas.

### Código

```r
if (!file.exists(ruta_base_datos)) {
  stop(
    "No se encontró la base database/forecasting.sqlite. ",
    "Debe ejecutarse primero el proceso de carga y transformación."
  )
}
```

`file.exists()` comprueba que la base haya sido creada.

### Código

```r
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
```

- `dir.create()` crea las carpetas si no existen.
- `recursive = TRUE` permite crear niveles superiores.
- `showWarnings = FALSE` evita avisos cuando ya existen.

## 4. Lectura de la tabla analítica

### Código

```r
leer_tabla_analitica <- function(ruta_bd) {
  conexion <- DBI::dbConnect(
    RSQLite::SQLite(),
    dbname = ruta_bd
  )

  on.exit(
    DBI::dbDisconnect(conexion),
    add = TRUE
  )
```

### Explicación

Se define una función que:

1. abre SQLite;
2. obtiene la tabla;
3. cierra la conexión.

`on.exit()` garantiza el cierre incluso si aparece un error.

### Comprobación de la tabla

```r
if (!DBI::dbExistsTable(
  conexion,
  "analitica_remision_mensual"
)) {
  stop(
    "No existe la tabla analitica_remision_mensual. ",
    "Debe ejecutarse primero R/04_ejecutar_sql_analitico.R."
  )
}
```

El proceso no continúa si falta la tabla creada en la etapa anterior.

### Consulta SQL

```r
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
```

### Explicación línea por línea

- `dbGetQuery()` ejecuta SQL y devuelve un `data.frame`.
- `SELECT` elige las columnas.
- `FROM` identifica la tabla.
- `ORDER BY fecha` exige el orden cronológico.
- `paste()` une las partes en una consulta.

### Ejecución de la función

```r
datos_serie <- leer_tabla_analitica(
  ruta_base_datos
)
```

La información queda almacenada en `datos_serie`.

## 5. Validación de la información

### Estructura esperada

```r
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
```

Se enumeran nombres y orden esperados.

```r
if (!identical(
  names(datos_serie),
  columnas_esperadas
)) {
  stop(
    "Las columnas leídas desde SQLite no coinciden ",
    "con la estructura esperada."
  )
}
```

`identical()` exige coincidencia exacta.

### Conversión de la fecha

```r
datos_serie$fecha <- as.Date(
  datos_serie$fecha
)
```

SQLite guardó las fechas como texto. `as.Date()` las convierte en fechas de R.

```r
if (anyNA(datos_serie$fecha)) {
  stop(
    "Una o más fechas no pudieron convertirse al tipo Date."
  )
}
```

`anyNA()` detecta conversiones fallidas.

### Ordenamiento

```r
datos_serie <- datos_serie[
  order(datos_serie$fecha),
  ,
  drop = FALSE
]

row.names(datos_serie) <- NULL
```

- `order()` ordena cronológicamente.
- `drop = FALSE` mantiene la tabla.
- Se eliminan los nombres internos de fila.

### Duplicados

```r
if (anyDuplicated(datos_serie$fecha) > 0L) {
  stop(
    "La tabla contiene fechas duplicadas."
  )
}
```

`anyDuplicated()` devuelve cero cuando no encuentra duplicados.

### Secuencia mensual esperada

```r
fechas_esperadas <- seq(
  from = min(datos_serie$fecha),
  to = max(datos_serie$fecha),
  by = "month"
)
```

`seq()` construye todos los meses entre la primera y la última fecha.

```r
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
```

Se comparan cantidad, orden y contenido.

### Validación de la variable objetivo

```r
if (
  anyNA(datos_serie$remision_litros) ||
  any(datos_serie$remision_litros <= 0)
) {
  stop(
    "La remisión mensual contiene valores ausentes ",
    "o no positivos."
  )
}
```

La serie no puede contener valores ausentes, iguales a cero o negativos.

## 6. Cantidad de días del mes

### Código

```r
primer_dia_mes_siguiente <- as.Date(
  format(
    datos_serie$fecha + 32,
    "%Y-%m-01"
  )
)
```

### Explicación

Cada fecha corresponde al primer día de un mes.

- Se agregan 32 días para asegurar el paso al mes siguiente.
- `format(..., "%Y-%m-01")` construye su primer día.
- `as.Date()` vuelve a convertir el texto en fecha.

### Código

```r
datos_serie$dias_mes <- as.integer(
  primer_dia_mes_siguiente -
    datos_serie$fecha
)
```

La diferencia entre primeros días consecutivos devuelve la cantidad de días del mes original.

### Validación

```r
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
```

Solo se admiten 28, 29, 30 o 31 días.

## 7. Remisión media diaria

### Código

```r
datos_serie$remision_litros_dia <-
  datos_serie$remision_litros /
  datos_serie$dias_mes
```

La remisión total se divide por la cantidad de días.

Esta medida no representa una observación diaria real. Es el promedio diario implícito dentro de cada total mensual.

### Conversión a millones

```r
datos_serie$remision_millones_dia <-
  datos_serie$remision_litros_dia /
  1000000
```

La conversión facilita gráficos y tablas.

### Logaritmo

```r
datos_serie$log_remision_litros_dia <- log(
  datos_serie$remision_litros_dia
)
```

El logaritmo puede:

- estabilizar variaciones proporcionales;
- facilitar una interpretación porcentual aproximada;
- impedir pronósticos negativos al retransformar.

Todavía no se concluye que deba utilizarse. Su conveniencia será evaluada posteriormente.

## 8. Creación de los objetos `ts`

### Inicio

```r
inicio_serie <- c(
  datos_serie$anio[[1]],
  datos_serie$mes[[1]]
)
```

El comienzo se obtiene de la primera observación.

### Total mensual

```r
serie_remision_mensual <- stats::ts(
  datos_serie$remision_millones_litros,
  start = inicio_serie,
  frequency = 12
)
```

### Intensidad diaria

```r
serie_remision_diaria <- stats::ts(
  datos_serie$remision_millones_dia,
  start = inicio_serie,
  frequency = 12
)
```

### Logaritmo diario

```r
serie_log_remision_diaria <- stats::ts(
  datos_serie$log_remision_litros_dia,
  start = inicio_serie,
  frequency = 12
)
```

### Significado de los argumentos

- `ts()` crea una serie temporal regular.
- `start` indica año y mes iniciales.
- `frequency = 12` indica doce observaciones por año.
- Cada observación representa un mes.

Las validaciones posteriores comprueban longitud y frecuencia.

## 9. Tabla de auditoría

La tabla `auditoria_serie` resume:

- cantidad de observaciones;
- primera y última fecha;
- frecuencia;
- meses faltantes;
- duplicados;
- duración mínima y máxima de los meses.

Se guarda en:

```text
outputs/tables/01_auditoria_serie.csv
```

## 10. Resumen descriptivo

La función:

```r
resumir_serie <- function(nombre_serie, valores)
```

calcula para cada representación:

- mínimo;
- primer cuartil;
- media;
- mediana;
- tercer cuartil;
- máximo;
- desviación estándar.

El resultado se guarda en:

```text
outputs/tables/02_resumen_descriptivo_serie.csv
```

No se utilizan estas estadísticas para seleccionar todavía un modelo. Su función es describir la escala y dispersión de las representaciones.

## 11. Perfil estacional

### Código principal

```r
perfil_estacional <- stats::aggregate(
  cbind(
    remision_millones_litros,
    remision_millones_dia
  ) ~ mes,
  data = datos_serie,
  FUN = mean
)
```

### Explicación

- `aggregate()` agrupa por mes.
- `cbind()` permite resumir dos variables.
- `~ mes` indica la agrupación.
- `FUN = mean` calcula el promedio histórico.

El resultado no demuestra por sí solo que la estacionalidad sea estable ni determina si debe utilizarse diferencia estacional. Es una descripción inicial.

Se guarda en:

```text
outputs/tables/03_perfil_estacional.csv
```

## 12. Primer gráfico: escalas mensual y diaria

El gráfico combina ambas representaciones en un formato vertical.

```r
ggplot2::facet_wrap(
  ~ serie,
  ncol = 1,
  scales = "free_y"
)
```

- `facet_wrap()` crea un panel para cada serie.
- `ncol = 1` los coloca verticalmente.
- `scales = "free_y"` permite diferentes escalas verticales.

Se guarda en:

```text
outputs/figures/01_remision_mensual_vs_diaria.png
```

Su objetivo es mostrar cuánto del movimiento mensual puede estar asociado a la duración del mes y cuánto persiste en la intensidad diaria.

## 13. Segundo gráfico: perfil estacional

El gráfico presenta la remisión media diaria promedio para cada mes.

Se guarda en:

```text
outputs/figures/02_perfil_estacional_remision_diaria.png
```

Si el perfil continúa variando claramente después de dividir por días, existe estacionalidad productiva además del efecto calendario.

Esto todavía no determina si la estacionalidad debe representarse mediante:

- términos SAR y SMA;
- diferencia estacional;
- variables indicadoras mensuales;
- alguna combinación debidamente validada.

## 14. Tercer gráfico: mapa estacional

El mapa utiliza:

- meses en el eje horizontal;
- años en el eje vertical;
- intensidad diaria representada mediante color.

Se guarda en:

```text
outputs/figures/03_mapa_estacional_remision_diaria.png
```

Este gráfico permite observar simultáneamente:

- cambios de nivel a través de los años;
- meses sistemáticamente altos o bajos;
- posibles cambios del patrón estacional;
- períodos visualmente atípicos.

## 15. Archivos generados

El bloque produce:

```text
outputs/
├── figures/
│   ├── 01_remision_mensual_vs_diaria.png
│   ├── 02_perfil_estacional_remision_diaria.png
│   └── 03_mapa_estacional_remision_diaria.png
└── tables/
    ├── 01_auditoria_serie.csv
    ├── 02_resumen_descriptivo_serie.csv
    └── 03_perfil_estacional.csv
```

## 16. Qué no se hace todavía

Este bloque todavía no:

- define muestras de entrenamiento y prueba;
- aplica diferenciación regular;
- aplica diferenciación estacional;
- realiza pruebas de raíz unitaria;
- calcula ACF o PACF para identificar órdenes;
- estima modelos ARIMA o SARIMA;
- selecciona un modelo;
- trata valores atípicos;
- produce pronósticos.

La exploración prepara las representaciones que serán diagnosticadas en las etapas siguientes.

## 17. Resultado conceptual

Al finalizar tendremos:
,
- datos leídos desde la tabla analítica;
- una secuencia mensual validada;
- la serie mensual original;
- la intensidad media diaria;
- su transformación logarítmica;
- tablas descriptivas reproducibles;
- tres gráficos iniciales.

El siguiente bloque utilizará esta base para definir la cronología de evaluación y diagnosticar tendencia, varianza y estacionalidad sin utilizar información futura de manera incorrecta.