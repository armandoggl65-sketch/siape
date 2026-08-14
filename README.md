# SIAPE — Sistema de Inteligencia y Análisis Político-Electoral

Monitoreo y análisis de posicionamiento político-electoral a nivel municipal, con dos capas
integradas: un **motor de análisis (LLM)** y un **sistema de software** de ingesta, métricas
y tablero.

> **Contexto de referencia:** candidatura de la actual presidenta municipal de San Pedro
> Cholula, Puebla, con miras al proceso electoral local 2027. Todo el sistema es parametrizable
> a otro actor/municipio.

---

## Las dos opciones, integradas

| | Opción 1 — Motor de análisis | Opción 2 — Sistema de software |
|---|---|---|
| **Qué hace** | Convierte datos del periodo en reporte estratégico | Captura, almacena y calcula métricas automáticamente |
| **Depende de** | API de Anthropic + prompt de analista | Conectores + base de datos + tablero |
| **Funciona solo** | **Sí**, con datos curados a mano | Alimenta a la Opción 1 |
| **Módulos** | `siape/analysis/` | `siape/ingest/`, `storage/`, `metrics/`, `dashboard/`, `alerts/` |

La secuencia recomendada da **valor inmediato con la Opción 1** y luego **reduce el trabajo
manual con la Opción 2**.

---

## Arquitectura

```
Fuentes  ──►  Ingesta        ──►  Almacenamiento  ──►  Métricas      ──►  Motor LLM     ──►  Entregables
(redes,      (conectores /       (PostgreSQL/         (engagement,       (análisis con      (reporte,
 medios,      carga manual)       PostGIS)             SOV, sentimiento,  prompt de          tablero,
 oficial)                                              posicionamiento)   analista)          alertas)
```

Cada capa está desacoplada: se puede empezar cargando datos a mano y ya obtener análisis, y
después conectar automatizaciones sin reescribir las capas superiores.

---

## Realidad de acceso a datos (léelo antes de programar conectores)

El acceso a redes sociales está limitado por términos de servicio y APIs. El diseño asume
esta realidad en lugar de prometer captura ilimitada:

- **Cuentas propias (del proyecto):** métricas completas vía las APIs oficiales de la
  plataforma (p. ej. Graph API para páginas propias). Es la fuente más rica y lícita.
- **Cuentas de terceros / adversarios:** solo datos **públicos** y dentro de ToS. La captura
  masiva o el scraping fuera de términos **no** se implementa.
- **YouTube:** datos públicos vía Data API.
- **X (Twitter):** API de pago con niveles restringidos; por defecto el sistema usa
  **carga manual/CSV** y deja el conector de API como opcional.
- **Meta (Facebook/Instagram):** Graph API para páginas propias; para terceros, observación
  pública acotada. Herramientas de investigación de Meta están sujetas a acceso especial.
- **Encuestas y datos oficiales:** carga manual/documental (INE, IEE Puebla, boletines).

> Las condiciones y precios de las APIs cambian con frecuencia: **verifica los términos
> vigentes** de cada plataforma al implementar cada conector (marcado con `# TODO(verificar-ToS)`).

La **capa de carga manual** (`ingest/manual/`) es de primera clase: garantiza que el sistema
sea útil aunque una API no esté disponible.

---

## Consideraciones legales (México)

- **Información:** solo pública, lícita y verificable. Sin datos personales sensibles.
- **Materia electoral:** respetar tiempos de campaña, veda, propaganda y fiscalización
  (INE / IEE Puebla).
- **Servidores públicos:** cualquier uso con fin electoral debe operarse con recursos, tiempos
  y personal ajenos a la función pública (principio de imparcialidad, Art. 134 constitucional;
  Ley General en Materia de Delitos Electorales). Ante duda, consultar asesoría jurídica.

Estas reglas están reflejadas en `CLAUDE.md` y en el prompt de analista.

### Independencia del proyecto

SIAPE es un **proyecto autónomo y separado** de cualquier sistema institucional (incluidos
sistemas catastrales o de la administración pública). No comparte código, base de datos,
credenciales, servidores ni datos con ellos. Cualquier capa territorial futura usa
**cartografía pública** (p. ej. secciones electorales del INE), nunca información de otros
sistemas. Esta separación es deliberada y debe mantenerse.

---

## Stack

- Python 3.11+
- PostgreSQL 15+ / PostGIS (fallback dev: SQLite, sin geo)
- SQLAlchemy 2.x + Alembic
- SDK `anthropic` (motor de análisis)
- pandas (métricas), feedparser (RSS de medios), google-api-python-client (YouTube)
- Pydantic (salida estructurada), Streamlit + Plotly (tablero)

---

## Puesta en marcha (rápida)

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # coloca tu ANTHROPIC_API_KEY y DATABASE_URL
# Opción 1 (motor) — funciona con datos de ejemplo:
python scripts/run_analysis.py --period-file data/periodo_ejemplo.json
# Opción 2 (tablero):
streamlit run siape/dashboard/app.py
```

---

## Plan de construcción (fases)

**Fase 0 — Base.** Config, esquema de datos (`db/schema.sql`), modelos ORM, carga manual CSV.
**Fase 1 — Motor de análisis (Opción 1).** `analysis/engine.py` + prompt + esquemas Pydantic;
reporte ejecutivo a partir de datos curados. *Entregable útil al final de esta fase.*
**Fase 2 — Métricas.** engagement, share of voice, sentimiento, posicionamiento comparativo.
**Fase 3 — Ingesta automatizada.** Conectores YouTube y RSS de medios; cuentas propias de Meta.
**Fase 4 — Tablero y alertas.** Streamlit con KPIs y semáforos; detección de crisis/oportunidad.
**Fase 5 — Geo (opcional).** Secciones electorales y colonias con PostGIS; mapas de posicionamiento.
**Fase 6 — Profundización.** Historial real de métricas y variación entre cortes (6.1); cartografía
real del INE para San Pedro Cholula (6.2); vínculo observación→sección electoral en la carga manual
CSV, para que el mapa de posicionamiento refleje datos reales (6.3, `scripts/cargar_observaciones_csv.py`);
notoriedad y saldo de opinión por sección electoral, visibles en el tablero (6.4, `dashboard/mapa.py`).

Cada fase se cierra con pruebas en `tests/`.

---

## Estructura del repositorio

Ver `CLAUDE.md` para convenciones y `db/schema.sql` para el modelo de datos.
