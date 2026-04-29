from ytmusic_api.admin.parser import parse_curl_headers


def test_parses_basic_curl_headers():
    raw = """curl 'https://music.youtube.com/youtubei/v1/browse' \\
      -H 'authority: music.youtube.com' \\
      -H 'cookie: SAPISID=abc; HSID=xyz' \\
      -H 'user-agent: Mozilla/5.0 (Macintosh; Intel)' \\
      -H 'authorization: SAPISIDHASH 1700000000_abc' \\
      -H 'x-goog-authuser: 0' \\
      --data-raw '{}' \\
      --compressed"""
    headers = parse_curl_headers(raw)

    assert headers["Cookie"] == "SAPISID=abc; HSID=xyz"
    assert headers["User-Agent"] == "Mozilla/5.0 (Macintosh; Intel)"
    assert headers["Authorization"] == "SAPISIDHASH 1700000000_abc"
    assert headers["X-Goog-Authuser"] == "0"


def test_rejects_input_without_cookie():
    raw = "curl 'https://example.com' -H 'user-agent: x'"
    try:
        parse_curl_headers(raw)
    except ValueError as exc:
        assert "cookie" in str(exc).lower()
    else:
        raise AssertionError("expected ValueError")


def test_parses_chrome_b_flag_cookies():
    """Chrome DevTools 'Copy as cURL (bash)' emits cookies via -b, not -H."""
    raw = (
        "curl 'https://music.youtube.com/youtubei/v1/browse' "
        "-H 'user-agent: Mozilla/5.0' "
        "-H 'authorization: SAPISIDHASH 1700000000_abc' "
        "-b 'YSC=foo; SAPISID=bar; __Secure-1PSID=baz'"
    )
    headers = parse_curl_headers(raw)

    assert headers["Cookie"] == "YSC=foo; SAPISID=bar; __Secure-1PSID=baz"
    assert headers["User-Agent"] == "Mozilla/5.0"
    assert headers["Authorization"] == "SAPISIDHASH 1700000000_abc"


def test_h_cookie_takes_precedence_over_b_flag():
    """If both -H 'cookie: ...' and -b are present, -H wins."""
    raw = (
        "curl 'https://example.com' "
        "-H 'cookie: from_h=1' "
        "-b 'from_b=2'"
    )
    headers = parse_curl_headers(raw)
    assert headers["Cookie"] == "from_h=1"


import pytest  # noqa: E402


@pytest.fixture
def admin_client(headers_store, auth_monitor):
    """Variant of the client where save() validation is stubbed."""
    from fastapi.testclient import TestClient

    from ytmusic_api.main import create_app

    app = create_app(headers_store=headers_store, auth_monitor=auth_monitor)
    return TestClient(app)


def test_admin_page_renders(admin_client):
    response = admin_client.get("/admin")
    assert response.status_code == 200
    # Verify the rendered template, not just an "auth" substring.
    assert "Auth:" in response.text
    assert "unknown" in response.text  # default status from the StubMonitor
    assert 'name="curl_input"' in response.text  # the form is present


def test_admin_post_saves_headers(admin_client, headers_store):
    raw_curl = (
        "curl 'https://music.youtube.com/youtubei/v1/browse' "
        "-H 'cookie: SAPISID=abc' "
        "-H 'user-agent: Mozilla/5.0' "
        "-H 'authorization: SAPISIDHASH 123_abc'"
    )

    response = admin_client.post(
        "/admin/cookies/refresh",
        data={"curl_input": raw_curl},
        follow_redirects=False,
    )

    assert response.status_code in (200, 303)
    saved = headers_store.current()
    assert saved is not None
    assert saved["Cookie"] == "SAPISID=abc"


def test_admin_post_rejects_invalid_input(admin_client, headers_store):
    response = admin_client.post(
        "/admin/cookies/refresh",
        data={"curl_input": "not a curl command"},
        follow_redirects=False,
    )
    assert response.status_code == 400
    assert headers_store.current() is None
    # New assertion: the error block from the template should be populated.
    assert "missing required Cookie" in response.text
