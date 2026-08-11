from siape.analysis.schemas import Indicador
from siape.metrics.historial import (
    calcular_variacion,
    construir_indicadores_con_historial,
    enriquecer_con_variacion,
    registrar_corte,
    valor_ultimo_corte,
)
from siape.storage.models import Actor, Fuente, Metrica, Observacion


def test_calcular_variacion_porcentaje():
    assert calcular_variacion(120, 100) == 20.0
    assert calcular_variacion(80, 100) == -20.0


def test_calcular_variacion_sin_corte_previo_o_cero():
    assert calcular_variacion(50, None) is None
    assert calcular_variacion(50, 0) is None


def test_valor_ultimo_corte_toma_el_mas_reciente_antes_de_la_fecha(db_session):
    actor = Actor(nombre="Tonanzin Fernández")
    db_session.add(actor)
    db_session.flush()

    db_session.add_all(
        [
            Metrica(actor_id=actor.id, kpi="share_of_voice_pct", valor=40.0, confianza="medio", fecha_corte="2026-07-24"),
            Metrica(actor_id=actor.id, kpi="share_of_voice_pct", valor=50.0, confianza="medio", fecha_corte="2026-07-31"),
        ]
    )
    db_session.commit()

    assert valor_ultimo_corte(db_session, actor.id, "share_of_voice_pct", "2026-08-07") == 50.0
    assert valor_ultimo_corte(db_session, actor.id, "share_of_voice_pct", "2026-07-25") == 40.0
    assert valor_ultimo_corte(db_session, actor.id, "share_of_voice_pct", "2026-07-01") is None


def test_enriquecer_con_variacion(db_session):
    actor = Actor(nombre="Tonanzin Fernández")
    db_session.add(actor)
    db_session.flush()
    db_session.add(Metrica(actor_id=actor.id, kpi="share_of_voice_pct", valor=50.0, confianza="medio", fecha_corte="2026-07-31"))
    db_session.commit()

    indicadores = [Indicador(kpi="share_of_voice_pct", valor=60.0, confianza="medio")]
    enriquecidos = enriquecer_con_variacion(db_session, actor.id, indicadores, "2026-08-07")

    assert enriquecidos[0].variacion == 20.0
    assert indicadores[0].variacion is None  # no muta el original


def test_registrar_corte_persiste_y_permite_comparar_despues(db_session):
    actor = Actor(nombre="Tonanzin Fernández")
    fuente = Fuente(nombre="X propio", source_level=3, tipo="redes")
    db_session.add_all([actor, fuente])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-01", confianza="medio"),
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-02", confianza="medio"),
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-09", confianza="medio"),
        ]
    )
    db_session.commit()

    primer_corte = construir_indicadores_con_historial(
        db_session, actor.id, "2026-08-01", "2026-08-07", fecha_corte="2026-08-07"
    )
    assert all(i.variacion is None for i in primer_corte)  # sin corte previo
    registrar_corte(db_session, actor.id, primer_corte, "2026-08-07")

    registros = db_session.query(Metrica).filter_by(actor_id=actor.id).all()
    assert len(registros) == len(primer_corte)

    segundo_corte = construir_indicadores_con_historial(
        db_session, actor.id, "2026-08-08", "2026-08-14", fecha_corte="2026-08-14"
    )
    sov = next(i for i in segundo_corte if i.kpi == "share_of_voice_pct")
    assert sov.variacion == 0.0  # mismo valor que el corte anterior (100% ambas veces)
