# CONTEXTO_TECNICO_DENILSON_M1

Auditoría técnica exclusiva del módulo M1 - Proyecto Taller_Social
Rama: `feature/riesgo-agenda` (publicada en GitHub)
Autor: Denilson Morales (Arquitecto M1)
Fecha: 11/11/2026
Modo: solo lectura + creación del informe solicitado

---

## 1. Resumen ejecutivo

El módulo M1 (Evaluación y Riesgo de Ansiedad Social) está sustancialmente implementado en sus dos servicios base, pero le faltan los componentes que le dan valor diferenciador: explicabilidad SHAP, historial gráfico y la Agenda Académica.

- `services/riskEvaluation` (Node.js/TypeScript/Express): implementado y funcional. Endpoints de creación de evaluación y historial propio, persistencia MySQL, autenticación JWT por rol, integración HTTP con `prediction-ml`.
- `services/prediction-ml` (Python/Flask): implementado. Ensamble de 5 modelos (CatBoost, KNN, LightGBM, RandomForest, XGBoost) cargados desde `.pkl`, generador de reporte IA con Gemini y fallback determinista. No hay SHAP.
- `services/academic-agenda`: no existe. Debe construirse desde cero.
- Frontend Flutter: pantallas de evaluación, resultado e historial implementadas con `provider`. Faltan pantallas de SHAP y Agenda Académica, y gráficas de historial.

Estado general: **funcional base, pendientes de completarse SHAP y Agenda Académica**.

---

## 2. Arquitectura real

### 2.1 Servicios de M1

| Servicio | Tecnología | Puerto | Responsabilidad |
|---|---|---|---|
| `riskEvaluation` | Node.js/TypeScript/Express | 3002 | Evaluación de riesgo, historial, MySQL |
| `prediction-ml` | Python/Flask | 5001 | Ensamble ML, reporte IA (Gemini/fallback) |
| `users` | Node.js/TypeScript/Express | (otro integrante) | No tocar |

### 2.2 Patrones y capas (riskEvaluation)
Clean Architecture con capas:
- `src/domain/entities/`: `RiskEvaluation`, `RiskLevel` (`BAJO|MEDIO|ALTO`), `AIReport`, `RiskRecommendation`.
- `src/domain/repositories/`: interfaces `RiskEvaluationRepository`, `RiskRecommendationRepository`.
- `src/application/useCases/`: `CreateRiskEvaluation`, `GetRiskEvaluationHistory`.
- `src/application/clients/`: `AiPredictionClient` (interfaz) para llamar a `prediction-ml`.
- `src/infrastructure/`: `MySqlRiskEvaluationRepository`, `MySqlRiskRecommendationRepository`, `HttpAiPredictionClient`, `FakeAiPredictionClient`, `JwtTokenService`.
- `src/presentation/`: controladores, rutas, middlewares (auth, role, errorHandler, logging), DTOs con Zod.

Configuración: `src/config/config.ts` lee `DB_*`, `JWT_SECRET`, `AI_PREDICTION_URL` via `dotenv`. `src/config/database.ts` crea un pool `mysql2/promise` con SSL (`rejectUnauthorized: false`). No hay `docker-compose` ni `Dockerfile` en la raíz.

### 2.3 Predicción ML
`EnsemblePredictor` carga 5 modelos `.pkl` con `joblib`. Características del ensamble (`FEATURES`): `PHQ9, GAD7, OnlineStress, FinancialStress, ExerciseFreq, SocialActivity, SleepHours` (7). El `PredictionRequest` del contrato valida 15 indicadores, pero el ensamble solo usa 7; los otros 8 se validan y envían pero no influyen en la probabilidad. Niveles de riesgo: `BAJO < 0.35`, `MEDIO 0.35-0.70`, `ALTO > 0.70` (`categorize_risk`).

Reporte IA: `GeminiReportGenerator` (llama a Gemini con `response_schema`) con `FallbackReportGenerator` determinista si no hay `GEMINI_API_KEY`.

