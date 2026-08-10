"""Share of voice: % de menciones del actor frente al total del entorno competitivo."""
from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from siape.storage.models import Observacion


def share_of_voice(
    session: Session,
    actor_id: int,
    fecha_inicio: str,
    fecha_fin: str,
    tipo: str = "mencion",
) -> float | None:
    """% de menciones del actor sobre el total de menciones (todos los actores) en el rango.

    Solo cuenta observaciones de `tipo` (por defecto 'mencion'): los conteos
    de métricas propias (p. ej. 'seguidores') no son "voz" y no deben diluir
    el share of voice.
    """
    total = session.scalar(
        select(func.count(Observacion.id)).where(
            Observacion.actor_id.is_not(None),
            Observacion.tipo == tipo,
            Observacion.fecha >= fecha_inicio,
            Observacion.fecha <= fecha_fin,
        )
    )
    if not total:
        return None
    del_actor = session.scalar(
        select(func.count(Observacion.id)).where(
            Observacion.actor_id == actor_id,
            Observacion.tipo == tipo,
            Observacion.fecha >= fecha_inicio,
            Observacion.fecha <= fecha_fin,
        )
    )
    return round(del_actor / total * 100, 2)
