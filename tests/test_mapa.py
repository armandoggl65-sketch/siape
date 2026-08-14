import json
from pathlib import Path

import pytest

from siape.dashboard.mapa import (
    notoriedad_por_seccion,
    resumen_por_seccion,
    saldo_opinion_por_seccion,
)
from siape.storage.geo_models import ObservacionSeccion
from siape.storage.models import Actor, Fuente, Observacion

REPO_ROOT = Path(__file__).parent.parent
GEOJSON_PATH = REPO_ROOT / "data" / "secciones_san_pedro_cholula.geojson"

POSTGRES_ADMIN_DSN = "dbname=postgres user=postgres password=postgres host=localhost port=5432"
POSTGRES_TEST_DB = "siape_resumen_seccion_test"
POSTGRES_TEST_URL = f"postgresql+psycopg2://postgres:postgres@localhost:5432/{POSTGRES_TEST_DB}"


def test_notoriedad_por_seccion_agrega_conteos(db_session):
    """No requiere PostGIS: solo agrega la tabla puente observacion_seccion,
    que no tiene columnas de geometría."""
    actor = Actor(nombre="Tonanzin Fernández")
    fuente = Fuente(nombre="Boletín Ayuntamiento SPC", source_level=1, tipo="oficial")
    db_session.add_all([actor, fuente])
    db_session.flush()

    obs1 = Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-01", confianza="alto")
    obs2 = Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-02", confianza="alto")
    obs3 = Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-03", confianza="alto")
    db_session.add_all([obs1, obs2, obs3])
    db_session.flush()

    db_session.add_all(
        [
            ObservacionSeccion(observacion_id=obs1.id, seccion_id=101),
            ObservacionSeccion(observacion_id=obs2.id, seccion_id=101),
            ObservacionSeccion(observacion_id=obs3.id, seccion_id=202),
        ]
    )
    db_session.commit()

    resultado = notoriedad_por_seccion(db_session, actor.id, "2026-08-01", "2026-08-07")
    assert resultado == {101: 2, 202: 1}


def test_notoriedad_por_seccion_vacio_sin_vinculos(db_session):
    actor = Actor(nombre="Sin geo")
    db_session.add(actor)
    db_session.commit()

    assert notoriedad_por_seccion(db_session, actor.id, "2026-08-01", "2026-08-07") == {}


def test_saldo_opinion_por_seccion_agrega_por_seccion(db_session):
    """Tampoco requiere PostGIS: solo lee observacion_seccion + observaciones."""
    actor = Actor(nombre="Tonanzin Fernández")
    fuente = Fuente(nombre="Boletín Ayuntamiento SPC", source_level=1, tipo="oficial")
    db_session.add_all([actor, fuente])
    db_session.flush()

    obs1 = Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-01", confianza="alto", sentimiento="positivo")
    obs2 = Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-02", confianza="alto", sentimiento="negativo")
    obs3 = Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-03", confianza="alto", sentimiento="positivo")
    obs4 = Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-04", confianza="alto")  # sin sentimiento
    db_session.add_all([obs1, obs2, obs3, obs4])
    db_session.flush()

    db_session.add_all(
        [
            ObservacionSeccion(observacion_id=obs1.id, seccion_id=101),
            ObservacionSeccion(observacion_id=obs2.id, seccion_id=101),
            ObservacionSeccion(observacion_id=obs3.id, seccion_id=202),
            ObservacionSeccion(observacion_id=obs4.id, seccion_id=202),
        ]
    )
    db_session.commit()

    resultado = saldo_opinion_por_seccion(db_session, actor.id, "2026-08-01", "2026-08-07")
    # Sección 101: 1 positiva, 1 negativa -> saldo 0. Sección 202: solo 1 con sentimiento (positivo) -> 100.
    assert resultado == {101: 0.0, 202: 100.0}


def test_saldo_opinion_por_seccion_vacio_sin_sentimiento_etiquetado(db_session):
    actor = Actor(nombre="Tonanzin Fernández")
    fuente = Fuente(nombre="Boletín Ayuntamiento SPC", source_level=1, tipo="oficial")
    db_session.add_all([actor, fuente])
    db_session.flush()

    obs = Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-01", confianza="alto")
    db_session.add(obs)
    db_session.flush()
    db_session.add(ObservacionSeccion(observacion_id=obs.id, seccion_id=101))
    db_session.commit()

    assert saldo_opinion_por_seccion(db_session, actor.id, "2026-08-01", "2026-08-07") == {}


def test_resumen_por_seccion_vacio_sin_vinculos(db_session):
    """No requiere PostGIS: sin vínculos, resumen_por_seccion no llega a
    consultar secciones_electorales (que en SQLite ni siquiera existe)."""
    actor = Actor(nombre="Sin geo")
    db_session.add(actor)
    db_session.commit()

    assert resumen_por_seccion(db_session, actor.id, "2026-08-01", "2026-08-07") == []


def _postgres_disponible() -> bool:
    try:
        import psycopg2

        psycopg2.connect(POSTGRES_ADMIN_DSN, connect_timeout=2).close()
        return True
    except Exception:
        return False


@pytest.mark.skipif(not _postgres_disponible(), reason="No hay PostgreSQL disponible en este entorno")
def test_resumen_por_seccion_real_contra_postgis():
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
                fuente_nombre="Boletín Ayuntamiento SPC", source_level=1, tipo_fuente="oficial",
                tipo="mencion", fecha="2026-08-02", confianza="alto", sentimiento="negativo",
                seccion_ine="211800",
            ),
            RawObservation(
                actor_nombre="Tonanzin Fernández",
                fuente_nombre="Vecinos La Trinidad FB", source_level=3, tipo_fuente="redes",
                tipo="mencion", fecha="2026-08-03", confianza="medio", sentimiento="positivo",
                seccion_ine="211801",
            ),
        ]
        observaciones = persist_observations(session, raws)
        actor = observaciones[0].actor
        vincular_a_secciones(session, observaciones, raws)

        resumen = resumen_por_seccion(session, actor.id, "2026-08-01", "2026-08-07")

        assert len(resumen) == 2
        por_clave = {r.clave_ine: r for r in resumen}
        assert por_clave["211800"].notoriedad == 2
        assert por_clave["211800"].saldo_opinion == 0.0  # 1 positiva, 1 negativa
        assert por_clave["211801"].notoriedad == 1
        assert por_clave["211801"].saldo_opinion == 100.0
        # Ordenado por notoriedad descendente.
        assert resumen[0].clave_ine == "211800"
