# Primer commit local

## Objetivo

Incorporar los archivos iniciales al seguimiento de Git y guardar la primera versión completa del proyecto.

Un commit representa una versión identificable del proyecto. Antes de crearlo, los archivos deben pasar por el área de preparación de Git.

## 1. Preparación de los archivos

```bash
git add .gitignore README.md forecasting-remision-leche-uy.Rproj docs/
git status
```

### Explicación general

Este bloque selecciona los archivos que formarán parte del primer commit y permite revisarlos antes de confirmar la operación.

### Explicación línea por línea

```bash
git add .gitignore README.md forecasting-remision-leche-uy.Rproj docs/
```

Incorpora al área de preparación:

- `.gitignore`;
- `README.md`;
- el archivo del proyecto de RStudio;
- todo el contenido de `docs/`.

El área de preparación, también llamada *staging area*, contiene los cambios seleccionados para el próximo commit.

```bash
git status
```

Muestra qué archivos están preparados. Deben aparecer bajo el encabezado `Changes to be committed`.

## 2. Creación del commit

```bash
git commit -m "Initialize project structure and documentation"
git log --oneline -1
```

### Explicación general

Este bloque crea el primer commit y después muestra un resumen de la versión guardada.

### Explicación línea por línea

```bash
git commit -m "Initialize project structure and documentation"
```

Crea el commit. La opción `-m` permite escribir directamente un mensaje descriptivo.

El mensaje indica que este commit inicializa la estructura y la documentación del proyecto.

```bash
git log --oneline -1
```

Muestra únicamente el commit más reciente en una sola línea.

## Resultado esperado

Git debería informar cuántos archivos fueron incorporados y mostrar un identificador breve del commit.

## Posibles errores

### `Author identity unknown`

Git no tiene configurados el nombre y el correo del autor. En ese caso, deben configurarse antes de crear el commit.

### Un archivo no aparece en el commit

El archivo no fue agregado al área de preparación. Se debe comprobar su estado mediante `git status`.

### Las carpetas vacías no aparecen

Git no registra carpetas vacías. Aparecerán cuando contengan archivos.