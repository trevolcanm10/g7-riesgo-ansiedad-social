# ESTADO_GIT_EQUIPO

**Módulo:** M1 (Riesgo, ML, Agenda, SHAP)
**Rama actual:** `feature/riesgo-agenda` (renombrada de `denilson-rama`)
**Fecha de la auditoría:** 2026-11-11
**Estado de la auditoría:** Solo lectura / renombrado local

---

## 1. Estado general del repositorio

| Aspecto | Observación |
|---|---|
| Primera verificación de `git status` | Rama `denilson-rama`, commit `e60d570` |
| Rama actual tras renombrado | `feature/riesgo-agenda` (HEAD) |
| Número de commits en la historia | **1** (commit inicial `e60d570`) |
| Línea `main` | `e60d570`, tracking `origin/main` |
| Rama actual vs `main` | **Iguales** (`git merge-base` = `e60d570`, `git diff --stat` vacío) |
| Cambios locales sin commitear | `AGENTS.md` modificado (no staged); `.agents/`, `.cline/`, `.clinerules/` sin trackear |
| Rama remota `denilson-rama` | **No existe** en `origin` |
| Rama remota `feature/riesgo-agenda` | **No existe** |

Verificado mediante: `git status`, `git branch -vv`, `git log`, `git diff`, `git merge-base`.

**Inferido:** Este repositorio es un proyecto de pocas commits por ahora; las ramas de los compañeros contienen el desarrollo real de la funcionalidad.

---

## 2. Tabla de ramas locales y remotas

| Rama | Ruta remota | Último commit | Fecha | Tracking remoto | Estado |
|---|---|---|---|---|---|
| `main` | `origin/main` | `e60d570` | 2026-11-08 | Sí | Semilla |
| `feature/riesgo-agenda` | — | `e60d570` | 2026-11-08 | **No** | Rama local, al día con `main` |
| `origin/feature/citas` | Sí | `2cdd59f` | 2026-11-11 | — | 12 commits por delante de `main` |
| `origin/orientacion-confidencial` | Sí | `eea2dd5` | 2026-11-09 | — | Commit huérfano (sin padre) |

> La vía `git branch -r` solo listaba remotas; la vía `git branch -vv` muestra que `feature/riesgo-agenda` no tiene tracking. Verificado con `git branch -vv`.

---

## 3. Resumen de cambios de cada rama

### 3.1 `origin/main` — commit inicial

- Commit: `e60d570` ("Initial commit - Proyecto Riesgo Ansiedad Social", 2026-11-08).
- Contenido: `.gitignore`, `AGENTS.md`, `package.json`, `package-lock.json`, `frontend/`, `openapi/`, `services/`, `web-demo/`.
- Microservicios en `services/`: `riskEvaluation` (Node/TS), `prediction-ml` (Flask), `users`.
- `openapi/`: **vacío**.
- Verificado mediante `git log`, `git show --stat`, `find`.



### 3.2 `origin/feature/citas` — desarrollo de citas (12 commits)

- Último commit: `2cdd59f` ("fix(citas): una sola petición por acción y éxito aunque falle la recarga", 2026-11-11).
- 12 commits sobre `e60d570` (8 al 11 de noviembre). Historial: `7b5cfb8`, `e7b3de0`, `32a3020`, `13845c4`, `0d3fa16`, `f527867`, `3a5d4cc`, `19dd884`, `b88d88a`, `166f886`, `bd6ec3d`, `2cdd59f`.
- Microservicios involucrados: `services/citas/` (Python, Flask, MySQL, Regresión Logística para predicción de inasistencia).
- Frontend: pantallas Flutter (agenda UNAYOE, agendar cita, mis citas), modelo `cita_model.dart`, `HorariosService`, `ApiService`.
- Docs: `docs/Estado_del_Arte_Inasistencia_Citas.md`.
- Diferencial vs `main`: **59 archivos**, +5034 líneas, −15 líneas (verificado con `git diff --stat`).
- Incluye `services/citas/ml/artifacts/metrics_v1.json` y `no_show_logreg_v1.json` (artefactos de ML).
- Verificado mediante `git log --oneline`, `git diff --stat`, `git show --stat`.

