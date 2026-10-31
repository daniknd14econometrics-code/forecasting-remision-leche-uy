# Paso 08_00 - Preflight e inventario de fuentes internacionales de PTF

## Propósito

Este paso realiza un inventario reproducible de la carpeta de fuentes internacionales de productividad total de los factores (PTF). Su función es identificar qué archivos existen, qué formatos y hojas contienen, qué columnas podrían representar año, sector o PTF, y qué problemas de lectura deben resolverse antes de extraer y armonizar las series.

El paso 08_00 es deliberadamente **descriptivo y no transformativo**. No selecciona una fuente canónica, no calcula crecimientos de PTF, no construye correspondencias sectoriales y no genera el instrumento.

## Archivos del paso

| Tipo | Archivo | Función |
|---|---|---|
| Script | `08_preflight_fuentes_ptf.R` | Recorre las fuentes y construye el inventario. |
| Salida | `08_inventario_fuentes_ptf.dta` | Inventario a nivel de archivo o de hoja. |
| Registro | `08_preflight_fuentes_ptf.log` | Rutas, resultados, estados de lectura y errores. |
| Informe | `08_00_informe_preflight_fuentes_ptf.pdf` | Documentación técnica ampliada del paso. |

## Entrada

La entrada es la carpeta:

```text
Fuentes Internacionales/Shocks PTF
```

El script intenta localizarla mediante:

1. la variable de entorno `SHOCKS_PTF_DIR`;
2. rutas locales conocidas bajo OneDrive;
3. las variantes `Desktop` y `Escritorio`.

No mueve, modifica ni sobrescribe los archivos originales.

## Operación del script

El preflight:

1. enumera recursivamente todos los archivos;
2. identifica la carpeta superior como país o familia de fuente;
3. inspecciona formatos tabulares con una muestra pequeña;
4. registra cada hoja de Excel como una fila separada;
5. detecta nombres de columnas compatibles con año, sector y PTF mediante expresiones regulares;
6. registra archivos auxiliares, comprimidos y PDF sin forzar su conversión;
7. guarda una sola salida en formato Stata y un log de ejecución.

Los nombres detectados son **indicios**, no validaciones semánticas. Una columna marcada como posible PTF debe verificarse en el paso de extracción.

## Decisiones metodológicas y operativas

- **Lectura recursiva:** evita depender de una lista manual de países o archivos.
- **Nivel archivo-hoja:** un libro con varias hojas genera varias filas; por eso el número de filas del inventario puede superar el número de archivos.
- **Muestreo mínimo:** se leen encabezados y pocas filas, no bases completas. El objetivo es reconocer estructura, no procesar datos.
- **Preservación de fuentes:** el script es de solo lectura respecto de la carpeta de insumos.
- **Salida única `.dta`:** se respeta la convención del proyecto de no generar CSV o Excel como productos intermedios.
- **PDF y texto auxiliar:** se inventarían, pero no se interpretan como series tabulares.
- **Archivos comprimidos:** los ZIP se listan sin integrarlos; RAR y 7z se registran sin descompresión automática.
- **Errores no silenciosos:** cualquier fallo queda explícito en `estado_lectura` y `mensaje`.
- **Sin armonización:** no se decide todavía entre PTF sobre valor agregado, producto bruto, productividad laboral u otras definiciones.

## Resultado de la ejecución validada

La ejecución de `08_preflight_v4_2026-07-18` produjo:

- **1.075 archivos únicos** inventariados;
- **1.608 filas** en la base final, porque las hojas de los libros se registran por separado;
- **1.237 filas** con lectura satisfactoria;
- **un único error de lectura**, localizado en `IDB-LA/productivity-and-factor-accumulation-LA/dataset_metadata.csv`.

El error corresponde a un archivo auxiliar de metadatos cuyo encabezado no pudo leerse con UTF-8, CP932, SHIFT-JIS ni Latin-1. No bloquea el inventario general. Debe corregirse solo si esa fuente se utiliza posteriormente.

## Esquema de `08_inventario_fuentes_ptf.dta`

La base contiene 17 variables:

| Grupo | Variables |
|---|---|
| Identificación | `codigo_pais`, `carpeta_pais`, `ruta_relativa`, `archivo`, `extension`, `hoja` |
| Metadatos del archivo | `tamanio_bytes`, `tamanio_mb`, `fecha_modificacion` |
| Resultado de lectura | `estado_lectura`, `mensaje`, `contenido_archivo` |
| Estructura tabular | `n_columnas`, `columnas_detectadas` |
| Detecciones preliminares | `posibles_variables_anio`, `posibles_variables_sector`, `posibles_variables_ptf` |

## Relación con los pasos posteriores

La secuencia finalmente adoptada es:

```text
08_00  inventario y diagnóstico de archivos
08_01  extracción de fuentes directas conservando su sector original
09     armonización país × división CIIU Rev. 4 × año
10     cruce con pesos firma × HS6 × país y construcción del IV
11     integración del IV al panel EAAE
```

El documento exploratorio `08_README_resumen_fuentes_ptf.md` proponía inicialmente una salida directa por HS6 y 15 grupos sectoriales `k`. Esa arquitectura no corresponde al paso 08_00 y fue reemplazada por una separación más limpia: primero se preservan los sectores nativos; después se armonizan a divisiones CIIU Rev. 4; finalmente se aplica el puente HS6-CIIU4 al construir el instrumento.

## Criterio de cierre

El paso 08_00 queda cerrado cuando:

- existe una fila identificable para cada archivo u hoja examinada;
- el inventario se guarda correctamente en `.dta`;
- el log registra rutas, conteos y errores;
- ninguna fuente original es alterada;
- los problemas pendientes quedan visibles para el paso 08_01.

La ejecución adjunta satisface estos criterios.
