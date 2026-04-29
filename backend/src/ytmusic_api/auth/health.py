from __future__ import annotations

import asyncio
import logging
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Literal

logger = logging.getLogger(__name__)

AuthLabel = Literal["ok", "expired", "unknown"]


@dataclass(frozen=True)
class AuthStatus:
    label: AuthLabel
    last_ok_at: datetime | None


class AuthHealthMonitor:
    """Periodically calls an async check; records ok/expired/unknown."""

    def __init__(
        self,
        check: Callable[[], Awaitable[None]],
        interval: float = 900.0,
    ) -> None:
        self._check = check
        self._interval = interval
        self._status: AuthStatus = AuthStatus(label="unknown", last_ok_at=None)
        self._stop_event = asyncio.Event()

    def status(self) -> AuthStatus:
        return self._status

    def stop(self) -> None:
        self._stop_event.set()

    async def run(self) -> None:
        while not self._stop_event.is_set():
            try:
                await self._check()
                self._status = AuthStatus(
                    label="ok",
                    last_ok_at=datetime.now(UTC),
                )
            except Exception as exc:
                # Broad except is intentional: we want any failure (auth, network,
                # parse) to flip status to "expired" without crashing the loop.
                logger.warning(
                    "Auth health check failed (%s): %s", type(exc).__name__, exc
                )
                self._status = AuthStatus(
                    label="expired",
                    last_ok_at=self._status.last_ok_at,
                )

            try:
                await asyncio.wait_for(
                    self._stop_event.wait(), timeout=self._interval
                )
            except TimeoutError:
                continue