### 3.3 `origin/orientacion-confidencial` — Módulo M2

- Último commit: `eea2dd5` ("feat(orientacion): implement M2 Orientación Confidencial microservice, Flutter UI, and React web view", 2026-11-09).
- **Commit huérfano**: `git log --format='parent=%P'` devolvió padre vacío; `git merge-base main origin/orientacion-confidencial` falló con código 1. **No comparte ancestro con `main`.**
- Microservicios: `services/orientacion-service/` (Dockerfile, `.env.example`, `README.md`, `src/...`), `openapi/orientacion.yaml`.
- Frontend: pantalla y viewmodel de orientación (`orientacion_screen.dart`, `orientacion_viewmodel.dart`).
- Diferencial vs `main`: archivos `.idea/`, `frontend/lib/`, `openapi/orientacion.yaml`, `services/orientacion-service/` (verificado con `git diff --stat`).
- Verificado mediante `git log --format='parent=%P'`, `git show --stat`, `git diff --stat`.



## 4. Comparación de mi rama con `main`

| Comparación | Resultado |
|---|---|
| `git merge-base feature/riesgo-agenda main` | `e60d5700c2b0675be274ded42f7b307015bb5746` |
| `git log main..feature/riesgo-agenda --oneline` | Vacío |
| `git diff feature/riesgo-agenda main --stat` | Vacío |
| `git status` | Solo `AGENTS.md` modificado localmente (no commiteado) |

**Conclusión:** `feature/riesgo-agenda` está al 100% en sincronía con `main`; no hay cambios que aportar de forma aislada de otros módulos. El trabajo de M1 en esta rama es por completo nuevo (archivos a crear).

Verificado mediante `git merge-base`, `git log`, `git diff`.

---


## 6. Avance del proyecto observable en Git

| Recurso | Estado | En `main` | En `feature/riesgo-agenda` | En ramas de compañeros |
|---|---|---|---|---|
| `services/riskEvaluation` (Node/TS) | ✅ | Sí | Sí | No |
| `services/prediction-ml` (Flask) | ✅ | Sí | Sí | No |
| `services/users` (Node/TS) | ✅ | Sí | Sí | No |
| `services/citas` (nuevo) | ❌ | No | No | `origin/feature/citas` |
| `services/orientacion-service` (nuevo) | ❌ | No | No | `origin/orientacion-confidencial` |
| `openapi/` (vacío) | ✅ | No | No | `origin/orientacion-confidencial` → `openapi/orientacion.yaml` |
| Frontend Flutter (citas) | ❌ | Solo estructura base | No | `origin/feature/citas` |
| Frontend Flutter (orientación) | ❌ | No | No | `origin/orientacion-confidencial` |
| Docs de inasistencia | ❌ | No | No | `origin/feature/citas` |

**Conclusión:** el avance observado está restringido a 2 ramas de compañeros. `main` y la rama M1 son solo el commit inicial.

Verificado mediante `find`, `git branch -a`, `git diff --stat`.

---

## 7. Riesgos de integración identificados

| Riesgo | Severidad | Evidencia | Impacto en M1 |
|---|---|---|---|
| **Sin API de rutas compartidas** | Medio | `openapi/` está vacío en `main`, pero existen APIs en `feature/citas` y `orientacion-confidencial` | Si `academic-agenda` define endpoints nuevos, puede chocar con `citas` en `services/`. Conveniente definir en `openapi/` desde el inicio. |
| **Datos de inasistencia vs evaluación de riesgo** | Medio | `services/citas/ml/` predice no-show; `services/riskEvaluation` evaluará riesgo. Podrían compartir modelos de ML | Se recomienda definir límites claros de dominio: `prediction-ml` es de `academic-agenda`; `riskEvaluation` es de M1. |
| **Dependencia de MySQL** | Medio | `services/citas` usa MySQL y tiene tests de integración con TLS | `academic-agenda` debería insatisfactorizarse. Propuesta: SQLite/JSON para desarrollo (en consenso con el equipo). |
| **Historial huérfano** | Bajo | `origin/orientacion-confidencial` no tiene ancestro común | Los merges desde `main` a esa rama no son posibles sin rebase/cherry-pick; no afecta a M1 pero afecta a la integración general del equipo. |
| **Cambios local no commiteados en `AGENTS.md`** | Bajo | `AGENTS.md` modificado en `feature/riesgo-agenda` | No afecta código funcional; el archivo `services/AGENTS.md` queda en la rama. |

