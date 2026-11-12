---
name: microservices-quality
description: >
  Revisar contratos OpenAPI, autenticación, manejo de errores, pruebas y
  integración Flutter del módulo M1 (riesgo + predicción).
  ACTIVAR: al revisar/exponer OpenAPI, comprobar middleware de error,
  validar token en routes, revisar tests de Flutter.
  NO ACTIVAR: al implementar funcionalidad de ML o agenda; solo revisión
  de calidad de integración.
# microservices-quality

## Objetivo
Garantizar que M1 (riesgo + predicción + agenda futura) mantiene
contratos OpenAPI, auth y errores consistentes para Flutter.

## Flujo
1. Contratos: leer `openapi/risk-evaluation.yaml` y
   `openapi/prediction-ml.yaml`;
   verificar que paths y schemas de `RISK_EVALUATION_BASE_URL` y
   `PREDICTION_BASE_URL` en `frontend/.env.example` coinciden;
   reportar discrepancias sin cambiarlos. No editar YAML mientras se
   revisa.
2. Autenticación: localiza `services/riskEvaluation/src/presentation/
   middlewares/authMiddleware.ts` y revisa que `bearerAuth` esté en
   paths API; no modificar.
3. Errores: revisa `errorHandler.ts` y `validation.py` de prediction;
   confirmar que `MessageError` en OpenAPI coincida con respuesta
   `{message}` y `errors` opcional; no modificar código.
4. Flutter: lee `frontend/APIM.md` y `frontend/.env.example` para
   confirmar rutas (`/re/risk-evaluations`, `/predict`), headers
   (`Ocp-Apim-Subscription-Key`) y `dart-define`;
   no generar código Flutter nuevo.
5. Pruebas: ejecuta `cd frontend && flutter test --no-pub` y
   `cd services/prediction-ml && python -m pytest -q`
   solo si se modificaron esos archivos; no correr pruebas de otros
   módulos.

## Reglas
- No editar OpenAPI, `authMiddleware.ts`, `errorHandler.ts` o
  `frontend/APIM.md` sin justificación explícita.
- No añadir dependencias o servicios nuevos dentro de esta skill.
- Si detectas un contrato inconsistente, relájalo en el output y
  solicita confirmación antes de cambiarlo.
