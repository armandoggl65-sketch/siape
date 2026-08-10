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
