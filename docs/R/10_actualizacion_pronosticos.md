# Script 10: actualización local y pronósticos de remisión de leche

## 1. Objetivo y punto de partida

Este módulo implementa el ciclo operativo local acordado: comprobar la fuente del INALE, preparar toda la historia desde enero de 2002 hasta el último mes observado y, cuando corresponda, reestimar los coeficientes del mismo SARIMA para pronosticar los doce meses siguientes. Conserva el naïve estacional como referencia y registra cada nueva emisión completa en SQLite. Produce además un reporte visible de los doce meses, con pronósticos, intervalos, valores reales y diferencias; los meses aún no observados permanecen en la tabla.

El modelo sigue siendo **SARIMA(2,1,1)(1,0,0)[12]**, sin deriva, con once contrastes mensuales en diferencias, TC de febrero de 2006 con delta 0,7 y AO de abril de 2004. La transformación es el logaritmo del promedio diario: `log(remision_litros / dias_mes)`. No se ejecutan otra vez la selección del 06 ni el backtesting completo del 07. No se introducen nuevos métodos estadísticos.

Los scripts 08/09 ya prepararon las tablas y registraron la corrida `20261031_171120_23228`: una ejecución y 24 pronósticos. Su repetición conservó esos totales. Esa unidad se publicó en `38b950d`; Daniel aportó push correcto, árbol limpio y `0 0`, y se verificó el mismo commit en la rama remota `main`.

La publicación de ese código no significa que GitHub contenga la base local: SQLite sigue excluida de Git. Este módulo se prueba primero en el proyecto local. GitHub Actions será una etapa posterior.

## 2. Qué hacer ahora

Guardar estos dos archivos:

```text
R/10_actualizar_pronosticos.R
docs/R/10_actualizacion_pronosticos.md
```

No reemplazan ni modifican 01–09 ni los SQL existentes. Abrir el proyecto RStudio desde su raíz y ejecutar:

```r
source("R/10_actualizar_pronosticos.R", encoding = "UTF-8")
```

`source()` ejecuta todo el ciclo y devuelve `operacion10`. No hace falta cargar objetos anteriores en memoria. Utiliza paquetes ya empleados por el proyecto: `DBI`, `RSQLite`, `readxl`, `cellranger` y `forecast`. Comprueba su disponibilidad; no los instala ni modifica `renv.lock`.

Después de ejecutarlo, abrir con doble clic:

```text
outputs/reportes/pronostico_actual.html
```

Es la ubicación fija del reporte actual: **doce filas del SARIMA**, con una sección desplegable para consultar las doce del naïve. También se guarda `outputs/reportes/pronostico_actual.csv`. Para acceder a las emisiones anteriores, abrir `outputs/reportes/index.html` o utilizar el enlace del reporte. No hay que recorrer carpetas de controles para encontrar la tabla principal.

El script imprime igualmente las doce filas en la consola, aun cuando no corresponda volver a estimar. En RStudio también puede consultarse:

```r
View(operacion10$reporte_sarima)
```

Requiere conexión a internet para comprobar la página y descargar su Excel. También requiere la base preparada, el cierre guardado del 06, los SQL y los archivos de las emisiones registradas. No basta con tener únicamente las dos tablas sin sus artefactos.

**Punto de control cumplido:** Daniel ejecutó en Windows tanto la versión inicial como esta versión con el reporte completo. La segunda salida mostró las doce filas SARIMA de octubre de 2026 a septiembre de 2027, reales y diferencias pendientes, las rutas del HTML actual y del historial, y los mismos totales de una ejecución y 24 pronósticos. No se reestimó ni se actualizaron los datos. La evidencia de ambas versiones se diferencia en la sección 14; no hace falta repetir el ciclo para documentar este cierre.

## 3. Cuándo se genera otra trayectoria

| Situación | Actualización de la tabla analítica | Reestimación y nueva emisión |
|---|---|---|
| Mismos datos y emisión completa ya registrada con el mismo cierre | No se reescriben los mismos valores | No |
| Uno o más meses nuevos | Sí | Sí: toda la historia y doce meses desde el último observado |
| Revisión de litros de meses anteriores | Sí | Sí, conservando la misma especificación y las emisiones anteriores |
| Cambios solo de sólidos, composición u observaciones | Sí, cuando cambian esos campos | No, si los litros y la emisión correspondiente siguen iguales |
| Serie válida pero sin emisión correspondiente | Cuando hace falta | Sí |
| Fuente incompleta, unidades inesperadas o ajuste no admisible | No se confirma la actualización | No se registra otra emisión |

