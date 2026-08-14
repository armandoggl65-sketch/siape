"""Mapa de posicionamiento (Fase 5/6, opcional): notoriedad y sentimiento por
sección electoral.

Requiere vínculos poblados en `observacion_seccion` (Fase 5, tabla puente
entre `observaciones` y `secciones_electorales`). La agregación de notoriedad
es SQL simple sobre IDs — no ejecuta operaciones espaciales, así que es
testable sin PostGIS; `resumen_por_seccion` sí consulta `secciones_electorales`
(nombre/clave_ine), que solo existe en PostgreSQL/PostGIS. Los vínculos se
pueblan en la carga (Fase 6.3, ver `siape.ingest.geo_link.vincular_a_secciones`),
a partir de la clave_ine que quien captura el dato asigna manualmente en el
CSV — no hay geocodificación automática (determinar en qué sección cae una
observación sin esa etiqueta) en este alcance.
"""
from __future__ import annotations

from collections import Counter
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from siape.storage.geo_models import ObservacionSeccion, SeccionElectoral
from siape.storage.models import Observacion


def notoriedad_por_seccion(
    session: Session, actor_id: int, fecha_inicio: str, fecha_fin: str
) -> dict[int, int]:
    """Número de observaciones del actor por sección electoral, en el rango."""
    stmt = (
        select(ObservacionSeccion.seccion_id)
        .join(Observacion, Observacion.id == ObservacionSeccion.observacion_id)
        .where(
            Observacion.actor_id == actor_id,
            Observacion.fecha >= fecha_inicio,
            Observacion.fecha <= fecha_fin,
        )
    )
    return dict(Counter(session.scalars(stmt)))


def saldo_opinion_por_seccion(
    session: Session, actor_id: int, fecha_inicio: str, fecha_fin: str
) -> dict[int, float]:
    """(positivas − negativas) / total_con_sentimiento * 100, por sección electoral.

    Solo incluye secciones con al menos una observación con `sentimiento`
    etiquetado en el rango (mismo criterio que `siape.metrics.sentiment.saldo_opinion`,
    aplicado por sección en lugar de al actor completo).
    """
    stmt = (
        select(ObservacionSeccion.seccion_id, Observacion.sentimiento)
        .join(Observacion, Observacion.id == ObservacionSeccion.observacion_id)
        .where(
            Observacion.actor_id == actor_id,
            Observacion.fecha >= fecha_inicio,
            Observacion.fecha <= fecha_fin,
            Observacion.sentimiento.is_not(None),
        )
    )
    sentimientos_por_seccion: dict[int, list[str]] = {}
    for seccion_id, sentimiento in session.execute(stmt):
        sentimientos_por_seccion.setdefault(seccion_id, []).append(sentimiento)

    resultado: dict[int, float] = {}
    for seccion_id, sentimientos in sentimientos_por_seccion.items():
        positivas = sentimientos.count("positivo")
        negativas = sentimientos.count("negativo")
        resultado[seccion_id] = round((positivas - negativas) / len(sentimientos) * 100, 2)
    return resultado


@dataclass
class ResumenSeccion:
    seccion_id: int
    clave_ine: str
    nombre: str | None
    notoriedad: int
    saldo_opinion: float | None


def resumen_por_seccion(
    session: Session, actor_id: int, fecha_inicio: str, fecha_fin: str
) -> list[ResumenSeccion]:
    """Notoriedad y saldo de opinión por sección electoral, para las secciones
    con al menos una observación vinculada en el rango. Ordenado por
    notoriedad descendente. Requiere PostGIS (consulta `secciones_electorales`
    para nombre/clave_ine)."""
    notoriedad = notoriedad_por_seccion(session, actor_id, fecha_inicio, fecha_fin)
    if not notoriedad:
        return []

    saldo = saldo_opinion_por_seccion(session, actor_id, fecha_inicio, fecha_fin)
    secciones = (
        session.query(SeccionElectoral).filter(SeccionElectoral.id.in_(notoriedad.keys())).all()
    )

    resumen = [
        ResumenSeccion(
            seccion_id=seccion.id,
            clave_ine=seccion.clave_ine,
            nombre=seccion.nombre,
            notoriedad=notoriedad[seccion.id],
            saldo_opinion=saldo.get(seccion.id),
        )
        for seccion in secciones
    ]
    resumen.sort(key=lambda r: r.notoriedad, reverse=True)
    return resumen
