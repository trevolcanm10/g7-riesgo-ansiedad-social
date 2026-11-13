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
- **Recordatorios dentro de la app** (`GET /appointments/me/reminders`, solo estudiante): lista las citas activas que aún no ocurren. El aviso corresponde (`dueNow`) desde **24 h** antes y, si la probabilidad de inasistencia estimada alcanza el umbral del modelo (`flag_threshold`, 0,3153 en `logreg-calibrated-v1`; 0,30 en la línea base), desde **48 h** antes (recordatorio reforzado). El refuerzo solo adelanta el aviso: la respuesta no incluye la probabilidad ni factores y no condiciona la atención. Si el modelo falla, el recordatorio normal se entrega igual.

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

Cubren las reglas con repositorios en memoria y el predictor de inasistencia.

### Pruebas contra MySQL real (opcionales)

`tests/test_mysql_integration.py` repite las pruebas de la API con los repositorios MySQL y agrega
pruebas de concurrencia, restricciones y fechas. **Borran las tablas de Citas**, así que usan una
base aparte cuyo nombre debe terminar en `_test`. Sin `TEST_DB_NAME` se omiten.

```bash
# crear la base una vez (pide la contraseña de MySQL)
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS citas_test CHARACTER SET utf8mb4"
```

Agregar a `services/citas/.env` (ese archivo no se versiona):

```
TEST_DB_NAME=citas_test
TEST_DB_USER=root
TEST_DB_PASSWORD=<tu contraseña>
# opcionales: TEST_DB_HOST (localhost), TEST_DB_PORT (3306), TEST_DB_SSL (false)
```

```bash
python -m unittest tests.test_mysql_integration
```

El esquema `db/schema.sql` lo aplica la propia prueba. La conexión con TLS (`DB_SSL=true`, como en
Azure) **no** se ha probado todavía.

## Despliegue en Render

Los demás servicios (Users, Evaluación, Predicción) están en Render y se exponen por el APIM; Citas va
igual, como un servicio web más. Archivo: [`render.yaml`](render.yaml).

**Con Blueprint:** Render > New > Blueprint > elegir el repositorio y la rama; si pide la ruta del
archivo, `services/citas/render.yaml`. Render pedirá los valores secretos al crear el servicio.

**A mano** (equivalente): Web Service con Root Directory `services/citas`, Build
`pip install -r requirements.txt`, Start
`gunicorn --bind 0.0.0.0:$PORT --workers 2 --timeout 60 "app:create_app()"`, Health Check Path `/health`
y Python 3.11 o más.

Variables de entorno:

| Variable | Valor |
|---|---|
| `JWT_SECRET` | El **mismo** que usa Users (variable del servicio Users en Render) |
| `USE_IN_MEMORY` | `false` |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | La base `citas_db` (crearla antes y ejecutar `db/schema.sql`) |
| `DB_SSL` | `true` |
| `NO_SHOW_MODEL_PATH` | Opcional: `ml/artifacts/no_show_logreg_v1.json` |

Después de desplegar: `GET /health` debe responder `200` con `"database": "OK"`. Luego se agrega la ruta
`/c` en el APIM apuntando a la URL de Render y se verifica con el contrato de
[`openapi/citas.yaml`](../../openapi/citas.yaml). El plan gratuito de Render duerme el servicio tras un
rato sin tráfico: la primera petición puede tardar.

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
- **El límite de 2 citas activas no es atómico.** El servicio cuenta las citas activas y después reserva el horario; si un mismo estudiante envía dos solicitudes simultáneas, ambas pueden pasar la revisión y quedar con 3 citas. La reserva del horario sí es atómica (probado con 8 hilos), por lo que nunca se duplica un horario. Es poco probable con una persona usando la app y es aceptable para el MVP; si hiciera falta, se resuelve con un bloqueo por estudiante o una restricción en la base.
- Por defecto el predictor de inasistencia es una **línea base por reglas** (`rule-based-baseline-v0`). Con `NO_SHOW_MODEL_PATH` (ruta relativa a esta carpeta; el modelo en uso aparece como `noShowModel` en `/health`) se usa la regresión logística calibrada de `ml/` (ver `ml/README.md`), entrenada con un conjunto público de atención médica, no con estudiantes. En ambos casos solo sirve para decidir recordatorios y nunca debe usarse para negar o retrasar una cita.
- Los recordatorios se muestran dentro de la app al abrirla; **no hay envío en segundo plano** (push, correo o SMS). Cuando exista el servicio de Notificaciones podrá consumir `GET /appointments/me/reminders` u otro contrato que se acuerde.
- Pendiente con el equipo: prefijo `/c` en APIM, base MySQL y despliegue de Citas.
