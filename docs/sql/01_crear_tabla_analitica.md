# Creación y validación de la tabla analítica mensual

## Objetivo

Este documento explica el código SQL utilizado para transformar la tabla provisional `stg_remision_inale` en la tabla analítica `analitica_remision_mensual`.

La tabla provisional fue creada desde R y conserva los datos obtenidos del archivo original de INALE con una preparación técnica mínima.

La tabla analítica tiene una función diferente: organiza y valida la información que posteriormente utilizará R para construir la serie temporal y desarrollar el modelo SARIMA.

En esta etapa SQL se encarga de:

1. Crear una tabla analítica con una estructura explícita.
2. Extraer el año y el mes desde la fecha.
3. Expresar la remisión también en millones de litros.
4. Convertir las proporciones de grasa y proteína a porcentajes.
5. Aplicar restricciones que impidan cargar datos inválidos.
6. Comparar la cantidad de registros de las tablas provisional y analítica.
7. Comprobar la existencia de fechas duplicadas o valores imposibles.
8. Comprobar que la serie mensual no tenga meses faltantes.

El código se encuentra en:

```text
sql/01_crear_tabla_analitica.sql
```

## Lugar del SQL dentro del flujo del proyecto

Hasta este punto, el flujo es el siguiente:

```text
Página web de INALE
        ↓
Archivo Excel original
        ↓
Lectura y preparación técnica con R
        ↓
Tabla provisional stg_remision_inale
        ↓
Transformación y validación con SQL
        ↓
Tabla analítica analitica_remision_mensual
        ↓
Lectura desde R y construcción de la serie temporal
        ↓
Modelos SARIMA
```

SQL no modifica el archivo Excel original ni la tabla provisional. Crea una tabla nueva a partir de ellos.

Esto permite conservar tres niveles claramente separados:

- el archivo original descargado de INALE;
- la tabla provisional preparada por R;
- la tabla analítica construida y validada mediante SQL.

## Diferencia entre la tabla provisional y la tabla analítica

La tabla `stg_remision_inale` conserva variables cercanas a la estructura del archivo original:

- fecha serial de Excel;
- fecha normalizada;
- remisión en litros;
- remisión en kilos sólidos;
- grasa y proteína expresadas como proporciones;
- observaciones del archivo;
- información sobre el origen y el momento de carga.

La tabla `analitica_remision_mensual` incorpora una estructura más conveniente para el análisis:

- fecha mensual validada;
- año;
- número de mes;
- remisión en litros;
- remisión en millones de litros;
- remisión en kilos sólidos;
- grasa expresada en porcentaje;
- proteína expresada en porcentaje;
- información de trazabilidad.

No se imputan datos, no se eliminan valores atípicos y no se redondean las observaciones. Las transformaciones realizadas en esta etapa son únicamente estructurales y de escala.

## 1. Inicio de la transacción

### Código

```sql
BEGIN TRANSACTION;
```

### Explicación general

Una transacción agrupa varias instrucciones SQL dentro de una misma operación lógica.

En este script, la eliminación de la tabla anterior, la creación de la nueva tabla y la carga de los datos forman parte del mismo proceso.

La transacción se confirma posteriormente mediante `COMMIT`.

### Explicación línea por línea

- `BEGIN` indica que comienza una transacción.
- `TRANSACTION` aclara que las instrucciones siguientes pertenecen a esa operación conjunta.
- El punto y coma `;` marca el final de la instrucción SQL.

La transacción ayuda a evitar que la base quede en un estado intermedio si ocurre un problema durante la creación o la carga.

El script de R que ejecutará este archivo también deberá controlar los errores y cerrar correctamente la conexión con SQLite.

## 2. Eliminación de una versión anterior

### Código

```sql
DROP TABLE IF EXISTS analitica_remision_mensual;
```

### Explicación general

Esta instrucción elimina una versión anterior de la tabla analítica antes de crearla nuevamente.

Esto permite ejecutar todo el proceso más de una vez sin acumular datos ni generar observaciones duplicadas.

La tabla provisional `stg_remision_inale` no se elimina.

### Explicación línea por línea

