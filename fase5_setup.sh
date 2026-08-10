#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/siape

mkdir -p 'alembic'
cat > 'alembic/env.py' <<'SIAPE_F5_EOF_1_MARK'
import os
import sys
from logging.config import fileConfig

from sqlalchemy import engine_from_config
from sqlalchemy import pool

from alembic import context

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from config.settings import settings  # noqa: E402
from siape.storage.models import Base  # noqa: E402
from siape.storage import geo_models  # noqa: E402,F401 — registra tablas geo (Fase 5) en Base.metadata

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Interpret the config file for Python logging.
# This line sets up loggers basically.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

config.set_main_option("sqlalchemy.url", settings.database_url)

target_metadata = Base.metadata

# other values from the config, defined by the needs of env.py,
# can be acquired:
# my_important_option = config.get_main_option("my_important_option")
# ... etc.


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    This configures the context with just a URL
    and not an Engine, though an Engine is acceptable
    here as well.  By skipping the Engine creation
    we don't even need a DBAPI to be available.

    Calls to context.execute() here emit the given string to the
    script output.

    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode.

    In this scenario we need to create an Engine
    and associate a connection with the context.

    """
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection, target_metadata=target_metadata
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
SIAPE_F5_EOF_1_MARK

mkdir -p 'alembic/versions'
cat > 'alembic/versions/3649242c7205_geo_secciones_electorales_y_colonias_.py' <<'SIAPE_F5_EOF_2_MARK'
"""geo: secciones electorales y colonias (Fase 5, opcional)

Revision ID: 3649242c7205
Revises: e9d32eef416a
Create Date: 2026-08-10 15:13:09.912371

Esta capa solo aplica a PostgreSQL/PostGIS. El fallback de desarrollo
(SQLite) no soporta columnas de geometría, así que upgrade()/downgrade()
se saltan por completo en cualquier otro dialecto (CLAUDE.md, README →
Stack: "Fallback de desarrollo: SQLite, sin capa geográfica").

NOTA 1: `spatial_ref_sys` es una tabla del sistema creada por `CREATE EXTENSION
postgis`, no por nuestros modelos. Autogenerate la detecta como "removida"
por comparación ingenua contra Base.metadata; se ignora deliberadamente
para no borrar una tabla del propio PostGIS.

NOTA 2: no se llama a `op.create_index`/`op.drop_index` para los índices
espaciales — GeoAlchemy2 los crea y elimina automáticamente (columna
`Geometry(..., spatial_index=True)` por defecto) al crear/eliminar la tabla.
Hacerlo explícito además duplica el índice y falla con "already exists".
"""
from typing import Sequence, Union

import geoalchemy2
import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = '3649242c7205'
down_revision: Union[str, Sequence[str], None] = 'e9d32eef416a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    if op.get_bind().dialect.name != "postgresql":
        return

    op.create_table(
        'secciones_electorales',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('clave_ine', sa.String(), nullable=False),
        sa.Column('nombre', sa.String(), nullable=True),
        sa.Column('municipio', sa.String(), nullable=True),
        sa.Column('geom', geoalchemy2.types.Geometry(geometry_type='MULTIPOLYGON', srid=4326), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('clave_ine'),
    )

    op.create_table(
        'colonias',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('nombre', sa.String(), nullable=False),
        sa.Column('seccion_id', sa.Integer(), nullable=True),
        sa.Column('geom', geoalchemy2.types.Geometry(geometry_type='POLYGON', srid=4326), nullable=False),
        sa.ForeignKeyConstraint(['seccion_id'], ['secciones_electorales.id']),
        sa.PrimaryKeyConstraint('id'),
    )

    op.create_table(
        'observacion_seccion',
        sa.Column('observacion_id', sa.Integer(), nullable=False),
        sa.Column('seccion_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['observacion_id'], ['observaciones.id']),
        sa.ForeignKeyConstraint(['seccion_id'], ['secciones_electorales.id']),
        sa.PrimaryKeyConstraint('observacion_id', 'seccion_id'),
    )


def downgrade() -> None:
    if op.get_bind().dialect.name != "postgresql":
        return

    op.drop_table('observacion_seccion')
    op.drop_table('colonias')
    op.drop_table('secciones_electorales')
SIAPE_F5_EOF_2_MARK

mkdir -p 'siape/dashboard'
cat > 'siape/dashboard/mapa.py' <<'SIAPE_F5_EOF_3_MARK'
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
SIAPE_F5_EOF_3_MARK

mkdir -p 'siape/storage'
cat > 'siape/storage/geo_models.py' <<'SIAPE_F5_EOF_4_MARK'
"""Modelos geo (Fase 5, opcional): secciones electorales y colonias.

Usan cartografía PÚBLICA del INE — nunca datos de otros sistemas
(CLAUDE.md, "Proyecto autónomo"). Solo disponibles en PostgreSQL/PostGIS;
el fallback de desarrollo (SQLite) no tiene esta capa (README, Stack).