El identificador de una emisión no es solamente su origen. Por eso puede haber una nueva emisión desde el mismo mes si INALE revisa datos históricos: cambió la información utilizada, aunque no haya avanzado el último mes.

Una revisión no dispara por sí sola una búsqueda de otros órdenes o efectos. Se mantienen las decisiones del 06 y se vuelven a estimar sus coeficientes con la información vigente. Si los diagnósticos empeoran, se informa; no se sustituye automáticamente el SARIMA.

Si llegan varios meses juntos, se emite desde el último de ellos. No se inventan corridas intermedias como si se hubieran emitido antes de conocer esos datos.

## 4. Entradas, salidas y estado esperado

Entradas principales:

```text
database/forecasting.sqlite
sql/01_crear_tabla_analitica.sql
outputs/sarima_box_jenkins/09_cierre_modelado/11_objeto_bloque09.rds
```

Para reconocer una emisión previa se leen sus archivos `15_modelo_y_pronosticos_actuales.rds` y `10_pronosticos_proximos_12_meses.csv`, en la carpeta relativa guardada en `forecast_ejecuciones`. Esto incluye la corrida original del 07 ya registrada.

Cada comprobación crea una carpeta de control independiente:

```text
outputs/operacion_mensual/op10_<marca_UTC>_<PID>/
```

Una **carpeta de control** no equivale siempre a otra **emisión de pronósticos**. Si los datos no cambian, se guardan las comprobaciones, pero no se añade una ejecución a las tablas de pronósticos.

| Archivo de salida | Contenido |
|---|---|
| `00_estado.txt` | Resultado del ciclo o indicación de fallo |
| `00_fuente.csv` | Archivo original utilizado, URL o entrada local, huella y momento de comprobación |
| `01_datos_utilizados.csv` | Serie completa utilizada en la comprobación |
| `02_cambios_remision.csv` | Meses nuevos o revisados frente a la tabla analítica anterior |
| `03_seguimiento_emitido_vs_observado.csv` | Todas las fechas de las emisiones registradas, incluidas las futuras; observado y error vacíos hasta que exista el dato |
| `04_reporte_sarima_actual.csv` | Copia de las doce filas del SARIMA actual y su seguimiento al ejecutar este control |
| `04_reporte_sarima_actual.html` | Copia visible del reporte actual en el momento de la comprobación |
| `00_diseno_operacion.csv` | Solo al emitir: especificación, período, horizonte y huella del cierre |
| `10_pronosticos_proximos_12_meses.csv` | Solo al emitir: doce filas SARIMA y doce naïve |
| `11_coeficientes_ajuste_actual.csv` | Solo al emitir: coeficientes y errores estándar condicionales |
| `12_diagnostico_ajuste_actual.csv` | Solo al emitir: raíces, covarianzas, dispersión y Ljung–Box |
| `13_intentos_estimacion_actual.csv` | Intentos de ajuste; también se conserva si falla la estimación |
| `15_modelo_y_pronosticos_actuales.rds` | Solo al emitir: modelos, regresores, datos completos, efectos y predicciones |
| `16_objeto_operacion10.rds` | Resumen del ciclo completado, identificación de la emisión y conteos |
| `17_sessionInfo.txt` | Versiones de R y paquetes de la ejecución |

Si nada cambió desde la carga inicial, se espera una salida equivalente a:

```text
Datos: 2002-01-01 a 2026-09-01 | Meses: 297
Meses nuevos: 0 | Meses con revision de litros: 0
Ya existe una trayectoria completa con estos mismos datos y cierre: 20261031_171120_23228

RESULTADO DEL CICLO 10
No se reestimo ni se duplicaron pronosticos.
Actualizacion de tablas de datos: FALSE

                tabla filas
 forecast_ejecuciones     1
 forecast_pronosticos    24
Errores disponibles frente a observados actuales: 0
```

