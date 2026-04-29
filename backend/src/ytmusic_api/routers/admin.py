from __future__ import annotations

import logging
from pathlib import Path

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates

from ..admin.parser import parse_curl_headers
from ..auth.headers import HeadersStore
from ..auth.health import AuthHealthMonitor

logger = logging.getLogger(__name__)

_TEMPLATES_DIR = Path(__file__).resolve().parent.parent / "admin" / "templates"
templates = Jinja2Templates(directory=_TEMPLATES_DIR)

router = APIRouter()


@router.get("/admin", response_class=HTMLResponse)
def admin_index(request: Request) -> HTMLResponse:
    monitor: AuthHealthMonitor = request.app.state.auth_monitor
    status = monitor.status()
    return templates.TemplateResponse(
        request,
        "index.html",
        {
            "auth_status": status.label,
            "last_ok_at": status.last_ok_at.isoformat() if status.last_ok_at else None,
            "error": None,
            "message": None,
        },
    )


@router.post("/admin/cookies/refresh")
def admin_refresh(request: Request, curl_input: str = Form(...)):
    store: HeadersStore = request.app.state.headers_store
    monitor: AuthHealthMonitor = request.app.state.auth_monitor

    try:
        headers = parse_curl_headers(curl_input)
    except ValueError as exc:
        logger.warning("Bad curl input: %s", exc)
        status = monitor.status()
        return templates.TemplateResponse(
            request,
            "index.html",
            {
                "auth_status": status.label,
                "last_ok_at": status.last_ok_at.isoformat() if status.last_ok_at else None,
                "error": str(exc),
                "message": None,
            },
            status_code=400,
        )

    store.save(headers)
    return RedirectResponse(url="/admin", status_code=303)