- `DROP TABLE` indica que se desea eliminar una tabla.
- `IF EXISTS` evita que SQLite produzca un error si la tabla todavía no existe.
- `analitica_remision_mensual` es la tabla que se reemplazará.
- El punto y coma finaliza la instrucción.

Este diseño hace que el proceso sea reproducible: cada ejecución reconstruye la tabla analítica desde el principio utilizando la versión actual de la tabla provisional.

## 3. Creación de la tabla analítica

### Código

```sql
CREATE TABLE analitica_remision_mensual (
    fecha                       TEXT    NOT NULL PRIMARY KEY,
    anio                        INTEGER NOT NULL,
    mes                         INTEGER NOT NULL,
    remision_litros             REAL    NOT NULL,
    remision_millones_litros    REAL    NOT NULL,
    remision_kilos_solidos      REAL    NOT NULL,
    grasa_porcentaje            REAL    NOT NULL,
    proteina_porcentaje         REAL    NOT NULL,
    observacion_origen          TEXT,
    archivo_origen              TEXT    NOT NULL,
    fecha_carga_utc             TEXT    NOT NULL,

    CHECK (date(fecha) IS NOT NULL),
    CHECK (fecha = date(fecha, 'start of month')),
    CHECK (anio = CAST(strftime('%Y', fecha) AS INTEGER)),
    CHECK (mes = CAST(strftime('%m', fecha) AS INTEGER)),
    CHECK (mes BETWEEN 1 AND 12),
    CHECK (remision_litros > 0),
    CHECK (remision_millones_litros > 0),
    CHECK (remision_kilos_solidos > 0),
    CHECK (grasa_porcentaje BETWEEN 0 AND 10),
    CHECK (proteina_porcentaje BETWEEN 0 AND 10),

    UNIQUE (anio, mes)
);
```

### Explicación general

`CREATE TABLE` define explícitamente:

- el nombre de la tabla;
- las columnas que contendrá;
- los tipos de datos;
- las variables obligatorias;
- la clave principal;
- las restricciones de validez;
- la regla que impide duplicar un mismo año y mes.

A diferencia de una creación automática, esta definición obliga a que los datos cumplan ciertas condiciones antes de ser aceptados por SQLite.

## 3.1. Tipos de datos utilizados

SQLite utiliza en esta tabla tres tipos principales:

- `TEXT`: valores de texto, incluidas las fechas almacenadas como `AAAA-MM-DD`;
- `INTEGER`: números enteros, como el año y el mes;
- `REAL`: números que pueden contener decimales.

La fecha se guarda como texto porque el formato `AAAA-MM-DD` mantiene correctamente el orden cronológico y puede ser interpretado por las funciones de fecha de SQLite.

## 3.2. Definición de las columnas

### Fecha

```sql
fecha TEXT NOT NULL PRIMARY KEY,
```

- `fecha` es el nombre de la variable.
- `TEXT` indica que la fecha se guarda como texto.
- `NOT NULL` impide guardar una observación sin fecha.
- `PRIMARY KEY` identifica cada fila de manera única.
- Como la fecha es la clave principal, SQLite no admite dos observaciones con la misma fecha.

### Año

```sql
anio INTEGER NOT NULL,
```

- `anio` contiene el año calendario.
- `INTEGER` indica que debe ser un número entero.
- `NOT NULL` impide que quede vacío.

### Mes

```sql
mes INTEGER NOT NULL,
```

- `mes` contiene el número del mes.
- Los valores esperados van de `1` a `12`.
- `INTEGER` exige un número entero.
- `NOT NULL` impide valores ausentes.

### Remisión en litros

```sql
remision_litros REAL NOT NULL,
```

- Conserva la remisión mensual en la unidad original de litros.
- `REAL` admite valores numéricos con decimales.
- `NOT NULL` exige que cada mes tenga un valor.

Esta es la variable principal que posteriormente se utilizará para construir la serie temporal.

### Remisión en millones de litros

```sql
remision_millones_litros REAL NOT NULL,
```

- Expresa la misma remisión mensual en millones de litros.
- Se obtiene dividiendo `remision_litros` entre un millón.
- Facilita la lectura de tablas, gráficos y resultados.
- No reemplaza la variable original: ambas unidades se conservan.

Por ejemplo:

```text
105355000 litros = 105.355 millones de litros
```

### Remisión en kilos sólidos

```sql
remision_kilos_solidos REAL NOT NULL,
```

- Conserva la remisión mensual expresada en kilos sólidos.
- Se mantiene porque forma parte de la información oficial de INALE.
- No será la variable objetivo principal del primer modelo SARIMA.

### Porcentaje de grasa

```sql
grasa_porcentaje REAL NOT NULL,
```

- Contiene el porcentaje de grasa de la leche.
- La tabla provisional conserva este valor como proporción.
- SQL lo multiplica por `100` para expresarlo como porcentaje.

Por ejemplo:

```text
0.0352 como proporción = 3.52 %
```

### Porcentaje de proteína

```sql
proteina_porcentaje REAL NOT NULL,
```

- Contiene el porcentaje de proteína.
- También se obtiene multiplicando por `100` la proporción original.

Por ejemplo:

```text
0.0300 como proporción = 3.00 %
```

### Observación de origen

```sql
observacion_origen TEXT,
```

- Conserva la observación textual incluida por INALE.
- No utiliza `NOT NULL` porque muchos meses no tienen observaciones.
- En esos casos SQLite admite un valor nulo.

### Archivo de origen

```sql
archivo_origen TEXT NOT NULL,
```

- Identifica el archivo Excel del cual provino cada observación.
- Permite rastrear la fuente concreta utilizada durante la carga.
- `NOT NULL` obliga a conservar esta información.

### Fecha y hora de carga

```sql
fecha_carga_utc TEXT NOT NULL,
```

- Registra cuándo se preparó la observación para su carga en SQLite.
- Se conserva en la zona horaria UTC.
- Permite rastrear la ejecución que produjo la tabla.

## 3.3. Validación de la fecha

### Código

```sql
CHECK (date(fecha) IS NOT NULL),
```

### Explicación

- `date(fecha)` pide a SQLite que interprete el contenido como una fecha.
- `IS NOT NULL` exige que SQLite pueda reconocerla.
- `CHECK` impide insertar una fila que no cumpla esta condición.

Una cadena de texto que no represente una fecha válida no debería ser aceptada.

### Código

```sql
CHECK (fecha = date(fecha, 'start of month')),
```

### Explicación

- `date(fecha, 'start of month')` obtiene el primer día del mes correspondiente.
- El valor se compara con la fecha almacenada.
- La igualdad exige que todas las fechas sean el primer día de su mes.

Por ejemplo:

```text
2002-01-01 → válido
2002-01-15 → inválido
```

Esto es importante porque cada fila representa un mes completo y no un día particular.

## 3.4. Coherencia del año y del mes

### Código

```sql
CHECK (anio = CAST(strftime('%Y', fecha) AS INTEGER)),
```

### Explicación

- `strftime('%Y', fecha)` extrae el año de la fecha.
- El resultado inicial es un texto.
- `CAST(... AS INTEGER)` lo convierte en número entero.
- `CHECK` exige que el valor guardado en `anio` coincida con el año de `fecha`.

### Código

```sql
CHECK (mes = CAST(strftime('%m', fecha) AS INTEGER)),
```

### Explicación

- `strftime('%m', fecha)` extrae el mes.
- `CAST(... AS INTEGER)` lo convierte en entero.
- `CHECK` exige que el mes guardado coincida con la fecha.

Estas restricciones evitan incoherencias como:

```text
fecha = 2020-03-01
anio  = 2020
mes   = 4
```

## 3.5. Intervalo permitido para el mes

### Código

```sql
CHECK (mes BETWEEN 1 AND 12),
```

### Explicación

- `BETWEEN 1 AND 12` comprueba que el mes se encuentre dentro del intervalo válido.
- Se admiten los extremos `1` y `12`.
- Valores como `0` o `13` son rechazados.

## 3.6. Valores positivos de remisión

### Código

```sql
CHECK (remision_litros > 0),
CHECK (remision_millones_litros > 0),
CHECK (remision_kilos_solidos > 0),
```

### Explicación

Estas condiciones exigen valores estrictamente positivos.

Una remisión mensual igual a cero o negativa no tendría sentido en esta base y probablemente señalaría un problema de lectura, transformación o fuente.