El seguimiento tiene cero errores mientras no haya observaciones de las fechas futuras emitidas: octubre de 2026 a septiembre de 2027. No se rellenan esos errores con ceros. Cuando llegue un mes observado podrán compararse las predicciones anteriores para ese mes.

**Cero errores disponibles no significa una tabla sin filas:** el reporte actual siempre muestra sus doce meses, con `Pendiente` y campos reales/diferencias vacíos en el CSV. En HTML se representan con un guion largo. La consola usa `NA` para esos valores ausentes.

Las salidas de consulta se guardan además en rutas fijas:

| Ruta | Qué permite consultar |
|---|---|
| `outputs/reportes/pronostico_actual.html` | Reporte actual del SARIMA, con referencia naïve desplegable |
| `outputs/reportes/pronostico_actual.csv` | Doce filas del SARIMA actual, con precisión numérica completa |
| `outputs/reportes/naive_actual.csv` | Doce filas de la referencia actual |
| `outputs/reportes/index.html` | Índice de todas las emisiones registradas, identificadas por origen e ID |
| `outputs/reportes/emisiones/<id>/reporte.html` | Reporte de una emisión concreta, actualizado con los observados disponibles |
| `outputs/reportes/emisiones/<id>/sarima.csv` | Doce filas y seguimiento del SARIMA de esa emisión |
| `outputs/reportes/emisiones/<id>/naive_estacional.csv` | Seguimiento equivalente de la referencia |

Las rutas fijas y los reportes de cada emisión se actualizan en cada ciclo. No se editan manualmente sus observados: proceden de la tabla analítica. El archivo original de predicciones del 07 y los registros de pronósticos en SQLite permanecen intactos. Cada carpeta de control conserva además una copia del reporte actual en ese momento.

Si llega un nuevo mes, los totales pasarán inicialmente a dos ejecuciones y 48 pronósticos. Una segunda comprobación de los mismos datos debe mantener esos totales. Es un ejemplo de comportamiento; la salida real depende de la fuente al ejecutar.

## 5. Configuración

`config10` agrupa las rutas, la URL, el horizonte y las opciones de estimación. La configuración normal usa `archivo_local = NULL`: se comprueba INALE en esa ejecución.

```r
config10$horizonte       # 12
config10$version_modelo  # "SARIMA_06_v1"
```

`SARIMA_06_v1` identifica la arquitectura acordada; no congela los coeficientes. Se valida el cierre real para comprobar órdenes, ausencia de deriva, efectos y diseño. Cambiar ese texto no implementa por sí solo otro modelo.

La función de trabajo es `ejecutar_ciclo10(cfg)`. El archivo termina con:

```r
operacion10 <- ejecutar_ciclo10(config10)
```

Esto asegura que `source()` haga el trabajo completo. El parámetro `archivo_local` existe para reproducir una copia concreta o ejecutar pruebas en una base temporal; no es necesario configurarlo en la operación normal. No se deben cargar datos ficticios en el proyecto real para probar la llegada de otro mes.

## 6. Bloque 1: cálculo predictivo del modelo fijo

Se trasladaron catorce funciones del 07 con el prefijo `op10_`. Su contenido de cálculo es el mismo; el cambio de prefijo evita confundir objetos. Se verificó esa coincidencia automáticamente. No se hace `source()` del 07 porque eso ejecutaría también su backtesting histórico.

| Funciones | Responsabilidad |
|---|---|
| `op10_csv`, `op10_juntar` | Escritura de CSV y unión de registros de intentos |
| `op10_mes_siguiente`, `op10_dias_mes` | Calendario de doce meses y duración real de cada mes |
| `op10_contrastes`, `op10_diseno` | Once contrastes mensuales y perfiles AO/TC, con diseños compatibles de niveles y diferencias |
| `op10_raices`, `op10_cov_valida` | Admisibilidad de la parte ARMA y validez numérica de la matriz de covarianzas |
| `op10_estimar` | Reestimación conjunta del mismo modelo con varios inicios numéricos |
| `op10_pronosticar_sarima` | Trayectoria integrada, varianza predictiva y vuelta a litros |
| `op10_pronosticar_naive` | Referencia estacional sobre promedio diario, reconvertida a litros mensuales |
| `op10_coeficientes`, `op10_diagnostico` | Coeficientes, errores estándar y controles del ajuste |
| `op10_futuro` | Coordinación del ajuste y las dos trayectorias a doce meses |