**Verificado** mediante `git show --stat`, `git diff --stat`, `git log --format='parent=%P'`, `find`.

---

## 8. Recomendaciones antes de comenzar M1

1. **Configurar tracking remoto** (opcional pero recomendado):
   ```bash
   git push -u origin feature/riesgo-agenda
   ```
   Solo bajo autorización. Si la rama ya existía en el remoto, contactar al propietario y **no eliminar ni reemplazar automáticamente**.

2. **Resolver el archivo `AGENTS.md` modificado localmente**:
   - Es el perfil de M1; mantener la versión modificada respecto al commit inicial.
   - Si se decide commitear, usar `git add AGENTS.md && git commit` (no `git merge`, `git rebase` ni `git push` sin autorización).

3. **No tocar** `services/prediction-ml` y `services/riskEvaluation` (módulos existentes, fuera del alcance de M1 para modificar).

4. **Crear `services/academic-agenda`** nuevo (Python/Flask), siguiendo la arquitectura de `prediction-ml` como referencia.

5. **Definir contratos OpenAPI** desde el inicio si se planean endpoints nuevos compartidos.

6. **No crear commits ni push** hasta recibir la aprobación del equipo.

7. **Verificar pruebas relacionadas** solo de `academic-agenda` (foco en los archivos modificados).

Verificado mediante `git status`, `git branch -vv`, `git log`, `git diff`.

---

### Resumen ejecutivo

- ✅ Rama renombrada localmente a `feature/riesgo-agenda`.
- ✅ Historial preservado (`e60d570`).
- ✅ No se modificó ni se eliminó código funcional.
- ✅ No se hicieron push, no se crearon commits, no se eliminaron ramas.
- ⚠️ `feature/riesgo-agenda` no tiene tracking remoto aún: se necesita autorización para `git push -u origin feature/riesgo-agenda`.
- ⚠️ `openapi/` vacío en `main`; las APIs de `citas` y `orientación` están en ramas separadas.


## 5. Resultado del cambio de nombre de la rama

| Criterio | Resultado |
|---|---|
| Nombre anterior | `denilson-rama` |
| Nombre nuevo | `feature/riesgo-agenda` |
| Cambio local aplicado | ✅ Sí (`git branch -m denilson-rama feature/riesgo-agenda`) |
| Conservación de historial | ✅ Sí: commit `e60d570` sigue siendo HEAD |
| Estado del directorio de trabajo | ✅ Inalterado (mismos archivos modificados y sin trackear) |
| Configuración de tracking remoto | ❌ No configurado (`git branch -vv` no muestra `origin/...` para `feature/riesgo-agenda`) |
| Rama remota `origin/feature/riesgo-agenda` | ❌ No creada (deliberadamente, sin push) |

**Procedimiento de migración seguro (solo si el remoto ya tuviera `denilson-rama`):**
1. `git branch -m denilson-rama feature/riesgo-agenda` (local)
2. `git push -u origin feature/riesgo-agenda` (si no existe en remoto)
3. Si `origin/denilson-rama` existía: `git push origin :denilson-rama` (solo con autorización) y luego `git push -u origin feature/riesgo-agenda`.

Verificado mediante `git branch -vv`, `git log --oneline`, `git status`, `git branch -r`.