Estas restricciones no establecen qué valor es estadísticamente atípico. Solamente impiden valores imposibles o incompatibles con la variable.

## 3.7. Intervalos para grasa y proteína

### Código

```sql
CHECK (grasa_porcentaje BETWEEN 0 AND 10),
CHECK (proteina_porcentaje BETWEEN 0 AND 10),
```

### Explicación

Los porcentajes deben encontrarse entre `0` y `10`.

El intervalo es suficientemente amplio para los valores observados en la composición de la leche, pero permite detectar errores claros de escala.

Por ejemplo, si una proporción de `0.04` no se convirtiera correctamente y se guardara como `40`, la restricción impediría su ingreso.

## 3.8. Unicidad del año y el mes

### Código

```sql
UNIQUE (anio, mes)
```

### Explicación

Esta restricción impide que existan dos filas correspondientes al mismo año y mes.

La clave principal sobre `fecha` ya impide fechas exactamente duplicadas. La restricción `UNIQUE (anio, mes)` agrega una segunda protección: tampoco pueden existir dos fechas diferentes asociadas al mismo mes calendario.

## 4. Transformación y carga desde la tabla provisional

### Código

```sql
INSERT INTO analitica_remision_mensual (
    fecha,
    anio,
    mes,
    remision_litros,
    remision_millones_litros,
    remision_kilos_solidos,
    grasa_porcentaje,
    proteina_porcentaje,
    observacion_origen,
    archivo_origen,
    fecha_carga_utc
)
SELECT
    fecha,
    CAST(strftime('%Y', fecha) AS INTEGER) AS anio,
    CAST(strftime('%m', fecha) AS INTEGER) AS mes,
    remision_litros,
    remision_litros / 1000000.0 AS remision_millones_litros,
    remision_kilos_solidos,
    grasa_proporcion * 100.0 AS grasa_porcentaje,
    proteina_proporcion * 100.0 AS proteina_porcentaje,
    observacion_origen,
    archivo_origen,
    fecha_carga_utc
FROM stg_remision_inale
ORDER BY fecha;
```

### Explicación general

Este bloque toma las observaciones de `stg_remision_inale`, realiza las transformaciones definidas y las inserta en `analitica_remision_mensual`.

La operación combina:

- `INSERT INTO`, que indica dónde se guardarán los datos;
- `SELECT`, que define qué datos se extraen y cómo se transforman;
- `FROM`, que identifica la tabla de origen;
- `ORDER BY`, que ordena las observaciones cronológicamente durante la selección.

## 4.1. Columnas de destino

### Código

```sql
INSERT INTO analitica_remision_mensual (
```

- `INSERT INTO` indica que se agregarán filas a una tabla.
- `analitica_remision_mensual` es la tabla de destino.

Las columnas enumeradas a continuación establecen el orden exacto en que se recibirán los resultados del `SELECT`.

El primer resultado del `SELECT` se inserta en `fecha`, el segundo en `anio`, el tercero en `mes` y así sucesivamente.

## 4.2. Conservación de la fecha

### Código

```sql
fecha,
```

La fecha normalizada de la tabla provisional se copia sin modificar.

La validación de la tabla de destino comprueba que sea una fecha válida y corresponda al primer día del mes.

## 4.3. Extracción del año

### Código

```sql
CAST(strftime('%Y', fecha) AS INTEGER) AS anio,
```

- `strftime('%Y', fecha)` extrae el año con cuatro dígitos.
- `CAST(... AS INTEGER)` lo convierte a número entero.
- `AS anio` asigna un nombre al resultado.

Por ejemplo:

```text
fecha = 2026-09-01
anio  = 2026
```

## 4.4. Extracción del mes

### Código

```sql
CAST(strftime('%m', fecha) AS INTEGER) AS mes,
```

- `strftime('%m', fecha)` extrae el mes.
- Inicialmente puede devolver un texto como `"09"`.
- `CAST(... AS INTEGER)` lo convierte en el entero `9`.
- `AS mes` nombra la variable resultante.

## 4.5. Conservación de la remisión en litros

### Código

```sql
remision_litros,
```

La variable se copia sin modificar desde la tabla provisional.

