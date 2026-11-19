# academic-support

Microservicio M5 de apoyo académico y talleres para recomendar tutorías entre pares, talleres y materiales. Implementado con Python 3.12, Flask y MySQL propio, con capas de dominio, aplicación, infraestructura y presentación.

## Alcance

- Catálogo de tutorías, talleres y materiales.
- Preferencias explícitas por temas, cursos, disponibilidad horaria, zona horaria y modalidad.
- Recomendaciones explicables basadas en contenido.
- Filtrado colaborativo item-item cuando el catálogo ya tiene interacciones suficientes; si no hay señal personal, usa popularidad como línea base.
- Publicación y cancelación de recursos con permisos por rol.
- Inscripción de estudiantes a talleres con cupos y protección contra duplicados.
- Registro de interacciones para alimentar recomendaciones futuras.

Este servicio guarda solo el identificador de usuario que recibe en el JWT, las preferencias académicas/de actividades, los recursos y las interacciones. No consulta ni almacena nombres, correos o indicadores de salud; no usa evaluaciones de riesgo para recomendar.

## Recomendador

La primera versión combina atributos explícitos del recurso con los intereses del estudiante. Normaliza mayúsculas y acentos, y calcula coincidencias con pesos iniciales: intereses (45 %), cursos (35 %), disponibilidad horaria (15 %) y modalidad (5 %). Los pesos se renormalizan si el estudiante no completa todos los campos. La popularidad (vistas, clics, inscripciones y finalizaciones) aporta un desempate pequeño. El score es una puntuación relativa de ordenamiento, no una probabilidad ni una medida de eficacia.

Cuando existen interacciones compartidas entre estudiantes, calcula similitud coseno item-item sobre interacciones implícitas. En ese caso, el resultado combina 75 % de la puntuación por contenido/popularidad y 25 % de la señal colaborativa. Eventos usados: vista = 1, clic = 2, inscripción = 4 y finalización = 3. El motor no crea interacciones al mostrar una recomendación: el cliente registra vistas/clics de forma explícita mediante POST /interactions.

Para que las llamadas repetidas no inflen el ranking, cada combinación de usuario, recurso y tipo de evento aporta como máximo una vez por consulta. El endpoint aún conserva cada llamada recibida en el historial; configura límites de peticiones en el gateway para proteger el almacenamiento.

Cada consulta del recomendador considera como máximo los 2 000 recursos publicados más recientes y hasta 50 000 interacciones de los últimos 180 días. Son límites operativos de esta versión inicial; con un catálogo mayor conviene precalcular similitudes o agregarlas en la base de datos.

Modos de salida:

- CONTENT_BASED: hay preferencias y aún no existe señal colaborativa útil.
- HYBRID: se pueden combinar contenido y similitud item-item.
- POPULARITY_FALLBACK: el estudiante aún no tiene preferencias ni historial útil.
- NO_CATALOG: no hay recursos publicados disponibles.

Los datos de seed_demo.sql son sintéticos y solo permiten probar el catálogo. Los pesos son una línea base inicial, no métricas validadas con estudiantes. La evaluación offline reproducible con perfiles sintéticos y sus límites están en `ml/evaluation_report.md`; ejecútala con `python ml/evaluate_recommender.py` desde esta carpeta. El estado del arte resumido está en `../../docs/Estado_del_Arte_Apoyo_Academico.md`. No presentes los resultados sintéticos como rendimiento real.

Los códigos de curso y etiquetas en el catálogo demostrativo son ejemplos. Sustitúyelos por el catálogo aprobado por FISI/UNAYOE antes de una demostración institucional.

## Contrato HTTP

El contrato completo está en ../../openapi/academic-support.yaml.

