"""Verifica el comportamiento real de la migración geo (Fase 5) en ambos dialectos:
se salta en SQLite (dev) y crea las tablas/columnas de geometría en PostgreSQL/PostGIS.

La prueba contra Postgres se omite automáticamente si no hay un servidor
disponible en este entorno (no todos los entornos de desarrollo tienen
PostgreSQL+PostGIS corriendo).
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest
from sqlalchemy import create_engine, inspect

REPO_ROOT = Path(__file__).parent.parent
POSTGRES_ADMIN_DSN = "dbname=postgres user=postgres password=postgres host=localhost port=5432"
POSTGRES_TEST_DB = "siape_migration_test"
POSTGRES_TEST_URL = f"postgresql+psycopg2://postgres:postgres@localhost:5432/{POSTGRES_TEST_DB}"


def _run_alembic_upgrade(database_url: str) -> None:
    env = os.environ.copy()
    env["DATABASE_URL"] = database_url
    subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "head"],
        cwd=REPO_ROOT,
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )


def test_migracion_sqlite_omite_tablas_geo(tmp_path):
    database_url = f"sqlite:///{tmp_path / 'siape_migration_test.db'}"

    _run_alembic_upgrade(database_url)

    tablas = set(inspect(create_engine(database_url)).get_table_names())
    assert {"actores", "fuentes", "observaciones", "metricas"} <= tablas
    assert "secciones_electorales" not in tablas
    assert "colonias" not in tablas


def _postgres_disponible() -> bool:
    try:
        import psycopg2

        psycopg2.connect(POSTGRES_ADMIN_DSN, connect_timeout=2).close()
        return True
    except Exception:
        return False


@pytest.mark.skipif(not _postgres_disponible(), reason="No hay PostgreSQL disponible en este entorno")
def test_migracion_postgres_crea_tablas_geo():
    import psycopg2

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

    _run_alembic_upgrade(POSTGRES_TEST_URL)

    tablas = set(inspect(create_engine(POSTGRES_TEST_URL)).get_table_names())
    assert {"actores", "fuentes", "observaciones", "metricas"} <= tablas
    assert {"secciones_electorales", "colonias", "observacion_seccion"} <= tablas

    with create_engine(POSTGRES_TEST_URL).connect() as conn:
        columnas = inspect(conn).get_columns("secciones_electorales")
        geom_col = next(c for c in columnas if c["name"] == "geom")
        assert "geometry" in str(geom_col["type"]).lower()
