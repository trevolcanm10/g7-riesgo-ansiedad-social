# Resumen de entrega — Módulo 4: Panel Institucional y Analítica

**Autor de la rama:** `feature/panel-gerardo`
**Commit:** `8da6b8d` — *feat(panel): Modulo 4 Panel Institucional y Analitica*
**Alcance:** 112 archivos · +14 890 líneas · 1 borrado
**Remoto:** https://github.com/trevolcanm10/g7-riesgo-ansiedad-social

> **Guía paso a paso de instalación, ejecución, verificación y publicación:**
> [`README_MODULO_4.md`](README_MODULO_4.md)
> Este documento es el **resumen de qué se entregó y cómo se verificó**.

---

## 1. Qué se entregó, en una tabla

| Pieza | Ubicación | Estado |
|---|---|---|
| Microservicio backend (Flask) | `services/panel-service/` | ✅ 68 archivos, 5 capas, 5 puertos, 5 casos de uso |
| Frontend web (React) | `web-panel/frontend/` | ✅ 28 archivos, 6 rutas, 5 pantallas |
| Modelo de agrupamiento (K-Means) | `services/panel-service/ml/` | ✅ k=8, evaluado y exportado |
| Especificación OpenAPI | `openapi/panel.yaml` | ✅ 5 paths, 11 schemas |
| Extensión de `users` | `services/users/src/` | ✅ +1 endpoint (`by-code`) |
| Extensión de `riskEvaluation` | `services/riskEvaluation/src/` | ✅ +1 endpoint (`summary`) |
| Documentación | `README_MODULO_4.md` + READMEs internos | ✅ 16 secciones |

---

## 2. Fase 1 — Frontend institucional (React)

**Contenedor base**

| Requisito | Implementación |
|---|---|
| Layout con barra lateral | `src/app/AppShell.tsx` — `<aside>` fijo en escritorio, cajón en móvil (`lg:hidden`), `NavLink` con estado activo |
| Rutas estáticas | `src/app/navigation.ts` — 6 entradas centralizadas |
| Rutas preparadas | `/orientacion`, `/citas`, `/agenda` → `src/pages/Preparada.tsx`, listas para que otros microservicios conecten pantallas |
| Protección de sesión | `src/app/RutaProtegida.tsx` + `src/app/AuthContext.tsx` (token en memoria + `sessionStorage`, nunca la contraseña) |

**Pantallas del Módulo 4**

| Pantalla | Archivo | Qué hace |
|---|---|---|
| Login genérico | `src/pages/Login.tsx` | Valida en cliente, foco al primer error, `aria-invalid` / `aria-describedby` |
| Registro único | `src/pages/RegistroAtencion.tsx` | Datos de la atención + los 7 indicadores con sus rangos, distintivo «Opcionales» → «Perfil asignable» |
| Dashboard analítico | `src/pages/Dashboard.tsx` | 4 KPIs, barras, anillo SVG, tabla de perfiles de IA con **% del total** y **columna de riesgo** |
| Informes | `src/pages/Informes.tsx` | Selector de mes + descarga del CSV |

**Decisiones técnicas**

- **Sin librería de gráficos.** Los indicadores se dibujan con SVG/CSS a mano (`src/components/Graficos.tsx`), igual que la app Flutter.
- **Tailwind v4 con `@theme`** en `src/styles.css`, replicando la paleta de `web-demo` (`#0b456d`, `#13765f`, `#5b6c80`, `#e2e8ed`) para coherencia visual entre aplicaciones.
- **Ruta de login corregida** a `/u/users`, que es la ruta **confirmada por el equipo** (`frontend/APIM.md`). La convención de `web-demo` (`/users/users`) no coincidía.
- **Cliente HTTP con guardas de seguridad** (`src/services/api.ts`): rechaza hosts que no sean HTTPS `*.azure-api.net` y aborta si falta la clave, para que la clave de suscripción nunca salga del gateway.

---

## 3. Fase 2 — Microservicio backend (Flask)

**Arquitectura limpia** — `services/panel-service/app/`

```
domain/          Sin dependencias de frameworks. Entidades y reglas de negocio.
  entities/      Atencion, PerfilCluster
  services/      privacidad_k5 (la regla k=5), fecha_hora (UTC)

application/     Casos de uso y puertos (interfaces). No conoce SQLAlchemy.
  interfaces/    5 puertos: IAtencionRepository, IClusteringPort,
                 IEvaluacionesRiesgoPort, IPersonalExternoPort, IUsuariosPort
  use_cases/     RegistrarAtencion, ListarAtenciones, ObtenerEstadisticas,
                 ObtenerRiesgoPorPerfil, GenerarInforme

infrastructure/  Adaptadores concretos
  persistence/   SQLAlchemy: db_models.py + atencion_repository.py
  ml/            clustering_adapter.py (carga del .joblib) + artifacts/
  clients/       3 clientes HTTP: usuarios, riesgo, personal

presentation/    HTTP
  routes/        panel_routes.py (5 endpoints)
  dto/           schemas.py (Pydantic)
  middlewares/   auth_middleware.py (JWT + roles)
```

