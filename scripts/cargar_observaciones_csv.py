#!/usr/bin/env python
"""CLI: carga observaciones desde un CSV curado a mano (Fase 0) y, si el CSV
trae la columna opcional `seccion_ine`, las vincula a su sección electoral
(Fase 5/6 — requiere PostgreSQL/PostGIS con `secciones_electorales` ya
cargada vía scripts/cargar_secciones_electorales.py).

En SQLite (fallback de desarrollo) usa --sin-geo para omitir el paso de
vínculo geográfico, ya que esa tabla no existe en ese motor.

Uso:
    python scripts/cargar_observaciones_csv.py --csv data/observaciones.csv
    python scripts/cargar_observaciones_csv.py --csv data/observaciones.csv --sin-geo
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from siape.ingest.manual.csv_loader import CSVConnector  # noqa: E402
from siape.ingest.persist import persist_observations  # noqa: E402
from siape.storage.db import make_engine, make_session_factory  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--csv", required=True, help="Ruta al CSV de observaciones")
    parser.add_argument(
        "--sin-geo",
        action="store_true",
        help="Omite el vínculo a secciones electorales (necesario en SQLite)",
    )
    args = parser.parse_args()

    raws = CSVConnector(args.csv).fetch()
    if not raws:
        print("El CSV no contiene observaciones.")
        return

    engine = make_engine()
    session_factory = make_session_factory(engine)
    with session_factory() as session:
        observaciones = persist_observations(session, raws)
        print(f"{len(observaciones)} observaciones persistidas.")

        if args.sin_geo:
            return

        con_seccion = sum(1 for r in raws if r.seccion_ine)
        if con_seccion == 0:
            print("Ninguna fila trae seccion_ine; no hay nada que vincular.")
            return

        from siape.ingest.geo_link import vincular_a_secciones  # noqa: E402 (opcional, requiere PostGIS)

        vinculadas, no_encontradas = vincular_a_secciones(session, observaciones, raws)
        print(f"{vinculadas} observaciones vinculadas a su sección electoral.")
        if no_encontradas:
            print(
                f"Aviso: {len(no_encontradas)} clave(s) seccion_ine no encontradas en "
                f"secciones_electorales: {sorted(set(no_encontradas))}"
            )


if __name__ == "__main__":
    main()
