# Flujo general de Git y GitHub

## Objetivo

Este documento presenta de manera integrada la lógica de Git utilizada en el proyecto, desde la creación del repositorio local hasta la publicación de commits en GitHub.

## Los cuatro espacios de trabajo

| Espacio | Función |
|---|---|
| Carpeta de trabajo | Contiene los archivos que se crean y modifican normalmente |
| Área de preparación | Contiene los cambios seleccionados para el siguiente commit |
| Repositorio local | Contiene los commits guardados en la computadora |
| Repositorio remoto | Contiene los commits publicados en GitHub |

El flujo principal es:

```text
Modificar archivos
       ↓
git add
       ↓
Área de preparación
       ↓
git commit
       ↓
Repositorio local
       ↓
git push
       ↓
GitHub
```

## 1. Creación del repositorio local

RStudio creó el repositorio Git cuando se seleccionó la opción:

```text
Create a git repository
```

Internamente, esto equivale a ejecutar:

```bash
git init
```

Git creó una carpeta oculta llamada `.git`, donde conserva el historial y la configuración del repositorio.

## 2. Comprobación inicial

```bash
git rev-parse --show-toplevel
git status
git branch --show-current
```

### Explicación general

Este bloque comprueba la ubicación del repositorio, su estado y la rama activa.

### Explicación línea por línea

```bash
git rev-parse --show-toplevel
```

Muestra la carpeta principal del repositorio.

```bash
git status
```

Muestra:

- la rama actual;
- los archivos nuevos;
- los archivos modificados;
- los archivos preparados;
- la relación con GitHub.

```bash
git branch --show-current
```

Muestra el nombre de la rama activa.

## 3. Cambio de la rama principal

```bash
git branch -M main
```

### Explicación general

Cambia el nombre de la rama actual a `main`.

### Explicación de sus componentes

- `git branch`: administra ramas.
- `-M`: renombra la rama actual.
- `main`: nuevo nombre de la rama.

## 4. Selección de archivos

```bash
git add .gitignore README.md forecasting-remision-leche-uy.Rproj docs/
git status
```

### Explicación general

Selecciona los archivos que deben formar parte del siguiente commit y permite revisar la selección.

### Explicación línea por línea

```bash
git add .gitignore README.md forecasting-remision-leche-uy.Rproj docs/
```

Pasa los archivos indicados al área de preparación.

`git add` no crea un commit y no publica nada en GitHub.

```bash
git status
```

Permite comprobar qué archivos están preparados bajo:

```text
Changes to be committed
```

## 5. Creación de un commit

```bash
git commit -m "Initialize project structure and documentation"
```

### Explicación general

Guarda en el repositorio local una versión compuesta por los archivos previamente seleccionados.

### Explicación de sus componentes

- `git commit`: crea una versión local.
- `-m`: permite escribir el mensaje en el mismo comando.
- El texto describe el contenido del commit.

Cada commit recibe un identificador único. El primer commit del proyecto fue:

```text
450ccaa
```

## 6. Consulta del historial

```bash
git log --oneline -1
```

### Explicación general

Muestra de manera resumida el commit más reciente.

### Explicación de sus componentes

- `git log`: consulta el historial.
- `--oneline`: muestra cada commit en una sola línea.
- `-1`: limita el resultado al último commit.

## 7. Conexión con GitHub

```bash
git remote add origin https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy.git
git remote -v
```

### Explicación general

Registra la dirección del repositorio remoto y comprueba la conexión configurada.

### Explicación línea por línea

```bash
git remote add origin https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy.git
```

Agrega el repositorio de GitHub con el nombre corto `origin`.

Este comando no envía archivos.

```bash
git remote -v
```

Muestra las direcciones utilizadas para:

- `fetch`: recibir cambios;
- `push`: enviar cambios.

## 8. Publicación inicial

```bash
git push -u origin main
```

### Explicación general

Envía los commits de la rama local `main` a GitHub.

### Explicación de sus componentes

- `git push`: envía commits.
- `-u`: establece la relación permanente entre las ramas.
- `origin`: repositorio remoto.
- `main`: rama publicada.

Después de establecer esta relación, normalmente bastará con ejecutar:

```bash
git push
```

## 9. Significado de las ramas

```text
main
```

Es la rama local almacenada en la computadora.

```text
origin
```

Es el nombre corto asignado al repositorio de GitHub.

```text
origin/main
```

Representa el estado conocido de la rama `main` en GitHub.

Cuando Git indica:

```text
Your branch is up to date with 'origin/main'.
```

significa que el último commit local y el último commit publicado son iguales.

## 10. Ciclo habitual del proyecto

Después de modificar o crear archivos:

```bash
git status
git add archivos_seleccionados
git status
git commit -m "Mensaje descriptivo"
git push
```

### Interpretación

1. `git status`: examina los cambios.
2. `git add`: selecciona los cambios.
3. `git status`: revisa la selección.
4. `git commit`: guarda una versión local.
5. `git push`: publica los commits en GitHub.

## Distinciones fundamentales

- Crear o modificar un archivo no hace que Git lo guarde.
- `git add` selecciona cambios, pero no crea una versión.
- `git commit` crea una versión local, pero no la publica.
- `git push` publica commits ya creados.
- Git no registra carpetas vacías.
- `git status` puede utilizarse en cualquier momento para conocer la situación del repositorio.