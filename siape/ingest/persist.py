"""Persistencia de observaciones crudas: común a todos los conectores
(manual y automatizados), no solo a la carga manual CSV.
"""
from __future__ import annotations

from sqlalchemy.orm import Session

from siape.ingest.base import RawObservation
from siape.storage.models import Actor, Fuente, Observacion


def _get_or_create_actor(session: Session, nombre: str) -> Actor:
    actor = session.query(Actor).filter_by(nombre=nombre).one_or_none()
    if actor is None:
        actor = Actor(nombre=nombre)
        session.add(actor)
        session.flush()
    return actor


def _get_or_create_fuente(
    session: Session, nombre: str, source_level: int, tipo: str, plataforma: str | None
) -> Fuente:
    fuente = session.query(Fuente).filter_by(nombre=nombre).one_or_none()
    if fuente is None:
        fuente = Fuente(
            nombre=nombre, source_level=source_level, tipo=tipo, plataforma=plataforma
        )
        session.add(fuente)
        session.flush()
    return fuente


def persist_observations(session: Session, observations: list[RawObservation]) -> list[Observacion]:
    """Inserta observaciones crudas en la base, creando actor/fuente si hacen falta."""
    persisted: list[Observacion] = []
    for raw in observations:
        actor = _get_or_create_actor(session, raw.actor_nombre) if raw.actor_nombre else None
        fuente = _get_or_create_fuente(
            session, raw.fuente_nombre, raw.source_level, raw.tipo_fuente, raw.plataforma
        )
        observacion = Observacion(
            actor=actor,
            fuente=fuente,
            tipo=raw.tipo,
            tema=raw.tema,
            sentimiento=raw.sentimiento,
            texto=raw.texto,
            valor_numerico=raw.valor_numerico,
            url=raw.url,
            fecha=raw.fecha,
            confianza=raw.confianza,
            no_confirmado=raw.no_confirmado,
        )
        session.add(observacion)
        persisted.append(observacion)
    session.commit()
    return persisted
