#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/siape

mkdir -p 'siape/metrics'
cat > 'siape/metrics/__init__.py' <<'SIAPE_F2_EOF_1_MARK'
SIAPE_F2_EOF_1_MARK

mkdir -p 'siape/metrics'
cat > 'siape/metrics/engagement.py' <<'SIAPE_F2_EOF_2_MARK'
"""Métricas de redes: crecimiento y tasa de interacción (Sección 6, bloque 'Redes').

Convención: los conteos periódicos (seguidores, interacciones, alcance, etc.) se
cargan como `observaciones` con `tipo` igual al nombre de la métrica cruda
(p. ej. `tipo="seguidores_instagram"`) y `valor_numerico` con el conteo.
"""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from siape.storage.models import Observacion


def _valores_en_rango(
    session: Session, actor_id: int, tipo: str, fecha_inicio: str, fecha_fin: str
) -> list[Observacion]:
    stmt = (
        select(Observacion)
        .where(
            Observacion.actor_id == actor_id,
            Observacion.tipo == tipo,
            Observacion.fecha >= fecha_inicio,
            Observacion.fecha <= fecha_fin,
            Observacion.valor_numerico.is_not(None),
        )
        .order_by(Observacion.fecha)
    )
    return list(session.scalars(stmt))


def tasa_crecimiento(
    session: Session, actor_id: int, tipo: str, fecha_inicio: str, fecha_fin: str
) -> float | None:
    """% de variación entre la primera y la última observación de `tipo` en el rango.

    Devuelve None si hay menos de dos observaciones o si la inicial es 0
    (no se puede calcular una variación porcentual).
    """
    observaciones = _valores_en_rango(session, actor_id, tipo, fecha_inicio, fecha_fin)
    if len(observaciones) < 2:
        return None
    inicial, final = observaciones[0].valor_numerico, observaciones[-1].valor_numerico
    if not inicial:
        return None
    return round((final - inicial) / inicial * 100, 2)


def tasa_interaccion(
    session: Session,
    actor_id: int,
    tipo_interacciones: str,
    tipo_alcance: str,
    fecha_inicio: str,
    fecha_fin: str,
) -> float | None:
    """Interacciones totales / alcance total en el rango, como %."""
    interacciones = _valores_en_rango(session, actor_id, tipo_interacciones, fecha_inicio, fecha_fin)
    alcance = _valores_en_rango(session, actor_id, tipo_alcance, fecha_inicio, fecha_fin)
    total_alcance = sum(o.valor_numerico for o in alcance)
    if not total_alcance:
        return None
    total_interacciones = sum(o.valor_numerico for o in interacciones)
    return round(total_interacciones / total_alcance * 100, 2)
SIAPE_F2_EOF_2_MARK

mkdir -p 'siape/metrics'
cat > 'siape/metrics/share_of_voice.py' <<'SIAPE_F2_EOF_3_MARK'
"""Share of voice: % de menciones del actor frente al total del entorno competitivo."""
from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from siape.storage.models import Observacion


def share_of_voice(
    session: Session,
    actor_id: int,
    fecha_inicio: str,
    fecha_fin: str,
    tipo: str = "mencion",
) -> float | None:
    """% de menciones del actor sobre el total de menciones (todos los actores) en el rango.

    Solo cuenta observaciones de `tipo` (por defecto 'mencion'): los conteos
    de métricas propias (p. ej. 'seguidores') no son "voz" y no deben diluir
    el share of voice.
    """
    total = session.scalar(
        select(func.count(Observacion.id)).where(
            Observacion.actor_id.is_not(None),
            Observacion.tipo == tipo,
            Observacion.fecha >= fecha_inicio,
            Observacion.fecha <= fecha_fin,
        )
    )
    if not total:
        return None
    del_actor = session.scalar(
        select(func.count(Observacion.id)).where(
            Observacion.actor_id == actor_id,
            Observacion.tipo == tipo,
            Observacion.fecha >= fecha_inicio,
            Observacion.fecha <= fecha_fin,
        )
    )
    return round(del_actor / total * 100, 2)
SIAPE_F2_EOF_3_MARK

