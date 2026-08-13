"""Mapa de posicionamiento (Fase 5, opcional): observaciones por sección electoral.

Requiere vínculos poblados en `observacion_seccion` (Fase 5, tabla puente
entre `observaciones` y `secciones_electorales`). La agregación en sí es
SQL simple sobre IDs — no ejecuta operaciones espaciales, así que es
testable sin PostGIS. Los vínculos se pueblan en la carga (Fase 6.3, ver
`siape.ingest.geo_link.vincular_a_secciones`), a partir de la clave_ine
que quien captura el dato asigna manualmente en el CSV — no hay
geocodificación automática (determinar en qué sección cae una observación
sin esa etiqueta) en este alcance.
"""
from __future__ import annotations

from collections import Counter

from sqlalchemy import select
from sqlalchemy.orm import Session

from siape.storage.geo_models import ObservacionSeccion
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
