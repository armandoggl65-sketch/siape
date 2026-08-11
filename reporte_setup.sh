#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/siape
git checkout main
git pull
git checkout -b claude/add-reporte-ejemplo

cat > '.gitignore' <<'SIAPE_REP_EOF_1_MARK'
.venv/
__pycache__/
*.pyc
.env
siape_dev.db
data/*.json
!data/periodo_ejemplo.json
!data/reporte_ejemplo.json
.streamlit/secrets.toml
SIAPE_REP_EOF_1_MARK

mkdir -p 'data'
cat > 'data/reporte_ejemplo.json' <<'SIAPE_REP_EOF_2_MARK'
{
  "resumen_ejecutivo": [
    "El crecimiento de seguidores en Instagram se mantiene positivo (+5.8%) en el periodo, con Tonanzin Fernández concentrando dos tercios del share of voice frente al entorno competitivo.",
    "El saldo de opinión es negativo (-50%), impulsado por menciones sobre el servicio de agua en una colonia — activa una alerta de crisis.",
    "El tema 'seguridad' está siendo dominado por el adversario principal sin que el actor tenga presencia propia — es una ventana de oportunidad clara.",
    "La obra pública sigue siendo el tema con mejor sentimiento y el más citado en fuentes oficiales (Nivel 1).",
    "El único dato de Nivel 4 del periodo (corte de agua) no está triangulado con ninguna fuente de Nivel 1-3; se mantiene marcado como no confirmado.",
    "No hay datos de encuestas ni de listado nominal disponibles para este corte."
  ],
  "indicadores": [
    { "kpi": "crecimiento_seguidores", "valor": 5.81, "variacion": null, "confianza": "medio" },
    { "kpi": "share_of_voice_pct", "valor": 66.67, "variacion": null, "confianza": "medio" },
    { "kpi": "saldo_opinion", "valor": -50.0, "variacion": null, "confianza": "medio" }
  ],
  "analisis_por_dimension": [
    {
      "dimension": "A",
      "titulo": "Crecimiento estable en Instagram",
      "contenido": "Los seguidores crecieron de 17,200 a 18,200 en la semana (+5.8%), con un pico de interacción asociado a la publicación sobre la rehabilitación de calle en el centro histórico.",
      "confianza": "medio",
      "fuentes": ["Instagram propio (Nivel 3)"]
    },
    {
      "dimension": "C",
      "titulo": "Narrativa negativa concentrada en el tema agua",
      "contenido": "Tres menciones negativas sobre un corte de agua en una colonia dominan el saldo de opinión del periodo. Una de las tres es Nivel 4 (no confirmada); las otras dos son Nivel 3 (redes propias/públicas) y sí se triangulan entre sí, pero ninguna coincide con una fuente Nivel 1 o 2.",
      "confianza": "medio",
      "fuentes": ["Cuenta X @ejemplo (Nivel 4, no confirmado)", "Página Facebook local (Nivel 3)"]
    },
    {
      "dimension": "D",
      "titulo": "Vacío temático en seguridad",
      "contenido": "El adversario de referencia concentra la conversación sobre seguridad (alumbrado y patrullajes) sin que el actor principal tenga presencia registrada en ese tema durante el periodo.",
      "confianza": "medio",
      "fuentes": ["Medio Local Ejemplo (Nivel 2)"]
    }
  ],
  "alertas": [
    {
      "tipo": "crisis",
      "descripcion": "Saldo de opinión negativo (-50.0%) en el periodo, concentrado en el tema agua.",
      "accion_sugerida": "Emitir un comunicado oficial (Nivel 1) sobre el estado del suministro y triangular con la fuente Nivel 4 antes de responder públicamente.",
      "plazo": "48 horas",
      "confianza": "medio"
    },
    {
      "tipo": "oportunidad",
      "descripcion": "El tema 'seguridad' es dominado por el adversario de referencia; el actor principal no tiene presencia en él.",
      "accion_sugerida": "Evaluar generar agenda o contenido propio sobre seguridad, apoyado en datos oficiales si existen.",
      "plazo": "15 días",
      "confianza": "medio"
    }
  ],
  "recomendaciones": [
    {
      "texto": "Triangular la queja sobre el corte de agua con una fuente oficial antes de emitir cualquier respuesta pública.",
      "justificacion": "La única fuente disponible es Nivel 4 (no confirmada); responder sin triangulación arriesga validar un hecho no verificado.",
      "prioridad": 1
    },
    {
      "texto": "Explorar una pieza de comunicación propia sobre seguridad en la próxima semana.",
      "justificacion": "Es un tema con alta actividad del adversario y sin presencia propia — vacío temático de bajo costo de entrada.",
      "prioridad": 2
    },
    {
      "texto": "Mantener el ritmo de publicaciones sobre obra pública.",
      "justificacion": "Es el tema con mejor sentimiento y la única fuente Nivel 1 activa del periodo.",
      "prioridad": 3
    }
  ],
  "vacios_informacion": [
    {
      "descripcion": "No hay dato de encuestas de posicionamiento para este corte.",
      "como_obtenerlo": "Encargar levantamiento a una casa encuestadora acreditada ante el INE."
    },
    {
      "descripcion": "La queja sobre el corte de agua no está confirmada por ninguna fuente oficial.",
      "como_obtenerlo": "Solicitar reporte del organismo operador de agua municipal (fuente Nivel 1)."
    }
  ],
  "fecha_corte": "2026-08-11",
  "nivel_confianza_general": "medio"
}
SIAPE_REP_EOF_2_MARK

git add -A
git commit -m "Add sample ReporteEjecutivo output (data/reporte_ejemplo.json)"
git push -u origin claude/add-reporte-ejemplo
echo "LISTO"