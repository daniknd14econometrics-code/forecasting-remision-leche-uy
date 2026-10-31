# Persistencia de pronósticos: ejecuciones y trayectorias de doce meses

## 1. Objetivo acordado

El objetivo operativo es utilizar **toda la historia desde enero de 2002 hasta el último mes observado**, reestimar los coeficientes de la especificación SARIMA seleccionada y pronosticar los doce meses siguientes. Cuando ingrese otra observación se repetirá ese ciclo con la historia ampliada.

Cada ejecución produce una trayectoria completa de doce meses. El seguimiento de errores es una utilización posterior de esas trayectorias; no sustituye el objetivo principal de producirlas y actualizarlas.

Se mantiene el SARIMA `(2,1,1)(1,0,0)[12]`, sin deriva, con contrastes mensuales y los efectos del cierre del 06. No se repite mensualmente la búsqueda de órdenes, quiebres u outliers, ni el backtesting completo del 07. El naïve estacional se conserva como la única referencia ya acordada.

La revisión periódica de la especificación se tratará separadamente. Esta unidad de almacenamiento no decide cambiar el modelo ni incorpora métodos estadísticos nuevos.

## 2. Alcance de esta unidad

La unidad comprende estos archivos:

```text
sql/02_crear_tablas_pronosticos.sql
R/08_preparar_persistencia_sqlite.R
R/09_registrar_pronosticos_sqlite.R
docs/sql/02_persistencia_pronosticos.md
```

El SQL define dos tablas. El script R lo ejecuta en la base ya existente y verifica su estructura y relación. **Este primer paso no inserta todavía los resultados del 07 y no genera pronósticos nuevos.** Las tablas inicialmente vacías son el resultado esperado.

El script 09 registra la corrida `20261031_171120_23228` y comprueba sus doce filas por modelo. La preparación 08, la carga inicial 09 y su repetición ya fueron ejecutadas y comprobadas en el proyecto local. Queda por conectar ese registro con el ciclo operativo que genera nuevas trayectorias.

## 3. Por qué añadir SQLite si ya tenemos CSV/RDS

Los archivos del 07 ya guardan los resultados. SQLite permite relacionar ejecuciones, pronósticos y observaciones con claves explícitas y consultar ese historial mediante SQL.

La tabla `analitica_remision_mensual` ya contiene datos observados. Las dos nuevas tablas se añaden a `database/forecasting.sqlite`; no reemplazan la tabla analítica ni staging.

| Tabla | Qué representa una fila |
|---|---|
| `forecast_ejecuciones` | Una corrida de pronósticos, con su rango de datos y metadatos |
| `forecast_pronosticos` | Un mes de una trayectoria emitida por un modelo en una corrida |

Por ejemplo, la corrida de origen septiembre de 2026 tendrá doce fechas objetivo entre octubre de 2026 y septiembre de 2027 por modelo. La siguiente corrida, con origen octubre de 2026, tendrá otras doce, desde noviembre de 2026 hasta octubre de 2027. Se conservan ambas trayectorias completas.

Cuando una fecha objetivo se repite en distintas corridas no es un duplicado: son pronósticos emitidos en momentos distintos. Lo que se impide es guardar dos veces el mismo modelo y horizonte dentro de una misma corrida.

## 4. Ejecutar en RStudio

Guardar los tres archivos en las rutas indicadas y abrir el proyecto RStudio desde su raíz. La base `database/forecasting.sqlite` debe existir y contener `analitica_remision_mensual`.

Ejecutar:

```r
source("R/08_preparar_persistencia_sqlite.R", encoding = "UTF-8")
```

`source()` ejecuta todo este primer paso y crea `persistencia08`. No requiere cargar objetos del 06 o 07 en memoria y no instala paquetes; utiliza `DBI` y `RSQLite`, ya utilizados por el proyecto.

En la primera ejecución debe aparecer:

```text
PERSISTENCIA 08 — TABLAS PREPARADAS
                 tabla filas
  forecast_ejecuciones     0
  forecast_pronosticos     0
```

Se muestra además el control de datos observados: cantidad de meses, inicio, fin y suma de litros. Con la base usada en el 07 se esperan 297 observaciones, de enero de 2002 a septiembre de 2026. Si la base se actualizó posteriormente, el control puede tener otro fin y cantidad.

