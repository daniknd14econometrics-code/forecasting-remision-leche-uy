# Forecasting de la remisión de leche en Uruguay

Proyecto reproducible para construir, evaluar y actualizar pronósticos de la remisión mensual de leche a plantas industriales en Uruguay.

La fuente de información será el Instituto Nacional de la Leche (INALE). El proyecto integrará R, SQL, SQLite, Git, GitHub y, en una etapa posterior, GitHub Actions.

## Objetivo

Desarrollar un flujo de trabajo que permita:

- obtener los datos publicados por el INALE;
- conservar una copia original y fechada de cada descarga;
- preparar y validar la información;
- almacenar los datos en una base SQLite;
- utilizar consultas SQL para construir y controlar la tabla analítica;
- estimar y comparar modelos SARIMA;
- evaluar los pronósticos fuera de la muestra;
- actualizar posteriormente el proceso de manera automatizada.

## Alcance actual

La primera etapa se concentra exclusivamente en modelos SARIMA para una serie mensual.

Por el momento, el proyecto no incluye:

- modelos ARIMAX;
- variables explicativas externas;
- modelos de machine learning;
- datos simulados.

Estas extensiones solamente se considerarán después de completar y validar el flujo SARIMA.

## Flujo previsto

1. R localiza y descarga el archivo publicado por el INALE.
2. R conserva una copia original fechada, sin modificarla.
3. R lee y prepara inicialmente los datos.
4. R carga la información en una tabla provisional de SQLite.
5. SQL construye la tabla analítica y ejecuta controles de calidad.
6. R recupera la serie desde SQLite.
7. R estima, compara y evalúa los modelos SARIMA.
8. Git y GitHub registran la evolución del proyecto.
9. GitHub Actions automatiza posteriormente la actualización.

## Estructura del proyecto

```text
forecasting-remision-leche-uy/
├── R/                  # Scripts de R
├── sql/                # Consultas y transformaciones SQL
├── data/
│   ├── original/       # Archivos originales descargados
│   └── processed/      # Datos preparados
├── database/           # Base de datos SQLite
├── docs/
│   ├── R/              # Explicaciones del código R
│   ├── sql/            # Explicaciones del código SQL
│   └── git/            # Procedimientos de Git y GitHub
├── outputs/
│   ├── figures/        # Gráficos
│   └── tables/         # Tablas y resultados
├── .gitignore
├── README.md
└── forecasting-remision-leche-uy.Rproj
```

## Principio de documentación

Cada componente sustantivo de código tendrá un documento complementario que incluirá:

1. el bloque de código;
2. su objetivo general;
3. la explicación de cada línea;
4. el resultado esperado;
5. los posibles errores;
6. la forma de comprobar su funcionamiento.

## Estado actual

El repositorio local y su estructura inicial han sido creados. Todavía no se ha descargado información ni se han estimado modelos.

## Autor

Daniel Méndez