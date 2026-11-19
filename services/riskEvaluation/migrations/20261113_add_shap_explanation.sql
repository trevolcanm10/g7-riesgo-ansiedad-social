-- Run against the configured riskEvaluation database after confirming its name.
-- Additive and repeatable: existing evaluation rows remain unchanged and get NULL.
SET @shap_column_exists = (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'risk_evaluations'
    AND COLUMN_NAME = 'shap_explanation'
);

SET @shap_migration_sql = IF(
  @shap_column_exists = 0,
  'ALTER TABLE risk_evaluations ADD COLUMN shap_explanation JSON NULL AFTER ai_report',
  'SELECT 1'
);

PREPARE shap_migration FROM @shap_migration_sql;
EXECUTE shap_migration;
DEALLOCATE PREPARE shap_migration;
