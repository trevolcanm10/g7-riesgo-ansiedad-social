# Microservicio de Orientación Confidencial (Módulo M2 - UNAYOE FISI UNMSM)

Este microservicio forma parte de la plataforma de prevención del riesgo de ansiedad social de la FISI - UNMSM. Su objetivo es gestionar las solicitudes de orientación y acompañamiento redactadas por los estudiantes, clasificando el tema y la prioridad de atención mediante modelos locales de Inteligencia Artificial (Machine Learning), garantizando una privacidad estricta.

---

## Características Principales

*   **Arquitectura Limpia (Clean Architecture)**: Organizado en capas (Domain, Application, Infrastructure, API) para garantizar desacoplamiento, mantenibilidad e inyección de dependencias.
*   **Inferencia Local y Privacidad Estricta (RNF-07)**: Clasificación de texto mediante pipelines de `scikit-learn` (`.joblib`) ejecutados 100% de forma local. No se envían mensajes a APIs externas como Gemini.
*   **Detector de Urgencia Heurístico**: Analiza de forma autónoma frases críticas de riesgo ("no me siento seguro", "necesito ayuda ahora"). Al detectar coincidencia, fuerza la prioridad sugerida a `alta` e inyecta números institucionales de auxilio (UNAYOE, MINSA 113, SAMU 106).
*   **Validación Estricta de Datos**: Integración de **Pydantic** para la validación declarativa de Payloads en los endpoints.
*   **Intervención Humana (Human-in-the-Loop)**: Permite que el personal de UNAYOE confirme o sobrescriba el tema y la prioridad sugeridos por el modelo antes de cerrar el caso.
*   **Persistencia Dedicada**: Conexión a MySQL (`db_orientacion`) mediante `Flask-SQLAlchemy` y `PyMySQL`.
*   **Despliegue con Docker y Gunicorn**: Configurado con usuario no root (OWASP Docker Security) y preparado para producción con servidor WSGI Gunicorn.

---

## Stack Tecnológico

*   **Lenguaje**: Python 3.11
*   **Framework Web**: Flask v3.0.0
*   **ORM / Conector BD**: Flask-SQLAlchemy v3.1.1 / PyMySQL v1.1.0
*   **Machine Learning**: Scikit-Learn v1.6.1 / Joblib v1.3.2
*   **Validación**: Pydantic v2.5.2
*   **Pruebas**: Pytest v7.4.3 & Pytest-Mock
*   **WSGI / Contenedores**: Gunicorn v21.2.0 / Docker (python:3.11-slim)

---

## Estructura del Proyecto

```text
orientacion-service/
├── app/
│   ├── api/                    # Capa de Presentación / Controladores HTTP
│   │   ├── routes/             # Blueprints de Flask (solicitudes_router.py)
│   │   └── schemas/            # Esquemas de validación Pydantic
│   ├── application/            # Capa de Aplicación / Reglas del Negocio
│   │   ├── interfaces/         # Puertos/Contratos abstractos (Repo e IMLClassifier)
│   │   └── use_cases/          # Casos de uso del módulo (crear, atender, listar)
│   ├── domain/                 # Capa de Dominio Pura
│   │   └── entities/           # Entidades (SolicitudOrientacion, UrgenciaDomainService)
│   ├── infrastructure/         # Adaptadores Técnicos
│   │   ├── ml/                 # Adaptador Scikit-Learn y directorio /artifacts para .joblib
│   │   └── persistence/        # Repositorio SQLAlchemy y modelos de BD
│   └── config/                 # Configuración de variables de entorno (settings.py)
├── tests/                      # Suite de Pruebas Automatizadas
│   ├── unit/                   # Pruebas unitarias de lógica y Mocks
│   ├── integration/            # Pruebas de integración HTTP (SQLite en memoria)
│   └── conftest.py             # Fixtures globales de Pytest
├── Dockerfile                  # Imagen Docker optimizada para producción
├── requirements.txt            # Dependencias fijadas del proyecto
├── .env.example                # Plantilla de variables de entorno
└── run.py                      # Punto de entrada de la aplicación
```

---

## Configuración y Ejecución Local

### 1. Variables de Entorno
Copia el archivo `.env.example` a un archivo `.env` en la raíz de este directorio:
```bash
cp .env.example .env
```
Configura tus credenciales locales de MySQL:
```env
DB_USER=root
DB_PASS=tu_contraseña
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=db_orientacion
```

### 2. Instalación de Dependencias
```bash
pip install -r requirements.txt
```

### 3. Artefactos de Machine Learning
Coloca los archivos de modelo entrenados en la carpeta de artefactos:
*   `app/infrastructure/ml/artifacts/modelo_tema.joblib`
*   `app/infrastructure/ml/artifacts/modelo_prioridad.joblib`

*(Nota: Si no se encuentran los archivos `.joblib`, el servicio utilizará automáticamente un fallback heurístico sin romper la ejecución).*

### 4. Iniciar el Servidor
```bash
python run.py
```
El servicio iniciará en: `http://127.0.0.1:5000`

---

## Pruebas Automatizadas (Pytest)

Las pruebas ejecutan la suite sobre una base de datos **SQLite en memoria RAM (`sqlite:///:memory:`)**, sin modificar tu base de datos MySQL de producción ni requerir conexión externa:

```bash
pytest tests/ -v
```

---

## Ejecución con Docker

### Construir la imagen:
```bash
docker build -t orientacion-service:latest .
```

### Ejecutar el contenedor:
```bash
docker run -d -p 5002:5002 --env-file .env orientacion-service:latest
```

---

## Documentación de Endpoints REST

| Método | Endpoint | Descripción |
|---|---|---|
| **POST** | `/api/v1/orientacion/solicitudes` | Registra una nueva solicitud, ejecuta inferencia ML local y evaluación de urgencia. |
| **GET** | `/api/v1/orientacion/solicitudes` | Lista las solicitudes para la bandeja del orientador (ordenadas por prioridad alta y fecha desc). Soporta filtros `?estado=pendiente` o `?prioridad=alta`. |
| **GET** | `/api/v1/orientacion/solicitudes/<id>` | Obtiene el detalle completo de una solicitud por su ID. |
| **PATCH** | `/api/v1/orientacion/solicitudes/<id>/atender` | Permite al orientador responder, confirmar/corregir tema y prioridad, y cambiar el estado a "atendida". |
| **GET** | `/api/v1/orientacion/solicitudes/metricas/conteo-temas` | Retorna el conteo agrupado por tema (sugerido o confirmado) para el módulo de analítica. |
