from importlib.metadata import version as _pkg_version

from fastapi import FastAPI

from .routers import health

API_VERSION = _pkg_version("ytmusic-api")


def create_app() -> FastAPI:
    app = FastAPI(title="yt-music-api", version=API_VERSION)
    app.include_router(health.router, prefix="/v1")
    return app


app = create_app()
