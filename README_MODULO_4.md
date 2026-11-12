# Módulo 4 — Panel Institucional y Analítica

Guía paso a paso para instalar, ejecutar, verificar y publicar el Módulo 4 de
la plataforma de prevención del riesgo de ansiedad social (UNMSM / FISI).

El módulo tiene tres piezas independientes:

| Pieza | Ruta | Qué es |
|---|---|---|
| Microservicio backend | `services/panel-service/` | Flask + MySQL propia, expone la API del panel |
| Frontend web | `web-panel/frontend/` | React + Vite, la interfaz del personal institucional |
| Modelo de agrupamiento | `services/panel-service/ml/` | K-Means entrenado y exportado como `.joblib` |

Además hay cambios en dos servicios existentes para permitir la correlación
por HTTP: `services/users` (nuevo `GET /users/by-code/{code}`) y
`services/riskEvaluation` (nuevo `GET /risk-evaluations/summary`).

---

## 0. Requisitos

| Herramienta | Versión | Nota |
|---|---|---|
| Python | **3.9 – 3.12** | 3.9/3.10 requieren `greenlet==3.0.3` (ya fijado). **3.13 funciona; 3.14 no**: `scikit-learn==1.6.1` no publica ruedas para cp314 y pip intentaría compilarla |
| Node.js | 20 o superior | Para el frontend |
| Docker | con Desktop | Solo si vas a levantar MySQL en contenedor |
| MySQL | 8.0 | Alternativa: usar el contenedor del paso 2 |

> El `Dockerfile` del servicio usa `python:3.11-slim`, que es la versión de
> producción recomendada.

---

## 1. Backend — entorno e instalación

```powershell
cd services\panel-service

# 1. Crear el entorno virtual con un Python compatible
py -3.11 -m venv .venv          # si tienes 3.11
# si solo tienes 3.9 o 3.10:
#   & "C:\Users\EQUIPO\AppData\Local\Programs\Python\Python39\python.exe" -m venv .venv

.\.venv\Scripts\Activate.ps1

# 2. Instalar dependencias
pip install -r requirements.txt
```

**Verificación:** la instalación debe terminar sin errores. Si aparece
`error: Microsoft Visual C++ 14.0 or greater is required`, estás con
Python 3.9/3.10 y un `greenlet` sin fijar: comprueba que
`requirements.txt` incluye `greenlet==3.0.3`.

Comprobar el entorno:

```powershell
python -c "import flask, flask_sqlalchemy, sklearn, joblib, jwt; print('todo ok')"
```

---

## 2. Base de datos MySQL

El servicio tiene **su propia base de datos** (`db_panel` por defecto). No
comparte tablas con ningún otro microservicio.

### Opción A — Docker (recomendado para desarrollo)

```powershell
docker run -d --name panel-mysql `
  -e MYSQL_ROOT_PASSWORD=clave-local-pruebas `
  -e MYSQL_DATABASE=db_panel `
  -p 3306:3306 `
  mysql:8 --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci

# Crear el usuario de aplicación (MySQL 8 solo deja a root entrar por localhost)
docker exec panel-mysql mysql -uroot -pclave-local-pruebas -e "
  CREATE USER IF NOT EXISTS 'panel_app'@'%' IDENTIFIED BY 'clave-panel-app';
  GRANT ALL PRIVILEGES ON db_panel.* TO 'panel_app'@'%';
  FLUSH PRIVILEGES;"
```

### Opción B — MySQL ya instalado

```sql
CREATE DATABASE db_panel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'panel_app'@'%' IDENTIFIED BY '<tu clave>';
GRANT ALL PRIVILEGES ON db_panel.* TO 'panel_app'@'%';
```

---

## 3. Configuración por variables de entorno

```powershell
Copy-Item .env.example .env
```

Editar `.env` con los valores reales:

```ini
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=db_panel
DB_USER=panel_app
DB_PASS=clave-panel-app

# Debe ser el MISMO valor que el del servicio de usuarios: es lo que
# permite verificar la firma del token.
JWT_SECRET=<cadena aleatoria de 32+ caracteres>

# Servicio de usuarios (opcional). Si se deja vacio, el panel funciona
# sin resolver la identidad de quien registra.
USERS_BASE_URL=http://localhost:3001

# Servicio de evaluacion de riesgo (opcional). Si se deja vacio, el panel
# funciona sin la correlacion de nivel de riesgo.
RISK_EVALUATION_BASE_URL=http://localhost:3002

PORT=5003
FLASK_DEBUG=false
LOG_LEVEL=INFO
CORS_ALLOW_ORIGIN=http://localhost:5174
```

