-- Ejecutar dentro de la base exclusiva de academic-agenda.
-- user_id referencia el identificador de Users, sin FK entre servicios.
CREATE TABLE IF NOT EXISTS actividades_academicas (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(255) NOT NULL,
    course VARCHAR(255) NOT NULL,
    activity_type VARCHAR(32) NOT NULL,
    activity_date DATE NOT NULL,
    estimated_hours DECIMAL(8,2) NOT NULL,
    priority VARCHAR(16) NOT NULL,
    description TEXT NOT NULL,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_actividades_usuario_fecha (user_id, activity_date, created_at)
);