**Base de datos propia**

- MySQL exclusivo `db_panel` con **una sola tabla**, `atenciones` (21 columnas, 9 índices).
- Esquema **versionado** en `db/schema.sql`; se aplica con `scripts/init_db.py`, que además ejecuta **migraciones idempotentes** (por ejemplo la columna `estudiante_id`).
- `create_all()` **no** se invoca en producción: el esquema es explícito y reproducible.

**Endpoints**

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/panel/atencion` | Registra una atención y le asigna el perfil de agrupamiento. `201` |
| GET | `/api/panel/estadisticas` | KPIs, distribuciones y perfiles de IA. `200` |
| GET | `/api/panel/informe` | Informe CSV del periodo. `200` |
| GET | `/api/panel/atenciones` | Listado paginado con filtros. `200` |
| GET | `/api/panel/health` | Estado del servicio y de la base de datos. `200` / `503` |

Parámetro opcional `?periodo=YYYY-MM` en estadísticas, informe y listado.

---

## 4. Fase 3 — Modelo de agrupamiento

**Datos**

| Campo | Valor |
|---|---|
| Origen | Kaggle — `yuanchunhong/university-student-mental-health-indicators` |
| Licencia | **CC0-1.0** (dominio público) |
| Descarga | API pública, **sin credenciales**, con verificación de SHA256 |
| Contenido | 1 800 filas × 15 variables |
| SHA256 | `BB27C2A3D0046FA4C615D8C6222F5AC1C441B1F7CB780534CC1B73239968CF38` |

> ⚠️ **El dataset es sintético**: lo generó su propietario con una fórmula ponderada más ruido gaussiano (σ=1). Se documenta en el `README` del modelo, en la nota `nota_ia` de la API y en el panel. Los perfiles describen datos simulados, no poblaciones reales.

**Variables** — se usan las **7 del contrato de evaluación de riesgo** (PHQ9, GAD7, OnlineStress, FinancialStress, ExerciseFreq, SocialActivity, SleepHours), las mismas que consume `prediction-ml`. Decisión **medida**: sobre este subconjunto la silueta se duplica (0.10 frente a 0.05); las 8 restantes aportan ruido.

**Algoritmo y comparativa**

| | k | Coeficiente de Silueta ↑ | Índice Davies-Bouldin ↓ |
|---|---|---|---|
| **K-Means** (principal) | **8** | **0.1034** | **1.7971** |
| Jerárquico ward (línea base) | 2 | 0.0591 | 3.8037 |

K-Means supera al jerárquico en **ambas métricas y en los 9 valores de k** evaluados: la estructura está en los datos, no es un artefacto del algoritmo.

**Integración**

- Se exporta `Pipeline(StandardScaler, KMeans)` en **un solo `.joblib`**. Empaquetar el escalador con el modelo es deliberado: K-Means depende de la escala, y separarlos es la causa habitual del error que encontramos en `prediction-ml` (un KNN entrenado con z-score que recibía datos crudos).
- El backend lo carga en `ScikitClusteringAdapter` y lo invoca en **dos momentos**: al registrar (asigna `cluster_id`) y al consultar (aporta las descripciones de los perfiles). El conteo de estudiantes por perfil sale de la **base de datos**, no del catálogo de entrenamiento.

---

## 5. Fase 4 — Reglas obligatorias

### Privacidad k=5

Vive en el **dominio** (`app/domain/services/privacidad_k5.py`), no en la presentación: es una regla de negocio, no una comprobación de capa.

Se aplica a **toda** agrupación que salga de la API: distribuciones por tipo, modalidad, estado y periodo; perfiles de agrupamiento; celdas de nivel de riesgo dentro de cada perfil; y filas del informe CSV.

Los grupos suprimidos **no aparecen en ningún campo**. Solo se informa `grupos_omitidos_por_privacidad`, que dice **cuántos** se ocultaron, nunca su contenido.

> **Demostración en vivo:** la base de datos puede contener un grupo de 4 estudiantes y la API no lo muestra. Se contrasta en dos pantallas — es la comprobación más fácil de hacer ante un jurado.

### Aislamiento de datos

El servicio **no lee ninguna tabla ajena**. Toda información externa entra por HTTP a través de puertos:

| Puerto | Consulta | Para qué |
|---|---|---|
| `IPersonalExternoPort` | `users` → `GET /users/me` | Identidad de quien registra la atención |
| `IUsuariosPort` | `users` → `GET /users/by-code/{code}` | Identificador numérico del estudiante |
| `IEvaluacionesRiesgoPort` | `riskEvaluation` → `GET /risk-evaluations/summary` | Nivel de riesgo por perfil |

**Los tres degradan sin propagar**: si un servicio externo no responde, el panel sigue funcionando. Es una degradación deliberada, no un fallo.

### Seguridad

- Credenciales **solo** desde `.env`. Sin valores por defecto para `DB_USER`, `DB_PASS` ni `JWT_SECRET`.
- Si falta `JWT_SECRET`, las rutas protegidas responden `500` con mensaje explícito: **fallo cerrado**.
- JWT `HS256` con algoritmo fijo, `alg=none` rechazado, expiración de 1 h, `require: ["userId","role"]`.
- El **rol se lee del token firmado**, nunca del cuerpo de la petición. Solo `PERSONAL_UNAYOE` y `ADMINISTRADOR`.
- `.dockerignore` propio: sin él, `COPY . .` metería el `.env` **dentro de la imagen**. Verificado: la imagen no lo contiene.

### IA responsable

- Toda respuesta con resultados de IA incluye `nota_ia`.
- El panel muestra el aviso correspondiente en cada vista con contenido del modelo.
- Los comentarios del código que hablan del modelo dejan claro que son estimaciones orientativas.

---

## 6. Extensiones a servicios existentes

Solo se tocó lo **imprescindible** para que el panel consuma datos externos por HTTP:

**`services/users`** — nuevo `GET /users/by-code/{code}` (rol institucional). Devuelve **solo** `{ id, code }`: ningún nombre, correo ni dato personal del estudiante.

**`services/riskEvaluation`** — nuevo `GET /risk-evaluations/summary?userIds=…` (rol institucional). Devuelve la última evaluación de cada estudiante: identificador, nivel de riesgo, probabilidad y fecha. **No** incluye el reporte de IA ni las explicaciones.

---

## 7. Verificación ejecutada

Todas las cifras de esta tabla son reales, no estimadas.

| Comprobación | Comando | Resultado |
|---|---|---|
| Instalación limpia | `pip install -r requirements.txt` | ✅ exit 0 |
| Entorno Python | `import flask, sklearn, jwt…` | ✅ |
| Tests del backend | `pytest tests -q` | ✅ **79 passed** |
| Extremo a extremo | `python scripts/verificacion_e2e.py` | ✅ **26/26** |
| Tests del frontend | `npm test` | ✅ **32 passed** |
| Tipos (3 proyectos) | `tsc --noEmit` | ✅ exit 0 |
| Build del frontend | `npm run build` | ✅ exit 0 (~95 kB gzip) |
| OpenAPI (3 archivos) | parser YAML | ✅ 5 + 6 + 4 paths |
| Esquema en MySQL real | `DESCRIBE` / `SHOW INDEX` | ✅ 21 columnas, 9 índices |
| Migración | `python scripts/init_db.py` × 2 | ✅ aplicada e idempotente |
| Imagen Docker | `docker build` + `grep -c '^\.env$'` | ✅ `0` (el `.env` queda fuera) |
| Salud con BD real | `GET /api/panel/health` | ✅ `{"database":"OK",…}` |
| Reproducibilidad del modelo | `python ml/train_clustering.py` | ✅ k=8, 0.103353, 1.797103 |
| Aislamiento de datos | `SHOW DATABASES` | ✅ solo `db_panel` |

**Cobertura de pruebas**

| Archivo | Tests | Qué cubre |
|---|---|---|
| `unit/test_privacidad_k5.py` | 6 | La regla k=5 y que el contenido suprimido no se filtra |
| `unit/test_riesgo_por_perfil.py` | 8 | El cruce de riesgo por perfil y la k=5 interna |
| `unit/test_personal_externo.py` | 14 | La degradación si `users` no responde |
| `unit/test_evaluaciones_riesgo_client.py` | 10 | La degradación si `riskEvaluation` no responde |
| `unit/test_usuarios_client.py` | 9 | La resolución del identificador y el escapado de la URL |
| `integration/test_registro_atencion.py` | 14 | Registro, cluster, validaciones, listado y filtros |
| `integration/test_auth.py` | 9 | 401 / 403 / firma ajena / expirado / `alg=none` |
| `integration/test_estadisticas_informe.py` | 9 | k=5 en respuestas, nota de IA, CSV con BOM |
| `validation.test.ts` | 19 | Validadores, rangos, rol institucional, periodos |
| `api.test.ts` | 13 | Cabeceras, guardas de host y clave, respuestas inválidas |

---

## 8. Correcciones de calidad aplicadas durante el trabajo

| # | Hallazgo | Corrección |
|---|---|---|
| 1 | El KNN de `prediction-ml` estaba entrenado con z-score y recibía datos crudos; el escalador no estaba en el repo | **Reportado, no tocado** (fuera del alcance del Módulo 4). Impacto medido: −0.057 en P(ansiedad) y 10,5 % de las evaluaciones cambian de nivel de riesgo |
| 2 | `pip install` fallaba en Python 3.9/3.10 (`greenlet` sin rueda, compilaba y pedía Visual C++) | `greenlet==3.0.3` fijado en `requirements.txt` |
| 3 | `COPY . .` metía el `.env` (con `JWT_SECRET` y la contraseña de BD) dentro de la imagen Docker | `.dockerignore` propio |
| 4 | `load_dotenv()` sin ruta: el `.env` no se encontraba si se arrancaba desde otro directorio | Ruta absoluta al `.env` del servicio |
| 5 | `datetime.utcnow()`, deprecado desde Python 3.12 | `ahora_utc()` en `app/domain/services/fecha_hora.py` (mismo valor, sin deprecation) |
| 6 | MySQL 8 usa `caching_sha2_password` y PyMySQL necesita `cryptography` | `cryptography==44.0.0` añadido a `requirements.txt` |
| 7 | `CREATE TABLE IF NOT EXISTS` no altera tablas existentes: la columna nueva no llegaba a instalaciones previas | Migraciones idempotentes en `scripts/init_db.py` |
| 8 | `datetime` naive vs tz-aware al guardar en MySQL `DATETIME` | `ahora_utc()` devuelve UTC naive, idéntico al anterior |
| 9 | La ruta de login del frontend apuntaba a `/users/users`; la confirmada es `/u/users` | Corregida en `config.ts`, `.env.example` y los tests |
| 10 | `.playwright-mcp/` y `.vscode/` quedaban sin trackear | Añadidos al `.gitignore` raíz, junto con `.venv/`, `__pycache__/` y `.pytest_cache/` |
| 11 | El repo mezclaba finales de línea LF y CRLF | `.gitattributes` con `*.joblib` marcado como binario |

---

## 9. Lo que queda fuera de este módulo

Estas tareas son de **infraestructura** y las realiza el equipo:

| Tarea | Por qué no corresponde |
|---|---|
| Publicar `/panel` en Azure API Management | El frontend en producción llama al gateway; el API lo configura el equipo |
| Entregar `VITE_APIM_SUBSCRIPTION_KEY` | La clave la emite Azure; sin ella el frontend no puede llamar al gateway |
| Desplegar `panel-service` en Render | La imagen está lista (`Dockerfile`), el despliegue es del equipo |
| Redesplegar `users` y `riskEvaluation` | Los endpoints `by-code` y `summary` son nuevos |
| Crear el usuario institucional | Requiere `UPDATE` sobre la base de datos de `users` (ver §10) |

**Mientras tanto**, el panel funciona completo **salvo la correlación de riesgo**: sin `riskEvaluation` desplegado, la columna «Riesgo» muestra «Sin correlación» y `riesgo_disponible` es `false`. Es una degradación deliberada.

---

## 10. Un punto que conviene conocer

El rol institucional **no se puede obtener por la API**. En el servicio de usuarios, `CreateUser` fija siempre `role: "ESTUDIANTE"` y `UpdateUserDTO` es estricto y no admite el campo `role`. No existe ninguna vía por API para crear un `PERSONAL_UNAYOE` o un `ADMINISTRADOR`.

Por eso, el primer usuario del panel se crea directamente en la base de datos de `users`:

```sql
UPDATE users SET role = 'PERSONAL_UNAYOE' WHERE email = '<correo>';
```

Está documentado en `README_MODULO_4.md` (§7) y en el README del servicio.

---

## 11. Limitaciones declaradas

- **No hay pruebas de componentes React**: no se instaló `@testing-library` ni `jsdom`. Las 32 pruebas del frontend cubren lógica pura y el cliente HTTP; el renderizado se verificó de forma manual en el navegador.
- **No hay ESLint ni Prettier** configurados (tampoco en el resto del repo).
- **El modelo se entrenó con datos sintéticos.** Los perfiles describen ese dataset, no la realidad de la población. Con datos reales de la institución, reentrenar es sustituir el `.joblib`: ni la API ni el frontend cambian.
- **La silueta es baja (0.1034)**, muy por debajo del 0.25 habitual. Es consecuencia del ruido gaussiano del dataset sintético, no del algoritmo: K-Means gana a la línea base en los 9 valores de k.
- **El frontend en desarrollo no puede llamar al backend local**: `api.ts` exige host HTTPS `*.azure-api.net` y la clave de APIM está vacía. Para ver el dashboard con datos reales hacen falta la clave del equipo y `/panel` publicado en APIM. Mientras tanto, el script `scripts/verificacion_e2e.py` demuestra el backend completo por terminal.
