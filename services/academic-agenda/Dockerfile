FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src ./src
COPY app.py .

ENV FLASK_ENV=production
ENV DB_ENABLED=false
EXPOSE 5003
CMD ["sh", "-c", "exec gunicorn --workers 1 --bind 0.0.0.0:${PORT:-5003} 'app:create_app()'"]
