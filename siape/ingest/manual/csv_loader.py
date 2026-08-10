"""Conector de carga manual: observaciones curadas a mano en un archivo CSV.

Capa de primera clase (README.md → "Realidad de acceso a datos"): garantiza
que el sistema sea útil aunque ningún API automatizado esté disponible.

Columnas esperadas del CSV:
    actor_nombre, fuente_nombre, source_level, tipo_fuente, plataforma,
    tipo, tema, sentimiento, texto, valor_numerico, url, fecha, confianza,
    no_confirmado
Las columnas vacías se interpretan como None. `no_confirmado` acepta
"true"/"false" (insensible a mayúsculas); vacío equivale a false.
"""
from __future__ import annotations

import csv
from pathlib import Path

from sqlalchemy.orm import Session

from siape.ingest.base import BaseConnector, RawObservation
from siape.storage.models import Actor, Fuente, Observacion


def _clean(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip()
    return value or None


def _parse_bool(value: str | None) -> bool:
    return (value or "").strip().lower() in ("true", "1", "si", "sí")


class CSVConnector(BaseConnector):
    def __init__(self, csv_path: str | Path):
        self.csv_path = Path(csv_path)

    def fetch(self) -> list[RawObservation]:
        observations: list[RawObservation] = []
        with self.csv_path.open(newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                valor = _clean(row.get("valor_numerico"))
                observations.append(
                    RawObservation(
                        actor_nombre=_clean(row.get("actor_nombre")),
                        fuente_nombre=row["fuente_nombre"].strip(),
                        source_level=int(row["source_level"]),
                        tipo_fuente=row["tipo_fuente"].strip(),
                        plataforma=_clean(row.get("plataforma")),
                        tipo=row["tipo"].strip(),
                        tema=_clean(row.get("tema")),
                        sentimiento=_clean(row.get("sentimiento")),
                        texto=_clean(row.get("texto")),
                        valor_numerico=float(valor) if valor is not None else None,
                        url=_clean(row.get("url")),
                        fecha=row["fecha"].strip(),
                        confianza=row["confianza"].strip(),
                        no_confirmado=_parse_bool(row.get("no_confirmado")),
                    )
                )
        return observations


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
