import dataclasses
import json
from pathlib import Path
from types import SimpleNamespace

import pytest

from siape.analysis import engine
from siape.analysis.engine import build_client, load_period_data, load_system_prompt, run_analysis

REPO_ROOT = Path(__file__).parent.parent
PERIODO_EJEMPLO = REPO_ROOT / "data" / "periodo_ejemplo.json"

REPORTE_JSON = json.dumps(
    {
        "resumen_ejecutivo": ["Hallazgo de prueba"],
        "indicadores": [],
        "analisis_por_dimension": [],
        "alertas": [],
        "recomendaciones": [],
        "vacios_informacion": [],
        "fecha_corte": "2026-08-07",
        "nivel_confianza_general": "medio",
    }
)


class FakeMessages:
    def __init__(self, text: str):
        self._text = text
        self.last_call: dict | None = None

    def create(self, **kwargs):
        self.last_call = kwargs
        return SimpleNamespace(content=[SimpleNamespace(text=self._text)])


class FakeAnthropicClient:
    def __init__(self, text: str = REPORTE_JSON):
        self.messages = FakeMessages(text)


def test_load_system_prompt_no_vacio():
    prompt = load_system_prompt()
    assert "analista senior de inteligencia política" in prompt.lower()


def test_load_period_data_lee_json_de_ejemplo():
    data = load_period_data(PERIODO_EJEMPLO)
    assert data["actor_principal"]["nombre"] == "Tonanzin Fernández"


def test_build_client_sin_api_key_lanza_error(monkeypatch):
    sin_api_key = dataclasses.replace(engine.settings, anthropic_api_key=None)
    monkeypatch.setattr(engine, "settings", sin_api_key)
    with pytest.raises(RuntimeError):
        build_client()


def test_run_analysis_con_cliente_simulado():
    fake_client = FakeAnthropicClient()

    reporte = run_analysis(PERIODO_EJEMPLO, client=fake_client)

    assert reporte.fecha_corte == "2026-08-07"
    assert reporte.resumen_ejecutivo == ["Hallazgo de prueba"]
    # el motor debe mandar el system prompt y los datos del periodo en el mensaje
    assert "analista senior" in fake_client.messages.last_call["system"].lower()
    assert "Tonanzin Fernández" in fake_client.messages.last_call["messages"][0]["content"]
