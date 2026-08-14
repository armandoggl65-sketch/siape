import pytest
from pydantic import ValidationError

from siape.analysis.schemas import ReporteEjecutivo

REPORTE_VALIDO = {
    "resumen_ejecutivo": ["Hallazgo 1", "Hallazgo 2"],
    "indicadores": [
        {"kpi": "seguidores_instagram", "valor": 18200, "variacion": 1.4, "confianza": "alto"}
    ],
    "analisis_por_dimension": [
        {
            "dimension": "A",
            "titulo": "Crecimiento estable",
            "contenido": "El crecimiento se mantiene por encima del promedio del periodo anterior.",
            "confianza": "medio",
            "fuentes": ["Instagram (nivel 3)"],
        }
    ],
    "alertas": [
        {
            "tipo": "oportunidad",
            "descripcion": "Vacío temático en seguridad vial",
            "accion_sugerida": "Publicar contenido sobre el tema",
            "plazo": "7 días",
            "confianza": "medio",
        }
    ],
    "recomendaciones": [
        {"texto": "Reforzar agenda de obra pública", "justificacion": "Tema con sentimiento positivo", "prioridad": 1}
    ],
    "vacios_informacion": [
        {"descripcion": "Sin dato de encuestas", "como_obtenerlo": "Encargar encuesta a casa acreditada"}
    ],
    "fecha_corte": "2026-08-07",
    "nivel_confianza_general": "medio",
}


def test_reporte_ejecutivo_valido():
    reporte = ReporteEjecutivo.model_validate(REPORTE_VALIDO)
    assert reporte.fecha_corte == "2026-08-07"
    assert reporte.indicadores[0].kpi == "seguidores_instagram"


def test_confianza_invalida_rechazada():
    data = dict(REPORTE_VALIDO)
    data["nivel_confianza_general"] = "altísimo"
    with pytest.raises(ValidationError):
        ReporteEjecutivo.model_validate(data)


def test_maximo_cinco_recomendaciones():
    data = dict(REPORTE_VALIDO)
    data["recomendaciones"] = [
        {"texto": f"Recomendación {i}", "justificacion": "j", "prioridad": 1} for i in range(6)
    ]
    with pytest.raises(ValidationError):
        ReporteEjecutivo.model_validate(data)


def test_campos_opcionales_usan_default():
    minimo = {
        "resumen_ejecutivo": ["Único hallazgo"],
        "fecha_corte": "2026-08-07",
        "nivel_confianza_general": "bajo",
    }
    reporte = ReporteEjecutivo.model_validate(minimo)
    assert reporte.indicadores == []
    assert reporte.alertas == []


def test_localidad_es_opcional_en_alertas_y_recomendaciones():
    data = dict(REPORTE_VALIDO)
    reporte_sin_localidad = ReporteEjecutivo.model_validate(data)
    assert reporte_sin_localidad.alertas[0].localidad is None
    assert reporte_sin_localidad.recomendaciones[0].localidad is None

    data_con_localidad = dict(REPORTE_VALIDO)
    data_con_localidad["alertas"] = [{**REPORTE_VALIDO["alertas"][0], "localidad": "Sección 1801"}]
    data_con_localidad["recomendaciones"] = [
        {**REPORTE_VALIDO["recomendaciones"][0], "localidad": "Sección 1800"}
    ]
    reporte = ReporteEjecutivo.model_validate(data_con_localidad)
    assert reporte.alertas[0].localidad == "Sección 1801"
    assert reporte.recomendaciones[0].localidad == "Sección 1800"