> `.env` **no se versiona**: está en el `.gitignore` raíz. Solo se versiona
> `.env.example`.

---

## 4. Aplicar el esquema

```powershell
python scripts\init_db.py
```

**Salida esperada:**
```
  Migracion aplicada: atenciones.estudiante_id
Esquema aplicado correctamente desde schema.sql
```

El script es **idempotente**: se puede ejecutar las veces que haga falta. La
primera vez crea la tabla `atenciones` a partir de `db/schema.sql`; las
siguientes solo aplican las migraciones pendientes (por ejemplo, añadir la
columna `estudiante_id` a una instalación anterior).

Comprobar el esquema:

```powershell
docker exec panel-mysql mysql -upanel_app -pclave-panel-app db_panel -e "DESCRIBE atenciones; SHOW INDEX FROM atenciones;"
```

Debe mostrar **21 columnas** y **9 índices** (8 propios + PRIMARY).

---

## 5. Arrancar el backend

```powershell
python run.py
```

**Salida esperada:**
```
Panel institucional escuchando en el puerto 5003
```

Comprobar que responde y que ve la base de datos:

```powershell
(Invoke-WebRequest "http://127.0.0.1:5003/api/panel/health" -UseBasicParsing).Content
```

**Respuesta esperada:**
```json
{"database":"OK","service":"panel","status":"OK"}
```

> `"database":"OK"` confirma que el pool MySQL conectó de verdad.

---

## 6. Frontend

```powershell
cd ..\..\web-panel\frontend

npm install
Copy-Item .env.example .env
```

Editar `.env`:

```ini
# Base del gateway de Azure API Management.
VITE_APIM_BASE_URL=https://apim-g7-riesgo-ansiedad.azure-api.net

# Clave de suscripcion de APIM. Sin ella el panel no puede llamar al gateway.
VITE_APIM_SUBSCRIPTION_KEY=

# Sufijo del microservicio de panel dentro de APIM.
VITE_APIM_PANEL_PATH=/panel/api/panel

# Sufijo del microservicio de usuarios (ruta confirmada por el equipo).
VITE_APIM_USERS_PATH=/u/users
```

```powershell
npm run dev
```

**Salida esperada:** `VITE v6.4.6 ready` y `Local: http://localhost:5174/`

---

## 7. Acceso al panel

El panel exige un JWT con rol `PERSONAL_UNAYOE` o `ADMINISTRADOR`, emitido por
`POST /u/users/login` del servicio de usuarios.

### ⚠️ El rol institucional no se puede crear por la API

`CreateUser` del servicio de usuarios fija siempre `role: "ESTUDIANTE"`, y
`UpdateUserDTO` es estricto y no admite el campo `role`. **No existe ninguna
vía por API para crear un usuario con rol institucional.** Se hace
directamente en la base de datos de `users`:

```sql
UPDATE users SET role = 'PERSONAL_UNAYOE' WHERE email = '<correo>';
```

### Acceso en desarrollo sin clave de APIM

Si no hay clave de suscripción, el frontend no puede llamar al gateway. Para
revisar la interfaz se puede abrir una sesión directamente en el navegador:

1. Abrir `http://localhost:5174/login`
2. `F12` → **Console**
3. Ejecutar:

```js
sessionStorage.setItem('panel_sesion_v1', JSON.stringify({
  token: 'token-de-prueba',
  usuario: { id: 1, names: 'Ana', surnames: 'Perez', role: 'PERSONAL_UNAYOE' }
}))
```

4. **Recargar** la página (el token se lee al montar la aplicación)

> El token es ficticio: el frontend no lo valida, solo lo reenvía. Sirve para
> revisar la interfaz. Para la lógica de negocio, usa la verificación por API
> del paso 9.

---

## 8. Verificación completa

### 8.1 Pruebas del backend

```powershell
cd services\panel-service
pytest tests -q
```

