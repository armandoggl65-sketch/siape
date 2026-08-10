"""Mapa de posicionamiento (Fase 5, opcional): observaciones por sección electoral.

Requiere vínculos poblados en `observacion_seccion` (Fase 5, tabla puente
entre `observaciones` y `secciones_electorales`). La agregación en sí es
SQL simple sobre IDs — no ejecuta operaciones espaciales, así que es
testable sin PostGIS. Las consultas espaciales reales (determinar en qué
sección cae una observación) son responsabilidad de una capa de carga
geográfica futura, fuera del alcance de este módulo.
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
