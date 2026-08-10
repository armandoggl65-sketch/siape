from siape.alerts.crisis import detectar_crisis
from siape.storage.models import Actor, Fuente, Observacion


def test_detectar_crisis_por_saldo_de_opinion_negativo(db_session):
    actor = Actor(nombre="Tonanzin Fernández")
    fuente = Fuente(nombre="X propio", source_level=3, tipo="redes")
    db_session.add_all([actor, fuente])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-01", confianza="medio", sentimiento="negativo"),
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-02", confianza="medio", sentimiento="negativo"),
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-03", confianza="medio", sentimiento="negativo"),
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-04", confianza="medio", sentimiento="positivo"),
        ]
    )
    db_session.commit()

    alertas = detectar_crisis(db_session, actor.id, "2026-08-01", "2026-08-07")

    assert len(alertas) == 1
    assert "Saldo de opinión negativo" in alertas[0].descripcion
    assert alertas[0].plazo == "48 horas"


def test_detectar_crisis_por_caida_de_seguidores(db_session):
    actor = Actor(nombre="Tonanzin Fernández")
    fuente = Fuente(nombre="Instagram propio", source_level=3, tipo="redes")
    db_session.add_all([actor, fuente])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=actor, fuente=fuente, tipo="seguidores", fecha="2026-08-01", confianza="alto", valor_numerico=1000),
            Observacion(actor=actor, fuente=fuente, tipo="seguidores", fecha="2026-08-07", confianza="alto", valor_numerico=800),
        ]
    )
    db_session.commit()

    alertas = detectar_crisis(db_session, actor.id, "2026-08-01", "2026-08-07")

    assert len(alertas) == 1
    assert "Caída de seguidores" in alertas[0].descripcion


def test_detectar_crisis_sin_senales_devuelve_vacio(db_session):
    actor = Actor(nombre="Sin problemas")
    fuente = Fuente(nombre="X propio", source_level=3, tipo="redes")
    db_session.add_all([actor, fuente])
    db_session.flush()

    db_session.add(
        Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-01", confianza="medio", sentimiento="positivo")
    )
    db_session.commit()

    assert detectar_crisis(db_session, actor.id, "2026-08-01", "2026-08-07") == []
