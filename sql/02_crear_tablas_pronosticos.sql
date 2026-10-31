-- Persistencia de trayectorias completas de doce meses.
-- Se ejecuta desde R dentro de una transaccion, con foreign_keys activado.
-- Este archivo solo crea las dos tablas: no estima ni inserta pronosticos.

CREATE TABLE IF NOT EXISTS forecast_ejecuciones (
    ejecucion_id           TEXT    NOT NULL PRIMARY KEY,
    fecha_ejecucion_utc     TEXT    NOT NULL,
    inicio_datos           TEXT    NOT NULL,
    ultimo_dato            TEXT    NOT NULL,
    n_observaciones        INTEGER NOT NULL,
    horizonte             INTEGER NOT NULL DEFAULT 12,
    version_modelo         TEXT    NOT NULL,
    especificacion         TEXT    NOT NULL,
    carpeta_resultados     TEXT    NOT NULL,
    huella_pronosticos     TEXT    NOT NULL,

    CHECK (length(trim(ejecucion_id)) > 0),
    CHECK (length(trim(fecha_ejecucion_utc)) > 0),
    CHECK (date(inicio_datos) IS NOT NULL
           AND inicio_datos = date(inicio_datos, 'start of month')),
    CHECK (date(ultimo_dato) IS NOT NULL
           AND ultimo_dato = date(ultimo_dato, 'start of month')),
    CHECK (ultimo_dato >= inicio_datos),
    CHECK (typeof(n_observaciones) = 'integer' AND n_observaciones > 0),
    CHECK (horizonte = 12),
    CHECK (length(trim(version_modelo)) > 0),
    CHECK (length(trim(especificacion)) > 0),
    CHECK (length(trim(carpeta_resultados)) > 0),
    CHECK (length(huella_pronosticos) = 32)
);

CREATE TABLE IF NOT EXISTS forecast_pronosticos (
    ejecucion_id           TEXT    NOT NULL,
    modelo                 TEXT    NOT NULL,
    origen                 TEXT    NOT NULL,
    fecha_objetivo         TEXT    NOT NULL,
    h                      INTEGER NOT NULL,
    pred_media             REAL    NOT NULL,
    pred_mediana           REAL    NOT NULL,
    inferior80             REAL    NOT NULL,
    superior80             REAL    NOT NULL,
    inferior95             REAL    NOT NULL,
    superior95             REAL    NOT NULL,

    PRIMARY KEY (ejecucion_id, modelo, h),
    UNIQUE (ejecucion_id, modelo, fecha_objetivo),
    FOREIGN KEY (ejecucion_id)
        REFERENCES forecast_ejecuciones (ejecucion_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,

    CHECK (length(trim(modelo)) > 0),
    CHECK (date(origen) IS NOT NULL
           AND origen = date(origen, 'start of month')),
    CHECK (date(fecha_objetivo) IS NOT NULL
           AND fecha_objetivo = date(fecha_objetivo, 'start of month')),
    CHECK (typeof(h) = 'integer' AND h BETWEEN 1 AND 12),
    CHECK (fecha_objetivo = date(origen, '+' || h || ' months')),
    CHECK (typeof(pred_media) = 'real' AND pred_media > 0),
    CHECK (typeof(pred_mediana) = 'real' AND pred_mediana > 0),
    CHECK (typeof(inferior80) = 'real' AND typeof(superior80) = 'real'
           AND typeof(inferior95) = 'real' AND typeof(superior95) = 'real'),
    CHECK (inferior95 <= inferior80 AND inferior80 <= superior80
           AND superior80 <= superior95)
);
