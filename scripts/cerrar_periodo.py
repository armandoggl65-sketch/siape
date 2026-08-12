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
