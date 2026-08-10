from siape.alerts.opportunity import detectar_oceanos_azules
from siape.storage.models import Actor, Fuente, Observacion


def test_detecta_tema_dominado_por_adversario_sin_presencia_propia(db_session):
    principal = Actor(nombre="Tonanzin Fernández")
    adversario = Actor(nombre="Adversario 1")
    fuente = Fuente(nombre="Medio Local", source_level=2, tipo="medios")
    db_session.add_all([principal, adversario, fuente])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=adversario, fuente=fuente, tipo="mencion", tema="seguridad", fecha="2026-08-01", confianza="medio"),
            Observacion(actor=adversario, fuente=fuente, tipo="mencion", tema="seguridad", fecha="2026-08-02", confianza="medio"),
        ]
    )
    db_session.commit()

    alertas = detectar_oceanos_azules(db_session, principal.id, "2026-08-01", "2026-08-07")

    assert len(alertas) == 1
    assert "seguridad" in alertas[0].descripcion


def test_no_alerta_si_actor_principal_ya_tiene_presencia(db_session):
    principal = Actor(nombre="Tonanzin Fernández")
    adversario = Actor(nombre="Adversario 1")
    fuente = Fuente(nombre="Medio Local", source_level=2, tipo="medios")
    db_session.add_all([principal, adversario, fuente])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=adversario, fuente=fuente, tipo="mencion", tema="seguridad", fecha="2026-08-01", confianza="medio"),
            Observacion(actor=adversario, fuente=fuente, tipo="mencion", tema="seguridad", fecha="2026-08-02", confianza="medio"),
            Observacion(actor=principal, fuente=fuente, tipo="mencion", tema="seguridad", fecha="2026-08-03", confianza="medio"),
        ]
    )
    db_session.commit()

    assert detectar_oceanos_azules(db_session, principal.id, "2026-08-01", "2026-08-07") == []


def test_no_alerta_si_el_propio_actor_domina_el_tema(db_session):
    principal = Actor(nombre="Tonanzin Fernández")
    fuente = Fuente(nombre="Medio Local", source_level=2, tipo="medios")
    db_session.add_all([principal, fuente])
    db_session.flush()

    db_session.add(
        Observacion(actor=principal, fuente=fuente, tipo="mencion", tema="obra publica", fecha="2026-08-01", confianza="medio")
    )
    db_session.commit()

    assert detectar_oceanos_azules(db_session, principal.id, "2026-08-01", "2026-08-07") == []
