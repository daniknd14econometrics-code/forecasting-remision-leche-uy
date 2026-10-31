# Cierre local de persistencia y sincronización con GitHub

Fecha: 31 de octubre de 2026.

## 1. Objetivo y alcance

Registrar la preparación de las tablas de pronósticos, la carga de la corrida revisada del 07 y su repetición sin duplicados. Publicar los scripts, SQL y documentación como una unidad estable antes de continuar con la actualización mensual.

Este documento diferencia lo ejecutado de lo preparado. Las ejecuciones locales de R descritas en la sección 2 están comprobadas por las salidas aportadas por Daniel. Los comandos Git de las secciones siguientes están preparados; su commit, push y sincronización todavía no se afirman realizados.

El último cierre Git confirmado fue `dfbbd31` (`Update forecasting project status and correct README`): push correcto, árbol limpio y `0 0` entre `HEAD` y `origin/main` tras `git fetch origin`. Esa comprobación corresponde al cierre anterior; no describe automáticamente el estado actual después de añadir 08/09.

## 2. Ejecuciones locales comprobadas en RStudio

### Preparación de tablas

Desde la raíz del proyecto:

```r
source("R/08_preparar_persistencia_sqlite.R", encoding = "UTF-8")
```

Resultado aportado: tablas `forecast_ejecuciones` y `forecast_pronosticos` creadas y comprobadas, inicialmente con cero filas. Se conservaron 297 meses de datos observados, de enero de 2002 a septiembre de 2026, cuya suma es 44.046.232.078 litros.

### Primera carga de la corrida revisada

Daniel ejecutó:

```r
source("C:/Users/dani-/repos/forecasting-remision-leche-uy/R/09_registrar_pronosticos_sqlite.R")
```

La salida indicó `Registrada correctamente` para `20261031_171120_23228` y estos resultados:

| Control | Resultado |
|---|---|
| Ejecuciones registradas | 1 |
| Pronósticos registrados | 24 |
| SARIMA | 12 filas, horizontes 1 a 12 |
| Naïve estacional | 12 filas, horizontes 1 a 12 |
| Origen de los pronósticos | Septiembre de 2026 |
| Fechas objetivo | Octubre de 2026 a septiembre de 2027 |
| Datos de entrenamiento | 297 meses, enero de 2002 a septiembre de 2026 |
| Observados conservados | Mismo conteo, período y suma de litros |

La carga utilizó los archivos CSV/RDS que ya produjo el 07. No reestimó modelos ni ejecutó 06/07. Tampoco cargó las predicciones históricas del backtesting en estas tablas.

### Repetición de la carga

Daniel ejecutó después, desde la raíz:

```r
source("R/09_registrar_pronosticos_sqlite.R", encoding = "UTF-8")
```

La salida indicó `Ya registrada; sin cambios ni duplicados`. Los totales permanecieron en una ejecución y 24 pronósticos. Se conservaron las fechas y los 297 meses observados con su suma original.

Con esas dos salidas queda comprobada la carga inicial y su repetición. Las pruebas adicionales de reversión ante error y rechazo de fuentes inconsistentes se hicieron en una base temporal; se explican en [la documentación SQL](../sql/02_persistencia_pronosticos.md). No se confunden con acciones ejecutadas en la base de Windows.

## 3. Archivos de esta unidad

Guardar los archivos entregados en estas rutas del repositorio:

```text
R/08_preparar_persistencia_sqlite.R
R/09_registrar_pronosticos_sqlite.R
sql/02_crear_tablas_pronosticos.sql
docs/sql/02_persistencia_pronosticos.md
docs/git/06_persistencia_pronosticos_sincronizacion.md
README.md
docs/ESTADO_DEL_PROYECTO.md
```

Los tres primeros implementan la persistencia; el documento SQL explica íntegramente ambos scripts. Este registro conserva comandos y evidencias. README y estado reflejan la carga completada y lo que continúa pendiente. No se modifican 06, 07, los resultados publicados ni la especificación del SARIMA para cerrar esta unidad.

La base `database/forecasting.sqlite` contiene la carga local y sigue excluida de Git. No se modifica `.gitignore` para publicarla y no se usa `git add -f`. Los artefactos originales del 07 ya publicados permiten reconstruir el registro inicial. La persistencia entre ejecuciones de GitHub Actions todavía deberá resolverse explícitamente.

## 4. Primer punto de control: revisar antes de preparar el commit

Abrir **Símbolo del sistema de Windows (CMD)** y ejecutar:

```bat
cd /d C:\Users\dani-\repos\forecasting-remision-leche-uy
git status --short --branch
git --no-pager diff --stat
git check-ignore -- database/forecasting.sqlite
git fetch origin
git rev-list --left-right --count HEAD...origin/main
```

