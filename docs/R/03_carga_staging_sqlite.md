# Preparación y carga provisional en SQLite

## Objetivo

Este documento explica cómo se convierten los datos extraídos del Excel de INALE, cómo se construye la tabla provisional y cómo se carga en SQLite. La división de tareas es la siguiente:

- R interpreta la estructura particular del Excel.
- R convierte las variables a tipos utilizables y normaliza sus nombres.
- R cargará el resultado en una tabla provisional de SQLite.
- SQL construirá y validará la tabla analítica definitiva.

La tabla provisional se llamará `stg_remision_inale`. El prefijo `stg` indica que es una tabla intermedia y no el resultado analítico final.

## 1. Obtención de los datos inspeccionados

``` r
source(
  file.path("R", "02_inspeccionar_datos_inale.R"),
  echo = FALSE
)
```

### Explicación general

Este bloque ejecuta el script de inspección para reconstruir los objetos necesarios desde el archivo original.

El script 03 no depende de que los objetos continúen abiertos en la memoria de una sesión anterior.

### Explicación línea por línea

- `file.path()` construye la ruta del script anterior.
- `source()` ejecuta ese script desde el principio.
- `echo = FALSE` evita repetir en la consola cada línea de código ejecutada.
- Los mensajes y resultados generados por el script 02 pueden seguir apareciendo.

## 2. Función para convertir variables numéricas

``` r
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
```

### Explicación general

Esta función convierte una variable de texto a número y detiene el proceso si alguna observación no puede convertirse.

La función evita cargar silenciosamente valores inválidos en la base de datos.

### Explicación línea por línea

- `function(x, nombre_variable)` define una función con los datos y el nombre que se mostrará en caso de error.
- `as.numeric()` intenta convertir los valores.
- `suppressWarnings()` evita mostrar advertencias genéricas porque se realizará un control explícito.
- `anyNA()` comprueba si la conversión produjo valores ausentes.
- `which()` identifica las filas problemáticas.
- `stop()` detiene el script y muestra la variable y las filas afectadas.
- Si no existe ningún problema, la última línea devuelve `resultado`.

## 3. Conversión y normalización de variables

``` r
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
```

### Explicación general

Este bloque convierte las cuatro variables cuantitativas y conserva la columna de observaciones tal como viene del archivo.

Los valores de grasa y proteína todavía permanecen como proporciones: por ejemplo, `0.04` equivale a 4 %. La transformación a puntos porcentuales se realizará posteriormente mediante SQL.

### Explicación línea por línea

- `[["nombre"]]` selecciona una columna mediante su nombre exacto.
- `convertir_numerico()` convierte y valida cada variable.
- Los resultados reciben nombres simples, sin espacios, tildes ni paréntesis.
- `observacion_origen` conserva la información textual de INALE.
- `trimws()` elimina espacios laterales.
- Las observaciones vacías se convierten explícitamente en `NA`.

## 4. Construcción de la tabla provisional

``` r
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
```

### Explicación general

Este bloque reúne las variables en una tabla con una fila por mes.

También conserva información sobre el archivo de origen y el momento de carga para poder rastrear de dónde provienen los datos.

### Explicación línea por línea

- `data.frame()` construye la tabla provisional.

- `fecha_excel` conserva el número serial original.

- `fecha` almacena la fecha normalizada en formato `AAAA-MM-DD`.

- Las cuatro variables cuantitativas se incorporan como números.

- `observacion_origen` conserva las notas originales.

- `basename()` extrae el nombre del archivo sin su ruta.

- `Sys.time()` obtiene el momento de ejecución.

- `tz = "UTC"` registra el momento en una zona horaria uniforme.

- `stringsAsFactors = FALSE` mantiene las variables textuales como texto.

- `order(datos_staging$fecha)` ordena cronológicamente la tabla.

- `drop = FALSE` mantiene la estructura de tabla.

- `row.names(datos_staging) <- NULL` elimina numeraciones de filas que no pertenecen a los datos.

### Comprobación visual de la tabla provisional

``` r
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
```

### Explicación general

Este bloque confirma las dimensiones, tipos de variables y observaciones extremas antes de abrir la base de datos.

### Explicación línea por línea

- `nrow()` y `ncol()` muestran el tamaño de la tabla.
- `str()` muestra los tipos de las variables.
- `head()` muestra las primeras dos filas.
- `tail()` muestra las últimas dos.
- `row.names = FALSE` evita mostrar la numeración interna de las filas de R, porque esa numeración no forma parte de los datos.

## 5. Carga de la tabla provisional en SQLite

### Objetivo del bloque

