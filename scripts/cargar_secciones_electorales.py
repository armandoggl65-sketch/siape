#!/usr/bin/env python
"""CLI: carga secciones electorales desde un GeoJSON a `secciones_electorales`.

Solo funciona contra PostgreSQL/PostGIS (Fase 5, opcional) — en SQLite
(fallback de desarrollo) no existe esta tabla.

Espera geometrías GeoJSON tipo Polygon o MultiPolygon con anillos ya
correctamente orientados (regla de la mano derecha OGC: exterior CCW,
huecos CW) y en WGS84 (SRID 4326) — como las que produce
`shapefile.Shape.__geo_interface__` de pyshp, que sí respeta esa regla.

Uso:
    python scripts/cargar_secciones_electorales.py \
        --geojson data/secciones_san_pedro_cholula.geojson
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from geoalchemy2.elements import WKTElement  # noqa: E402

from siape.storage.db import make_engine, make_session_factory  # noqa: E402
from siape.storage.geo_models import SeccionElectoral  # noqa: E402


def _anillo_a_wkt(anillo: list) -> str:
    puntos = ", ".join(f"{lon} {lat}" for lon, lat in anillo)
    return f"({puntos})"


def geometria_a_multipolygon_wkt(geometry: dict) -> str:
    """Convierte una geometría GeoJSON (Polygon o MultiPolygon) a WKT MULTIPOLYGON,
    para que coincida con el tipo de columna declarado en SeccionElectoral.geom."""
    if geometry["type"] == "Polygon":
        poligonos = [geometry["coordinates"]]
    elif geometry["type"] == "MultiPolygon":
        poligonos = geometry["coordinates"]
    else:
        raise ValueError(f"Tipo de geometría no soportado: {geometry['type']}")

    poligonos_wkt = [
        f"({', '.join(_anillo_a_wkt(anillo) for anillo in poligono)})" for poligono in poligonos
    ]
    return f"MULTIPOLYGON({', '.join(poligonos_wkt)})"


def cargar_geojson(session, geojson: dict) -> tuple[int, int]:
    """Inserta o actualiza secciones desde un GeoJSON. Devuelve (creadas, actualizadas)."""
    creadas = actualizadas = 0
    for feature in geojson["features"]:
        props = feature["properties"]
        wkt = geometria_a_multipolygon_wkt(feature["geometry"])

        seccion = (
            session.query(SeccionElectoral).filter_by(clave_ine=props["clave_ine"]).one_or_none()
        )
        if seccion is None:
            seccion = SeccionElectoral(clave_ine=props["clave_ine"])
            session.add(seccion)
            creadas += 1
        else:
            actualizadas += 1
        seccion.nombre = f"Sección {props['seccion']}"
        seccion.municipio = props["municipio"]
        seccion.geom = WKTElement(wkt, srid=4326)

    session.commit()
    return creadas, actualizadas


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--geojson", required=True, help="Ruta al archivo GeoJSON de secciones")
    args = parser.parse_args()

    with open(args.geojson, encoding="utf-8") as f:
        geojson = json.load(f)

    engine = make_engine()
    session_factory = make_session_factory(engine)
    with session_factory() as session:
        creadas, actualizadas = cargar_geojson(session, geojson)

    print(f"{creadas} secciones creadas, {actualizadas} actualizadas.")


if __name__ == "__main__":
    main()