**Esperado: `79 passed`.** Las pruebas corren sobre SQLite en memoria: no
tocan MySQL ni requieren conexión externa.

| Archivo | Qué cubre |
|---|---|
| `unit/test_privacidad_k5.py` | La regla k=5: grupos y perfiles con menos de cinco estudiantes no se publican, y el contenido suprimido no se filtra |
| `unit/test_riesgo_por_perfil.py` | El cruce de nivel de riesgo por perfil, incluida la k=5 dentro de cada perfil |
| `unit/test_personal_externo.py` | La degradación si el servicio de usuarios no responde |
| `unit/test_evaluaciones_riesgo_client.py` | La degradación si el servicio de riesgo no responde, y el filtrado de respuestas con forma inválida |
| `unit/test_usuarios_client.py` | La resolución del identificador del estudiante y el escapado de la URL |
| `integration/test_auth.py` | 401 sin token, token con firma ajena, token expirado, `alg=none`, 403 por rol |
| `integration/test_registro_atencion.py` | Registro, asignación de cluster, validaciones, listado y filtros |
| `integration/test_estadisticas_informe.py` | k=5 en las respuestas, nota de IA, CSV con BOM y filas de total |

### 8.2 Verificación de extremo a extremo

```powershell
python scripts\verificacion_e2e.py
```

**Esperado: `VERIFICACION SUPERADA: todas las comprobaciones pasaron`** (26
comprobaciones). Levanta la aplicación, genera un token real y ejercita los
endpoints por HTTP.

### 8.3 Pruebas del frontend

```powershell
cd ..\..\web-panel\frontend
npm test              # 32 passed
npm run typecheck     # exit 0
npm run build         # exit 0
```

### 8.4 Comprobación manual de la regla k=5

Es la prueba más demostrativa, porque se contrasta la base de datos con la
respuesta de la API en dos pantallas.

```powershell
# 1. Registrar 6 atenciones de un tipo y 4 de otro (por API, con token)
$env:JWT_SECRET = "<el de tu .env>"
$H = @{ Authorization = "Bearer " + (node -e "const j=require('jsonwebtoken');console.log(j.sign({userId:1,role:'PERSONAL_UNAYOE'},process.env.JWT_SECRET,{expiresIn:'2h'}))") }

1..6 | ForEach-Object {
  $b = @{estudiante_codigo="2026$('{0:D4}' -f $_)"; modalidad="presencial"; tipo="orientacion";
         fecha_atencion="2026-03-15T10:00:00";
         indicadores=@{phq9=8;gad7=6;online_stress=6;financial_stress=5;exercise_freq=3;social_activity=6;sleep_hours=7}} | ConvertTo-Json -Depth 4
  Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:5003/api/panel/atencion" -Headers $H -ContentType "application/json" -Body $b | Out-Null
}

# 2. Lo que HAY en la base de datos
docker exec panel-mysql mysql -upanel_app -pclave-panel-app db_panel -e "SELECT tipo, COUNT(*) n FROM atenciones GROUP BY tipo;"

# 3. Lo que VE el panel
(Invoke-RestMethod -Uri "http://127.0.0.1:5003/api/panel/estadisticas" -Headers $H) | ConvertTo-Json -Depth 4
```

**Esperado:** el grupo de 4 **existe** en la base de datos pero **no aparece**
en `por_tipo`, y `grupos_omitidos_por_privacidad` es mayor que cero.

### 8.5 Aislamiento de datos

```powershell
docker exec panel-mysql mysql -upanel_app -pclave-panel-app -e "SHOW DATABASES;"
```

Solo debe listar `db_panel` e `information_schema` / `performance_schema`.
**No** debe aparecer `db_users` ni ninguna otra base del proyecto.

---

## 9. Imagen Docker (opcional)

```powershell
cd services\panel-service
docker build -t panel-service:latest .

docker run -d --name panel-svc -p 5003:5003 --env-file .env panel-service:latest
```

En Docker Desktop, el contenedor usa `host.docker.internal` para alcanzar un
MySQL del host:

```powershell
docker run -d --name panel-svc -p 5004:5003 --env-file .env -e DB_HOST=host.docker.internal panel-service:latest
```

Comprobar que el `.env` **no** quedó dentro de la imagen:

