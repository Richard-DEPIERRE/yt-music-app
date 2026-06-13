from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from ytmusic_api.main import create_app
from ytmusic_api.services.cache import TtlCache
from ytmusic_api.services.concurrency import BoundedRunner
from ytmusic_api.services.stream_resolver import ResolvedStream


def test_manifest_request_defaults():
    from ytmusic_api.models.downloads import ManifestRequest

    req = ManifestRequest(videoIds=["a", "b"])
    assert req.codec == "aac"
    assert req.quality == "high"
    assert req.videoIds == ["a", "b"]


class _MapResolver:
    """Resolves per-id from a payload map; missing ids raise."""

    def __init__(self, payloads=None, errors=None):
        self.payloads = payloads or {}
        self.errors = errors or {}
        self.calls = []

    async def resolve(self, video_id, *, codec, quality):
        self.calls.append((video_id, codec, quality))
        if video_id in self.errors:
            raise self.errors[video_id]
        return self.payloads[video_id]


def _payload(video_id):
    return ResolvedStream(
        video_id=video_id,
        url=f"https://rr.googlevideo.com/{video_id}",
        expires_at=datetime.utcnow() + timedelta(hours=6),
        codec="aac",
        container="m4a",
        bitrate=160_000,
        approx_duration_ms=180_000,
        content_length=4321,
        artwork_url="https://img/big.jpg",
    )


def _client(resolver):
    import tempfile
    from pathlib import Path
    from ytmusic_api.auth.headers import HeadersStore
    from ytmusic_api.auth.health import AuthHealthMonitor, AuthStatus

    class _StubMonitor(AuthHealthMonitor):
        def __init__(self, status: AuthStatus) -> None:
            self._fixed_status = status

        def status(self) -> AuthStatus:
            return self._fixed_status

        async def run(self) -> None:
            return

        def stop(self) -> None:
            return

    tmp = Path(tempfile.mkdtemp()) / "h.json"
    app = create_app(
        headers_store=HeadersStore(path=tmp),
        auth_monitor=_StubMonitor(status=AuthStatus(label="ok", last_ok_at=None)),
        cache=TtlCache(),
        stream_resolver=resolver,
        stream_runner=BoundedRunner(max_concurrent=3),
    )
    return TestClient(app)


def test_manifest_resolves_all_items():
    resolver = _MapResolver(payloads={"a": _payload("a"), "b": _payload("b")})
    client = _client(resolver)
    res = client.post("/v1/downloads/manifest", json={"videoIds": ["a", "b"]})
    assert res.status_code == 200
    body = res.json()
    assert {i["videoId"] for i in body["items"]} == {"a", "b"}
    assert body["errors"] == []
    item = body["items"][0]
    assert item["artworkUrl"] == "https://img/big.jpg"
    assert item["container"] == "m4a"


def test_manifest_isolates_per_item_errors():
    resolver = _MapResolver(
        payloads={"a": _payload("a")},
        errors={"bad": RuntimeError("boom")},
    )
    client = _client(resolver)
    res = client.post("/v1/downloads/manifest", json={"videoIds": ["a", "bad"]})
    assert res.status_code == 200
    body = res.json()
    assert [i["videoId"] for i in body["items"]] == ["a"]
    assert body["errors"] == [{"videoId": "bad", "error": "upstream_breakage"}]


def test_manifest_uses_stream_cache():
    resolver = _MapResolver(payloads={"a": _payload("a")})
    client = _client(resolver)
    client.post("/v1/downloads/manifest", json={"videoIds": ["a"], "codec": "aac"})
    client.post("/v1/downloads/manifest", json={"videoIds": ["a"], "codec": "aac"})
    assert len(resolver.calls) == 1  # second call served from cache


def test_manifest_rejects_empty_list():
    client = _client(_MapResolver())
    res = client.post("/v1/downloads/manifest", json={"videoIds": []})
    assert res.status_code == 422
