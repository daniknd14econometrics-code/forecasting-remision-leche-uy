# GitHub Actions 01 — Consulta mensual, persistencia y reporte público

Preparado el 31 de octubre de 2026. Estado inicial de este documento: código preparado y probado técnicamente; activación y ejecución real pendientes. No se da por concluida la automatización hasta comprobarla en GitHub.

## 1. Decisiones de esta etapa

- Consultar INALE una vez al mes, como pidió el usuario.
- Punto de partida del calendario: día 1 a las 09:17, zona `Europe/Madrid`. El minuto 17 evita concentrar la programación justo a la hora en punto. La hora es una programación solicitada, no una garantía de ejecución exacta del servicio.
- Permitir además la ejecución manual desde Actions.
- Publicar los HTML y CSV existentes mediante GitHub Pages.
- Mantener en `main` el código y la documentación, y en la rama `operacion` el estado actualizado automáticamente.
- Conservar la especificación del 06; reestimar coeficientes cuando corresponde una emisión nueva. No repetir el análisis del 06 ni el backtesting del 07.

La frecuencia mensual describe cuándo se consulta la fuente, no una fecha de publicación del INALE que hayamos verificado. Si la fuente se actualiza después del día 1, la novedad se incorporará en la siguiente consulta o al ejecutar manualmente el workflow.

## 2. Qué significa persistencia en esta implementación

El ejecutor de Actions no es la computadora del usuario y no conserva automáticamente el disco de la ejecución anterior. Por eso cada ejecución obtiene una copia de `operacion`, recupera su SQLite y sus artefactos, ejecuta el ciclo y confirma un nuevo estado en esa misma rama.

| Lugar | Qué guarda | Para qué sirve |
| --- | --- | --- |
| `main` | Código, documentación y evidencia histórica ya publicada | Reproducibilidad y desarrollo |
| `operacion/estado/` | SQLite, Excel originales y artefactos necesarios de las emisiones | Continuar el historial entre ejecuciones |
| `operacion/publico/` | Reportes HTML y CSV | Publicación en GitHub Pages |
| Artefacto temporal `github-pages` de Actions | Paquete del reporte a desplegar | Transporte al servicio Pages, no respaldo permanente de la base |
| Caché de renv | Paquetes de R | Acelerar la preparación del entorno, no guardar datos del proyecto |

`operacion/estado/` indica una carpeta dentro de la rama `operacion`; no una carpeta nueva que el usuario tenga que crear en su rama local `main`.

La base continúa ignorada por Git en el proyecto local. Se guarda expresamente en la rama operativa separada. Como el repositorio es público, los archivos de esa rama también lo son; contienen datos públicos de INALE y resultados del proyecto. SQLite no se incorpora al paquete de la página web.

El tamaño actual de este estado es pequeño. Este mecanismo está pensado para este proyecto mensual, no para un archivo industrial de bases enormes.

## 3. Workflow completo

Archivo: `.github/workflows/actualizar_pronosticos.yml`.

