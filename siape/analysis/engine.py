"""Motor de análisis (Opción 1): datos del periodo → reporte ejecutivo vía LLM.

Funciona con datos curados a mano (data/periodo_ejemplo.json u otro archivo
con el mismo formato) sin depender de la capa de ingesta automatizada.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import anthropic

from config.settings import settings
from siape.analysis.schemas import ReporteEjecutivo

PROMPT_PATH = Path(__file__).parent / "prompts" / "analyst_system.md"

USER_INSTRUCTIONS = (
    "Datos del periodo (JSON). Responde solo con el JSON de ReporteEjecutivo "
    "descrito en la Sección 10 del prompt de sistema, sin texto adicional ni "
    "bloques de código markdown.\n\n"
)


def load_system_prompt() -> str:
    return PROMPT_PATH.read_text(encoding="utf-8")


def load_period_data(period_file: str | Path) -> dict[str, Any]:
    return json.loads(Path(period_file).read_text(encoding="utf-8"))


def build_client() -> anthropic.Anthropic:
    if not settings.anthropic_api_key:
        raise RuntimeError(
            "ANTHROPIC_API_KEY no configurada. Copia .env.example a .env y agrega tu API key."
        )
    return anthropic.Anthropic(api_key=settings.anthropic_api_key)


def parse_response(raw_text: str) -> ReporteEjecutivo:
    data = json.loads(raw_text)
    return ReporteEjecutivo.model_validate(data)


def run_analysis(
    period_file: str | Path, client: anthropic.Anthropic | None = None
) -> ReporteEjecutivo:
    """Genera el reporte ejecutivo a partir de un archivo de datos del periodo.

    `client` es inyectable para pruebas (evita llamadas reales a la API).
    """
    period_data = load_period_data(period_file)
    system_prompt = load_system_prompt()
    client = client or build_client()

    response = client.messages.create(
        model=settings.siape_model,
        max_tokens=settings.siape_max_tokens,
        system=system_prompt,
        messages=[
            {
                "role": "user",
                "content": USER_INSTRUCTIONS
                + json.dumps(period_data, ensure_ascii=False, indent=2),
            }
        ],
    )

    raw_text = response.content[0].text
    return parse_response(raw_text)
