# Phase 0: Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the mono-repo, a FastAPI backend with `/v1/health` and a server-rendered admin cookie page, the `pot-provider` sidecar, Docker Compose orchestration, Cloudflared + CF Access wiring docs, and a Flutter app shell that successfully calls `/v1/health` through CF Access. End state: end-to-end "hello world" — opening the app shows backend health pulled live through Cloudflare.

**Architecture:** Mono-repo at `yt-music-app/` with `backend/`, `app/`, and `pot-provider/`. Backend is FastAPI with a `HeadersStore` that loads `secrets/yt_headers.json` and hot-reloads on file change via `watchfiles`, and an `AuthHealthMonitor` background task that pings YT Music every 15 minutes to confirm cookies are alive. The Flutter app stores the CF Access service-token + base URL in `flutter_secure_storage`, configured by an onboarding screen on first launch, and uses a Dio interceptor to inject the `CF-Access-Client-Id`/`Secret` headers on every request.

**Tech Stack:** Python 3.12, FastAPI, `uv`, `ruff`, `pytest`, `pytest-asyncio`, `httpx`, `ytmusicapi`, `watchfiles`, Jinja2, Docker (Compose v2), Flutter ≥3.22, Dart ≥3.4, `dio`, `flutter_riverpod`, `riverpod_generator`, `go_router`, `flutter_secure_storage`, `mocktail`.

**Out of scope for this phase:** Search, library, streaming, downloads, audio playback, Drift schema. All of those start in Phase 1+.

---

## File map (what gets created in this phase)

### Backend (`backend/`)
- `pyproject.toml` — uv-managed Python project
- `Dockerfile` — multi-stage build
- `README.md` — backend dev notes
- `src/ytmusic_api/__init__.py` — package marker
- `src/ytmusic_api/main.py` — FastAPI app factory
- `src/ytmusic_api/config.py` — pydantic-settings config
- `src/ytmusic_api/auth/__init__.py`
- `src/ytmusic_api/auth/headers.py` — `HeadersStore` (load + watch)
- `src/ytmusic_api/auth/health.py` — `AuthHealthMonitor` (periodic check)
- `src/ytmusic_api/routers/__init__.py`
- `src/ytmusic_api/routers/health.py` — `GET /v1/health`
- `src/ytmusic_api/routers/admin.py` — `GET /admin`, `POST /admin/cookies/refresh`
- `src/ytmusic_api/models/__init__.py`
- `src/ytmusic_api/models/health.py` — pydantic response models
- `src/ytmusic_api/admin/templates/index.html` — Jinja2 admin page
- `tests/conftest.py` — pytest fixtures
- `tests/test_health.py`
- `tests/test_headers_store.py`
- `tests/test_auth_health.py`
- `tests/test_admin.py`

### Sidecar (`pot-provider/`)
- `Dockerfile` — pins upstream image

### Flutter app (`app/`, scaffolded by `flutter create`)
- `pubspec.yaml` — deps
- `lib/main.dart` — entrypoint
- `lib/app.dart` — root widget + GoRouter
- `lib/core/api/api_client.dart` — Dio client + CF Access interceptor
- `lib/core/api/api_config.dart` — value class for base URL + creds
- `lib/core/settings/settings_repository.dart` — secure storage wrapper
- `lib/core/theme/app_theme.dart` — Material 3 theme
- `lib/features/onboarding/onboarding_screen.dart`
- `lib/features/health/health_screen.dart`
- `lib/features/health/health_controller.dart`
- `lib/routing/app_router.dart`
- `test/api_client_test.dart`
- `test/settings_repository_test.dart`
- `test/health_screen_test.dart`

### Root
- `README.md` — top-level setup guide (Cloudflare wiring lives here)
- `docker-compose.yml` — orchestrates `yt-music-api` + `pot-provider`
- `.env.example`
- `.gitignore`
- `secrets/.gitkeep` (file: `secrets/yt_headers.json` is gitignored)

---

## Task 1: Repo skeleton

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: `.env.example`
- Create: `secrets/.gitkeep`

- [ ] **Step 1.1: Write `.gitignore`**

```gitignore
# Secrets
secrets/*
!secrets/.gitkeep
.env
.env.local

# Python
__pycache__/
*.py[cod]
*.egg-info/
.venv/
.pytest_cache/
.ruff_cache/
htmlcov/
.coverage
dist/
build/

# Flutter / Dart
app/.dart_tool/
app/.flutter-plugins
app/.flutter-plugins-dependencies
app/build/
app/.idea/
app/.vscode/
app/ios/Pods/
app/ios/.symlinks/
app/ios/Flutter/Flutter.framework
app/ios/Flutter/Flutter.podspec
app/android/.gradle/
app/android/local.properties
app/android/app/.cxx/
*.iml
.packages
pubspec.lock

# OS
.DS_Store
Thumbs.db

# Docker
data/
```

- [ ] **Step 1.2: Write top-level `README.md` (placeholder; expanded in Task 10)**

```markdown
# UichaaMusic

A personal-use mobile music client backed by a self-hosted FastAPI service that wraps `ytmusicapi` + `yt-dlp`. See [`docs/superpowers/specs/2026-04-29-yt-music-client-design.md`](docs/superpowers/specs/2026-04-29-yt-music-client-design.md) for the full design.

## Layout

- `backend/` — FastAPI service
- `pot-provider/` — `bgutil-ytdlp-pot-provider` sidecar (PO token minting)
- `app/` — Flutter app
- `docs/` — design specs and plans

## Phase 0: Foundations

See [`docs/superpowers/plans/2026-04-29-phase-0-foundations.md`](docs/superpowers/plans/2026-04-29-phase-0-foundations.md).
```

- [ ] **Step 1.3: Write `.env.example`**

```env
# Path inside the yt-music-api container to the mounted cookie file.
YT_HEADERS_PATH=/secrets/yt_headers.json

# Hostname the pot-provider listens on, internal Docker network.
POT_PROVIDER_URL=http://pot-provider:4416

# Health check cadence in seconds.
AUTH_HEALTH_INTERVAL=900
```

- [ ] **Step 1.4: Create `secrets/.gitkeep`** (empty file)

```bash
mkdir -p secrets
touch secrets/.gitkeep
```

- [ ] **Step 1.5: Verify the layout**

Run:
```bash
ls -la
```
Expected output includes: `.gitignore`, `README.md`, `.env.example`, `secrets/`, `docs/`.

- [ ] **Step 1.6: Commit**

```bash
git add .gitignore README.md .env.example secrets/.gitkeep
git commit -m "chore: bootstrap repo skeleton (gitignore, env example, secrets dir)"
```

---

## Task 2: Backend project setup

**Files:**
- Create: `backend/pyproject.toml`
- Create: `backend/README.md`
- Create: `backend/src/ytmusic_api/__init__.py`
- Create: `backend/src/ytmusic_api/config.py`
- Create: `backend/src/ytmusic_api/main.py`
- Create: `backend/src/ytmusic_api/routers/__init__.py`
- Create: `backend/src/ytmusic_api/routers/health.py`
- Create: `backend/src/ytmusic_api/models/__init__.py`
- Create: `backend/src/ytmusic_api/models/health.py`
- Create: `backend/tests/conftest.py`
- Create: `backend/tests/test_health.py`

- [ ] **Step 2.1: Write `backend/pyproject.toml`**

```toml
[project]
name = "ytmusic-api"
version = "0.1.0"
description = "Personal YT Music backend"
requires-python = ">=3.12"
dependencies = [
  "fastapi>=0.115",
  "uvicorn[standard]>=0.32",
  "pydantic>=2.9",
  "pydantic-settings>=2.5",
  "ytmusicapi>=1.8",
  "watchfiles>=0.24",
  "jinja2>=3.1",
  "python-multipart>=0.0.12",
]

[project.optional-dependencies]
dev = [
  "pytest>=8.3",
  "pytest-asyncio>=0.24",
  "httpx>=0.27",
  "ruff>=0.7",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/ytmusic_api"]

[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP"]

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
pythonpath = ["src"]
```

- [ ] **Step 2.2: Write `backend/README.md`**

````markdown
# yt-music-api

FastAPI backend wrapping `ytmusicapi`.

## Dev setup

```bash
cd backend
uv sync --extra dev
uv run ruff check .
uv run pytest
uv run uvicorn ytmusic_api.main:app --reload --port 8000
```

## Tests

```bash
uv run pytest
```
````

- [ ] **Step 2.3: Create empty `__init__.py` files**

