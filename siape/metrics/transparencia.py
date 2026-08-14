"""Transparencia de temas y fuentes (Sección 4/6 del prompt de analista y
CLAUDE.md): expone en el tablero qué temas se están midiendo, quién los
domina, y con qué fuentes —y su nivel de verificabilidad (1-4)— se sostiene
cada número, para que ningún indicador se muestre sin poder rastrear su
origen.
"""
from __future__ import annotations

from collections import Counter
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from siape.metrics.positioning import propiedad_tematica
from siape.storage.models import Actor, Fuente, Observacion

NIVEL_ETIQUETAS = {
    1: "Nivel 1 — Oficial",
    2: "Nivel 2 — Medios",
    3: "Nivel 3 — Redes",
    4: "Nivel 4 — No verificado",
}


@dataclass
class TemaResumen:
    tema: str
    total_observaciones: int
    observaciones_actor: int
    actor_dominante: str | None
    saldo_opinion_actor: float | None


@dataclass
class FuenteResumen:
    fuente: str
    nivel: int
    nivel_etiqueta: str
    tipo: str
    num_observaciones: int


def resumen_temas(
    session: Session, actor_id: int, fecha_inicio: str, fecha_fin: str
) -> list[TemaResumen]:
    """Para cada tema con al menos una observación en el periodo (de
    cualquier actor): menciones totales, menciones del actor principal,
    quién domina el tema (None si hay empate, Sección 5.D) y el saldo de
    opinión del actor principal en ese tema."""
    dominante_por_tema = propiedad_tematica(session, fecha_inicio, fecha_fin)

    stmt_totales = select(Observacion.tema).where(
        Observacion.tema.is_not(None),
        Observacion.fecha >= fecha_inicio,
        Observacion.fecha <= fecha_fin,
    )
    totales = Counter(session.scalars(stmt_totales))

    stmt_actor = select(Observacion.tema, Observacion.sentimiento).where(
        Observacion.actor_id == actor_id,
        Observacion.tema.is_not(None),
        Observacion.fecha >= fecha_inicio,
        Observacion.fecha <= fecha_fin,
    )
    sentimientos_por_tema: dict[str, list[str | None]] = {}
    conteo_actor: Counter = Counter()
    for tema, sentimiento in session.execute(stmt_actor):
        conteo_actor[tema] += 1
        sentimientos_por_tema.setdefault(tema, []).append(sentimiento)

    nombres_actor = dict(session.execute(select(Actor.id, Actor.nombre)).all())

    resumen: list[TemaResumen] = []
    for tema, total in totales.items():
        sentimientos = [s for s in sentimientos_por_tema.get(tema, []) if s is not None]
        if sentimientos:
            positivas = sentimientos.count("positivo")
            negativas = sentimientos.count("negativo")
            saldo = round((positivas - negativas) / len(sentimientos) * 100, 2)
        else:
            saldo = None

        dominante_id = dominante_por_tema.get(tema)
        resumen.append(
            TemaResumen(
                tema=tema,
                total_observaciones=total,
                observaciones_actor=conteo_actor.get(tema, 0),
                actor_dominante=nombres_actor.get(dominante_id) if dominante_id is not None else None,
                saldo_opinion_actor=saldo,
            )
        )
    resumen.sort(key=lambda t: t.total_observaciones, reverse=True)
    return resumen


def resumen_fuentes(
    session: Session, actor_id: int, fecha_inicio: str, fecha_fin: str
) -> list[FuenteResumen]:
    """Fuentes usadas en observaciones del actor en el periodo, con su nivel
    de verificabilidad (Sección 4 del prompt de analista / CLAUDE.md).
    Ordenado por nivel (1 primero) y, dentro de cada nivel, por número de
    observaciones descendente."""
    stmt = (
        select(Fuente.nombre, Fuente.source_level, Fuente.tipo)
        .join(Observacion, Observacion.fuente_id == Fuente.id)
        .where(
            Observacion.actor_id == actor_id,
            Observacion.fecha >= fecha_inicio,
            Observacion.fecha <= fecha_fin,
        )
    )
    conteo = Counter(tuple(fila) for fila in session.execute(stmt))

    resumen = [
        FuenteResumen(
            fuente=nombre,
            nivel=nivel,
            nivel_etiqueta=NIVEL_ETIQUETAS[nivel],
            tipo=tipo,
            num_observaciones=n,
        )
        for (nombre, nivel, tipo), n in conteo.items()
    ]
    resumen.sort(key=lambda f: (f.nivel, -f.num_observaciones))
    return resumen
