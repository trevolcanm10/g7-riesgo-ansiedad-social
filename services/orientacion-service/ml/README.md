# Respaldo de Modelos ML — Orientación Confidencial (M2)

Este directorio contiene el conjunto de datos prototipo y el script reproducible que genera los artefactos serializados utilizados por `ScikitLocalClassifier` en `app/infrastructure/ml/artifacts/`.

## 1. Enfoque híbrido de clasificación y triaje

El microservicio ejecuta inferencia 100 % local (sin llamadas a APIs generativas externas ni envío de texto sensible fuera del servidor) combinando tres mecanismos complementarios:

1. **Reglas heurísticas deterministas de urgencia (`UrgenciaDomainService`)**: normalizan el texto (minúsculas, eliminación de tildes y puntuación) y aplican expresiones regulares compiladas sobre ideación suicida, expresiones indirectas de riesgo vital, autolesión y crisis inmediata. Si hay coincidencia crítica, fuerzan `prioridad_sugerida = "alta"` con `urgencia_detectada = true` e inyectan líneas oficiales de ayuda (`Línea 113 MINSA Opción 5`, `SAMU 106`, `PNP 105` y la lista configurable en `ORIENTACION_HELP_LINES`), independientemente de lo que prediga el modelo ML. Si detectan frustración académica aguda no vital (p. ej. *"no aguanto más este curso de cálculo"*), elevan `prioridad_sugerida = "alta"` sin disparar falsa alarma de riesgo suicida.
2. **Clasificación local híbrida (`ScikitLocalClassifier`)**:
   - **Tema (`tema_sugerido`)**: aplica coincidencia léxica tokenizada primero (dando precedencia clínica a `economico`/`ansiedad_estres` sobre desempates arbitrarios) y usa `TF-IDF (1–2 gramas) + Regresión Logística` como respaldo cuando hay suficiente vocabulario y confianza (`>= 0.40`). Si el mensaje carece de señal temática (saludos cortos como *"hola"* o texto sin vocabulario como *"asdfgh"*), devuelve `tema_sugerido = "sin_clasificar"` en lugar de forzar una clase por sesgo de intercepto.
   - **Prioridad (`prioridad_sugerida`)**: utiliza `TF-IDF (1–2 gramas) + Regresión Logística (class_weight="balanced")` protegido contra vectores vacíos (`nnz == 0` -> `"baja"`) y combinado con señales léxicas explícitas de urgencia.
3. **Human-in-the-loop**: el orientador/psicólogo de UNAYOE confirma o corrige `tema_confirmado` (entre las 5 categorías accionables) y `prioridad_confirmada` al atender la solicitud (`PATCH /api/v1/orientacion/solicitudes/<id>/atender`).

## 2. Corpus prototipo, procedencia y limitaciones

- **Archivo:** `ml/data/corpus_orientacion_prototipo.csv`
- **Tamaño:** 250 mensajes sintéticos en español universitario peruano (50 por tema; 200 entrenamiento / 50 prueba estratificada con `random_state=42`).
- **Procedencia:** Corpus sintético prototipo redactado por el equipo de desarrollo simulando consultas frecuentes de estudiantes universitarios hacia UNAYOE FISI.
- **Limitaciones:**
  - No proviene de historias clínicas ni mensajes reales de estudiantes de la UNMSM.
  - Al tener 250 ejemplos (≈40 de entrenamiento por tema), el vocabulario libre tiene alta dispersión entre particiones, lo que limita el rendimiento de TF-IDF en clases semánticamente cercanas (p. ej. `personal` vs `ansiedad_estres`).
  - **Requisito para uso clínico real:** antes de pasar a operación institucional supervisada, el corpus debe ampliarse y reetiquetarse con datos anonimizados reales validados por psicólogos de UNAYOE, evaluando calibración de umbrales y métricas de sensibilidad clínica.

## 3. Reproducibilidad y versionado de artefactos

### Comando de reentrenamiento

Desde `services/orientacion-service/`:

```bash
python ml/train_orientacion.py
```

### Versiones de entorno verificadas

