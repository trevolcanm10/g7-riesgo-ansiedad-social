---
name: microservices-quality
description: Revisar contratos OpenAPI, autenticación, manejo de errores, pruebas y integración Flutter del módulo M1. ACTIVAR: al revisar/exponer OpenAPI, middleware de error, token en routes, pruebas Flutter. NO ACTIVAR: al implementar funcionalidad ML o agenda; solo revisión de integración.
---

# microservices-quality

## Objetivo
Garantizar que M1 (riesgo + predicción + agenda futura) mantiene OpenAPI,
autenticación y errores consistentes para Flutter. Revisión solo, sin cambios.

## Flujo
1. Contratos: leer `openapi/risk-evaluation.yaml` y `prediction-ml.yaml`;
   verificar rutas y schemas de `RISK_EVALUATION_BASE_URL` y
   `PREDICTION_BASE_URL` en `frontend/.env.example`; reportar
   discrepancias sin editar el YAML.
2. Autenticación: localizar `services/riskEvaluation/src/presentation/
   middlewares/authMiddleware.ts`; confirmar `bearerAuth` en paths; no
   modificar.
3. Errores: revisar `errorHandler.ts` y `validation.py`;
   validar que `MessageError` OpenAPI coincida con `{message}` y `errors`.
4. Flutter: leer `frontend/APIM.md` y `frontend/.env.example` para
   validar rutas (`/re/risk-evaluations`, `/predict`), headers
   (`Ocp-Apim-Subscription-Key`) y `dart-define`; no generar código.
5. Pruebas: ejecutar `cd frontend && flutter test --no-pub` y
   `cd services/prediction-ml && python -m pytest -q` solo si se modificaron
   esos archivos; no correr pruebas de otros módulos.

## Reglas
- No editar OpenAPI, `authMiddleware.ts`, `errorHandler.ts` o
  `frontend/APIM.md` sin justificación explícita.
- No añadir dependencias; reportar inconsistencias y pedir confirmación.
