# Microservicio Panel Institucional (Modulo 4)

Microservicio del **Panel Institucional y Analitica** de la plataforma de
prevencion del riesgo de ansiedad social. Registra atenciones a estudiantes,
expone estadisticas anonimizadas con indicadores de IA y genera el informe
mensual.

> **Guia completa de instalacion, ejecucion, verificacion y publicacion:**
> [`README_MODULO_4.md`](../../README_MODULO_4.md) en la raiz del repositorio.
> Este documento describe el servicio en detalle.

---

## Caracteristicas principales

- **Arquitectura Limpia (Clean Architecture)**: capas `domain`, `application`,
  `infrastructure` y `presentation`. El dominio no depende de Flask ni de
  SQLAlchemy; los casos de uso dependen de puertos (interfaces) y los
  adaptadores concretos se inyectan en `run.py`.
- **Base de datos propia**: MySQL dedicado (`db_panel` por defecto) con una
  sola tabla, `atenciones`. El esquema esta versionado en `db/schema.sql` y
  se aplica con `scripts/init_db.py`. **No** se crea el esquema de forma
  implicita al arrancar.
- **Aislamiento de datos**: el servicio **no** lee las tablas de otros
  microservicios. Toda informacion externa se obtiene por HTTP, a traves de
  puertos: `IPersonalExternoPort` (identidad de quien registra, contra
  `users`), `IUsuariosPort` (identificador del estudiante a partir de su
  codigo, contra `users`) e `IEvaluacionesRiesgoPort` (nivel de riesgo por
  perfil de agrupamiento, contra `riskEvaluation`). Los tres degradan sin
  propagar: si un servicio externo no responde, el panel sigue funcionando.
- **Privacidad k=5**: ningun grupo con menos de cinco estudiantes sale del
  dominio. Es una regla de negocio, no una comprobacion de presentacion:
  vive en `app/domain/services/privacidad_k5.py`. La regla se aplica tambien
  dentro de cada perfil: una celda de nivel de riesgo con menos de cinco
  estudiantes se omite.
- **IA responsable**: toda respuesta con resultados de IA incluye la nota
  `nota_ia`, y los perfiles se describen como estimaciones orientativas que
  **no** constituyen un diagnostico clinico.
- **Autenticacion JWT**: se verifica la firma con el `JWT_SECRET` compartido
  con el servicio `users` y se exige rol `PERSONAL_UNAYOE` o `ADMINISTRADOR`.
  El rol se lee del token firmado, nunca del cuerpo de la peticion.

---

## Stack

| Elemento | Tecnologia |
|---|---|
| Lenguaje | Python 3.11 |
| Framework | Flask 3.0.3 |
| ORM / conector | Flask-SQLAlchemy 3.1.1 / PyMySQL 1.1.0 |
| Modelo de agrupamiento | scikit-learn 1.6.1 (K-Means) |
| Validacion | Pydantic 2.5.2 |
| Tokens | PyJWT 2.9.0 |
| Pruebas | pytest 8.3.3 |
| Produccion | Gunicorn 23.0.0 / Docker (python:3.11-slim) |

---

## Estructura

```text
panel-service/
├── app/
│   ├── domain/                              # Capa de dominio (sin dependencias)
│   │   ├── entities/
│   │   │   ├── atencion.py                 # Entidad de atencion
│   │   │   └── perfil_cluster.py            # Perfil de IA y grupos estadisticos
│   │   └── services/
│   │       └── privacidad_k5.py             # Regla de privacidad k=5
│   ├── application/                         # Casos de uso y puertos
│   │   ├── interfaces/
│   │   │   ├── atencion_repository_port.py
│   │   │   ├── clustering_port.py
│   │   │   └── personal_externo_port.py
│   │   └── use_cases/
│   │       ├── registrar_atencion.py
│   │       ├── listar_atenciones.py
│   │       ├── obtener_estadisticas.py
│   │       └── generar_informe.py
│   ├── infrastructure/                      # Adaptadores concretos
│   │   ├── persistence/
│   │   │   ├── db_models.py                 # Tabla atenciones
│   │   │   └── atencion_repository.py
│   │   ├── ml/
│   │   │   ├── clustering_adapter.py        # Carga del modelo .joblib
│   │   │   └── artifacts/                   # modelo + perfiles (versionados)
│   │   └── clients/
│   │       └── personal_externo_client.py   # Consulta HTTP a users
│   ├── presentation/                        # HTTP
│   │   ├── routes/panel_routes.py
│   │   ├── dto/schemas.py                   # Validacion Pydantic
│   │   └── middlewares/auth_middleware.py
│   └── config/settings.py                   # Configuracion desde .env
├── db/schema.sql                            # Esquema versionado
├── scripts/init_db.py                       # Aplicacion idempotente del esquema
├── ml/                                      # Entrenamiento del modelo (ver ml/README.md)
│   ├── train_clustering.py
│   ├── download_dataset.py
│   ├── data/mental_health_indicators.csv
│   └── resultados/comparativa.json
├── tests/
│   ├── conftest.py
│   ├── unit/test_privacidad_k5.py
│   └── integration/
├── Dockerfile
├── requirements.txt
├── .env.example
└── run.py
```

