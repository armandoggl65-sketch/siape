from siape.metrics.share_of_voice import share_of_voice
from siape.storage.models import Actor, Fuente, Observacion


def test_share_of_voice_calcula_porcentaje(db_session):
    principal = Actor(nombre="Tonanzin Fernández")
    adversario = Actor(nombre="Adversario 1")
    fuente = Fuente(nombre="Medio Local", source_level=2, tipo="medios")
    db_session.add_all([principal, adversario, fuente])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=principal, fuente=fuente, tipo="mencion", fecha="2026-08-03", confianza="medio"),
            Observacion(actor=principal, fuente=fuente, tipo="mencion", fecha="2026-08-04", confianza="medio"),
            Observacion(actor=principal, fuente=fuente, tipo="mencion", fecha="2026-08-05", confianza="medio"),
            Observacion(actor=adversario, fuente=fuente, tipo="mencion", fecha="2026-08-05", confianza="medio"),
        ]
    )
    db_session.commit()

    resultado = share_of_voice(db_session, principal.id, "2026-08-01", "2026-08-07")
    assert resultado == 75.0


def test_share_of_voice_none_si_no_hay_observaciones(db_session):
    actor = Actor(nombre="Sin datos")
    db_session.add(actor)
    db_session.commit()

    assert share_of_voice(db_session, actor.id, "2026-08-01", "2026-08-07") is None
