"""Métricas de redes: crecimiento y tasa de interacción (Sección 6, bloque 'Redes').

Convención: los conteos periódicos (seguidores, interacciones, alcance, etc.) se
cargan como `observaciones` con `tipo` igual al nombre de la métrica cruda
(p. ej. `tipo="seguidores_instagram"`) y `valor_numerico` con el conteo.
"""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from siape.storage.models import Observacion


def _valores_en_rango(
    session: Session, actor_id: int, tipo: str, fecha_inicio: str, fecha_fin: str
) -> list[Observacion]:
    stmt = (
        select(Observacion)
        .where(
            Observacion.actor_id == actor_id,
            Observacion.tipo == tipo,
            Observacion.fecha >= fecha_inicio,
            Observacion.fecha <= fecha_fin,
            Observacion.valor_numerico.is_not(None),
        )
        .order_by(Observacion.fecha)
    )
    return list(session.scalars(stmt))


def tasa_crecimiento(
    session: Session, actor_id: int, tipo: str, fecha_inicio: str, fecha_fin: str
) -> float | None:
    """% de variación entre la primera y la última observación de `tipo` en el rango.

    Devuelve None si hay menos de dos observaciones o si la inicial es 0
    (no se puede calcular una variación porcentual).
    """
    observaciones = _valores_en_rango(session, actor_id, tipo, fecha_inicio, fecha_fin)
    if len(observaciones) < 2:
        return None
    inicial, final = observaciones[0].valor_numerico, observaciones[-1].valor_numerico
    if not inicial:
        return None
    return round((final - inicial) / inicial * 100, 2)


def tasa_interaccion(
    session: Session,
    actor_id: int,
    tipo_interacciones: str,
    tipo_alcance: str,
    fecha_inicio: str,
    fecha_fin: str,
) -> float | None:
    """Interacciones totales / alcance total en el rango, como %."""
    interacciones = _valores_en_rango(session, actor_id, tipo_interacciones, fecha_inicio, fecha_fin)
    alcance = _valores_en_rango(session, actor_id, tipo_alcance, fecha_inicio, fecha_fin)
    total_alcance = sum(o.valor_numerico for o in alcance)
    if not total_alcance:
        return None
    total_interacciones = sum(o.valor_numerico for o in interacciones)
    return round(total_interacciones / total_alcance * 100, 2)