Es posible repetir la preparación: no borra tablas ni datos y conserva los registros que ya pudieran haberse incorporado. `IF NOT EXISTS` evita recrear tablas existentes; el script comprueba después sus columnas y relación. No es un mecanismo de migración para una estructura distinta.

**Punto de control cumplido:** Daniel aportó la salida de RStudio del 08: ambas tablas vacías, 297 observaciones de enero de 2002 a septiembre de 2026 y suma de 44.046.232.078 litros. Se conservaron los observados. La creación de las tablas y el registro de una corrida se comprueban por separado; la ejecución del 09 se detalla en la sección 11.

## 5. Tabla de ejecuciones

| Columna | Significado |
|---|---|
| `ejecucion_id` | Identificador de la corrida; será el nombre de carpeta de resultados del 07 para la importación inicial |
| `fecha_ejecucion_utc` | Momento de generación, en UTC; no se confunde con el último mes observado |
| `inicio_datos` | Primer mes utilizado para estimar; en el flujo acordado, enero de 2002 |
| `ultimo_dato` | Último mes observado incluido en esa estimación |
| `n_observaciones` | Cantidad de meses en niveles usados por la corrida |
| `horizonte` | Doce meses en este proyecto |
| `version_modelo` | Versión documentada de la especificación principal, distinta de sus coeficientes reestimados |
| `especificacion` | Descripción del SARIMA, transformación y componentes deterministas |
| `carpeta_resultados` | Ruta relativa a los artefactos de la corrida |
| `huella_pronosticos` | MD5 del archivo de pronósticos de origen, para identificar si cambió su contenido |

`TEXT`, `INTEGER` y `REAL` declaran tipos. `NOT NULL` impide valores ausentes. `PRIMARY KEY` identifica de forma única cada corrida. `CHECK` añade condiciones, como horizonte igual a doce y fechas mensuales válidas.

El identificador representa la ejecución; no se utiliza solamente el último mes como clave. Esto permite conservar otra ejecución del mismo origen si hubiese una revisión explícita de datos o del procedimiento, con su propia identidad y metadatos.

La huella MD5 comprueba la consistencia del archivo; no es protección criptográfica. El 09 reconoce una ejecución idéntica sin duplicarla y rechaza reutilizar el identificador con contenido diferente. La huella identifica los bytes del CSV: una modificación de sus saltos de línea también cambia la huella. Se conserva el archivo original y no se fuerza su reemplazo si aparece un conflicto.

## 6. Tabla de pronósticos

| Columna | Significado |
|---|---|
| `ejecucion_id` | Corrida a la que pertenece el pronóstico |
| `modelo` | Identificador del modelo: inicialmente SARIMA o naïve estacional |
| `origen` | Último mes observado desde el cual se pronosticó |
| `fecha_objetivo` | Mes cuyo volumen se pronostica, representado por su primer día |
| `h` | Mes de anticipación dentro de la trayectoria, de 1 a 12 |
| `pred_media` | Media predictiva en litros mensuales |
| `pred_mediana` | Mediana predictiva en litros mensuales |
| `inferior80`, `superior80` | Límites del intervalo predictivo del 80% |
| `inferior95`, `superior95` | Límites del intervalo predictivo del 95% |

La clave primaria es `(ejecucion_id, modelo, h)`. También se exige unicidad de `(ejecucion_id, modelo, fecha_objetivo)`.

La clave foránea obliga a que la ejecución exista antes de registrar sus pronósticos. `ON DELETE RESTRICT` y `ON UPDATE RESTRICT` impiden eliminar o cambiar la identidad de una ejecución que ya tenga pronósticos asociados. No se activa un borrado en cascada.

Se comprueba que `fecha_objetivo` sea igual a origen más `h` meses y que los intervalos estén ordenados y anidados. No se obliga a que el límite inferior sea positivo, porque las bandas del naïve guardadas por el 07 no se recortan artificialmente.

La base no exige por sí sola que haya exactamente doce filas de cada modelo ni que el origen coincida con `ultimo_dato` de la tabla de ejecuciones. El 09 realiza esas comprobaciones al importar la trayectoria completa, antes de confirmar la transacción. Tampoco se utiliza la tabla para recalcular o sustituir predicciones previamente emitidas.

