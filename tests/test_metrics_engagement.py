from siape.metrics.engagement import tasa_crecimiento, tasa_interaccion
from siape.storage.models import Actor, Fuente, Observacion


def _fuente(session):
    fuente = Fuente(nombre="Instagram propio", source_level=3, tipo="redes")
    session.add(fuente)
    session.flush()
    return fuente


def test_tasa_crecimiento_calcula_variacion(db_session):
    actor = Actor(nombre="Tonanzin Fernández")
    fuente = _fuente(db_session)
    db_session.add(actor)
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=actor, fuente=fuente, tipo="seguidores", fecha="2026-08-01", confianza="alto", valor_numerico=100),
            Observacion(actor=actor, fuente=fuente, tipo="seguidores", fecha="2026-08-07", confianza="alto", valor_numerico=110),
        ]
    )
    db_session.commit()

    resultado = tasa_crecimiento(db_session, actor.id, "seguidores", "2026-08-01", "2026-08-07")
    assert resultado == 10.0


def test_tasa_crecimiento_none_si_insuficientes_datos(db_session):
    actor = Actor(nombre="Solo un dato")
    fuente = _fuente(db_session)
    db_session.add(actor)
    db_session.flush()
    db_session.add(
        Observacion(actor=actor, fuente=fuente, tipo="seguidores", fecha="2026-08-01", confianza="alto", valor_numerico=100)
    )
    db_session.commit()

    assert tasa_crecimiento(db_session, actor.id, "seguidores", "2026-08-01", "2026-08-07") is None


def test_tasa_interaccion(db_session):
    actor = Actor(nombre="Tonanzin Fernández")
    fuente = _fuente(db_session)
    db_session.add(actor)
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=actor, fuente=fuente, tipo="alcance", fecha="2026-08-03", confianza="medio", valor_numerico=1000),
            Observacion(actor=actor, fuente=fuente, tipo="interaccion", fecha="2026-08-03", confianza="medio", valor_numerico=50),
        ]
    )
    db_session.commit()

    resultado = tasa_interaccion(db_session, actor.id, "interaccion", "alcance", "2026-08-01", "2026-08-07")
    assert resultado == 5.0
