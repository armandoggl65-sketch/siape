"""Detección temprana de crisis (Sección 5.F): señales de riesgo reputacional."""
from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy.orm import Session

from siape.metrics.engagement import tasa_crecimiento
from siape.metrics.sentiment import saldo_opinion

UMBRAL_SALDO_NEGATIVO = -30.0
UMBRAL_CAIDA_KPI_PCT = -15.0


@dataclass
class AlertaCrisis:
    descripcion: str
    accion_sugerida: str
    plazo: str
    confianza: str


def detectar_crisis(
    session: Session,
    actor_id: int,
    fecha_inicio: str,
    fecha_fin: str,
    tipo_seguidores: str = "seguidores",
) -> list[AlertaCrisis]:
    """Revisa saldo de opinión y crecimiento de KPIs en busca de señales de crisis.

    No inventa alertas sin datos: cada chequeo se omite si no hay suficiente
    información en el rango (mismo principio de las funciones de siape/metrics).
    """
    alertas: list[AlertaCrisis] = []

    saldo = saldo_opinion(session, actor_id, fecha_inicio, fecha_fin)
    if saldo is not None and saldo <= UMBRAL_SALDO_NEGATIVO:
        alertas.append(
            AlertaCrisis(
                descripcion=f"Saldo de opinión negativo ({saldo}%) en el periodo.",
                accion_sugerida="Revisar narrativas negativas dominantes y preparar respuesta.",
                plazo="48 horas",
                confianza="medio",
            )
        )

    crecimiento = tasa_crecimiento(session, actor_id, tipo_seguidores, fecha_inicio, fecha_fin)
    if crecimiento is not None and crecimiento <= UMBRAL_CAIDA_KPI_PCT:
        alertas.append(
            AlertaCrisis(
                descripcion=f"Caída de {tipo_seguidores} del {crecimiento}% en el periodo.",
                accion_sugerida="Investigar la causa de la caída (fuga de seguidores, reporte masivo, etc.).",
                plazo="7 días",
                confianza="medio",
            )
        )

    return alertas