```yaml
name: Actualizar pronosticos mensuales

# Consulta mensual y posibilidad de ejecucion manual. No se activa por cada push.
on:
  schedule:
    - cron: '17 9 1 * *'
      timezone: Europe/Madrid
  workflow_dispatch:
    inputs:
      inicializar:
        description: 'Solo la primera vez: crear la rama operacion si aun no existe'
        type: boolean
        required: false
        default: false

# Una sola operacion a la vez, incluyendo la publicacion; no cancelar escrituras.
concurrency:
  group: forecasting-operacion-mensual
  cancel-in-progress: false

permissions:
  contents: read

jobs:
  actualizar:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-24.04
    timeout-minutes: 45
    permissions:
      contents: write
    defaults:
      run:
        shell: bash
        working-directory: codigo
    env:
      TZ: UTC
      FORECAST_ESTADO_DIR: ${{ github.workspace }}/estado
      FORECAST_INICIALIZAR: ${{ github.event_name == 'workflow_dispatch' && inputs.inicializar && 'true' || 'false' }}

    steps:
      - name: Conservar saltos de linea de los archivos originales
        working-directory: ${{ github.workspace }}
        run: git config --global core.autocrlf false

      - name: Obtener codigo de main
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          path: codigo
          persist-credentials: false

      - name: Recuperar la rama operacion o autorizar su primer arranque
        env:
          REPOSITORIO_URL: https://github.com/${{ github.repository }}.git
        run: |
          set -euo pipefail
          set +e
          git ls-remote --exit-code --heads "$REPOSITORIO_URL" refs/heads/operacion
          estado=$?
          set -e
          if [ "$estado" -eq 0 ]; then
            git clone --depth=1 --single-branch --branch operacion "$REPOSITORIO_URL" "$FORECAST_ESTADO_DIR"
          elif [ "$estado" -eq 2 ] && [ "$FORECAST_INICIALIZAR" = true ]; then
            git init --initial-branch=operacion "$FORECAST_ESTADO_DIR"
            git -C "$FORECAST_ESTADO_DIR" remote add origin "$REPOSITORIO_URL"
          else
            echo "::error::No se recupero operacion. No se reinicia el historial. Solo el primer arranque manual permite inicializar."
            exit 1
          fi

      - name: Preparar R con la version del proyecto
        uses: r-lib/actions/setup-r@f9a764fea8d5c63df6ef9a5c7795bf7deb5d7e05 # v2
        with:
          r-version: '4.6.1'
          use-public-rspm: true

      - name: Restaurar paquetes registrados en renv.lock
        uses: r-lib/actions/setup-renv@f9a764fea8d5c63df6ef9a5c7795bf7deb5d7e05 # v2
        with:
          working-directory: codigo

      - name: Ejecutar recuperacion, ciclo 10, metricas y respaldo
        run: Rscript -e 'source("R/11_operacion_github_actions.R", encoding = "UTF-8")'

      - name: Confirmar y guardar el estado antes de publicar el reporte
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          set -euo pipefail
          # El token temporal sirve solo para este repositorio y no se guarda en el estado.
          gh auth setup-git --hostname github.com
          git -C "$FORECAST_ESTADO_DIR" config user.name 'github-actions[bot]'
          git -C "$FORECAST_ESTADO_DIR" config user.email '41898282+github-actions[bot]@users.noreply.github.com'
          git -C "$FORECAST_ESTADO_DIR" add -- .gitattributes README.md formato_estado.txt modelo_cierre_md5.txt manifiesto_md5.csv ultima_comprobacion.csv estado publico
          if ! git -C "$FORECAST_ESTADO_DIR" diff --cached --quiet; then
            git -C "$FORECAST_ESTADO_DIR" commit -m "Update monthly forecast state: run $GITHUB_RUN_ID"
            git -C "$FORECAST_ESTADO_DIR" push origin HEAD:refs/heads/operacion
          fi

      - name: Preparar los HTML y CSV para GitHub Pages
        uses: actions/upload-pages-artifact@fc324d3547104276b827a68afc52ff2a11cc49c9 # v5.0.0
        with:
          path: estado/publico

  publicar:
    needs: actualizar
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.despliegue.outputs.page_url }}
    steps:
      - name: Publicar el reporte vigente y el historial
        id: despliegue
        uses: actions/deploy-pages@368f82528645a54fb793d4d04e342629a3f51346 # v5.0.1
```

## 4. Lectura del workflow, en el orden de ejecución

### Nombre y disparadores

`name` es el nombre visible en la pestaña Actions. `schedule` define la consulta mensual mediante cinco campos cron: minuto, hora, día del mes, mes y día de la semana. `timezone: Europe/Madrid` hace que el horario siga la zona elegida, incluyendo sus cambios estacionales.

`workflow_dispatch` crea el botón de ejecución manual. Su única entrada es `inicializar`, una casilla booleana que debe marcarse solo al crear el primer estado. No permite cambiar el modelo, la fuente ni sustituir datos reales por una prueba.

No hay disparador `push`: corregir un documento o subir otro archivo no debe recalcular pronósticos.

### Concurrencia y rama de ejecución

`concurrency` impide dos operaciones simultáneas del mismo workflow. `cancel-in-progress: false` evita cancelar una escritura en curso para iniciar otra ejecución. La condición del trabajo exige `main`, tanto para el disparo manual como para el programado.

La ejecución utiliza `ubuntu-24.04`. No se necesita dejar Windows encendido ni instalar un ejecutor en la computadora del usuario.

### Directorios y variables

`codigo/` contiene el checkout de `main`. `estado/` es un directorio hermano donde se obtiene la rama operativa. Los comandos R se ejecutan dentro de `codigo/`; el 11 exige que el directorio de estado esté fuera de ese checkout para evitar confusiones con la base local.

`FORECAST_INICIALIZAR` será `true` solo si la ejecución es manual y el usuario marcó la casilla. El calendario nunca habilita automáticamente el arranque desde cero.

### Preparar Git y descargar el código

`core.autocrlf=false` evita conversiones automáticas en el ejecutor Linux. Además, el estado tiene sus propias reglas `.gitattributes` para conservar archivos con huellas registradas.

La acción de checkout descarga el código. Se fija una revisión concreta de cada acción mediante su SHA y se conserva como comentario la versión consultada. Los SHA corresponden a las acciones oficiales, consultadas al preparar esta entrega. No se usa la rama principal cambiante de esas acciones como dependencia silenciosa.

