# Inicio del repositorio local

## Objetivo

Este documento registra la creación del proyecto de RStudio, la inicialización del repositorio Git y la estructura básica de carpetas del proyecto de forecasting.

## Herramientas utilizadas

- RStudio
- Terminal integrado de RStudio
- Git
- Símbolo del sistema de Windows (`cmd.exe`)

## 1. Comprobación del repositorio

```bash
git rev-parse --show-toplevel
git status
git branch --show-current
```

### Explicación general

Este bloque comprueba que el Terminal está trabajando dentro del repositorio correcto, muestra su estado y permite conocer la rama activa.

### Explicación línea por línea

```bash
git rev-parse --show-toplevel
```

Muestra la ruta correspondiente a la carpeta principal del repositorio Git.

En este proyecto, el resultado esperado es:

```text
C:/Users/dani-/repos/forecasting-remision-leche-uy
```

```bash
git status
```

Muestra la situación actual del repositorio: rama activa, archivos modificados, archivos nuevos y cambios preparados para un commit.

```bash
git branch --show-current
```

Muestra únicamente el nombre de la rama activa.

## 2. Cambio de la rama principal

```bash
git branch -M main
git branch --show-current
git status
```

### Explicación general

Este bloque cambia el nombre de la rama inicial de `master` a `main` y comprueba que el cambio se haya realizado correctamente.

### Explicación línea por línea

```bash
git branch -M main
```

Cambia el nombre de la rama actual a `main`. La opción `-M` fuerza el cambio de nombre si fuera necesario.

```bash
git branch --show-current
```

Comprueba el nombre de la rama activa. El resultado esperado es `main`.

```bash
git status
```

Comprueba nuevamente el estado del repositorio. La primera línea debería indicar `On branch main`.

## 3. Creación de la estructura de carpetas

```bat
mkdir R
mkdir sql
mkdir data\original
mkdir data\processed
mkdir database
mkdir docs\R
mkdir docs\sql
mkdir docs\git
mkdir outputs\figures
mkdir outputs\tables
dir
```

### Explicación general

Este bloque crea las carpetas que separarán el código, los datos, la base SQLite, la documentación y los resultados.

### Explicación línea por línea

- `mkdir R`: crea la carpeta para los scripts de R.
- `mkdir sql`: crea la carpeta para los archivos de código SQL.
- `mkdir data\original`: crea la carpeta para las copias originales descargadas del INALE.
- `mkdir data\processed`: crea la carpeta para datos preparados o transformados.
- `mkdir database`: crea la carpeta donde se generará la base SQLite.
- `mkdir docs\R`: crea la carpeta para explicar el código de R.
- `mkdir docs\sql`: crea la carpeta para explicar el código SQL.
- `mkdir docs\git`: crea la carpeta para documentar Git y GitHub.
- `mkdir outputs\figures`: crea la carpeta para los gráficos generados.
- `mkdir outputs\tables`: crea la carpeta para las tablas y resultados.
- `dir`: muestra el contenido de la carpeta principal para comprobar el resultado.

`mkdir` significa *make directory*, es decir, crear una carpeta.

## Resultado comprobado

La carpeta principal contiene actualmente:

```text
forecasting-remision-leche-uy/
├── R/
├── sql/
├── data/
│   ├── original/
│   └── processed/
├── database/
├── docs/
│   ├── R/
│   ├── sql/
│   └── git/
├── outputs/
│   ├── figures/
│   └── tables/
├── .gitignore
└── forecasting-remision-leche-uy.Rproj
```

## Posibles errores

### `fatal: not a git repository`

Significa que el Terminal no está ubicado dentro de la carpeta del repositorio. La solución es abrir el proyecto `.Rproj` y utilizar el Terminal integrado de RStudio.

### Una carpeta no aparece en Git

Git no registra carpetas vacías. La carpeta comenzará a aparecer en Git cuando contenga al menos un archivo.

### `A subdirectory or file already exists`

Significa que la carpeta ya fue creada. No es necesario volver a crearla.