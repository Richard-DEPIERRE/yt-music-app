def test_health_returns_initial_shape(client):
    response = client.get("/v1/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] in {"ok", "degraded"}
    assert body["auth_status"] in {"ok", "expired", "unknown"}
    assert body["version"] == "0.1.0"
    assert "last_ok_at" in body
    assert "pot_provider_ok" in body
