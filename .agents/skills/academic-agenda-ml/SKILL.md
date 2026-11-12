---
name: academic-agenda-ml
description: Construir el microservicio de agenda académica con clasificación semanal (verde/amarillo/rojo), datos sintéticos, comparación vs línea base y avisos preventivos. ACTIVAR: al implementar CRUD, clasificar cargas, generar datos sintéticos, comparar con línea base o añadir avisos. NO ACTIVAR: al revisar la ML existente, OpenAPI predictions, usuarios o front.
---

# academic-agenda-ml

## Objetivo
Crear `services/academic-agenda` nuevo. No tocar `riskEvaluation`,
`prediction-ml`, `users`, `frontend` ni `openapi`.

## Flujo
1. Aplicación Flask con `src/domain/models.py` (`CurricularUnit`, `WeeklyLoad`, `Aviso`);
   `src/domain/repository.py` (interfaz `AgendaRepository`);
   `src/application/use_cases.py` (CRUD create/read/list_by_user/update/delete);
   `src/infrastructure/repositories.py` (SQLite/JSON transitoria, solo dev);
   `src/presentation/routes.py` (POST/GET/PUT/DELETE `/agenda`).
2. Clasificar carga: `VERDE` 0–39; `AMARILLO` 40–79; `ROJO` ≥ 80;
   función `classify_load(load:int) -> str`.
3. Datos sintéticos: `src/infrastructure/synthetic.py`,
   `generate_synthetic_agenda(user_id, n_weeks=4)`. NUNCA guardar datos reales.
4. Línea base: `baseline = mean(historial)`; si `carga > baseline * 1.2`
   añadir aviso `AMARILLO`; si `> baseline * 1.5` aviso `ROJO`.
5. JSON consistente; colecciones como lista, ítems como objeto.

## Restricciones
- Solo código en `services/academic-agenda` nuevo.
- Sin datasets reales, modelos binarios, credenciales o puntuaciones
  psicométricas expuestas fuera del usuario autenticado.
