#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/siape

mkdir -p 'siape/alerts'
cat > 'siape/alerts/__init__.py' <<'SIAPE_F4_EOF_1_MARK'
SIAPE_F4_EOF_1_MARK

mkdir -p 'siape/alerts'
cat > 'siape/alerts/crisis.py' <<'SIAPE_F4_EOF_2_MARK'
"""Detección temprana de crisis (Sección 5.F): señales de riesgo reputacional."""
from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy.orm import Session

from siape.metrics.engagement import tasa_crecimiento
from siape.metrics.sentiment import saldo_opinion

UMBRAL_SALDO_NEGATIVO = -30.0
UMBRAL_CAIDA_KPI_PCT = -15.0


@dataclass
class AlertaCrisis:
    descripcion: str
    accion_sugerida: str
    plazo: str
    confianza: str


def detectar_crisis(
    session: Session,
    actor_id: int,
    fecha_inicio: str,
    fecha_fin: str,
    tipo_seguidores: str = "seguidores",
) -> list[AlertaCrisis]:
    """Revisa saldo de opinión y crecimiento de KPIs en busca de señales de crisis.

    No inventa alertas sin datos: cada chequeo se omite si no hay suficiente
    información en el rango (mismo principio de las funciones de siape/metrics).
    """
    alertas: list[AlertaCrisis] = []

    saldo = saldo_opinion(session, actor_id, fecha_inicio, fecha_fin)
    if saldo is not None and saldo <= UMBRAL_SALDO_NEGATIVO:
        alertas.append(
            AlertaCrisis(
                descripcion=f"Saldo de opinión negativo ({saldo}%) en el periodo.",
                accion_sugerida="Revisar narrativas negativas dominantes y preparar respuesta.",
                plazo="48 horas",
                confianza="medio",
            )
        )

    crecimiento = tasa_crecimiento(session, actor_id, tipo_seguidores, fecha_inicio, fecha_fin)
    if crecimiento is not None and crecimiento <= UMBRAL_CAIDA_KPI_PCT:
        alertas.append(
            AlertaCrisis(
                descripcion=f"Caída de {tipo_seguidores} del {crecimiento}% en el periodo.",
                accion_sugerida="Investigar la causa de la caída (fuga de seguidores, reporte masivo, etc.).",
                plazo="7 días",
                confianza="medio",
            )
        )

    return alertas
SIAPE_F4_EOF_2_MARK

mkdir -p 'siape/alerts'
cat > 'siape/alerts/opportunity.py' <<'SIAPE_F4_EOF_3_MARK'
"""Detección de ventanas de oportunidad (Sección 5.G): temas vacíos ("océanos azules")."""
from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from siape.metrics.positioning import propiedad_tematica
from siape.storage.models import Observacion


@dataclass
class AlertaOportunidad:
    descripcion: str
    accion_sugerida: str
    plazo: str
    confianza: str


def _temas_del_actor(
    session: Session, actor_id: int, fecha_inicio: str, fecha_fin: str
) -> set[str]:
    stmt = (
        select(Observacion.tema)
        .where(
            Observacion.actor_id == actor_id,
            Observacion.tema.is_not(None),
            Observacion.fecha >= fecha_inicio,
            Observacion.fecha <= fecha_fin,
        )
        .distinct()
    )
    return set(session.scalars(stmt))


def detectar_oceanos_azules(
    session: Session, actor_id: int, fecha_inicio: str, fecha_fin: str
) -> list[AlertaOportunidad]:
    """Temas que otro actor domina y donde el actor principal no tiene presencia alguna."""
    propiedad = propiedad_tematica(session, fecha_inicio, fecha_fin)
    temas_propios = _temas_del_actor(session, actor_id, fecha_inicio, fecha_fin)

    alertas: list[AlertaOportunidad] = []
    for tema, actor_dominante in propiedad.items():
        if actor_dominante is not None and actor_dominante != actor_id and tema not in temas_propios:
            alertas.append(
                AlertaOportunidad(
                    descripcion=(
                        f"El tema '{tema}' es dominado por otro actor; "
                        "el actor principal no tiene presencia en él."
                    ),
                    accion_sugerida=f"Evaluar generar agenda/contenido propio sobre '{tema}'.",
                    plazo="15 días",
                    confianza="medio",
                )
            )
    return alertas