Los artefactos `modelo_tema.joblib` y `modelo_prioridad.joblib` se entrenan y serializan con las versiones exactas fijadas en `requirements.txt` y registradas en `app/infrastructure/ml/artifacts/metadatos_modelos.json`:

- Python `3.10.8` (compatible con runtime Docker `3.11`)
- `scikit-learn==1.6.1`
- `joblib==1.3.2`
- `numpy==1.26.4`

## 4. Evaluación comparativa frente a línea base

### Validación cruzada estratificada (`StratifiedKFold`, 5 folds, 250 mensajes)

| Tarea | Estrategia | Accuracy | Macro-F1 | Métrica clave adicional |
| --- | --- | :---: | :---: | --- |
| **Tema** (5 clases) | TF-IDF + Regresión Logística (puro) | `0.5320` | `0.5307` | Menor F1 en `ansiedad_estres` (`0.4444`) |
| **Tema** (5 clases) | Línea base palabras clave | `0.6840` | `0.6918` | F1 `familiar` (`0.9495`), `economico` (`0.6835`) |
| **Tema** (5 clases) | **Estrategia híbrida desplegada** | **`0.6960`** | **`0.6920`** | Combina precisión léxica + respaldo TF-IDF out-of-fold |
| **Prioridad** (3 clases) | **TF-IDF + Regresión Logística** | **`0.6920`** | **`0.6923`** | Recall `alta`: **`0.4691`** (F1 `alta`: `0.5278`) |
| **Prioridad** (3 clases) | Línea base palabras clave | `0.4320` | `0.3359` | Recall `alta`: `0.1235` (F1 `alta`: `0.2128`) |

### Referencia en conjunto de prueba (`test_size = 0.2`, 50 mensajes, `random_state = 42`)

| Tarea | Modelo / Línea base | Accuracy | Macro-F1 | Métrica clave adicional |
| --- | --- | :---: | :---: | --- |
| **Tema** (5 clases) | TF-IDF + Regresión Logística | `0.5400` | `0.5446` | Mejor F1 en `economico` (`0.8421`) |
| **Tema** (5 clases) | Línea base palabras clave | `0.7800` | `0.7832` | F1 `familiar` (`1.0000`), `economico` (`0.8235`) |
| **Prioridad** (3 clases) | TF-IDF + Regresión Logística | `0.6800` | `0.6725` | Recall `alta`: **`0.4375`** (F1 `alta`: `0.5385`) |
| **Prioridad** (3 clases) | Línea base palabras clave | `0.4800` | `0.4041` | Recall `alta`: `0.1875` (F1 `alta`: `0.3158`) |

### Interpretación técnica y justificación de diseño

- En **prioridad**, TF-IDF + Regresión Logística supera consistentemente a las reglas léxicas simples en validación cruzada de 5 folds (`Macro-F1 0.6923` vs `0.3359`, y casi cuatro veces más *recall* en prioridad `alta`: `0.4691` vs `0.1235`), capturando expresiones graduales de malestar sin depender únicamente de palabras clave rígidas.
- No obstante, un *recall* de `0.4691` en prioridad `alta` usando solo un modelo lineal sobre 250 ejemplos **es insuficiente por sí solo para seguridad del paciente**, lo cual justifica mantener `UrgenciaDomainService` como primera barrera determinista de alta sensibilidad para crisis e ideación autolesiva, además de la revisión obligatoria por el equipo UNAYOE.
- En **tema**, la validación cruzada 5-fold confirma que el clasificador puramente estadístico (`Macro-F1 0.5307`) rinde por debajo de las reglas léxicas (`0.6918`) y comete desempates ruidosos (como asignar `familiar` a mensajes explícitos de ansiedad por exámenes). Por ello se adopta explícitamente una **estrategia híbrida en producción** (`Macro-F1 0.6920` en 5-fold CV): reglas tokenizadas primero, respaldo TF-IDF con umbral de confianza y etiqueta `sin_clasificar` cuando el mensaje carece de señal; conforme se incorporen mensajes reales validados mediante `tema_confirmado`, se podrá reevaluar la transición a un modelo estadístico puro.
