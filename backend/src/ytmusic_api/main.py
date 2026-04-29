from __future__ import annotations

import asyncio
import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from importlib.metadata import version as _pkg_version

from fastapi import FastAPI

from .auth.check import make_real_check
from .auth.headers import HeadersStore
from .auth.health import AuthHealthMonitor
from .config import get_settings
from .routers import admin, catalog, health
from .services.cache import TtlCache
from .services.ytmusic_client import YTMusicClient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

API_VERSION = _pkg_version("ytmusic-api")


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    store = HeadersStore(path=settings.yt_headers_path)
    ytm = YTMusicClient(store)
    cache = TtlCache()
    monitor = AuthHealthMonitor(
        check=make_real_check(ytm),
        interval=settings.auth_health_interval,
    )

    app.state.headers_store = store
    app.state.ytmusic_client = ytm
    app.state.cache = cache
    app.state.auth_monitor = monitor

    watch_task = asyncio.create_task(store.watch())
    monitor_task = asyncio.create_task(monitor.run())

    try:
        yield
    finally:
        monitor.stop()
        watch_task.cancel()
        await monitor_task
        try:
            await watch_task
        except asyncio.CancelledError:
            pass


def create_app(
    *,
    headers_store: HeadersStore | None = None,
    auth_monitor: AuthHealthMonitor | None = None,
    ytmusic_client: YTMusicClient | None = None,
    cache: TtlCache | None = None,
) -> FastAPI:
    """App factory.

    Test code can pass any subset of dependencies; lifespan is bypassed if
    both `headers_store` AND `auth_monitor` are provided.
    """
    use_lifespan = headers_store is None or auth_monitor is None

    app = FastAPI(
        title="yt-music-api",
        version=API_VERSION,
        lifespan=lifespan if use_lifespan else None,
    )

    if not use_lifespan:
        app.state.headers_store = headers_store
        app.state.auth_monitor = auth_monitor
        app.state.ytmusic_client = ytmusic_client
        app.state.cache = cache or TtlCache()

    app.include_router(health.router, prefix="/v1")
    app.include_router(catalog.router, prefix="/v1")
    app.include_router(admin.router)
    return app


app = create_app()
