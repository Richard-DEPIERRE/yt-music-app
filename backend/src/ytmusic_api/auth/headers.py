from __future__ import annotations

import json
import logging
import os
from pathlib import Path
from typing import Any

from watchfiles import awatch

logger = logging.getLogger(__name__)


class HeadersStore:
    """Loads and watches the YT Music auth headers JSON file.

    Hot-reloads the in-memory copy when the file changes on disk.
    """

    def __init__(self, path: Path) -> None:
        self._path = path
        self._cached: dict[str, Any] | None = None
        self._load()

    def _load(self) -> None:
        try:
            text = self._path.read_text()
            self._cached = json.loads(text)
        except FileNotFoundError:
            self._cached = None
        except json.JSONDecodeError as exc:
            logger.error("Invalid JSON in %s: %s", self._path, exc)
            self._cached = None

    def current(self) -> dict[str, Any] | None:
        return self._cached

    def save(self, headers: dict[str, Any]) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._path.write_text(json.dumps(headers, indent=2))
        try:
            os.chmod(self._path, 0o600)
        except OSError:
            pass
        self._cached = dict(headers)

    async def watch(self) -> None:
        """Run forever; reload self._cached whenever the file changes."""
        watch_dir = self._path.parent
        watch_dir.mkdir(parents=True, exist_ok=True)
        async for changes in awatch(watch_dir, debounce=100):
            for _change_type, changed_path in changes:
                if Path(changed_path) == self._path:
                    self._load()
                    logger.info("Reloaded headers from %s", self._path)
                    break
