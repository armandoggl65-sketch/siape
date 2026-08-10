import dataclasses

import pytest

from siape.ingest import youtube as youtube_module
from siape.ingest.youtube import YouTubeConnector


class FakeYouTubeClient:
    """Simula la cadena channels().list(...).execute() del SDK de Google."""

    def __init__(self, response):
        self._response = response

    def channels(self):
        return self

    def list(self, **kwargs):
        return self

    def execute(self):
        return self._response


def test_youtube_connector_parsea_estadisticas():
    client = FakeYouTubeClient(
        {"items": [{"statistics": {"subscriberCount": "18200", "viewCount": "500000"}}]}
    )
    connector = YouTubeConnector(channel_id="UCxxxx", actor_nombre="Tonanzin Fernández", client=client)

    observations = connector.fetch()

    assert len(observations) == 2
    seguidores = next(o for o in observations if o.tipo == "seguidores_youtube")
    assert seguidores.valor_numerico == 18200.0
    assert seguidores.source_level == 3
    assert seguidores.confianza == "alto"
    assert seguidores.actor_nombre == "Tonanzin Fernández"

    vistas = next(o for o in observations if o.tipo == "vistas_totales_youtube")
    assert vistas.valor_numerico == 500000.0


def test_youtube_connector_sin_items_devuelve_vacio():
    client = FakeYouTubeClient({"items": []})
    connector = YouTubeConnector(channel_id="UCxxxx", client=client)

    assert connector.fetch() == []


def test_youtube_connector_requiere_api_key_sin_cliente(monkeypatch):
    sin_api_key = dataclasses.replace(youtube_module.settings, youtube_api_key=None)
    monkeypatch.setattr(youtube_module, "settings", sin_api_key)

    connector = YouTubeConnector(channel_id="UCxxxx")

    with pytest.raises(RuntimeError):
        connector.fetch()
