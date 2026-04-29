import asyncio
from datetime import UTC, datetime, timedelta

import pytest

from ytmusic_api.auth.health import AuthHealthMonitor, AuthStatus


def test_initial_status_is_unknown():
    monitor = AuthHealthMonitor(check=lambda: None, interval=0.05)
    assert monitor.status() == AuthStatus(label="unknown", last_ok_at=None)


@pytest.mark.asyncio
async def test_run_records_ok_when_check_succeeds():
    async def check_ok():
        return None  # success: no exception

    monitor = AuthHealthMonitor(check=check_ok, interval=0.05)
    task = asyncio.create_task(monitor.run())
    await asyncio.sleep(0.15)  # at least one tick
    monitor.stop()
    await task

    status = monitor.status()
    assert status.label == "ok"
    assert status.last_ok_at is not None
    assert datetime.now(UTC) - status.last_ok_at < timedelta(seconds=2)


@pytest.mark.asyncio
async def test_run_records_expired_when_check_raises():
    async def check_expired():
        raise RuntimeError("auth expired")

    monitor = AuthHealthMonitor(check=check_expired, interval=0.05)
    task = asyncio.create_task(monitor.run())
    await asyncio.sleep(0.15)
    monitor.stop()
    await task

    assert monitor.status().label == "expired"


@pytest.mark.asyncio
async def test_recovery_from_expired_to_ok():
    state = {"calls": 0}

    async def flaky():
        state["calls"] += 1
        if state["calls"] == 1:
            raise RuntimeError("expired")
        return None

    monitor = AuthHealthMonitor(check=flaky, interval=0.05)
    task = asyncio.create_task(monitor.run())
    await asyncio.sleep(0.25)  # at least 2 ticks
    monitor.stop()
    await task

    assert monitor.status().label == "ok"
