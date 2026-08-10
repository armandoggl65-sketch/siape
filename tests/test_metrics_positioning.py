from siape.metrics.positioning import notoriedad_por_actor, propiedad_tematica
from siape.storage.models import Actor, Fuente, Observacion


def test_notoriedad_por_actor_cuenta_observaciones(db_session):
    principal = Actor(nombre="Tonanzin Fernández")
    adversario = Actor(nombre="Adversario 1")
    fuente = Fuente(nombre="Medio Local", source_level=2, tipo="medios")
    db_session.add_all([principal, adversario, fuente])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=principal, fuente=fuente, tipo="mencion", fecha="2026-08-01", confianza="medio"),
            Observacion(actor=principal, fuente=fuente, tipo="mencion", fecha="2026-08-02", confianza="medio"),
            Observacion(actor=adversario, fuente=fuente, tipo="mencion", fecha="2026-08-03", confianza="medio"),
        ]
    )
    db_session.commit()

    resultado = notoriedad_por_actor(db_session, "2026-08-01", "2026-08-07")
    assert resultado == {principal.id: 2, adversario.id: 1}


def test_propiedad_tematica_identifica_dominante_y_empate(db_session):
    principal = Actor(nombre="Tonanzin Fernández")
    adversario = Actor(nombre="Adversario 1")
    fuente = Fuente(nombre="Medio Local", source_level=2, tipo="medios")
    db_session.add_all([principal, adversario, fuente])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=principal, fuente=fuente, tipo="mencion", tema="obra publica", fecha="2026-08-01", confianza="medio"),
            Observacion(actor=principal, fuente=fuente, tipo="mencion", tema="obra publica", fecha="2026-08-02", confianza="medio"),
            Observacion(actor=adversario, fuente=fuente, tipo="mencion", tema="obra publica", fecha="2026-08-03", confianza="medio"),
            Observacion(actor=principal, fuente=fuente, tipo="mencion", tema="seguridad", fecha="2026-08-01", confianza="medio"),
            Observacion(actor=adversario, fuente=fuente, tipo="mencion", tema="seguridad", fecha="2026-08-02", confianza="medio"),
        ]
    )
    db_session.commit()

    resultado = propiedad_tematica(db_session, "2026-08-01", "2026-08-07")
    assert resultado["obra publica"] == principal.id
    assert resultado["seguridad"] is None  # empate 1-1