Las observaciones reales y los errores no se mezclan con estas columnas de pronóstico. Ya disponemos de los observados en la tabla analítica; posteriormente se relacionarán por fecha objetivo. Si la fuente revisa datos, se documentará qué versión del observado se usa al evaluar. Los archivos originales fechados y los artefactos de cada corrida permanecen conservados.

## 7. Recorrido del script R, bloque por bloque

### Bloque 1 — Dependencias y rutas

Comprueba `DBI`, `RSQLite`, la existencia de la base y la del SQL. Usa rutas relativas desde la raíz. No crea silenciosamente una base vacía en otra carpeta.

### Bloque 2 — Lectura del SQL

`readLines()` lee el archivo UTF-8; se quitan comentarios de línea y se separan las dos instrucciones por punto y coma. Se exige que ambas comiencen con `CREATE TABLE IF NOT EXISTS`.

Esta separación es suficiente para el archivo entregado, con dos DDL sencillas. No es un analizador general de SQL: no debe reutilizarse sin adaptación para triggers o textos que contengan puntos y coma.

### Bloque 3 — Conexión y relaciones

`dbConnect()` abre la base y `on.exit(dbDisconnect(...))` garantiza el cierre al terminar o fallar la función. Se exige la tabla analítica del proyecto.

`PRAGMA foreign_keys = ON` activa el control de claves foráneas en esa conexión y se verifica su valor. Debe activarse también en futuras conexiones que escriban pronósticos: no basta con hacerlo una vez al crear la base.

Se toma un control agregado de la tabla analítica antes de la preparación. No se introducen nuevas observaciones ni se transforman sus valores.

### Bloque 4 — Transacción y estructura

`dbWithTransaction()` ejecuta ambas creaciones como una unidad: si ocurre un error dentro del bloque, se revierte la transacción. Se comprueban nombres y orden de columnas, la relación de clave foránea y que el control agregado de los observados no cambie.

El archivo SQL no incluye su propio `BEGIN` o `COMMIT`: la transacción la administra R, evitando transacciones anidadas.

### Bloque 5 — Comprobación final

Se consultan las tablas mediante `sqlite_master`, se cuentan sus filas y se comprueba integridad referencial. El resultado se imprime y se devuelve como lista en `persistencia08`.

El script no contiene `DROP`, `DELETE`, `UPDATE`, carga de predicciones ni llamadas al modelado. Si se detecta una estructura previa incompatible, se informa el problema; no se aplica una migración automática.

## 8. Relación con la automatización posterior

El flujo que estamos preparando es:

1. Detectar datos nuevos o revisiones y actualizar la información validada.
2. Utilizar toda la historia desde 2002 al último mes observado para reestimar los coeficientes del mismo SARIMA.
3. Generar los siguientes doce meses y conservar también la referencia.
4. Registrar la ejecución y la trayectoria completa en las tablas de esta unidad.
5. Cuando corresponda, obtener errores frente a observaciones ya disponibles y actualizar el seguimiento.

El 08 implementa la estructura necesaria para el punto 4; el 09 añade la importación de la corrida revisada que ya produjo el 07. Esto todavía no constituye el ciclo mensual automatizado completo.

El registro inicial del 07 permitirá comprobar una ejecución y 24 filas: doce SARIMA y doce naïve. Una nueva ejecución mensual añadirá otra trayectoria; no reemplazará la anterior. Las métricas por horizonte podrán obtenerse después sin cambiar este objetivo operativo.

## 9. Verificación y estado

El SQL se comprobó en una base temporal de SQLite: creación repetida sin borrar datos, carga de prueba de las 24 predicciones del 07, relación entre tablas, rechazo de claves duplicadas, fechas incompatibles, intervalos mal ordenados y textos en campos numéricos. Se confirmó que los datos observados se conservaran.

También se ejecutó el script R completo mediante `source()` en un entorno temporal con R 4.3.3, DBI 1.2.2 y RSQLite 2.3.4. La base de prueba contenía los 297 meses del archivo de datos del 07. Se verificaron la creación inicial con conteos 0/0, su repetición y la conservación de una ejecución y 24 pronósticos añadidos solamente como prueba técnica. El conteo, período y suma de los datos observados se mantuvieron.

La prueba temporal no escribió en la base de Windows ni equivale a registrar allí la corrida. Daniel comprobó después la ejecución local del 08 y las dos ejecuciones del 09. La primera indicó `Registrada correctamente`; la segunda, `Ya registrada; sin cambios ni duplicados`. En ambas salidas del 09 se mantuvieron una ejecución, 24 pronósticos y los 297 meses observados, de enero de 2002 a septiembre de 2026, con suma de 44.046.232.078 litros.

