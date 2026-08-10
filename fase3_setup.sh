#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/siape

mkdir -p 'siape/ingest/manual'
cat > 'siape/ingest/manual/csv_loader.py' <<'SIAPE_F3_EOF_1_MARK'
"""Conector de carga manual: observaciones curadas a mano en un archivo CSV.

Capa de primera clase (README.md → "Realidad de acceso a datos"): garantiza
que el sistema sea útil aunque ningún API automatizado esté disponible.

Columnas esperadas del CSV:
    actor_nombre, fuente_nombre, source_level, tipo_fuente, plataforma,
    tipo, tema, sentimiento, texto, valor_numerico, url, fecha, confianza,
    no_confirmado
Las columnas vacías se interpretan como None. `no_confirmado` acepta
"true"/"false" (insensible a mayúsculas); vacío equivale a false.
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
                    )
                )
        return observations
SIAPE_F3_EOF_1_MARK

mkdir -p 'siape/ingest'
cat > 'siape/ingest/meta.py' <<'SIAPE_F3_EOF_2_MARK'
"""Conector de Meta (Facebook/Instagram): páginas PROPIAS del proyecto vía Graph API.

Solo páginas propias — nunca observación de terceros (README →
"Realidad de acceso a datos"). Para adversarios/terceros, la única fuente
lícita es la observación pública manual (capa `ingest/manual/`).

# TODO(verificar-ToS): revisar los Términos de Servicio y la Política de Datos
de Meta Graph API antes de operar este conector en producción.
"""
from __future__ import annotations

import datetime as dt

import requests

from config.settings import settings
from siape.ingest.base import BaseConnector, RawObservation

GRAPH_API_BASE = "https://graph.facebook.com/v19.0"


class MetaConnector(BaseConnector):
    def __init__(
        self,
        page_id: str,
        actor_nombre: str | None = None,
        access_token: str | None = None,
        session=None,
    ):
        self.page_id = page_id
        self.actor_nombre = actor_nombre
        self.access_token = access_token or settings.meta_access_token
        self._session = session or requests

        if not self.access_token:
            raise RuntimeError(
                "META_ACCESS_TOKEN no configurado. Copia .env.example a .env y agrega tu token."
            )

    def fetch(self) -> list[RawObservation]:
        response = self._session.get(
            f"{GRAPH_API_BASE}/{self.page_id}",
            params={"fields": "fan_count", "access_token": self.access_token},
        )
        response.raise_for_status()
        data = response.json()

        if "fan_count" not in data:
            return []

        return [
            RawObservation(
                actor_nombre=self.actor_nombre,
                fuente_nombre=f"Facebook (página propia) — {self.page_id}",
                source_level=3,
                tipo_fuente="redes",
                plataforma="Facebook",
                tipo="seguidores_facebook",
                fecha=dt.date.today().isoformat(),
                confianza="alto",
                valor_numerico=float(data["fan_count"]),
            )
        ]
SIAPE_F3_EOF_2_MARK

mkdir -p 'siape/ingest'
cat > 'siape/ingest/persist.py' <<'SIAPE_F3_EOF_3_MARK'
"""Persistencia de observaciones crudas: común a todos los conectores
(manual y automatizados), no solo a la carga manual CSV.
"""
from __future__ import annotations

from sqlalchemy.orm import Session

from siape.ingest.base import RawObservation
from siape.storage.models import Actor, Fuente, Observacion


def _get_or_create_actor(session: Session, nombre: str) -> Actor:
    actor = session.query(Actor).filter_by(nombre=nombre).one_or_none()
    if actor is None:
        actor = Actor(nombre=nombre)
        session.add(actor)
        session.flush()
    return actor


def _get_or_create_fuente(
    session: Session, nombre: str, source_level: int, tipo: str, plataforma: str | None
) -> Fuente:
    fuente = session.query(Fuente).filter_by(nombre=nombre).one_or_none()
    if fuente is None:
        fuente = Fuente(
            nombre=nombre, source_level=source_level, tipo=tipo, plataforma=plataforma
        )
        session.add(fuente)
        session.flush()
    return fuente


def persist_observations(session: Session, observations: list[RawObservation]) -> list[Observacion]:
    """Inserta observaciones crudas en la base, creando actor/fuente si hacen falta."""
    persisted: list[Observacion] = []
    for raw in observations:
        actor = _get_or_create_actor(session, raw.actor_nombre) if raw.actor_nombre else None
        fuente = _get_or_create_fuente(
            session, raw.fuente_nombre, raw.source_level, raw.tipo_fuente, raw.plataforma
        )
        observacion = Observacion(
            actor=actor,
            fuente=fuente,
            tipo=raw.tipo,
            tema=raw.tema,
            sentimiento=raw.sentimiento,
            texto=raw.texto,
            valor_numerico=raw.valor_numerico,
            url=raw.url,
            fecha=raw.fecha,
            confianza=raw.confianza,
            no_confirmado=raw.no_confirmado,
        )
        session.add(observacion)
        persisted.append(observacion)
    session.commit()
    return persisted
SIAPE_F3_EOF_3_MARK

mkdir -p 'siape/ingest'
cat > 'siape/ingest/rss.py' <<'SIAPE_F3_EOF_4_MARK'
"""Conector de medios: RSS de prensa local/regional (Sección 4, Nivel 2)."""
from __future__ import annotations

import datetime as dt

import feedparser

from siape.ingest.base import BaseConnector, RawObservation


class RSSConnector(BaseConnector):
    def __init__(self, feed_urls: list[str], actor_nombre: str | None = None):
        self.feed_urls = feed_urls
        self.actor_nombre = actor_nombre

    def fetch(self) -> list[RawObservation]:
        observations: list[RawObservation] = []
        for url in self.feed_urls:
            parsed = feedparser.parse(url)
            fuente_nombre = parsed.feed.get("title") or url
            for entry in parsed.entries:
                observations.append(
                    RawObservation(
                        actor_nombre=self.actor_nombre,
                        fuente_nombre=fuente_nombre,
                        source_level=2,
                        tipo_fuente="medios",
                        tipo="nota_prensa",
                        fecha=self._fecha_de_entrada(entry),
                        confianza="medio",
                        texto=entry.get("title"),
                        url=entry.get("link"),
                    )
                )
        return observations

    @staticmethod
    def _fecha_de_entrada(entry) -> str:
        publicado = entry.get("published_parsed") or entry.get("updated_parsed")
        if publicado:
            return dt.date(*publicado[:3]).isoformat()
        return dt.date.today().isoformat()
SIAPE_F3_EOF_4_MARK

mkdir -p 'siape/ingest'
cat > 'siape/ingest/youtube.py' <<'SIAPE_F3_EOF_5_MARK'
"""Conector de YouTube: estadísticas públicas de un canal (Data API v3).

