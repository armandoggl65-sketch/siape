"""Traducción de indicadores a semáforo visual (🟢🟡🔴), sin dependencias de Streamlit.

Separado de siape/dashboard/app.py para poder probarlo sin un navegador.
"""
from __future__ import annotations

from siape.analysis.schemas import Indicador

VERDE = "🟢"
AMARILLO = "🟡"
ROJO = "🔴"


def semaforo_confianza(confianza: str) -> str:
    return {"alto": VERDE, "medio": AMARILLO, "bajo": ROJO}.get(confianza, AMARILLO)


def semaforo_variacion(variacion: float | None) -> str:
    """Verde si mejora, rojo si empeora, amarillo si es estable o no hay dato."""
    if variacion is None or variacion == 0:
        return AMARILLO
    return VERDE if variacion > 0 else ROJO


def semaforo_indicador(indicador: Indicador) -> str:
    """Semáforo combinado: usa la variación cuando existe; si no, la confianza."""
    if indicador.variacion is not None:
        return semaforo_variacion(indicador.variacion)
    return semaforo_confianza(indicador.confianza)
