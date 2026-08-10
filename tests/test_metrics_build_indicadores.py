from siape.metrics.build_indicadores import construir_indicadores
from siape.storage.models import Actor, Fuente, Observacion


def test_construir_indicadores_incluye_solo_kpis_con_datos(db_session):
    principal = Actor(nombre="Tonanzin Fernández")
    adversario = Actor(nombre="Adversario 1")
    fuente = Fuente(nombre="Instagram propio", source_level=3, tipo="redes")
    db_session.add_all([principal, adversario, fuente])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=principal, fuente=fuente, tipo="seguidores", fecha="2026-08-01", confianza="alto", valor_numerico=100),
            Observacion(actor=principal, fuente=fuente, tipo="seguidores", fecha="2026-08-07", confianza="alto", valor_numerico=120),
            Observacion(actor=principal, fuente=fuente, tipo="mencion", fecha="2026-08-03", confianza="medio", sentimiento="positivo"),
            Observacion(actor=adversario, fuente=fuente, tipo="mencion", fecha="2026-08-04", confianza="medio"),
        ]
    )
    db_session.commit()

    indicadores = construir_indicadores(db_session, principal.id, "2026-08-01", "2026-08-07")
    kpis = {i.kpi: i.valor for i in indicadores}

    assert kpis["crecimiento_seguidores"] == 20.0
    assert kpis["share_of_voice_pct"] == 50.0
    assert kpis["saldo_opinion"] == 100.0
    assert all(i.confianza == "medio" for i in indicadores)


def test_construir_indicadores_vacio_sin_datos(db_session):
    actor = Actor(nombre="Sin datos")
    db_session.add(actor)
    db_session.commit()

    assert construir_indicadores(db_session, actor.id, "2026-08-01", "2026-08-07") == []
