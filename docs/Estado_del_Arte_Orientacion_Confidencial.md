# Estado del Arte: Detección de Urgencias y Triaje de Orientación Confidencial en Salud Mental Universitaria

**Módulo:** M2 — Microservicio de Orientación Confidencial (`orientacion-service`)  
**Contexto institucional:** Unidad de Asesoría y Orientación al Estudiante (UNAYOE) — FISI UNMSM  

---

## 1. Planteamiento del problema y requisitos de privacidad

Los estudiantes universitarios que experimentan malestar emocional, ansiedad académica o social, dificultades económicas o crisis psicológicas agudas requieren canales de orientación confidenciales y asíncronos. A diferencia de los chats públicos o formularios conectados a modelos generativos en la nube, un módulo universitario de orientación confidencial exige:

1. **Privacidad local estricta:** el texto libre redactado por el estudiante no debe enviarse a APIs externas de terceros (como LLMs comerciales) para evitar exposición de datos sensibles de salud.
2. **Detección prioritaria de crisis:** mensajes con ideación suicida, autolesión o riesgo inmediato deben escalarse en milisegundos para mostrar líneas reales de ayuda e informar con prioridad alta al equipo clínico.
3. **Asistencia al triaje humano (Human-in-the-loop):** la clasificación automática debe servir como apoyo al orientador (sugerencia de tema y prioridad), manteniendo siempre la validación final y corrección en manos del profesional humano.

---

## 2. Revisión de literatura científica reciente (2023)

1. **Modelos lineales interpretables (TF-IDF + Regresión Logística) en consejería basada en texto:**  
   Broadbent, M., Medina Grespan, M., Axford, K., Zhang, X., et al. (2023). *A machine learning approach to identifying suicide risk among text-based crisis counseling encounters*. *Frontiers in Psychiatry*, 14, 1110527. DOI: `10.3389/fpsyt.2023.1110527`.  
   - **Hallazgo relevante:** evalúa modelos de procesamiento de lenguaje natural basados en representación *bag-of-words* / TF-IDF y regresión logística frente a clasificadores más complejos sobre conversaciones reales de consejería en crisis, destacando su viabilidad como línea base ligera, auditabilidad por términos discriminativos y bajo costo computacional en entornos con restricciones de latencia y privacidad.

2. **Arquitecturas híbridas en dos etapas (reglas rápidas + ML) para triaje clínico de mensajes:**  
   Swaminathan, A., López, I., Mar, R. A. G., Heist, T., et al. (2023). *Natural language processing system for rapid detection and intervention of mental health crisis chat messages*. *npj Digital Medicine*, 6, Artículo 213. DOI: `10.1038/s41746-023-00951-3`.  
   - **Hallazgo relevante:** demuestra la efectividad operativa de sistemas de detección en tiempo real que combinan detección léxica/heurística de alta prioridad con modelos supervisados para alertar a orientadores humanos en segundos dentro de plataformas de mensajería de salud mental, resaltando la importancia crítica del *recall* en mensajes de crisis y de la supervisión humana.

3. **Revisión sistemática de PNL aplicado a detección de ideación suicida:**  
   Arowosegbe, A., & Oyelade, T. (2023). *Application of Natural Language Processing (NLP) in Detecting and Preventing Suicide Ideation: A Systematic Review*. *International Journal of Environmental Research and Public Health (IJERPH)*, 20(2), 1514. DOI: `10.3390/ijerph20021514`.  
   - **Hallazgo relevante:** revisa estudios de detección de ideación suicida en texto y concluye que las técnicas basadas en TF-IDF con clasificadores supervisados clásicos (como Regresión Logística y SVM) continúan siendo altamente competitivas cuando los conjuntos de datos son acotados, al tiempo que advierte sobre los sesgos de corpus sintéticos o de redes sociales frente a contextos clínicos específicos y la necesidad de validación humana continua.

