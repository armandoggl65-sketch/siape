#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/siape
git checkout main
git pull
git checkout -b claude/fase6-historial-metricas

mkdir -p 'scripts'
cat > 'scripts/cerrar_periodo.py' <<'SIAPE_F6_EOF_1_MARK'
#!/usr/bin/env python
"""CLI: cierra un periodo — calcula indicadores, los compara contra el
último corte registrado, y los guarda como el nuevo corte oficial.

Pensado para correrse con la periodicidad semanal/quincenal del prompt de
analista (Sección 7.6), no en cada visita al tablero.

Uso:
    python scripts/cerrar_periodo.py --actor-id 1 \
        --fecha-inicio 2026-08-01 --fecha-fin 2026-08-07 --fecha-corte 2026-08-07
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from siape.metrics.historial import construir_indicadores_con_historial, registrar_corte  # noqa: E402
from siape.storage.db import make_engine, make_session_factory  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--actor-id", type=int, required=True)
    parser.add_argument("--fecha-inicio", required=True, help="YYYY-MM-DD")
    parser.add_argument("--fecha-fin", required=True, help="YYYY-MM-DD")
    parser.add_argument(
        "--fecha-corte", required=True, help="YYYY-MM-DD, fecha oficial de este corte"
    )
    args = parser.parse_args()

    engine = make_engine()
    session_factory = make_session_factory(engine)

    with session_factory() as session:
        indicadores = construir_indicadores_con_historial(
            session, args.actor_id, args.fecha_inicio, args.fecha_fin, args.fecha_corte
        )
        if not indicadores:
            print("Sin indicadores calculables para este periodo; no se registra ningún corte.")
            return

        registrar_corte(session, args.actor_id, indicadores, args.fecha_corte)

        print(f"Corte {args.fecha_corte} registrado ({len(indicadores)} indicadores):")
        for ind in indicadores:
            variacion = f"{ind.variacion:+.2f}%" if ind.variacion is not None else "sin corte previo"
            print(f"  - {ind.kpi}: {ind.valor} (variación: {variacion}, confianza: {ind.confianza})")


if __name__ == "__main__":
    main()
SIAPE_F6_EOF_1_MARK

mkdir -p 'siape/dashboard'
cat > 'siape/dashboard/app.py' <<'SIAPE_F6_EOF_2_MARK'
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
from siape.dashboard.semaforo import semaforo_indicador
from siape.metrics.historial import construir_indicadores_con_historial, registrar_corte
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


main()
SIAPE_F6_EOF_2_MARK

mkdir -p 'siape/metrics'
cat > 'siape/metrics/historial.py' <<'SIAPE_F6_EOF_3_MARK'
"""Persistencia y comparación histórica de métricas (Sección 6: "variación vs. periodo anterior").

Separado de `build_indicadores.py`: ese módulo calcula el periodo actual "en
vivo" (usado por el tablero en cada carga). Este módulo registra *cortes*
deliberados — semanales/quincenales, según la periodicidad del prompt de
analista (Sección 7.6) — y calcula la variación real contra el corte
anterior. No se registra un corte automáticamente en cada render del
tablero: eso inflaría `metricas` con duplicados sin valor.
"""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from siape.analysis.schemas import Indicador
from siape.metrics.build_indicadores import construir_indicadores
from siape.storage.models import Metrica


def valor_ultimo_corte(
    session: Session, actor_id: int, kpi: str, antes_de: str
) -> float | None:
    """Último valor registrado de `kpi` para el actor, en un corte anterior a `antes_de`."""
    stmt = (
        select(Metrica.valor)
        .where(Metrica.actor_id == actor_id, Metrica.kpi == kpi, Metrica.fecha_corte < antes_de)
        .order_by(Metrica.fecha_corte.desc())
        .limit(1)
    )
    return session.scalar(stmt)


def calcular_variacion(valor_actual: float, valor_anterior: float | None) -> float | None:
    """% de cambio contra el corte anterior. None si no hay corte previo o este era 0."""
    if valor_anterior is None or valor_anterior == 0:
        return None
    return round((valor_actual - valor_anterior) / abs(valor_anterior) * 100, 2)


def enriquecer_con_variacion(
    session: Session, actor_id: int, indicadores: list[Indicador], fecha_corte: str
) -> list[Indicador]:
    """Copia los indicadores agregando `variacion` contra el último corte registrado."""
    enriquecidos = []
    for ind in indicadores:
        anterior = valor_ultimo_corte(session, actor_id, ind.kpi, fecha_corte)
        variacion = calcular_variacion(ind.valor, anterior)
        enriquecidos.append(ind.model_copy(update={"variacion": variacion}))
    return enriquecidos


def registrar_corte(
    session: Session, actor_id: int, indicadores: list[Indicador], fecha_corte: str
) -> list[Metrica]:
    """Guarda un snapshot de los indicadores como el corte oficial de `fecha_corte`."""
    registros = []
    for ind in indicadores:
        metrica = Metrica(
            actor_id=actor_id,
            kpi=ind.kpi,
            valor=ind.valor,
            variacion=ind.variacion,
            confianza=ind.confianza,
            fecha_corte=fecha_corte,
        )
        session.add(metrica)
        registros.append(metrica)
    session.commit()
    return registros


def construir_indicadores_con_historial(
    session: Session,
    actor_id: int,
    fecha_inicio: str,
    fecha_fin: str,
    fecha_corte: str,
    tipo_seguidores: str = "seguidores",
) -> list[Indicador]:
    """Indicadores del periodo, con `variacion` real contra el último corte registrado.

    No persiste nada — es de solo lectura, apta para el tablero. Para cerrar
    un periodo y dejarlo disponible como referencia futura, llamar aparte a
    `registrar_corte` con el resultado.
    """
    indicadores = construir_indicadores(session, actor_id, fecha_inicio, fecha_fin, tipo_seguidores)
    return enriquecer_con_variacion(session, actor_id, indicadores, fecha_corte)
SIAPE_F6_EOF_3_MARK

mkdir -p 'tests'
cat > 'tests/test_metrics_historial.py' <<'SIAPE_F6_EOF_4_MARK'
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
SIAPE_F6_EOF_4_MARK

git add -A
git commit -m "Implement Fase 6.1: persistencia de metricas historicas y variacion real"
git push -u origin claude/fase6-historial-metricas
echo "LISTO"