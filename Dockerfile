FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src ./src
COPY app.py .
COPY /tmp/run_app.py /run_app.py

ENV PORT=5003

EXPOSE 5003

ENV FLASK_ENV=production

ENTRYPOINT ["python", "/run_app.py"]