Hasta este punto, los datos estaban preparados únicamente dentro de R, en el objeto `datos_staging`. Eso significa que existían mientras la sesión de R permaneciera abierta, pero todavía no estaban guardados en una base de datos.

Este bloque realiza cuatro tareas:

1.  Define dónde se guardará la base de datos SQLite.
2.  Abre una conexión entre R y SQLite.
3.  Guarda `datos_staging` como una tabla llamada `stg_remision_inale`.
4.  Comprueba que SQLite haya recibido correctamente las 297 observaciones.

En esta etapa, R escribe la tabla provisional en SQLite mediante los paquetes `DBI` y `RSQLite`. Todavía no se realizan las transformaciones analíticas con código SQL. Eso se hará posteriormente mediante archivos `.sql`.

La palabra *staging* indica que esta es una tabla intermedia: contiene los datos técnicamente preparados, pero todavía no constituye la tabla analítica definitiva que utilizará el modelo SARIMA.

### Código

``` r
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
```

### Explicación general

El bloque toma el `data.frame` llamado `datos_staging` y lo guarda dentro del archivo `database/forecasting.sqlite`.

Dentro de esa base se crea la tabla:

``` text
stg_remision_inale
```

La relación entre los objetos es la siguiente:

- `datos_staging` es la tabla que existe dentro de R.
- `forecasting.sqlite` es el archivo que contiene la base de datos.
- `stg_remision_inale` es la tabla guardada dentro de esa base.

El argumento `overwrite = TRUE` permite ejecutar nuevamente el proceso. Si la tabla provisional ya existe, se reemplaza por la nueva versión. Esto evita que las mismas observaciones se acumulen o dupliquen cada vez que se ejecuta el script.

Después de guardar la tabla, el código consulta SQLite para comprobar:

- cuántas filas fueron almacenadas;
- cuál es la primera fecha;
- cuál es la última fecha;
- qué columnas y tipos de datos tiene la tabla.

### Explicación detallada

#### Definición de la ruta de la base de datos

``` r
ruta_base_datos <- file.path(
        raiz_proyecto,
        "database",
        "forecasting.sqlite"
)
```

`file.path()` construye una ruta compatible con el sistema operativo.

La ruta se forma uniendo:

- `raiz_proyecto`: carpeta principal del proyecto;
- `"database"`: carpeta destinada a las bases de datos;
- `"forecasting.sqlite"`: nombre del archivo que contendrá la base.

En este equipo, el resultado es:

``` text
C:/Users/dani-/repos/forecasting-remision-leche-uy/database/forecasting.sqlite
```

#### Comprobación de la carpeta de destino

``` r
dir.create(
        dirname(ruta_base_datos),
        recursive = TRUE,
        showWarnings = FALSE
)
```

`dirname(ruta_base_datos)` obtiene solamente la carpeta que contiene el archivo, es decir, `database`.

`dir.create()` crea esa carpeta si todavía no existe.

`recursive = TRUE` permite crear también carpetas superiores faltantes.

`showWarnings = FALSE` evita mostrar una advertencia cuando la carpeta ya existe.

#### Creación de una función para realizar la carga

``` r
cargar_staging_sqlite <- function(datos, ruta_bd) {
```

Se define una función llamada `cargar_staging_sqlite`.

La función recibe dos argumentos:

- `datos`: la tabla de R que se guardará;
- `ruta_bd`: la ubicación del archivo SQLite.

Usar una función permite concentrar en un solo bloque la conexión, la escritura, las consultas de comprobación y el cierre de la base.

#### Apertura de la conexión

``` r
conexion <- DBI::dbConnect(
        RSQLite::SQLite(),
        dbname = ruta_bd
)
```

`DBI::dbConnect()` abre la conexión con la base de datos.

`RSQLite::SQLite()` indica que el motor utilizado es SQLite.

`dbname = ruta_bd` señala dónde se encuentra o dónde debe crearse el archivo.

Si `forecasting.sqlite` todavía no existe, SQLite lo crea. Si ya existe, abre la base existente.

#### Cierre seguro de la conexión

``` r
on.exit(
        DBI::dbDisconnect(conexion),
        add = TRUE
)
```

`DBI::dbDisconnect(conexion)` cierra la conexión con SQLite.

`on.exit()` indica que esa desconexión debe realizarse cuando la función termine, incluso si se produce un error durante la ejecución.

`add = TRUE` agrega esta acción a las tareas de salida de la función sin reemplazar otras que pudieran existir.

Esto evita dejar conexiones abiertas innecesariamente.

#### Escritura de la tabla

``` r
DBI::dbWriteTable(
        conn = conexion,
        name = "stg_remision_inale",
        value = datos,
        overwrite = TRUE,
        row.names = FALSE
)
```