### 2.4 Frontend Flutter
Estado con `provider` (`EvaluacionViewModel`, `AuthViewModel`). Cliente HTTP `ApiService` con bearer token, timeout 60s, soporte Azure APIM (`Ocp-Apim-Subscription-Key`). Navegación por rutas nombradas. Pantallas M1: `evaluacion_screen`, `resultado_screen`, `historial_screen`. No hay `academic-agenda` ni pantallas SHAP.

---

## 3. Estado de Evaluación y Riesgo (`services/riskEvaluation`)

### 3.1 Endpoints reales y métodos HTTP

| Endpoint | Método | Descripción | Auth | Rol |
|---|---|---|---|---|
| `/risk-evaluations/` | POST | Crear evaluación (llama a prediction-ml y guarda) | Bearer JWT | ESTUDIANTE, ADMINISTRADOR |
| `/risk-evaluations/me/history` | GET | Historial propio (más reciente primero) | Bearer JWT | ESTUDIANTE, ADMINISTRADOR |
| `/health` | GET | Estado servicio + MySQL | No | - |
| `/test-error-500` | GET | Endpoint de prueba de métrica 500 | No | - |

### 3.2 Flujo de registro de evaluaciones
1. `RiskEvaluationController.create` valida el cuerpo con `createRiskEvaluationSchema` (Zod; 15 campos, rangos).
2. `CreateRiskEvaluation.execute` llama a `aiPredictionClient.predict(...)` (HTTP POST a `AI_PREDICTION_URL/predict`).
3. Busca `RiskRecommendation` por `riskLevel` en `risk_recommendations`.
4. Construye `RiskEvaluation` con los 15 indicadores + resultados de predicción.
5. Guarda en `risk_evaluations` (MySQL) con `ai_report` como JSON y `risk_recommendation_id` FK.

### 3.3 Persistencia y modelos de datos
Tablas MySQL (inferidas del código): `risk_evaluations` y `risk_recommendations`. `risk_evaluations` almacena los 15 indicadores, `anxiety_probability`, `risk_level`, `explanation`, `ai_report` (JSON), `created_at` y FK `risk_recommendation_id`. `findByUserId` ordena por `created_at DESC`.

### 3.4 Historial de evaluaciones
`GET /risk-evaluations/me/history` devuelve lista de `RiskEvaluation` (id, userId, anxietyProbability, riskLevel, explanation, recommendations, aiReport, createdAt). El frontend `HistorialScreen` los muestra como lista con icono de nivel y probabilidad. **No hay gráficas ni series temporales.**

### 3.5 Integración con Predicción ML
`HttpAiPredictionClient` hace `POST ${AI_PREDICTION_URL}/predict` mapeando campos camelCase del DTO a snake_case de la API ML. Mapea `reporte_ia` (snake_case) a `AIReport` (camelCase). Existe `FakeAiPredictionClient` para pruebas sin servicio ML. No hay reintentos ni circuit breaker; si `prediction-ml` cae, la creación de evaluación falla.

### 3.6 Autenticación y autorización
`authMiddleware` verifica `Bearer` JWT via `JwtTokenService.verifyAccessToken` y setea `req.userId` / `req.userRole`. `roleMiddleware` restringe a `ESTUDIANTE` y `ADMINISTRADOR`. El servicio `users` (otro integrante) emite los tokens; no se inspeccionó.

### 3.7 Pruebas existentes
**No hay carpeta de pruebas en `services/riskEvaluation`** (ni `__tests__` ni `test`). No hay unit tests ni integration tests del servicio.

### 3.8 Funcionalidades pendientes para M1 (riskEvaluation)
- SHAP / explicabilidad por evaluación.
- Endpoint de estadísticas/agregados (semáforo de carga).
- Pruebas automatizadas.

---

## 4. Estado de Predicción ML (`services/prediction-ml`)

### 4.1 Modelos realmente utilizados
Cinco modelos binarios en `src/infrastructure/models/`:
`catboost_weighted_model.pkl`, `knn_model.pkl`, `lightgbm_model.pkl`, `random_forest_model.pkl`, `xgboost_weighted_model.pkl`.
Todos cargan con `joblib`; se valida que tengan `predict_proba`, 2 clases `{0,1}` y el orden de features contractual.

