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
| POST | `/auth/login` | Genera token JWT (user_id, role) | No |
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

## Pruebas

```bash
cd services/academic-agenda
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pytest tests/
python app.py
```

Puerto predeterminado: 5003.
