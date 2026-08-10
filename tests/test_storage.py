from siape.storage.models import Actor, Fuente, Observacion


def test_crear_actor(db_session):
    actor = Actor(nombre="Tonanzin Fernández", cargo_actual="Presidenta municipal", es_principal=True)
    db_session.add(actor)
    db_session.commit()

    guardado = db_session.query(Actor).filter_by(nombre="Tonanzin Fernández").one()
    assert guardado.es_principal is True
    assert guardado.cargo_actual == "Presidenta municipal"


def test_observacion_requiere_fuente_y_confianza(db_session):
    fuente = Fuente(nombre="Boletín Ayuntamiento SPC", source_level=1, tipo="oficial")
    db_session.add(fuente)
    db_session.flush()

    observacion = Observacion(
        fuente=fuente,
        tipo="mencion",
        fecha="2026-08-03",
        confianza="alto",
    )
    db_session.add(observacion)
    db_session.commit()

    guardada = db_session.query(Observacion).one()
    assert guardada.fuente.source_level == 1
    assert guardada.confianza == "alto"
    assert guardada.no_confirmado is False


def test_observacion_query_por_actor(db_session):
    actor = Actor(nombre="Adversario Ejemplo 1")
    fuente = Fuente(nombre="Medio Local Ejemplo", source_level=2, tipo="medios")
    db_session.add_all([actor, fuente])
    db_session.flush()

    db_session.add(
        Observacion(actor=actor, fuente=fuente, tipo="nota", fecha="2026-08-05", confianza="medio")
    )
    db_session.commit()

    observaciones = db_session.query(Observacion).filter_by(actor_id=actor.id).all()
    assert len(observaciones) == 1