```powershell
docker run --rm --entrypoint sh panel-service:latest -c "ls -a /app | grep -c '^\.env$'"
```

**Esperado: `0`.** Existe un `.dockerignore` precisamente para esto.

---

## 10. Modelo de agrupamiento

```powershell
cd services\panel-service

# Verificar la integridad del dataset
python ml\download_dataset.py

# Reentrenar (reproduce exactamente los mismos números)
python ml\train_clustering.py
```

**Salida esperada:**
```
Modelo principal  : K-Means k=8 silueta=0.103353 davies=1.797103
Linea base        : jerarquico k=2 silueta=0.059057 davies=3.803741
```

La metodología completa está en [`ml/README.md`](ml/README.md).

---

## 11. Modelo de datos

Base de datos propia `db_panel`, una sola tabla:

| Columna | Tipo | Notas |
|---|---|---|
| `id` | INT PK AI | |
| `estudiante_codigo` | VARCHAR(50) | Referencia al estudiante. **No** se guardan nombres ni correos |
| `estudiante_id` | INT NULL | Identificador numérico del servicio de usuarios, resuelto por HTTP. Permite correlacionar con el nivel de riesgo |
| `modalidad` | VARCHAR(20) | presencial, virtual, telefonica, correo |
| `tipo` | VARCHAR(30) | orientacion, seguimiento, derivacion, evaluacion, emergencia |
| `estado` | VARCHAR(20) | registrada, en_seguimiento, cerrada |
| `phq9` … `sleep_hours` | DOUBLE NULL | Los 7 indicadores del contrato de riesgo, opcionales |
| `cluster_id` | INT NULL | Perfil asignado por el modelo. Nulo si no hubo indicadores |
| `notas` | TEXT NULL | Notas internas de gestión |
| `seguimiento_requerido` | BOOLEAN | |
| `registrado_por` | VARCHAR(120) NULL | Identidad de quien registró, resuelta por HTTP |
| `fecha_atencion` | DATETIME | |
| `fecha_creacion` | DATETIME | |
| `periodo` | VARCHAR(7) | `YYYY-MM`, derivado de `fecha_atencion` en Python |

---

## 12. Endpoints

Base `/api/panel`. Todos exigen `Authorization: Bearer <jwt>` con rol
`PERSONAL_UNAYOE` o `ADMINISTRADOR`, salvo `/api/panel/health`.

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/panel/atencion` | Registra una atención. `201` |
| GET | `/api/panel/estadisticas` | KPIs, distribuciones y perfiles de IA. `200` |
| GET | `/api/panel/informe` | Informe CSV del periodo. `200` |
| GET | `/api/panel/atenciones` | Listado paginado con filtros. `200` |
| GET | `/api/panel/health` | Estado del servicio y de la base de datos. `200` / `503` |

Parámetro opcional `?periodo=YYYY-MM` en estadísticas, informe y listado.

Especificación completa: `openapi/panel.yaml` (raíz del repositorio).

---

## 13. Publicar en GitHub

```powershell
cd "C:\Users\EQUIPO\Documents\Proyectos personales\Taller Sociales\g7-riesgo-ansiedad-social"

# Revisar qué se va a subir
git status
git diff --stat

# Confirmar que los .env NO se incluyen
git check-ignore -v services/panel-service/.env web-panel/frontend/.env

# Preparar
git add .gitignore
git add openapi/
git add services/panel-service
git add services/users/src
git add services/riskEvaluation/src
git add web-panel

# REVISAR ANTES DE COMMITEAR
git status                    # <- ningún .env debe aparecer
git diff --cached --stat

# Commit
git commit -m "feat(panel): Modulo 4 Panel Institucional y Analitica

- Microservicio Flask panel-service con Clean Architecture y MySQL propia
- Modelo de agrupamiento K-Means (k=8) sobre dataset Kaggle CC0, exportado
  como Pipeline(StandardScaler, KMeans) y cargado por el backend
- Regla de privacidad k=5 en la capa de dominio, aplicada tambien a las
  celdas de nivel de riesgo dentro de cada perfil
- Frontend React del panel institucional con barra lateral, rutas preparadas
  (/orientacion, /citas, /agenda) y porcentaje por perfil
