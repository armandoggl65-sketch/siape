from siape.metrics.sentiment import saldo_opinion
from siape.storage.models import Actor, Fuente, Observacion


def test_saldo_opinion_calcula_balance(db_session):
    actor = Actor(nombre="Tonanzin Fernández")
    fuente = Fuente(nombre="X propio", source_level=3, tipo="redes")
    db_session.add_all([actor, fuente])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-01", confianza="medio", sentimiento="positivo"),
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-02", confianza="medio", sentimiento="positivo"),
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-03", confianza="medio", sentimiento="negativo"),
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-04", confianza="medio", sentimiento="neutro"),
        ]
    )
    db_session.commit()

    resultado = saldo_opinion(db_session, actor.id, "2026-08-01", "2026-08-07")
    assert resultado == 25.0  # (2 positivas - 1 negativa) / 4 total * 100


def test_saldo_opinion_filtra_por_tema(db_session):
    actor = Actor(nombre="Tonanzin Fernández")
    fuente = Fuente(nombre="X propio", source_level=3, tipo="redes")
    db_session.add_all([actor, fuente])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=actor, fuente=fuente, tipo="mencion", tema="agua", fecha="2026-08-01", confianza="medio", sentimiento="negativo"),
            Observacion(actor=actor, fuente=fuente, tipo="mencion", tema="obra publica", fecha="2026-08-02", confianza="medio", sentimiento="positivo"),
        ]
    )
    db_session.commit()

    assert saldo_opinion(db_session, actor.id, "2026-08-01", "2026-08-07", tema="agua") == -100.0


def test_saldo_opinion_none_sin_datos(db_session):
    actor = Actor(nombre="Sin datos")
    db_session.add(actor)
    db_session.commit()

    assert saldo_opinion(db_session, actor.id, "2026-08-01", "2026-08-07") is None