# TODO(verificar-ToS): revisar los Términos de Servicio y la Política de Datos
de la YouTube Data API antes de operar este conector en producción.
"""
from __future__ import annotations

import datetime as dt

from googleapiclient.discovery import build

from config.settings import settings
from siape.ingest.base import BaseConnector, RawObservation


class YouTubeConnector(BaseConnector):
    def __init__(
        self,
        channel_id: str,
        actor_nombre: str | None = None,
        api_key: str | None = None,
        client=None,
    ):
        self.channel_id = channel_id
        self.actor_nombre = actor_nombre
        self.api_key = api_key or settings.youtube_api_key
        self._client = client

    def _build_client(self):
        if self._client is not None:
            return self._client
        if not self.api_key:
            raise RuntimeError(
                "YOUTUBE_API_KEY no configurada. Copia .env.example a .env y agrega tu API key."
            )
        return build("youtube", "v3", developerKey=self.api_key)

    def fetch(self) -> list[RawObservation]:
        youtube = self._build_client()
        response = youtube.channels().list(part="statistics", id=self.channel_id).execute()
        items = response.get("items", [])
        if not items:
            return []

        stats = items[0]["statistics"]
        fecha = dt.date.today().isoformat()
        fuente_nombre = f"YouTube — canal {self.channel_id}"
        observations: list[RawObservation] = []

        if "subscriberCount" in stats:
            observations.append(
                RawObservation(
                    actor_nombre=self.actor_nombre,
                    fuente_nombre=fuente_nombre,
                    source_level=3,
                    tipo_fuente="redes",
                    plataforma="YouTube",
                    tipo="seguidores_youtube",
                    fecha=fecha,
                    confianza="alto",
                    valor_numerico=float(stats["subscriberCount"]),
                )
            )
        if "viewCount" in stats:
            observations.append(
                RawObservation(
                    actor_nombre=self.actor_nombre,
                    fuente_nombre=fuente_nombre,
                    source_level=3,
                    tipo_fuente="redes",
                    plataforma="YouTube",
                    tipo="vistas_totales_youtube",
                    fecha=fecha,
                    confianza="alto",
                    valor_numerico=float(stats["viewCount"]),
                )
            )
        return observations
SIAPE_F3_EOF_5_MARK

mkdir -p 'tests'
cat > 'tests/test_ingest_manual.py' <<'SIAPE_F3_EOF_6_MARK'
from siape.ingest.base import RawObservation
from siape.ingest.manual.csv_loader import CSVConnector
from siape.ingest.persist import persist_observations
from siape.storage.models import Observacion

CSV_HEADER = (
    "actor_nombre,fuente_nombre,source_level,tipo_fuente,plataforma,tipo,tema,"
    "sentimiento,texto,valor_numerico,url,fecha,confianza,no_confirmado\n"
)


def test_csv_connector_parsea_filas(tmp_path):
    csv_path = tmp_path / "observaciones.csv"
    csv_path.write_text(
        CSV_HEADER
        + "Tonanzin Fernández,Boletín Ayuntamiento SPC,1,oficial,,mencion,obra pública,"
        "positivo,Inauguración de calle,,,2026-08-03,alto,false\n"
        + "Tonanzin Fernández,Cuenta X @ejemplo,4,no_verificado,X,mencion,agua,negativo,"
        "Trascendido sin confirmar,,,2026-08-06,bajo,\n",
        encoding="utf-8",
    )

    observations = CSVConnector(csv_path).fetch()

    assert len(observations) == 2
    assert all(isinstance(o, RawObservation) for o in observations)
    assert observations[0].source_level == 1
    assert observations[0].no_confirmado is False
    # Nivel 4 se marca como no confirmado aunque el CSV lo deje vacío.
    assert observations[1].source_level == 4
    assert observations[1].no_confirmado is True


def test_persist_observations_crea_actor_y_fuente(db_session, tmp_path):
    csv_path = tmp_path / "observaciones.csv"
    csv_path.write_text(
        CSV_HEADER
        + "Tonanzin Fernández,Boletín Ayuntamiento SPC,1,oficial,,mencion,obra pública,"
        "positivo,Inauguración de calle,,,2026-08-03,alto,false\n",
        encoding="utf-8",
    )

    observations = CSVConnector(csv_path).fetch()
    persist_observations(db_session, observations)

    guardadas = db_session.query(Observacion).all()
    assert len(guardadas) == 1
    assert guardadas[0].actor.nombre == "Tonanzin Fernández"
    assert guardadas[0].fuente.nombre == "Boletín Ayuntamiento SPC"
    assert guardadas[0].fuente.source_level == 1
SIAPE_F3_EOF_6_MARK

mkdir -p 'tests'
cat > 'tests/test_ingest_meta.py' <<'SIAPE_F3_EOF_7_MARK'
import dataclasses

import pytest

from siape.ingest import meta as meta_module
from siape.ingest.meta import MetaConnector


class FakeResponse:
    def __init__(self, json_data, status_code=200):
        self._json_data = json_data
        self.status_code = status_code

    def raise_for_status(self):
        if self.status_code >= 400:
            raise RuntimeError(f"HTTP {self.status_code}")

    def json(self):
        return self._json_data


class FakeSession:
    def __init__(self, json_data):
        self._json_data = json_data
        self.last_call: tuple | None = None

    def get(self, url, params=None):
        self.last_call = (url, params)
        return FakeResponse(self._json_data)


def test_meta_connector_parsea_fan_count():
    session = FakeSession({"fan_count": 5400})
    connector = MetaConnector(
        page_id="123456", actor_nombre="Tonanzin Fernández", access_token="fake-token", session=session
    )

    observations = connector.fetch()

    assert len(observations) == 1
    obs = observations[0]
    assert obs.valor_numerico == 5400.0
    assert obs.tipo == "seguidores_facebook"
    assert obs.source_level == 3
    assert obs.confianza == "alto"
    assert session.last_call[1]["access_token"] == "fake-token"
    assert "123456" in session.last_call[0]


def test_meta_connector_sin_fan_count_devuelve_vacio():
    session = FakeSession({})
    connector = MetaConnector(page_id="123456", access_token="fake-token", session=session)

    assert connector.fetch() == []


def test_meta_connector_requiere_access_token(monkeypatch):
    sin_token = dataclasses.replace(meta_module.settings, meta_access_token=None)
    monkeypatch.setattr(meta_module, "settings", sin_token)

    with pytest.raises(RuntimeError):
        MetaConnector(page_id="123456")
SIAPE_F3_EOF_7_MARK

mkdir -p 'tests'
cat > 'tests/test_ingest_rss.py' <<'SIAPE_F3_EOF_8_MARK'
from siape.ingest.rss import RSSConnector

RSS_XML = """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
<channel>
<title>Medio Local Ejemplo</title>
<item>
  <title>Nota sobre obra pública en el centro</title>
  <link>https://medio.example/obra-publica</link>
  <pubDate>Mon, 03 Aug 2026 10:00:00 GMT</pubDate>
