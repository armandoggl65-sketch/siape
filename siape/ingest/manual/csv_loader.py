"""Conector de carga manual: observaciones curadas a mano en un archivo CSV.

Capa de primera clase (README.md → "Realidad de acceso a datos"): garantiza
que el sistema sea útil aunque ningún API automatizado esté disponible.

Columnas esperadas del CSV:
    actor_nombre, fuente_nombre, source_level, tipo_fuente, plataforma,
    tipo, tema, sentimiento, texto, valor_numerico, url, fecha, confianza,
    no_confirmado, seccion_ine
Las columnas vacías se interpretan como None. `no_confirmado` acepta
"true"/"false" (insensible a mayúsculas); vacío equivale a false.
`seccion_ine` es opcional (Fase 5/6, requiere PostGIS): la clave_ine de la
sección electoral donde ocurrió/aplica la observación, cuando quien captura
el dato la conoce (p. ej. una queja ubicada en una colonia concreta). Se
vincula con `siape.ingest.geo_link.vincular_a_secciones` tras persistir.
"""
from __future__ import annotations

import csv
from pathlib import Path

from siape.ingest.base import BaseConnector, RawObservation


def _clean(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip()
    return value or None


def _parse_bool(value: str | None) -> bool:
    return (value or "").strip().lower() in ("true", "1", "si", "sí")


class CSVConnector(BaseConnector):
    def __init__(self, csv_path: str | Path):
        self.csv_path = Path(csv_path)

    def fetch(self) -> list[RawObservation]:
        observations: list[RawObservation] = []
        with self.csv_path.open(newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                valor = _clean(row.get("valor_numerico"))
                observations.append(
                    RawObservation(
                        actor_nombre=_clean(row.get("actor_nombre")),
                        fuente_nombre=row["fuente_nombre"].strip(),
                        source_level=int(row["source_level"]),
                        tipo_fuente=row["tipo_fuente"].strip(),
                        plataforma=_clean(row.get("plataforma")),
                        tipo=row["tipo"].strip(),
                        tema=_clean(row.get("tema")),
                        sentimiento=_clean(row.get("sentimiento")),
                        texto=_clean(row.get("texto")),
                        valor_numerico=float(valor) if valor is not None else None,
                        url=_clean(row.get("url")),
                        fecha=row["fecha"].strip(),
                        confianza=row["confianza"].strip(),
                        no_confirmado=_parse_bool(row.get("no_confirmado")),
                        seccion_ine=_clean(row.get("seccion_ine")),
                    )
                )
        return observations
