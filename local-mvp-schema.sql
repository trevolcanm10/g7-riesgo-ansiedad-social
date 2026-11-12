-- Preparación opcional: revisar contra SHOW CREATE TABLE antes de aplicar.
-- No ejecutar sobre tablas existentes sin comparar su estructura.
CREATE DATABASE IF NOT EXISTS riesgo_social_users CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS riesgo_social_evaluations CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS riesgo_social_users.users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  names VARCHAR(150) NOT NULL,
  surnames VARCHAR(150) NOT NULL,
  code VARCHAR(50) NOT NULL UNIQUE,
  email VARCHAR(255) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,
  school VARCHAR(150) NOT NULL,
  cycle INT NOT NULL,
  role ENUM('ESTUDIANTE', 'PERSONAL_UNAYOE', 'ADMINISTRADOR') NOT NULL,
  created_at DATETIME NOT NULL
);

CREATE TABLE IF NOT EXISTS riesgo_social_evaluations.risk_recommendations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  category ENUM('BAJO', 'MEDIO', 'ALTO') NOT NULL UNIQUE,
  title VARCHAR(255) NOT NULL,
  description TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS riesgo_social_evaluations.risk_evaluations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  risk_recommendation_id BIGINT UNSIGNED NOT NULL,
  phq9_score INT NOT NULL,
  gad7_score INT NOT NULL,
  sleep_hours DOUBLE NOT NULL,
  exercise_freq DOUBLE NOT NULL,
  social_activity DOUBLE NOT NULL,
  online_stress DOUBLE NOT NULL,
  gpa DOUBLE NOT NULL,
  family_support DOUBLE NOT NULL,
  screen_time DOUBLE NOT NULL,
  academic_stress DOUBLE NOT NULL,
  diet_quality DOUBLE NOT NULL,
  self_efficacy DOUBLE NOT NULL,
  peer_relationship DOUBLE NOT NULL,
  financial_stress DOUBLE NOT NULL,
  sleep_quality DOUBLE NOT NULL,
  anxiety_probability DOUBLE NOT NULL,
  risk_level ENUM('BAJO', 'MEDIO', 'ALTO') NOT NULL,
  explanation TEXT NOT NULL,
  ai_report JSON NOT NULL,
  created_at DATETIME NOT NULL,
  INDEX (user_id, created_at),
  CONSTRAINT fk_risk_recommendation FOREIGN KEY (risk_recommendation_id)
    REFERENCES riesgo_social_evaluations.risk_recommendations(id)
);