- Integracion por HTTP con users y riskEvaluation, con degradacion segura
- OpenAPI: nuevo panel.yaml y documentacion de los endpoints agregados"

# Publicar
git push -u origin feature/panel-gerardo
```

> Si el push pide contraseña, usa un **Personal Access Token** de GitHub, no
> tu contraseña normal.

---

## 14. Pendiente de despliegue (no corresponde a este módulo)

Estas tareas son de infraestructura y las realiza el equipo:

| Tarea | Por qué |
|---|---|
| Publicar `/panel` en Azure API Management | El frontend en producción llama al gateway |
| Entregar `VITE_APIM_SUBSCRIPTION_KEY` | Sin clave el frontend no puede llamar al gateway |
| Desplegar `panel-service` en Render | Hoy solo existe la imagen Docker local |
| Redesplegar `users` y `riskEvaluation` | Los endpoints `by-code` y `summary` son nuevos |
| Crear el usuario institucional | Requiere `UPDATE` en la base de datos de `users` |

**Mientras tanto**, el panel funciona por completo salvo la correlación de
riesgo: sin `riskEvaluation` desplegado, la columna «Riesgo» muestra «Sin
correlación» y `riesgo_disponible` es `false`. Es una degradación
deliberada, no un fallo.

---

## 15. Estructura

```text
services/panel-service/
├── app/
│   ├── domain/                    # Sin dependencias de frameworks
│   │   ├── entities/              # Atencion, PerfilCluster
│   │   └── services/              # privacidad_k5 (regla k=5), fecha_hora (UTC)
│   ├── application/               # Casos de uso y puertos (interfaces)
│   │   ├── interfaces/            # 5 puertos: atenciones, clustering, riesgo, usuarios, personal
│   │   └── use_cases/             # 5 casos de uso
│   ├── infrastructure/            # Adaptadores concretos
│   │   ├── persistence/           # SQLAlchemy
│   │   ├── ml/                    # Carga del modelo .joblib + artefactos
│   │   └── clients/               # Clientes HTTP (usuarios, riesgo, personal)
│   ├── presentation/              # Rutas, DTOs Pydantic, middleware JWT
│   └── config/settings.py         # Configuración desde .env
├── db/schema.sql                  # Esquema versionado
├── scripts/
│   ├── init_db.py                 # Aplica esquema + migraciones (idempotente)
│   └── verificacion_e2e.py        # 26 comprobaciones end-to-end
├── ml/                            # Entrenamiento del modelo
│   ├── train_clustering.py
│   ├── download_dataset.py
│   ├── data/mental_health_indicators.csv
│   └── resultados/comparativa.json
├── tests/                         # 79 pruebas
├── Dockerfile
├── requirements.txt
├── .env.example
└── run.py

web-panel/frontend/
├── src/
│   ├── app/                       # AppShell (barra lateral), AuthContext, RutaProtegida, navegación
│   ├── components/                # Avisos (IA, k=5), Gráficos (SVG sin librería)
│   ├── pages/                     # Login, Dashboard, RegistroAtencion, Informes, Preparada
│   ├── services/                  # Cliente HTTP y operaciones del panel
│   ├── types.ts  validation.ts  config.ts  styles.css
└── package.json
```

---

## 16. Resumen de verificación

| Comprobación | Comando | Resultado esperado |
|---|---|---|
| Instalación | `pip install -r requirements.txt` | Sin errores |
| Entorno | `python -c "import flask, sklearn"` | Sin errores |
| Esquema | `python scripts\init_db.py` | `Esquema aplicado correctamente` |
| Tabla | `DESCRIBE atenciones` | 21 columnas, 9 índices |
| Backend | `python run.py` | Escucha en el 5003 |
| Salud | `GET /api/panel/health` | `{"database":"OK",...}` |
| Tests backend | `pytest tests -q` | **79 passed** |
| E2E | `python scripts\verificacion_e2e.py` | 26/26 |
| Tests frontend | `npm test` | **32 passed** |
| Tipos | `npm run typecheck` | exit 0 |
| Build | `npm run build` | exit 0 |
| Modelo | `python ml\train_clustering.py` | k=8, silueta 0.103353 |
| Aislamiento | `SHOW DATABASES` | Solo `db_panel` |
| Imagen | `docker build` + `grep -c '^\.env$'` | `0` |
