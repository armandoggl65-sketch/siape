"""Tablero de indicadores SIAPE (Streamlit).

Uso: streamlit run siape/dashboard/app.py
"""
from __future__ import annotations

import datetime as dt
import sys
from pathlib import Path

import streamlit as st

# `streamlit run` no agrega la raíz del repo a sys.path (a diferencia de
# `python -m` o de pytest), así que los imports de `siape.*` fallarían sin esto.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from siape.alerts.crisis import detectar_crisis
from siape.alerts.opportunity import detectar_oceanos_azules
from siape.dashboard.mapa import resumen_por_seccion
from siape.dashboard.semaforo import semaforo_indicador
from siape.metrics.historial import construir_indicadores_con_historial, registrar_corte
from siape.metrics.transparencia import resumen_fuentes, resumen_temas
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
        indicadores = construir_indicadores_con_historial(
            session, actor_id, fecha_inicio_str, fecha_fin_str, fecha_corte=fecha_fin_str
        )
        if indicadores:
            filas = [
                {
                    "KPI": i.kpi,
                    "Valor": i.valor,
                    "Variación": f"{i.variacion:+.2f}%" if i.variacion is not None else "—",
                    "Confianza": i.confianza,
                    "Semáforo": semaforo_indicador(i),
                }
                for i in indicadores
            ]
            st.table(filas)

            if st.button("Registrar este corte", help="Guarda estos valores para poder comparar futuros periodos contra hoy."):
                registrar_corte(session, actor_id, indicadores, fecha_fin_str)
                st.success(f"Corte {fecha_fin_str} registrado. Los próximos periodos mostrarán variación contra este.")
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

        st.subheader("Agenda temática")
        temas = resumen_temas(session, actor_id, fecha_inicio_str, fecha_fin_str)
        if temas:
            filas_temas = [
                {
                    "Tema": t.tema,
                    "Menciones totales": t.total_observaciones,
                    "Menciones del actor": t.observaciones_actor,
                    "Quién domina": t.actor_dominante or "—",
                    "Saldo de opinión del actor": (
                        f"{t.saldo_opinion_actor:+.1f}%"
                        if t.saldo_opinion_actor is not None
                        else "sin sentimiento etiquetado"
                    ),
                }
                for t in temas
            ]
            st.table(filas_temas)
        else:
            st.info("Sin temas registrados en el periodo.")

        st.subheader("Fuentes de la información")
        st.caption(
            "Jerarquía de verificabilidad (CLAUDE.md, Sección 4): Nivel 1 = oficial, "
            "2 = medios, 3 = redes, 4 = no verificado."
        )
        fuentes = resumen_fuentes(session, actor_id, fecha_inicio_str, fecha_fin_str)
        if fuentes:
            filas_fuentes = [
                {
                    "Fuente": f.fuente,
                    "Nivel de verificabilidad": f.nivel_etiqueta,
                    "Tipo": f.tipo,
                    "Observaciones": f.num_observaciones,
                }
                for f in fuentes
            ]
            st.table(filas_fuentes)
        else:
            st.info("Sin fuentes registradas en el periodo.")

        # secciones_electorales/observacion_seccion (Fase 5/6, opcional) solo existen
        # en PostgreSQL/PostGIS — el fallback de desarrollo (SQLite) no tiene esta capa.
        if engine.dialect.name != "sqlite":
            st.subheader("Mapa de posicionamiento por localidad")
            resumen = resumen_por_seccion(session, actor_id, fecha_inicio_str, fecha_fin_str)
            if resumen:
                filas_mapa = [
                    {
                        "Sección (INE)": r.clave_ine,
                        "Nombre": r.nombre or "—",
                        "Notoriedad": r.notoriedad,
                        "Saldo de opinión": (
                            f"{r.saldo_opinion:+.1f}%"
                            if r.saldo_opinion is not None
                            else "sin sentimiento etiquetado"
                        ),
                    }
                    for r in resumen
                ]
                st.table(filas_mapa)
            else:
                st.info(
                    "Sin observaciones vinculadas a una sección electoral en este periodo "
                    "(carga el CSV con la columna seccion_ine para poblar este mapa)."
                )


main()
