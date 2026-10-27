# Conexión del repositorio local con GitHub

## Objetivo

Conectar el repositorio Git almacenado en la computadora con el repositorio remoto creado en GitHub y publicar sus commits.

El repositorio local y el repositorio remoto son dos ubicaciones diferentes:

- el repositorio local está en la computadora;
- el repositorio remoto está alojado en GitHub.

## Repositorio remoto

```text
https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy
```

URL utilizada por Git:

```text
https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy.git
```

## 1. Registrar el repositorio remoto

```bash
git remote add origin https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy.git
git remote -v
```

### Explicación general

Este bloque registra en el repositorio local la dirección del repositorio de GitHub y comprueba que haya sido guardada correctamente.

### Explicación línea por línea

```bash
git remote add origin https://github.com/daniknd14econometrics-code/forecasting-remision-leche-uy.git
```

Agrega una conexión remota.

- `git remote add` indica que se agregará un repositorio remoto.
- `origin` es el nombre convencional asignado al repositorio remoto principal.
- La URL indica la ubicación del repositorio en GitHub.

```bash
git remote -v
```

Muestra las conexiones remotas configuradas.

Deben aparecer dos registros para `origin`:

- `fetch`: dirección desde la cual se reciben cambios;
- `push`: dirección a la cual se envían cambios.

## 2. Publicar la rama principal

```bash
git push -u origin main
```

### Explicación general

Este comando envía a GitHub los commits existentes en la rama local `main`.

### Explicación de cada componente

- `git push`: envía commits al repositorio remoto.
- `-u`: establece una relación permanente entre las ramas local y remota.
- `origin`: identifica el repositorio remoto.
- `main`: identifica la rama que será publicada.

Después de establecer esta relación, los siguientes envíos podrán realizarse simplemente mediante:

```bash
git push
```

## Resultado esperado

Git debería:

1. autenticar la cuenta de GitHub si fuera necesario;
2. enviar los commits;
3. crear la rama remota `main`;
4. establecer la relación entre `main` local y `origin/main`.

## Posibles errores

### `remote origin already exists`

Ya existe una conexión llamada `origin`. Antes de modificarla, debe comprobarse mediante:

```bash
git remote -v
```

### Error de autenticación

GitHub puede abrir una ventana del navegador o de Git Credential Manager para confirmar la cuenta.

### `rejected` o `non-fast-forward`

El repositorio remoto contiene commits que no existen localmente. No debería ocurrir aquí porque el repositorio de GitHub fue creado vacío.