from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="", env_file=None)

    yt_headers_path: Path = Field(default=Path("/secrets/yt_headers.json"))
    pot_provider_url: str = Field(default="http://pot-provider:4416")
    auth_health_interval: int = Field(default=900)  # seconds


@lru_cache
def get_settings() -> Settings:
    return Settings()
