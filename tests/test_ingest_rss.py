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
