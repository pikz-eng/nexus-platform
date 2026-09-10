import os
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="Nexus Platform API", version="1.0.0")

def get_vault_db_creds():
secret_path = "/vault/secrets/db-creds"
creds = {"mounted": False, "username": None}
if os.path.exists(secret_path):
    creds["mounted"] = True
    try:
        with open(secret_path, "r") as f:
            for line in f:
                if line.startswith("DB_USER="):
                    creds["username"] = line.strip().split("=", 1)[1]
    except Exception as e:
        creds["error"] = str(e)
return creds

@app.get("/")
def read_root():
vault_status = get_vault_db_creds()
return {
    "app": "nexus-platform",
    "environment": os.getenv("APP_ENV", "production"),
    "status": "healthy",
    "vault_secret_injected": vault_status["mounted"],
    "database_user": vault_status.get("username", "none")
}

@app.get("/healthz")
def healthz():
return {"status": "ok"}

@app.get("/readyz")
def readyz():
return {"ready": True}