---

## Configuracion

Copia la plantilla y completa los valores:

```bash
cp .env.example .env
```

| Variable | Descripcion | Por defecto |
|---|---|---|
| `DB_HOST` | Servidor MySQL propio del panel | `127.0.0.1` |
| `DB_PORT` | Puerto MySQL | `3306` |
| `DB_NAME` | Base de datos **exclusiva** del panel | `db_panel` |
| `DB_USER` | Usuario MySQL | (vacio) |
| `DB_PASS` | Contrasena MySQL | (vacio) |
| `JWT_SECRET` | Secreto compartido con `users` para validar tokens | (vacio) |
| `USERS_BASE_URL` | Base del servicio `users` (consulta HTTP) | (vacio) |
| `RISK_EVALUATION_BASE_URL` | Base de `riskEvaluation` (correlacion de riesgo por HTTP) | (vacio) |
| `PORT` | Puerto HTTP del servicio | `5003` |
| `CORS_ALLOW_ORIGIN` | Origenes permitidos, separados por coma | `http://localhost:5174` |
| `FLASK_DEBUG` | Modo debug | `false` |
| `LOG_LEVEL` | Nivel de log | `INFO` |

**Fallo cerrado:** si `JWT_SECRET` no esta definido, las rutas protegidas
responden `500` con un mensaje explicito. No se acepta ninguna peticion sin
verificar la firma.

La contrasena de MySQL se escapa con `quote_plus` al construir la URI, de modo
que los caracteres especiales no rompen la cadena de conexion.

---

## Ejecucion local

```bash
pip install -r requirements.txt
python scripts/init_db.py     # aplica db/schema.sql
python run.py                 # http://localhost:5003
```

Con Docker:

```bash
docker build -t panel-service:latest .
docker run -d -p 5003:5003 --env-file .env panel-service:latest
```

---

## Endpoints

Base: `/api/panel`. Todos exigen `Authorization: Bearer <jwt>` con rol
`PERSONAL_UNAYOE` o `ADMINISTRADOR`, salvo `/api/panel/health`.

| Metodo | Ruta | Descripcion |
|---|---|---|
| POST | `/api/panel/atencion` | Registra una atencion. `201`. |
| GET | `/api/panel/estadisticas` | KPIs, distribuciones y perfiles de IA. `200`. |
| GET | `/api/panel/informe` | Informe CSV del periodo. `200`. |
| GET | `/api/panel/atenciones` | Listado paginado con filtros. `200`. |
| GET | `/api/panel/health` | Estado del servicio y de la base de datos. `200` / `503`. |

Parametro opcional `?periodo=YYYY-MM` en estadisticas, informe y listado.

La especificacion completa esta en `openapi/panel.yaml` (raiz del repositorio).

---

## Correlacion con el nivel de riesgo

El nivel de riesgo (`BAJO` / `MEDIO` / `ALTO`) lo publica el microservicio
`riskEvaluation`. El panel **no lee su base de datos**: lo pide por HTTP a
`GET /risk-evaluations/summary?userIds=...`, que devuelve la ultima
evaluacion de cada estudiante.

El flujo completo:

```
1. Al registrar una atencion, el panel resuelve el identificador del
   estudiante: GET {USERS_BASE_URL}/users/by-code/{codigo}
   -> guarda estudiante_id junto al cluster asignado por el modelo.

2. Al pedir estadisticas, cuenta los estudiantes por cluster en su propia
   base de datos y pide a riskEvaluation la evaluacion de esos estudiantes.

3. Cruza ambos: cada perfil muestra cuantos de sus estudiantes estan en
   riesgo alto, medio y bajo.
```

