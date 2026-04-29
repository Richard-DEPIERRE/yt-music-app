from fastapi import APIRouter

from ..models.health import HealthResponse

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    # Imported here (not at module load) to keep this router decoupled from
    # main.py's app construction and avoid an import cycle.
    from ..main import API_VERSION

    return HealthResponse(
        status="degraded",
        auth_status="unknown",
        last_ok_at=None,
        pot_provider_ok=None,
        version=API_VERSION,
    )
