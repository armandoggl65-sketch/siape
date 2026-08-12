#!/usr/bin/env python
"""CLI: extrae las secciones electorales de un municipio desde un shapefile
del Marco Geográfico Electoral (INE) y las exporta a GeoJSON en WGS84.

Documenta cómo se generó data/secciones_san_pedro_cholula.geojson, y sirve
para agregar otros municipios más adelante.

Requiere `pyshp` y `pyproj` (solo para esta herramienta de extracción, no
para el resto de la aplicación — no están en requirements.txt por defecto).

IMPORTANTE — el campo MUNICIPIO de estos shapefiles usa la clave IFE/INE,
NO la clave INEGI (suelen diferir). Verifica la clave IFE correcta cruzando
por número de sección contra un catálogo confiable (p. ej.
equivSecc/tablaEquivalenciasSeccionalesDesde1994.csv del repositorio
github.com/emagar/mxDistritos) antes de asumir que un número de municipio
coincide con el que esperas — un municipio con muy pocas secciones respecto
a lo esperado es señal de que el código no es el correcto.

Uso:
    python scripts/extraer_secciones_shapefile.py \
        --shapefile SECCION.shp \
        --municipio-ife 141 \
        --municipio-nombre "San Pedro Cholula" \
        --entidad-clave 21 \
        --entidad-nombre Puebla \
        --crs-origen EPSG:32614 \
        --fuente "https://github.com/emagar/mxDistritos/..." \
        --output data/secciones_san_pedro_cholula.geojson
"""
from __future__ import annotations

import argparse
import datetime as dt
import json


def _reproyectar_anillo(anillo, transformer):
    return [list(transformer.transform(x, y)) for x, y in anillo]


def _geometria_a_multipolygon(shape, transformer):
    """A partir de `shape.__geo_interface__` (que ya respeta la orientación
    OGC de anillos), produce coordenadas GeoJSON tipo MultiPolygon en WGS84."""
    gi = shape.__geo_interface__
    if gi["type"] == "Polygon":
        poligonos = [gi["coordinates"]]
    elif gi["type"] == "MultiPolygon":
        poligonos = gi["coordinates"]
    else:
        raise ValueError(f"Tipo de geometría no soportado: {gi['type']}")
    return [
        [_reproyectar_anillo(anillo, transformer) for anillo in poligono] for poligono in poligonos
    ]


def extraer(
    shapefile_path: str,
    municipio_ife: int,
    municipio_nombre: str,
    entidad_clave: int,
    entidad_nombre: str,
    crs_origen: str,
    fuente: str,
) -> dict:
    import shapefile
    from pyproj import Transformer

    transformer = Transformer.from_crs(crs_origen, "EPSG:4326", always_xy=True)
    sf = shapefile.Reader(shapefile_path)

    features = []
    for r in sf.iterShapeRecords():
        if r.record["MUNICIPIO"] != municipio_ife:
            continue
        seccion = r.record["SECCION"]
        coords_mp = _geometria_a_multipolygon(r.shape, transformer)
        features.append(
            {
                "type": "Feature",
                "properties": {
                    "clave_ine": f"{entidad_clave}{seccion:04d}",
                    "seccion": seccion,
                    "municipio": municipio_nombre,
                    "entidad": entidad_nombre,
                },
                "geometry": {"type": "MultiPolygon", "coordinates": coords_mp},
            }
        )
    features.sort(key=lambda f: f["properties"]["seccion"])

    return {
        "type": "FeatureCollection",
        "metadata": {
            "_nota": (
                f"Secciones electorales de {municipio_nombre}, {entidad_nombre} "
                f"(municipio IFE {entidad_clave}{municipio_ife}). Cartografía pública del INE "
                "(Marco Geográfico Electoral), reproyectada a WGS84 (EPSG:4326)."
            ),
            "fuente": fuente,
            "generado": dt.date.today().isoformat(),
        },
        "features": features,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--shapefile", required=True, help="Ruta al archivo .shp")
    parser.add_argument("--municipio-ife", type=int, required=True, help="Clave IFE/INE del municipio (campo MUNICIPIO del shapefile)")
    parser.add_argument("--municipio-nombre", required=True)
    parser.add_argument("--entidad-clave", type=int, required=True, help="Clave de entidad (p. ej. 21 = Puebla)")
    parser.add_argument("--entidad-nombre", required=True)
    parser.add_argument("--crs-origen", default="EPSG:32614", help="CRS del shapefile origen (ver su .prj)")
    parser.add_argument("--fuente", required=True, help="URL o referencia de dónde salió el shapefile")
    parser.add_argument("--output", required=True, help="Ruta del GeoJSON de salida")
    args = parser.parse_args()

    geojson = extraer(
        args.shapefile,
        args.municipio_ife,
        args.municipio_nombre,
        args.entidad_clave,
        args.entidad_nombre,
        args.crs_origen,
        args.fuente,
    )

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(geojson, f, ensure_ascii=False, indent=2)

    print(f"{len(geojson['features'])} secciones exportadas a {args.output}")


if __name__ == "__main__":
    main()
