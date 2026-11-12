-- Run this file against the database named by DB_NAME before starting the service.
-- All timestamps are stored in UTC. User IDs are references only; this service owns no user account data.

CREATE TABLE IF NOT EXISTS student_preferences (
    user_id BIGINT UNSIGNED NOT NULL,
    interests JSON NOT NULL,
    course_codes JSON NOT NULL,
    available_slots JSON NOT NULL,
    preferred_modalities JSON NOT NULL,
    time_zone VARCHAR(64) NOT NULL DEFAULT 'America/Lima',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS support_resources (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    resource_type ENUM('TUTORING', 'WORKSHOP', 'MATERIAL') NOT NULL,
    title VARCHAR(160) NOT NULL,
    description TEXT NOT NULL,
    tags JSON NOT NULL,
    course_codes JSON NOT NULL,
    modality ENUM('PRESENCIAL', 'REMOTO', 'HIBRIDO') NULL,
    location VARCHAR(255) NULL,
    start_at DATETIME NULL,
    end_at DATETIME NULL,
    capacity INT UNSIGNED NULL,
    url VARCHAR(2048) NULL,
    creator_user_id BIGINT UNSIGNED NOT NULL,
    status ENUM('PUBLISHED', 'CANCELLED') NOT NULL DEFAULT 'PUBLISHED',
    is_synthetic BOOLEAN NOT NULL DEFAULT FALSE,
    demo_key VARCHAR(80) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_support_resources_demo_key (demo_key),
    KEY ix_support_resources_status_type_start (status, resource_type, start_at),
    KEY ix_support_resources_creator (creator_user_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS workshop_enrollments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    resource_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    status ENUM('ACTIVE', 'CANCELLED') NOT NULL DEFAULT 'ACTIVE',
    enrolled_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_workshop_enrollment_user_resource (user_id, resource_id),
    KEY ix_workshop_enrollment_capacity (resource_id, status),
    CONSTRAINT fk_workshop_enrollment_resource
        FOREIGN KEY (resource_id) REFERENCES support_resources (id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS resource_interactions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    resource_id BIGINT UNSIGNED NOT NULL,
    event_type ENUM('VIEW', 'CLICK', 'ENROLL', 'COMPLETE', 'DISMISS', 'WITHDRAW') NOT NULL,
    event_key VARCHAR(100) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_resource_interaction_event_key (event_key),
    KEY ix_resource_interaction_user_resource_date (user_id, resource_id, created_at),
    KEY ix_resource_interaction_resource_type_date (resource_id, event_type, created_at),
    CONSTRAINT fk_resource_interaction_resource
        FOREIGN KEY (resource_id) REFERENCES support_resources (id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
