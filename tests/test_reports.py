from siape.analysis.schemas import ReporteEjecutivo
from siape.reports.executive import render_markdown

REPORTE = ReporteEjecutivo.model_validate(
    {
        "resumen_ejecutivo": ["Punto uno", "Punto dos"],
        "indicadores": [{"kpi": "seguidores_instagram", "valor": 100, "variacion": 1.0, "confianza": "alto"}],
        "analisis_por_dimension": [
            {
                "dimension": "D",
                "titulo": "Agenda temática",
                "contenido": "Detalle del hallazgo.",
                "confianza": "medio",
                "fuentes": ["Boletín oficial"],
            }
        ],
        "alertas": [
            {
                "tipo": "crisis",
                "descripcion": "Tema escalando",
                "accion_sugerida": "Responder públicamente",
                "plazo": "48 horas",
                "confianza": "medio",
            }
        ],
        "recomendaciones": [{"texto": "Actuar ya", "justificacion": "Riesgo alto", "prioridad": 1}],
        "vacios_informacion": [{"descripcion": "Falta encuesta", "como_obtenerlo": "Contratar casa encuestadora"}],
        "fecha_corte": "2026-08-07",
        "nivel_confianza_general": "medio",
    }
)


def test_render_markdown_incluye_todas_las_secciones():
    md = render_markdown(REPORTE)
    assert "## 1. Resumen ejecutivo" in md
    assert "## 2. Indicadores clave" in md
    assert "## 3. Análisis por dimensión" in md
    assert "## 4. Alertas" in md
    assert "## 5. Recomendaciones priorizadas" in md
    assert "## 6. Vacíos de información" in md
    assert "seguidores_instagram" in md
    assert "[CRISIS]" in md
