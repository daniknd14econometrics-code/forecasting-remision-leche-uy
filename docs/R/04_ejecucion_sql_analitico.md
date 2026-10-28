# Ejecución y validación del SQL analítico desde R

## Objetivo

Este documento explica cómo R abre la base SQLite, lee el archivo de instrucciones SQL, ejecuta la transformación y comprueba que la tabla analítica haya sido creada correctamente.

El script documentado se encuentra en:

```text
R/04_ejecutar_sql_analitico.R
```

El archivo SQL ejecutado se encuentra en:

```text
sql/01_crear_tabla_analitica.sql
```

La base de datos utilizada es:

```text
database/forecasting.sqlite
```

El resultado principal es la tabla:

```text
analitica_remision_mensual
```

## División de responsabilidades

En esta etapa se combinan R, SQLite y SQL, pero cada elemento cumple una función diferente:

- R localiza los archivos y abre la conexión.
- R lee y separa las instrucciones del archivo `.sql`.
- SQLite ejecuta las instrucciones y almacena las tablas.
- SQL define las transformaciones y los controles de calidad.
- R recibe los resultados de los controles.
- R detiene el proceso si encuentra un problema.

El código SQL no se copia dentro del script de R. Permanece en un archivo independiente para que pueda ser leído, estudiado y modificado como SQL propiamente dicho.

## Flujo de esta etapa

```text
R/04_ejecutar_sql_analitico.R
              ↓
database/forecasting.sqlite
              ↓
stg_remision_inale
              ↓
sql/01_crear_tabla_analitica.sql
              ↓
analitica_remision_mensual
              ↓
controles devueltos a R
```

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

Este bloque identifica la carpeta desde la cual se está ejecutando R y comprueba que corresponda al proyecto correcto.

El control evita crear o buscar archivos accidentalmente en otra carpeta.

### Explicación línea por línea

- `"."` representa la carpeta de trabajo actual.
- `normalizePath()` convierte esa ubicación en una ruta completa.
- `winslash = "/"` utiliza barras compatibles con el código del proyecto.
- `mustWork = TRUE` exige que la carpeta exista.
- `basename()` extrae el último componente de la ruta.
- `!=` comprueba si el nombre es diferente del esperado.
- `stop()` detiene la ejecución cuando el script se inicia desde otra carpeta.

## 2. Definición de las rutas

### Código

```r
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
```

### Explicación general

Se construyen las rutas completas de los dos archivos necesarios:

- la base SQLite;
- el script SQL.

### Explicación línea por línea

- `file.path()` une los componentes de una ruta.
- `ruta_base_datos` señala el archivo que contiene la tabla provisional.
- `ruta_script_sql` señala el archivo con la transformación analítica.
- Las rutas se construyen a partir de la raíz y no dependen del nombre del usuario de Windows.

## 3. Comprobación de los archivos necesarios

### Código

```r
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
```

### Explicación general

Antes de abrir SQLite, R comprueba que existan tanto la base como el script SQL.

Esto produce un error comprensible si se intenta ejecutar la etapa fuera de orden.

### Explicación línea por línea

- `c()` reúne las dos rutas en un vector.
- Los nombres describen cada elemento.
- `file.exists()` comprueba la existencia de los archivos.
- `!` invierte el resultado para seleccionar los que faltan.
- `names()` recupera sus descripciones.
- `length()` cuenta cuántos elementos faltan.
- `paste(..., collapse = ", ")` reúne los nombres en un mensaje.
- `stop()` interrumpe la ejecución si falta algún elemento.

### Mensajes informativos

```r
message("Base de datos: ", ruta_base_datos)
message("Script SQL: ", ruta_script_sql)
```

`message()` informa qué archivos serán utilizados sin modificar su contenido.

## 4. Función para leer las instrucciones SQL

### Código

```r
leer_sentencias_sql <- function(ruta_sql) {
```

### Explicación

Se define una función que recibe la ruta de un archivo SQL y devuelve sus instrucciones por separado.

El archivo contiene varias instrucciones terminadas en punto y coma. Para poder ejecutarlas correctamente mediante `DBI`, R debe separarlas.

## 4.1. Lectura del archivo

### Código

```r
lineas_sql <- readLines(
  ruta_sql,
  warn = FALSE,
  encoding = "UTF-8"
)
```

### Explicación línea por línea

- `readLines()` lee el archivo como líneas de texto.
- `ruta_sql` identifica el archivo.
- `warn = FALSE` evita una advertencia innecesaria por la última línea.
- `encoding = "UTF-8"` permite leer correctamente tildes y caracteres especiales.

## 4.2. Control de archivo vacío

### Código

```r
if (length(lineas_sql) == 0L) {
  stop("El archivo SQL está vacío.")
}
```

- `length(lineas_sql)` cuenta las líneas.
- `0L` representa el entero cero.
- Si no existe ninguna línea, el proceso se detiene.

