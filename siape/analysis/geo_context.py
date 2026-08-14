"""Puente entre las métricas geográficas (Fase 5/6) y el motor de análisis
(Opción 1): convierte el resumen por sección electoral a un formato plano,
listo para incluirse en los datos del periodo que consume el motor LLM
(ver el bloque `kpis_por_localidad` en data/periodo_ejemplo.json).

Requiere PostgreSQL/PostGIS (mismo requisito que siape.dashboard.mapa) — en
SQLite (fallback de desarrollo) no se debe invocar este módulo.
"""
from __future__ import annotations

from sqlalchemy.orm import Session

from siape.dashboard.mapa import resumen_por_seccion


def construir_kpis_por_localidad(
    session: Session, actor_id: int, fecha_inicio: str, fecha_fin: str
) -> list[dict[str, object]]:
    """Notoriedad y saldo de opinión por sección electoral, en formato
    serializable a JSON directamente con `json.dumps`."""
    resumen = resumen_por_seccion(session, actor_id, fecha_inicio, fecha_fin)
    return [
        {
            "localidad": r.nombre or r.clave_ine,
            "clave_ine": r.clave_ine,
            "notoriedad": r.notoriedad,
            "saldo_opinion": r.saldo_opinion,
        }
        for r in resumen
    ]