### 4.2 Variables de entrada y orden
`INDICATORS` (15, snake_case, orden contractual):
`phq9_score, gad7_score, online_stress, financial_stress, exercise_freq, social_activity, sleep_hours, gpa, family_support, screen_time, academic_stress, diet_quality, self_efficacy, peer_relationship, sleep_quality`.

El `FEATURES` del ensamble usa solo 7: `PHQ9, GAD7, OnlineStress, FinancialStress, ExerciseFreq, SocialActivity, SleepHours`. Los otros 8 se validan en `validation.py` pero **no influyen** en la probabilidad.

### 4.3 Preprocesamiento y ensamble
Sin escalado ni codificación adicional; se arman en un `pd.DataFrame` con el orden de `FEATURES`. Cada modelo devuelve `predict_proba` para la clase 0 (riesgo); `predict_probability` retorna el **promedio aritmético** de las 5 probabilidades.

### 4.4 Cálculo de probabilidades y niveles
`categorize_risk`: `BAJO < 0.35`, `MEDIO <= 0.70`, `ALTO > 0.70`. Respuesta:
`{ nivel_riesgo, probabilidad_ansiedad, explicacion, reporte_ia }`.

### 4.5 Endpoints y estructura de respuesta
- `POST /predict`: cuerpo `PredictionRequest` (15 indicadores); respuesta `PredictionResponse` + `AIReport` (resumen, fortalezas, factores_preocupantes, recomendaciones, plan_7_dias, temas_videos, temas_lectura, prioridad_intervencion, mensaje_motivacional).
- `GET /health`: `{ service, status, models_loaded }` (5 modelos).

### 4.6 Integración con Gemini y respaldo
`GeminiReportGenerator` llama a `genai.Client.models.generate_content` con `response_schema` y 2 reintentos ante errores transitorios. Si falta `GEMINI_API_KEY`/`GEMINI_MODEL` o falla, usa `FallbackReportGenerator` (reporte determinista, textos estáticos). No se registran claves ni prompts.

### 4.7 SHAP
**No existe SHAP.** No hay importes de `shap`, ni explainers, ni endpoint de explicabilidad. Para incorporarlo habría que añadir la librería `shap`, crear explainers por modelo (TreeExplainer para los basados en árbol, KernelExplainer/otro para KNN), añadir un endpoint `/explain` y adaptar el frontend. Los modelos `.pkl` ya están cargados en memoria, lo cual facilita el acceso a los estimadores subyacentes.

### 4.8 Archivos que necesitarían modificaciones para SHAP
- `services/prediction-ml/src/infrastructure/ensemble_predictor.py` (exponer modelos/estimadores).
- `services/prediction-ml/src/application/predict_risk.py` (nuevo caso de uso `/explain`).
- `services/prediction-ml/src/presentation/http.py` (nueva ruta).
- `services/prediction-ml/src/domain/risk.py` (utilidades de explicabilidad).
- `openapi/prediction-ml.yaml` (nuevo contrato).

### 4.9 Métricas existentes
`app.py` reporta `models_loaded` en `/health`. `riskEvaluation` tiene `/test-error-500` para métrica. No hay documentación de precisión, recall, F1 ni AUC de los modelos, ni proceso de entrenamiento versionado. No se debe cargar ni entrenar los `.pkl` (restricción).

---

## 5. Posibilidades de implementación de SHAP

- **Factible**: los 5 modelos ya están instanciados en `EnsemblePredictor._models`; se puede acceder a `model` y extraer importancias/valores SHAP.
- **Desafío KNN**: KNN no tiene estructura de árbol; requiere `KernelExplainer` (más lento) o aproximaciones.
- **Ensamble**: SHAP por modelo habría que agregarlo (promedio ponderado) para tener una explicabilidad global consistente con la probabilidad del ensamble.
- **Endpoint**: agregar `GET/POST /predict/{id}/explain` o `/explain` que devuelva aportaciones por feature.
- **Frontend**: pantalla nueva que consuma el endpoint y muestre barras de contribución por variable.
- **Privacidad**: SHAP no debe exponer puntuaciones psicológicas fuera del usuario autenticado.

