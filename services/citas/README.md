# Citas (M3)

Microservicio de agendamiento de citas con UNAYOE. Python 3.11+ (probado en 3.13) y Flask.
Valida el mismo JWT que emite `services/users` (HS256, payload `{userId, role}`), por eso necesita el **mismo `JWT_SECRET`**.
Contrato: [`openapi/citas.yaml`](../../openapi/citas.yaml). Esquema SQL: [`db/schema.sql`](db/schema.sql).

## Reglas de negocio (v1)

- Cita de **30 minutos fijos**. El estudiante elige entre los horarios libres.
- Máximo **2 citas activas** (SOLICITADA o CONFIRMADA) por estudiante.
- El estudiante cancela o reprograma hasta **12 h antes**; UNAYOE/ADMIN, en cualquier momento.
- Estados: `SOLICITADA → CONFIRMADA → ATENDIDA | NO_ASISTIO`, y `CANCELADA`. Reprogramar mueve la misma cita a otro horario y vuelve a `SOLICITADA`.
- `priority: ALTA` es **solo informativa** en la v1: no cambia orden ni permisos.
- No se guardan puntajes ni respuestas del cuestionario.

## Ejecutar en local (bash)

```bash
cd services/citas
python -m venv .venv
source .venv/Scripts/activate
python -m pip install -r requirements.txt
cp .env.example .env
```

Para ensayar **sin MySQL** pon en `.env`: `JWT_SECRET=cualquier-texto` y `USE_IN_MEMORY=true` (los datos se pierden al reiniciar).

```bash
python app.py        # http://localhost:3004/health
```

Con MySQL: crea una base, ejecuta `db/schema.sql` y completa `DB_*` en `.env` (con `USE_IN_MEMORY=false`).

## Pruebas

```bash
python -m unittest discover -s tests -t .
```

Cubren las reglas con repositorios en memoria. **No hay pruebas contra MySQL real todavía.**

## Estructura

```
app.py                       composition root
src/domain/                  modelo, errores y puertos (sin Flask ni MySQL)
src/application/services.py  casos de uso
src/infrastructure/          MySQL, memoria, JWT, predictor de inasistencia
src/presentation/http.py     rutas Flask y manejo de errores ({"message": ...})
```

## Limitaciones conocidas

- Reservar horario y crear la cita no comparten transacción: si falla el segundo paso se libera el horario (compensación). Es suficiente para el MVP.
- El predictor de inasistencia es una **línea base por reglas** (`rule-based-baseline-v0`), no un modelo entrenado. Nunca debe usarse para negar o retrasar una cita.
- Pendiente con el equipo: prefijo `/c` en APIM, base MySQL y despliegue de Citas, y conexión con Notificaciones para los recordatorios.