La ecuación estimada sigue siendo un ARMA sobre la primera diferencia del logaritmo del promedio diario. El código utiliza:

```r
stats::arima(y, order = c(2L, 0L, 1L),
  seasonal = list(order = c(1L, 0L, 0L), period = 12L),
  xreg = X, include.mean = FALSE, method = "ML", ...)
```

El cero en `d` de esa llamada corresponde a que `y` ya está diferenciada. La representación de la serie original conserva **d=1, D=0**. No se cambia a una serie original estacionaria en niveles.

Los inicios numéricos se calculan con el entrenamiento actual. Todos estiman la misma especificación. Se selecciona el mayor logaritmo de verosimilitud entre ajustes convergentes con parámetros y raíces admisibles; el ciclo exige también covarianzas válidas antes de emitir. No se comparan otros órdenes SARIMA.

AO es un pulso en log-niveles; TC decae con delta 0,7. Sus perfiles se diferencian para la ecuación de diferencias. Los contrastes mensuales se acumulan al construir los regresores del filtro integrado. No se reemplazan observaciones originales.

Para pronosticar log-niveles se usa un filtro integrado con los parámetros fijados a los estimados sobre diferencias. Esa llamada no selecciona ni estima un segundo modelo. Permite obtener la varianza predictiva integrada teniendo en cuenta las covarianzas entre diferencias. Se comprueba que su media coincida con acumular las diferencias pronosticadas.

La vuelta a litros conserva las fórmulas del 07:

```text
media   = días_del_mes × exp(media_log + varianza_log / 2)
mediana = días_del_mes × exp(media_log)
```

Las bandas del 80% y 95% son condicionales al modelo, a parámetros estimados fijos y a regresores conocidos. No incorporan incertidumbre de selección, de parámetros, futuras revisiones ni eventos nuevos desconocidos. El naïve utiliza el promedio diario del mismo mes del año previo por los días del mes objetivo; sus bandas no se recortan artificialmente.

## 7. Bloque 2: comprobar y conservar la fuente

`op10_fuente()` descarga la página y exige un único enlace Excel absoluto, siguiendo la estructura utilizada por el 01. Descarga el Excel a un archivo temporal en modo binario y solicita no reutilizar caché. Si falla la conexión o cambia la estructura de enlaces, termina con un error visible antes de escribir en SQLite.

A diferencia del 01, no omite la comprobación porque exista una copia del mismo día. INALE podría revisar su Excel sin que haya cambiado nuestra fecha de ejecución.

Calcula MD5 con `tools::md5sum()`. Si ese archivo exacto ya está conservado en `data/original/`, lo reutiliza; de lo contrario guarda otra copia fechada con hora UTC y una parte de la huella. No sobrescribe los originales. MD5 se utiliza para reconocer archivos y detectar cambios, no como protección criptográfica.

Un Excel distinto no implica necesariamente litros distintos: también pueden cambiar notas o formato. La decisión de reestimar se basa posteriormente en las observaciones utilizadas por el modelo, no solo en los bytes del Excel.

## 8. Bloque 3: lectura, unidades y cambios

`op10_leer_excel()` usa el mismo rectángulo del 02: hoja `Listado Datos`, desde B5 hasta la columna G, con altura variable. Lee como texto y valida los seis encabezados esperados. Se excluyen las filas no mensuales de títulos y notas según la presencia de una fecha Excel numérica.

Convierte las fechas con origen `1899-12-30`, igual que 02/03. Los campos numéricos deben ser finitos. La remisión en litros y los sólidos deben ser positivos; grasa y proteína deben conservar las proporciones de la fuente, compatibles con 0–10% después de multiplicar por cien.

Se ordenan las observaciones y se exige una serie mensual sin duplicados, sin huecos y desde enero de 2002. No se imputan ni se eliminan meses para hacer pasar una fuente incompleta.

Prepara dos objetos: staging con las columnas de carga y la serie para el modelo con fechas, litros, días del mes, promedio diario y logaritmo. Las cifras observadas no se corrigen por atípicos: los efectos pertenecen a los regresores del modelo.

Funciones auxiliares:

