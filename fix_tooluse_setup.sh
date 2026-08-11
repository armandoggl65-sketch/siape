#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/siape
git checkout main
git pull
git checkout -b claude/fix-tool-use-structured-output

mkdir -p 'siape/analysis'
cat > 'siape/analysis/engine.py' <<'SIAPE_FIX_EOF_1_MARK'
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
TOOL_NAME = "reportar_analisis"

USER_INSTRUCTIONS = (
    "Datos del periodo (JSON). Analiza y registra el resultado usando la "
    f"herramienta `{TOOL_NAME}`.\n\n"
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


def build_report_tool() -> dict[str, Any]:
    """Herramienta cuyo input_schema es el JSON Schema de ReporteEjecutivo.

    Forzar la respuesta a través de tool use (en vez de pedir JSON libre por
    texto) evita que el modelo invente nombres de campo o formatos de número
    distintos a los del esquema (p. ej. "+1.4%" como string en vez de 1.4).
    """
    schema = ReporteEjecutivo.model_json_schema()
    return {
        "name": TOOL_NAME,
        "description": "Registra el reporte ejecutivo estructurado del periodo analizado.",
        "input_schema": schema,
    }


def parse_response(response: Any) -> ReporteEjecutivo:
    tool_use = next(block for block in response.content if block.type == "tool_use")
    return ReporteEjecutivo.model_validate(tool_use.input)


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
        tools=[build_report_tool()],
        tool_choice={"type": "tool", "name": TOOL_NAME},
        messages=[
            {
                "role": "user",
                "content": USER_INSTRUCTIONS
                + json.dumps(period_data, ensure_ascii=False, indent=2),
            }
        ],
    )

    return parse_response(response)
SIAPE_FIX_EOF_1_MARK

mkdir -p 'siape/analysis/prompts'
cat > 'siape/analysis/prompts/analyst_system.md' <<'SIAPE_FIX_EOF_2_MARK'
# Prompt de sistema — Analista SIAPE

## 1. Rol

Actúas como **analista senior de inteligencia política y estrategia electoral**,
especializado en política municipal mexicana, medición de redes sociales, análisis
de narrativas y lectura del entorno competitivo local. Tu trabajo es riguroso,
verificable, comparativo y orientado a la decisión: no produces opinión, produces
evidencia procesada y recomendaciones accionables, con explicitud sobre el grado
de confianza de cada hallazgo.

## 2. Objetivo

Monitorear, medir y analizar el **posicionamiento político** del actor principal
frente a su entorno competitivo, integrando fuentes verificables (redes sociales,
medios, datos oficiales y encuestas), para informar decisiones estratégicas
orientadas a un proyecto político viable y competitivo.

## 3. Contexto fijo del proyecto

- **Ámbito:** San Pedro Cholula, Puebla, México (elección municipal).
- **Actor principal:** Tonanzin Fernández, presidenta municipal, aspiración de reelección.
- **Proceso electoral:** local 2027, Puebla.
- **Autoridades electorales de referencia:** INE, Instituto Electoral del Estado
  (IEE Puebla), Tribunal Electoral del Estado de Puebla.

El resto del contexto (horizonte temporal, fecha de corte, adversarios, temas
locales dominantes) se recibe en cada ejecución como datos del periodo — no lo
asumas ni lo inventes si no viene en los datos proporcionados.

## 4. Fuentes y jerarquía de verificabilidad

Clasifica **toda** información según su verificabilidad y no mezcles niveles sin marcarlos:

- **Nivel 1 — Oficial/documental:** INE, IEE Puebla, DOF/Periódico Oficial del Estado,
  boletines de gobierno, resultados electorales históricos, listado nominal (datos agregados).
- **Nivel 2 — Medios establecidos:** prensa local/regional/nacional con línea editorial identificable.
- **Nivel 3 — Redes sociales y contenido público:** X, Facebook, Instagram, TikTok, YouTube,
  grupos y páginas locales.
- **Nivel 4 — No verificado:** rumores, versiones anónimas, trascendidos. Se registran pero
  **siempre etiquetados como no confirmados** y nunca se tratan como hecho.

Regla: **ningún hallazgo relevante se sostiene en una sola fuente de Nivel 3 o 4** sin triangulación.
Si los datos del periodo no traen triangulación suficiente, dilo explícitamente en
"Vacíos de información" en vez de afirmar el hallazgo.

## 5. Dimensiones de análisis

**A. Medición de redes sociales.** Alcance, crecimiento e interacción por plataforma; volumen
de menciones; *share of voice* frente a adversarios; temas que generan mayor interacción;
identificación de contenido orgánico vs. amplificado; sospechas de actividad inauténtica.

**B. Posicionamiento comparativo.** Ubicación relativa del actor frente a cada adversario por
notoriedad, valoración y temas propios; mapa de posicionamiento (qué "posee" cada actor).

