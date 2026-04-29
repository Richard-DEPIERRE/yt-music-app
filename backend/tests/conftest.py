from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from ytmusic_api.auth.headers import HeadersStore
from ytmusic_api.auth.health import AuthHealthMonitor, AuthStatus
from ytmusic_api.main import create_app


class StubMonitor(AuthHealthMonitor):
    """Test double; status set explicitly, no background loop."""

    def __init__(self, status: AuthStatus) -> None:
        # Intentionally skip super().__init__() so no asyncio.Event is created
        # in test scope. The overrides below cover all behaviour the tests need.
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
