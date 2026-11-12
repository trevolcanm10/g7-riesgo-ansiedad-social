---
name: clinerules
description: >
  Reglas mínimas para el módulo M1 (Evaluación de Riesgo, Seguimiento y
  Agenda Académica) del proyecto Taller_Social FISI-UNMSM.
---

# M1 — Reglas generales

## Arquitectura y tecnologías
- M1: Node.js/TypeScript (riskEvaluation), Python/Flask (prediction-ml y
  agenda académica).
- ML: ensamble CatBoost+KNN+LightGBM+RandomForest+XGBoost.
- Datos: MySQL (prod) / SQLite/JSON (dev transitoria); no almacenar
  datasets reales.
- Frontend: Flutter con `frontend/APIM.md` como guía de integración.

## Responsabilidad de M1
- Evaluación de riesgo → `services/riskEvaluation`.
- Predicción ML → `services/prediction-ml` (ensamble fijo, no tocar).
- Agenda académica → `services/academic-agenda` nuevo, sin tocar otros
  servicios.

## Preservación del código funcional
- No modificar `services/riskEvaluation`, `services/prediction-ml`,
  `openapi/*.yaml`, `frontend/APIM.md` ni `users` sin permiso expreso.
- Solo añadir archivos nuevos bajo el módulo correspondiente.

## Privacidad y IA
- Resultados de IA (SHAP, métricas, reportes) NO son diagnósticos.
- No exponer puntuaciones psicométricas fuera del usuario autenticado y
  la ruta correspondiente.
- No guardar credenciales ni secrets en código: `.env` o variables del
  entorno solo.

## Cambios mínimos
- Modificar solo lo necesario para cumplir el requerimiento.
- Verificar pruebas relacionadas antes de confirmar; no ejecutar
  pruebas costosas sin necesidad.
- Si se detecta un problema en otro módulo, reportarlo, no corregir.
