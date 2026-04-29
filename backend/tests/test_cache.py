import asyncio

import pytest

from ytmusic_api.services.cache import TtlCache


def test_get_returns_none_when_missing():
    cache = TtlCache()
    assert cache.get("missing") is None


def test_set_then_get_returns_value():
    cache = TtlCache()
    cache.set("k", {"hello": 1}, ttl_seconds=60)
    assert cache.get("k") == {"hello": 1}


@pytest.mark.asyncio
async def test_value_expires_after_ttl():
    cache = TtlCache()
    cache.set("k", "v", ttl_seconds=0.05)
    assert cache.get("k") == "v"
    await asyncio.sleep(0.1)
    assert cache.get("k") is None


def test_overwrite_resets_ttl():
    cache = TtlCache()
    cache.set("k", "v1", ttl_seconds=60)
    cache.set("k", "v2", ttl_seconds=60)
    assert cache.get("k") == "v2"


def test_clear_drops_all():
    cache = TtlCache()
    cache.set("a", 1, ttl_seconds=60)
    cache.set("b", 2, ttl_seconds=60)
    cache.clear()
    assert cache.get("a") is None
    assert cache.get("b") is None
