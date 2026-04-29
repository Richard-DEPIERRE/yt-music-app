from datetime import UTC, datetime

import pytest
from fastapi.testclient import TestClient

from ytmusic_api.auth.health import AuthStatus
from ytmusic_api.main import create_app


def test_health_unknown_when_monitor_unknown(client):
    response = client.get("/v1/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "degraded"
    assert body["auth_status"] == "unknown"
    assert body["last_ok_at"] is None
    assert body["version"] == "0.1.0"
    assert body["pot_provider_ok"] is None  # no pot_client wired


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


class _FakePotClient:
    def __init__(self, *, ok: bool) -> None:
        self.ok = ok
        self.calls = 0

    async def ping(self) -> bool:
        self.calls += 1
        return self.ok

    async def aclose(self) -> None:
        return None


@pytest.mark.parametrize("ping_returns,expected", [(True, True), (False, False)])
def test_health_reports_pot_provider_ok(headers_store, auth_monitor, ping_returns, expected):
    pot = _FakePotClient(ok=ping_returns)
    app = create_app(
        headers_store=headers_store,
        auth_monitor=auth_monitor,
        pot_client=pot,
    )
    client = TestClient(app)
    body = client.get("/v1/health").json()
    assert body["pot_provider_ok"] is expected
    assert pot.calls == 1
