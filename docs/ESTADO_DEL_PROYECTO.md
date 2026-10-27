# Estado del proyecto

Última actualización: 27 de octubre de 2026.

## Objetivo vigente

Construir un flujo reproducible para pronosticar la remisión mensual de leche a plantas industriales en Uruguay mediante modelos SARIMA.

## Alcance actual

Esta etapa incluye:

- una serie mensual de remisión de leche;
- modelos SARIMA;
- R y RStudio;
- SQL y SQLite;
- Git y GitHub;
- automatización posterior mediante GitHub Actions.

Esta etapa no incluye todavía:

- ARIMAX;
- variables explicativas externas;
- machine learning;
- datos simulados.

## Decisiones metodológicas y técnicas

1. Los datos se obtendrán desde el INALE mediante código de R.
2. Cada descarga conservará una copia original fechada y sin modificaciones.
3. R realizará la lectura y preparación inicial de los datos.
4. R cargará los datos en una tabla provisional de SQLite.
5. SQL construirá la tabla analítica y realizará controles de calidad.
6. R recuperará desde SQLite la serie que se utilizará en los modelos.
7. Primero se completará y validará el flujo SARIMA.
8. GitHub Actions se incorporará solamente cuando el proceso local funcione correctamente.
9. El taller 05B será una referencia metodológica, pero su código será revisado y adaptado al nuevo proyecto.

## Forma de trabajo

- El desarrollo se realizará en unidades pequeñas.
- Daniel ejecutará los pasos en su computadora.
- Cada unidad será comprobada antes de continuar.
- El código sustantivo tendrá documentación pedagógica complementaria.
- Los commits representarán bloques completos y comprobados.
- El repositorio será la fuente principal para conocer el estado real del proyecto.

## Trabajo completado

- Proyecto local de RStudio creado.
- Repositorio Git inicializado.
- Rama principal renombrada de `master` a `main`.
- Estructura inicial de carpetas creada.
- Documento de inicio de Git creado.
- README inicial creado.

## Estado de Git al finalizar esta unidad

- Rama actual: `main`.
- Primer commit local: creado.
- Repositorio remoto en GitHub: todavía no creado.
- Archivos iniciales: incorporados al seguimiento de Git.

## Trabajo pendiente

- Crear el repositorio remoto en GitHub.
- Conectar el repositorio local con GitHub.
- Configurar el entorno de paquetes de R.
- Desarrollar la descarga de datos del INALE.
- Crear la base SQLite.
- Desarrollar y evaluar los modelos SARIMA.

## Siguiente paso exacto

Crear el repositorio remoto en GitHub y conectarlo con el repositorio local.