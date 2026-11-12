-- Esquema del microservicio Citas (base de datos propia). Fechas en UTC.
-- Sin claves foráneas hacia Users: solo se guarda el id del usuario.

CREATE TABLE IF NOT EXISTS availability_slots (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  staff_user_id INT UNSIGNED NOT NULL,
  start_at      DATETIME NOT NULL,
  status        ENUM('LIBRE','RESERVADO','BLOQUEADO') NOT NULL DEFAULT 'LIBRE',
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_slot_staff_start (staff_user_id, start_at),
  KEY idx_slot_status_start (status, start_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS appointments (
  id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  student_user_id  INT UNSIGNED NOT NULL,
  staff_user_id    INT UNSIGNED NOT NULL,
  slot_id          BIGINT UNSIGNED NOT NULL,
  start_at         DATETIME NOT NULL,
  status           ENUM('SOLICITADA','CONFIRMADA','ATENDIDA','NO_ASISTIO','CANCELADA')
                   NOT NULL DEFAULT 'SOLICITADA',
  priority         ENUM('NORMAL','ALTA') NOT NULL DEFAULT 'NORMAL',
  reason           VARCHAR(200) NULL,
  reschedule_count INT UNSIGNED NOT NULL DEFAULT 0,
  cancelled_by     INT UNSIGNED NULL,
  cancel_reason    VARCHAR(200) NULL,
  created_at       DATETIME NOT NULL,
  updated_at       DATETIME NOT NULL,
  CONSTRAINT fk_appt_slot FOREIGN KEY (slot_id) REFERENCES availability_slots(id),
  KEY idx_appt_student (student_user_id, status),
  KEY idx_appt_staff_start (staff_user_id, start_at)
) ENGINE=InnoDB;

-- Auditoría y datos para entrenar el modelo de inasistencia.
CREATE TABLE IF NOT EXISTS appointment_events (
  id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  appointment_id BIGINT UNSIGNED NOT NULL,
  event_type     VARCHAR(30) NOT NULL,
  actor_user_id  INT UNSIGNED NOT NULL,
  created_at     DATETIME NOT NULL,
  CONSTRAINT fk_event_appt FOREIGN KEY (appointment_id) REFERENCES appointments(id),
  KEY idx_event_appt (appointment_id)
) ENGINE=InnoDB;
