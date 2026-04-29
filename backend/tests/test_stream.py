from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from ytmusic_api.main import create_app
from ytmusic_api.services.cache import TtlCache
from ytmusic_api.services.concurrency import BoundedRunner
from ytmusic_api.services.stream_resolver import ResolvedStream


class _FakeResolver:
    def __init__(self) -> None:
        self.calls: list[tuple[str, str, str]] = []
        self.payload: ResolvedStream | None = None
        self.error: Exception | None = None

    async def resolve(self, video_id, *, codec, quality):
        self.calls.append((video_id, codec, quality))
        if self.error:
            raise self.error
        assert self.payload is not None
        return self.payload


@pytest.fixture
def fake_resolver():
    return _FakeResolver()


@pytest.fixture
def stream_client(headers_store, auth_monitor, fake_resolver):
    app = create_app(
        headers_store=headers_store,
        auth_monitor=auth_monitor,
        cache=TtlCache(),
        stream_resolver=fake_resolver,
        stream_runner=BoundedRunner(max_concurrent=3),
    )
    return TestClient(app)


def test_stream_returns_resolved_url(stream_client, fake_resolver):
    fake_resolver.payload = ResolvedStream(
        video_id="abc",
        url="https://rr.googlevideo.com/x?expire=999999",
        expires_at=datetime.utcnow() + timedelta(hours=6),
        codec="opus",
        container="webm",
        bitrate=160_000,
        approx_duration_ms=180_000,
        content_length=4321,
    )

    response = stream_client.get("/v1/track/abc/stream?codec=opus&quality=high")
    assert response.status_code == 200
    body = response.json()
    assert body["videoId"] == "abc"
    assert body["url"].startswith("https://rr.googlevideo.com/")
    assert body["codec"] == "opus"
    assert body["bitrate"] == 160_000
    assert body["contentLength"] == 4321
    assert "expiresAt" in body


def test_stream_caches_per_videoid_codec_quality(stream_client, fake_resolver):
    fake_resolver.payload = ResolvedStream(
        video_id="abc", url="u", expires_at=datetime.utcnow() + timedelta(hours=1),
        codec="opus", container="webm", bitrate=160_000,
        approx_duration_ms=180_000, content_length=None,
    )
    stream_client.get("/v1/track/abc/stream?codec=opus&quality=high")
    stream_client.get("/v1/track/abc/stream?codec=opus&quality=high")
    assert len(fake_resolver.calls) == 1


def test_stream_502_when_resolver_raises(stream_client, fake_resolver):
    fake_resolver.error = RuntimeError("yt-dlp boom")
    response = stream_client.get("/v1/track/abc/stream")
    assert response.status_code == 502
    body = response.json()
    assert body["detail"]["error"] == "upstream_breakage"
