"""Engine y factoría de sesiones SQLAlchemy, controlados por DATABASE_URL."""
from __future__ import annotations

from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session, sessionmaker

from config.settings import settings


def make_engine(database_url: str | None = None) -> Engine:
    return create_engine(database_url or settings.database_url)


def make_session_factory(engine: Engine) -> sessionmaker[Session]:
    return sessionmaker(bind=engine)
