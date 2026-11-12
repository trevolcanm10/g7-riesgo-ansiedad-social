---
name: academic-agenda-ml
description: >
  Construir y operar el servicio de agenda académica con clasificación
  semanal (verde/amarillo/rojo), datos sintéticos, comparación vs línea
  base y avisos preventivos.
  ACTIVAR: al implementar CRUD, clasificar semanas, generar datos
  sintéticos, comparar con línea base o añadir avisos.
  NO ACTIVAR: al revisar la ML existente, OpenAPI del prediction-ml,
---

# academic-agenda-ml

## Objetivo
Proporcionar la agenda académica con estado semanal y avisos preventivos,
sin tocar servicios o contratos existentes.

## Flujo
1. Crear aplicación Flask nueva bajo `services/academic-agenda` con:
   - `src/domain/models.py` para `CurricularUnit`, `WeeklyLoad`, `Aviso`;
   - `src/domain/repository.py` con interfaz `AgendaRepository` (contrato
     futuro);
   - `src/application/use_cases.py` con CRUD (`create`, `read`,
     `list_by_user`, `update`, `delete`);
   - `src/infrastructure/repositories.py` con implementación SQLite/JSON
     transitoria (solo para pruebas local);
   - `src/presentation/routes.py` con `POST /agenda`, `GET
     /agenda`, `GET /agenda/<id>`, `PUT /agenda/<id>`, `DELETE
     /agenda/<id>`;
   - `src/presentation/validate.py` con paso de carga 0–10 y avisos;
2. Clasificar carga semanal:
   - `VERDE` 0–39; `AMARILLO` 40–79; `ROJO` 80+;
   - `classify_load(load:int) -> str`.
3. Generar datos sintéticos con `src/infrastructure/synthetic.py`:
   - `generate_synthetic_agenda(user_id, n_weeks=4)` con cargas
     0–100, profesores, cursos y días de semana;
   - NUNCA guardar datos reales del usuario en desarrollo.
4. Comparar con línea base: `baseline = mean(historial anteriores)`;
   si `carga > baseline * 1.2` añadir aviso `AMARILLO`; si
   `carga > baseline * 1.5` aviso `ROJO`.
5. Exponer respuestas JSON consistentes; siempre devolverLista si el
   recurso es colección, objeto si es ítem.
6. No modificar contratos de `risk-evaluation.yaml` ni
   `prediction-ml.yaml` mientras se añade la ruta de agenda.

## Restricciones
- Código solo en `services/academic-agenda` nuevo; no modificar
  `services/riskEvaluation`, `services/prediction-ml`, `users`,
  `frontend`, `openapi`.
- Sin datasets reales, modelos binarios ni credenciales.
- No exponer puntuaciones psicométricas en la respuesta JSON salvo
  el usuario autenticado y solo si la ruta corresponde.