SIAPE_F4_EOF_3_MARK

mkdir -p 'siape/dashboard'
cat > 'siape/dashboard/__init__.py' <<'SIAPE_F4_EOF_4_MARK'
SIAPE_F4_EOF_4_MARK

mkdir -p 'siape/dashboard'
cat > 'siape/dashboard/app.py' <<'SIAPE_F4_EOF_5_MARK'
"""Tablero de indicadores SIAPE (Streamlit).

Uso: streamlit run siape/dashboard/app.py
"""
from __future__ import annotations

import datetime as dt

import streamlit as st

from siape.alerts.crisis import detectar_crisis
from siape.alerts.opportunity import detectar_oceanos_azules
from siape.dashboard.semaforo import semaforo_indicador
from siape.metrics.build_indicadores import construir_indicadores
from siape.storage.db import make_engine, make_session_factory
from siape.storage.models import Actor


def main() -> None:
    st.set_page_config(page_title="SIAPE — Tablero", layout="wide")
    st.title("SIAPE — Tablero de indicadores")

    engine = make_engine()
    session_factory = make_session_factory(engine)

    with session_factory() as session:
        actores = session.query(Actor).order_by(Actor.nombre).all()
        if not actores:
            st.warning(
                "No hay actores cargados en la base de datos. "
                "Carga datos con la capa de ingesta (Fase 0 manual o conectores de Fase 3) primero."
            )
            return

        nombres_a_id = {a.nombre: a.id for a in actores}
        nombre_seleccionado = st.sidebar.selectbox("Actor", list(nombres_a_id.keys()))
        actor_id = nombres_a_id[nombre_seleccionado]

        hoy = dt.date.today()
        fecha_inicio = st.sidebar.date_input("Desde", hoy - dt.timedelta(days=7))
        fecha_fin = st.sidebar.date_input("Hasta", hoy)
        fecha_inicio_str, fecha_fin_str = str(fecha_inicio), str(fecha_fin)

        st.subheader("Indicadores clave")
        indicadores = construir_indicadores(session, actor_id, fecha_inicio_str, fecha_fin_str)
        if indicadores:
            filas = [
                {
                    "KPI": i.kpi,
                    "Valor": i.valor,
                    "Variación": i.variacion,
                    "Confianza": i.confianza,
                    "Semáforo": semaforo_indicador(i),
                }
                for i in indicadores
            ]
            st.table(filas)
        else:
            st.info("Sin indicadores calculables para el periodo seleccionado.")

        st.subheader("Alertas")
        alertas_crisis = detectar_crisis(session, actor_id, fecha_inicio_str, fecha_fin_str)
        alertas_oportunidad = detectar_oceanos_azules(session, actor_id, fecha_inicio_str, fecha_fin_str)

        if not alertas_crisis and not alertas_oportunidad:
            st.info("Sin alertas activas en el periodo.")

        for alerta in alertas_crisis:
            st.error(
                f"🔴 CRISIS — {alerta.descripcion} · Acción: {alerta.accion_sugerida} "
                f"(plazo: {alerta.plazo})"
            )
        for alerta in alertas_oportunidad:
            st.success(
                f"🟢 OPORTUNIDAD — {alerta.descripcion} · Acción: {alerta.accion_sugerida} "
                f"(plazo: {alerta.plazo})"
            )


main()
SIAPE_F4_EOF_5_MARK

mkdir -p 'siape/dashboard'
cat > 'siape/dashboard/semaforo.py' <<'SIAPE_F4_EOF_6_MARK'
"""Traducción de indicadores a semáforo visual (🟢🟡🔴), sin dependencias de Streamlit.

Separado de siape/dashboard/app.py para poder probarlo sin un navegador.
"""
from __future__ import annotations

from siape.analysis.schemas import Indicador

VERDE = "🟢"
AMARILLO = "🟡"
ROJO = "🔴"


