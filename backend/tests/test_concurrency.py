import asyncio

import pytest

from ytmusic_api.services.concurrency import BoundedRunner


@pytest.mark.asyncio
async def test_runs_serially_when_max_is_one():
    runner = BoundedRunner(max_concurrent=1)
    started: list[int] = []
    finished: list[int] = []

    async def task(i: int) -> int:
        started.append(i)
        await asyncio.sleep(0.05)
        finished.append(i)
        return i

    results = await asyncio.gather(*(runner.run(task, i) for i in range(3)))
    assert results == [0, 1, 2]
    # Serial execution: each task finishes before the next starts.
    assert started == [0, 1, 2]
    assert finished == [0, 1, 2]


@pytest.mark.asyncio
async def test_propagates_exceptions():
    runner = BoundedRunner(max_concurrent=2)

    async def boom() -> None:
        raise RuntimeError("nope")

    with pytest.raises(RuntimeError, match="nope"):
        await runner.run(boom)


@pytest.mark.asyncio
async def test_allows_two_in_flight_when_max_is_two():
    runner = BoundedRunner(max_concurrent=2)
    in_flight = 0
    max_observed = 0
    lock = asyncio.Lock()

    async def task() -> None:
        nonlocal in_flight, max_observed
        async with lock:
            in_flight += 1
            max_observed = max(max_observed, in_flight)
        await asyncio.sleep(0.05)
        async with lock:
            in_flight -= 1

    await asyncio.gather(*(runner.run(task) for _ in range(4)))
    assert max_observed == 2  # never more than 2 simultaneously