mkdir -p 'siape/metrics'
cat > 'siape/metrics/sentiment.py' <<'SIAPE_F2_EOF_4_MARK'
"""Sentimiento: saldo de opinión (positivo − negativo) por actor, tema y periodo."""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from siape.storage.models import Observacion


def saldo_opinion(
    session: Session,
    actor_id: int,
    fecha_inicio: str,
    fecha_fin: str,
    tema: str | None = None,
) -> float | None:
    """(positivas − negativas) / total_con_sentimiento * 100.

    Si `tema` se especifica, restringe el cálculo a observaciones de ese tema.
    Devuelve None si no hay observaciones con sentimiento etiquetado en el rango.
    """
    stmt = select(Observacion.sentimiento).where(
        Observacion.actor_id == actor_id,
        Observacion.fecha >= fecha_inicio,
        Observacion.fecha <= fecha_fin,
        Observacion.sentimiento.is_not(None),
    )
    if tema is not None:
        stmt = stmt.where(Observacion.tema == tema)

    sentimientos = list(session.scalars(stmt))
    if not sentimientos:
        return None

    positivas = sentimientos.count("positivo")
    negativas = sentimientos.count("negativo")
    return round((positivas - negativas) / len(sentimientos) * 100, 2)
SIAPE_F2_EOF_4_MARK

mkdir -p 'siape/metrics'
cat > 'siape/metrics/positioning.py' <<'SIAPE_F2_EOF_5_MARK'
"""Posicionamiento comparativo: notoriedad estimada y propiedad temática."""
from __future__ import annotations

from collections import Counter

from sqlalchemy import select
from sqlalchemy.orm import Session

from siape.storage.models import Observacion


def notoriedad_por_actor(
    session: Session, fecha_inicio: str, fecha_fin: str
) -> dict[int, int]:
    """Número de observaciones por actor en el rango, como proxy de notoriedad."""
    stmt = select(Observacion.actor_id).where(
        Observacion.actor_id.is_not(None),
        Observacion.fecha >= fecha_inicio,
        Observacion.fecha <= fecha_fin,
    )
    return dict(Counter(session.scalars(stmt)))


def propiedad_tematica(
    session: Session, fecha_inicio: str, fecha_fin: str
) -> dict[str, int | None]:
    """Para cada tema con observaciones, el actor_id con más menciones.

    El valor es None cuando hay empate entre dos o más actores (no se puede
    afirmar que uno "domina" ese tema sin triangulación adicional).
    """
    stmt = select(Observacion.tema, Observacion.actor_id).where(
        Observacion.tema.is_not(None),
        Observacion.actor_id.is_not(None),
        Observacion.fecha >= fecha_inicio,
        Observacion.fecha <= fecha_fin,
    )
    por_tema: dict[str, Counter] = {}
    for tema, actor_id in session.execute(stmt):
        por_tema.setdefault(tema, Counter())[actor_id] += 1

    resultado: dict[str, int | None] = {}
    for tema, contador in por_tema.items():
        mas_comunes = contador.most_common(2)
        empate = len(mas_comunes) > 1 and mas_comunes[0][1] == mas_comunes[1][1]
        resultado[tema] = None if empate else mas_comunes[0][0]
    return resultado
SIAPE_F2_EOF_5_MARK

mkdir -p 'siape/metrics'
cat > 'siape/metrics/build_indicadores.py' <<'SIAPE_F2_EOF_6_MARK'
"""Convierte los cálculos de siape/metrics/* al formato Indicador (Fase 1).

Puente entre la Opción 2 (métricas desde la BD) y la Opción 1 (motor de
análisis): permite alimentar al motor con KPIs calculados en vez de solo
el JSON de ejemplo curado a mano.
"""
from __future__ import annotations

from sqlalchemy.orm import Session

from siape.analysis.schemas import Indicador
from siape.metrics.engagement import tasa_crecimiento
from siape.metrics.sentiment import saldo_opinion
from siape.metrics.share_of_voice import share_of_voice


