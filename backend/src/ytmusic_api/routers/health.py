from fastapi import APIRouter, Request

from ..auth.health import AuthHealthMonitor
from ..models.health import HealthResponse

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
def health(request: Request) -> HealthResponse:
    # Imported here (not at module load) to keep this router decoupled from
    # main.py's app construction and avoid an import cycle.
    from ..main import API_VERSION

    monitor: AuthHealthMonitor = request.app.state.auth_monitor
    status = monitor.status()
    return HealthResponse(
        status="ok" if status.label == "ok" else "degraded",
        auth_status=status.label,
        last_ok_at=status.last_ok_at,
        pot_provider_ok=None,  # wired in Phase 1+
        version=API_VERSION,
    )
