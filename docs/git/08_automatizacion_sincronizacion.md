# Git 08 — Preparación y sincronización de la automatización mensual

Fecha de preparación: 31 de octubre de 2026. Actualización de evidencia: 1 de noviembre de 2026.

## 1. Punto de partida confirmado

El último cierre publicado antes de esta etapa es:

```text
f667dfc Add local forecast cycle and twelve-month tracking reports
```

Después se archivaron fuera del repositorio dos carpetas anteriores de controles y se restauraron dos líneas vacías añadidas al script 08. El usuario confirmó que terminó esa limpieza. No se genera un commit para esos espacios.

Esta unidad incorpora la configuración de GitHub Actions y su documentación. No cambia el modelo ni sustituye los scripts existentes del 06 al 10.

## 2. Archivos nuevos esperados en main

```text
.github/workflows/actualizar_pronosticos.yml
R/11_operacion_github_actions.R
docs/R/11_operacion_github_actions.md
docs/github_actions/01_actualizacion_mensual.md
docs/git/08_automatizacion_sincronizacion.md
```

El ZIP de entrega se extrae directamente en la raíz. No guardar el ZIP dentro del repositorio. Su contenido respeta las rutas anteriores, incluida la carpeta `.github`.

El número 11 del documento de R corresponde al script 11. La numeración 01 de la nueva carpeta de GitHub Actions comienza la documentación de esa herramienta; la numeración 08 continúa la documentación de Git.

## 3. Revisión local antes de preparar el commit

Ejecutar en la terminal de Windows, desde la raíz del proyecto:

```bat
cd /d C:\Users\dani-\repos\forecasting-remision-leche-uy
git status --short --branch
git --no-pager diff --stat
git fetch origin
git rev-list --left-right --count HEAD...origin/main
```

Se esperan solo los cinco archivos nuevos anteriores, aunque Git puede resumir carpetas sin seguimiento. `git diff --stat` no incluye todavía los archivos nuevos. El último comando debería mostrar `0 0` si no hubo otra modificación de main.

Punto de control: si aparecen archivos ajenos a esta etapa o commits divergentes, revisar antes de añadirlos.

## 4. Preparar únicamente esta unidad

```bat
git add -- .github/workflows/actualizar_pronosticos.yml R/11_operacion_github_actions.R docs/R/11_operacion_github_actions.md docs/github_actions/01_actualizacion_mensual.md docs/git/08_automatizacion_sincronizacion.md
git --no-pager diff --cached --stat
git --no-pager diff --cached --name-only
git diff --cached --check
```

Se esperan cinco archivos y ningún SQLite, Excel nuevo, archivo simulado ni carpeta de prueba. Estos documentos y código no requieren volver a ejecutar 06, 07 o 10 en RStudio.

Las advertencias LF/CRLF al añadir texto se distinguen de errores de código. El estado operativo utilizará sus reglas de conservación exacta de bytes en otra rama, preparadas por el 11.

Punto de control: comunicar el resumen de archivos preparados antes de hacer el commit cuando se trabaja de forma guiada.

## 5. Commit y publicación, tras revisar el punto anterior

```bat
git commit -m "Add monthly GitHub Actions automation and persistent forecast state"
git push origin main
git fetch origin
git status --short --branch
git rev-list --left-right --count HEAD...origin/main
git log -1 --oneline
```

Daniel ejecutó estos comandos y confirmó push correcto, árbol limpio y `0 0`. El commit resultante fue `a3c6a4c`. La corrección posterior del workflow se publicó en `bb559f0`, también con sincronización comprobada.

El workflow no se dispara por este push. Se habilita Pages y se hace el primer arranque manual siguiendo la guía de Actions. Si llega el calendario antes de inicializar, el workflow se detendrá sin crear un historial nuevo por su cuenta.

## 6. Configuración y primera ejecución en GitHub

Seguir `docs/github_actions/01_actualizacion_mensual.md`:

1. En este repositorio, **Settings → Pages → Build and deployment → Source: GitHub Actions**.
2. En **Actions**, abrir **Actualizar pronosticos mensuales**.
3. Ejecutar desde **main**, marcando inicialización únicamente la primera vez.
4. Comprobar los dos trabajos: `actualizar` y `publicar`.
5. Abrir el enlace real de Pages y comprobar reporte vigente, historial y métricas.
6. Hacer una segunda ejecución manual sin marcar inicialización para comprobar que recupera el estado y no duplica emisiones si los datos no cambiaron.

