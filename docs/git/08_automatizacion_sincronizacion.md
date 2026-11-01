# Git 08 — Preparación y sincronización de la automatización mensual

Fecha de preparación: 31 de octubre de 2026.

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
git commit -m "Add monthly GitHub Actions workflow and persistent forecast state"
git push origin main
git fetch origin
git status --short --branch
git rev-list --left-right --count HEAD...origin/main
git log -1 --oneline
```

Verificar push correcto, árbol limpio y `0 0`. El SHA de este commit todavía no se conoce al escribir este documento; no se inventa ni se considera ejecutado.

El workflow no se dispara por este push. Se habilita Pages y se hace el primer arranque manual siguiendo la guía de Actions. Si llega el calendario antes de inicializar, el workflow se detendrá sin crear un historial nuevo por su cuenta.

## 6. Configuración y primera ejecución en GitHub

Seguir `docs/github_actions/01_actualizacion_mensual.md`:

1. En este repositorio, **Settings → Pages → Build and deployment → Source: GitHub Actions**.
2. En **Actions**, abrir **Actualizar pronosticos mensuales**.
3. Ejecutar desde **main**, marcando inicialización únicamente la primera vez.
4. Comprobar los dos trabajos: `actualizar` y `publicar`.
5. Abrir el enlace real de Pages y comprobar reporte vigente, historial y métricas.
6. Hacer una segunda ejecución manual sin marcar inicialización para comprobar que recupera el estado y no duplica emisiones si los datos no cambiaron.

Estos pasos aún no están ejecutados al preparar este documento. Su verificación se hace con las salidas del servicio, no por la mera existencia del YAML.

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

| Elemento | Estado al preparar la entrega |
| --- | --- |
| Último cierre previo de main | `f667dfc`, confirmado |
| Script 11 y workflow mensual | Preparados |
| Pruebas temporales de recuperación y mes simulado | Correctas; no publicadas como datos reales |
| Conservación de huellas al hacer commit y clonar localmente | Comprobada |
| Lectura YAML y sintaxis bash | Comprobadas |
| Commit de esta unidad en el repositorio del usuario | Pendiente |
| Primera ejecución real de Actions | Pendiente |
| Reporte accesible en Pages | Pendiente |
| Segunda ejecución real y continuidad del estado | Pendiente |
| Primer disparo mensual programado | Pendiente |

Los resultados posteriores se revisan contra esta lista. No se reescribe un commit ya publicado solo para insertar su propio SHA en su documentación.
