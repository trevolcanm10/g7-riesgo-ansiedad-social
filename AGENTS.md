# AGENTS.md — M1

## Arquitectura
- `services/riskEvaluation` Node.js/TypeScript; `services/prediction-ml` Flask,
  ensamble CatBoost+KNN+LightGBM+RandomForest+XGBoost; `services/academic-agenda`
  Flask (nuevo); MySQL (prod) / SQLite (dev); Flutter + `frontend/APIM.md`.

## Responsabilidad M1
- Riesgo → `riskEvaluation`; ML → `prediction-ml` (ensamble fijo); Agenda →
  `academic-agenda` nuevo, sin tocar otros servicios.

## Preservación
- No modificar `riskEvaluation`, `prediction-ml`, `openapi/*.yaml`,
  `frontend/APIM.md` ni `users` sin permiso. Solo añadir nuevos archivos.

## Seguridad y privacidad
- Credenciales y secrets solo en `.env` o variables de entorno.
- Resultados de IA (SHAP, métricas, reportes) no son diagnósticos.
- Sin puntuaciones psicométricas expuestas fuera del usuario autenticado.

## Cambios
- Mínimos; pruebas focalizadas (solo archivos modificados).
- Sin datasets reales, modelos binarios ni credenciales en código.
