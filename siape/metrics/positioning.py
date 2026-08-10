"""Posicionamiento comparativo: notoriedad estimada y propiedad temática."""
from __future__ import annotations

from collections import Counter

from sqlalchemy import select
from sqlalchemy.orm import Session

from siape.storage.models import Observacion


def notoriedad_por_actor(
    session: Session, fecha_inicio: str, fecha_fin: str
) -> dict[int, int]:
    """Número de observaciones por actor en el rango, como proxy de notoriedad."""
    stmt = select(Observacion.actor_id).where(
        Observacion.actor_id.is_not(None),
        Observacion.fecha >= fecha_inicio,
        Observacion.fecha <= fecha_fin,
    )
    return dict(Counter(session.scalars(stmt)))


def propiedad_tematica(
    session: Session, fecha_inicio: str, fecha_fin: str
) -> dict[str, int | None]:
    """Para cada tema con observaciones, el actor_id con más menciones.

    El valor es None cuando hay empate entre dos o más actores (no se puede
    afirmar que uno "domina" ese tema sin triangulación adicional).
    """
    stmt = select(Observacion.tema, Observacion.actor_id).where(
        Observacion.tema.is_not(None),
        Observacion.actor_id.is_not(None),
        Observacion.fecha >= fecha_inicio,
        Observacion.fecha <= fecha_fin,
    )
    por_tema: dict[str, Counter] = {}
    for tema, actor_id in session.execute(stmt):
        por_tema.setdefault(tema, Counter())[actor_id] += 1

    resultado: dict[str, int | None] = {}
    for tema, contador in por_tema.items():
        mas_comunes = contador.most_common(2)
        empate = len(mas_comunes) > 1 and mas_comunes[0][1] == mas_comunes[1][1]
        resultado[tema] = None if empate else mas_comunes[0][0]
    return resultado
