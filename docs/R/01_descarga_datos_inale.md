# Descarga de datos de remisión desde INALE

## Objetivo

Este documento explica el código utilizado para localizar y descargar la serie de remisión a planta publicada por el Instituto Nacional de la Leche de Uruguay.

La descarga se realizará desde la página oficial estable de INALE. El enlace concreto del archivo Excel puede cambiar cuando INALE actualiza la información, por lo que no se fijará manualmente esa dirección en el código.

Las copias descargadas se guardarán sin modificaciones dentro de `data/original`.

## 1. Configuración general

``` r
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
```

### Explicación general

Este bloque comprueba que el script se está ejecutando dentro del proyecto correcto, define la página oficial de INALE, construye la ruta de la carpeta destinada a los archivos originales y registra la fecha de ejecución.

Todavía no se descarga ningún archivo.

### Explicación línea por línea

- `normalizePath()` transforma una ruta en una ruta absoluta y normalizada.

- `"."` representa la carpeta de trabajo actual. Al abrir el archivo `.Rproj`, debería ser la raíz del proyecto.

- `winslash = "/"` indica que las rutas de Windows se mostrarán utilizando barras normales. Esto facilita su lectura y evita problemas con el carácter `\`.

- `mustWork = TRUE` obliga a R a detenerse si la carpeta indicada no existe.

- El resultado se guarda en el objeto `raiz_proyecto`.

- `basename(raiz_proyecto)` extrae el último componente de la ruta, que debería ser `forecasting-remision-leche-uy`.

- `!=` significa “distinto de”.

- Si el nombre no coincide, `stop()` detiene el script y muestra un mensaje de error.

- Esta comprobación evita crear o descargar archivos accidentalmente en otra carpeta.

- `paste0()` une fragmentos de texto sin agregar espacios.

- Los dos fragmentos forman la dirección estable de la página oficial de INALE.

- El resultado se guarda en `pagina_inale`.

- Se divide visualmente la dirección en dos líneas para que el código sea más legible.

- `file.path()` construye rutas utilizando el separador correcto para el sistema operativo.

- `raiz_proyecto`, `"data"` y `"original"` forman la ruta de la carpeta donde se guardarán las copias originales.

- El resultado se guarda en `carpeta_original`.

- `Sys.Date()` obtiene la fecha actual del sistema.

- Esa fecha se guarda en `fecha_descarga` y posteriormente se utilizará para identificar cuándo se obtuvo cada copia.

- `dir.create()` crea una carpeta si todavía no existe.

- `recursive = TRUE` permite crear también carpetas intermedias si fueran necesarias.

- `showWarnings = FALSE` evita mostrar una advertencia cuando la carpeta ya existe.

- En este proyecto la carpeta fue creada previamente, por lo que esta instrucción funciona como medida de seguridad.

- `message()` muestra información útil durante la ejecución.

- Los cuatro mensajes permiten verificar el proyecto, la fuente, la carpeta de destino y la fecha.

- Estos mensajes también serán útiles cuando el proceso se ejecute automáticamente.

## 2. Localización automática del archivo Excel

``` r
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
```

### Explicación general

Este bloque descarga temporalmente el código HTML de la página oficial de INALE y busca dentro de él una dirección que termine en `.xls` o `.xlsx`.

El archivo temporal contiene la página web, no los datos de remisión. Después de localizar el enlace del Excel, la página temporal se elimina.

El bloque exige encontrar exactamente un archivo Excel. Si no encuentra ninguno o encuentra varios, detiene el proceso en lugar de elegir uno arbitrariamente.

Todavía no se descarga la copia definitiva de los datos.

### Explicación línea por línea

- `tempfile()` genera una ruta temporal que no interfiere con los archivos permanentes del proyecto.

- `fileext = ".html"` agrega la extensión `.html` al archivo temporal.

- La ruta generada se guarda en `archivo_html_temporal`.

- `download.file()` descarga un recurso de Internet.

- `url = pagina_inale` utiliza la página oficial definida en el bloque anterior.

- `destfile = archivo_html_temporal` guarda la página en el archivo temporal.

- `mode = "wb"` solicita una descarga en modo binario, evitando alteraciones durante la transferencia.

- `quiet = TRUE` evita mostrar la barra de progreso de esta descarga temporal.

- `readLines()` lee el archivo HTML como una colección de líneas de texto.

- `warn = FALSE` evita advertencias innecesarias si la última línea del HTML no termina con un salto de línea.

- `encoding = "UTF-8"` indica la codificación utilizada para interpretar el texto.

- `paste(..., collapse = "\n")` vuelve a unir todas las líneas en un único texto.

- El resultado se guarda en `html_inale`.

- `patron_excel` contiene una expresión regular para reconocer direcciones de Internet que terminan en `.xls` o `.xlsx`.

- `https?` permite que la dirección comience tanto con `http` como con `https`.

- `[^\"'[:space:]<>]+` representa los caracteres que pueden formar la parte central de la dirección.

- `\\.xlsx?` reconoce las extensiones `.xls` y `.xlsx`.

- En R se escribe `\\.` porque la barra debe escaparse para que el punto se interprete literalmente.

- `gregexpr()` busca todas las apariciones del patrón dentro del HTML.

- `pattern = patron_excel` indica qué patrón se busca.

- `text = html_inale` indica dónde debe buscarse.

- `ignore.case = TRUE` permite reconocer extensiones escritas con mayúsculas o minúsculas.

- `perl = TRUE` activa el motor de expresiones regulares utilizado para interpretar el patrón.

- `regmatches()` extrae el texto correspondiente a las coincidencias encontradas.

- `[[1]]` extrae el primer conjunto de resultados de la lista producida por la búsqueda.

- El resultado se guarda en `coincidencias`.

- `unique()` elimina enlaces repetidos que puedan aparecer varias veces en el HTML.

- El resultado se guarda en `enlaces_excel`.

- `length(enlaces_excel)` cuenta cuántos enlaces diferentes fueron encontrados.

- `1L` representa el número entero uno.

- `!= 1L` comprueba que el resultado sea distinto de exactamente un enlace.

- Si la condición se cumple, `stop()` detiene el script y explica cuántos enlaces fueron encontrados.

- Esta comprobación evita que una modificación de la página de INALE produzca una descarga incorrecta y silenciosa.

- `enlaces_excel[[1]]` extrae el único enlace validado.

- Ese enlace se guarda en `url_excel`.

- `unlink()` elimina el archivo HTML temporal porque ya no es necesario.

- `message()` muestra en la consola el enlace localizado.

## 3. Descarga de la copia original

``` r
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
    scientific = FALSE,
    trim = TRUE
  ),
  " bytes"
)
```

### Explicación general

Este bloque descarga el archivo Excel localizado en la página de INALE y lo guarda sin modificaciones en `data/original`.

El nombre incorpora la fecha de descarga. Así queda registrado cuándo se obtuvo cada copia, aunque INALE mantenga el mismo nombre para distintas actualizaciones.

Si el script se ejecuta nuevamente durante el mismo día, no sobrescribe la copia ya existente.

### Explicación línea por línea

- `grepl()` comprueba si la dirección localizada termina en `.xlsx`.

- `ignore.case = TRUE` permite reconocer la extensión aunque esté escrita con mayúsculas.

- Si la condición es verdadera, `extension_excel` recibe `.xlsx`.

- En caso contrario, recibe `.xls`.

- `paste0()` construye el nombre del archivo sin agregar espacios.

- `"remision_a_planta_inale_"` identifica el contenido y la fuente.

- `format(fecha_descarga, "%Y-%m-%d")` transforma la fecha al formato año-mes-día.

- `extension_excel` conserva la extensión correspondiente al archivo publicado.

- `file.path()` combina la carpeta original y el nombre del archivo.

- La ruta completa se guarda en `ruta_archivo_original`.

- `file.exists()` comprueba si ya existe una copia con esa fecha.

- `!` significa negación: el bloque de descarga se ejecuta solamente si el archivo no existe.

- `download.file()` descarga el Excel.

- `url = url_excel` utiliza el enlace localizado automáticamente.

- `destfile = ruta_archivo_original` determina dónde se guarda.

- `mode = "wb"` conserva los bytes originales del archivo.

- `quiet = FALSE` muestra el progreso de la descarga.

- Si el archivo ya existe, el bloque `else` informa de ello y evita sobrescribirlo.

- `file.info()` consulta las propiedades del archivo.

- `$size` extrae su tamaño en bytes.

- El resultado se guarda en `tamano_archivo`.

- `is.na(tamano_archivo)` detecta si R no pudo obtener el tamaño.

- `tamano_archivo <= 0` detecta un archivo vacío.

- `||` significa “o”.

- Si alguna condición se cumple, `stop()` detiene el proceso.

- El último `message()` muestra el tamaño del archivo.

- `big.mark = "."` agrega puntos como separadores de miles.

- `decimal.mark = ","`

- `scientific = FALSE` evita la notación científica.

- `trim = TRUE` elimina espacios innecesarios.
