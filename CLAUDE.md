# CLAUDE.md — Guía del proyecto para Claude Code

Este archivo orienta a Claude Code al trabajar en **SIAPE** (Sistema de Inteligencia
y Análisis Político-Electoral). Léelo antes de generar o modificar código.

## Qué es SIAPE

Sistema de monitoreo y análisis de posicionamiento político-electoral a nivel municipal.
Integra **dos capas** que deben poder operar de forma independiente:

- **Opción 1 — Motor de análisis (LLM).** `siape/analysis/`. Recibe los datos del periodo
  (aunque sean curados a mano) y produce un reporte estructurado usando el prompt de analista
  (`siape/analysis/prompts/analyst_system.md`) vía la API de Anthropic. **Debe funcionar
  desde el día uno sin depender de la ingesta automática.**
- **Opción 2 — Sistema de software.** `siape/ingest/`, `siape/storage/`, `siape/metrics/`,
  `siape/dashboard/`, `siape/alerts/`. Automatiza progresivamente la captura, el cálculo de
  métricas, el tablero y las alertas que alimentan a la Opción 1.

Regla de oro de secuencia: **primero valor con la Opción 1, luego automatización con la Opción 2.**

## Principios no negociables (heredados del prompt de analista)

1. **Solo información pública, lícita y verificable.** Nada de datos personales sensibles ni
   de origen ilícito. Nada de perfiles falsos ni amplificación inauténtica.
2. **Jerarquía de fuentes.** Todo dato lleva `source_level` (1 oficial, 2 medios, 3 redes,
   4 no verificado). Ninguna afirmación relevante se sostiene con una sola fuente de nivel 3/4.
3. **Confianza y fecha.** Cada métrica y hallazgo lleva nivel de confianza (alto/medio/bajo)
   y fecha de corte.
4. **Cumplimiento electoral y de ToS.** Respetar la legislación electoral (INE/IEE Puebla) y
   los Términos de Servicio de cada plataforma. Ver `README.md` → "Realidad de acceso a datos".
5. **Separación hecho / inferencia / recomendación** en toda salida.
6. **Proyecto autónomo.** SIAPE no se integra con sistemas institucionales ni catastrales:
   sin base de datos compartida, sin credenciales compartidas, sin importar datos de otros
   sistemas. Cualquier capa geográfica usa cartografía pública (INE), no datos externos.

## Convenciones técnicas

- **Lenguaje:** Python 3.11+. Identificadores en inglés; docstrings y textos de usuario en español.
- **Datos:** PostgreSQL 15+ con PostGIS (para secciones electorales y colonias). Fallback de
  desarrollo: SQLite (sin capa geográfica). La conexión se controla con `DATABASE_URL`.
- **ORM:** SQLAlchemy 2.x + Alembic. El esquema de referencia está en `db/schema.sql`.
- **LLM:** SDK `anthropic`. Modelo por defecto configurable con `SIAPE_MODEL` (ver `.env.example`).
  Nunca escribir la API key en código; leerla del entorno.
- **Salida estructurada del motor:** validar con Pydantic (`siape/analysis/schemas.py`).
- **Tablero:** Streamlit (`siape/dashboard/app.py`). Se puede sustituir por FastAPI sin tocar
  las capas de datos/análisis.
- **Config:** `config/settings.py` con `python-dotenv`. No hardcodear rutas ni secretos.
- **Pruebas:** `pytest` en `tests/`. Toda función de métrica debe tener prueba unitaria.

## Arquitectura de carpetas

```
siape/
  ingest/     conectores de captura (redes, medios, oficial, manual)
  storage/    modelos ORM y repositorio de acceso a datos
  metrics/    cálculo de engagement, share of voice, sentimiento, posicionamiento
  analysis/   motor LLM + prompts + esquemas de salida
  reports/    generación de reportes ejecutivos (md/html)
  alerts/     detección de crisis y oportunidades
  dashboard/  tablero de indicadores
```

## Orden de construcción sugerido (fases)

Ver `README.md` → "Plan de construcción". No saltar fases: cada una debe quedar probada.

## Al implementar, siempre

- Marca con `# TODO(verificar-ToS)` cualquier conector que dependa de términos de plataforma.
- No inventes métricas de fuentes que no existan; si falta el dato, deja el campo nulo y
  regístralo como "vacío de información".
- Escribe primero la interfaz (`ingest/base.py`) y haz que cada conector la cumpla.
