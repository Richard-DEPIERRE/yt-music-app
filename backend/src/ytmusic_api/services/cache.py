from __future__ import annotations

import json
import sqlite3
import threading
import time
from typing import Any


class TtlCache:
    """Process-local TTL cache backed by an in-memory SQLite DB.

    Values are JSON-encoded so consumers must use JSON-friendly data.
    Thread-safe via a single lock; fine for our concurrency level.
    """

    def __init__(self) -> None:
        self._conn = sqlite3.connect(":memory:", check_same_thread=False)
        self._lock = threading.Lock()
        with self._lock:
            self._conn.execute(
                "CREATE TABLE entries (k TEXT PRIMARY KEY, v TEXT, expires_at REAL)"
            )

    def get(self, key: str) -> Any | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT v, expires_at FROM entries WHERE k = ?", (key,)
            ).fetchone()
            if row is None:
                return None
            value, expires_at = row
            if expires_at < time.time():
                self._conn.execute("DELETE FROM entries WHERE k = ?", (key,))
                return None
            return json.loads(value)

    def set(self, key: str, value: Any, *, ttl_seconds: float) -> None:
        expires_at = time.time() + ttl_seconds
        encoded = json.dumps(value)
        with self._lock:
            self._conn.execute(
                "INSERT INTO entries(k, v, expires_at) VALUES(?, ?, ?) "
                "ON CONFLICT(k) DO UPDATE SET v=excluded.v, expires_at=excluded.expires_at",
                (key, encoded, expires_at),
            )

    def clear(self) -> None:
        with self._lock:
            self._conn.execute("DELETE FROM entries")
