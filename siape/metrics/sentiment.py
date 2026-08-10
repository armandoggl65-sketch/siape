"""Sentimiento: saldo de opinión (positivo − negativo) por actor, tema y periodo."""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from siape.storage.models import Observacion


def saldo_opinion(
    session: Session,
    actor_id: int,
    fecha_inicio: str,
    fecha_fin: str,
    tema: str | None = None,
) -> float | None:
    """(positivas − negativas) / total_con_sentimiento * 100.

    Si `tema` se especifica, restringe el cálculo a observaciones de ese tema.
    Devuelve None si no hay observaciones con sentimiento etiquetado en el rango.
    """
    stmt = select(Observacion.sentimiento).where(
        Observacion.actor_id == actor_id,
        Observacion.fecha >= fecha_inicio,
        Observacion.fecha <= fecha_fin,
        Observacion.sentimiento.is_not(None),
    )
    if tema is not None:
        stmt = stmt.where(Observacion.tema == tema)

    sentimientos = list(session.scalars(stmt))
    if not sentimientos:
        return None

    positivas = sentimientos.count("positivo")
    negativas = sentimientos.count("negativo")
    return round((positivas - negativas) / len(sentimientos) * 100, 2)