def construir_indicadores(
    session: Session,
    actor_id: int,
    fecha_inicio: str,
    fecha_fin: str,
    tipo_seguidores: str = "seguidores",
) -> list[Indicador]:
    """Calcula un set base de KPIs desde la BD y los arma como `Indicador`.

    Cada KPI calculado se omite si no hay datos suficientes en el rango (no se
    inventan valores). La confianza se marca 'medio' de forma conservadora:
    combina varias observaciones sin la triangulación explícita que requeriría
    'alto' (Sección 7, metodología).
    """
    indicadores: list[Indicador] = []

    crecimiento = tasa_crecimiento(session, actor_id, tipo_seguidores, fecha_inicio, fecha_fin)
    if crecimiento is not None:
        indicadores.append(
            Indicador(
                kpi=f"crecimiento_{tipo_seguidores}",
                valor=crecimiento,
                variacion=None,
                confianza="medio",
            )
        )

    sov = share_of_voice(session, actor_id, fecha_inicio, fecha_fin)
    if sov is not None:
        indicadores.append(
            Indicador(kpi="share_of_voice_pct", valor=sov, variacion=None, confianza="medio")
        )

    saldo = saldo_opinion(session, actor_id, fecha_inicio, fecha_fin)
    if saldo is not None:
        indicadores.append(
            Indicador(kpi="saldo_opinion", valor=saldo, variacion=None, confianza="medio")
        )

    return indicadores
SIAPE_F2_EOF_6_MARK

mkdir -p 'tests'
cat > 'tests/test_metrics_engagement.py' <<'SIAPE_F2_EOF_7_MARK'
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
SIAPE_F2_EOF_7_MARK

mkdir -p 'tests'
cat > 'tests/test_metrics_share_of_voice.py' <<'SIAPE_F2_EOF_8_MARK'
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
SIAPE_F2_EOF_8_MARK

mkdir -p 'tests'
cat > 'tests/test_metrics_sentiment.py' <<'SIAPE_F2_EOF_9_MARK'
from siape.metrics.sentiment import saldo_opinion
from siape.storage.models import Actor, Fuente, Observacion


def test_saldo_opinion_calcula_balance(db_session):
    actor = Actor(nombre="Tonanzin Fernández")
    fuente = Fuente(nombre="X propio", source_level=3, tipo="redes")
    db_session.add_all([actor, fuente])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-01", confianza="medio", sentimiento="positivo"),
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-02", confianza="medio", sentimiento="positivo"),
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-03", confianza="medio", sentimiento="negativo"),
            Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-04", confianza="medio", sentimiento="neutro"),
        ]
    )
    db_session.commit()

    resultado = saldo_opinion(db_session, actor.id, "2026-08-01", "2026-08-07")
    assert resultado == 25.0  # (2 positivas - 1 negativa) / 4 total * 100


def test_saldo_opinion_filtra_por_tema(db_session):
    actor = Actor(nombre="Tonanzin Fernández")
    fuente = Fuente(nombre="X propio", source_level=3, tipo="redes")
    db_session.add_all([actor, fuente])
    db_session.flush()

    db_session.add_all(
        [
            Observacion(actor=actor, fuente=fuente, tipo="mencion", tema="agua", fecha="2026-08-01", confianza="medio", sentimiento="negativo"),
            Observacion(actor=actor, fuente=fuente, tipo="mencion", tema="obra publica", fecha="2026-08-02", confianza="medio", sentimiento="positivo"),
        ]
    )
    db_session.commit()

    assert saldo_opinion(db_session, actor.id, "2026-08-01", "2026-08-07", tema="agua") == -100.0


def test_saldo_opinion_none_sin_datos(db_session):
    actor = Actor(nombre="Sin datos")
    db_session.add(actor)
    db_session.commit()

    assert saldo_opinion(db_session, actor.id, "2026-08-01", "2026-08-07") is None
SIAPE_F2_EOF_9_MARK

mkdir -p 'tests'
cat > 'tests/test_metrics_positioning.py' <<'SIAPE_F2_EOF_10_MARK'
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
SIAPE_F2_EOF_10_MARK

mkdir -p 'tests'
cat > 'tests/test_metrics_build_indicadores.py' <<'SIAPE_F2_EOF_11_MARK'
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
SIAPE_F2_EOF_11_MARK

git add -A
git commit -m "Implement Fase 2 (métricas) of SIAPE"
git push
echo "LISTO"
