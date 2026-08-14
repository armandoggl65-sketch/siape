"""Pruebas para siape/analysis/geo_context.py.

Requiere PostgreSQL/PostGIS (mismo requisito que resumen_por_seccion) — se
omite automáticamente si no hay servidor disponible en este entorno.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent
GEOJSON_PATH = REPO_ROOT / "data" / "secciones_san_pedro_cholula.geojson"

POSTGRES_ADMIN_DSN = "dbname=postgres user=postgres password=postgres host=localhost port=5432"
POSTGRES_TEST_DB = "siape_geo_context_test"
POSTGRES_TEST_URL = f"postgresql+psycopg2://postgres:postgres@localhost:5432/{POSTGRES_TEST_DB}"


def _postgres_disponible() -> bool:
    try:
        import psycopg2

        psycopg2.connect(POSTGRES_ADMIN_DSN, connect_timeout=2).close()
        return True
    except Exception:
        return False


@pytest.mark.skipif(not _postgres_disponible(), reason="No hay PostgreSQL disponible en este entorno")
def test_construir_kpis_por_localidad_real_contra_postgis():
    import psycopg2
    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session

    admin = psycopg2.connect(POSTGRES_ADMIN_DSN)
    admin.autocommit = True
    with admin.cursor() as cur:
        cur.execute(f"DROP DATABASE IF EXISTS {POSTGRES_TEST_DB}")
        cur.execute(f"CREATE DATABASE {POSTGRES_TEST_DB}")
    admin.close()

    setup = psycopg2.connect(POSTGRES_ADMIN_DSN.replace("dbname=postgres", f"dbname={POSTGRES_TEST_DB}"))
    setup.autocommit = True
    with setup.cursor() as cur:
        cur.execute("CREATE EXTENSION IF NOT EXISTS postgis")
    setup.close()

    from siape.analysis.geo_context import construir_kpis_por_localidad
    from siape.ingest.base import RawObservation
    from siape.ingest.geo_link import vincular_a_secciones
    from siape.ingest.persist import persist_observations
    from siape.storage.models import Base

    engine = create_engine(POSTGRES_TEST_URL)
    tablas = [
        t
        for t in Base.metadata.tables.values()
        if t.name in ("actores", "fuentes", "observaciones", "secciones_electorales", "observacion_seccion")
    ]
    Base.metadata.create_all(engine, tables=tablas)

    from scripts.cargar_secciones_electorales import cargar_geojson

    with GEOJSON_PATH.open(encoding="utf-8") as f:
        geojson = json.load(f)

    with Session(engine) as session:
        cargar_geojson(session, geojson)

        raws = [
            RawObservation(
                actor_nombre="Tonanzin Fernández",
                fuente_nombre="Boletín Ayuntamiento SPC", source_level=1, tipo_fuente="oficial",
                tipo="mencion", fecha="2026-08-01", confianza="alto", sentimiento="positivo",
                seccion_ine="211800",
            ),
            RawObservation(
                actor_nombre="Tonanzin Fernández",
                fuente_nombre="Vecinos La Trinidad FB", source_level=3, tipo_fuente="redes",
                tipo="mencion", fecha="2026-08-02", confianza="medio", sentimiento="negativo",
                seccion_ine="211801",
            ),
        ]
        observaciones = persist_observations(session, raws)
        actor = observaciones[0].actor
        vincular_a_secciones(session, observaciones, raws)

        kpis = construir_kpis_por_localidad(session, actor.id, "2026-08-01", "2026-08-07")

        assert len(kpis) == 2
        por_clave = {k["clave_ine"]: k for k in kpis}
        assert por_clave["211800"]["notoriedad"] == 1
        assert por_clave["211800"]["saldo_opinion"] == 100.0
        assert por_clave["211800"]["localidad"] == "Sección 1800"
        assert por_clave["211801"]["saldo_opinion"] == -100.0

        # Debe ser directamente serializable a JSON, como se usa en engine.py.
        json.dumps(kpis, ensure_ascii=False)
