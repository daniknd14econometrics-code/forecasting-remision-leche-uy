# Inspección inicial de los datos de INALE

## Objetivo

Este documento explica cómo se localiza la copia original más reciente y cómo se examina la estructura del archivo Excel antes de transformar los datos.

La inspección se realiza en un script separado de la descarga. De esta manera, un script obtiene el archivo original y otro se ocupa de leerlo y comprender su organización.

## Dependencia utilizada

Para leer archivos `.xls` y `.xlsx` se utiliza el paquete `readxl`.

```r
install.packages(
  "readxl",
  repos = "https://cloud.r-project.org"
)

packageVersion("readxl")
```

### Explicación general

`readxl` permite consultar las hojas de un libro de Excel y leer sus datos sin necesitar Microsoft Excel instalado.

El paquete se instala dentro del entorno privado administrado por `renv`.

### Explicación línea por línea

- `install.packages()` instala un paquete de R.
- `"readxl"` identifica el paquete necesario para leer archivos Excel.
- `repos` indica el servidor de CRAN utilizado para descargarlo.
- `packageVersion("readxl")` comprueba la versión instalada.
- La versión instalada durante la preparación del proyecto fue `1.6.0`.

## 1. Localización de la copia original más reciente

```r
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
```

### Explicación general

Este bloque localiza las copias originales descargadas y selecciona la más reciente según la fecha incluida en su nombre.

El script puede ejecutarse de forma independiente: no necesita que el script de descarga siga abierto ni que sus objetos permanezcan en la memoria.

### Explicación línea por línea

- `normalizePath()` obtiene la ruta absoluta del proyecto.
- La comprobación con `basename()` evita ejecutar el script desde otra carpeta.
- `file.path()` construye la ruta de `data/original`.

- `patron_archivo` define qué nombres son considerados copias válidas.
- `[0-9]{4}` representa cuatro cifras para el año.
- `[0-9]{2}` representa dos cifras para el mes y el día.
- `\\.xlsx?` permite las extensiones `.xls` y `.xlsx`.

- `list.files()` busca los archivos que cumplen ese patrón.
- `full.names = TRUE` devuelve sus rutas completas.
- `ignore.case = TRUE` ignora diferencias entre mayúsculas y minúsculas.

- Si no se encuentra ningún archivo, `stop()` detiene el script.
- `sort(..., decreasing = TRUE)` ordena las rutas de la fecha más reciente a la más antigua.
- `[[1]]` selecciona la primera.
- Esto funciona porque las fechas utilizan el formato `AAAA-MM-DD`.

## 2. Identificación y validación de las hojas

```r
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
```

### Explicación general

Este bloque obtiene los nombres de todas las hojas y comprueba que las tres hojas principales esperadas sigan existiendo.

La validación permite detectar si INALE modifica la estructura del archivo en una actualización futura.

### Explicación línea por línea

- `readxl::excel_sheets()` devuelve los nombres de las hojas.
- `hojas_principales` contiene los nombres que esperamos encontrar.
- `setdiff()` identifica nombres esperados que no aparecen en el Excel.
- Si falta alguna hoja, `stop()` detiene el proceso.
- `paste(..., collapse = ", ")` une varios nombres en un mensaje legible.
- El último `message()` muestra todas las hojas encontradas.

## 3. Vista preliminar de Listado Datos

```r
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
```

### Explicación general

Este bloque lee únicamente las primeras quince filas de `Listado Datos`. El objetivo es conocer su organización antes de decidir qué filas son encabezados y qué columnas necesitaremos.

No se modifica el archivo original.

### Explicación línea por línea

- `readxl::read_excel()` lee una hoja de Excel.
- `path` indica el archivo original seleccionado.
- `sheet = "Listado Datos"` selecciona la hoja que se desea inspeccionar.
- `col_names = FALSE` impide asumir que la primera fila contiene nombres de variables.
- `n_max = 15` limita la lectura a las primeras quince filas.
- El resultado se guarda en `vista_listado_datos`.
- `print()` muestra la tabla en la consola.
- `n = Inf` solicita mostrar todas las filas leídas.
- `width = Inf` solicita mostrar todas las columnas.


## 4. Lectura del rectángulo de datos

```r
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
```

### Explicación general

Este bloque lee exclusivamente las columnas B:G a partir de la fila 5 de `Listado Datos`.

La última fila se deja abierta para que futuras actualizaciones mensuales puedan incorporar nuevas observaciones. Después se distinguen las filas mensuales de las notas metodológicas ubicadas al final del Excel.

En esta etapa todas las columnas se leen como texto para conservar los valores tal como llegan. La conversión definitiva de tipos se realizará posteriormente.

### Explicación línea por línea

- `cellranger::cell_limits()` define el rectángulo que debe leer `readxl`.
- `ul = c(5, 2)` significa que el extremo superior izquierdo es la fila 5, columna 2, correspondiente a B5.
- `lr = c(NA, 7)` fija la última columna en G y deja abierta la última fila.
- `sheet = "Listado Datos"` indica la hoja.
- La fila 5 se utiliza como encabezado.

- `col_types = "text"` obliga a leer inicialmente todas las columnas como texto.
- Esto evita que las notas finales alteren automáticamente los tipos de las variables.
- `na` identifica los valores ausentes.
- `trim_ws` elimina espacios laterales innecesarios.

- `as.numeric()` intenta convertir la columna `Fecha`, que inicialmente contiene números seriales de Excel.
- Las notas metodológicas no pueden convertirse y producen valores ausentes.
- `suppressWarnings()` oculta esas advertencias esperadas.

- `filas_mensuales` identifica las filas que contienen una fecha numérica válida.
- `datos_inale_brutos` conserva únicamente esas filas.
- `drop = FALSE` mantiene el resultado como tabla aunque cambie el número de columnas.

- `as.Date()` convierte los números seriales de Excel en fechas.
- `origin = "1899-12-30"` utiliza el origen correspondiente al sistema de fechas de Excel para Windows.

- Los mensajes finales muestran la cantidad de observaciones, el período disponible y las filas auxiliares excluidas.
- `head()` y `tail()` permiten revisar los extremos de la tabla mensual.