</item>
<item>
  <title>Quejas por alumbrado público</title>
  <link>https://medio.example/alumbrado</link>
  <pubDate>Wed, 05 Aug 2026 08:30:00 GMT</pubDate>
</item>
</channel>
</rss>
"""


def test_rss_connector_parsea_entradas():
    connector = RSSConnector(feed_urls=[RSS_XML], actor_nombre="Tonanzin Fernández")

    observations = connector.fetch()

    assert len(observations) == 2
    obs = observations[0]
    assert obs.source_level == 2
    assert obs.tipo_fuente == "medios"
    assert obs.confianza == "medio"
    assert obs.fuente_nombre == "Medio Local Ejemplo"
    assert obs.texto == "Nota sobre obra pública en el centro"
    assert obs.url == "https://medio.example/obra-publica"
    assert obs.fecha == "2026-08-03"
    assert obs.actor_nombre == "Tonanzin Fernández"


def test_rss_connector_feed_vacio_no_falla():
    feed_vacio = '<?xml version="1.0"?><rss version="2.0"><channel><title>Vacío</title></channel></rss>'
    connector = RSSConnector(feed_urls=[feed_vacio])

    assert connector.fetch() == []
SIAPE_F3_EOF_8_MARK

mkdir -p 'tests'
cat > 'tests/test_ingest_youtube.py' <<'SIAPE_F3_EOF_9_MARK'
import dataclasses

import pytest

from siape.ingest import youtube as youtube_module
from siape.ingest.youtube import YouTubeConnector


class FakeYouTubeClient:
    """Simula la cadena channels().list(...).execute() del SDK de Google."""

    def __init__(self, response):
        self._response = response

    def channels(self):
        return self

    def list(self, **kwargs):
        return self

    def execute(self):
        return self._response


def test_youtube_connector_parsea_estadisticas():
    client = FakeYouTubeClient(
        {"items": [{"statistics": {"subscriberCount": "18200", "viewCount": "500000"}}]}
    )
    connector = YouTubeConnector(channel_id="UCxxxx", actor_nombre="Tonanzin Fernández", client=client)

    observations = connector.fetch()

    assert len(observations) == 2
    seguidores = next(o for o in observations if o.tipo == "seguidores_youtube")
    assert seguidores.valor_numerico == 18200.0
    assert seguidores.source_level == 3
    assert seguidores.confianza == "alto"
    assert seguidores.actor_nombre == "Tonanzin Fernández"

    vistas = next(o for o in observations if o.tipo == "vistas_totales_youtube")
    assert vistas.valor_numerico == 500000.0


def test_youtube_connector_sin_items_devuelve_vacio():
    client = FakeYouTubeClient({"items": []})
    connector = YouTubeConnector(channel_id="UCxxxx", client=client)

    assert connector.fetch() == []


def test_youtube_connector_requiere_api_key_sin_cliente(monkeypatch):
    sin_api_key = dataclasses.replace(youtube_module.settings, youtube_api_key=None)
    monkeypatch.setattr(youtube_module, "settings", sin_api_key)

    connector = YouTubeConnector(channel_id="UCxxxx")

    with pytest.raises(RuntimeError):
        connector.fetch()
SIAPE_F3_EOF_9_MARK

git add -A
git commit -m "Implement Fase 3 (ingesta automatizada) of SIAPE"
git push
echo "LISTO"