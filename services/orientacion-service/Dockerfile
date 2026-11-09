# 1. Imagen base oficial, ligera y segura
FROM python:3.11-slim

# 2. Variables de entorno optimizadas para Python en contenedores
# Evita que Python escriba archivos .pyc en el disco
ENV PYTHONDONTWRITEBYTECODE=1
# Evita que Python guarde en búfer stdout y stderr, ideal para logs en tiempo real en Docker
ENV PYTHONUNBUFFERED=1
# Puerto por defecto a exponer
ENV PORT=5002

# 3. Crear usuario no root por seguridad (OWASP Docker Security)
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 4. Establecer y preparar el directorio de trabajo
WORKDIR /app
RUN chown appuser:appuser /app

# 5. Instalar dependencias del sistema y copiar requirements
# Copiamos solo el requirements primero para aprovechar la caché de capas de Docker
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 6. Copiar el resto del código de la aplicación
COPY --chown=appuser:appuser . .

# (NOTA: Los archivos .joblib están dentro de /app/app/infrastructure/ml/artifacts/ según nuestra Clean Architecture.
# Serán copiados junto con el resto del código arriba).

# 7. Cambiar al usuario no root
USER appuser

# 8. Exponer el puerto
EXPOSE $PORT

# 9. Iniciar el microservicio con Gunicorn para producción
# Se usan 2 workers y hilos para manejar peticiones concurrentemente
CMD ["sh", "-c", "gunicorn --bind 0.0.0.0:${PORT} --workers 2 --threads 4 --timeout 120 'run:create_app()'"]