No se modifica el esquema de `Observacion` (Fase 0): el vínculo geográfico
es una tabla puente opcional, para no acoplar las fases anteriores a esta
capa opcional.
"""
from __future__ import annotations

from geoalchemy2 import Geometry
from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from siape.storage.models import Base


class SeccionElectoral(Base):
    __tablename__ = "secciones_electorales"

    id: Mapped[int] = mapped_column(primary_key=True)
    clave_ine: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    nombre: Mapped[str | None] = mapped_column(String)
    municipio: Mapped[str | None] = mapped_column(String)
    geom = mapped_column(Geometry(geometry_type="MULTIPOLYGON", srid=4326), nullable=False)

    colonias: Mapped[list["Colonia"]] = relationship(back_populates="seccion")


class Colonia(Base):
    __tablename__ = "colonias"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String, nullable=False)
    seccion_id: Mapped[int | None] = mapped_column(ForeignKey("secciones_electorales.id"))
    geom = mapped_column(Geometry(geometry_type="POLYGON", srid=4326), nullable=False)

    seccion: Mapped[SeccionElectoral | None] = relationship(back_populates="colonias")


class ObservacionSeccion(Base):
    """Vínculo opcional: en qué sección electoral ocurrió una observación."""

    __tablename__ = "observacion_seccion"

    observacion_id: Mapped[int] = mapped_column(ForeignKey("observaciones.id"), primary_key=True)
    seccion_id: Mapped[int] = mapped_column(ForeignKey("secciones_electorales.id"), primary_key=True)
SIAPE_F5_EOF_4_MARK

mkdir -p 'tests'
cat > 'tests/conftest.py' <<'SIAPE_F5_EOF_5_MARK'
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from siape.storage.models import Base


def _tiene_columna_geometrica(table) -> bool:
    """Detecta columnas GeoAlchemy2 (Geometry), incompatibles con SQLite plano."""
    return any(type(column.type).__module__.startswith("geoalchemy2") for column in table.columns)


def create_all_sin_geo(engine) -> None:
    """`Base.metadata.create_all` excluyendo tablas con columnas de geometría
    (Fase 5, opcional): SQLite sin SpatiaLite no las soporta. Útil en
    cualquier test con SQLite, sin importar qué otros módulos del proyecto
    (p. ej. siape.storage.geo_models) se hayan importado antes en la misma
    sesión de pytest y hayan registrado tablas geo en el Base compartido.
    """
    tablas = [t for t in Base.metadata.tables.values() if not _tiene_columna_geometrica(t)]
    Base.metadata.create_all(engine, tables=tablas)


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    create_all_sin_geo(engine)
    with Session(engine) as session:
        yield session
SIAPE_F5_EOF_5_MARK

mkdir -p 'tests'
cat > 'tests/test_dashboard_app.py' <<'SIAPE_F5_EOF_6_MARK'
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from siape.storage.models import Actor, Fuente, Observacion
from tests.conftest import create_all_sin_geo


def _seeded_engine():
    """Motor SQLite en memoria compartido entre conexiones (StaticPool), con datos de ejemplo."""
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    create_all_sin_geo(engine)
    with Session(engine) as session:
        actor = Actor(nombre="Tonanzin Fernández")
        fuente = Fuente(nombre="Instagram propio", source_level=3, tipo="redes")
        session.add_all([actor, fuente])
        session.flush()
        session.add_all(
            [
                Observacion(actor=actor, fuente=fuente, tipo="seguidores", fecha="2026-08-01", confianza="alto", valor_numerico=100),
                Observacion(actor=actor, fuente=fuente, tipo="seguidores", fecha="2026-08-07", confianza="alto", valor_numerico=120),
                Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-03", confianza="medio", sentimiento="positivo"),
            ]
        )
        session.commit()
    return engine


def test_dashboard_app_renderiza_sin_errores(monkeypatch):
    from streamlit.testing.v1 import AppTest

    engine = _seeded_engine()
    monkeypatch.setattr("siape.storage.db.make_engine", lambda *args, **kwargs: engine)

    at = AppTest.from_file("../siape/dashboard/app.py")
    at.run(timeout=15)

    assert not at.exception
    assert "SIAPE — Tablero de indicadores" in [t.value for t in at.title]
SIAPE_F5_EOF_6_MARK

mkdir -p 'tests'
cat > 'tests/test_geo_migration.py' <<'SIAPE_F5_EOF_7_MARK'
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
SIAPE_F5_EOF_7_MARK

mkdir -p 'tests'
cat > 'tests/test_mapa.py' <<'SIAPE_F5_EOF_8_MARK'
from siape.dashboard.mapa import notoriedad_por_seccion
from siape.storage.geo_models import ObservacionSeccion
from siape.storage.models import Actor, Fuente, Observacion


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
SIAPE_F5_EOF_8_MARK

git add -A
git commit -m "Implement Fase 5 (geo, opcional) of SIAPE"
git push
echo "LISTO"