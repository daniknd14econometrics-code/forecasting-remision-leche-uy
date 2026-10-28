-- ============================================================================
-- Creación de la tabla analítica mensual de remisión de leche
-- Fuente: tabla provisional stg_remision_inale
-- Motor: SQLite
-- ============================================================================


-- 1. Inicio de la transacción ------------------------------------------------

BEGIN TRANSACTION;


-- 2. Eliminación de una versión anterior -------------------------------------

DROP TABLE IF EXISTS analitica_remision_mensual;


-- 3. Creación de la tabla analítica ------------------------------------------

CREATE TABLE analitica_remision_mensual (
    fecha                       TEXT    NOT NULL PRIMARY KEY,
    anio                        INTEGER NOT NULL,
    mes                         INTEGER NOT NULL,
    remision_litros             REAL    NOT NULL,
    remision_millones_litros    REAL    NOT NULL,
    remision_kilos_solidos      REAL    NOT NULL,
    grasa_porcentaje            REAL    NOT NULL,
    proteina_porcentaje         REAL    NOT NULL,
    observacion_origen          TEXT,
    archivo_origen              TEXT    NOT NULL,
    fecha_carga_utc             TEXT    NOT NULL,

    CHECK (date(fecha) IS NOT NULL),
    CHECK (fecha = date(fecha, 'start of month')),
    CHECK (anio = CAST(strftime('%Y', fecha) AS INTEGER)),
    CHECK (mes = CAST(strftime('%m', fecha) AS INTEGER)),
    CHECK (mes BETWEEN 1 AND 12),
    CHECK (remision_litros > 0),
    CHECK (remision_millones_litros > 0),
    CHECK (remision_kilos_solidos > 0),
    CHECK (grasa_porcentaje BETWEEN 0 AND 10),
    CHECK (proteina_porcentaje BETWEEN 0 AND 10),

    UNIQUE (anio, mes)
);


-- 4. Transformación y carga desde la tabla provisional -----------------------

INSERT INTO analitica_remision_mensual (
    fecha,
    anio,
    mes,
    remision_litros,
    remision_millones_litros,
    remision_kilos_solidos,
    grasa_porcentaje,
    proteina_porcentaje,
    observacion_origen,
    archivo_origen,
    fecha_carga_utc
)
SELECT
    fecha,
    CAST(strftime('%Y', fecha) AS INTEGER) AS anio,
    CAST(strftime('%m', fecha) AS INTEGER) AS mes,
    remision_litros,
    remision_litros / 1000000.0 AS remision_millones_litros,
    remision_kilos_solidos,
    grasa_proporcion * 100.0 AS grasa_porcentaje,
    proteina_proporcion * 100.0 AS proteina_porcentaje,
    observacion_origen,
    archivo_origen,
    fecha_carga_utc
FROM stg_remision_inale
ORDER BY fecha;


-- 5. Confirmación de la transacción ------------------------------------------

COMMIT;


-- 6. Control de cantidad de filas y periodo ----------------------------------

SELECT
    (SELECT COUNT(*)
     FROM stg_remision_inale) AS filas_staging,

    COUNT(*) AS filas_analiticas,

    CASE
        WHEN COUNT(*) = (
            SELECT COUNT(*)
            FROM stg_remision_inale
        )
        THEN 'OK'
        ELSE 'REVISAR'
    END AS control_filas,

    MIN(fecha) AS fecha_min,
    MAX(fecha) AS fecha_max

FROM analitica_remision_mensual;


-- 7. Control de valores inválidos --------------------------------------------

SELECT
    SUM(
        CASE
            WHEN fecha IS NULL THEN 1
            ELSE 0
        END
    ) AS fechas_nulas,

    COUNT(*) - COUNT(DISTINCT fecha) AS fechas_duplicadas,

    SUM(
        CASE
            WHEN remision_litros <= 0
              OR remision_millones_litros <= 0
              OR remision_kilos_solidos <= 0
            THEN 1
            ELSE 0
        END
    ) AS valores_no_positivos,

    SUM(
        CASE
            WHEN grasa_porcentaje NOT BETWEEN 0 AND 10
              OR proteina_porcentaje NOT BETWEEN 0 AND 10
            THEN 1
            ELSE 0
        END
    ) AS porcentajes_invalidos

FROM analitica_remision_mensual;


-- 8. Control de continuidad mensual ------------------------------------------
-- La consulta debe devolver cero filas si no existen meses faltantes.

WITH orden_mensual AS (
    SELECT
        fecha,
        LAG(fecha) OVER (
            ORDER BY fecha
        ) AS fecha_anterior
    FROM analitica_remision_mensual
)

SELECT
    fecha_anterior,
    fecha AS fecha_actual,
    date(fecha_anterior, '+1 month') AS fecha_esperada

FROM orden_mensual

WHERE fecha_anterior IS NOT NULL
  AND fecha <> date(fecha_anterior, '+1 month')

ORDER BY fecha;