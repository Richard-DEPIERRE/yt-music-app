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