`DBI::dbWriteTable()` guarda una tabla de R dentro de una base de datos.

`conn = conexion` indica qué conexión debe utilizarse.

`name = "stg_remision_inale"` establece el nombre de la tabla dentro de SQLite.

`value = datos` indica qué objeto de R debe guardarse.

`overwrite = TRUE` reemplaza la tabla si ya existe. Esto permite volver a ejecutar el proceso sin duplicar información.

`row.names = FALSE` evita guardar los números internos de fila de R como una columna adicional.

#### Consulta del número de filas y del período

``` r
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
```

`DBI::dbGetQuery()` envía una consulta SQL a la base y devuelve el resultado a R.

`paste()` une las distintas partes de la consulta en una sola instrucción SQL.

La consulta resultante es:

``` sql
SELECT
    COUNT(*) AS filas,
    MIN(fecha) AS fecha_min,
    MAX(fecha) AS fecha_max
FROM stg_remision_inale;
```

`COUNT(*) AS filas` cuenta las observaciones guardadas.

`MIN(fecha) AS fecha_min` obtiene la fecha más antigua.

`MAX(fecha) AS fecha_max` obtiene la fecha más reciente.

`FROM stg_remision_inale` indica la tabla que se está consultando.

Este es el primer uso de una consulta SQL en el flujo, aunque todavía se encuentra escrita dentro del script de R. Su función es comprobar la carga, no transformar los datos.

#### Consulta de la estructura de la tabla

``` r
esquema <- DBI::dbGetQuery(
        conexion,
        "PRAGMA table_info(stg_remision_inale);"
)
```

`PRAGMA table_info()` es una instrucción propia de SQLite que muestra la estructura de una tabla.

El resultado permite comprobar:

- el nombre de cada columna;
- el tipo de dato asignado;
- si admite valores faltantes;
- si forma parte de una clave primaria.

#### Resultado devuelto por la función

``` r
list(
        resumen = resumen,
        esquema = esquema
)
```

`list()` reúne los dos resultados obtenidos:

- `resumen`: cantidad de filas y período;
- `esquema`: nombres y tipos de las columnas.

La función devuelve ambos resultados juntos.

#### Ejecución de la función

``` r
resultado_carga <- cargar_staging_sqlite(
        datos = datos_staging,
        ruta_bd = ruta_base_datos
)
```

Aquí se ejecuta la función.

`datos = datos_staging` entrega la tabla preparada anteriormente en R.

`ruta_bd = ruta_base_datos` indica dónde debe crearse o actualizarse la base SQLite.

Los resultados de las comprobaciones se guardan en `resultado_carga`.

#### Validación de la cantidad de filas

``` r
if (resultado_carga$resumen$filas[[1]] != nrow(datos_staging)) {
        stop(
                "La cantidad de filas guardadas en SQLite no coincide ",
                "con la tabla preparada en R."
        )
}
```

`resultado_carga$resumen$filas[[1]]` extrae el número de filas informado por SQLite.

`nrow(datos_staging)` cuenta las filas de la tabla original de R.

`!=` comprueba si ambas cantidades son diferentes.

Si no coinciden, `stop()` detiene el script y muestra un mensaje de error.

Esta validación evita continuar silenciosamente si alguna observación no fue guardada.

#### Mensajes finales

``` r
message("Base SQLite creada: ", ruta_base_datos)
message("Resumen de la tabla provisional:")
```

El primer mensaje muestra la ubicación de la base.

El segundo anuncia el resumen de la carga.

``` r
print(
        resultado_carga$resumen,
        row.names = FALSE
)
```

Se imprimen la cantidad de filas y el período almacenado.

`row.names = FALSE` evita mostrar una columna innecesaria con los números de fila de R.

``` r
message("Esquema creado por SQLite:")
```

Este mensaje anuncia la estructura de la tabla.

``` r
print(
        resultado_carga$esquema,
        row.names = FALSE
)
```

Se imprimen los nombres y tipos de las columnas creadas en SQLite.

### Resultado obtenido

La ejecución produjo el siguiente resumen:

``` text
filas  fecha_min   fecha_max
297    2002-01-01  2026-09-01
```

Por tanto:

- se guardaron las 297 observaciones preparadas en R;
- no se perdieron filas durante la carga;
- la primera observación corresponde a enero de 2002;
- la última observación corresponde a septiembre de 2026.

SQLite creó las variables numéricas con tipo `REAL` y las variables de texto con tipo `TEXT`.

La tabla `stg_remision_inale` es todavía una tabla provisional. El siguiente paso será utilizar código SQL para validar su contenido y construir la tabla analítica definitiva que posteriormente leerá R para desarrollar el modelo SARIMA.
