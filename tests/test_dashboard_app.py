from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from siape.storage.models import Actor, Base, Fuente, Observacion


def _seeded_engine():
    """Motor SQLite en memoria compartido entre conexiones (StaticPool), con datos de ejemplo."""
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
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
