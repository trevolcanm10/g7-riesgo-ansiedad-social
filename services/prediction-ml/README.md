# prediction-ml

Servicio Flask independiente y sin persistencia. Estima riesgo; no produce diagnósticos.
Python 3.12. Dependencias fijadas a las versiones verificadas localmente.

## Reporte Gemini y respaldo

`POST /predict` devuelve exactamente `probabilidad_ansiedad`, `nivel_riesgo`,
`explicacion`, `reporte_ia` y `explicacion_shap`. Este último campo contiene
`estado` (`disponible` o `no_disponible`), escala
`log_odds_riesgo_clase_0` y hasta tres factores con `nombre`, `valor` y
`direccion`; las contribuciones no son porcentajes ni diagnósticos. La
inferencia, las siete features y los umbrales
no cambian. La explicación reutiliza los textos por nivel del proyecto original,
añadiendo que no es diagnóstico clínico. Gemini nunca calcula el riesgo.

El puerto `ReportGenerator` se inyecta en `PredictRiskUseCase`. Su adaptador
`GeminiReportGenerator` usa `google-genai==2.14.0`, importado de forma diferida.
Configurar `GEMINI_API_KEY` y `GEMINI_MODEL` en `services/prediction-ml/.env`.
No hay modelo predeterminado: elegir uno habilitado para la cuenta.
No se guardan evaluaciones ni se registran prompts, claves o respuestas del proveedor.

### Carga de configuracion

`app.py` ejecuta `load_dotenv(Path(__file__).resolve().parent / ".env")` con
`override=False`, antes de construir el adaptador:

- `GEMINI_API_KEY` y `GEMINI_MODEL` se leen de `services/prediction-ml/.env`.
- Las variables ya definidas en el entorno del proceso tienen prioridad;
  el `.env` nunca las sobrescribe.
- `.env` esta ignorado por Git (`.gitignore` de la raiz, linea 2). Usar
  `.env.example` como plantilla; no versionar credenciales reales.
- No se guardan evaluaciones ni se registran prompts, claves o respuestas.

El prompt recuperado del proyecto original pide orientación universitaria,
JSON sin markdown y límites de 5 fortalezas/factores/recomendaciones, 7 acciones
y 3 temas de videos/lectura. Se añaden restricciones de no diagnóstico,
no recalcular riesgo y no inventar circunstancias personales.
Solo se envían los quince indicadores validados y el resultado ML, sin identidad.
Estos indicadores son datos de bienestar enviados a un proveedor externo cuando
se configura Gemini; no se registran prompts, claves, respuestas ni excepciones
del proveedor en logs del adaptador.

Los nueve campos obligatorios del reporte son:
`resumen` (string), `fortalezas` (string[]), `factores_preocupantes` (string[]),
`recomendaciones` (string[]), `plan_7_dias` (string[]), `temas_videos` (string[]),
`temas_lectura` (string[]), `prioridad_intervencion` (string) y
`mensaje_motivacional` (string). Se rechazan campos ausentes/adicionales,
textos vacíos, tipos incorrectos y listas que exceden los límites.
Validar estructura no garantiza la exactitud del contenido generativo.

El esquema enviado a Gemini es \`GEMINI_SCHEMA\`: una \`deepcopy\` de
\`REPORT_SCHEMA\` sin \`additionalProperties\`, porque la API valida
\`response_schema\` contra OpenAPI 3.0 y rechaza esa clave. \`REPORT_SCHEMA\` y
\`validate_report\` permanecen intactos como contrato estricto.

Timeout HTTP del SDK: 15000 ms; reintentos internos deshabilitados.
Máximo dos intentos del adaptador, con pausa de 0.25 s únicamente ante timeout
o HTTP 408/429/500/502/503/504. No reintenta JSON inválido ni errores permanentes.
El presupuesto típico máximo de espera de red es aproximadamente 10.25 s,
además del tiempo de transporte/SDK; no es un plazo global de la petición Flask.

Sin clave/modelo/SDK, ante bloqueo, respuesta inválida o fallo del proveedor,
se responde 200 con la predicción real y un reporte determinista completo.
Su resumen contiene `Reporte determinista de respaldo`, no atribuye fortalezas
ni factores personales y marca prioridad `NO DISPONIBLE`. No es un reporte Gemini.
Los errores de validación (400), modelos ausentes (503), inferencia/internos (500)
y rutas/métodos (404/405) usan `{"error":"Error","mensaje":"Texto comprensible"}`.
`GET /health` conserva su contrato operativo e indica disponibilidad ML, no Gemini.

### Pruebas locales sin API

`python -m unittest discover -s tests -v` usa clientes Gemini simulados.
`python tests/verify_real_http.py` usa los modelos locales y fuerza clave vacía
en el proceso hijo para impedir llamadas Gemini; no almacena evaluaciones.
Verifica el camino de fallback determinista, no la integracion con Gemini.

### Prueba real manual (requiere autorización)

1. Verificar las dependencias de requirements.txt; instalar solo con autorización.
2. Proporcionar GEMINI_API_KEY mediante el gestor de secretos o entorno, sin
   escribirla en código, historial de comandos ni logs; definir GEMINI_MODEL.
3. Ejecutar `python app.py` y enviar example.json a `/predict` con JSON.
4. Verificar los nueve campos y que el resumen no indique respaldo determinista.
   Revisar el contenido: un JSON válido no equivale a orientación clínicamente validada.

RiskEvaluation debe activar su HttpAiPredictionClient (actualmente usa Fake)
y configurar AI_PREDICTION_URL con la URL completa `http://localhost:5001/predict`.
Esos cambios corresponden a su responsable y no forman parte de este servicio.

