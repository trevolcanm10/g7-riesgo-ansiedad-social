-- Esquema de la base de datos propia del Panel Institucional (Modulo 4).
--
-- Este servicio tiene su propia base de datos y sus propias tablas. No
-- comparte esquema con ningun otro microservicio: el microservicio de
-- usuarios guarda las cuentas y el de evaluacion guarda las evaluaciones.
--
-- Aplicacion: python scripts/init_db.py

CREATE TABLE IF NOT EXISTS atenciones (
    id                      INT AUTO_INCREMENT PRIMARY KEY,
    estudiante_codigo       VARCHAR(50)  NOT NULL,
    -- Identificador numerico del estudiante en el servicio de usuarios. Se
    -- resuelve por HTTP. Permite correlacionar con las evaluaciones de riesgo
    -- sin compartir bases de datos. Nulo si no se pudo resolver.
    estudiante_id           INT          NULL,
    modalidad               VARCHAR(20)  NOT NULL,
    tipo                    VARCHAR(30)  NOT NULL,
    estado                  VARCHAR(20)  NOT NULL DEFAULT 'registrada',

    -- Indicadores del contrato de evaluacion de riesgo. Todos opcionales:
    -- una atencion puede registrarse sin indicadores y quedar sin perfil.
    phq9                    DOUBLE       NULL,
    gad7                    DOUBLE       NULL,
    online_stress           DOUBLE       NULL,
    financial_stress        DOUBLE       NULL,
    exercise_freq           DOUBLE       NULL,
    social_activity         DOUBLE       NULL,
    sleep_hours             DOUBLE       NULL,

    -- Cluster asignado por el modelo de agrupamiento.
    cluster_id              INT          NULL,

    notas                   TEXT         NULL,
    seguimiento_requerido   BOOLEAN      NOT NULL DEFAULT FALSE,
    registrado_por          VARCHAR(120) NULL,

    fecha_atencion          DATETIME     NOT NULL,
    fecha_creacion          DATETIME     NOT NULL,
    -- Periodo YYYY-MM derivado de fecha_atencion. Se calcula en la aplicacion
    -- para no depender de funciones especificas de motor.
    periodo                 VARCHAR(7)   NOT NULL,

    INDEX idx_atenciones_estudiante (estudiante_codigo),
    INDEX idx_atenciones_estudiante_id (estudiante_id),
    INDEX idx_atenciones_modalidad (modalidad),
    INDEX idx_atenciones_tipo (tipo),
    INDEX idx_atenciones_estado (estado),
    INDEX idx_atenciones_cluster (cluster_id),
    INDEX idx_atenciones_seguimiento (seguimiento_requerido),
    INDEX idx_atenciones_fecha (fecha_atencion),
    INDEX idx_atenciones_periodo (periodo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