## 4.3. Eliminación de una posible marca de codificación

### Código

```r
lineas_sql[[1]] <- sub(
  pattern = "^\ufeff",
  replacement = "",
  x = lineas_sql[[1]]
)
```

### Explicación

Algunos editores agregan al principio de un archivo UTF-8 una marca invisible denominada BOM.

- `lineas_sql[[1]]` selecciona la primera línea.
- `sub()` reemplaza una coincidencia.
- `"^\ufeff"` representa la marca solamente al inicio.
- `replacement = ""` la elimina si existe.

Esto evita que la primera palabra SQL sea interpretada incorrectamente.

## 4.4. Eliminación de comentarios

### Código

```r
lineas_codigo <- lineas_sql[
  !grepl(
    pattern = "^\\s*--",
    x = lineas_sql
  )
]
```

### Explicación línea por línea

- En SQL, `--` inicia un comentario de una línea.
- `^` representa el comienzo de la línea.
- `\\s*` admite espacios antes del comentario.
- `grepl()` identifica las líneas comentadas.
- `!` selecciona las que no son comentarios.
- El contenido explicativo del SQL no se envía al motor.

Los comentarios permanecen guardados en el archivo original; solamente se excluyen de las instrucciones ejecutadas.

## 4.5. Unión del texto

### Código

```r
texto_sql <- paste(
  lineas_codigo,
  collapse = "\n"
)
```

- `paste()` vuelve a unir las líneas.
- `collapse = "\n"` conserva los saltos de línea.
- El resultado es un único texto con todo el código ejecutable.

## 4.6. Separación mediante puntos y comas

### Código

```r
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
```

### Explicación línea por línea

- `strsplit()` separa el texto.
- `split = ";"` utiliza el punto y coma como delimitador.
- `fixed = TRUE` interpreta el punto y coma literalmente.
- `unlist()` convierte el resultado en un vector.
- `use.names = FALSE` evita nombres innecesarios.
- `trimws()` elimina espacios y saltos laterales.

Este método es adecuado para el archivo SQL actual porque sus textos internos no contienen puntos y comas.

Si en el futuro se incorporaran textos que contuvieran `;`, habría que utilizar un analizador SQL más especializado.

## 4.7. Eliminación de fragmentos vacíos

### Código

```r
sentencias_sql <- sentencias_sql[
  nzchar(sentencias_sql)
]
```

- `nzchar()` identifica los textos con al menos un carácter.
- Los fragmentos vacíos aparecen, por ejemplo, después del último punto y coma.
- Esos fragmentos no deben enviarse a SQLite.

## 4.8. Resultado de la función

### Código

```r
if (length(sentencias_sql) == 0L) {
  stop(
    "No se encontraron instrucciones SQL ejecutables."
  )
}

sentencias_sql
```

La función se detiene si no encuentra código y, en caso contrario, devuelve el vector de instrucciones.

## 5. Función para ejecutar el archivo SQL

### Código

```r
ejecutar_archivo_sql <- function(ruta_bd, ruta_sql) {
```

La función recibe:

- `ruta_bd`: ubicación de la base SQLite;
- `ruta_sql`: ubicación del archivo SQL.

Dentro de ella se abre la conexión, se ejecutan las instrucciones, se guardan los resultados de las consultas y se cierra la conexión.

## 5.1. Apertura de la conexión

### Código

```r
conexion <- DBI::dbConnect(
  RSQLite::SQLite(),
  dbname = ruta_bd
)
```

### Explicación línea por línea

- `DBI::dbConnect()` abre una conexión.
- `RSQLite::SQLite()` selecciona el motor SQLite.
- `dbname = ruta_bd` indica el archivo concreto.

## 5.2. Cierre garantizado

### Código

```r
on.exit(
  DBI::dbDisconnect(conexion),
  add = TRUE
)
```

- `DBI::dbDisconnect()` cierra la conexión.
- `on.exit()` garantiza el cierre cuando termina la función.
- También se ejecuta si ocurre un error.
- `add = TRUE` conserva otras posibles tareas de salida.

## 5.3. Comprobación de la tabla provisional

### Código

```r
if (!DBI::dbExistsTable(
  conexion,
  "stg_remision_inale"
)) {
  stop(
    "No existe la tabla provisional stg_remision_inale. ",
    "Debe ejecutarse primero R/03_cargar_staging_sqlite.R."
  )
}
```

### Explicación

- `dbExistsTable()` comprueba si la tabla existe.
- `!` representa la negación.
- Si no existe, el script se detiene y explica qué etapa falta.

## 5.4. Preparación de la ejecución

### Código

```r
sentencias_sql <- leer_sentencias_sql(
  ruta_sql
)

resultados_consultas <- list()
contador_consultas <- 0L
```

