from __future__ import annotations

from fastapi import FastAPI

from app.routers import auth, commands, day, transcriptions

app = FastAPI(title="Projeto Jubileu API", version="0.1.0", openapi_url="/v1/openapi.json", docs_url="/docs")
app.include_router(auth.router, prefix="/v1")
app.include_router(commands.router, prefix="/v1")
app.include_router(day.router, prefix="/v1")
app.include_router(transcriptions.router, prefix="/v1")


@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok"}