4. **Factores predictores en población universitaria hispanohablante:**  
   Lázaro-Pérez, C., Munuera Gómez, P., Martínez-López, J. Á., & Gómez-Galán, J. (2023). *Predictive Factors of Suicidal Ideation in Spanish University Students: A Health, Preventive, Social, and Cultural Approach*. *Journal of Clinical Medicine*, 12(3), 1207. DOI: `10.3390/jcm12031207`.  
   - **Hallazgo relevante:** analiza factores asociados a riesgo emocional e ideación suicida en estudiantes universitarios hispanohablantes (estrés académico, problemas familiares, situación económica, apoyo percibido), respaldando la taxonomía temática definida para el triaje inicial (`academico`, `ansiedad_estres`, `economico`, `familiar`, `personal`).

---

## 3. Justificación técnica de la arquitectura adoptada en M2

Con base en la evidencia revisada y las restricciones operativas del proyecto (despliegue ligero en contenedores sin GPU, latencia baja y privacidad local):

| Componente | Decisión técnica en `orientacion-service` | Sustento en la literatura y contexto |
| --- | --- | --- |
| **Primera línea de seguridad** | `UrgenciaDomainService` con normalización Unicode y expresiones regulares compiladas sobre ideación suicida, autolesión y crisis | Arquitectura en dos etapas tipo Swaminathan et al. (2023): garantiza escalado determinista (`prioridad = alta`, `es_urgencia = true`) y entrega inmediata de líneas oficiales (Línea 113 MINSA Opción 5, SAMU 106, PNP 105) sin depender del volumen del corpus de entrenamiento. |
| **Clasificación estadística local** | Pipeline `TfidfVectorizer` (1–2 gramas) + `LogisticRegression(class_weight="balanced")` serializado en `.joblib` (`scikit-learn==1.6.1`) | Modelo ligero, reproducible e interpretable sin dependencias de APIs externas (Broadbent et al., 2023; Arowosegbe & Oyelade, 2023). Se ejecuta 100 % en memoria dentro del microservicio. |
| **Taxonomía y triaje asistido** | 5 temas (`academico`, `ansiedad_estres`, `economico`, `familiar`, `personal`) y 3 prioridades (`alta`, `media`, `baja`) con corrección obligatoria por UNAYOE (`tema_confirmado`, `prioridad_confirmada`) | Alineado con factores universitarios descritos por Lázaro-Pérez et al. (2023) y el principio de *human-in-the-loop* para alimentar futuros ciclos de reentrenamiento real. |

---

## 4. Resultados experimentales del prototipo y brechas identificadas

En la evaluación reproducible ejecutada con `python ml/train_orientacion.py` sobre el corpus sintético prototipo (`ml/data/corpus_orientacion_prototipo.csv`, 250 mensajes, partición estratificada 80/20 con `random_state=42`):

- **Prioridad:** TF-IDF + Regresión Logística obtuvo `Accuracy = 0.6800`, `Macro-F1 = 0.6725` y `Recall(alta) = 0.4375`, superando a la línea base por palabras clave (`Accuracy = 0.4800`, `Macro-F1 = 0.4041`, `Recall(alta) = 0.1875`).
- **Tema:** TF-IDF + Regresión Logística alcanzó `Accuracy = 0.5400` y `Macro-F1 = 0.5446` frente a `Accuracy = 0.7600` y `Macro-F1 = 0.7585` de la línea base léxica.

### Limitaciones abiertas para trabajo futuro

1. El modelo actual es un **prototipo experimental** entrenado sobre 250 mensajes sintéticos; no debe emplearse para diagnóstico clínico automatizado.
2. El *recall* estadístico de prioridad `alta` (`0.4375`) confirma que los clasificadores lineales sobre corpus pequeños no reemplazan a las reglas deterministas de crisis (`UrgenciaDomainService`) ni al criterio del psicólogo.
3. Cuando UNAYOE acumule solicitudes reales anonimizadas y etiquetadas mediante `tema_confirmado` y `prioridad_confirmada`, el mismo script `ml/train_orientacion.py` permitirá reentrenar y calibrar los artefactos sobre datos reales del dominio UNMSM.
