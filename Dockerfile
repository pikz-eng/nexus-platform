FROM python:3.11-slim

WORKDIR /app

# Creăm utilizatorul non-root 10001 conform securityContext din K8s
RUN groupadd -g 10001 appgroup && \
useradd -u 10001 -g appgroup -s /bin/sh -m appuser

COPY src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

USER 10001

EXPOSE 8080

CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]
