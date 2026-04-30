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
from .routers import admin, catalog, health, library, stream
from .services.cache import TtlCache
from .services.concurrency import BoundedRunner
from .services.pot_client import PotClient
from .services.stream_resolver import StreamResolver
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

    pot_client = PotClient(base_url=settings.pot_provider_url)
    stream_resolver = StreamResolver(pot_provider_url=settings.pot_provider_url)
    stream_runner = BoundedRunner(max_concurrent=3)

    app.state.headers_store = store
    app.state.ytmusic_client = ytm
    app.state.cache = cache
    app.state.auth_monitor = monitor
    app.state.pot_client = pot_client
    app.state.stream_resolver = stream_resolver
    app.state.stream_runner = stream_runner

    watch_task = asyncio.create_task(store.watch())
    monitor_task = asyncio.create_task(monitor.run())

    try:
        yield
    finally:
        await pot_client.aclose()
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
    stream_resolver: StreamResolver | None = None,
    stream_runner: BoundedRunner | None = None,
    pot_client: PotClient | None = None,
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
        app.state.stream_resolver = stream_resolver
        app.state.stream_runner = stream_runner
        app.state.pot_client = pot_client

    app.include_router(health.router, prefix="/v1")
    app.include_router(catalog.router, prefix="/v1")
    app.include_router(stream.router, prefix="/v1")
    app.include_router(library.router, prefix="/v1")
    app.include_router(admin.router)
    return app


app = create_app()