Esta seguirá siendo la medida original de la variable objetivo.

## 4.6. Conversión a millones de litros

### Código

```sql
remision_litros / 1000000.0 AS remision_millones_litros,
```

- La remisión original se divide entre `1.000.000`.
- El uso de `1000000.0` asegura una división numérica con decimales.
- `AS remision_millones_litros` asigna el nombre a la variable transformada.

Esta transformación cambia únicamente la unidad de medida. No modifica el contenido económico de la serie.

## 4.7. Conservación de los kilos sólidos

### Código

```sql
remision_kilos_solidos,
```

La variable se copia directamente desde la tabla provisional.

## 4.8. Conversión de grasa a porcentaje

### Código

```sql
grasa_proporcion * 100.0 AS grasa_porcentaje,
```

- `grasa_proporcion` contiene el valor original como proporción.
- La multiplicación por `100` lo convierte a porcentaje.
- `AS grasa_porcentaje` asigna el nuevo nombre.

## 4.9. Conversión de proteína a porcentaje

### Código

```sql
proteina_proporcion * 100.0 AS proteina_porcentaje,
```

La lógica es la misma que para la grasa:

```text
0.0365 × 100 = 3.65 %
```

## 4.10. Conservación de la trazabilidad

### Código

```sql
observacion_origen,
archivo_origen,
fecha_carga_utc
```

Estas variables se copian sin modificar.

Permiten conocer:

- si INALE agregó una observación a un mes;
- qué archivo Excel se utilizó;
- cuándo se realizó la carga.

## 4.11. Tabla de origen

### Código

```sql
FROM stg_remision_inale
```

`FROM` identifica la tabla de la cual se obtienen las observaciones.

La única fuente de la tabla analítica es `stg_remision_inale`.

## 4.12. Orden cronológico

### Código

```sql
ORDER BY fecha;
```

`ORDER BY fecha` organiza cronológicamente los resultados del `SELECT` durante la inserción.

No debe suponerse que una consulta futura devolverá automáticamente las filas en ese orden. Cuando R lea la tabla, la consulta también deberá utilizar `ORDER BY fecha`.

## 5. Confirmación de la transacción

### Código

```sql
COMMIT;
```

### Explicación general

`COMMIT` confirma los cambios realizados desde `BEGIN TRANSACTION`.

Una vez ejecutado correctamente, la nueva tabla analítica y sus observaciones quedan guardadas en la base SQLite.

### Explicación línea por línea

- `COMMIT` confirma la transacción.
- El punto y coma finaliza la instrucción.

## 6. Control de cantidad de filas y período

### Código

```sql
SELECT
    (SELECT COUNT(*)
     FROM stg_remision_inale) AS filas_staging,

    COUNT(*) AS filas_analiticas,

    CASE
        WHEN COUNT(*) = (
            SELECT COUNT(*)
            FROM stg_remision_inale
        )
        THEN 'OK'
        ELSE 'REVISAR'
    END AS control_filas,

    MIN(fecha) AS fecha_min,
    MAX(fecha) AS fecha_max

FROM analitica_remision_mensual;
```

### Explicación general

Esta consulta compara la cantidad de filas de las tablas provisional y analítica.

También informa la primera y la última fecha disponibles.

La consulta no modifica datos. Solamente devuelve un resumen de control.

## 6.1. Cantidad de filas provisionales

### Código

```sql
(SELECT COUNT(*)
 FROM stg_remision_inale) AS filas_staging,
```

- `COUNT(*)` cuenta todas las filas.
- La subconsulta consulta `stg_remision_inale`.
- `AS filas_staging` nombra el resultado.

## 6.2. Cantidad de filas analíticas

### Código

```sql
COUNT(*) AS filas_analiticas,
```

Esta expresión cuenta las filas de la tabla indicada en el `FROM` principal:

```sql
FROM analitica_remision_mensual
```

## 6.3. Comparación de cantidades

### Código

```sql
CASE
    WHEN COUNT(*) = (
        SELECT COUNT(*)
        FROM stg_remision_inale
    )
    THEN 'OK'
    ELSE 'REVISAR'
END AS control_filas,
```

