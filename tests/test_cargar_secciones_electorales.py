"""Pruebas para scripts/cargar_secciones_electorales.py.

`scripts/` no es un paquete instalable, así que el módulo se carga por ruta.
La prueba de carga real contra PostGIS se omite si no hay servidor
disponible (mismo patrón que tests/test_geo_migration.py).
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent
SCRIPT_PATH = REPO_ROOT / "scripts" / "cargar_secciones_electorales.py"
GEOJSON_PATH = REPO_ROOT / "data" / "secciones_san_pedro_cholula.geojson"

POSTGRES_ADMIN_DSN = "dbname=postgres user=postgres password=postgres host=localhost port=5432"
POSTGRES_TEST_DB = "siape_secciones_test"
POSTGRES_TEST_URL = f"postgresql+psycopg2://postgres:postgres@localhost:5432/{POSTGRES_TEST_DB}"


def _cargar_modulo():
    spec = importlib.util.spec_from_file_location("cargar_secciones_electorales", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


modulo = _cargar_modulo()


def test_geojson_polygon_simple_a_wkt():
    geometry = {"type": "Polygon", "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]]}
    wkt = modulo.geometria_a_multipolygon_wkt(geometry)
    assert wkt == "MULTIPOLYGON(((0 0, 1 0, 1 1, 0 1, 0 0)))"


def test_geojson_multipolygon_a_wkt():
    geometry = {
        "type": "MultiPolygon",
        "coordinates": [
            [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]],
            [[[5, 5], [6, 5], [6, 6], [5, 6], [5, 5]]],
        ],
    }
    wkt = modulo.geometria_a_multipolygon_wkt(geometry)
    assert wkt == (
        "MULTIPOLYGON(((0 0, 1 0, 1 1, 0 1, 0 0)), ((5 5, 6 5, 6 6, 5 6, 5 5)))"
    )


def test_tipo_de_geometria_no_soportado():
    with pytest.raises(ValueError):
        modulo.geometria_a_multipolygon_wkt({"type": "Point", "coordinates": [0, 0]})


def test_data_file_secciones_san_pedro_cholula_bien_formado():
    """El archivo de datos real (no un fixture) debe tener 46 secciones válidas."""
    with GEOJSON_PATH.open(encoding="utf-8") as f:
        geojson = json.load(f)

    assert geojson["type"] == "FeatureCollection"
    assert len(geojson["features"]) == 46
    for feature in geojson["features"]:
        props = feature["properties"]
        assert props["municipio"] == "San Pedro Cholula"
        assert props["clave_ine"].startswith("21")
        assert feature["geometry"]["type"] in ("Polygon", "MultiPolygon")
        # No debe fallar la conversión a WKT para ninguna de las 46 secciones reales.
        modulo.geometria_a_multipolygon_wkt(feature["geometry"])


def _postgres_disponible() -> bool:
    try:
        import psycopg2

        psycopg2.connect(POSTGRES_ADMIN_DSN, connect_timeout=2).close()
        return True
    except Exception:
        return False


@pytest.mark.skipif(not _postgres_disponible(), reason="No hay PostgreSQL disponible en este entorno")
def test_cargar_geojson_real_contra_postgis():
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

    from siape.storage.geo_models import SeccionElectoral
    from siape.storage.models import Base

    engine = create_engine(POSTGRES_TEST_URL)
    tablas = [t for t in Base.metadata.tables.values() if t.name == "secciones_electorales"]
    Base.metadata.create_all(engine, tables=tablas)

    with GEOJSON_PATH.open(encoding="utf-8") as f:
        geojson = json.load(f)

    with Session(engine) as session:
        creadas, actualizadas = modulo.cargar_geojson(session, geojson)
        assert creadas == 46
        assert actualizadas == 0

        total = session.query(SeccionElectoral).count()
        assert total == 46

        # Cargar de nuevo debe actualizar, no duplicar.
        creadas2, actualizadas2 = modulo.cargar_geojson(session, geojson)
        assert creadas2 == 0
        assert actualizadas2 == 46
        assert session.query(SeccionElectoral).count() == 46
