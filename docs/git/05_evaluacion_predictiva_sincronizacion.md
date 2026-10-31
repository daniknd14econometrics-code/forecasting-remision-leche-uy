# Cierre predictivo del script 07 y sincronización con GitHub

Fecha de preparación: 31 de octubre de 2026.

## 1. Objetivo y estado del registro

Registrar la ejecución y revisión del script 07 y guiar su publicación desde el repositorio local de Windows. Este documento continúa [el cierre de modelado](04_cierre_sarima_sincronizacion.md). El documento anterior se conserva como registro de su propia unidad; no se reemplaza por este.

**Comprobado:** ejecución del 07 y revisión de su salida, tablas y gráficos. **Pendiente de evidencia local:** comandos Git de esta unidad, nuevo commit, envío y comprobación final de sincronización. Los comandos siguientes están preparados para ejecutarlos; no se presentan como un historial ya ejecutado.

| Componente | Situación al preparar este documento |
|---|---|
| Selección del script 06 | Cerrada; no se modifica |
| Script 07 | Ejecutado por Daniel en RStudio |
| Evaluación histórica | 166 orígenes mensuales y horizontes 1–12, ambos modelos |
| Pronóstico futuro | Octubre de 2026–septiembre de 2027, origen septiembre de 2026 |
| Documentación estadística | Markdown del 07 actualizado con resultados y decisiones |
| Dependencias actuales | Versiones registradas en la salida; volver a consultar `renv::status()` antes de publicar |
| Commit/push de esta unidad | Todavía sin confirmación |
| Sincronización final | Todavía sin confirmación |

## 2. Qué se ejecutó y comprobó

En RStudio se ejecutó:

```r
source("C:/Users/dani-/repos/forecasting-remision-leche-uy/R/07_evaluar_pronosticar_sarima.R")
```

La ejecución utilizó datos desde enero de 2002 hasta septiembre de 2026, con 297 observaciones mensuales. Procesó todos los orígenes entre diciembre de 2011 y septiembre de 2025: 166 orígenes × 12 horizontes × 2 modelos = 3.984 pronósticos históricos, sin claves duplicadas. Se revisó también la coherencia entre los errores guardados y las métricas.

La comparación incluye exclusivamente el SARIMA seleccionado y el naïve estacional sobre remisión diaria promedio. El SARIMA presenta menor MAE y RMSE a 1–3 meses; el naïve, a 4–12 meses. Los resultados se conservan por horizonte y mes objetivo. Se mantiene la interpretación de evaluación retrospectiva condicionada a la especificación elegida.

Se guardaron pronósticos futuros e intervalos y se revisaron diagnósticos y avisos de estimación. La lectura estadística completa pertenece a [la documentación del script 07](../R/07_evaluacion_pronosticos_sarima.md), sección 13.

Carpeta de resultados de esta ejecución:

```text
outputs/evaluacion_predictiva/07_sarima_vs_naive/20261031_171120_23228/
```

No hace falta volver a ejecutar el 06 o el 07 para publicar los resultados que ya se revisaron. Tampoco corresponde volver a mover los resultados anteriores archivados en la unidad previa.

## 3. Archivos que integran esta unidad

Guardar los documentos entregados en sus rutas definitivas:

```text
R/07_evaluar_pronosticar_sarima.R
docs/R/07_evaluacion_pronosticos_sarima.md
docs/git/05_evaluacion_predictiva_sincronizacion.md
outputs/evaluacion_predictiva/07_sarima_vs_naive/20261031_171120_23228/
```

El script 07 ya está en la computadora y se ejecutó; no se entrega otra versión de código para este cierre. El Markdown de `docs/R` sustituye su versión anterior y agrega los resultados. El documento de `docs/git` es una unidad nueva.

Se publican tablas, gráficos, objetos de resultados y metadatos de esta corrida, elaborados a partir de información pública del INALE. No se agrega el ZIP adjunto al chat ni la base SQLite generada localmente. La configuración actual de `.gitignore` excluye `database/*.sqlite` y sus archivos auxiliares.

Se utiliza la ruta exacta de la corrida revisada para no incluir por accidente otras ejecuciones todavía no examinadas. Las corridas futuras deberán identificarse con sus propias carpetas; no reemplazar los pronósticos históricos publicados.

## 4. Verificar el entorno reproducible — en RStudio

```r
renv::status()
```

Si devuelve `No issues found`, no se necesita actualizar el lockfile por rutina.

Si informa dependencias utilizadas y no registradas, revisar la lista y, cuando corresponda:

```r
renv::snapshot()
renv::status()
```

No ejecutar `renv::restore()` para descartar sin revisión el entorno que acaba de producir los resultados. Si cambia justificadamente `renv.lock`, incluirlo en esta publicación de forma explícita.

## 5. Revisar la carpeta local y la relación con GitHub — en CMD

Abrir CMD de Windows. No copiar estos comandos en la consola de R.

```bat
cd /d C:\Users\dani-\repos\forecasting-remision-leche-uy
git status --short --branch
git diff --stat
git fetch origin
git rev-list --left-right --count HEAD...origin/main
```

| Comando | Qué permite comprobar |
|---|---|
| `cd /d` | Cambia de unidad y directorio al repositorio de Windows |
| `git status --short --branch` | Rama, archivos modificados, nuevos y preparados |
| `git diff --stat` | Resumen de cambios no preparados en archivos ya seguidos |
| `git fetch origin` | Actualiza la referencia local del estado de GitHub |
| `git rev-list --left-right --count HEAD...origin/main` | Commits exclusivos de cada lado |

