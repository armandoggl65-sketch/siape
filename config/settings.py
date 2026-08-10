"""Configuración de SIAPE cargada desde variables de entorno (.env)."""
from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Settings:
    anthropic_api_key: str | None
    siape_model: str
    siape_max_tokens: int
    database_url: str
    youtube_api_key: str | None
    x_bearer_token: str | None
    meta_access_token: str | None
    siape_municipio: str
    siape_proceso: str


def load_settings() -> Settings:
    return Settings(
        anthropic_api_key=os.getenv("ANTHROPIC_API_KEY"),
        siape_model=os.getenv("SIAPE_MODEL", "claude-sonnet-5"),
        siape_max_tokens=int(os.getenv("SIAPE_MAX_TOKENS", "4096")),
        database_url=os.getenv("DATABASE_URL", "sqlite:///siape_dev.db"),
        youtube_api_key=os.getenv("YOUTUBE_API_KEY") or None,
        x_bearer_token=os.getenv("X_BEARER_TOKEN") or None,
        meta_access_token=os.getenv("META_ACCESS_TOKEN") or None,
        siape_municipio=os.getenv("SIAPE_MUNICIPIO", "San Pedro Cholula, Puebla"),
        siape_proceso=os.getenv("SIAPE_PROCESO", "Elección local 2027"),
    )


settings = load_settings()
