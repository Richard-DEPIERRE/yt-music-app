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
