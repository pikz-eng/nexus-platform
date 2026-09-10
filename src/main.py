import os
from fastapi import FastAPI

app = FastAPI(title="Nexus Platform API")

@app.get("/")
def read_root():
    secret_path = "/vault/secrets/db-creds"
    vault_injected = os.path.exists(secret_path)
    db_user = None

    if vault_injected:
        try:
            with open(secret_path, "r") as f:
                for line in f:
                    if line.startswith("DB_USER="):
                        db_user = line.strip().split("=")[1]
        except Exception:
            pass

    return {
        "app": "nexus-platform",
        "environment": os.getenv("APP_ENV", "unknown"),
        "status": "healthy",
        "vault_secret_injected": vault_injected,
        "database_user": db_user
    }

@app.get("/health")
def health_check():
    return {"status": "ok"}
