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
