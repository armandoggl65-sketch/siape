import dataclasses

import pytest

from siape.ingest import meta as meta_module
from siape.ingest.meta import MetaConnector


class FakeResponse:
    def __init__(self, json_data, status_code=200):
        self._json_data = json_data
        self.status_code = status_code

    def raise_for_status(self):
        if self.status_code >= 400:
            raise RuntimeError(f"HTTP {self.status_code}")

    def json(self):
        return self._json_data


class FakeSession:
    def __init__(self, json_data):
        self._json_data = json_data
        self.last_call: tuple | None = None

    def get(self, url, params=None):
        self.last_call = (url, params)
        return FakeResponse(self._json_data)


def test_meta_connector_parsea_fan_count():
    session = FakeSession({"fan_count": 5400})
    connector = MetaConnector(
        page_id="123456", actor_nombre="Tonanzin Fernández", access_token="fake-token", session=session
    )

    observations = connector.fetch()

    assert len(observations) == 1
    obs = observations[0]
    assert obs.valor_numerico == 5400.0
    assert obs.tipo == "seguidores_facebook"
    assert obs.source_level == 3
    assert obs.confianza == "alto"
    assert session.last_call[1]["access_token"] == "fake-token"
    assert "123456" in session.last_call[0]


def test_meta_connector_sin_fan_count_devuelve_vacio():
    session = FakeSession({})
    connector = MetaConnector(page_id="123456", access_token="fake-token", session=session)

    assert connector.fetch() == []


def test_meta_connector_requiere_access_token(monkeypatch):
    sin_token = dataclasses.replace(meta_module.settings, meta_access_token=None)
    monkeypatch.setattr(meta_module, "settings", sin_token)

    with pytest.raises(RuntimeError):
        MetaConnector(page_id="123456")
