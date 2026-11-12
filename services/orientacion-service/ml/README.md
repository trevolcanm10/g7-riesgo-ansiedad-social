# Respaldo de Modelos ML — Orientación Confidencial (M2)

Este directorio contiene el conjunto de datos prototipo y el script reproducible que genera los artefactos serializados utilizados por `ScikitLocalClassifier` en `app/infrastructure/ml/artifacts/`.

## 1. Enfoque híbrido de clasificación y triaje

El microservicio ejecuta inferencia 100 % local (sin llamadas a APIs generativas externas ni envío de texto sensible fuera del servidor) combinando tres mecanismos complementarios:

1. **Reglas heurísticas deterministas de urgencia (`UrgenciaDomainService`)**: normalizan el texto (minúsculas, eliminación de tildes y puntuación) y aplican expresiones regulares compiladas sobre ideación suicida, autolesión y crisis inmediata. Si hay coincidencia, fuerzan `prioridad_sugerida = "alta"` con `es_urgencia = true` e inyectan líneas oficiales de ayuda (`Línea 113 MINSA Opción 5`, `SAMU 106`, `PNP 105` y la lista configurable en `ORIENTACION_HELP_LINES`), independientemente de lo que prediga el modelo ML.
2. **Clasificación local con TF-IDF (1–2 gramas) + Regresión Logística (`class_weight="balanced"`)**: sugiere `tema_sugerido` (`academico`, `ansiedad_estres`, `economico`, `familiar`, `personal`) y `prioridad_sugerida` (`alta`, `media`, `baja`) cuando el caso no es atrapado por reglas de crisis crítica.
3. **Human-in-the-loop**: el orientador/psicólogo de UNAYOE confirma o corrige `tema_confirmado` y `prioridad_confirmada` al atender la solicitud (`PATCH /api/v1/orientacion/solicitudes/<id>/atender`).

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

Sobre el conjunto de prueba (`test_size = 0.2`, 50 mensajes, `random_state = 42`), se comparó el pipeline TF-IDF + Regresión Logística contra la línea base determinista por palabras clave (`ScikitLocalClassifier._fallback_*`):

| Tarea | Modelo / Línea base | Accuracy | Macro-F1 | Métrica clave adicional |
| --- | --- | :---: | :---: | --- |
| **Tema** (5 clases) | TF-IDF + Regresión Logística | `0.5400` | `0.5446` | Mejor F1 en `economico` (`0.8421`) |
| **Tema** (5 clases) | Línea base palabras clave | `0.7600` | `0.7585` | F1 `familiar` (`0.9474`), `economico` (`0.8571`) |
| **Prioridad** (3 clases) | TF-IDF + Regresión Logística | `0.6800` | `0.6725` | Recall `alta`: **`0.4375`** (F1 `alta`: `0.5385`) |
| **Prioridad** (3 clases) | Línea base palabras clave | `0.4800` | `0.4041` | Recall `alta`: `0.1875` (F1 `alta`: `0.3158`) |

### Interpretación técnica

- En **prioridad**, TF-IDF + Regresión Logística supera ampliamente a las reglas léxicas simples (`Macro-F1 0.6725` vs `0.4041`, y más del doble de *recall* en prioridad `alta`: `0.4375` vs `0.1875`), capturando expresiones graduales de malestar sin depender únicamente de palabras clave rígidas.
- No obstante, un *recall* de `0.4375` en prioridad `alta` usando solo un modelo lineal sobre 200 ejemplos **es insuficiente por sí solo para seguridad del paciente**, lo cual justifica arquitectónicamente mantener `UrgenciaDomainService` como primera barrera determinista de alta sensibilidad para crisis e ideación autolesiva, además de la revisión obligatoria por el equipo UNAYOE.
- En **tema**, con 200 muestras de entrenamiento, la línea base léxica (`Macro-F1 0.7585`) supera actualmente al modelo estadístico (`0.5446`) por el tamaño reducido y alta especificidad léxica del corpus sintético; conforme se incorporen solicitudes reales anonimizadas confirmadas mediante `tema_confirmado`, la brecha estadística se revertirá con el mismo flujo de reentrenamiento.