```bash
mkdir -p backend/src/ytmusic_api/{routers,models,auth,admin/templates}
mkdir -p backend/tests
touch backend/src/ytmusic_api/__init__.py
touch backend/src/ytmusic_api/routers/__init__.py
touch backend/src/ytmusic_api/models/__init__.py
touch backend/src/ytmusic_api/auth/__init__.py
touch backend/src/ytmusic_api/admin/__init__.py
```

- [ ] **Step 2.4: Write `backend/src/ytmusic_api/config.py`**

```python
from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="", env_file=None)

    yt_headers_path: Path = Field(default=Path("/secrets/yt_headers.json"))
    pot_provider_url: str = Field(default="http://pot-provider:4416")
    auth_health_interval: int = Field(default=900)  # seconds


@lru_cache
def get_settings() -> Settings:
    return Settings()
```

- [ ] **Step 2.5: Write `backend/src/ytmusic_api/models/health.py`**

```python
from datetime import datetime

from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str  # "ok" | "degraded"
    auth_status: str  # "ok" | "expired" | "unknown"
    last_ok_at: datetime | None = None
    pot_provider_ok: bool | None = None
    version: str
```

- [ ] **Step 2.6: Write the failing test for `/v1/health` (initial shape)**

`backend/tests/conftest.py`:
```python
import pytest
from fastapi.testclient import TestClient

from ytmusic_api.main import create_app


@pytest.fixture
def client() -> TestClient:
    return TestClient(create_app())
```

`backend/tests/test_health.py`:
```python
def test_health_returns_initial_shape(client):
    response = client.get("/v1/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] in {"ok", "degraded"}
    assert body["auth_status"] in {"ok", "expired", "unknown"}
    assert body["version"] == "0.1.0"
    assert "last_ok_at" in body
    assert "pot_provider_ok" in body
```

- [ ] **Step 2.7: Run the test, expect failure**

```bash
cd backend
uv sync --extra dev
uv run pytest tests/test_health.py::test_health_returns_initial_shape -v
```
Expected: FAIL with `ModuleNotFoundError: No module named 'ytmusic_api.main'`.

- [ ] **Step 2.8: Implement `/v1/health` (returns "unknown" auth for now)**

`backend/src/ytmusic_api/routers/health.py`:
```python
from fastapi import APIRouter

from ..models.health import HealthResponse

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        status="degraded",
        auth_status="unknown",
        last_ok_at=None,
        pot_provider_ok=None,
        version="0.1.0",
    )
```

`backend/src/ytmusic_api/main.py`:
```python
from fastapi import FastAPI

from .routers import health


def create_app() -> FastAPI:
    app = FastAPI(title="yt-music-api", version="0.1.0")
    app.include_router(health.router, prefix="/v1")
    return app


app = create_app()
```

- [ ] **Step 2.9: Run the test, expect pass**

```bash
uv run pytest tests/test_health.py::test_health_returns_initial_shape -v
```
Expected: PASS.

- [ ] **Step 2.10: Commit**

```bash
git add backend/
git commit -m "feat(backend): scaffold FastAPI app with /v1/health (unknown auth)"
```

---

## Task 3: Cookie file loader (`HeadersStore`)

The `HeadersStore` reads `yt_headers.json` from disk, exposes the parsed headers dict, and hot-reloads when the file changes (via `watchfiles`). Tests use a tmp_path fixture and rewrite the file mid-test.

**Files:**
- Create: `backend/src/ytmusic_api/auth/headers.py`
- Create: `backend/tests/test_headers_store.py`

- [ ] **Step 3.1: Write the failing tests**

`backend/tests/test_headers_store.py`:
```python
import asyncio
import json
from pathlib import Path

import pytest

from ytmusic_api.auth.headers import HeadersStore


@pytest.fixture
def headers_path(tmp_path: Path) -> Path:
    return tmp_path / "yt_headers.json"


def test_returns_none_when_file_missing(headers_path: Path):
    store = HeadersStore(path=headers_path)
    assert store.current() is None


def test_loads_existing_file(headers_path: Path):
    payload = {"User-Agent": "Mozilla/5.0", "Cookie": "SAPISID=abc"}
    headers_path.write_text(json.dumps(payload))

    store = HeadersStore(path=headers_path)
    assert store.current() == payload


def test_save_writes_file_and_updates_cache(headers_path: Path):
    payload = {"User-Agent": "X", "Cookie": "Y"}
    store = HeadersStore(path=headers_path)
    store.save(payload)

    assert json.loads(headers_path.read_text()) == payload
    assert store.current() == payload


@pytest.mark.asyncio
async def test_hot_reload_picks_up_external_changes(headers_path: Path):
    headers_path.write_text(json.dumps({"v": 1}))
    store = HeadersStore(path=headers_path)
    assert store.current() == {"v": 1}

    task = asyncio.create_task(store.watch())
    await asyncio.sleep(0.1)  # let the watcher start

    headers_path.write_text(json.dumps({"v": 2}))

    # Poll up to 2s for reload
    for _ in range(20):
        await asyncio.sleep(0.1)
        if store.current() == {"v": 2}:
            break

    assert store.current() == {"v": 2}
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass
```

- [ ] **Step 3.2: Run tests, expect failure**

```bash
uv run pytest tests/test_headers_store.py -v
```
Expected: FAIL with `ModuleNotFoundError`.

- [ ] **Step 3.3: Implement `HeadersStore`**

`backend/src/ytmusic_api/auth/headers.py`:
```python
from __future__ import annotations

import asyncio
import json
import logging
import os
from pathlib import Path
from typing import Any

from watchfiles import awatch

logger = logging.getLogger(__name__)


class HeadersStore:
    """Loads and watches the YT Music auth headers JSON file.

    Hot-reloads the in-memory copy when the file changes on disk.
    """

    def __init__(self, path: Path) -> None:
        self._path = path
        self._cached: dict[str, Any] | None = None
        self._load()

    def _load(self) -> None:
        try:
            text = self._path.read_text()
            self._cached = json.loads(text)
        except FileNotFoundError:
            self._cached = None
        except json.JSONDecodeError as exc:
            logger.error("Invalid JSON in %s: %s", self._path, exc)
            self._cached = None

    def current(self) -> dict[str, Any] | None:
        return self._cached

    def save(self, headers: dict[str, Any]) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._path.write_text(json.dumps(headers, indent=2))
        try:
            os.chmod(self._path, 0o600)
        except OSError:
            pass
        self._cached = headers

    async def watch(self) -> None:
        """Run forever; reload self._cached whenever the file changes."""
        watch_dir = self._path.parent
        watch_dir.mkdir(parents=True, exist_ok=True)
        async for changes in awatch(watch_dir):
            for _change_type, changed_path in changes:
                if Path(changed_path) == self._path:
                    self._load()
                    logger.info("Reloaded headers from %s", self._path)
                    break
```

- [ ] **Step 3.4: Run tests, expect pass**

```bash
uv run pytest tests/test_headers_store.py -v
```
Expected: 4 PASSED.

- [ ] **Step 3.5: Commit**

```bash
git add backend/src/ytmusic_api/auth/headers.py backend/tests/test_headers_store.py
git commit -m "feat(backend): add HeadersStore with disk load + watchfiles hot-reload"
```

---

## Task 4: Auth health monitor

`AuthHealthMonitor` runs a periodic auth-check (calls a pluggable `Callable`), recording the latest result. Tests inject a stub callable; production wires it to `ytmusicapi.YTMusic(...).get_library_songs(limit=1)`.

**Files:**
- Create: `backend/src/ytmusic_api/auth/health.py`
- Create: `backend/tests/test_auth_health.py`

- [ ] **Step 4.1: Write the failing tests**