- `CASE` inicia una evaluación condicional.
- `WHEN` define la condición.
- Se compara el número de filas analíticas con el número de filas provisionales.
- `THEN 'OK'` devuelve `OK` cuando las cantidades coinciden.
- `ELSE 'REVISAR'` advierte cuando no coinciden.
- `END` cierra la condición.
- `AS control_filas` nombra el resultado.

## 6.4. Primera y última fecha

### Código

```sql
MIN(fecha) AS fecha_min,
MAX(fecha) AS fecha_max
```

- `MIN(fecha)` devuelve la fecha más antigua.
- `MAX(fecha)` devuelve la más reciente.
- El formato `AAAA-MM-DD` permite que el orden textual coincida con el orden cronológico.

### Resultado esperado

```text
filas_staging    297
filas_analiticas 297
control_filas    OK
fecha_min        2002-01-01
fecha_max        2026-09-01
```

## 7. Control de valores inválidos

### Código

```sql
SELECT
    SUM(
        CASE
            WHEN fecha IS NULL THEN 1
            ELSE 0
        END
    ) AS fechas_nulas,

    COUNT(*) - COUNT(DISTINCT fecha) AS fechas_duplicadas,

    SUM(
        CASE
            WHEN remision_litros <= 0
              OR remision_millones_litros <= 0
              OR remision_kilos_solidos <= 0
            THEN 1
            ELSE 0
        END
    ) AS valores_no_positivos,

    SUM(
        CASE
            WHEN grasa_porcentaje NOT BETWEEN 0 AND 10
              OR proteina_porcentaje NOT BETWEEN 0 AND 10
            THEN 1
            ELSE 0
        END
    ) AS porcentajes_invalidos

FROM analitica_remision_mensual;
```

### Explicación general

Esta consulta cuenta cuatro posibles problemas:

- fechas nulas;
- fechas duplicadas;
- cantidades de remisión no positivas;
- porcentajes fuera del intervalo permitido.

Las restricciones de la tabla deberían impedir estos problemas durante la inserción. La consulta permite verificar explícitamente el resultado final.

## 7.1. Fechas nulas

### Código

```sql
SUM(
    CASE
        WHEN fecha IS NULL THEN 1
        ELSE 0
    END
) AS fechas_nulas,
```

Para cada fila:

- devuelve `1` si la fecha es nula;
- devuelve `0` si la fecha existe;
- `SUM()` suma los resultados;
- `AS fechas_nulas` nombra el total.

El resultado esperado es `0`.

## 7.2. Fechas duplicadas

### Código

```sql
COUNT(*) - COUNT(DISTINCT fecha) AS fechas_duplicadas,
```

- `COUNT(*)` cuenta todas las filas.
- `COUNT(DISTINCT fecha)` cuenta las fechas diferentes.
- La resta identifica cuántas fechas están repetidas.

El resultado esperado es `0`.

## 7.3. Valores no positivos

### Código

```sql
SUM(
    CASE
        WHEN remision_litros <= 0
          OR remision_millones_litros <= 0
          OR remision_kilos_solidos <= 0
        THEN 1
        ELSE 0
    END
) AS valores_no_positivos,
```

- `OR` indica que basta con que una de las condiciones sea verdadera.
- Una fila recibe el valor `1` si contiene alguna cantidad igual o inferior a cero.
- `SUM()` cuenta las filas problemáticas.

El resultado esperado es `0`.

## 7.4. Porcentajes inválidos

### Código

```sql
SUM(
    CASE
        WHEN grasa_porcentaje NOT BETWEEN 0 AND 10
          OR proteina_porcentaje NOT BETWEEN 0 AND 10
        THEN 1
        ELSE 0
    END
) AS porcentajes_invalidos
```

- `NOT BETWEEN 0 AND 10` identifica valores fuera del intervalo.
- Se revisan tanto grasa como proteína.
- `SUM()` cuenta las filas que incumplen alguna condición.

El resultado esperado es `0`.

## 8. Control de continuidad mensual

### Código

```sql
WITH orden_mensual AS (
    SELECT
        fecha,
        LAG(fecha) OVER (
            ORDER BY fecha
        ) AS fecha_anterior
    FROM analitica_remision_mensual
)

SELECT
    fecha_anterior,
    fecha AS fecha_actual,
    date(fecha_anterior, '+1 month') AS fecha_esperada

FROM orden_mensual

WHERE fecha_anterior IS NOT NULL
  AND fecha <> date(fecha_anterior, '+1 month')

ORDER BY fecha;
```