- Se utiliza la función anterior para leer el SQL.
- `list()` crea una lista vacía para los resultados.
- `contador_consultas` registra cuántas consultas devolvieron tablas.

## 5.5. Recorrido de las instrucciones

### Código

```r
for (indice in seq_along(sentencias_sql)) {
  sentencia <- sentencias_sql[[indice]]
```

- `seq_along()` produce una secuencia con las posiciones.
- `for` recorre cada posición.
- `[[indice]]` extrae una instrucción individual.

## 5.6. Identificación de la primera palabra

### Código

```r
palabra_inicial <- toupper(
  strsplit(
    sentencia,
    split = "[[:space:]]+"
  )[[1]][[1]]
)
```

### Explicación

- `strsplit()` separa la instrucción por espacios o saltos.
- `[[1]][[1]]` extrae su primera palabra.
- `toupper()` la convierte a mayúsculas.

Ejemplos:

```text
CREATE TABLE → CREATE
INSERT INTO  → INSERT
SELECT       → SELECT
WITH         → WITH
```

## 5.7. Mensaje de progreso

### Código

```r
message(
  "Ejecutando instrucción ",
  indice,
  " de ",
  length(sentencias_sql),
  ": ",
  palabra_inicial
)
```

El mensaje permite seguir el avance e identificar qué instrucción falló si aparece un error.

## 5.8. Diferencia entre ejecución y consulta

### Código

```r
produce_resultado <- palabra_inicial %in% c(
  "SELECT",
  "WITH",
  "PRAGMA"
)
```

### Explicación

No todas las instrucciones SQL devuelven una tabla de resultados.

- `CREATE`, `DROP`, `INSERT`, `BEGIN` y `COMMIT` modifican la base.
- `SELECT`, `WITH` y `PRAGMA` producen resultados que R puede recibir.

`%in%` comprueba si la palabra inicial pertenece al segundo grupo.

## 5.9. Consultas que devuelven resultados

### Código

```r
if (produce_resultado) {
  contador_consultas <- contador_consultas + 1L

  resultados_consultas[[
    contador_consultas
  ]] <- DBI::dbGetQuery(
    conexion,
    sentencia
  )
}
```

### Explicación

- Se incrementa el contador.
- `dbGetQuery()` ejecuta una consulta y recupera su resultado.
- El resultado se guarda en una posición de la lista.

El archivo SQL actual devuelve tres resultados:

1. control de filas y período;
2. control de valores inválidos;
3. control de continuidad mensual.

## 5.10. Instrucciones que modifican la base

### Código

```r
else {
  DBI::dbExecute(
    conexion,
    sentencia
  )
}
```

`dbExecute()` se utiliza cuando no es necesario recuperar una tabla de resultados.

Ejecuta instrucciones como:

- `BEGIN`;
- `DROP`;
- `CREATE`;
- `INSERT`;
- `COMMIT`.

## 5.11. Control de errores y rollback

### Código

```r
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
```

### Explicación

Este bloque forma parte de `tryCatch()`.

- Si una instrucción falla, se intenta ejecutar `dbRollback()`.
- El rollback deshace una transacción que todavía no haya sido confirmada.
- `try(..., silent = TRUE)` evita que un rollback imposible o innecesario oculte el error original.
- `conditionMessage()` recupera el mensaje concreto de SQLite.
- `call. = FALSE` muestra un mensaje más limpio.

## 5.12. Comprobación de la tabla creada

### Código

```r
tabla_analitica_existe <- DBI::dbExistsTable(
  conexion,
  "analitica_remision_mensual"
)
```

Comprueba que SQL haya creado la tabla esperada.

### Código

```r
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
```

- Si la tabla existe, `dbListFields()` obtiene sus columnas.
- Si no existe, `character()` devuelve un vector de texto vacío.

## 5.13. Resultado de la función

### Código

```r
list(
  resultados_consultas = resultados_consultas,
  tabla_analitica_existe = tabla_analitica_existe,
  columnas_analiticas = columnas_analiticas
)
```

La función devuelve:

- los resultados de las tres consultas;
- la confirmación de existencia de la tabla;
- sus nombres de columnas.

## 6. Ejecución de la transformación

### Código

```r
ejecucion_sql <- ejecutar_archivo_sql(
  ruta_bd = ruta_base_datos,
  ruta_sql = ruta_script_sql
)
```

Aquí se ejecuta efectivamente el archivo SQL.

El resultado completo queda almacenado en `ejecucion_sql`.

## 7. Identificación de los controles

### Código

```r
if (
  length(ejecucion_sql$resultados_consultas) != 3L
) {
  stop(
    "Se esperaban tres consultas de control, pero se obtuvieron ",
    length(ejecucion_sql$resultados_consultas),
    "."
  )
}
```