| Método y ruta | Función | Acceso |
|---|---|---|
| GET /health | Estado del servicio y la base | Público |
| GET /resources | Catálogo, filtros y paginación | JWT |
| GET /resources/{id} | Ver un recurso publicado | JWT |
| POST /resources | Publicar tutoría/taller/material | JWT; estudiante: una tutoría publicada |
| PATCH /resources/{id} | Editar recurso | Personal UNAYOE/admin; dueño de tutoría |
| DELETE /resources/{id} | Cancelar recurso sin borrar historial | Personal UNAYOE/admin; dueño de tutoría |
| GET /students/me/preferences | Consultar preferencias | Estudiante |
| PUT /students/me/preferences | Reemplazar preferencias | Estudiante |
| GET /recommendations?limit=10 | Obtener recomendaciones personalizadas | Estudiante |
| POST /interactions | Registrar vista, clic, finalización o descarte | Estudiante |
| GET /students/me/enrollments | Consultar inscripciones activas | Estudiante |
| POST /workshops/{id}/enroll | Inscribirse si existe cupo | Estudiante |
| DELETE /workshops/{id}/enroll | Cancelar inscripción | Estudiante |

Los campos JSON usan camelCase. Cada endpoint protegido verifica el JWT HS256 emitido por users usando el mismo JWT_SECRET. El identificador y rol se toman del token, nunca del cuerpo de la petición.

### Preferencias

PUT /students/me/preferences reemplaza el conjunto completo; omitir una lista equivale a dejarla vacía.

- interests: lista de etiquetas como ["programación", "comunicación"].
- courseCodes: códigos de curso como ["INF101"].
- availableSlots: bloques en hora local de timeZone; weekday usa 0=lunes…6=domingo, horas HH:MM.
- preferredModalities: valores PRESENCIAL, REMOTO, HIBRIDO.
- timeZone: zona IANA; por defecto America/Lima.

Ejemplo:

    {
      "interests": ["programación", "técnicas de estudio"],
      "courseCodes": ["INF101"],
      "availableSlots": [
        {"weekday": 2, "startTime": "15:00", "endTime": "18:00"}
      ],
      "preferredModalities": ["REMOTO"],
      "timeZone": "America/Lima"
    }

### Recursos

Tipos permitidos: TUTORING, WORKSHOP y MATERIAL. Talleres y tutorías requieren inicio/fin ISO 8601 con zona horaria, modalidad y location si son presenciales o híbridos. Talleres requieren capacity positiva. Materiales requieren URL HTTP/HTTPS. Todos los recursos tienen título, descripción y lista de etiquetas. Los códigos de curso son opcionales.

Un estudiante puede mantener solo una oferta de tutoría propia publicada. Para publicar otra, debe cancelar la anterior. Personal UNAYOE y administradores pueden publicar los tres tipos. La API no permite que el cliente elija creatorUserId, status o isSynthetic.

## Configuración local

Requisitos: Python 3.12 y MySQL 8.0.

Desde la raíz del repositorio, en Git Bash:

    cd services/academic-support
    python -m venv .venv
    source .venv/Scripts/activate
    python -m pip install -r requirements.txt
    cp .env.example .env

Configura `.env` con las variables de `.env.example`. Puedes usar el mismo servidor MySQL que `users`, pero este microservicio debe tener su propia base (`DB_NAME=academic_support`) y una cuenta con permisos limitados sobre ella. No apuntes `DB_NAME` a la base de `users` ni guardes credenciales en el repositorio. `JWT_SECRET` sí debe coincidir exactamente con el de `users` para validar sus tokens.

Para una instancia MySQL remota que requiera TLS, configura `DB_SSL=true`; el cliente valida el certificado y el nombre del servidor. Si la instancia usa una autoridad certificadora privada, define `DB_SSL_CA` con la ruta al certificado CA en formato PEM. En una base local de desarrollo puede dejarse `DB_SSL=false`.

Crea primero la base de datos. Aplica schema.sql con una cuenta de migraciones que tenga permisos DDL; configura la cuenta de ejecución del servicio con permisos DML limitados a esa base. Si necesitas ejemplos, carga el catálogo sintético:

    mysql -u migration_user -p academic_support < schema.sql
    mysql -u academic_support_app -p academic_support < seed_demo.sql
    python app.py