### Explicación general

Esta consulta busca saltos en la secuencia mensual.

Para cada observación, compara:

- la fecha actual;
- la fecha anterior;
- el mes que debería aparecer después de la fecha anterior.

Si la secuencia es completa, la consulta devuelve cero filas.

Por ejemplo, si después de enero apareciera marzo, la consulta mostraría:

```text
fecha_anterior = 2020-01-01
fecha_actual   = 2020-03-01
fecha_esperada = 2020-02-01
```

## 8.1. Creación de un resultado temporal

### Código

```sql
WITH orden_mensual AS (
```

`WITH` crea una expresión de tabla común, conocida como CTE.

`orden_mensual` es un resultado temporal utilizado solamente durante esta consulta. No se guarda como una nueva tabla en la base.

## 8.2. Identificación de la fecha anterior

### Código

```sql
LAG(fecha) OVER (
    ORDER BY fecha
) AS fecha_anterior
```

- `LAG(fecha)` obtiene la fecha de la fila anterior.
- `OVER` indica que se utiliza como función de ventana.
- `ORDER BY fecha` define el orden cronológico.
- `AS fecha_anterior` asigna un nombre al resultado.

Para la primera observación no existe una fecha anterior, por lo que `LAG()` devuelve un valor nulo.

## 8.3. Fecha esperada

### Código

```sql
date(fecha_anterior, '+1 month') AS fecha_esperada
```

- `date()` utiliza la fecha anterior.
- `'+1 month'` agrega exactamente un mes.
- `AS fecha_esperada` nombra el resultado.

## 8.4. Selección de los problemas

### Código

```sql
WHERE fecha_anterior IS NOT NULL
  AND fecha <> date(fecha_anterior, '+1 month')
```

- La primera condición excluye la primera observación, porque no tiene un mes anterior.
- La segunda compara la fecha observada con la fecha esperada.
- `<>` significa “diferente de”.
- Solamente se muestran las filas donde existe un salto mensual.

### Resultado esperado

La consulta debe devolver cero filas.

El período comprendido entre enero de 2002 y septiembre de 2026 contiene:

```text
24 años completos × 12 meses = 288 meses
enero a septiembre de 2026   =   9 meses
total esperado               = 297 meses
```

Las 297 observaciones disponibles son compatibles con una serie mensual completa para ese período.

## 9. Resultados esperados del script

Después de ejecutar correctamente el archivo SQL, debe existir:

```text
database/forecasting.sqlite
└── analitica_remision_mensual
```

La tabla debe contener:

- 297 filas;
- una fila por mes;
- un período desde `2002-01-01` hasta `2026-09-01`;
- ninguna fecha duplicada;
- ningún mes faltante;
- ninguna cantidad no positiva;
- ningún porcentaje fuera del intervalo permitido.

La tabla provisional `stg_remision_inale` debe continuar existiendo dentro de la misma base.

## 10. Qué no hace este script

Este script todavía no:

- convierte los datos en un objeto de serie temporal de R;
- define la frecuencia estacional de 12 meses;
- aplica logaritmos;
- calcula diferencias regulares o estacionales;
- selecciona órdenes ARIMA;
- estima modelos SARIMA;
- divide la muestra entre entrenamiento y evaluación;
- genera pronósticos;
- evalúa errores de predicción;
- elimina o corrige posibles valores atípicos.

Esas decisiones pertenecen a las etapas estadísticas posteriores y deberán justificarse mediante análisis exploratorio, validación temporal y diagnóstico de los modelos.

## 11. Resultado conceptual de esta etapa

Al finalizar esta etapa tendremos una separación clara de responsabilidades:

- R interpreta y prepara técnicamente el archivo Excel.
- SQLite almacena de forma estructurada los datos.
- SQL transforma y valida la tabla analítica.
- R utilizará la tabla validada para el análisis de series temporales.

La tabla `analitica_remision_mensual` será la fuente de datos utilizada por el siguiente componente del proyecto.