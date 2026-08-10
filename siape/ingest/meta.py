"""Conector de Meta (Facebook/Instagram): páginas PROPIAS del proyecto vía Graph API.

Solo páginas propias — nunca observación de terceros (README →
"Realidad de acceso a datos"). Para adversarios/terceros, la única fuente
lícita es la observación pública manual (capa `ingest/manual/`).

# TODO(verificar-ToS): revisar los Términos de Servicio y la Política de Datos
de Meta Graph API antes de operar este conector en producción.
"""
from __future__ import annotations

import datetime as dt

import requests

from config.settings import settings
from siape.ingest.base import BaseConnector, RawObservation

GRAPH_API_BASE = "https://graph.facebook.com/v19.0"


class MetaConnector(BaseConnector):
    def __init__(
        self,
        page_id: str,
        actor_nombre: str | None = None,
        access_token: str | None = None,
        session=None,
    ):
        self.page_id = page_id
        self.actor_nombre = actor_nombre
        self.access_token = access_token or settings.meta_access_token
        self._session = session or requests

        if not self.access_token:
            raise RuntimeError(
                "META_ACCESS_TOKEN no configurado. Copia .env.example a .env y agrega tu token."
            )

    def fetch(self) -> list[RawObservation]:
        response = self._session.get(
            f"{GRAPH_API_BASE}/{self.page_id}",
            params={"fields": "fan_count", "access_token": self.access_token},
        )
        response.raise_for_status()
        data = response.json()

        if "fan_count" not in data:
            return []

        return [
            RawObservation(
                actor_nombre=self.actor_nombre,
                fuente_nombre=f"Facebook (página propia) — {self.page_id}",
                source_level=3,
                tipo_fuente="redes",
                plataforma="Facebook",
                tipo="seguidores_facebook",
                fecha=dt.date.today().isoformat(),
                confianza="alto",
                valor_numerico=float(data["fan_count"]),
            )
        ]