La configuración de conexión usa el mismo formato de variables (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`) que `services/users`; el archivo `.env` de ese servicio no se incluye en el repositorio. Reutiliza el host y puerto de la instancia compartida, crea la base `academic_support` y otorga permisos a una cuenta propia del microservicio. No copies ni publiques contraseñas en el chat o en Git.

Con `.env` configurado y `schema.sql` aplicado, puedes comprobar la conexión real, las cuatro tablas y la colación del esquema desde PowerShell:

    $env:ACADEMIC_SUPPORT_MYSQL_INTEGRATION = "1"
    python -m unittest discover -s tests -p test_mysql_live.py -v

Esta prueba consulta únicamente la base configurada y comprueba conexión, tablas, colación y GET_LOCK (adquisición y liberación). Sin la variable de activación, se omite durante la suite normal de pruebas.

También hay pruebas de integración del repositorio que crean y eliminan datos de prueba. Ejecútalas solo contra una base aislada cuyo nombre termine en `_test` (por ejemplo, `academic_support_test`), con `schema.sql` aplicado:

    $env:DB_NAME = "academic_support_test"
    $env:ACADEMIC_SUPPORT_MYSQL_INTEGRATION = "1"
    python -m unittest discover -s tests -p test_mysql_repository_integration.py -v

Estas pruebas cubren filtros SQL, preferencias, edición/cancelación, la oferta única de tutoría por estudiante y la concurrencia sobre el último cupo. Se niegan a ejecutarse si `DB_NAME` no termina en `_test`.

El servidor escucha en http://localhost:5003. GET /health devuelve 503 si MySQL no está disponible. Para producción, usa Gunicorn o la imagen Docker incluida; no uses el servidor de desarrollo de Flask.

Variables:

- PORT: puerto HTTP, por defecto 5003.
- DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD: conexión a la base propia.
- DB_SSL: requiere y valida TLS para MySQL remoto; por defecto es false para desarrollo local.
- DB_SSL_CA: ruta opcional a la CA PEM de una instancia con certificados privados.
- JWT_SECRET: secreto compartido con users para verificar tokens.

El archivo .env local está ignorado por Git. app.py carga el .env de esta carpeta y no reemplaza variables ya definidas en el entorno del proceso.

## Integración

- La aplicación móvil debe usar el token Bearer existente y enviar las preferencias antes de pedir recomendaciones.
- APIM debe publicar este backend como ruta propia; el gateway y el despliegue Azure quedan configurados por el responsable transversal. No se inventa aquí una URL de producción.
- Los IDs de curso, tags y catálogo deben acordarse con el equipo. El código no modifica users, riskEvaluation, prediction-ml ni sus contratos.


## Preparación de despliegue en Render

El Blueprint está en render.yaml. Al crear el Blueprint en Render, selecciona services/academic-support/render.yaml; queda en la subcarpeta del microservicio para no afectar otros servicios del monorepo. La configuración construye la imagen con el Dockerfile del servicio y comprueba GET /health.

Antes de desplegar, crea una base propia para este servicio y aplica schema.sql con una cuenta de migraciones. Luego configura de forma privada DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD y el mismo JWT_SECRET que usa Users. El Blueprint marca esos valores como sync:false para no guardarlos en Git. DB_SSL está activo para conexión TLS. DB_SSL_CA solo se configura en Render si la base usa una autoridad certificadora privada.

La comprobación de salud consulta MySQL, así que el esquema y las variables deben estar listos antes de que el servicio pase el health check. Render no ejecuta schema.sql automáticamente. El APIM no está incluido porque el equipo aún debe asignar el prefijo y la URL pública.

### Compatibilidad con TiDB

La documentación oficial de TiDB lista GET_LOCK entre las funciones de bloqueo de usuario y establece un tiempo mínimo de espera de 1 segundo. El servicio usa 5 segundos. La colación utf8mb4_0900_ai_ci de schema.sql requiere TiDB 7.4.0 o posterior; para una versión anterior habrá que elegir una colación compatible y actualizar la expectativa de la prueba live.

Antes del despliegue, configura una base de prueba aislada cuyo nombre termine en _test y activa ACADEMIC_SUPPORT_MYSQL_INTEGRATION=1. Las pruebas live comprueban conexión, tablas, colación y adquisición de GET_LOCK; las pruebas de integración del repositorio cubren concurrencia. No ejecutes las pruebas que crean datos sobre la base de producción.

Referencias: [funciones de bloqueo de TiDB](https://docs.pingcap.com/tidb/v8.1/locking-functions/) y [juegos de caracteres y colaciones de TiDB](https://docs.pingcap.com/tidb/stable/character-set-and-collation/).