- `op10_misma_serie()` compara fechas y litros con los datos de una emisión anterior.
- `op10_cambios()` identifica meses nuevos y revisiones de litros frente a SQLite. Rechaza que desaparezcan meses previamente almacenados.
- `op10_mismos_campos()` compara también sólidos, composición y observaciones. Ignora diferencias en el sello horario y nombre del archivo para no reescribir por esos metadatos solos.

Las comparaciones numéricas admiten únicamente tolerancias de representación: `0,00001` litros o kilos, y `1e-10` puntos porcentuales en composición. Son diferencias absolutas minúsculas que evitan confundir redondeos de lectura/escritura con revisiones. No son tolerancias porcentuales ni reglas estadísticas para ignorar revisiones económicas.

## 9. Bloque 4: recuperar el cierre

`op10_cierre()` lee el objeto final del 06 y valida arquitectura, efectos y delta. También reproduce los regresores del desarrollo. Recupera su huella para identificar con qué cierre se genera cada emisión.

El 07 exigía reproducir los valores de desarrollo porque su ejercicio estaba fijado a una muestra histórica. En este módulo operativo una revisión válida de esos valores sí puede incorporarse al nuevo ajuste, conservando la especificación. Esa revisión aparece en `02_cambios_remision.csv`; no cambia los artefactos del 06 ni las predicciones previamente emitidas.

Este módulo no interpreta una revisión administrativa de datos como prueba de cambio estructural ni vuelve a decidir d o D.

## 10. Bloque 5: reconocer y comprobar emisiones anteriores

`op10_pred_db()` valida las dos trayectorias completas antes de registrarlas: 24 filas, ambos modelos, horizontes 1–12 sin duplicados, origen y fecha objetivo compatibles, predicciones finitas y positivas e intervalos ordenados. Produce las columnas del esquema creado por el 08.

`op10_igual_registro()` compara ese resultado con SQLite, permitiendo solo el redondeo numérico mínimo de almacenamiento.

`op10_buscar_emision()` busca emisiones de la misma versión de especificación y último mes. Para reconocer una emisión como repetición exige:

1. La misma historia de fechas y litros, recuperada de su RDS.
2. La misma huella del cierre del 06.
3. El archivo CSV original conservado con la huella registrada.
4. Las 24 predicciones en SQLite coincidentes con las archivadas.
5. Metadatos compatibles de cantidad de observaciones y horizonte.

No basta con encontrar el mismo mes de origen. Si los litros cambiaron, se necesita otra emisión. Si falta un archivo de una emisión registrada o su contenido ya no coincide, se detiene en lugar de ocultar la inconsistencia.

Las huellas de CSV se calculan sobre bytes: cambiar sus saltos de línea modifica la huella aunque los números parezcan iguales. No se editan ni normalizan las fuentes ya registradas para forzar que pase esta comprobación. La continuidad de base y artefactos entre entornos deberá preservarse al configurar Actions.

## 11. Bloque 6: reutilizar el SQL analítico

`op10_actualizar_tablas()` reutiliza `sql/01_crear_tabla_analitica.sql`. No necesita una segunda definición distinta de unidades o columnas. Actualiza staging y reconstruye la tabla analítica vigente con el mismo SQL utilizado por el 04.

La diferencia operativa es que elimina de las instrucciones a ejecutar el `BEGIN TRANSACTION` y el `COMMIT` del archivo original: aquí la transacción la administra `DBI::dbWithTransaction()` junto con el registro de pronósticos. El archivo SQL original permanece intacto.

Se ejecutan las mismas tres consultas de control: cantidad de filas/período, valores inválidos y continuidad mensual. Sus resultados deben ser correctos antes de confirmar. El SQL no reconstruye ni borra las dos tablas de pronósticos.

La tabla analítica representa la versión vigente de los observados; no es por sí sola un historial de publicaciones. Se conservan los originales y los datos de cada comprobación/emisión para distinguir la información utilizada en diferentes fechas.

## 12. Bloque 6B: reportes de doce meses y emisiones anteriores

`op10_generar_reportes()` consulta todos los pronósticos registrados mediante `LEFT JOIN` con la tabla de observados. De ese modo conserva las fechas futuras aunque todavía no haya un valor real. Las doce filas de cada modelo se validan y ordenan por horizonte antes de exportar.

Para cada fila se calculan:

```text
diferencia_litros = real_litros − pronostico_litros
diferencia_pct    = 100 × diferencia_litros / real_litros
```

