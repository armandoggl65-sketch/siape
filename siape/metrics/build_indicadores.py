"""Convierte los cálculos de siape/metrics/* al formato Indicador (Fase 1).

Puente entre la Opción 2 (métricas desde la BD) y la Opción 1 (motor de
análisis): permite alimentar al motor con KPIs calculados en vez de solo
el JSON de ejemplo curado a mano.
"""
from __future__ import annotations

from sqlalchemy.orm import Session

from siape.analysis.schemas import Indicador
from siape.metrics.engagement import tasa_crecimiento
from siape.metrics.sentiment import saldo_opinion
from siape.metrics.share_of_voice import share_of_voice


def construir_indicadores(
    session: Session,
    actor_id: int,
    fecha_inicio: str,
    fecha_fin: str,
    tipo_seguidores: str = "seguidores",
) -> list[Indicador]:
    """Calcula un set base de KPIs desde la BD y los arma como `Indicador`.

    Cada KPI calculado se omite si no hay datos suficientes en el rango (no se
    inventan valores). La confianza se marca 'medio' de forma conservadora:
    combina varias observaciones sin la triangulación explícita que requeriría
    'alto' (Sección 7, metodología).
    """
    indicadores: list[Indicador] = []

    crecimiento = tasa_crecimiento(session, actor_id, tipo_seguidores, fecha_inicio, fecha_fin)
    if crecimiento is not None:
        indicadores.append(
            Indicador(
                kpi=f"crecimiento_{tipo_seguidores}",
                valor=crecimiento,
                variacion=None,
                confianza="medio",
            )
        )

    sov = share_of_voice(session, actor_id, fecha_inicio, fecha_fin)
    if sov is not None:
        indicadores.append(
            Indicador(kpi="share_of_voice_pct", valor=sov, variacion=None, confianza="medio")
        )

    saldo = saldo_opinion(session, actor_id, fecha_inicio, fecha_fin)
    if saldo is not None:
        indicadores.append(
            Indicador(kpi="saldo_opinion", valor=saldo, variacion=None, confianza="medio")
        )

    return indicadores
