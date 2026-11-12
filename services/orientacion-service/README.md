# Microservicio de Orientación Confidencial (M2 - UNAYOE FISI UNMSM)

Microservicio en **Python + Flask** diseñado bajo **Clean Architecture** para la recepción, triaje local asistido por IA y gestión de solicitudes confidenciales de orientación estudiantil.

## Arquitectura y Seguridad

- **Domain (`app/domain/`):** Entidades (`SolicitudOrientacion`), enumeraciones (`Role`, temas, prioridades, estados), excepciones de dominio y servicio determinista de detección de urgencias (`UrgenciaDomainService`).
- **Application (`app/application/`):** Casos de uso (`OrientacionUseCases`) y puertos (`ISolicitudRepository`, `IMLClassifier`, `ITokenService`).
- **Infrastructure (`app/infrastructure/`):** Persistencia MySQL vía SQLAlchemy (`SqlAlchemySolicitudRepository`), verificación JWT HS256 (`JwtTokenService`) e inferencia 100 % local con Scikit-Learn (`ScikitLocalClassifier`).
- **API (`app/api/`):** Blueprint Flask con validación estricta Pydantic v2 (`extra="forbid"`), decorador `@auth(*roles)` e identidades (`estudiante_id`, `atendido_por`) derivadas exclusivamente del JWT.

### Seguridad, Roles y Privacidad

- Todos los endpoints `/api/v1/orientacion/solicitudes*` exigen `Authorization: Bearer <JWT>` firmado con `JWT_SECRET` (HS256, `exp` obligatorio, `userId` entero positivo y `role` válido).
- **`ESTUDIANTE`:** crea sus propias solicitudes y consulta únicamente las suyas (`GET /` filtrado por su `userId`; consultar el ID de otro estudiante retorna `404`).
- **`PERSONAL_UNAYOE` / `ADMINISTRADOR`:** lista la bandeja con paginación y filtros, consulta detalles, atiende solicitudes (`PATCH .../atender`, retornando `409` si ya estaba atendida) y consulta métricas agregadas (`GET .../metricas/conteo-temas`).
- **Urgencias y líneas de ayuda:** `UrgenciaDomainService` normaliza texto (sin tildes ni puntuación) y detecta ideación suicida, autolesión o crisis inmediata mediante expresiones regulares compiladas, forzando `prioridad_sugerida = "alta"` y devolviendo líneas oficiales configurables (`ORIENTACION_HELP_LINES`, por defecto `Línea 113 MINSA Opción 5`, `SAMU 106`, `PNP 105`).

## Endpoints

- `GET /health`: Verifica disponibilidad de base de datos y reporta `classifierModel` (`trained-tfidf-logreg` o `keyword-fallback`).
- `POST /api/v1/orientacion/solicitudes` (`ESTUDIANTE`)
- `GET /api/v1/orientacion/solicitudes` (`ESTUDIANTE` propias / `PERSONAL_UNAYOE` y `ADMINISTRADOR` bandeja con `estado`, `prioridad`, `limit`, `offset`)
- `GET /api/v1/orientacion/solicitudes/<id>` (`ESTUDIANTE` propia / `PERSONAL_UNAYOE` y `ADMINISTRADOR`)
- `PATCH /api/v1/orientacion/solicitudes/<id>/atender` (`PERSONAL_UNAYOE` / `ADMINISTRADOR`)
- `GET /api/v1/orientacion/solicitudes/metricas/conteo-temas` (`PERSONAL_UNAYOE` / `ADMINISTRADOR`)

## Base de datos y configuración

- Esquema DDL explícito en `db/schema.sql`. En producción se recomienda `AUTO_CREATE_TABLES=false` y ejecutar `db/schema.sql` durante el aprovisionamiento.
- Variables de entorno documentadas en `.env.example` (puerto por defecto `5002`, prefijo APIM `/o`, `FLASK_DEBUG=false`, `CORS_ALLOW_ORIGIN`, `JWT_SECRET`, `DB_SSL`, `ORIENTACION_HELP_LINES`).

## Ejecución local y pruebas

```bash
pip install -r requirements.txt -r requirements-dev.txt
python ml/train_orientacion.py
python -m pytest tests -v
python run.py
```

Para despliegue en Docker/Render ver `Dockerfile` y `render.yaml`. Para detalles del respaldo ML ver `ml/README.md`.
