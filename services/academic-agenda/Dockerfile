FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src ./src
COPY app.py .

ENV FLASK_ENV=production
ENV DB_ENABLED=true
ENV DB_SSL=true
EXPOSE 5003
CMD ["sh", "-c", "exec gunicorn --workers 1 --bind 0.0.0.0:${PORT:-5003} 'app:create_app()'"]
