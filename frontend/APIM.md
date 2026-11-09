# Flutter Windows: local y Azure API Management

Ejecutar los comandos desde `frontend/`.

## Local

```powershell
flutter run -d windows --dart-define=USERS_BASE_URL=http://localhost:5000 --dart-define=RISK_EVALUATION_BASE_URL=http://localhost:3002
```

Sin `APIM_BASE_URL`, no se añade el encabezado de suscripción. Registro y login
comparten la base Users configurada. Evaluación conserva su base independiente.

## Azure

Configurar `APIM_SUBSCRIPTION_KEY` en el entorno de la terminal con el valor
entregado por el equipo, sin guardarlo en archivos versionados ni mostrarlo.

```powershell
flutter run -d windows --dart-define=APIM_BASE_URL=https://apim-g7-riesgo-ansiedad.azure-api.net --dart-define="APIM_SUBSCRIPTION_KEY=$env:APIM_SUBSCRIPTION_KEY"
```

La configuración APIM tiene prioridad sobre `USERS_BASE_URL`,
`RISK_EVALUATION_BASE_URL` y la base local guardada en preferencias.
Cambiar los `dart-define` requiere volver a ejecutar Flutter; hot reload no los cambia.

| Operación | Ruta | Bearer |
|---|---|---|
| Registro | `/u/users` | No |
| Login | `/u/users/login` | No |
| Evaluación | `/re/risk-evaluations` | Sí |
| Restauración | `/u/users/me` | Sí |

Todas las solicitudes al host APIM configurado incluyen
`Ocp-Apim-Subscription-Key`, también GET, listas, PUT y DELETE.
La clave no se incorpora a solicitudes a otros hosts o a localhost.
Si falta la clave, la solicitud APIM se rechaza antes de enviarse.

La persistencia existente identifica la sesión por la base Users: cambiar entre
local y APIM requiere iniciar sesión en el entorno seleccionado.

## Limitaciones de integración

- El equipo debe confirmar que `GET /u/users/me` está publicado para restaurar sesión.
- Historial y rutas antiguas de Admin/Médico no tienen rutas APIM confirmadas;
  esta fase conserva su configuración existente.
- Un HTTP 401 de una solicitud autenticada mantiene la invalidación global
  existente. Una clave APIM rechazada puede producir ese mismo código.
- El backend debe conservar el contrato camelCase y responder HTTP 201 al crear
  una evaluación. No se ha verificado contra Azure mediante solicitudes reales.
- `dart-define` evita versionar la clave, pero la incorpora al ejecutable cliente;
  no equivale a almacenarla como un secreto de servidor.

## Pruebas sin servicios reales

```powershell
flutter test --no-pub
flutter analyze --no-pub
flutter test --no-pub test/apim_configuration_test.dart --dart-define=APIM_BASE_URL=https://apim-g7-riesgo-ansiedad.azure-api.net --dart-define=APIM_SUBSCRIPTION_KEY=fake-subscription
```

Las pruebas usan clientes simulados y claves ficticias. No invocan Azure ni Gemini.

## Configuración con .env (Git Bash)

Coloca `frontend/.env` (junto a este archivo) con:

    APIM_BASE_URL=https://apim-g7-riesgo-ansiedad.azure-api.net
    APIM_SUBSCRIPTION_KEY=<clave entregada por el equipo>

Usa `frontend/.env.example` como plantilla. El archivo `.env` **no se sube al
repositorio** (`.gitignore`), por lo que cada miembro coloca su propia clave.

Ejecuta desde Git Bash, en la carpeta `frontend/`:

    bash run-apim.sh

o:

    ./run-apim.sh

El script lee `.env`, valida las dos variables y lanza:

    flutter run -d windows --dart-define=APIM_BASE_URL=... --dart-define=APIM_SUBSCRIPTION_KEY=...

sin mostrar la clave. Recuerda: `--dart-define` **incorpora la clave al
ejecutable** del cliente, así que esta configuración es **solo para pruebas
controladas**, no para producción.