### Recuperar o inicializar la rama operativa

`git ls-remote` distingue tres situaciones: encuentra `operacion` (código 0); no existe esa referencia (código 2); o aparece otro error, por ejemplo de conexión. Solo el segundo caso y con inicialización manual permiten crear la rama nueva.

Si ya existe, se clona. Si hay un error de conexión, no se interpreta como pérdida del historial y no se arranca otra base. No se utiliza `push --force`.

### Restaurar R y renv

Se prepara R 4.6.1, la versión registrada en el proyecto, y se restauran las dependencias de `codigo/renv.lock` mediante las acciones de r-lib. La caché sirve para reducir descargas posteriores; perderla no debe causar pérdida de datos.

No se modifica `renv.lock` para instalar otra versión de forecast o cambiar los resultados. La primera ejecución remota debe confirmar que las versiones registradas se restauran correctamente en Linux. Si falla una dependencia, se estudia ese error concreto.

### Ejecutar el script 11

El 11 recupera SQLite o realiza su arranque único con los archivos iniciales publicados. Luego ejecuta la función del 10, valida la conservación de las emisiones, genera las métricas y prepara el respaldo.

Si la fuente real sigue terminando en septiembre de 2026 y no revisó los litros, se espera conservar la emisión `20261031_171120_23228`: una ejecución de pronósticos y 24 filas, aunque se agregue un nuevo registro de control de consulta. Si INALE ya publicó novedades, esos conteos pueden cambiar legítimamente y se revisará el detalle del ciclo.

### Guardar el estado remoto

Solo si el script termina correctamente se prepara el commit de `operacion`. Se usa el token temporal del trabajo (`GITHUB_TOKEN`) mediante `GH_TOKEN`, sin crear un token personal, guardarlo en archivos o publicarlo en la rama.

`gh auth setup-git` configura la autenticación en el ejecutor temporal. La identidad del commit es `github-actions[bot]`. Solo se agregan las carpetas y metadatos previstos de esa rama. Se hace commit si hay cambios y se publica sin forzar la referencia.

El control y las fechas del reporte pueden cambiar aunque no haya meses nuevos. Eso justifica un commit de consulta; no equivale a una emisión adicional en SQLite.

### Publicar Pages después de guardar el estado

El paquete de Pages incluye únicamente `estado/publico`, en el directorio del ejecutor. El trabajo `publicar` depende del éxito de `actualizar` y tiene solo los permisos necesarios de Pages e identidad de despliegue.

Se confirma primero el estado y después se publica la web. Si Pages falla, el estado puede haber quedado guardado y la web seguir mostrando la versión anterior. Revisar ambos trabajos, no solo el primero.

## 5. Activación guiada

Este es el recorrido completo de referencia. Durante el trabajo con la IA se ejecuta una unidad por vez y se revisa la salida antes de continuar.

### Paso A. Publicar los archivos de configuración

Extraer el paquete de esta etapa en la raíz del proyecto. Deben aparecer cinco archivos nuevos. No se sustituyen los scripts 06 a 10 ni los documentos existentes.

Seguir `docs/git/08_automatizacion_sincronizacion.md` para revisar, hacer commit y push. En esta etapa el workflow todavía no se ejecuta por un push.

### Paso B. Habilitar Pages para este repositorio

En GitHub, abrir el repositorio `forecasting-remision-leche-uy`.

1. Entrar en **Settings**.
2. En la sección **Code and automation**, entrar en **Pages**.
3. En **Build and deployment**, elegir **GitHub Actions** en **Source**.

No crear una plantilla adicional ni cambiar el repositorio del portfolio. La publicación corresponde al proyecto actual. Si la pantalla ofrece una configuración distinta, comunicar lo que muestra antes de cambiar otras opciones.

El workflow solicita sus permisos de escritura expresamente. No es necesario crear un secreto con una contraseña ni un token personal. Si una política del repositorio impide esos permisos y aparece un 403, se revisa ese error en lugar de habilitar permisos generales innecesarios.

### Paso C. Primera ejecución manual

1. Abrir **Actions**.
2. Elegir **Actualizar pronosticos mensuales**.
3. Pulsar **Run workflow**, seleccionando la rama **main**.
4. Marcar la casilla de inicialización **solo en esta primera ejecución**.
5. Iniciar y abrir el detalle de la ejecución.

Debe terminar correctamente tanto `actualizar` como `publicar`. Revisar los pasos de restauración de paquetes, ciclo R, push de estado y despliegue. La rama `operacion` debe aparecer con SQLite, los artefactos, el manifiesto y los reportes.

No se da por verificada una ejecución mensual programada solo porque la manual funcionó. Se deja configurada y se confirma cuando ocurra su primer disparo real.

