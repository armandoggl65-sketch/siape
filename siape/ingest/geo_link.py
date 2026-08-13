"""Vincula observaciones ya persistidas a su sección electoral (Fase 5/6,
opcional). Requiere PostgreSQL/PostGIS con `secciones_electorales` cargada
(ver scripts/cargar_secciones_electorales.py) — en SQLite (fallback de
desarrollo) esa tabla no existe y este módulo no debe invocarse.

Deliberadamente separado de `siape.ingest.persist`, para no acoplar la
persistencia base (Fase 0) a la capa geo opcional (mismo criterio que
`siape.storage.geo_models`).
"""
from __future__ import annotations

from sqlalchemy.orm import Session

from siape.ingest.base import RawObservation
from siape.storage.geo_models import ObservacionSeccion, SeccionElectoral
from siape.storage.models import Observacion


def vincular_a_secciones(
    session: Session, observaciones: list[Observacion], raws: list[RawObservation]
) -> tuple[int, list[str]]:
    """Crea vínculos `observacion_seccion` para las observaciones cuyo
    `RawObservation` de origen trae `seccion_ine`.

    `observaciones` y `raws` deben corresponder 1 a 1 y en el mismo orden
    (la lista que produjo un conector y la que devolvió
    `persist_observations` a partir de ella).

    Devuelve (vinculadas, claves_ine_no_encontradas) — las claves no
    encontradas en `secciones_electorales` se omiten silenciosamente en la
    base (no rompen la carga) pero se reportan para que quien captura el
    dato corrija la clave o cargue la sección faltante.
    """
    if len(observaciones) != len(raws):
        raise ValueError("observaciones y raws deben tener la misma longitud y orden")

    vinculadas = 0
    no_encontradas: list[str] = []
    cache: dict[str, SeccionElectoral | None] = {}

    for observacion, raw in zip(observaciones, raws):
        if not raw.seccion_ine:
            continue

        if raw.seccion_ine not in cache:
            cache[raw.seccion_ine] = (
                session.query(SeccionElectoral).filter_by(clave_ine=raw.seccion_ine).one_or_none()
            )
        seccion = cache[raw.seccion_ine]

        if seccion is None:
            no_encontradas.append(raw.seccion_ine)
            continue

        existente = (
            session.query(ObservacionSeccion)
            .filter_by(observacion_id=observacion.id, seccion_id=seccion.id)
            .one_or_none()
        )
        if existente is None:
            session.add(ObservacionSeccion(observacion_id=observacion.id, seccion_id=seccion.id))
            vinculadas += 1

    session.commit()
    return vinculadas, no_encontradas
