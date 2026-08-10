from siape.dashboard.mapa import notoriedad_por_seccion
from siape.storage.geo_models import ObservacionSeccion
from siape.storage.models import Actor, Fuente, Observacion


def test_notoriedad_por_seccion_agrega_conteos(db_session):
    """No requiere PostGIS: solo agrega la tabla puente observacion_seccion,
    que no tiene columnas de geometría."""
    actor = Actor(nombre="Tonanzin Fernández")
    fuente = Fuente(nombre="Boletín Ayuntamiento SPC", source_level=1, tipo="oficial")
    db_session.add_all([actor, fuente])
    db_session.flush()

    obs1 = Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-01", confianza="alto")
    obs2 = Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-02", confianza="alto")
    obs3 = Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-03", confianza="alto")
    db_session.add_all([obs1, obs2, obs3])
    db_session.flush()

    db_session.add_all(
        [
            ObservacionSeccion(observacion_id=obs1.id, seccion_id=101),
            ObservacionSeccion(observacion_id=obs2.id, seccion_id=101),
            ObservacionSeccion(observacion_id=obs3.id, seccion_id=202),
        ]
    )
    db_session.commit()

    resultado = notoriedad_por_seccion(db_session, actor.id, "2026-08-01", "2026-08-07")
    assert resultado == {101: 2, 202: 1}


def test_notoriedad_por_seccion_vacio_sin_vinculos(db_session):
    actor = Actor(nombre="Sin geo")
    db_session.add(actor)
    db_session.commit()

    assert notoriedad_por_seccion(db_session, actor.id, "2026-08-01", "2026-08-07") == {}
