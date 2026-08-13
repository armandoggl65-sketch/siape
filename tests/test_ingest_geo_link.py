"""Pruebas para siape/ingest/geo_link.py.

La lógica de vínculo requiere `secciones_electorales` (tabla con columna de
geometría), así que la prueba de comportamiento real se omite si no hay
PostgreSQL/PostGIS disponible (mismo patrón que tests/test_geo_migration.py
y tests/test_cargar_secciones_electorales.py).
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from siape.ingest.base import RawObservation
from siape.ingest.geo_link import vincular_a_secciones

REPO_ROOT = Path(__file__).parent.parent
GEOJSON_PATH = REPO_ROOT / "data" / "secciones_san_pedro_cholula.geojson"

POSTGRES_ADMIN_DSN = "dbname=postgres user=postgres password=postgres host=localhost port=5432"
POSTGRES_TEST_DB = "siape_geo_link_test"
POSTGRES_TEST_URL = f"postgresql+psycopg2://postgres:postgres@localhost:5432/{POSTGRES_TEST_DB}"

CLAVE_INE_REAL = "211800"  # sección 1800, presente en data/secciones_san_pedro_cholula.geojson


def _raw(seccion_ine: str | None) -> RawObservation:
    return RawObservation(
        fuente_nombre="Boletín Ayuntamiento SPC",
        source_level=1,
        tipo_fuente="oficial",
        tipo="mencion",
        fecha="2026-08-01",
        confianza="alto",
        seccion_ine=seccion_ine,
    )


def test_vincular_a_secciones_exige_misma_longitud():
    with pytest.raises(ValueError):
        vincular_a_secciones(session=None, observaciones=[object()], raws=[])


def _postgres_disponible() -> bool:
    try:
        import psycopg2

        psycopg2.connect(POSTGRES_ADMIN_DSN, connect_timeout=2).close()
        return True
    except Exception:
        return False


@pytest.mark.skipif(not _postgres_disponible(), reason="No hay PostgreSQL disponible en este entorno")
def test_vincular_a_secciones_real_contra_postgis():
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

    from siape.ingest.persist import persist_observations
    from siape.storage.geo_models import ObservacionSeccion
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

        raws = [_raw(CLAVE_INE_REAL), _raw(None), _raw("999999")]
        observaciones = persist_observations(session, raws)

        vinculadas, no_encontradas = vincular_a_secciones(session, observaciones, raws)
        assert vinculadas == 1
        assert no_encontradas == ["999999"]

        vinculos = session.query(ObservacionSeccion).all()
        assert len(vinculos) == 1
        assert vinculos[0].observacion_id == observaciones[0].id

        # Reintentar no debe duplicar el vínculo ya creado.
        vinculadas2, no_encontradas2 = vincular_a_secciones(session, observaciones, raws)
        assert vinculadas2 == 0
        assert no_encontradas2 == ["999999"]
        assert session.query(ObservacionSeccion).count() == 1