Ambas diferencias quedan ausentes mientras no haya un observado. El porcentaje usa el real como denominador. Una diferencia positiva indica que el pronóstico quedó por debajo de lo observado.

Cada CSV del SARIMA contiene fecha objetivo, horizonte, pronóstico, real, diferencia en litros y porcentaje, límites 80/95%, estado, origen e identificador de emisión. Tiene doce filas, no veinticuatro; la referencia se exporta por separado. El CSV mantiene la precisión original y utiliza el formato de comas/UTF-8 del proyecto; en Excel puede importarse indicando ese separador.

`op10_html_reporte()` transforma esa tabla en un HTML autónomo, sin conexión externa, con cifras legibles y los intervalos. Presenta primero el SARIMA, deja la referencia en una sección desplegable y muestra origen, fecha de generación, corte de observados y actualización del seguimiento. Los valores en litros se redondean solo para mostrar; las celdas pendientes se identifican expresamente. Los datos de texto se escapan al incorporarlos al HTML.

Se actualizan los reportes **de todas las emisiones**, no solo el actual. Ejemplo: al llegar octubre de 2026, la emisión de septiembre conserva sus pronósticos de octubre–septiembre y completa el real de octubre y su diferencia. La nueva emisión, con origen octubre, pasa a ser el reporte actual y muestra noviembre–octubre con sus propios doce pronósticos. El índice permite seguir consultando la emisión anterior y ver cómo se completa. Una revisión del observado modifica su diferencia en el reporte, pero nunca el pronóstico original.

El HTML y los CSV de consulta son vistas actualizables. Las copias de `04_reporte_sarima_actual.*` dentro de cada carpeta de control permiten ver cómo se presentaba el reporte en esa comprobación. No se sobrescriben los CSV originales ni los RDS de las emisiones para actualizar sus observados.

## 12B. Bloque 7: coordinación y confirmación del ciclo

`ejecutar_ciclo10()` coordina todas las funciones anteriores:

1. Comprueba paquetes, rutas y configuración.
2. Crea un bloqueo local para impedir dos ciclos 10 simultáneos sobre la misma base y una carpeta de control propia.
3. Descarga/conserva el original, valida su contenido y recupera la especificación.
4. Compara con SQLite y busca una emisión equivalente.
5. Si falta esa emisión, estima y prepara pronósticos/artefactos **antes de confirmar escrituras en la base**.
6. En una sola transacción actualiza datos, cuando hace falta, e inserta los metadatos y 24 pronósticos de una nueva emisión.
7. Comprueba los datos guardados, las predicciones y la integridad referencial.
8. Genera los reportes completos, cuenta únicamente los errores con real disponible, guarda el resumen y muestra las doce filas actuales.

La conexión activa claves foráneas y utiliza consultas parametrizadas para identificadores. `on.exit()` cierra la conexión y retira el bloqueo al terminar normalmente o ante un error manejado. Antes de escribir se verifica que la tabla analítica no haya cambiado mientras se calculaba el ajuste.

El bloqueo es la carpeta `database/operacion10.lock`, que contiene PID y momento de inicio. Si R se cerrase abruptamente podría quedar allí. No se elimina un bloqueo encontrado de manera automática: primero hay que comprobar que no siga otra ejecución activa. Una nueva corrida informa el problema de forma visible.

La transacción se confirma completa o se revierte completa. Si falla una inserción de pronósticos después de actualizar staging/analítica, también se revierten esas actualizaciones. Si falla la estimación, ni siquiera comienza esa escritura. El original descargado y la carpeta de diagnóstico pueden quedar disponibles para investigar el fallo.

Las carpetas no tienen una transacción conjunta con SQLite. Por eso `00_estado.txt` diferencia un error anterior a la confirmación de un fallo al exportar después de que SQLite ya se confirmó. En ese último caso se revisa el registro y se puede repetir la comprobación; no se fuerza una segunda emisión. El reconocimiento de emisiones se apoya en SQLite y en los artefactos, no solo en un nombre de carpeta.

Cuando no hace falta emitir, no se llaman las funciones de estimación; sí se generan/actualizan los reportes. Si solo cambiaron campos ajenos a los litros, puede actualizar la tabla analítica conservando la emisión existente. `operacion10$reporte_sarima` contiene la tabla de doce filas y `operacion10$ruta_reporte` la ruta del HTML actual.

