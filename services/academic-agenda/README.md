# academic-agenda

Microservicio Flask para gestión de actividades académicas y clasificación semanal de carga.

## Arquitectura (siguiendo prediction-ml)

- `src/domain/`: entidades y reglas de negocio (puertos de repositorio, token, clasificador).
- `src/application/`: casos de uso (CRUD de actividades, clasificación semanal).
- `src/infrastructure/`: persistencia MySQL, servicio JWT, predictor ML.
- `src/infrastructure/models/`: contrato y artefacto `modelo_carga_academica.joblib`.
- `src/presentation/`: API REST Flask.
- `app.py`: composición root.

## Endpoints

| Método | Ruta | Descripción | Auth |
|--------|------|-------------|------|
| GET | `/health` | Estado del servicio y disponibilidad ML | No |
| POST | `/actividades` | Crea una actividad académica | Sí (Bearer) |
| GET | `/actividades` | Lista actividades del usuario | Sí (Bearer) |
| GET | `/actividades/:id` | Obtiene una actividad por ID | Sí (Bearer) |
| PATCH | `/actividades/:id` | Actualiza una actividad | Sí (Bearer) |
| DELETE | `/actividades/:id` | Elimina una actividad | Sí (Bearer) |
| POST | `/clasificacion/semanal` | Clasifica carga semanal (ML) | Sí (Bearer) |

## Modelo ML

El predictor de carga semanal carga el modelo entrenado incluido en:
```
services/academic-agenda/src/infrastructure/models/modelo_carga_academica.joblib
```

Si el artefacto falta, el servicio arranca normalmente: el CRUD funciona
sin problemas y `/clasificacion/semanal` responde 503 informando que el
predictor no está disponible. No se entrena ni se inventa ningún modelo.

## Variables de entorno

Copia `.env.example` a `.env` y completa con valores reales. Nunca versionar
`.env`.

Para Render, usa `render.yaml` con el Dockerfile de `services/academic-agenda`.
El contenedor inicia Gunicorn con un worker y escucha en `PORT` (5004 por
defecto). En el servicio de Render configura `DB_ENABLED=true`, `DB_SSL=true`,
`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` y el mismo
`JWT_SECRET` que Users. Configura los valores secretos en el panel de Render;
no los pongas en el Dockerfile ni en Git.
`DB_SSL_CA` es opcional: indica la ruta de un certificado CA disponible dentro
del contenedor; si se omite se usa el almacén de CA del sistema. La conexión
verifica certificado e identidad del servidor. Aplica `db/schema.sql` a la
base exclusiva de Agenda antes de activar el CRUD. `CORS_ORIGINS` acepta
orígenes separados por coma y está vacío por defecto.

Si falla la conexión inicial, el servicio arranca y el CRUD autenticado
responde 503 sin exponer credenciales. Si la conexión cae después, el CRUD
también responde 503. `/health` informa `database: OK` solo cuando la BD
responde; si no, responde 503 con `database: UNAVAILABLE`. Si la conexión
inicial falla, se requiere reiniciar el proceso cuando la BD vuelva a estar
disponible. `DB_ENABLED=false` deja el CRUD deshabilitado de
forma explícita. Para MySQL local sin TLS, usa `DB_SSL=false` solo en
desarrollo.

## Pruebas

```bash
cd services/academic-agenda
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pytest tests/
python app.py
```

Puerto predeterminado: 5004.
