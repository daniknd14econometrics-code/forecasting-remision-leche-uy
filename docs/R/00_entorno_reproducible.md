# Entorno reproducible con R y renv

## Objetivo

Este documento explica cómo se configuró el entorno reproducible del proyecto de forecasting de remisión de leche en Uruguay.

Un entorno reproducible permite registrar las versiones de R y de los paquetes utilizados. De esta manera, el proyecto puede reconstruirse posteriormente en otra computadora o en GitHub Actions.

`renv` no selecciona los paquetes que debe utilizar el proyecto. Su función es registrar y reconstruir las versiones de los paquetes que se incorporen durante el desarrollo.

## 1. Comprobación de la versión de R

```r
R.version.string
R.home()
```

### Explicación general

Este bloque permite comprobar qué versión de R está ejecutando RStudio y dónde se encuentra instalada.

### Explicación línea por línea

- `R.version.string` devuelve el nombre completo y la versión de R utilizada por la sesión actual.
- `R.home()` devuelve la carpeta donde está instalada esa versión de R.

### Resultado obtenido

```text
R version 4.6.1 (2026-06-24 ucrt)
C:/PROGRA~1/R/R-46~1.1
```

`C:/PROGRA~1/R/R-46~1.1` es la representación abreviada de Windows para la carpeta `C:/Program Files/R/R-4.6.1`.

## 2. Instalación de renv

```r
install.packages("renv", repos = "https://cloud.r-project.org")

packageVersion("renv")
```

### Explicación general

Este bloque instala `renv` y comprueba qué versión fue instalada.

La instalación inicial de `renv` se realiza en la biblioteca personal correspondiente a R 4.6. Después, `renv` se utiliza para crear una biblioteca aislada para el proyecto.

### Explicación línea por línea

- `install.packages()` instala un paquete de R.
- `"renv"` indica el nombre del paquete que se desea instalar.
- `repos = "https://cloud.r-project.org"` indica explícitamente el servidor de CRAN desde el cual se descarga.
- `packageVersion("renv")` consulta la versión instalada del paquete.

### Resultado obtenido

```text
renv 1.3.1
```

Durante la instalación apareció una advertencia indicando que Rtools no estaba instalado. La advertencia no impidió la instalación porque R descargó un paquete binario ya preparado para Windows.

Rtools solo será necesario si posteriormente debemos compilar algún paquete desde su código fuente.

## 3. Inicialización de renv en el proyecto

```r
renv::init(
  project = "C:/Users/dani-/repos/forecasting-remision-leche-uy"
)
```

### Explicación general

Este bloque activa la administración reproducible de paquetes dentro del proyecto.

La inicialización crea una biblioteca privada para el proyecto y los archivos necesarios para registrar y reconstruir sus dependencias.

### Explicación línea por línea

- `renv::` indica que se utilizará una función perteneciente al paquete `renv`.
- `init()` inicializa un entorno reproducible.
- `project = ...` señala explícitamente la carpeta que debe inicializarse.
- La ruta indicada corresponde a la raíz del repositorio local.

### Archivos principales creados

- `.Rprofile`: activa automáticamente `renv` cada vez que se abre el proyecto.
- `renv.lock`: registra la versión de R y las versiones de los paquetes.
- `renv/activate.R`: contiene el mecanismo de activación de `renv`.
- `renv/settings.json`: contiene la configuración del entorno.
- `renv/.gitignore`: evita que Git guarde bibliotecas locales y archivos temporales.

La biblioteca privada contiene físicamente los paquetes del proyecto, pero no se guarda en Git. Puede reconstruirse utilizando `renv.lock`.

## 4. Comprobación del estado del entorno

```r
renv::status()
```

### Explicación general

Este comando compara el código del proyecto, la biblioteca privada y el archivo `renv.lock` para detectar diferencias.

### Explicación línea por línea

- `renv::status()` solicita a `renv` que revise la consistencia del entorno activo.

### Resultado obtenido

```text
No issues found -- the project is in a consistent state.
```

Esto indica que el entorno actual y el archivo `renv.lock` son consistentes.

No significa que ya se hayan elegido todos los paquetes del proyecto. En este momento solo se ha registrado el punto de partida, compuesto principalmente por R 4.6.1 y `renv` 1.3.1.

## 5. Incorporación futura de paquetes

Cuando se decida utilizar un paquete, se instalará mientras el proyecto esté abierto y `renv` esté activo.

```r
install.packages("nombre_del_paquete")
```

### Explicación general

Este comando instalará el paquete en la biblioteca privada del proyecto.

### Explicación línea por línea

- `install.packages()` solicita la instalación de un paquete.
- `"nombre_del_paquete"` deberá sustituirse por el nombre real del paquete acordado.

La instalación no significa que debamos registrar inmediatamente el paquete. Primero se escribirá y probará el bloque de código correspondiente.

## 6. Registro de las versiones utilizadas

Cuando un bloque de código haya sido probado correctamente, se actualizará el archivo `renv.lock`.

```r
renv::snapshot()
```

### Explicación general

Este comando registra en `renv.lock` las versiones de los paquetes utilizados por el proyecto.

### Explicación línea por línea

- `renv::snapshot()` analiza las dependencias del proyecto y actualiza el archivo de bloqueo.

Después de ejecutarlo se utilizará `renv::status()` para comprobar que no existan diferencias.

## 7. Reconstrucción del entorno

En otra computadora o en GitHub Actions se podrá ejecutar:

```r
renv::restore()
```

### Explicación general

Este comando reconstruye la biblioteca del proyecto utilizando las versiones registradas en `renv.lock`.

### Explicación línea por línea

- `renv::restore()` lee el archivo `renv.lock` e instala las versiones registradas de los paquetes.

`renv` no instala automáticamente la versión de R. R deberá instalarse previamente; posteriormente, `renv::restore()` reconstruirá los paquetes.

## 8. Flujo de trabajo adoptado

El flujo será el siguiente:

1. Acordar qué paquete necesita un bloque de código.
2. Instalarlo dentro del proyecto.
3. Escribir y probar el código.
4. Ejecutar `renv::snapshot()`.
5. Comprobar el entorno con `renv::status()`.
6. Revisar los cambios con Git.
7. Realizar el commit cuando el bloque completo funcione.

De esta manera, `renv` no determina qué herramientas se utilizan. Solamente registra de forma reproducible las decisiones tomadas durante el desarrollo.