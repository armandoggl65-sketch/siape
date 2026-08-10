"""Conector de medios: RSS de prensa local/regional (Sección 4, Nivel 2)."""
from __future__ import annotations

import datetime as dt

import feedparser

from siape.ingest.base import BaseConnector, RawObservation


class RSSConnector(BaseConnector):
    def __init__(self, feed_urls: list[str], actor_nombre: str | None = None):
        self.feed_urls = feed_urls
        self.actor_nombre = actor_nombre

    def fetch(self) -> list[RawObservation]:
        observations: list[RawObservation] = []
        for url in self.feed_urls:
            parsed = feedparser.parse(url)
            fuente_nombre = parsed.feed.get("title") or url
            for entry in parsed.entries:
                observations.append(
                    RawObservation(
                        actor_nombre=self.actor_nombre,
                        fuente_nombre=fuente_nombre,
                        source_level=2,
                        tipo_fuente="medios",
                        tipo="nota_prensa",
                        fecha=self._fecha_de_entrada(entry),
                        confianza="medio",
                        texto=entry.get("title"),
                        url=entry.get("link"),
                    )
                )
        return observations

    @staticmethod
    def _fecha_de_entrada(entry) -> str:
        publicado = entry.get("published_parsed") or entry.get("updated_parsed")
        if publicado:
            return dt.date(*publicado[:3]).isoformat()
        return dt.date.today().isoformat()
