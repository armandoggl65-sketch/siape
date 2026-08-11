import dataclasses
from pathlib import Path
from types import SimpleNamespace

import pytest

from siape.analysis import engine
from siape.analysis.engine import build_client, load_period_data, load_system_prompt, run_analysis

REPO_ROOT = Path(__file__).parent.parent
PERIODO_EJEMPLO = REPO_ROOT / "data" / "periodo_ejemplo.json"

REPORTE_DICT = {
    "resumen_ejecutivo": ["Hallazgo de prueba"],
    "indicadores": [],
    "analisis_por_dimension": [],
    "alertas": [],
    "recomendaciones": [],
    "vacios_informacion": [],
    "fecha_corte": "2026-08-07",
    "nivel_confianza_general": "medio",
}


class FakeMessages:
    def __init__(self, tool_input: dict, con_thinking: bool = False):
        self._tool_input = tool_input
        self._con_thinking = con_thinking
        self.last_call: dict | None = None

    def create(self, **kwargs):
        self.last_call = kwargs
        content = []
        if self._con_thinking:
            # Con extended thinking, el modelo antepone un bloque que no es tool_use.
            content.append(SimpleNamespace(type="thinking", thinking="..."))
        content.append(
            SimpleNamespace(type="tool_use", name="reportar_analisis", input=self._tool_input)
        )
        return SimpleNamespace(content=content)


class FakeAnthropicClient:
    def __init__(self, tool_input: dict = REPORTE_DICT, con_thinking: bool = False):
        self.messages = FakeMessages(tool_input, con_thinking=con_thinking)


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
    llamada = fake_client.messages.last_call
    # el motor debe mandar el system prompt y los datos del periodo en el mensaje
    assert "analista senior" in llamada["system"].lower()
    assert "Tonanzin Fernández" in llamada["messages"][0]["content"]
    # y debe forzar la respuesta estructurada vía tool use (Sección 10)
    assert llamada["tools"][0]["name"] == "reportar_analisis"
    assert llamada["tool_choice"] == {"type": "tool", "name": "reportar_analisis"}


def test_run_analysis_ignora_bloques_que_no_son_tool_use():
    """Regresión: con extended thinking, el primer bloque puede no ser tool_use —
    el motor debe encontrarlo por tipo, no asumir índice 0."""
    fake_client = FakeAnthropicClient(con_thinking=True)

    reporte = run_analysis(PERIODO_EJEMPLO, client=fake_client)

    assert reporte.fecha_corte == "2026-08-07"
