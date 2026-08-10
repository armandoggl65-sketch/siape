"""Conector de YouTube: estadísticas públicas de un canal (Data API v3).

# TODO(verificar-ToS): revisar los Términos de Servicio y la Política de Datos
de la YouTube Data API antes de operar este conector en producción.
"""
from __future__ import annotations

import datetime as dt

from googleapiclient.discovery import build

from config.settings import settings
from siape.ingest.base import BaseConnector, RawObservation


class YouTubeConnector(BaseConnector):
    def __init__(
        self,
        channel_id: str,
        actor_nombre: str | None = None,
        api_key: str | None = None,
        client=None,
    ):
        self.channel_id = channel_id
        self.actor_nombre = actor_nombre
        self.api_key = api_key or settings.youtube_api_key
        self._client = client

    def _build_client(self):
        if self._client is not None:
            return self._client
        if not self.api_key:
            raise RuntimeError(
                "YOUTUBE_API_KEY no configurada. Copia .env.example a .env y agrega tu API key."
            )
        return build("youtube", "v3", developerKey=self.api_key)

    def fetch(self) -> list[RawObservation]:
        youtube = self._build_client()
        response = youtube.channels().list(part="statistics", id=self.channel_id).execute()
        items = response.get("items", [])
        if not items:
            return []

        stats = items[0]["statistics"]
        fecha = dt.date.today().isoformat()
        fuente_nombre = f"YouTube — canal {self.channel_id}"
        observations: list[RawObservation] = []

        if "subscriberCount" in stats:
            observations.append(
                RawObservation(
                    actor_nombre=self.actor_nombre,
                    fuente_nombre=fuente_nombre,
                    source_level=3,
                    tipo_fuente="redes",
                    plataforma="YouTube",
                    tipo="seguidores_youtube",
                    fecha=fecha,
                    confianza="alto",
                    valor_numerico=float(stats["subscriberCount"]),
                )
            )
        if "viewCount" in stats:
            observations.append(
                RawObservation(
                    actor_nombre=self.actor_nombre,
                    fuente_nombre=fuente_nombre,
                    source_level=3,
                    tipo_fuente="redes",
                    plataforma="YouTube",
                    tipo="vistas_totales_youtube",
                    fecha=fecha,
                    confianza="alto",
                    valor_numerico=float(stats["viewCount"]),
                )
            )
        return observations
