-- Esquema del microservicio Orientación Confidencial (base de datos propia). Fechas en UTC.
-- Sin claves foráneas hacia Users ni RiskEvaluation: solo se almacena el ID numérico.

CREATE TABLE IF NOT EXISTS solicitudes_orientacion (
  id                         INT AUTO_INCREMENT PRIMARY KEY,
  estudiante_id              INT UNSIGNED NOT NULL,
  mensaje                    TEXT NOT NULL,
  comparte_evaluacion_riesgo TINYINT(1) NOT NULL DEFAULT 0,
  evaluacion_riesgo_id       INT UNSIGNED NULL,
  tema_sugerido              VARCHAR(50) NULL,
  prioridad_sugerida         ENUM('alta', 'media', 'baja') NULL,
  urgencia_detectada         TINYINT(1) NOT NULL DEFAULT 0,
  estado                     ENUM('pendiente', 'atendida') NOT NULL DEFAULT 'pendiente',
  tema_confirmado            VARCHAR(50) NULL,
  prioridad_confirmada       ENUM('alta', 'media', 'baja') NULL,
  respuesta_escrita          TEXT NULL,
  atendido_por               INT UNSIGNED NULL,
  fecha_creacion             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_atencion             DATETIME NULL,
  KEY idx_sol_estudiante (estudiante_id, fecha_creacion),
  KEY idx_sol_estado_prio_fecha (estado, prioridad_confirmada, prioridad_sugerida, fecha_creacion),
  KEY idx_sol_tema (tema_confirmado, tema_sugerido)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