| Comando | Qué permite comprobar |
|---|---|
| `cd /d ...` | Sitúa la terminal en el repositorio, incluso si debe cambiar de unidad de disco. |
| `git status --short --branch` | Muestra rama, cambios ya seguidos y archivos nuevos. |
| `git --no-pager diff --stat` | Resume cambios en archivos ya seguidos que todavía no están preparados; no incluye archivos nuevos sin seguimiento. |
| `git check-ignore -- ...` | Debe mostrar la ruta de la base, confirmando que está ignorada. |
| `git fetch origin` | Actualiza la referencia remota local sin fusionar ni cambiar los archivos de trabajo. |
| `git rev-list --left-right --count ...` | Compara commits: el primer número cuenta los exclusivos locales; el segundo, los exclusivos remotos. |

Se esperan los siete archivos de la sección 3 como nuevos o modificados, sin la base entre los archivos por preparar. Si no se hicieron otros commits, la comparación debe dar `0 0`: los cambios de archivos aún no confirmados no incrementan esa cuenta.

**Punto de control:** comunicar estas salidas antes de seguir. Si aparecen cambios adicionales o commits remotos nuevos, se revisan; no se incluyen, descartan ni fusionan automáticamente.

## 5. Preparar solo los siete archivos revisados

Estos comandos corresponden al siguiente paso, después de revisar el estado anterior:

```bat
git add -- R/08_preparar_persistencia_sqlite.R R/09_registrar_pronosticos_sqlite.R sql/02_crear_tablas_pronosticos.sql docs/sql/02_persistencia_pronosticos.md docs/git/06_persistencia_pronosticos_sincronizacion.md README.md docs/ESTADO_DEL_PROYECTO.md
git --no-pager diff --cached --stat
git --no-pager diff --cached --name-only
git diff --cached --check
```

`git add --` prepara las rutas explícitas. No se utiliza `git add .`, que podría incluir cambios ajenos a esta unidad. El comando tampoco elimina archivos que ya estuvieran preparados; por eso se revisa después la lista completa.

`--cached` muestra lo que entraría en el commit. Deben aparecer únicamente los siete archivos acordados. `--check` detecta problemas de espacios o marcadores de conflicto; no sustituye las pruebas funcionales de R y no debe ignorarse si informa problemas.

Los avisos LF/CRLF indican la política de saltos de línea de Git en Windows. No se cambia la configuración global ni se normaliza todo el repositorio para esta publicación. Se revisan los archivos preparados si el resumen difiere de lo previsto.

**Punto de control:** revisar el resumen antes de confirmar. No se prepara la base ni se añade una ejecución de estimación nueva.

## 6. Confirmar, enviar y comprobar

Después de aprobar el contenido preparado:

```bat
git commit -m "Add SQLite forecast persistence and verified initial registration"
git push origin main
git fetch origin
git status --short --branch
git rev-list --left-right --count HEAD...origin/main
git log -1 --oneline
```

`commit` crea una versión local de los archivos preparados. `push` envía ese commit al remoto. El `fetch` posterior permite comprobar contra la referencia remota actualizada.

El cierre se considera publicado cuando el push termina correctamente, `status` no muestra archivos pendientes de esta unidad y la comparación devuelve `0 0`. `git log -1` aporta el identificador real del commit; no se inventa uno por adelantado. Si hay cambios ajenos deliberadamente pendientes, deben quedar descritos y no se afirmará que el árbol está limpio.

Si `push` falla, el commit puede existir solo localmente: no se declara sincronización. No se usa `--force` como solución automática.

Este documento puede entrar en el mismo commit como registro del procedimiento y de las pruebas locales ya ejecutadas. No hace falta un segundo commit únicamente para insertar el hash del primero dentro de su propio documento. El hash y el envío se comprueban con la salida de terminal.

## 7. Estado al preparar este cierre

| Aspecto | Estado |
|---|---|
| SQL y scripts 08/09 | Escritos y explicados. |
| Preparación de tablas | Ejecutada y comprobada localmente. |
| Carga inicial de la corrida del 07 | Ejecutada y comprobada localmente. |
| Repetición sin duplicados | Ejecutada y comprobada localmente. |
| Datos observados y predicciones originales | Conservados en los controles realizados. |
| Documentación del cierre | Actualizada con las salidas aportadas. |
| Preparación, commit y push de esta unidad | Pendientes de ejecución y evidencia local. |
| Actualización mensual integrada y GitHub Actions | Pendientes; no se declaran implementados por tener estas tablas. |

## 8. Siguiente unidad después de sincronizar

Integrar el ciclo local que actualiza los datos y produce otra trayectoria completa desde el último mes disponible. La regla acordada es usar toda la historia desde enero de 2002, reestimar coeficientes del SARIMA seleccionado y generar los siguientes doce meses, conservando la referencia y cada emisión anterior.

No se repetirá mensualmente toda la selección del script 06 ni el backtesting histórico completo del 07. Se deberá comprobar qué ocurre cuando no hay datos nuevos, cuando llega un nuevo mes y cuando la fuente revisa observaciones. El seguimiento de errores se incorporará sin sustituir las predicciones pasadas. La ejecución programada remota será posterior al funcionamiento local comprobado.