---

## 6. Historial de evaluaciones

Implementado en `riskEvaluation`:
- Backend: `GET /risk-evaluations/me/history` (autenticado, rol ESTUDIANTE/ADMINISTRADOR), orden descendente por `created_at`.
- Repositorio: `findByUserId` con JOIN a `risk_recommendations`.
- Frontend: `HistorialScreen` + `ObtenerHistorialUseCase` + `EvaluacionRemoteDataSource.obtenerHistorial()` + `EvaluacionViewModel.obtenerHistorial()`. Muestra nivel (icono verde/amarillo/rojo) y probabilidad.
- **Pendiente**: gráficas/series temporales, exportación, filtrado por fecha, semáforo histórico.

---

## 7. Estado del frontend Flutter (`frontend/`)

### 7.1 Pantallas M1 implementadas
- `presentation/pages/evaluacion/evaluacion_screen.dart`: formulario multipaso con las 15 variables (escalas 0-10, chips de días).
- `presentation/pages/evaluacion/resultado_screen.dart`: indicador de riesgo, explicación IA, recomendaciones, reporte IA (fortalezas, factores, plan 7 días), enlaces de bienestar.
- `presentation/pages/evaluacion/historial_screen.dart`: lista de evaluaciones con nivel y probabilidad.

### 7.2 Gestión del estado
`provider` (`ChangeNotifier`): `EvaluacionViewModel` (probabilidad, nivelRiesgo, explicacion, recomendaciones, historial, ultimoResultado) y `AuthViewModel`. `limpiarSesion` invalida versión de sesión.

### 7.3 Cliente HTTP
`ApiService` (`data/datasources/remote/api_service.dart`): GET/POST/PUT/DELETE con bearer token, timeout 60s, manejo de 401 (invalida sesión y notifica `onUnauthorized`), soporte APIM (clave de suscripción solo si host coincide y es HTTPS). `ApiException` expone `apimRequestId` para correlación.

### 7.4 Navegación
Rutas nombradas (`/home`, `/login`, etc.). `ResultadoScreen` usa `Navigator.pushNamedAndRemoveUntil('/home', ...)`.

### 7.5 Pantallas pendientes para M1
- Pantalla de explicabilidad SHAP (no existe).
- Pantallas de Agenda Académica: CRUD de actividades, calendario, lista, semáforo de carga, avisos preventivos (no existen).
- Gráficas en historial (no existen).

---

## 8. Diseño preliminar de Agenda Académica

No existe servicio ni código reutilizable. Componentes a construir (sin tocar `riskEvaluation`, `prediction-ml`, `users` ni contratos OpenAPI existentes):

### 8.1 Servicio backend (`services/academic-agenda`, Flask nuevo)
- CRUD de actividades académicas (crear, leer, actualizar, eliminar) asociadas al usuario autenticado.
- Endpoints: listado (calendario/lista), detalle, crear, actualizar, eliminar, salud.
- Clasificador de carga semanal: suma horas/creditos por semana y devuelve semáforo (verde/amarillo/rojo).
- Avisos preventivos: notificaciones cuando la carga cruza umbrales.
- Persistencia MySQL independiente (base/usuario propios; no tocar esquema de `riskEvaluation`).
- Contrato OpenAPI: `openapi/academic-agenda.yaml`.
- Autenticación: reusar validación de JWT (misma `JWT_SECRET` que `riskEvaluation`) o delegar en `users`; no duplicar lógica de login.

### 8.2 Integración Flutter
- Nuevas pantallas: lista de actividades, calendario, formulario CRUD, indicador semáforo.
- ViewModel y UseCases siguiendo el patrón existente (`provider`).
- Cliente HTTP `ApiService` ya soporta bearer y APIM; reutilizar.

---

## 9. Endpoints existentes (resumen)

**riskEvaluation** (`https://g7-riesgo-ansiedad-risk-evaluations.onrender.com` / local 3002):
- `POST /risk-evaluations/`
- `GET /risk-evaluations/me/history`
- `GET /health`

