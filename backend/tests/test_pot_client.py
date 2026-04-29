import httpx
import pytest

from ytmusic_api.services.pot_client import PotClient


@pytest.mark.asyncio
async def test_ping_returns_true_on_200():
    async def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/ping"
        return httpx.Response(200, json={"server_uptime": 1, "version": "1.3.1"})

    transport = httpx.MockTransport(handler)
    client = PotClient(base_url="http://pot:4416", transport=transport)
    try:
        assert await client.ping() is True
    finally:
        await client.aclose()


@pytest.mark.asyncio
async def test_ping_returns_false_on_500():
    async def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500)

    transport = httpx.MockTransport(handler)
    client = PotClient(base_url="http://pot:4416", transport=transport)
    try:
        assert await client.ping() is False
    finally:
        await client.aclose()


@pytest.mark.asyncio
async def test_ping_returns_false_on_connection_error():
    async def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("nope")

    transport = httpx.MockTransport(handler)
    client = PotClient(base_url="http://pot:4416", transport=transport)
    try:
        assert await client.ping() is False
    finally:
        await client.aclose()