El script exige exactamente tres consultas de control. Esto permite detectar si el archivo SQL fue modificado o quedó incompleto.

### Código

```r
control_filas <- ejecucion_sql$resultados_consultas[[1]]
control_valores <- ejecucion_sql$resultados_consultas[[2]]
control_continuidad <- ejecucion_sql$resultados_consultas[[3]]
```

Cada resultado recibe un nombre descriptivo.

## 8. Validación de la estructura

### Código

```r
if (!ejecucion_sql$tabla_analitica_existe) {
  stop(
    "La tabla analitica_remision_mensual no fue creada."
  )
}
```

La ejecución se detiene si la tabla no existe.

### Código

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

Se define el orden exacto esperado.

### Código

```r
if (!identical(
  ejecucion_sql$columnas_analiticas,
  columnas_esperadas
)) {
  stop(
    "Las columnas de la tabla analítica no coinciden ",
    "con la estructura esperada."
  )
}
```

`identical()` exige que nombres y orden coincidan exactamente.

## 9. Validación de la cantidad de filas

### Código

```r
columnas_control_filas <- c(
  "filas_staging",
  "filas_analiticas",
  "control_filas",
  "fecha_min",
  "fecha_max"
)
```

Define las columnas esperadas en el primer control.

### Código

```r
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
```

- Debe existir exactamente una fila.
- `names()` obtiene los nombres.
- `%in%` comprueba su presencia.
- `all()` exige que estén todos.
- `||` significa “o”.

### Código

```r
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
```

La ejecución solo continúa cuando SQL devuelve `OK`.

## 10. Validación de valores imposibles

### Código

```r
columnas_control_valores <- c(
  "fechas_nulas",
  "fechas_duplicadas",
  "valores_no_positivos",
  "porcentajes_invalidos"
)
```

Estas son las cuatro cantidades que deben ser iguales a cero.

### Código

```r
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
```

### Explicación

- Se selecciona la primera fila y las columnas de control.
- `drop = FALSE` mantiene la estructura tabular.
- `vapply()` recorre las columnas.
- Cada resultado se convierte a número.
- `numeric(1)` exige un único número por variable.

### Código

```r
if (
  anyNA(conteos_problemas) ||
  any(conteos_problemas != 0)
) {
  stop(
    "La tabla analítica contiene valores inválidos. ",
    "Revise la consulta de control."
  )
}
```

El script se detiene si encuentra:

- un resultado ausente;
- un resultado diferente de cero.

## 11. Validación de la continuidad mensual

### Código

```r
if (nrow(control_continuidad) != 0L) {
  stop(
    "La serie contiene uno o más meses faltantes."
  )
}
```

La consulta SQL de continuidad solamente devuelve filas cuando encuentra un salto mensual.

Por tanto, el resultado correcto es una tabla con cero filas.

## 12. Presentación de los resultados

### Código

```r
message("")
message("Control 1: cantidad de filas y periodo")

print(
  control_filas,
  row.names = FALSE
)
```

Muestra la comparación entre tablas y el período disponible.

### Código

```r
message("")
message("Control 2: valores inválidos")

print(
  control_valores,
  row.names = FALSE
)
```

Muestra las cantidades de problemas encontrados.

### Código

```r
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
```

Si no existen saltos mensuales, se imprime un mensaje claro. Si existen, se muestran las fechas problemáticas.

### Código

```r
message("")
message(
  "Tabla analítica creada y validada correctamente: ",
  "analitica_remision_mensual"
)
```

Este mensaje solamente aparece después de superar todas las validaciones.

## 13. Resultado esperado

La ejecución correcta debe mostrar:

```text
Control 1: cantidad de filas y periodo

filas_staging filas_analiticas control_filas fecha_min   fecha_max
           297              297 OK            2002-01-01  2026-09-01
```

El segundo control debe devolver ceros:

```text
fechas_nulas fechas_duplicadas valores_no_positivos porcentajes_invalidos
           0                  0                     0                      0
```

El tercero debe indicar:

```text
No se encontraron meses faltantes.
```

El mensaje final debe ser:

```text
Tabla analítica creada y validada correctamente:
analitica_remision_mensual
```

## 14. Repetición del proceso

El script puede ejecutarse nuevamente.

El SQL:

1. elimina la tabla analítica anterior;
2. vuelve a crearla;
3. carga los datos actuales de la tabla provisional;
4. repite todos los controles.

La tabla provisional no se elimina ni se modifica.

## 15. Qué queda preparado

Después de esta etapa, la base contiene dos niveles:

```text
forecasting.sqlite
├── stg_remision_inale
└── analitica_remision_mensual
```

La primera tabla conserva la preparación técnica procedente de R.

La segunda será la fuente del análisis de series temporales.

El siguiente bloque del proyecto leerá `analitica_remision_mensual` desde R, construirá la serie mensual y comenzará el análisis exploratorio.