**Degradacion.** Si `riskEvaluation` no responde, o si `users` no esta
desplegado con el endpoint `by-code`, el panel sigue funcionando: la
correlacion aparece vacia y `riesgo_disponible` es `false` en la respuesta.
El personal ve los perfiles sin la correlacion, pero nada mas falla.

**Estado actual:** los endpoints `by-code` (en `users`) y `summary` (en
`riskEvaluation`) son **nuevos**. Hasta que ambos servicios se redesplieguen,
la correlacion de riesgo no aparece. Todo lo demas funciona igual.

---

## Acceso del personal institucional

El panel exige un JWT con rol `PERSONAL_UNAYOE` o `ADMINISTRADOR`, emitido
por `POST /u/users/login` del servicio de usuarios.

**El rol no se puede obtener por la API de registro.** `CreateUser` fija
siempre `role: "ESTUDIANTE"`, y `UpdateUserDTO` es estricto y no admite el
campo `role`. Por eso la creacion de un usuario institucional se hace
directamente en la base de datos de `users`:

```sql
UPDATE users SET role = 'PERSONAL_UNAYOE' WHERE email = '<correo>';
```

El `JWT_SECRET` del panel debe ser **el mismo** que el del servicio de
usuarios: es lo que permite validar la firma del token.

---

## Regla de privacidad k=5

Se aplica a **toda** agrupacion que salga del dominio:

- distribuciones por tipo, modalidad, estado y periodo;
- perfiles de agrupamiento de la IA;
- filas del informe CSV.

Un grupo con menos de cinco estudiantes se descarta por completo: su
contenido no aparece en ningun campo de la respuesta. El panel recibe
`grupos_omitidos_por_privacidad`, que informa **cuantos** grupos se ocultaron
sin revelar su contenido.

```python
from app.domain.services.privacidad_k5 import filtrar_grupos
resultado = filtrar_grupos(grupos)   # resultado.grupos, resultado.omitidos
```

---

## Modelo de agrupamiento

El modelo (K-Means, `k=8`) y su metodologia estan documentados en
[`ml/README.md`](ml/README.md).

Aviso: los perfiles son **estimaciones orientativas** y **no son
diagnosticos clinicos**. Provienen de un dataset sintetico (Kaggle, CC0) y no
describen poblaciones reales. La arquitectura del adaptador no depende del
dataset: reentrenar con datos reales de la institucion es sustituir el
`.joblib` y volver a ejecutar `ml/train_clustering.py`.

---

## Pruebas

```bash
pytest tests/ -q
```

**Esperado: `79 passed`.** Las pruebas corren sobre **SQLite en memoria**
(`sqlite:///:memory:`), sin tocar MySQL ni requerir conexion externa. No
invocan servicios externos: los clientes HTTP se sustituyen con dobles de
prueba.

Ademas, la verificacion de extremo a extremo:

```bash
python scripts/verificacion_e2e.py
```

**Esperado: `VERIFICACION SUPERADA`** (26 comprobaciones). Levanta la
aplicacion, genera un token JWT real y ejercita los endpoints por HTTP.

Cobertura:

| Archivo | Verifica |
|---|---|
| `unit/test_privacidad_k5.py` | La regla k=5 en grupos y perfiles, incluidos los bordes (4, 5) y que el contenido suprimido no se filtra |
| `unit/test_riesgo_por_perfil.py` | El cruce de nivel de riesgo por perfil, incluida la k=5 dentro de cada perfil y el hecho de que una celda vacia no cuente como omitida |
| `unit/test_personal_externo.py` | La degradacion si el servicio de usuarios no responde: la atencion se registra igual |
| `unit/test_evaluaciones_riesgo_client.py` | La degradacion si el servicio de riesgo no responde, y el filtrado de respuestas con forma invalida |
| `unit/test_usuarios_client.py` | La resolucion del identificador del estudiante y el escapado de la URL |
| `integration/test_registro_atencion.py` | Registro, asignacion de cluster, validaciones (modalidad, tipo, rangos, codigo), listado, paginacion y filtros |
| `integration/test_auth.py` | 401 sin token, token con firma ajena, token expirado, `alg=none`, 403 para rol `ESTUDIANTE`, acceso de `PERSONAL_UNAYOE` y `ADMINISTRADOR` |
| `integration/test_estadisticas_informe.py` | k=5 en las respuestas, nota de IA, CSV con BOM, cabecera estable y filas de total, filtrado por periodo |
