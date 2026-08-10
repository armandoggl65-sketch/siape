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