def semaforo_confianza(confianza: str) -> str:
    return {"alto": VERDE, "medio": AMARILLO, "bajo": ROJO}.get(confianza, AMARILLO)


def semaforo_variacion(variacion: float | None) -> str:
    """Verde si mejora, rojo si empeora, amarillo si es estable o no hay dato."""
    if variacion is None or variacion == 0:
        return AMARILLO
    return VERDE if variacion > 0 else ROJO


def semaforo_indicador(indicador: Indicador) -> str:
    """Semáforo combinado: usa la variación cuando existe; si no, la confianza."""
    if indicador.variacion is not None:
        return semaforo_variacion(indicador.variacion)
    return semaforo_confianza(indicador.confianza)
SIAPE_F4_EOF_6_MARK

mkdir -p 'tests'
cat > 'tests/test_alerts_crisis.py' <<'SIAPE_F4_EOF_7_MARK'
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
SIAPE_F4_EOF_7_MARK

mkdir -p 'tests'
cat > 'tests/test_alerts_opportunity.py' <<'SIAPE_F4_EOF_8_MARK'
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
SIAPE_F4_EOF_8_MARK

mkdir -p 'tests'
cat > 'tests/test_dashboard_app.py' <<'SIAPE_F4_EOF_9_MARK'
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from siape.storage.models import Actor, Base, Fuente, Observacion


def _seeded_engine():
    """Motor SQLite en memoria compartido entre conexiones (StaticPool), con datos de ejemplo."""
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    with Session(engine) as session:
        actor = Actor(nombre="Tonanzin Fernández")
        fuente = Fuente(nombre="Instagram propio", source_level=3, tipo="redes")
        session.add_all([actor, fuente])
        session.flush()
        session.add_all(
            [
                Observacion(actor=actor, fuente=fuente, tipo="seguidores", fecha="2026-08-01", confianza="alto", valor_numerico=100),
                Observacion(actor=actor, fuente=fuente, tipo="seguidores", fecha="2026-08-07", confianza="alto", valor_numerico=120),
                Observacion(actor=actor, fuente=fuente, tipo="mencion", fecha="2026-08-03", confianza="medio", sentimiento="positivo"),
            ]
        )
        session.commit()
    return engine


def test_dashboard_app_renderiza_sin_errores(monkeypatch):
    from streamlit.testing.v1 import AppTest

    engine = _seeded_engine()
    monkeypatch.setattr("siape.storage.db.make_engine", lambda *args, **kwargs: engine)

    at = AppTest.from_file("../siape/dashboard/app.py")
    at.run(timeout=15)

    assert not at.exception
    assert "SIAPE — Tablero de indicadores" in [t.value for t in at.title]
SIAPE_F4_EOF_9_MARK

mkdir -p 'tests'
cat > 'tests/test_dashboard_semaforo.py' <<'SIAPE_F4_EOF_10_MARK'
from siape.analysis.schemas import Indicador
from siape.dashboard.semaforo import (
    AMARILLO,
    ROJO,
    VERDE,
    semaforo_confianza,
    semaforo_indicador,
    semaforo_variacion,
)


def test_semaforo_confianza():
    assert semaforo_confianza("alto") == VERDE
    assert semaforo_confianza("medio") == AMARILLO
    assert semaforo_confianza("bajo") == ROJO


def test_semaforo_variacion():
    assert semaforo_variacion(5.0) == VERDE
    assert semaforo_variacion(-5.0) == ROJO
    assert semaforo_variacion(0) == AMARILLO
    assert semaforo_variacion(None) == AMARILLO


def test_semaforo_indicador_prioriza_variacion_sobre_confianza():
    indicador = Indicador(kpi="x", valor=1, variacion=-2.0, confianza="alto")
    assert semaforo_indicador(indicador) == ROJO


def test_semaforo_indicador_usa_confianza_sin_variacion():
    indicador = Indicador(kpi="x", valor=1, variacion=None, confianza="bajo")
    assert semaforo_indicador(indicador) == ROJO
SIAPE_F4_EOF_10_MARK

git add -A
git commit -m "Implement Fase 4 (tablero y alertas) of SIAPE"
git push
echo "LISTO"