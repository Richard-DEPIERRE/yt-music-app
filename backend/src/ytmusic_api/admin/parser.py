from __future__ import annotations

import re

# Matches:  -H 'header: value'  (Chrome DevTools "Copy as cURL (bash)" format)
_HEADER_RE = re.compile(r"-H\s+'([^:]+):\s*([^']+)'")

# Matches:  -b 'cookie1=...; cookie2=...'  (Chrome puts cookies here, not in -H)
_COOKIE_RE = re.compile(r"-b\s+'([^']+)'")


def parse_curl_headers(raw: str) -> dict[str, str]:
    """Extract HTTP header pairs from a curl command (DevTools 'Copy as cURL').

    Chrome's "Copy as cURL (bash)" emits cookies via the ``-b`` flag rather than
    ``-H 'cookie: ...'``, so we accept both forms. If both are present, the
    explicit ``-H 'cookie: ...'`` takes precedence.
    """
    headers: dict[str, str] = {}
    for match in _HEADER_RE.finditer(raw):
        name = match.group(1).strip()
        value = match.group(2).strip()
        # Title-case header names (HTTP is case-insensitive but be tidy)
        canonical = "-".join(part.capitalize() for part in name.split("-"))
        headers[canonical] = value

    if "Cookie" not in headers:
        cookie_match = _COOKIE_RE.search(raw)
        if cookie_match:
            headers["Cookie"] = cookie_match.group(1).strip()

    if "Cookie" not in headers:
        raise ValueError(
            "curl input missing required Cookie header (expected either "
            "-H 'cookie: ...' or -b 'cookie1=...; cookie2=...')"
        )

    return headers
