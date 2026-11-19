# 1. Imagen base oficial, ligera y segura
FROM python:3.11-slim

# 2. Variables de entorno optimizadas para Python en contenedores
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=5002
ENV FLASK_DEBUG=false

# 3. Crear usuario no root por seguridad (OWASP Docker Security)
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 4. Establecer y preparar el directorio de trabajo
WORKDIR /app
RUN chown appuser:appuser /app

# 5. Instalar dependencias de producción
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 6. Copiar el código y los artefactos .joblib
COPY --chown=appuser:appuser . .

# 7. Cambiar al usuario no root
USER appuser

# 8. Exponer el puerto
EXPOSE $PORT

# 9. Iniciar el microservicio con Gunicorn para producción
CMD ["sh", "-c", "gunicorn --bind 0.0.0.0:${PORT} --workers 2 --threads 4 --timeout 120 'run:create_app()'"]