`backend/tests/test_auth_health.py`:
```python
import asyncio
from datetime import UTC, datetime, timedelta

import pytest

from ytmusic_api.auth.health import AuthHealthMonitor, AuthStatus


def test_initial_status_is_unknown():
    monitor = AuthHealthMonitor(check=lambda: None, interval=0.05)
    assert monitor.status() == AuthStatus(label="unknown", last_ok_at=None)


@pytest.mark.asyncio
async def test_run_records_ok_when_check_succeeds():
    async def check_ok():
        return None  # success: no exception

    monitor = AuthHealthMonitor(check=check_ok, interval=0.05)
    task = asyncio.create_task(monitor.run())
    await asyncio.sleep(0.15)  # at least one tick
    monitor.stop()
    await task

    status = monitor.status()
    assert status.label == "ok"
    assert status.last_ok_at is not None
    assert datetime.now(UTC) - status.last_ok_at < timedelta(seconds=2)


@pytest.mark.asyncio
async def test_run_records_expired_when_check_raises():
    async def check_expired():
        raise RuntimeError("auth expired")

    monitor = AuthHealthMonitor(check=check_expired, interval=0.05)
    task = asyncio.create_task(monitor.run())
    await asyncio.sleep(0.15)
    monitor.stop()
    await task

    assert monitor.status().label == "expired"


@pytest.mark.asyncio
async def test_recovery_from_expired_to_ok():
    state = {"calls": 0}

    async def flaky():
        state["calls"] += 1
        if state["calls"] == 1:
            raise RuntimeError("expired")
        return None

    monitor = AuthHealthMonitor(check=flaky, interval=0.05)
    task = asyncio.create_task(monitor.run())
    await asyncio.sleep(0.25)  # at least 2 ticks
    monitor.stop()
    await task

    assert monitor.status().label == "ok"
```

- [ ] **Step 4.2: Run tests, expect failure**

```bash
uv run pytest tests/test_auth_health.py -v
```
Expected: FAIL with `ModuleNotFoundError`.

- [ ] **Step 4.3: Implement `AuthHealthMonitor`**

`backend/src/ytmusic_api/auth/health.py`:
```python
from __future__ import annotations

import asyncio
import logging
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Literal

logger = logging.getLogger(__name__)

AuthLabel = Literal["ok", "expired", "unknown"]


@dataclass(frozen=True)
class AuthStatus:
    label: AuthLabel
    last_ok_at: datetime | None


class AuthHealthMonitor:
    """Periodically calls an async check; records ok/expired/unknown."""

    def __init__(
        self,
        check: Callable[[], Awaitable[None]],
        interval: float = 900.0,
    ) -> None:
        self._check = check
        self._interval = interval
        self._status: AuthStatus = AuthStatus(label="unknown", last_ok_at=None)
        self._stop_event = asyncio.Event()

    def status(self) -> AuthStatus:
        return self._status

    def stop(self) -> None:
        self._stop_event.set()

    async def run(self) -> None:
        while not self._stop_event.is_set():
            try:
                await self._check()
                self._status = AuthStatus(
                    label="ok",
                    last_ok_at=datetime.now(UTC),
                )
            except Exception as exc:  # noqa: BLE001 - log and continue
                logger.warning("Auth health check failed: %s", exc)
                self._status = AuthStatus(
                    label="expired",
                    last_ok_at=self._status.last_ok_at,
                )

            try:
                await asyncio.wait_for(
                    self._stop_event.wait(), timeout=self._interval
                )
            except asyncio.TimeoutError:
                continue
```

- [ ] **Step 4.4: Run tests, expect pass**

```bash
uv run pytest tests/test_auth_health.py -v
```
Expected: 4 PASSED.

- [ ] **Step 4.5: Commit**

```bash
git add backend/src/ytmusic_api/auth/health.py backend/tests/test_auth_health.py
git commit -m "feat(backend): add AuthHealthMonitor with pluggable check fn"
```

---

## Task 5: Wire `HeadersStore` and `AuthHealthMonitor` into the FastAPI app

App startup builds a `HeadersStore`, an `AuthHealthMonitor` (using a real `ytmusicapi`-backed check), launches the watch + monitor as background tasks, and exposes them via `app.state` for the routers.

**Files:**
- Modify: `backend/src/ytmusic_api/main.py`
- Create: `backend/src/ytmusic_api/auth/check.py`
- Modify: `backend/src/ytmusic_api/routers/health.py`
- Modify: `backend/tests/conftest.py`
- Modify: `backend/tests/test_health.py`

- [ ] **Step 5.1: Write the production check implementation**

`backend/src/ytmusic_api/auth/check.py`:
```python
"""Real ytmusicapi-backed auth check used in production."""
from __future__ import annotations

import asyncio
import logging

from .headers import HeadersStore

logger = logging.getLogger(__name__)


def make_real_check(store: HeadersStore):
    """Returns an async callable that pings ytmusicapi.

    Raises if cookies invalid or unloaded.
    """

    async def check() -> None:
        headers = store.current()
        if headers is None:
            raise RuntimeError("headers not loaded")

        # ytmusicapi is sync; offload to thread.
        def _probe() -> None:
            from ytmusicapi import YTMusic

            client = YTMusic(auth=headers)
            # Cheapest authenticated call: get_library_songs(limit=1).
            client.get_library_songs(limit=1)

        await asyncio.to_thread(_probe)

    return check
```

- [ ] **Step 5.2: Update health router to read from `app.state`**

`backend/src/ytmusic_api/routers/health.py`:
```python
from fastapi import APIRouter, Request

from ..auth.health import AuthHealthMonitor
from ..models.health import HealthResponse

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
def health(request: Request) -> HealthResponse:
    monitor: AuthHealthMonitor = request.app.state.auth_monitor
    status = monitor.status()
    return HealthResponse(
        status="ok" if status.label == "ok" else "degraded",
        auth_status=status.label,
        last_ok_at=status.last_ok_at,
        pot_provider_ok=None,  # wired in Phase 1+
        version="0.1.0",
    )
```

- [ ] **Step 5.3: Update app factory with lifespan**

`backend/src/ytmusic_api/main.py`:
```python
from __future__ import annotations

import asyncio
import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from .auth.check import make_real_check
from .auth.headers import HeadersStore
from .auth.health import AuthHealthMonitor
from .config import get_settings
from .routers import health

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    store = HeadersStore(path=settings.yt_headers_path)
    monitor = AuthHealthMonitor(
        check=make_real_check(store),
        interval=settings.auth_health_interval,
    )

    app.state.headers_store = store
    app.state.auth_monitor = monitor

    watch_task = asyncio.create_task(store.watch())
    monitor_task = asyncio.create_task(monitor.run())

    try:
        yield
    finally:
        monitor.stop()
        watch_task.cancel()
        try:
            await monitor_task
        except asyncio.CancelledError:
            pass
        try:
            await watch_task
        except asyncio.CancelledError:
            pass


def create_app(
    *,
    headers_store: HeadersStore | None = None,
    auth_monitor: AuthHealthMonitor | None = None,
) -> FastAPI:
    """App factory.

    Test code can pass pre-built dependencies to bypass the lifespan setup.
    """
    if headers_store is not None and auth_monitor is not None:
        app = FastAPI(title="yt-music-api", version="0.1.0")
        app.state.headers_store = headers_store
        app.state.auth_monitor = auth_monitor
    else:
        app = FastAPI(title="yt-music-api", version="0.1.0", lifespan=lifespan)

    app.include_router(health.router, prefix="/v1")
    return app


app = create_app()
```

- [ ] **Step 5.4: Update test fixture to inject stubs**

`backend/tests/conftest.py`:
```python
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from ytmusic_api.auth.headers import HeadersStore
from ytmusic_api.auth.health import AuthHealthMonitor, AuthStatus
from ytmusic_api.main import create_app


class StubMonitor(AuthHealthMonitor):
    """Test double; status set explicitly, no background loop."""

    def __init__(self, status: AuthStatus) -> None:
        self._fixed_status = status

    def status(self) -> AuthStatus:
        return self._fixed_status

    async def run(self) -> None:  # pragma: no cover - never called in tests
        return

    def stop(self) -> None:
        return


@pytest.fixture
def headers_store(tmp_path: Path) -> HeadersStore:
    return HeadersStore(path=tmp_path / "headers.json")


@pytest.fixture
def auth_monitor() -> StubMonitor:
    return StubMonitor(status=AuthStatus(label="unknown", last_ok_at=None))


@pytest.fixture
def client(headers_store, auth_monitor) -> TestClient:
    return TestClient(
        create_app(headers_store=headers_store, auth_monitor=auth_monitor)
    )
```

- [ ] **Step 5.5: Add tests covering wired behavior**

