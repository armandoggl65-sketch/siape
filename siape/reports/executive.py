"""Genera el reporte ejecutivo en Markdown a partir de un ReporteEjecutivo."""
from __future__ import annotations

from siape.analysis.schemas import ReporteEjecutivo

DIMENSION_NOMBRES = {
    "A": "Medición de redes sociales",
    "B": "Posicionamiento comparativo",
    "C": "Sentimiento y narrativas",
    "D": "Agenda temática",
    "E": "Mapeo de actores e influencia",
    "F": "Detección temprana de crisis",
    "G": "Ventanas de oportunidad",
}


def render_markdown(reporte: ReporteEjecutivo) -> str:
    lines: list[str] = []
    lines.append("# Reporte ejecutivo SIAPE")
    lines.append("")
    lines.append(f"**Fecha de corte:** {reporte.fecha_corte}  ")
    lines.append(f"**Nivel de confianza general:** {reporte.nivel_confianza_general}")
    lines.append("")

    lines.append("## 1. Resumen ejecutivo")
    for viñeta in reporte.resumen_ejecutivo:
        lines.append(f"- {viñeta}")
    lines.append("")

    lines.append("## 2. Indicadores clave")
    if reporte.indicadores:
        lines.append("| KPI | Valor | Variación | Confianza |")
        lines.append("|---|---|---|---|")
        for ind in reporte.indicadores:
            lines.append(f"| {ind.kpi} | {ind.valor} | {ind.variacion} | {ind.confianza} |")
    else:
        lines.append("_Sin indicadores reportados en este periodo._")
    lines.append("")

    lines.append("## 3. Análisis por dimensión")
    if reporte.analisis_por_dimension:
        for d in reporte.analisis_por_dimension:
            nombre = DIMENSION_NOMBRES.get(d.dimension, d.dimension)
            lines.append(f"### {d.dimension}. {nombre} — {d.titulo}")
            lines.append(f"{d.contenido}")
            lines.append(f"*Confianza: {d.confianza}*")
            if d.fuentes:
                lines.append(f"Fuentes: {', '.join(d.fuentes)}")
            lines.append("")
    else:
        lines.append("_Sin novedades relevantes en este periodo._")
        lines.append("")

    lines.append("## 4. Alertas")
    if reporte.alertas:
        for a in reporte.alertas:
            lines.append(f"- **[{a.tipo.upper()}]** {a.descripcion}")
            lines.append(f"  - Acción sugerida: {a.accion_sugerida} (plazo: {a.plazo})")
            lines.append(f"  - Confianza: {a.confianza}")
    else:
        lines.append("_Sin alertas activas._")
    lines.append("")

    lines.append("## 5. Recomendaciones priorizadas")
    if reporte.recomendaciones:
        for r in sorted(reporte.recomendaciones, key=lambda x: x.prioridad):
            lines.append(f"{r.prioridad}. {r.texto}")
            lines.append(f"   - Justificación: {r.justificacion}")
    else:
        lines.append("_Sin recomendaciones en este periodo._")
    lines.append("")

    lines.append("## 6. Vacíos de información")
    if reporte.vacios_informacion:
        for v in reporte.vacios_informacion:
            lines.append(f"- {v.descripcion} — cómo obtenerlo: {v.como_obtenerlo}")
    else:
        lines.append("_Sin vacíos de información identificados._")
    lines.append("")

    return "\n".join(lines)