La configuración de Pages y las dos ejecuciones manuales ya se comprobaron. El apartado 8 registra los identificadores y resultados. Las instrucciones anteriores quedan como referencia: para consultas posteriores, dejar desmarcada la inicialización.

## 7. Qué cambia en el flujo de Git después de activar Actions

El usuario continúa trabajando normalmente en `main`. El workflow confirma sus resultados en `operacion`, una rama distinta. Una consulta mensual puede agregar un commit allí sin agregar commits a `main`.

Por eso `HEAD...origin/main` puede seguir mostrando `0 0` aunque haya reportes nuevos en `operacion`. El informe público de Pages refleja la rama operativa; los archivos de ejemplo históricos ya guardados en main no se reemplazan por cada consulta.

No hacer merge automático de `operacion` en `main` ni usar `git add -f` sobre la base local. La rama operativa contiene un estado completo que debe tratarse como una unidad.

Para observar referencias remotas actualizadas:

```bat
git fetch origin
git branch --remotes
```

Se espera ver `origin/operacion` después del primer push correcto del workflow. No hace falta cambiar de rama local para abrir el reporte web.

## 8. Registro verificable de esta etapa

Verificación del 1 de noviembre de 2026, con código `bb559f0`:

| Ejecución de Actions | Resultado | Evidencia |
|---|---|---|
| [41257750531](https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy/actions/runs/41257750531) | Cancelada a los 45 minutos | Bloqueo en `apt-get update`, durante la preparación de R; no ejecutó el ciclo R ni escribió estado remoto. |
| [41262543730](https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy/actions/runs/41262543730) | `actualizar` y `publicar` correctos | Inicialización explícita desde los archivos publicados; 297 meses, una emisión y 24 pronósticos; sin novedades de INALE. |
| [41262927931](https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy/actions/runs/41262927931) | `actualizar` y `publicar` correctos | `FORECAST_INICIALIZAR=false`; recuperó `operacion`, conservó la misma emisión y 24 pronósticos, sin reestimar ni duplicar. |

La primera ejecución correcta guardó `operacion` en `a4327b1`; la segunda avanzó a `6ea765f`. Su control quedó en `ultima_comprobacion.csv`, a las 01:54:38 UTC del 1 de noviembre de 2026 (02:54:38 en Madrid): origen septiembre de 2026, 297 meses, emisión `20261031_171120_23228`, cero meses nuevos, cero revisiones y cero errores evaluables. Son consultas reales a INALE; no se añadieron meses simulados al estado publicado.

Daniel abrió el reporte público, el historial y las métricas y aportó capturas. Los reales y las diferencias continúan pendientes porque no se dispone de observados para octubre de 2026 en adelante. MAE y RMSE pendientes no equivalen a errores cero.

El calendario mensual está configurado para el día 1 a las 09:17, zona `Europe/Madrid`. Estas comprobaciones fueron manuales: el primer disparo programado y la primera actualización con nuevos datos reales permanecen pendientes de observación.

### Corrección del bloqueo y publicación

El archivo `actualizar_pronosticos.yml` se reemplazó por la versión completa corregida. Daniel inspeccionó el diff: 14 líneas añadidas; `git diff --check` solo mostró el aviso de conversión LF/CRLF, sin defectos de espacios.

```bat
git add -- .github/workflows/actualizar_pronosticos.yml
git commit -m "Fix Ubuntu package download stall in forecast workflow"
git push origin main
git fetch origin
git status --short --branch
git rev-list --left-right --count HEAD...origin/main
git log -1 --oneline
```

Resultado aportado por Daniel: `bb559f0`, un archivo cambiado y 14 inserciones; push correcto, `## main...origin/main` sin cambios y `0 0`. Después inició un nuevo `Run workflow` desde `main`, con inicialización marcada porque la ejecución fallida no había creado el estado remoto. La segunda prueba correcta se inició después con la casilla desmarcada.

### Cierre documental preparado

Esta entrega actualiza exclusivamente cinco documentos: README, estado, guía de R 11, guía Actions 01 y este registro Git 08. No incluye scripts R, SQLite, salidas nuevas ni el workflow ya publicado.

Tras reemplazarlos en la raíz, revisar en CMD:

```bat
git status --short --branch
git --no-pager diff --stat
git diff --check
```

Se esperan esos cinco documentos modificados. El commit y push de este cierre documental todavía no se han ejecutado; se harán después de revisar la salida en el trabajo guiado. No hace falta repetir estimaciones ni otra consulta manual para publicar documentación.
