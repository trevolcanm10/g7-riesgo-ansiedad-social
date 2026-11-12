# Prototipo individual del recomendador

Prototipo local y navegable para presentar el módulo M5 de recomendación de actividades académicas. Usa un catálogo sintético en el navegador; no requiere instalación, credenciales ni conexión a MySQL.

## Abrir

Abre `index.html` en un navegador. Cambia intereses, curso, modalidad o disponibilidad y pulsa **Actualizar recomendaciones**. Las tarjetas muestran afinidad y motivos; los botones de inscripción y guardado solo simulan la interacción.

## Correspondencia con la API M5

- Preferencias: `PUT /students/me/preferences`
- Obtener recomendaciones: `GET /recommendations`
- Guardar una interacción: `POST /interactions`
- Inscripción real a un taller: `POST /workshops/{id}/enroll`

La interfaz es una demostración aislada. No pretende reemplazar la demo integrada ni llamar al backend; la integración puede hacerse después mediante la API documentada.
