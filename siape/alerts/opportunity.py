"""Detección de ventanas de oportunidad (Sección 5.G): temas vacíos ("océanos azules")."""
from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from siape.metrics.positioning import propiedad_tematica
from siape.storage.models import Observacion


@dataclass
class AlertaOportunidad:
    descripcion: str
    accion_sugerida: str
    plazo: str
    confianza: str


def _temas_del_actor(
    session: Session, actor_id: int, fecha_inicio: str, fecha_fin: str
) -> set[str]:
    stmt = (
        select(Observacion.tema)
        .where(
            Observacion.actor_id == actor_id,
            Observacion.tema.is_not(None),
            Observacion.fecha >= fecha_inicio,
            Observacion.fecha <= fecha_fin,
        )
        .distinct()
    )
    return set(session.scalars(stmt))


def detectar_oceanos_azules(
    session: Session, actor_id: int, fecha_inicio: str, fecha_fin: str
) -> list[AlertaOportunidad]:
    """Temas que otro actor domina y donde el actor principal no tiene presencia alguna."""
    propiedad = propiedad_tematica(session, fecha_inicio, fecha_fin)
    temas_propios = _temas_del_actor(session, actor_id, fecha_inicio, fecha_fin)

    alertas: list[AlertaOportunidad] = []
    for tema, actor_dominante in propiedad.items():
        if actor_dominante is not None and actor_dominante != actor_id and tema not in temas_propios:
            alertas.append(
                AlertaOportunidad(
                    descripcion=(
                        f"El tema '{tema}' es dominado por otro actor; "
                        "el actor principal no tiene presencia en él."
                    ),
                    accion_sugerida=f"Evaluar generar agenda/contenido propio sobre '{tema}'.",
                    plazo="15 días",
                    confianza="medio",
                )
            )
    return alertas
