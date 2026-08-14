"""Configuración de SIAPE cargada desde variables de entorno (.env) o, si no
están ahí, desde los "Secrets" de Streamlit Community Cloud (para el
despliegue del tablero sin depender de un .env local)."""
from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


def _get_secret(key: str, default: str | None = None) -> str | None:
    """Variable de entorno primero; si no está, intenta st.secrets (solo
    disponible cuando corre dentro de Streamlit, p. ej. en Streamlit
    Community Cloud). Nunca falla si Streamlit no está en un contexto de
    app (scripts CLI, tests)."""
    value = os.getenv(key)
    if value is not None:
        return value
    try:
        import streamlit as st

        return st.secrets.get(key, default)
    except Exception:
        return default


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
        anthropic_api_key=_get_secret("ANTHROPIC_API_KEY"),
        siape_model=_get_secret("SIAPE_MODEL", "claude-sonnet-5"),
        siape_max_tokens=int(_get_secret("SIAPE_MAX_TOKENS", "4096")),
        database_url=_get_secret("DATABASE_URL", "sqlite:///siape_dev.db"),
        youtube_api_key=_get_secret("YOUTUBE_API_KEY") or None,
        x_bearer_token=_get_secret("X_BEARER_TOKEN") or None,
        meta_access_token=_get_secret("META_ACCESS_TOKEN") or None,
        siape_municipio=_get_secret("SIAPE_MUNICIPIO", "San Pedro Cholula, Puebla"),
        siape_proceso=_get_secret("SIAPE_PROCESO", "Elección local 2027"),
    )


settings = load_settings()