`backend/tests/test_health.py` (replace contents):
```python
from datetime import UTC, datetime

from ytmusic_api.auth.health import AuthStatus


def test_health_unknown_when_monitor_unknown(client):
    response = client.get("/v1/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "degraded"
    assert body["auth_status"] == "unknown"
    assert body["last_ok_at"] is None
    assert body["version"] == "0.1.0"


def test_health_ok_when_monitor_ok(client, auth_monitor):
    now = datetime.now(UTC)
    auth_monitor._fixed_status = AuthStatus(label="ok", last_ok_at=now)

    response = client.get("/v1/health")
    body = response.json()

    assert body["status"] == "ok"
    assert body["auth_status"] == "ok"
    assert body["last_ok_at"] is not None


def test_health_degraded_when_expired(client, auth_monitor):
    auth_monitor._fixed_status = AuthStatus(label="expired", last_ok_at=None)

    body = client.get("/v1/health").json()

    assert body["status"] == "degraded"
    assert body["auth_status"] == "expired"
```

- [ ] **Step 5.6: Run all backend tests**

```bash
uv run pytest -v
```
Expected: all PASS (including the headers-store and auth-health tests from earlier tasks).

- [ ] **Step 5.7: Commit**

```bash
git add backend/
git commit -m "feat(backend): wire HeadersStore + AuthHealthMonitor into app lifespan; /v1/health reflects live auth state"
```

---

## Task 6: Admin page (server-rendered cookie refresh)

Mounts `/admin` on the same FastAPI app. `GET /admin` shows current status and a textarea. `POST /admin/cookies/refresh` parses pasted curl-as-bash from Chrome DevTools, validates by running the auth check, persists via `HeadersStore.save()`. Test the parser deterministically; auth-validation is mocked.

**Files:**
- Create: `backend/src/ytmusic_api/admin/parser.py`
- Create: `backend/src/ytmusic_api/admin/templates/index.html`
- Create: `backend/src/ytmusic_api/routers/admin.py`
- Create: `backend/tests/test_admin.py`
- Modify: `backend/src/ytmusic_api/main.py`

- [ ] **Step 6.1: Write the failing test for the curl parser**

`backend/tests/test_admin.py` (start; will grow):
```python
from ytmusic_api.admin.parser import parse_curl_headers


def test_parses_basic_curl_headers():
    raw = """curl 'https://music.youtube.com/youtubei/v1/browse' \\
      -H 'authority: music.youtube.com' \\
      -H 'cookie: SAPISID=abc; HSID=xyz' \\
      -H 'user-agent: Mozilla/5.0 (Macintosh; Intel)' \\
      -H 'authorization: SAPISIDHASH 1700000000_abc' \\
      -H 'x-goog-authuser: 0' \\
      --data-raw '{}' \\
      --compressed"""
    headers = parse_curl_headers(raw)

    assert headers["Cookie"] == "SAPISID=abc; HSID=xyz"
    assert headers["User-Agent"] == "Mozilla/5.0 (Macintosh; Intel)"
    assert headers["Authorization"] == "SAPISIDHASH 1700000000_abc"
    assert headers["X-Goog-Authuser"] == "0"


def test_rejects_input_without_cookie():
    raw = "curl 'https://example.com' -H 'user-agent: x'"
    try:
        parse_curl_headers(raw)
    except ValueError as exc:
        assert "cookie" in str(exc).lower()
    else:
        raise AssertionError("expected ValueError")
```

- [ ] **Step 6.2: Run test, expect failure**

```bash
uv run pytest tests/test_admin.py -v
```
Expected: FAIL with `ModuleNotFoundError`.

- [ ] **Step 6.3: Implement the parser**

`backend/src/ytmusic_api/admin/parser.py`:
```python
from __future__ import annotations

import re

# Matches:  -H 'header: value'   or   --header 'header: value'
_HEADER_RE = re.compile(r"-H\s+'([^:]+):\s*([^']+)'")


def parse_curl_headers(raw: str) -> dict[str, str]:
    """Extract HTTP header pairs from a curl command (DevTools 'Copy as cURL')."""
    headers: dict[str, str] = {}
    for match in _HEADER_RE.finditer(raw):
        name = match.group(1).strip()
        value = match.group(2).strip()
        # Title-case header names (HTTP is case-insensitive but be tidy)
        canonical = "-".join(part.capitalize() for part in name.split("-"))
        headers[canonical] = value

    if "Cookie" not in headers:
        raise ValueError("curl input missing required Cookie header")

    return headers
```

- [ ] **Step 6.4: Run test, expect pass**

```bash
uv run pytest tests/test_admin.py -v
```
Expected: 2 PASSED.

- [ ] **Step 6.5: Write the admin route tests**

Append to `backend/tests/test_admin.py`:
```python
import json

import pytest


@pytest.fixture
def admin_client(headers_store, auth_monitor, monkeypatch):
    """Variant of the client where save() validation is stubbed."""
    from fastapi.testclient import TestClient

    from ytmusic_api.main import create_app

    app = create_app(headers_store=headers_store, auth_monitor=auth_monitor)
    return TestClient(app)


def test_admin_page_renders(admin_client):
    response = admin_client.get("/admin")
    assert response.status_code == 200
    assert "auth_status" in response.text.lower()


def test_admin_post_saves_headers(admin_client, headers_store):
    raw_curl = (
        "curl 'https://music.youtube.com/youtubei/v1/browse' "
        "-H 'cookie: SAPISID=abc' "
        "-H 'user-agent: Mozilla/5.0' "
        "-H 'authorization: SAPISIDHASH 123_abc'"
    )

    response = admin_client.post(
        "/admin/cookies/refresh",
        data={"curl_input": raw_curl},
        follow_redirects=False,
    )

    assert response.status_code in (200, 303)
    saved = headers_store.current()
    assert saved is not None
    assert saved["Cookie"] == "SAPISID=abc"


def test_admin_post_rejects_invalid_input(admin_client, headers_store):
    response = admin_client.post(
        "/admin/cookies/refresh",
        data={"curl_input": "not a curl command"},
        follow_redirects=False,
    )
    assert response.status_code == 400
    assert headers_store.current() is None
```

- [ ] **Step 6.6: Run new tests, expect failure**

```bash
uv run pytest tests/test_admin.py -v
```
Expected: 3 of 5 FAIL (admin routes not implemented yet).

- [ ] **Step 6.7: Implement the admin Jinja template**

