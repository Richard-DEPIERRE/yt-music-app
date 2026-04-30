from __future__ import annotations

import logging

import httpx

logger = logging.getLogger(__name__)


class PotClient:
    """Talks to the bgutil-ytdlp-pot-provider sidecar.

    Used for healthchecks; yt-dlp itself integrates with the sidecar via the
    `po_token_provider_url` extractor-args flag (out of band of this client).
    """

    def __init__(
        self,
        *,
        base_url: str,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self._client = httpx.AsyncClient(
            base_url=base_url,
            timeout=httpx.Timeout(2.0, connect=1.0),
            transport=transport,
        )

    async def ping(self) -> bool:
        try:
            res = await self._client.get("/ping")
            return res.status_code == 200
        except (httpx.RequestError, httpx.HTTPError) as exc:
            logger.debug("pot-provider ping failed: %s", exc)
            return False

    async def aclose(self) -> None:
        await self._client.aclose()