## 13. Seguimiento inicial frente a datos observados

La consulta conserva todos los pronósticos guardados y añade el observado por fecha objetivo cuando existe:

```sql
SELECT p.ejecucion_id, p.modelo, p.origen, p.fecha_objetivo,
       p.h, p.pred_media, p.inferior80, p.superior80,
       p.inferior95, p.superior95,
       a.remision_litros AS observado,
       a.remision_litros - p.pred_media AS error
FROM forecast_pronosticos p
LEFT JOIN analitica_remision_mensual a ON a.fecha = p.fecha_objetivo;
```

El error es observado menos media pronosticada: positivo significa subpredicción. Se conservan origen, horizonte y ejecución para no mezclar emisiones diferentes. Se guarda el resultado completo de cada comprobación en su carpeta, sin modificar la predicción original. `n_errores_disponibles` cuenta filas con observado, no todas las filas: con una emisión pendiente habrá 24 filas en el seguimiento de ambos modelos, doce en el reporte SARIMA y cero errores evaluables.

Se utiliza el observado vigente al ejecutar; no necesariamente la primera publicación del mes. Si hay una revisión, una consulta posterior puede devolver otro error para la misma predicción. La fuente y el corte de la comprobación quedan archivados.

Esta unidad guarda los errores disponibles, pero no vuelve a realizar el backtesting del 07 ni añade tests de precisión. El resumen acumulado de MAE/RMSE operativos se incorporará con un criterio de lectura por horizonte y cantidad de errores, cuando haya observaciones suficientes. La prioridad continúa siendo generar cada trayectoria completa de doce meses.

## 14. Pruebas realizadas y límites de la comprobación

Se obtuvieron del repositorio publicado el Excel original del 29 de octubre, el cierre real del 06 y el SQL analítico. Se usaron además los archivos reales de la corrida del 07 aportados por Daniel. Las pruebas se hicieron en una **base temporal separada**, con R 4.3.3, DBI 1.2.2, RSQLite 2.3.4, readxl 1.4.3 y forecast 8.21.1. No se escribió en la base de Windows.

| Prueba | Resultado comprobado |
|---|---|
| Lectura del Excel real y carga de la emisión inicial | Se reprodujeron los 297 meses y el registro de 1 ejecución/24 pronósticos. |
| Dos ciclos con la misma información | Reconocieron la emisión inicial; sin reestimación, cambios analíticos ni duplicados. |
| Un mes adicional ficticio en la base temporal | Ajustó con 298 meses, emitió doce meses desde el nuevo origen y pasó a 2 ejecuciones/48 pronósticos. |
| Repetición de ese mes adicional | Conservó 2/48, sin reestimar. |
| Revisión ficticia de un mes histórico | Conservó la arquitectura, reestimó y añadió otra emisión desde el mismo último mes. |
| Cambio únicamente en composición | Actualizó los observados correspondientes sin otra emisión de litros. |
| Fallo forzado al insertar pronósticos | Revirtió conjuntamente staging, tabla analítica y nueva ejecución/pronósticos. |
| Fuente sin el primer mes requerido | Rechazo visible, sin actualizar la base. |
| Conservación de la emisión original del 07 | Sus 24 filas permanecieron iguales después de todas las pruebas. |
| `source()` completo con descarga HTML/Excel controlada | Funcionó usando un servidor HTTP local de prueba y reconoció la emisión existente. |
| Núcleo predictivo frente al 07 | Sus catorce funciones coinciden en cálculo; solo cambia el prefijo. |
| Reporte inicial de doce filas | Doce SARIMA y doce de referencia, reales y diferencias ausentes, estados pendientes y cifras originales conservadas. |
| Llegada de un observado ficticio | Completa el real y la diferencia en la emisión anterior sin cambiar su pronóstico; la nueva emisión mantiene sus propios doce meses futuros. |
| Revisión de ese observado ficticio | Actualiza su diferencia y conserva idéntico el pronóstico de origen. |
| Integridad del reporte inicial | HTML con doce filas por tabla, fechas y cifras verificadas, sin dependencias externas; CSV con ausentes vacíos. |

