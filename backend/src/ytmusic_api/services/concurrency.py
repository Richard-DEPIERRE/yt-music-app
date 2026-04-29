from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from typing import Any, TypeVar

T = TypeVar("T")


class BoundedRunner:
    """Wraps an asyncio.Semaphore so callers don't manage `async with` themselves."""

    def __init__(self, *, max_concurrent: int) -> None:
        self._sem = asyncio.Semaphore(max_concurrent)

    async def run(
        self,
        fn: Callable[..., Awaitable[T]],
        *args: Any,
        **kwargs: Any,
    ) -> T:
        async with self._sem:
            return await fn(*args, **kwargs)
