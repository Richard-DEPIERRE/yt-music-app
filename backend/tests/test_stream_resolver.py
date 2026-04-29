from datetime import datetime
from typing import Any

import pytest

from ytmusic_api.services.stream_resolver import (
    ResolvedStream,
    StreamResolver,
    _pick_format,
)


def test_pick_format_prefers_aac_when_requested():
    formats: list[dict[str, Any]] = [
        {
            "format_id": "251",
            "ext": "webm",
            "acodec": "opus",
            "abr": 160,
            "filesize": 1,
            "url": "u-opus",
            "approx_duration_ms": 1,
        },
        {
            "format_id": "140",
            "ext": "m4a",
            "acodec": "mp4a.40.2",
            "abr": 256,
            "filesize": 2,
            "url": "u-aac",
            "approx_duration_ms": 1,
        },
    ]
    fmt = _pick_format(formats, codec="aac", quality="high")
    assert fmt["format_id"] == "140"


def test_pick_format_falls_back_when_codec_unavailable():
    formats: list[dict[str, Any]] = [
        {
            "format_id": "251",
            "ext": "webm",
            "acodec": "opus",
            "abr": 160,
            "url": "u",
            "approx_duration_ms": 1,
        },
    ]
    fmt = _pick_format(formats, codec="aac", quality="high")
    assert fmt["format_id"] == "251"  # falls back to opus


def test_pick_format_picks_low_bitrate_for_low_quality():
    formats: list[dict[str, Any]] = [
        {
            "format_id": "139",
            "ext": "m4a",
            "acodec": "mp4a.40.2",
            "abr": 48,
            "url": "u",
            "approx_duration_ms": 1,
        },
        {
            "format_id": "140",
            "ext": "m4a",
            "acodec": "mp4a.40.2",
            "abr": 128,
            "url": "u",
            "approx_duration_ms": 1,
        },
    ]
    fmt = _pick_format(formats, codec="aac", quality="low")
    assert fmt["format_id"] == "139"


@pytest.mark.asyncio
async def test_resolver_returns_resolved_stream(monkeypatch):
    """Smoke test using a fake yt_dlp.YoutubeDL."""
    captured: dict[str, Any] = {}

    class _FakeYDL:
        def __init__(self, opts):
            captured["opts"] = opts

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return None

        def extract_info(self, video_id, download=False):
            return {
                "id": video_id,
                "title": "T",
                "duration": 180,
                "formats": [
                    {
                        "format_id": "251",
                        "ext": "webm",
                        "acodec": "opus",
                        "abr": 160,
                        "url": "https://rr.googlevideo.com/sig?xyz",
                        "filesize": 4321,
                        "approx_duration_ms": 180000,
                    },
                ],
            }

    import ytmusic_api.services.stream_resolver as sr

    monkeypatch.setattr(sr, "YoutubeDL", _FakeYDL)

    resolver = StreamResolver(pot_provider_url="http://pot:4416")
    result = await resolver.resolve("abc", codec="opus", quality="high")

    assert isinstance(result, ResolvedStream)
    assert result.video_id == "abc"
    assert result.url.startswith("https://rr.googlevideo.com/")
    assert result.codec == "opus"
    assert result.container == "webm"
    assert result.bitrate == 160_000
    assert result.content_length == 4321
    assert result.expires_at > datetime.utcnow()

    # Verify pot-provider URL was wired into yt-dlp opts.
    extractor_args = captured["opts"]["extractor_args"]
    assert "youtube" in extractor_args
    pot_values = [
        v for vs in extractor_args["youtube"].values() for v in vs
    ]
    assert any("pot:4416" in v for v in pot_values)
