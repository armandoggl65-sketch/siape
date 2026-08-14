from siape.metrics.transparencia import resumen_fuentes, resumen_temas
from siape.storage.models import Actor, Fuente, Observacion


def test_resumen_temas_agrega_totales_dominancia_y_saldo(db_session):
    actor = Actor(nombre="Tonanzin Fernández")
    adversario = Actor(nombre="Adversario Ejemplo 1")
    fuente = Fuente(nombre="Boletín Ayuntamiento SPC", source_level=1, tipo="oficial")
    db_session.add_all([actor, adversario, fuente])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=actor, fuente=fuente, tipo="mencion", tema="agua", sentimiento="positivo", fecha="2026-08-01", confianza="alto"),
            Observacion(actor=actor, fuente=fuente, tipo="mencion", tema="agua", sentimiento="negativo", fecha="2026-08-02", confianza="alto"),
            Observacion(actor=adversario, fuente=fuente, tipo="mencion", tema="seguridad", sentimiento="positivo", fecha="2026-08-01", confianza="alto"),
            Observacion(actor=adversario, fuente=fuente, tipo="mencion", tema="seguridad", sentimiento="positivo", fecha="2026-08-02", confianza="alto"),
        ]
    )
    db_session.commit()

    temas = resumen_temas(db_session, actor.id, "2026-08-01", "2026-08-07")
    por_tema = {t.tema: t for t in temas}

    assert por_tema["agua"].total_observaciones == 2
    assert por_tema["agua"].observaciones_actor == 2
    assert por_tema["agua"].actor_dominante == "Tonanzin Fernández"
    assert por_tema["agua"].saldo_opinion_actor == 0.0

    assert por_tema["seguridad"].total_observaciones == 2
    assert por_tema["seguridad"].observaciones_actor == 0
    assert por_tema["seguridad"].actor_dominante == "Adversario Ejemplo 1"
    assert por_tema["seguridad"].saldo_opinion_actor is None


def test_resumen_temas_vacio_sin_datos(db_session):
    actor = Actor(nombre="Sin datos")
    db_session.add(actor)
    db_session.commit()

    assert resumen_temas(db_session, actor.id, "2026-08-01", "2026-08-07") == []


def test_resumen_fuentes_agrupa_por_nivel_y_cuenta(db_session):
    actor = Actor(nombre="Tonanzin Fernández")
    oficial = Fuente(nombre="Boletín Ayuntamiento SPC", source_level=1, tipo="oficial")
    redes = Fuente(nombre="Cuenta X @ejemplo", source_level=3, tipo="redes")
    db_session.add_all([actor, oficial, redes])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=actor, fuente=oficial, tipo="mencion", fecha="2026-08-01", confianza="alto"),
            Observacion(actor=actor, fuente=redes, tipo="mencion", fecha="2026-08-02", confianza="medio"),
            Observacion(actor=actor, fuente=redes, tipo="mencion", fecha="2026-08-03", confianza="medio"),
        ]
    )
    db_session.commit()

    fuentes = resumen_fuentes(db_session, actor.id, "2026-08-01", "2026-08-07")

    assert len(fuentes) == 2
    # Ordenado por nivel ascendente: Nivel 1 (oficial) antes que Nivel 3 (redes).
    assert fuentes[0].fuente == "Boletín Ayuntamiento SPC"
    assert fuentes[0].nivel == 1
    assert fuentes[0].nivel_etiqueta == "Nivel 1 — Oficial"
    assert fuentes[0].num_observaciones == 1

    assert fuentes[1].fuente == "Cuenta X @ejemplo"
    assert fuentes[1].nivel == 3
    assert fuentes[1].num_observaciones == 2


def test_resumen_fuentes_vacio_sin_datos(db_session):
    actor = Actor(nombre="Sin datos")
    db_session.add(actor)
    db_session.commit()

    assert resumen_fuentes(db_session, actor.id, "2026-08-01", "2026-08-07") == []