## Inicio desde Git Bash (raíz del repositorio)

```bash
cd services/prediction-ml
python -m venv .venv
source .venv/Scripts/activate
python -m pip install -r requirements.txt
python app.py
```

Puerto predeterminado 5001; se puede ejecutar `PORT=5002 python app.py`.
El servidor de Flask se utiliza para pruebas locales, con debug desactivado.

## HTTP

- `GET http://localhost:5001/health`: 200 con `service`, `status`, `models_loaded`; 503 si no se cargó XGBoost.
- `POST http://localhost:5001/predict`: Content-Type `application/json`; usar `example.json`.
- Las 15 variables son obligatorias, numéricas, finitas y dentro de los rangos de `src/presentation/validation.py`. Booleanos y cadenas numéricas se rechazan. Campos adicionales se ignoran.
- Entrada inválida: 400 con `error` y `mensaje`. Modelos no disponibles: 503. Error de inferencia: 500. No se exponen detalles internos en la respuesta.

```bash
python -m unittest discover -s tests -v
python tests/verify_real_http.py
curl http://localhost:5001/health
curl -H 'Content-Type: application/json' --data-binary @example.json http://localhost:5001/predict
```

## Arquitectura

`app.py` es la raíz de composición. Conecta el adaptador de salida `XGBoostPredictor` con `PredictRiskUseCase` y el adaptador de entrada Flask.

- Domain: puerto `RiskPredictor`, errores y reglas de categorización; solo biblioteca estándar.
- Application: caso de uso dependiente del puerto, sin bibliotecas ML.
- Infrastructure: `XGBoostPredictor` carga únicamente `xgboost_risk.ubj` con `load_model`, verifica metadatos (clases {0,1}, 7 features, orden contractual, `predict_proba`) y provee explicación SHAP de esa misma predicción (TreeExplainer, top 3 factores, escala log-odds de clase 0).
- Presentation: validación del contrato JSON y traducción HTTP.

SRP separa estas responsabilidades. DIP hace depender el caso de uso de una abstracción. OCP permite reemplazar el predictor al componer la aplicación sin cambiar el caso de uso.

Se construye un DataFrame en orden PHQ9, GAD7, OnlineStress, FinancialStress, ExerciseFreq, SocialActivity, SleepHours. XGBoost localiza clase 0 (riesgo) en `classes_` y devuelve su probabilidad. BAJO < 0.35; MEDIO entre 0.35 y 0.70 inclusive; ALTO > 0.70. SHAP explica la probabilidad de clase 0 con los 3 factores de mayor impacto absoluto. No hay entrenamiento ni integración con usuarios.

## Metadatos y compatibilidad

`models_loaded` reporta 1 (único artefacto XGBoost). El artefacto UBJ conserva los siete nombres de variables y se carga con XGBoost 3.3.0 sin deserializar un pickle.

La conversión desde el artefacto anterior se verificó con el mismo `example.json`: las probabilidades antes y después coincidieron dentro de `1e-7`. Las fallas SHAP conservan la predicción, registran el tipo de excepción sin datos personales y aumentan `shap_failures` en el proceso.

`verify_real_http.py` inicia temporalmente el servicio en el puerto 5001, verifica las tres solicitudes con el modelo real y detiene su proceso; ejecutar con ese puerto libre.

## Evidencia de entrenamiento

No se dispone del conjunto de datos original ni de un conjunto de prueba común para comparar el ensamble anterior, los cinco modelos y XGBoost solo. Por ello **no se afirma superioridad de métricas**. Se eligió XGBoost como único predictor para explicar la predicción activa con `TreeExplainer`; el artefacto se conserva en formato UBJ. Una comparación AUC/recall/F1 requiere recuperar el conjunto original y el protocolo de evaluación, sin inventar resultados.