### Paso D. Verificar el reporte

La URL esperada, si no se configura un dominio personalizado, es:

- Índice: `https://daniknd14econometrics-code.github.io/forecasting-remision-leche-uy/`
- Reporte actual: `https://daniknd14econometrics-code.github.io/forecasting-remision-leche-uy/pronostico_actual.html`
- Seguimiento: `https://daniknd14econometrics-code.github.io/forecasting-remision-leche-uy/metricas_operativas.html`

La URL efectiva la muestra el trabajo de Pages y la configuración del repositorio. Comprobar que el reporte actual tenga doce filas SARIMA, que el historial se pueda abrir y que los CSV sean descargables. Al comenzar, los observados y las diferencias permanecen pendientes mientras no existan datos reales para esos meses.

### Paso E. Segunda ejecución manual

Volver a ejecutar desde `main`, ahora con la casilla de inicialización desmarcada. La salida debe indicar recuperación del estado anterior. Si los datos no cambiaron entre ambas consultas, no debe agregar otra emisión ni duplicar los 24 pronósticos.

Se verifica así la continuidad en dos ejecutores distintos de GitHub, no solo la repetición local de una función.

## 6. Operación posterior

Cada día 1 se consulta la fuente real. Si no cambió, se conserva la emisión y se actualiza el control. Si hay un nuevo mes o revisión de litros, se usa toda la historia, se reestiman los coeficientes y se guardan los próximos doce meses.

La emisión anterior permanece consultable. Sus columnas de reales, diferencias y métricas se actualizan con los observados vigentes. La emisión vigente se desplaza al nuevo origen; no reemplaza las predicciones antiguas.

Para una consulta fuera de calendario se usa **Run workflow**, sin inicializar. Si algún día se decide cambiar el día o la frecuencia, se modifica `schedule` y se documenta esa decisión. No se necesita cambiar la especificación estadística.

GitHub advierte que las ejecuciones programadas pueden retrasarse y que en repositorios públicos pueden deshabilitarse tras un período de inactividad. Revisar periódicamente la pestaña Actions; no interpretar una ausencia prolongada de ejecuciones como evidencia de que la fuente no publicó datos.

Los ejecutores estándar de Actions para repositorios públicos y Pages están disponibles sin contratar infraestructura adicional. Se evita usar el almacenamiento temporal de artefactos como archivo permanente y se mantiene pequeño el estado versionado.

## 7. Errores y recuperación

| Situación | Qué hacer |
| --- | --- |
| La rama no existe antes de la primera ejecución | Iniciar manualmente una vez con la casilla marcada |
| La rama existía y ahora falta o su manifiesto no coincide | Detenerse y recuperar el estado correcto; no inicializar de nuevo |
| INALE no responde o cambia la estructura del Excel | Revisar el paso R; el estado remoto anterior se conserva si no hubo push |
| Falla renv o la preparación de R | Revisar el error de instalación; no cambiar de modelo ni de paquetes sin justificación |
| El estado se guardó pero Pages falló | Revisar Pages y repetir; no borrar SQLite ni volver a registrar la emisión inicial |
| Se quiere continuar localmente desde el estado remoto | Recuperar el conjunto del manifiesto, no solo SQLite, en una copia preparada para ello |
| Se modificó la especificación del 06 | Preparar una migración y versión explícitas antes de continuar con ese nuevo cierre |

## 8. Evidencia al preparar esta entrega

Se verificaron el arranque R con los archivos reales iniciales, la recuperación, un mes adicional simulado en un entorno temporal, la conservación de las predicciones, las métricas exactas de ese ejemplo y el rechazo de estados incompletos. También se verificó un commit/clon Git local con conservación de huellas, la lectura del YAML y la sintaxis bash.

La prueba real de Actions, el despliegue web y el primer disparo mensual aún no se han observado. Su resultado se documentará con la evidencia del repositorio. Los datos simulados usados para las pruebas no están incluidos en esta entrega.

## 9. Fuentes oficiales consultadas

- Sintaxis de workflows, calendario y zona horaria: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
- Eventos programados y sus limitaciones: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
- Entornos de ejecución y uso en repositorios públicos: https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- Retención de artefactos y registros: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository
- GitHub CLI en workflows: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-github-cli
- Configuración de Pages: https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
- Publicación mediante workflow: https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages
- Restauración de renv: https://github.com/r-lib/actions/tree/v2/setup-renv
- Acciones oficiales fijadas: https://github.com/actions/checkout/releases/tag/v7.0.1 · https://github.com/actions/upload-pages-artifact/releases/tag/v5.0.0 · https://github.com/actions/deploy-pages/releases/tag/v5.0.1