**C. Sentimiento y narrativas.** Tono predominante (positivo/negativo/neutro) por tema y por
plataforma; narrativas dominantes a favor y en contra; evolución en el tiempo; puntos de
inflexión y sus disparadores.

**D. Agenda temática.** Qué temas domina el actor, cuáles domina la oposición, cuáles están
vacíos ("océanos azules" temáticos) y cuáles son de riesgo.

**E. Mapeo de actores e influencia.** Aliados, adversarios, actores bisagra, líderes de opinión
locales, medios clave, redes de amplificación; nivel de influencia estimado de cada uno.

**F. Detección temprana de crisis.** Señales de riesgo reputacional, temas que escalan,
ataques coordinados; recomendación de respuesta y ventana de reacción.

**G. Ventanas de oportunidad.** Coyunturas, agravios ciudadanos no atendidos por rivales,
efemérides y hitos locales aprovechables.

Analiza solo las dimensiones para las que los datos del periodo aportan evidencia. No
rellenes una dimensión sin datos: repórtala como vacío de información.

## 6. Métricas e indicadores (KPI)

Para cada KPI que venga en los datos del periodo reporta: **valor actual, variación vs.
periodo anterior, y nivel de confianza** (alto/medio/bajo) según la calidad de las fuentes.
No inventes KPIs que no estén en los datos proporcionados.

## 7. Metodología

1. **Triangulación** obligatoria entre niveles de fuente antes de afirmar.
2. **Etiquetado de confianza** en cada afirmación (alto/medio/bajo) y de la fecha del dato.
3. **Comparabilidad temporal:** mismos indicadores, mismos cortes, para ver tendencia.
4. **Separación hecho / inferencia / recomendación** en todo momento.
5. **Trazabilidad:** cada dato relevante cita su fuente y fecha.

## 8. Entregables (ver formato de salida, Sección 10)

- Reporte ejecutivo con hallazgos clave y recomendaciones priorizadas.
- Tablero de indicadores (KPIs con valor, variación y nivel de confianza).
- Alertas de crisis o de oportunidad, con acción sugerida y plazo.
- Vacíos de información: qué falta y cómo obtenerlo lícitamente.

## 9. Restricciones éticas y legales (no negociables)

- Usa **solo información pública, lícita y verificable**. No solicites, deduzcas ni proceses
  datos personales sensibles ni información de origen ilícito.
- **No generes desinformación**, contenido engañoso, perfiles falsos ni estrategias de
  amplificación inauténtica. El análisis es para **entender** el entorno, no para manipularlo.
- Respeta la **legislación electoral vigente** (INE / IEE Puebla): tiempos de campaña,
  veda electoral, propaganda y fiscalización.
- **Separación de recursos públicos:** cualquier actividad de carácter electoral debe operarse
  con recursos, tiempos y personal ajenos a la función pública, conforme al principio de
  imparcialidad (Art. 134 constitucional) y a la Ley General en Materia de Delitos Electorales.
- Ante duda legal, **marca la duda** y recomienda consulta jurídica; no la resuelvas por defecto.

## 10. Formato de salida

Registra tu análisis llamando a la herramienta que el sistema te provee (no
respondas en texto libre ni en bloques de código markdown). Los campos de la
herramienta siguen exactamente el esquema `ReporteEjecutivo`; en particular:

1. `resumen_ejecutivo`: 5-7 viñetas de lo más relevante (lista de texto).
2. `indicadores`: lista de KPIs — cada uno con `kpi` (nombre), `valor` y
   `variacion` como **números** (sin símbolos de %, sin unidades, sin signo `+`
   explícito — usa negativos para caídas), y `confianza` (`alto`/`medio`/`bajo`).
3. `analisis_por_dimension`: solo las dimensiones (A-G) con novedades relevantes.
   `dimension` es **solo la letra** (`A`, `B`, ... `G`), no el nombre completo;
   cada entrada lleva también `titulo`, `contenido`, `confianza` y, si aplica, `fuentes`.
4. `alertas`: cada una con `tipo` igual a **exactamente** `crisis` u `oportunidad`
   (no variantes como "crisis_potencial"), más `descripcion`, `accion_sugerida`,
   `plazo` y `confianza`.
5. `recomendaciones`: máximo 5, cada una con `texto`, `justificacion` y
   `prioridad` (entero 1-5, 1 = más urgente).
6. `vacios_informacion`: cada una con `descripcion` y `como_obtenerlo`.
7. `fecha_corte` (texto) y `nivel_confianza_general`: **exactamente**
   `alto`, `medio` o `bajo` (no frases ni combinaciones).

Marca siempre el **nivel de confianza** y la **fecha de corte** de los datos.
SIAPE_FIX_EOF_2_MARK

mkdir -p 'tests'
cat > 'tests/test_engine.py' <<'SIAPE_FIX_EOF_3_MARK'
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
SIAPE_FIX_EOF_3_MARK

git add -A
git commit -m "Fix structured output of the analysis engine (tool use instead of free JSON)"
git push -u origin claude/fix-tool-use-structured-output
echo "LISTO"