Los meses/revisiones ficticios fueron exclusivamente insumos de prueba en un directorio temporal y no se entregan como datos reales. El ensayo HTTP utilizó una copia de prueba con la URL cambiada a un servidor local; no demuestra por sí solo disponibilidad del servidor público de INALE.

Posteriormente, Daniel ejecutó en su proyecto Windows:

```r
source("C:/Users/dani-/repos/forecasting-remision-leche-uy/R/10_actualizar_pronosticos.R")
```

La ejecución comprobó la fuente pública y finalizó correctamente con los siguientes resultados:

| Control local | Resultado aportado |
|---|---|
| Período y observaciones | Enero de 2002 a septiembre de 2026; 297 meses |
| Meses nuevos / revisiones de litros | 0 / 0 |
| Emisión reconocida | `20261031_171120_23228` |
| Nueva estimación | No |
| Actualización de tablas de datos | `FALSE` |
| Ejecuciones / pronósticos | 1 / 24 |
| Errores disponibles | 0, porque todavía no hay observados de las fechas objetivo emitidas |
| Carpeta de control | `outputs/operacion_mensual/op10_20261031_192032004458Z_23228/` |

Queda así comprobada en Windows la conexión real y la rama de datos sin cambios. La rama con un nuevo mes, las revisiones y la reversión ante error están comprobadas en la base temporal descrita arriba; no se afirma que haya llegado un mes nuevo real al proyecto local.

Esa salida local corresponde a la versión inicial del 10, que aún no incluía el reporte visible completo. La mejora de reportes se probó después en una base temporal con los archivos reales de la emisión, junto con observados ficticios para comprobar su actualización. Se verificó que los registros originales de pronósticos y su CSV archivado no cambiaran.

Daniel ejecutó después la versión con el reporte completo mediante el mismo `source()`. La salida mostró las doce fechas objetivo de octubre de 2026 a septiembre de 2027, sus pronósticos originales, reales y diferencias `NA` y estado `Pendiente`. Conservó 297 meses, cero meses nuevos/revisiones, ninguna reestimación, actualización analítica `FALSE` y totales 1/24. Informó las rutas de `outputs/reportes/pronostico_actual.html` y `outputs/reportes/index.html`.

La carpeta de control de esa segunda versión es:

```text
outputs/operacion_mensual/op10_20261031_195334646465Z_23228/
```

**Está comprobada la ejecución local de la versión con el reporte completo y su salida en consola.** Su publicación Git continúa pendiente. No se declara implementado GitHub Actions ni una revisión automática de especificación.

## 15. Qué continúa después

El siguiente paso es seguir [el registro Git del ciclo local](../git/07_actualizacion_local_sincronizacion.md), ya actualizado con ambas carpetas de control y `outputs/reportes/`, y publicar la unidad completa tras revisar los archivos preparados. No se reestima ni se repite el ciclo para cerrar la documentación. Después se resolverá la continuidad de SQLite y artefactos para configurar y comprobar GitHub Actions.

El ciclo mensual no repite el desarrollo del 06. Una revisión periódica de especificación y una revisión extraordinaria ante deterioro persistente se tratarán como decisiones separadas; esta unidad no impone un plazo como recomendación universal de la literatura.

Para completar la automatización remota habrá que definir dónde se conservan SQLite y los artefactos necesarios entre ejecutores temporales, configurar el workflow y comprobar una ejecución real. La base local excluida de Git no aparecerá automáticamente en un runner. No se añade infraestructura de pago ni se da por resuelto ese punto al programar una descarga.

## 16. Referencias dentro del proyecto

- [Evaluación y lógica predictiva del 07](07_evaluacion_pronosticos_sarima.md).
- [Esquema SQLite, preparación 08 y registro 09](../sql/02_persistencia_pronosticos.md).
- [Registro Git del cierre de persistencia](../git/06_persistencia_pronosticos_sincronizacion.md).
- [Registro Git del ciclo local del 10](../git/07_actualizacion_local_sincronizacion.md).
- [Estado general del proyecto](../ESTADO_DEL_PROYECTO.md).

El fundamento estadístico sigue siendo el ya aplicado y documentado en el 07: taller 05B, capítulo de función de forecasting y capítulo transversal de evaluación. Las decisiones nuevas de este módulo son de actualización, integridad de datos y conservación de emisiones.
