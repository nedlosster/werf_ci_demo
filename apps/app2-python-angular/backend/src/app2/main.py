import os

import psycopg
from fastapi import FastAPI

from app2._version import __version__

# Swagger под /api -- так он доступен через ingress (/api -> backend).
app = FastAPI(
    title="app2-python-angular",
    docs_url="/api/docs",
    openapi_url="/api/openapi.json",
    redoc_url=None,
)


def _connect():
    return psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "app2"),
        user=os.getenv("DB_USER", "app2"),
        password=os.getenv("DB_PASSWORD", "app2pass"),
    )


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/api/v1/hello")
def hello() -> dict:
    return {
        "app": "app2-python-angular",
        "stack": "FastAPI (Python)",
        "message": "привет из бекенда app2",
    }


@app.get("/api/v1/version")
def version() -> dict:
    return {"version": __version__}


@app.get("/api/v1/items")
def items() -> list[dict]:
    with _connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, name, note FROM items ORDER BY id")
        rows = cur.fetchall()
    return [{"id": r[0], "name": r[1], "note": r[2]} for r in rows]
