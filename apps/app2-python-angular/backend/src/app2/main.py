from fastapi import FastAPI

from app2._version import __version__

app = FastAPI(title="app2-python-angular")


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