Los archivos nuevos pueden aparecer como `??` en `status` y no aparecer en `git diff --stat`. Esa diferencia es normal.

Antes de crear el nuevo commit, `0 0` indica historiales alineados, aunque haya cambios de trabajo pendientes. Si aparece otro resultado, comprobar su causa antes del envío: no utilizar `push --force`, `reset` o restauraciones por rutina.

**Punto de control:** revisar esta salida con Daniel antes de preparar o publicar cambios ajenos a la unidad. Si aparecen README, estado del proyecto u otros archivos pendientes de la unidad documental anterior, identificar primero si corresponde incorporarlos; no agregarlos indiscriminadamente.

## 6. Preparar el conjunto revisado

Una vez comprobado el paso anterior, en el mismo CMD:

```bat
git add -- R/07_evaluar_pronosticar_sarima.R docs/R/07_evaluacion_pronosticos_sarima.md docs/git/05_evaluacion_predictiva_sincronizacion.md outputs/evaluacion_predictiva/07_sarima_vs_naive/20261031_171120_23228
git diff --cached --name-status
git diff --cached --stat
```

`git add` prepara los archivos concretos para el próximo commit; no los envía a GitHub. Se usa una lista explícita para controlar el alcance.

`--cached` revisa el área preparada. El primer resumen identifica rutas y tipos de cambio; el segundo muestra su tamaño. Los CSV, PNG y RDS pertenecen a la corrida revisada. Los archivos binarios se identifican como tales; no se espera que Git muestre sus diferencias línea a línea.

Si se actualizó el lockfile en el paso 4, antes de repetir la revisión del área preparada:

```bat
git add -- renv.lock
```

Si hay archivos preparados de otra tarea, no se incluyen automáticamente en el commit por haber usado una lista explícita: Git incorpora **todo lo que ya esté preparado**. Por eso importa revisar `git diff --cached --name-status` antes del siguiente paso.

## 7. Registrar y enviar

Cuando el área preparada contenga el conjunto comprobado:

```bat
git commit -m "Close SARIMA historical evaluation and monthly forecasts"
git push origin main
```

`commit` registra el contenido preparado en el historial local. `push` publica los commits de `main` en el remoto `origin`.

Si el commit informa `nothing to commit`, comprobar si ya se había registrado ese trabajo. Si el envío se rechaza por cambios remotos, detenerse y leer el estado antes de elegir cómo integrarlos. No forzar el envío.

El identificador del commit y la salida de `push` serán evidencia del cierre de esta unidad. No se inventa ahora un hash ni se atribuye el 07 al commit anterior `d6af68f`, que corresponde al modelado.

## 8. Comprobar el cierre

Después de un envío satisfactorio:

```bat
git fetch origin
git status --short --branch
git rev-list --left-right --count HEAD...origin/main
git log -1 --format=fuller
```

La comprobación esperada es:

```text
## main...origin/main
0       0
```

La ausencia de filas de archivos indica un árbol de trabajo limpio para los archivos que Git sigue o detecta. `0 0`, después de consultar el remoto, indica que `HEAD` y `origin/main` no tienen commits exclusivos de ninguno de los dos lados. El último comando identifica el commit recién publicado y sus metadatos.

La sincronización se refiere al contenido versionado. No significa que GitHub contenga la base SQLite ignorada o la carpeta externa de resultados anteriores. Si quedan otros cambios locales, enumerarlos y tratarlos explícitamente; no describir el árbol como limpio.

## 9. Qué se cierra y qué sigue abierto

La ejecución estadística del 07 y su revisión están completadas. La publicación de esta unidad quedará comprobada cuando Daniel aporte la salida del paso 8. Esta condición pertenece al registro de ejecución, no requiere volver a estimar modelos.

Queda registrada la posibilidad futura de ARIMAX con precio de la leche y precipitaciones. No se presupone ganancia predictiva ni se incorpora esa extensión en este commit. La decisión de realizarla aquí o en otro proyecto permanece abierta.

Después de comprobar la publicación se revisará el estado global y se actualizarán README y `docs/ESTADO_DEL_PROYECTO.md` para reflejar el avance real. El seguimiento de nuevas observaciones, la persistencia operativa de predicciones, un punto de entrada del flujo completo y GitHub Actions requieren un balance concreto; no se dan por terminados al publicar este análisis.

## 10. Criterio de registro y referencias

Este documento conserva completos los comandos previstos, su propósito y las verificaciones. Al momento de entregarlo, las secciones 4–8 son instrucciones de ejecución, no una certificación de que ya se realizaron. La evidencia posterior de consola permitirá confirmar lo efectivamente ejecutado y decidir si hace falta una anotación documental adicional; no se crea un ciclo de commits solo para agregar el hash del propio documento.

- [Flujo general de Git](00_flujo_general_git.md).
- [Cierre anterior de modelado](04_cierre_sarima_sincronizacion.md).
- [Script 07 y resultados](../R/07_evaluacion_pronosticos_sarima.md).
- [Git: status](https://git-scm.com/docs/git-status).
- [Git: diff](https://git-scm.com/docs/git-diff).
- [Git: add](https://git-scm.com/docs/git-add).
- [Git: commit](https://git-scm.com/docs/git-commit).
- [Git: push](https://git-scm.com/docs/git-push).
- [Git: fetch](https://git-scm.com/docs/git-fetch).
- [Git: rev-list](https://git-scm.com/docs/git-rev-list).