**prediction-ml** (`https://g7-riesgo-ansiedad-prediction.onrender.com` / local 5001):
- `POST /predict`
- `GET /health`

**users**: no inspeccionado (per AGENTS.md / clinerules).

---

## 10. Pruebas disponibles

- `services/prediction-ml/tests/`: `test_prediction.py`, `test_report.py`, `verify_real_http.py`.
- `frontend/test/`: 12 archivos Dart (`risk_evaluation_contract_test.dart`, `evaluation_form_test.dart`, `apim_configuration_test.dart`, `session_*.dart`, etc.).
- `services/riskEvaluation/`: **sin pruebas**.
- No se ejecutaron pruebas que alteren datos (restricción).

---

## 11. Funcionalidades pendientes

1. SHAP / explicabilidad (prediction-ml + frontend).
2. Agenda Académica completa (servicio, OpenAPI, MySQL, Flutter).
3. Gráficas/series temporales del historial.
4. Pruebas automatizadas de `riskEvaluation`.
5. Circuit breaker / reintentos en `HttpAiPredictionClient`.
6. Documentación de métricas de los modelos ML.

---

## 12. Riesgos técnicos

- **Ensamble usa solo 7 de 15 indicadores**: 8 variables validadas no afectan la probabilidad; puede generar expectativa incorrecta en el frontend.
- **Sin SHAP**: no hay explicabilidad por feature; requisito pendiente de Denilson.
- **Dependencia sincrónica**: `riskEvaluation` falla si `prediction-ml` no responde (sin reintentos ni fallback en el cliente HTTP).
- **Modelos `.pkl` en repositorio**: archivos binarios de modelos versionados; restricción de no entrenar/cargar.
- **Falta `academic-agenda`**: servicio nuevo desde cero; riesgo de desalineación de schemas y autenticación con `users`.
- **No hay Docker Compose**: despliegue local multi-servicio no documentado.
- **No hay pruebas en `riskEvaluation`**: riesgo de regresiones al agregar SHAP o agenda.
- **JWT compartido**: `academic-agenda` debe reusar `JWT_SECRET` sin acoplarse al servicio `users`.

---

## 13. Orden recomendado de implementación

1. Crear `services/academic-agenda` (Flask) con CRUD, MySQL independiente y OpenAPI.
2. Agregar autenticación JWT (reusar secreto) y endpoint de semáforo de carga.
3. Integrar Agenda Académica en Flutter (pantallas, ViewModel, reutilizar `ApiService`).
4. Implementar SHAP en `prediction-ml` (nuevo endpoint `/explain`, `shap`).
5. Agregar pantallas de SHAP y gráficas de historial en Flutter.
6. Añadir pruebas a `riskEvaluation` y circuit breaker en `HttpAiPredictionClient`.

---

## 14. Archivos prioritarios para modificar

- `services/academic-agenda/` (nuevo): app, rutas, modelos, repositorio MySQL, OpenAPI.
- `services/prediction-ml/src/infrastructure/ensemble_predictor.py` (SHAP: exponer estimadores).
- `services/prediction-ml/src/presentation/http.py` (SHAP: ruta `/explain`).
- `services/prediction-ml/src/application/predict_risk.py` (SHAP: caso de uso explicabilidad).
- `services/riskEvaluation/src/infrastructure/clients/HttpAiPredictionClient.ts` (reintentos/circuit breaker).
- `openapi/academic-agenda.yaml` (nuevo contrato).
- `openapi/prediction-ml.yaml` (agregar endpoint SHAP).
- `frontend/lib/presentation/pages/`: pantallas SHAP y Agenda Académica (nuevas).
- `frontend/lib/presentation/viewmodels/`: viewmodels de agenda y SHAP (nuevos).

---

*Informe generado en modo solo lectura; se creó el archivo solicitado. No se modificó código fuente, ni se hicieron commits, ni se entrenaron modelos. Rutas verificadas contra el estado real de la rama `feature/riesgo-agenda`.