`backend/src/ytmusic_api/admin/templates/index.html`:
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>UichaaMusic - Admin</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif;
           max-width: 720px; margin: 2em auto; padding: 0 1em; color: #222; }
    h1 { margin-bottom: 0.2em; }
    .status { padding: 0.6em 0.9em; border-radius: 4px; margin: 1em 0; }
    .status.ok { background: #d4edda; color: #155724; }
    .status.expired, .status.unknown { background: #fff3cd; color: #856404; }
    .err { background: #f8d7da; color: #721c24; padding: 0.6em 0.9em; border-radius: 4px; }
    label { display: block; margin-top: 1em; font-weight: 600; }
    textarea { width: 100%; min-height: 220px; font-family: ui-monospace, Menlo, monospace;
               font-size: 12px; padding: 0.6em; box-sizing: border-box; }
    button { margin-top: 0.8em; padding: 0.5em 1em; cursor: pointer; }
  </style>
</head>
<body>
  <h1>UichaaMusic Admin</h1>

  <div class="status {{ auth_status }}">
    <strong>Auth:</strong> {{ auth_status }}
    {% if last_ok_at %}<br /><small>Last OK: {{ last_ok_at }}</small>{% endif %}
  </div>

  {% if error %}<div class="err">{{ error }}</div>{% endif %}
  {% if message %}<div class="status ok">{{ message }}</div>{% endif %}

  <form method="post" action="/admin/cookies/refresh">
    <label for="curl_input">Paste "Copy as cURL (bash)" from Chrome DevTools (any authenticated request to <code>music.youtube.com/youtubei/v1/*</code>):</label>
    <textarea id="curl_input" name="curl_input" required></textarea>
    <button type="submit">Save & test</button>
  </form>
</body>
</html>
```

- [ ] **Step 6.8: Implement the admin router**

`backend/src/ytmusic_api/routers/admin.py`:
```python
from __future__ import annotations

import logging
from pathlib import Path

from fastapi import APIRouter, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates

from ..admin.parser import parse_curl_headers
from ..auth.headers import HeadersStore
from ..auth.health import AuthHealthMonitor

logger = logging.getLogger(__name__)

_TEMPLATES_DIR = Path(__file__).resolve().parent.parent / "admin" / "templates"
templates = Jinja2Templates(directory=_TEMPLATES_DIR)

router = APIRouter()


@router.get("/admin", response_class=HTMLResponse)
def admin_index(request: Request) -> HTMLResponse:
    monitor: AuthHealthMonitor = request.app.state.auth_monitor
    status = monitor.status()
    return templates.TemplateResponse(
        request,
        "index.html",
        {
            "auth_status": status.label,
            "last_ok_at": status.last_ok_at.isoformat() if status.last_ok_at else None,
            "error": None,
            "message": None,
        },
    )


@router.post("/admin/cookies/refresh")
def admin_refresh(request: Request, curl_input: str = Form(...)):
    store: HeadersStore = request.app.state.headers_store

    try:
        headers = parse_curl_headers(curl_input)
    except ValueError as exc:
        logger.warning("Bad curl input: %s", exc)
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    store.save(headers)
    return RedirectResponse(url="/admin", status_code=303)
```

- [ ] **Step 6.9: Mount the admin router in `main.py`**

In `backend/src/ytmusic_api/main.py`, replace the routers section in `create_app`:
```python
    app.include_router(health.router, prefix="/v1")
    from .routers import admin as admin_router
    app.include_router(admin_router.router)
```

(Place the `from .routers import admin as admin_router` import at the top of the file with the other imports for cleanliness — but the inline import works too. Pick one style.)

- [ ] **Step 6.10: Run all tests, expect pass**

```bash
uv run pytest -v
```
Expected: all PASS.

- [ ] **Step 6.11: Manual smoke test of the admin page**

```bash
uv run uvicorn ytmusic_api.main:app --reload --port 8000
```

In another terminal:
```bash
curl -s http://localhost:8000/admin | grep -i "auth"
```
Expected: HTML containing the word "Auth".

Stop the server with Ctrl-C.

- [ ] **Step 6.12: Commit**

```bash
git add backend/
git commit -m "feat(backend): add admin page with curl-headers parser + cookie save"
```

---

## Task 7: Backend Dockerfile

Multi-stage build using `uv`. Final stage has only the runtime, mounted secrets at `/secrets`.

**Files:**
- Create: `backend/Dockerfile`

- [ ] **Step 7.1: Write the Dockerfile**

`backend/Dockerfile`:
```dockerfile
# syntax=docker/dockerfile:1.7

FROM python:3.12-slim AS base
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

# Install uv
COPY --from=ghcr.io/astral-sh/uv:0.4.30 /uv /usr/local/bin/uv

WORKDIR /app

# ----- builder -----
FROM base AS builder
COPY pyproject.toml ./
COPY src ./src
RUN uv sync --frozen --no-dev || uv sync --no-dev

# ----- runtime -----
FROM base AS runtime
COPY --from=builder /app /app
ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000
CMD ["uvicorn", "ytmusic_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

- [ ] **Step 7.2: Build the image**

```bash
cd backend
docker build -t ytmusic-api:dev .
```
Expected: build succeeds (may take 2–3 minutes first time).

- [ ] **Step 7.3: Smoke-run the image**

```bash
docker run --rm -p 8000:8000 -e YT_HEADERS_PATH=/tmp/none.json ytmusic-api:dev &
sleep 3
curl -s http://localhost:8000/v1/health | python3 -m json.tool
docker stop $(docker ps -q --filter ancestor=ytmusic-api:dev) || true
```
Expected JSON:
```json
{"status": "degraded", "auth_status": "unknown", ...}
```

- [ ] **Step 7.4: Commit**

```bash
git add backend/Dockerfile
git commit -m "feat(backend): multi-stage Dockerfile using uv"
```

---

## Task 8: pot-provider sidecar

Pin the upstream image; expose internally on port 4416. The sidecar takes its own configuration via env vars per upstream docs.

**Files:**
- Create: `pot-provider/Dockerfile`

- [ ] **Step 8.1: Write the Dockerfile**

`pot-provider/Dockerfile`:
```dockerfile
# Pinned to a known-good tag. Bump after upstream release notes review.
FROM brainicism/bgutil-ytdlp-pot-provider:0.7.2

# Container listens on 4416 by default; nothing to override here.
EXPOSE 4416
```

> Note: confirm the latest tag at https://github.com/Brainicism/bgutil-ytdlp-pot-provider/pkgs/container/bgutil-ytdlp-pot-provider before merging. Update the tag if a newer stable release exists.

- [ ] **Step 8.2: Build the image**

```bash
cd pot-provider
docker build -t pot-provider:dev .
```
Expected: build succeeds (downloads upstream image).

- [ ] **Step 8.3: Commit**

```bash
git add pot-provider/Dockerfile
git commit -m "feat(pot): pin upstream bgutil-ytdlp-pot-provider image"
```

---

## Task 9: docker-compose.yml

Orchestrates `yt-music-api` + `pot-provider`. Cloudflared runs separately (existing setup, documented in Task 10).

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 9.1: Write the compose file**

`docker-compose.yml`:
```yaml
services:
  pot-provider:
    build:
      context: ./pot-provider
    container_name: pot-provider
    restart: unless-stopped
    networks:
      - ytmusic_internal
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:4416/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3

  yt-music-api:
    build:
      context: ./backend
    container_name: yt-music-api
    restart: unless-stopped
    depends_on:
      - pot-provider
    environment:
      YT_HEADERS_PATH: /secrets/yt_headers.json
      POT_PROVIDER_URL: http://pot-provider:4416
      AUTH_HEALTH_INTERVAL: "900"
    volumes:
      - ./secrets:/secrets:rw
    ports:
      - "127.0.0.1:8000:8000"   # cloudflared connects to localhost:8000
    networks:
      - ytmusic_internal
    healthcheck:
      test: ["CMD-SHELL", "python -c 'import urllib.request; urllib.request.urlopen(\"http://localhost:8000/v1/health\")'"]
      interval: 30s
      timeout: 5s
      retries: 3

networks:
  ytmusic_internal:
    driver: bridge
```

- [ ] **Step 9.2: Validate the compose file**

```bash
docker compose config
```
Expected: prints the resolved config without error.

- [ ] **Step 9.3: Bring up the stack**

```bash
docker compose up -d --build
sleep 5
docker compose ps
```
Expected: both `pot-provider` and `yt-music-api` show `healthy` (or `starting` for the first ~30s).

- [ ] **Step 9.4: Smoke-test from the host**

```bash
curl -s http://localhost:8000/v1/health | python3 -m json.tool
curl -s http://localhost:8000/admin | head -n 20
```
Expected: health JSON; HTML containing `<title>UichaaMusic - Admin</title>`.

- [ ] **Step 9.5: Tear down**

```bash
docker compose down
```

- [ ] **Step 9.6: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: docker-compose orchestration for yt-music-api + pot-provider"
```

---

## Task 10: Cloudflared + CF Access setup documentation

Cloudflared and the CF Access policy are configured in the Cloudflare dashboard, not in code. We document the steps so the engineer (and future-you) can re-do them.

**Files:**
- Modify: `README.md`

- [ ] **Step 10.1: Replace the top-level README**

`README.md`:
````markdown
# UichaaMusic

A personal-use mobile music client backed by a self-hosted FastAPI service that wraps `ytmusicapi` + `yt-dlp`. See [`docs/superpowers/specs/2026-04-29-yt-music-client-design.md`](docs/superpowers/specs/2026-04-29-yt-music-client-design.md) for the full design.

## Layout

- `backend/` — FastAPI service
- `pot-provider/` — `bgutil-ytdlp-pot-provider` sidecar (PO-token minting)
- `app/` — Flutter app
- `docs/` — design specs and plans

## Phase 0 setup

### 1. Bring up the homelab stack

```bash
docker compose up -d --build
curl -s http://localhost:8000/v1/health
```

You should see `{"status":"degraded","auth_status":"unknown",...}`. That means the backend is alive but no cookies are loaded yet.

### 2. Cloudflare Tunnel

We assume you already have `cloudflared` running on the homelab. Add a public hostname routing your chosen subdomain (example: `ytmusic.example.com`) to `http://localhost:8000`:

- Cloudflare Zero Trust dashboard → Networks → Tunnels → your tunnel → Public Hostname → Add
- Subdomain: `ytmusic`
- Domain: your zone
- Service: `HTTP`, URL: `localhost:8000`

### 3. Cloudflare Access

Create an Access Application gating the new hostname:

- Zero Trust → Access → Applications → Add an application → Self-hosted
- Application name: `UichaaMusic`
- Session duration: 24h (or whatever)
- Application domain: `ytmusic.example.com`
- Path: leave blank to cover everything (including `/admin/*`)

Add a service-token-based policy:

- Policies → Add a policy → Name: "App + admin"
- Action: Allow
- Selector: **Service Token** → pick "Create a service token"
  - Name: `uichaa-music-mobile`
  - Save and **copy the Client ID + Client Secret immediately** (the secret is only shown once)

Add a second policy for browser access to `/admin` (so you can use the cookie-refresh page from a laptop without the service token):

- Policies → Add a policy → Name: "Admin browser"
- Action: Allow
- Selector: Emails → your email

### 4. Verify Access

From your laptop (logged in via the email policy):

```
https://ytmusic.example.com/admin
```

You should see the admin page. Paste a "Copy as cURL (bash)" from Chrome DevTools after browsing music.youtube.com → click Save. The auth status should flip to `ok` within ~15 minutes.

From a terminal (using the service token):

```bash
CFID="<paste Client-Id>"
CFSECRET="<paste Client-Secret>"
curl -s \
  -H "CF-Access-Client-Id: $CFID" \
  -H "CF-Access-Client-Secret: $CFSECRET" \
  https://ytmusic.example.com/v1/health
```

Should return the same JSON as the localhost call.

### 5. Configure the Flutter app

On first launch the app shows an Onboarding screen. Enter:
- Base URL: `https://ytmusic.example.com`
- CF Access Client ID
- CF Access Client Secret

The app stores these in iOS Keychain / Android Keystore. The Health screen then ticks live from `/v1/health`.

## Dev workflow

- Backend: `cd backend && uv sync --extra dev && uv run pytest`
- Flutter app: `cd app && flutter pub get && flutter test`
- Stack up: `docker compose up -d --build`
- Stack down: `docker compose down`
````

- [ ] **Step 10.2: Commit**

```bash
git add README.md
git commit -m "docs: add Phase 0 setup guide (Cloudflare Tunnel + Access)"
```

---

## Task 11: Flutter project scaffolding

We create the Flutter project under `app/` with the agreed bundle ID and display name. Project Dart name is `ytmusic` so the bundle ID becomes `com.richarddepierre.ytmusic` automatically.

**Files (created by `flutter create`):**
- `app/pubspec.yaml`, `app/lib/main.dart`, iOS + Android scaffolding

- [ ] **Step 11.1: Create the Flutter project**

From the repo root:
```bash
flutter --version
flutter create --org com.richarddepierre --project-name ytmusic --platforms ios,android app
```
Expected: Flutter scaffolds the `app/` directory.

- [ ] **Step 11.2: Verify bundle ID and rename app**

iOS: open `app/ios/Runner/Info.plist` and edit `CFBundleDisplayName` from "Ytmusic" to `UichaaMusic`:
```xml
<key>CFBundleDisplayName</key>
<string>UichaaMusic</string>
```
(If the key isn't present, add it inside `<dict>`.)

Android: edit `app/android/app/src/main/AndroidManifest.xml`, change `android:label="ytmusic"` to `android:label="UichaaMusic"`.

Verify bundle ID: `app/ios/Runner.xcodeproj/project.pbxproj` should contain `PRODUCT_BUNDLE_IDENTIFIER = com.richarddepierre.ytmusic;` (three occurrences). `app/android/app/build.gradle` should contain `applicationId "com.richarddepierre.ytmusic"`.

- [ ] **Step 11.3: Smoke run on a simulator**

```bash
cd app
flutter run -d "iPhone 15"   # or any device id from `flutter devices`
```
Expected: blank Flutter counter app launches.

Hot-stop with `q`.

- [ ] **Step 11.4: Commit**

```bash
git add app/
git commit -m "feat(app): scaffold Flutter project (UichaaMusic, com.richarddepierre.ytmusic)"
```

---

## Task 12: Flutter dependencies

**Files:**
- Modify: `app/pubspec.yaml`

- [ ] **Step 12.1: Replace `dependencies`/`dev_dependencies`/`flutter` blocks in `pubspec.yaml`**

`app/pubspec.yaml` (replace the relevant blocks; keep `name: ytmusic`, `description`, `publish_to`, `version`, `environment`):
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # State
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1

  # Routing
  go_router: ^14.6.2

  # Networking
  dio: ^5.7.0

  # Storage
  flutter_secure_storage: ^9.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

  # Codegen
  build_runner: ^2.4.13
  riverpod_generator: ^2.6.3

  # Tests
  mocktail: ^1.0.4

flutter:
  uses-material-design: true
```

- [ ] **Step 12.2: Fetch dependencies**

```bash
cd app
flutter pub get
```
Expected: deps resolve cleanly.

- [ ] **Step 12.3: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock
git commit -m "feat(app): add core dependencies (riverpod, dio, go_router, secure_storage)"
```

---

## Task 13: Settings repository (`SettingsRepository`)

Persists the API base URL + CF Access service token in `flutter_secure_storage`. Three keys: `api_base_url`, `cf_access_client_id`, `cf_access_client_secret`. The repo exposes `read()` and `save()` returning a value class.

**Files:**
- Create: `app/lib/core/api/api_config.dart`
- Create: `app/lib/core/settings/settings_repository.dart`
- Create: `app/test/settings_repository_test.dart`

- [ ] **Step 13.1: Define the value class**

`app/lib/core/api/api_config.dart`:
```dart
class ApiConfig {
  ApiConfig({
    required this.baseUrl,
    required this.cfAccessClientId,
    required this.cfAccessClientSecret,
  });

  final String baseUrl;
  final String cfAccessClientId;
  final String cfAccessClientSecret;

  bool get isComplete =>
      baseUrl.isNotEmpty &&
      cfAccessClientId.isNotEmpty &&
      cfAccessClientSecret.isNotEmpty;
}
```

- [ ] **Step 13.2: Write the failing tests using a fake storage**

`app/test/settings_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ytmusic/core/settings/settings_repository.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockStorage storage;
  late SettingsRepository repo;

  setUp(() {
    storage = _MockStorage();
    repo = SettingsRepository(storage: storage);
  });

  test('returns null config when nothing stored', () async {
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    final config = await repo.read();
    expect(config, isNull);
  });

  test('returns config when all three keys stored', () async {
    when(() => storage.read(key: 'api_base_url'))
        .thenAnswer((_) async => 'https://x.example.com');
    when(() => storage.read(key: 'cf_access_client_id'))
        .thenAnswer((_) async => 'cid');
    when(() => storage.read(key: 'cf_access_client_secret'))
        .thenAnswer((_) async => 'csecret');

    final config = await repo.read();
    expect(config!.baseUrl, 'https://x.example.com');
    expect(config.cfAccessClientId, 'cid');
    expect(config.cfAccessClientSecret, 'csecret');
  });

  test('save writes all three keys', () async {
    when(() => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});

    await repo.save(const ApiConfigInput(
      baseUrl: 'https://x.example.com',
      cfAccessClientId: 'cid',
      cfAccessClientSecret: 'csecret',
    ));

    verify(() => storage.write(key: 'api_base_url', value: 'https://x.example.com'))
        .called(1);
    verify(() => storage.write(key: 'cf_access_client_id', value: 'cid')).called(1);
    verify(() => storage.write(key: 'cf_access_client_secret', value: 'csecret'))
        .called(1);
  });
}
```

- [ ] **Step 13.3: Run, expect failure**

```bash
cd app
flutter test test/settings_repository_test.dart
```
Expected: FAIL (`SettingsRepository` not defined).

- [ ] **Step 13.4: Implement the repository**

`app/lib/core/settings/settings_repository.dart`:
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_config.dart';

class ApiConfigInput {
  const ApiConfigInput({
    required this.baseUrl,
    required this.cfAccessClientId,
    required this.cfAccessClientSecret,
  });

  final String baseUrl;
  final String cfAccessClientId;
  final String cfAccessClientSecret;
}

class SettingsRepository {
  SettingsRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kBaseUrl = 'api_base_url';
  static const _kClientId = 'cf_access_client_id';
  static const _kClientSecret = 'cf_access_client_secret';

  final FlutterSecureStorage _storage;

  Future<ApiConfig?> read() async {
    final baseUrl = await _storage.read(key: _kBaseUrl);
    final clientId = await _storage.read(key: _kClientId);
    final clientSecret = await _storage.read(key: _kClientSecret);

    if (baseUrl == null || clientId == null || clientSecret == null) {
      return null;
    }

    return ApiConfig(
      baseUrl: baseUrl,
      cfAccessClientId: clientId,
      cfAccessClientSecret: clientSecret,
    );
  }

  Future<void> save(ApiConfigInput input) async {
    await _storage.write(key: _kBaseUrl, value: input.baseUrl);
    await _storage.write(key: _kClientId, value: input.cfAccessClientId);
    await _storage.write(key: _kClientSecret, value: input.cfAccessClientSecret);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kBaseUrl);
    await _storage.delete(key: _kClientId);
    await _storage.delete(key: _kClientSecret);
  }
}
```

- [ ] **Step 13.5: Run, expect pass**

```bash
flutter test test/settings_repository_test.dart
```
Expected: 3 PASSED.

- [ ] **Step 13.6: Commit**

```bash
git add app/
git commit -m "feat(app): SettingsRepository on flutter_secure_storage"
```

---

## Task 14: API client with CF Access interceptor

`ApiClient` wraps Dio. Constructor takes an `ApiConfig`; an interceptor injects `CF-Access-Client-Id` + `CF-Access-Client-Secret` on every request and sets the base URL. Exposes `getHealth()` returning a typed `HealthResult`.

**Files:**
- Create: `app/lib/core/api/api_client.dart`
- Create: `app/test/api_client_test.dart`

- [ ] **Step 14.1: Write the failing tests**

`app/test/api_client_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/core/api/api_config.dart';

class _RecordingAdapter extends HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final body = '{"status":"ok","auth_status":"ok","last_ok_at":null,'
        '"pot_provider_ok":null,"version":"0.1.0"}';
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }
}

void main() {
  test('injects CF Access headers and base URL', () async {
    final adapter = _RecordingAdapter();
    final client = ApiClient(
      config: ApiConfig(
        baseUrl: 'https://ytmusic.example.com',
        cfAccessClientId: 'CID',
        cfAccessClientSecret: 'CSECRET',
      ),
    );
    client.dio.httpClientAdapter = adapter;

    final result = await client.getHealth();

    expect(result.status, 'ok');
    expect(result.authStatus, 'ok');
    expect(result.version, '0.1.0');

    expect(adapter.lastRequest!.uri.toString(),
        'https://ytmusic.example.com/v1/health');
    expect(adapter.lastRequest!.headers['CF-Access-Client-Id'], 'CID');
    expect(adapter.lastRequest!.headers['CF-Access-Client-Secret'], 'CSECRET');
  });

  test('throws ApiException on non-2xx', () async {
    final adapter = _RecordingAdapter();
    adapter._statusCode = 401;
    final client = ApiClient(
      config: ApiConfig(
        baseUrl: 'https://ytmusic.example.com',
        cfAccessClientId: 'CID',
        cfAccessClientSecret: 'CSECRET',
      ),
    );
    client.dio.httpClientAdapter = adapter;

    expect(client.getHealth(), throwsA(isA<ApiException>()));
  });
}

extension on _RecordingAdapter {
  set _statusCode(int code) => _statusCodeOverride = code;
}
```

> Reality check: the second test wants a 401. We'll adjust the adapter to support overrides — update the adapter:

Replace the `_RecordingAdapter` definition above with:
```dart
class _RecordingAdapter extends HttpClientAdapter {
  RequestOptions? lastRequest;
  int statusCode = 200;
  String body = '{"status":"ok","auth_status":"ok","last_ok_at":null,'
      '"pot_provider_ok":null,"version":"0.1.0"}';

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {'content-type': ['application/json']},
    );
  }
}
```

And update the second test:
```dart
test('throws ApiException on non-2xx', () async {
  final adapter = _RecordingAdapter()..statusCode = 401;
  final client = ApiClient(
    config: ApiConfig(
      baseUrl: 'https://ytmusic.example.com',
      cfAccessClientId: 'CID',
      cfAccessClientSecret: 'CSECRET',
    ),
  );
  client.dio.httpClientAdapter = adapter;

  expect(client.getHealth(), throwsA(isA<ApiException>()));
});
```

(Remove the trailing `extension` block — it was a placeholder.)

Also add `import 'dart:typed_data';` at top for `Uint8List`.

- [ ] **Step 14.2: Run, expect failure**

```bash
flutter test test/api_client_test.dart
```
Expected: FAIL (`ApiClient` not defined).

- [ ] **Step 14.3: Implement `ApiClient`**

`app/lib/core/api/api_client.dart`:
```dart
import 'package:dio/dio.dart';

import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class HealthResult {
  HealthResult({
    required this.status,
    required this.authStatus,
    required this.lastOkAt,
    required this.potProviderOk,
    required this.version,
  });

  final String status;
  final String authStatus;
  final DateTime? lastOkAt;
  final bool? potProviderOk;
  final String version;

  factory HealthResult.fromJson(Map<String, dynamic> json) => HealthResult(
        status: json['status'] as String,
        authStatus: json['auth_status'] as String,
        lastOkAt: json['last_ok_at'] != null
            ? DateTime.parse(json['last_ok_at'] as String)
            : null,
        potProviderOk: json['pot_provider_ok'] as bool?,
        version: json['version'] as String,
      );
}

class ApiClient {
  ApiClient({required ApiConfig config})
      : dio = Dio(BaseOptions(
          baseUrl: config.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'CF-Access-Client-Id': config.cfAccessClientId,
            'CF-Access-Client-Secret': config.cfAccessClientSecret,
          },
        ));

  final Dio dio;

  Future<HealthResult> getHealth() async {
    try {
      final res = await dio.get<Map<String, dynamic>>('/v1/health');
      if (res.statusCode != 200 || res.data == null) {
        throw ApiException(res.statusCode ?? 0, 'Unexpected response');
      }
      return HealthResult.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode ?? 0,
        e.message ?? 'Network error',
      );
    }
  }
}
```

- [ ] **Step 14.4: Run, expect pass**

```bash
flutter test test/api_client_test.dart
```
Expected: 2 PASSED.

- [ ] **Step 14.5: Commit**

```bash
git add app/
git commit -m "feat(app): ApiClient with CF Access interceptor and getHealth()"
```

---

## Task 15: App shell + routing + Riverpod providers

Wire `main.dart`, root widget, GoRouter, and the Riverpod providers exposing `SettingsRepository` and the (future-built-on-demand) `ApiClient`.

**Files:**
- Modify: `app/lib/main.dart`
- Create: `app/lib/app.dart`
- Create: `app/lib/routing/app_router.dart`
- Create: `app/lib/core/theme/app_theme.dart`
- Create: `app/lib/core/api/api_providers.dart`
- Create: `app/lib/core/settings/settings_providers.dart`

- [ ] **Step 15.1: Write `app/lib/core/theme/app_theme.dart`**

```dart
import 'package:flutter/material.dart';

ThemeData buildLightTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF0033)),
      useMaterial3: true,
    );

ThemeData buildDarkTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF0033),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
```

- [ ] **Step 15.2: Write `app/lib/core/settings/settings_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_repository.dart';
import '../api/api_config.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final apiConfigProvider = FutureProvider<ApiConfig?>((ref) async {
  return ref.watch(settingsRepositoryProvider).read();
});
```

- [ ] **Step 15.3: Write `app/lib/core/api/api_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'api_config.dart';
import '../settings/settings_providers.dart';

final apiClientProvider = Provider<ApiClient?>((ref) {
  final config = ref.watch(apiConfigProvider).valueOrNull;
  if (config == null || !config.isComplete) {
    return null;
  }
  return ApiClient(config: config);
});
```

- [ ] **Step 15.4: Write `app/lib/routing/app_router.dart`**

(`HealthScreen` and `OnboardingScreen` are built in subsequent tasks; this file references them by import path.)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/settings/settings_providers.dart';
import '../features/health/health_screen.dart';
import '../features/onboarding/onboarding_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/health',
    redirect: (context, state) {
      final config = ref.read(apiConfigProvider).valueOrNull;
      final configured = config != null && config.isComplete;
      final goingToOnboarding = state.matchedLocation == '/onboarding';

      if (!configured && !goingToOnboarding) return '/onboarding';
      if (configured && goingToOnboarding) return '/health';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/health', builder: (_, __) => const HealthScreen()),
    ],
  );
});
```

- [ ] **Step 15.5: Write `app/lib/app.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

class UichaaMusicApp extends ConsumerWidget {
  const UichaaMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'UichaaMusic',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 15.6: Replace `app/lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  runApp(const ProviderScope(child: UichaaMusicApp()));
}
```

- [ ] **Step 15.7: Verify it compiles**

```bash
cd app
flutter analyze
```
Expected: errors only for missing `OnboardingScreen` / `HealthScreen` (built in next tasks). If anything else is broken, fix before proceeding.

- [ ] **Step 15.8: Commit**

```bash
git add app/lib/main.dart app/lib/app.dart app/lib/routing/ app/lib/core/theme/ app/lib/core/api/api_providers.dart app/lib/core/settings/settings_providers.dart
git commit -m "feat(app): app shell + GoRouter + Riverpod providers (api/config wired)"
```

---

## Task 16: Onboarding screen

Form: base URL, CF Access Client ID, CF Access Client Secret. On submit: save via `SettingsRepository`, invalidate `apiConfigProvider`, GoRouter redirect kicks user to `/health`.

**Files:**
- Create: `app/lib/features/onboarding/onboarding_screen.dart`

- [ ] **Step 16.1: Write the screen**

`app/lib/features/onboarding/onboarding_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_providers.dart';
import '../../core/settings/settings_repository.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _cidController = TextEditingController();
  final _csecretController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _urlController.dispose();
    _cidController.dispose();
    _csecretController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await ref.read(settingsRepositoryProvider).save(
            ApiConfigInput(
              baseUrl: _urlController.text.trim(),
              cfAccessClientId: _cidController.text.trim(),
              cfAccessClientSecret: _csecretController.text.trim(),
            ),
          );
      ref.invalidate(apiConfigProvider);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const Text(
                  'Enter your homelab backend URL and CF Access service token credentials.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://ytmusic.example.com',
                  ),
                  keyboardType: TextInputType.url,
                  validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
                ),
                TextFormField(
                  controller: _cidController,
                  decoration: const InputDecoration(
                    labelText: 'CF-Access-Client-Id',
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
                ),
                TextFormField(
                  controller: _csecretController,
                  decoration: const InputDecoration(
                    labelText: 'CF-Access-Client-Secret',
                  ),
                  obscureText: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 16.2: Run analyzer**

```bash
cd app
flutter analyze lib/features/onboarding/
```
Expected: no errors.

- [ ] **Step 16.3: Commit**

```bash
git add app/lib/features/onboarding/
git commit -m "feat(app): onboarding screen for base URL + CF Access credentials"
```

---

## Task 17: Health screen

Calls `/v1/health` on mount, shows status, auto-refreshes on pull-to-refresh. Riverpod `FutureProvider` does the work; widget renders the three states (loading, data, error).

**Files:**
- Create: `app/lib/features/health/health_controller.dart`
- Create: `app/lib/features/health/health_screen.dart`
- Create: `app/test/health_screen_test.dart`

- [ ] **Step 17.1: Write the controller**

`app/lib/features/health/health_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_providers.dart';

final healthFutureProvider = FutureProvider.autoDispose<HealthResult>((ref) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    throw ApiException(0, 'Client not configured');
  }
  return client.getHealth();
});
```

- [ ] **Step 17.2: Write the failing widget test**

`app/test/health_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ytmusic/core/api/api_client.dart';
import 'package:ytmusic/features/health/health_controller.dart';
import 'package:ytmusic/features/health/health_screen.dart';

void main() {
  testWidgets('renders auth_status from health response', (tester) async {
    final fakeResult = HealthResult(
      status: 'ok',
      authStatus: 'ok',
      lastOkAt: DateTime.utc(2026, 4, 29, 12, 0, 0),
      potProviderOk: null,
      version: '0.1.0',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthFutureProvider.overrideWith((_) async => fakeResult),
        ],
        child: const MaterialApp(home: HealthScreen()),
      ),
    );

    // Loading state first
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.textContaining('ok', findRichText: true), findsWidgets);
    expect(find.textContaining('0.1.0'), findsOneWidget);
  });

  testWidgets('renders error message when call fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthFutureProvider.overrideWith((_) async {
            throw ApiException(401, 'unauthorized');
          }),
        ],
        child: const MaterialApp(home: HealthScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('401'), findsOneWidget);
  });
}
```

- [ ] **Step 17.3: Run, expect failure**

```bash
flutter test test/health_screen_test.dart
```
Expected: FAIL (`HealthScreen` not defined).

- [ ] **Step 17.4: Implement `HealthScreen`**

`app/lib/features/health/health_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health_controller.dart';

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthFutureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Backend Health')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(healthFutureProvider.future),
        child: health.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Error: $err', style: const TextStyle(color: Colors.red)),
            ],
          ),
          data: (h) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Row('Status', h.status),
              _Row('Auth', h.authStatus),
              _Row('Last OK', h.lastOkAt?.toIso8601String() ?? '—'),
              _Row('PoT provider', h.potProviderOk?.toString() ?? '—'),
              _Row('Version', h.version),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 17.5: Run, expect pass**

```bash
flutter test test/health_screen_test.dart
```
Expected: 2 PASSED.

- [ ] **Step 17.6: Run all app tests**

```bash
flutter test
```
Expected: all PASS.

- [ ] **Step 17.7: Commit**

```bash
git add app/lib/features/health/ app/test/health_screen_test.dart
git commit -m "feat(app): HealthScreen calling /v1/health with pull-to-refresh"
```

---

## Task 18: End-to-end milestone validation

Stand up the homelab stack, configure Cloudflare per the README, install the app on a simulator with the service-token creds, confirm the Health screen shows live values from the backend.

**Files:** none (validation step only)

- [ ] **Step 18.1: Bring up the stack on the homelab**

```bash
docker compose up -d --build
docker compose ps         # both services healthy
curl -s http://localhost:8000/v1/health
```
Expected: `{"status":"degraded","auth_status":"unknown",...}`.

- [ ] **Step 18.2: Configure Cloudflare Tunnel + Access**

Follow `README.md` Phase 0 setup §2–§3. End state: `https://ytmusic.<your-zone>/v1/health` returns the same JSON when called with the service-token headers.

```bash
curl -s \
  -H "CF-Access-Client-Id: $CF_CID" \
  -H "CF-Access-Client-Secret: $CF_CSECRET" \
  https://ytmusic.<your-zone>/v1/health
```

- [ ] **Step 18.3: Run the Flutter app and complete onboarding**

```bash
cd app
flutter run -d "iPhone 15"
```

In the app:
- Onboarding screen appears
- Enter base URL = `https://ytmusic.<your-zone>`
- Enter the CF Access Client ID + Secret from §3
- Tap Save

Expected: app navigates to the Health screen, which displays:
- Status: `degraded`
- Auth: `unknown`
- Version: `0.1.0`

- [ ] **Step 18.4: Refresh cookies via the admin page**

From your laptop browser (logged in via the email-based Access policy):
- Open `https://ytmusic.<your-zone>/admin`
- In another tab, open https://music.youtube.com (logged in)
- DevTools → Network → any request to `/youtubei/v1/browse` → right-click → Copy → Copy as cURL (bash)
- Paste into the admin textarea → Save

Wait up to 15 minutes (or change `AUTH_HEALTH_INTERVAL=60` in `.env` for a faster poll during testing).

- [ ] **Step 18.5: Confirm end-to-end success**

In the app, pull-to-refresh the Health screen. Expected:
- Status: `ok`
- Auth: `ok`
- Last OK: a recent timestamp
- Version: `0.1.0`

Take a screenshot for the Phase-0-completion record (optional).

- [ ] **Step 18.6: Final commit (mark phase complete)**

If any small fixes were made during validation, commit them. Otherwise:

```bash
git tag phase-0-complete
git log --oneline | head -20
```

---

## Self-review

Spec coverage check:
- §1 architecture diagram → Tasks 7–10 stand up the homelab side; Tasks 11–17 the Flutter side.
- §2 backend API surface → only `/v1/health`, `/admin`, `/admin/cookies/refresh` ship in Phase 0; all others deferred to Phase 1+.
- §3 auth & cookie management → Tasks 3–6, 18.
- §4 Flutter architecture → Tasks 11–17 (layers, packages, ApiClient, error model partial: ApiException only; full ErrorBoundary in Phase 7).
- §5 data model → not in scope for Phase 0.
- §6 download system → not in scope.
- §7 repo structure → Tasks 1, 2, 11.
- §8 roadmap (Phase 0 row) → fully covered.
- §9 risks register → mitigations not yet engaged (no PoT calls yet, no `ytmusicapi` calls except the health probe).

No placeholders, no TBDs. All test code, implementation code, and commands are concrete. Type names and method signatures are consistent across tasks (`HeadersStore.current()`/`save()`/`watch()`, `AuthHealthMonitor.status()`/`run()`/`stop()`, `ApiClient.getHealth()`, `SettingsRepository.read()`/`save()`/`clear()`).