El 09 se probó por separado en R 4.3.3 con DBI 1.2.2 y RSQLite 2.3.4, utilizando los CSV y el RDS reales de la corrida del 07. Se verificaron: registro inicial 1/24, repetición sin duplicados, rechazo de una versión incompatible bajo el mismo identificador, rechazo de una trayectoria incompleta y de discrepancias CSV/RDS, y reversión completa ante un fallo forzado durante la inserción de pronósticos. Los 297 meses observados y su suma permanecieron iguales. Estas pruebas se hicieron en una base temporal, sin reestimar modelos ni modificar archivos originales.

La carga inicial y su repetición están comprobadas. Su publicación se documenta en [el registro Git de esta unidad](../git/06_persistencia_pronosticos_sincronizacion.md); los comandos de publicación están preparados y pendientes de la salida local. La base SQLite sigue excluida por `.gitignore`; se versionan el SQL, los scripts y su documentación, no la base local por accidente.

## 10. Referencias técnicas

- [SQLite: CREATE TABLE](https://www.sqlite.org/lang_createtable.html).
- [SQLite: claves foráneas](https://www.sqlite.org/foreignkeys.html).
- [DBI: dbWithTransaction](https://dbi.r-dbi.org/reference/dbWithTransaction.html).

Las restricciones son reglas de integridad del almacenamiento. No son nuevas pruebas estadísticas ni modifican el modelo elegido.

## 11. Registrar ahora la corrida del 07

Guardar el archivo completo como `R/09_registrar_pronosticos_sqlite.R`. Con el proyecto abierto desde su raíz, ejecutar:

```r
source("R/09_registrar_pronosticos_sqlite.R", encoding = "UTF-8")
```

No hace falta volver a ejecutar 06, 07 ni 08. Se requiere que la base ya preparada y la carpeta original sigan presentes:

```text
outputs/evaluacion_predictiva/07_sarima_vs_naive/20261031_171120_23228/
```

El script lee tres archivos de esa carpeta:

| Archivo | Uso en el registro |
|---|---|
| `00_diseno_evaluacion.csv` | Identificar la especificación, el período y el horizonte |
| `10_pronosticos_proximos_12_meses.csv` | Obtener las 24 predicciones y calcular su huella MD5 |
| `16_objeto_evaluacion07.rds` | Contrastar las predicciones, comprobar los datos de entrenamiento y recuperar el momento de ejecución |

No carga las predicciones históricas del backtesting en las tablas. Registra únicamente los doce meses futuros de cada modelo ya generado por el 07. La presencia del naïve no incorpora otro modelo nuevo: conserva la referencia acordada y ya incluida en esos archivos.

El resultado inicial esperado es:

```text
REGISTRO 09 — PRONOSTICOS EN SQLITE
Corrida: 20261031_171120_23228 | Registrada correctamente
Datos utilizados: 2002-01-01 a 2026-09-01 | Meses: 297

           modelo filas h_min h_max      desde      hasta
 Naive_estacional    12     1    12 2026-10-01 2027-09-01
           SARIMA    12     1    12 2026-10-01 2027-09-01

                tabla filas
 forecast_ejecuciones     1
 forecast_pronosticos    24
```

Son **una ejecución y 24 pronósticos**, no 24 ejecuciones. El origen es septiembre de 2026; las fechas objetivo van de octubre de 2026 a septiembre de 2027. Se imprime también el control de observados. Los totales 1/24 corresponden a esta primera carga, partiendo de las tablas vacías confirmadas en el 08.

Para comprobar la repetición basta con ejecutar el mismo `source()` otra vez. Debe indicar `Ya registrada; sin cambios ni duplicados`, conservando los totales 1/24. `registro09` contiene el resumen devuelto por la última ejecución.

**Punto de control cumplido:** Daniel aportó ambas salidas locales. El registro inicial y la repetición dieron los resultados previstos: una ejecución, doce filas por modelo, las mismas fechas objetivo y los observados conservados. El siguiente paso es publicar esta unidad en Git antes de conectar la persistencia con la generación mensual.

## 12. Recorrido del script 09

### Bloque 1 — Archivos e identidad

Comprueba las dependencias, la base y los tres archivos. La carpeta predeterminada es la corrida revisada; no busca automáticamente la carpeta más reciente. Se exige una ruta dentro del proyecto y se guarda su forma relativa, evitando registrar la ruta personal de Windows.

La función `registrar_pronosticos09()` permite indicar otra carpeta explícitamente cuando corresponda. El `source()` inicial usa la corrida indicada arriba. Su identificador es el nombre de carpeta; no se deduce de esa cadena la hora de ejecución.

### Bloque 2 — Datos utilizados y metadatos

Verifica que el objeto del 07 esté finalizado y que la historia de entrenamiento sea mensual, sin huecos, con valores positivos y desde enero de 2002. Compara el diseño CSV con el del RDS. El último mes de esa historia debe ser el origen de los pronósticos.

Se registra la fecha de ejecución almacenada en el RDS, convertida a UTC. No es la hora de importación ni se interpreta el nombre de carpeta como un reloj con zona horaria conocida. Para esta corrida el valor guardado en el objeto corresponde a `2026-10-31T16:19:44Z`.

`SARIMA_06_v1` es la etiqueta inicial que asignamos ahora a la especificación cerrada del 06. No significa que exista una variable con ese nombre en el objeto original, ni que los coeficientes queden congelados. La descripción también explicita la transformación `log(litros/dias_del_mes)`.

Se utiliza la historia archivada por la corrida para sus metadatos. Si la tabla analítica incorpora nuevos meses o revisiones posteriormente, eso no cambia el período con que se emitieron estos pronósticos. Esta carga no vuelve a validar ni a sustituir observaciones: esa tarea pertenece al flujo de datos.

### Bloque 3 — Trayectorias completas y coincidencia entre fuentes

Exige exclusivamente los dos modelos acordados, con una fila de cada horizonte 1 a 12; comprueba claves, origen, fechas objetivo, valores numéricos finitos y orden de los intervalos. No exige que todos los campos auxiliares del CSV tengan valores: el naïve no necesita columnas del cálculo logarítmico del SARIMA.

Contrasta los campos que se almacenan con los del RDS. Para cantidades en litros admite una diferencia absoluta máxima de `0,00001`, destinada únicamente al redondeo de escritura/lectura del CSV; no es una tolerancia porcentual. No recalcula las predicciones.

### Bloque 4 — Carga completa o reversión completa

Abre una conexión a la base existente, activa claves foráneas y comprueba las columnas preparadas por el 08. Usa consultas parametrizadas para el identificador.

Dentro de `dbWithTransaction()`, si la ejecución no existe, inserta primero sus metadatos y luego los 24 pronósticos. Lee lo guardado y lo contrasta con la fuente antes de confirmar. Si falla una parte, se revierten las dos inserciones.

Si el identificador ya existe y coinciden los metadatos, la huella y los pronósticos, reconoce la repetición sin escribir. Si difieren, termina con un error: no borra, reemplaza ni actualiza el registro previo. Una nueva emisión deliberada necesita su propia identidad y sus artefactos; no se cambia una predicción pasada para mejorar su coincidencia con lo observado.

También verifica la integridad referencial y que el control agregado de la tabla analítica se conserve. El código solo escribe en las dos tablas de pronósticos.

### Bloque 5 — Comprobación visible

Muestra las doce filas por modelo, sus horizontes y fechas, los totales de las tablas y el control de observados. Devuelve esos resultados en `registro09`. No estima, pronostica, evalúa errores nuevos ni instala paquetes.

## 13. Lo que queda después de este registro

El 09 ya quedó comprobado localmente. Corresponde seguir [el registro Git de esta unidad](../git/06_persistencia_pronosticos_sincronizacion.md) y sincronizar SQL, scripts y documentación. La base local conserva los datos cargados y sigue fuera del repositorio según la configuración existente; publicar código no equivale a publicar ni respaldar automáticamente esa base.

Después construiremos el ciclo operativo: detectar datos nuevos, validar y actualizar la serie, reestimar el mismo SARIMA con toda la historia disponible, generar los siguientes doce meses y guardar una nueva ejecución completa. Antes de automatizarlo en un entorno remoto deberá resolverse dónde se conserva la base entre ejecuciones. El registro inicial implementado aquí es una parte concreta de ese flujo, no su automatización completa.
