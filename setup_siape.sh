#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/siape

cat > '.env.example' <<'SIAPE_EOF_1_MARK'
# ── SIAPE · variables de entorno (copiar a .env) ─────────────────────────
# API de Anthropic (motor de análisis, Opción 1)
ANTHROPIC_API_KEY=sk-ant-...
SIAPE_MODEL=claude-sonnet-5          # modelo del motor de análisis
SIAPE_MAX_TOKENS=4096

# Base de datos (Opción 2). Producción: PostgreSQL/PostGIS. Dev: sqlite.
DATABASE_URL=postgresql+psycopg2://usuario:clave@localhost:5432/siape
# DATABASE_URL=sqlite:///siape_dev.db   # fallback de desarrollo (sin geo)

# Conectores opcionales (dejar vacío para usar carga manual)
YOUTUBE_API_KEY=
X_BEARER_TOKEN=
META_ACCESS_TOKEN=

# Parámetros del proyecto
SIAPE_MUNICIPIO=San Pedro Cholula, Puebla
SIAPE_PROCESO=Elección local 2027
SIAPE_EOF_1_MARK

cat > '.gitignore' <<'SIAPE_EOF_2_MARK'
.venv/
__pycache__/
*.pyc
.env
siape_dev.db
data/*.json
!data/periodo_ejemplo.json
.streamlit/secrets.toml
SIAPE_EOF_2_MARK

cat > 'CLAUDE.md' <<'SIAPE_EOF_3_MARK'
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
SIAPE_EOF_3_MARK

cat > 'README.md' <<'SIAPE_EOF_4_MARK'
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

Cada fase se cierra con pruebas en `tests/`.

---

## Estructura del repositorio

Ver `CLAUDE.md` para convenciones y `db/schema.sql` para el modelo de datos.
SIAPE_EOF_4_MARK

cat > 'alembic.ini' <<'SIAPE_EOF_5_MARK'
# A generic, single database configuration.

[alembic]
# path to migration scripts.
# this is typically a path given in POSIX (e.g. forward slashes)
# format, relative to the token %(here)s which refers to the location of this
# ini file
script_location = %(here)s/alembic

# template used to generate migration file names; The default value is %%(rev)s_%%(slug)s
# Uncomment the line below if you want the files to be prepended with date and time
# see https://alembic.sqlalchemy.org/en/latest/tutorial.html#editing-the-ini-file
# for all available tokens
# file_template = %%(year)d_%%(month).2d_%%(day).2d_%%(hour).2d%%(minute).2d-%%(rev)s_%%(slug)s
# Or organize into date-based subdirectories (requires recursive_version_locations = true)
# file_template = %%(year)d/%%(month).2d/%%(day).2d_%%(hour).2d%%(minute).2d_%%(second).2d_%%(rev)s_%%(slug)s

# sys.path path, will be prepended to sys.path if present.
# defaults to the current working directory.  for multiple paths, the path separator
# is defined by "path_separator" below.
prepend_sys_path = .


# timezone to use when rendering the date within the migration file
# as well as the filename.
# If specified, requires the tzdata library which can be installed by adding
# `alembic[tz]` to the pip requirements.
# string value is passed to ZoneInfo()
# leave blank for localtime
# timezone =

# max length of characters to apply to the "slug" field
# truncate_slug_length = 40

# set to 'true' to run the environment during
# the 'revision' command, regardless of autogenerate
# revision_environment = false

# set to 'true' to allow .pyc and .pyo files without
# a source .py file to be detected as revisions in the
# versions/ directory
# sourceless = false

# version location specification; This defaults
# to <script_location>/versions.  When using multiple version
# directories, initial revisions must be specified with --version-path.
# The path separator used here should be the separator specified by "path_separator"
# below.
# version_locations = %(here)s/bar:%(here)s/bat:%(here)s/alembic/versions

# path_separator; This indicates what character is used to split lists of file
# paths, including version_locations and prepend_sys_path within configparser
# files such as alembic.ini.
# The default rendered in new alembic.ini files is "os", which uses os.pathsep
# to provide os-dependent path splitting.
#
# Note that in order to support legacy alembic.ini files, this default does NOT
# take place if path_separator is not present in alembic.ini.  If this
# option is omitted entirely, fallback logic is as follows:
#
# 1. Parsing of the version_locations option falls back to using the legacy
#    "version_path_separator" key, which if absent then falls back to the legacy
#    behavior of splitting on spaces and/or commas.
# 2. Parsing of the prepend_sys_path option falls back to the legacy
#    behavior of splitting on spaces, commas, or colons.
#
# Valid values for path_separator are:
#
# path_separator = :
# path_separator = ;
# path_separator = space
# path_separator = newline
#
# Use os.pathsep. Default configuration used for new projects.
path_separator = os

# set to 'true' to search source files recursively
# in each "version_locations" directory
# new in Alembic version 1.10
# recursive_version_locations = false

# the output encoding used when revision files
# are written from script.py.mako
# output_encoding = utf-8

# database URL.  This is consumed by the user-maintained env.py script only.
# other means of configuring database URLs may be customized within the env.py
# file.
# sqlalchemy.url se define en tiempo de ejecución en alembic/env.py desde DATABASE_URL


[post_write_hooks]
# post_write_hooks defines scripts or Python functions that are run
# on newly generated revision scripts.  See the documentation for further
# detail and examples

# format using "black" - use the console_scripts runner, against the "black" entrypoint
# hooks = black
# black.type = console_scripts
# black.entrypoint = black
# black.options = -l 79 REVISION_SCRIPT_FILENAME

# lint with attempts to fix using "ruff" - use the module runner, against the "ruff" module
# hooks = ruff
# ruff.type = module
# ruff.module = ruff
# ruff.options = check --fix REVISION_SCRIPT_FILENAME

# Alternatively, use the exec runner to execute a binary found on your PATH
# hooks = ruff
# ruff.type = exec
# ruff.executable = ruff
# ruff.options = check --fix REVISION_SCRIPT_FILENAME

# Logging configuration.  This is also consumed by the user-maintained
# env.py script only.
[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARNING
handlers = console
qualname =

[logger_sqlalchemy]
level = WARNING
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
SIAPE_EOF_5_MARK

mkdir -p 'alembic'
cat > 'alembic/README' <<'SIAPE_EOF_6_MARK'
Generic single-database configuration.
SIAPE_EOF_6_MARK

mkdir -p 'alembic'
cat > 'alembic/env.py' <<'SIAPE_EOF_7_MARK'
import os
import sys
from logging.config import fileConfig

from sqlalchemy import engine_from_config
from sqlalchemy import pool

from alembic import context

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from config.settings import settings  # noqa: E402
from siape.storage.models import Base  # noqa: E402

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Interpret the config file for Python logging.
# This line sets up loggers basically.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

config.set_main_option("sqlalchemy.url", settings.database_url)

target_metadata = Base.metadata

# other values from the config, defined by the needs of env.py,
# can be acquired:
# my_important_option = config.get_main_option("my_important_option")
# ... etc.


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    This configures the context with just a URL
    and not an Engine, though an Engine is acceptable
    here as well.  By skipping the Engine creation
    we don't even need a DBAPI to be available.

    Calls to context.execute() here emit the given string to the
    script output.

    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode.

    In this scenario we need to create an Engine
    and associate a connection with the context.

    """
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection, target_metadata=target_metadata
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
SIAPE_EOF_7_MARK

mkdir -p 'alembic'
cat > 'alembic/script.py.mako' <<'SIAPE_EOF_8_MARK'
"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
${imports if imports else ""}

# revision identifiers, used by Alembic.
revision: str = ${repr(up_revision)}
down_revision: Union[str, Sequence[str], None] = ${repr(down_revision)}
branch_labels: Union[str, Sequence[str], None] = ${repr(branch_labels)}
depends_on: Union[str, Sequence[str], None] = ${repr(depends_on)}


def upgrade() -> None:
    """Upgrade schema."""
    ${upgrades if upgrades else "pass"}


def downgrade() -> None:
    """Downgrade schema."""
    ${downgrades if downgrades else "pass"}
SIAPE_EOF_8_MARK

mkdir -p 'alembic/versions'
cat > 'alembic/versions/e9d32eef416a_esquema_inicial.py' <<'SIAPE_EOF_9_MARK'
"""esquema inicial

Revision ID: e9d32eef416a
Revises: 
Create Date: 2026-08-10 04:57:25.297457

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e9d32eef416a'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # ### commands auto generated by Alembic - please adjust! ###
    op.create_table('actores',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('nombre', sa.String(), nullable=False),
    sa.Column('cargo_actual', sa.String(), nullable=True),
    sa.Column('partido', sa.String(), nullable=True),
    sa.Column('es_principal', sa.Boolean(), nullable=False),
    sa.Column('aspiracion', sa.String(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_table('fuentes',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('nombre', sa.String(), nullable=False),
    sa.Column('source_level', sa.Integer(), nullable=False),
    sa.Column('tipo', sa.String(), nullable=False),
    sa.Column('plataforma', sa.String(), nullable=True),
    sa.Column('url', sa.String(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.CheckConstraint("tipo IN ('oficial', 'medios', 'redes', 'no_verificado')", name='ck_fuentes_tipo'),
    sa.CheckConstraint('source_level BETWEEN 1 AND 4', name='ck_fuentes_source_level'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_table('metricas',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('actor_id', sa.Integer(), nullable=False),
    sa.Column('kpi', sa.String(), nullable=False),
    sa.Column('valor', sa.Float(), nullable=True),
    sa.Column('variacion', sa.Float(), nullable=True),
    sa.Column('confianza', sa.String(), nullable=False),
    sa.Column('fecha_corte', sa.String(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.CheckConstraint("confianza IN ('alto', 'medio', 'bajo')", name='ck_metricas_confianza'),
    sa.ForeignKeyConstraint(['actor_id'], ['actores.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_table('observaciones',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('actor_id', sa.Integer(), nullable=True),
    sa.Column('fuente_id', sa.Integer(), nullable=False),
    sa.Column('tipo', sa.String(), nullable=False),
    sa.Column('tema', sa.String(), nullable=True),
    sa.Column('sentimiento', sa.String(), nullable=True),
    sa.Column('texto', sa.Text(), nullable=True),
    sa.Column('valor_numerico', sa.Float(), nullable=True),
    sa.Column('url', sa.String(), nullable=True),
    sa.Column('fecha', sa.String(), nullable=False),
    sa.Column('confianza', sa.String(), nullable=False),
    sa.Column('no_confirmado', sa.Boolean(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.CheckConstraint("confianza IN ('alto', 'medio', 'bajo')", name='ck_observaciones_confianza'),
    sa.CheckConstraint("sentimiento IN ('positivo', 'negativo', 'neutro')", name='ck_observaciones_sentimiento'),
    sa.ForeignKeyConstraint(['actor_id'], ['actores.id'], ),
    sa.ForeignKeyConstraint(['fuente_id'], ['fuentes.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    # ### end Alembic commands ###


def downgrade() -> None:
    """Downgrade schema."""
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_table('observaciones')
    op.drop_table('metricas')
    op.drop_table('fuentes')
    op.drop_table('actores')
    # ### end Alembic commands ###
SIAPE_EOF_9_MARK

mkdir -p 'config'
cat > 'config/__init__.py' <<'SIAPE_EOF_10_MARK'
SIAPE_EOF_10_MARK

mkdir -p 'config'
cat > 'config/settings.py' <<'SIAPE_EOF_11_MARK'
"""Configuración de SIAPE cargada desde variables de entorno (.env)."""
from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Settings:
    anthropic_api_key: str | None
    siape_model: str
    siape_max_tokens: int
    database_url: str
    youtube_api_key: str | None
    x_bearer_token: str | None
    meta_access_token: str | None
    siape_municipio: str
    siape_proceso: str


def load_settings() -> Settings:
    return Settings(
        anthropic_api_key=os.getenv("ANTHROPIC_API_KEY"),
        siape_model=os.getenv("SIAPE_MODEL", "claude-sonnet-5"),
        siape_max_tokens=int(os.getenv("SIAPE_MAX_TOKENS", "4096")),
        database_url=os.getenv("DATABASE_URL", "sqlite:///siape_dev.db"),
        youtube_api_key=os.getenv("YOUTUBE_API_KEY") or None,
        x_bearer_token=os.getenv("X_BEARER_TOKEN") or None,
        meta_access_token=os.getenv("META_ACCESS_TOKEN") or None,
        siape_municipio=os.getenv("SIAPE_MUNICIPIO", "San Pedro Cholula, Puebla"),
        siape_proceso=os.getenv("SIAPE_PROCESO", "Elección local 2027"),
    )


settings = load_settings()
SIAPE_EOF_11_MARK

mkdir -p 'data'
cat > 'data/periodo_ejemplo.json' <<'SIAPE_EOF_12_MARK'
{
  "_nota": "Dataset de EJEMPLO con datos FICTICIOS, usado solo para probar el pipeline (Opción 1) sin depender de captura real. No representa mediciones reales.",
  "periodo": {
    "municipio": "San Pedro Cholula, Puebla",
    "proceso": "Elección local 2027",
    "fecha_inicio": "2026-08-01",
    "fecha_corte": "2026-08-07",
    "horizonte": "intercampaña"
  },
  "actor_principal": {
    "nombre": "Tonanzin Fernández",
    "cargo_actual": "Presidenta municipal",
    "partido": "Ejemplo Partido A",
    "aspiracion": "Reelección"
  },
  "adversarios": [
    {"nombre": "Adversario Ejemplo 1", "partido": "Ejemplo Partido B", "cargo_actual": null},
    {"nombre": "Adversario Ejemplo 2", "partido": "Ejemplo Partido C", "cargo_actual": "Regidor"}
  ],
  "kpis": [
    {
      "kpi": "seguidores_instagram",
      "actor": "Tonanzin Fernández",
      "valor": 18200,
      "variacion_pct": 1.4,
      "confianza": "alto",
      "fecha_corte": "2026-08-07",
      "source_level": 3
    },
    {
      "kpi": "tasa_interaccion_instagram",
      "actor": "Tonanzin Fernández",
      "valor": 3.1,
      "variacion_pct": -0.4,
      "confianza": "medio",
      "fecha_corte": "2026-08-07",
      "source_level": 3
    },
    {
      "kpi": "share_of_voice_pct",
      "actor": "Tonanzin Fernández",
      "valor": 42.0,
      "variacion_pct": 2.0,
      "confianza": "medio",
      "fecha_corte": "2026-08-07",
      "source_level": 3
    }
  ],
  "observaciones": [
    {
      "fecha": "2026-08-03",
      "actor": "Tonanzin Fernández",
      "fuente_nombre": "Boletín Ayuntamiento SPC",
      "source_level": 1,
      "tipo_fuente": "oficial",
      "tema": "obra pública",
      "sentimiento": "positivo",
      "confianza": "alto",
      "texto_resumen": "Inauguración de rehabilitación de calle en el centro histórico.",
      "no_confirmado": false
    },
    {
      "fecha": "2026-08-05",
      "actor": "Adversario Ejemplo 1",
      "fuente_nombre": "Medio Local Ejemplo",
      "source_level": 2,
      "tipo_fuente": "medios",
      "tema": "seguridad",
      "sentimiento": "negativo",
      "confianza": "medio",
      "texto_resumen": "Nota señala incremento de quejas ciudadanas por alumbrado público.",
      "no_confirmado": false
    },
    {
      "fecha": "2026-08-06",
      "actor": "Tonanzin Fernández",
      "fuente_nombre": "Cuenta X @ejemplo_ciudadano",
      "source_level": 4,
      "tipo_fuente": "no_verificado",
      "tema": "agua",
      "sentimiento": "negativo",
      "confianza": "bajo",
      "texto_resumen": "Trascendido no confirmado sobre corte de suministro en una colonia; no triangulado con otra fuente.",
      "no_confirmado": true
    }
  ]
}
SIAPE_EOF_12_MARK

mkdir -p 'db'
cat > 'db/schema.sql' <<'SIAPE_EOF_13_MARK'
-- SIAPE — esquema de referencia (Fase 0)
--
-- Compatible con PostgreSQL 15+ (producción) y SQLite (fallback de desarrollo,
-- sin capa geográfica). No se usan tipos específicos de Postgres (ENUM, PostGIS)
-- para mantener compatibilidad; las reglas de valor se aplican con CHECK.
--
-- Regla de oro (CLAUDE.md): todo dato relevante lleva source_level (1-4) y,
-- cuando aplica, nivel de confianza (alto/medio/bajo) y fecha de corte.

CREATE TABLE actores (
    id              INTEGER PRIMARY KEY,
    nombre          TEXT NOT NULL,
    cargo_actual    TEXT,
    partido         TEXT,
    es_principal    INTEGER NOT NULL DEFAULT 0 CHECK (es_principal IN (0, 1)),
    aspiracion      TEXT,
    created_at      TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Jerarquía de verificabilidad (Sección 4 del prompt de analista):
-- 1 = oficial/documental, 2 = medios establecidos, 3 = redes/contenido público,
-- 4 = no verificado (rumor/trascendido, nunca tratado como hecho).
CREATE TABLE fuentes (
    id              INTEGER PRIMARY KEY,
    nombre          TEXT NOT NULL,
    source_level    INTEGER NOT NULL CHECK (source_level BETWEEN 1 AND 4),
    tipo            TEXT NOT NULL CHECK (tipo IN ('oficial', 'medios', 'redes', 'no_verificado')),
    plataforma      TEXT,
    url             TEXT,
    created_at      TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Dato crudo/observación: una mención, publicación, resultado de encuesta, etc.
-- Es la unidad mínima que alimenta las métricas y el motor de análisis.
CREATE TABLE observaciones (
    id              INTEGER PRIMARY KEY,
    actor_id        INTEGER REFERENCES actores(id),
    fuente_id       INTEGER NOT NULL REFERENCES fuentes(id),
    tipo            TEXT NOT NULL,
    tema            TEXT,
    sentimiento     TEXT CHECK (sentimiento IN ('positivo', 'negativo', 'neutro') OR sentimiento IS NULL),
    texto           TEXT,
    valor_numerico  REAL,
    url             TEXT,
    fecha           TEXT NOT NULL,
    confianza       TEXT NOT NULL CHECK (confianza IN ('alto', 'medio', 'bajo')),
    no_confirmado   INTEGER NOT NULL DEFAULT 0 CHECK (no_confirmado IN (0, 1)),
    created_at      TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Métricas/KPI calculados para un actor en un periodo de corte.
CREATE TABLE metricas (
    id              INTEGER PRIMARY KEY,
    actor_id        INTEGER NOT NULL REFERENCES actores(id),
    kpi             TEXT NOT NULL,
    valor           REAL,
    variacion       REAL,
    confianza       TEXT NOT NULL CHECK (confianza IN ('alto', 'medio', 'bajo')),
    fecha_corte     TEXT NOT NULL,
    created_at      TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_observaciones_actor ON observaciones(actor_id);
CREATE INDEX idx_observaciones_fuente ON observaciones(fuente_id);
CREATE INDEX idx_observaciones_fecha ON observaciones(fecha);
CREATE INDEX idx_metricas_actor ON metricas(actor_id);
CREATE INDEX idx_metricas_fecha_corte ON metricas(fecha_corte);

-- Nota (Fase 5, opcional): una capa geográfica futura (secciones electorales,
-- colonias) se añadirá con PostGIS usando cartografía pública del INE — nunca
-- datos de otros sistemas. No se modela aquí para no acoplar fases tempranas
-- a una dependencia que Fase 0-1 no necesitan.
SIAPE_EOF_13_MARK

cat > 'requirements.txt' <<'SIAPE_EOF_14_MARK'
anthropic>=0.40
SQLAlchemy>=2.0
alembic>=1.13
psycopg2-binary>=2.9
GeoAlchemy2>=0.15
pandas>=2.2
pydantic>=2.7
python-dotenv>=1.0
feedparser>=6.0
google-api-python-client>=2.130
requests>=2.32
streamlit>=1.36
plotly>=5.22
pytest>=8.2
SIAPE_EOF_14_MARK

mkdir -p 'scripts'
cat > 'scripts/run_analysis.py' <<'SIAPE_EOF_15_MARK'
#!/usr/bin/env python
"""CLI: genera el reporte ejecutivo (Opción 1) a partir de un archivo de periodo.

Uso:
    python scripts/run_analysis.py --period-file data/periodo_ejemplo.json
    python scripts/run_analysis.py --period-file data/periodo_ejemplo.json --output reporte.md
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from siape.analysis.engine import run_analysis  # noqa: E402
from siape.reports.executive import render_markdown  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--period-file", required=True, help="Ruta al JSON de datos del periodo")
    parser.add_argument("--output", help="Ruta donde guardar el reporte Markdown (por defecto, stdout)")
    args = parser.parse_args()

    reporte = run_analysis(args.period_file)
    markdown = render_markdown(reporte)

    if args.output:
        Path(args.output).write_text(markdown, encoding="utf-8")
        print(f"Reporte guardado en {args.output}")
    else:
        print(markdown)


if __name__ == "__main__":
    main()
SIAPE_EOF_15_MARK

mkdir -p 'siape'
cat > 'siape/__init__.py' <<'SIAPE_EOF_16_MARK'
SIAPE_EOF_16_MARK

mkdir -p 'siape/analysis'
cat > 'siape/analysis/__init__.py' <<'SIAPE_EOF_17_MARK'
SIAPE_EOF_17_MARK

mkdir -p 'siape/analysis'
cat > 'siape/analysis/engine.py' <<'SIAPE_EOF_18_MARK'
"""Motor de análisis (Opción 1): datos del periodo → reporte ejecutivo vía LLM.

Funciona con datos curados a mano (data/periodo_ejemplo.json u otro archivo
con el mismo formato) sin depender de la capa de ingesta automatizada.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import anthropic

from config.settings import settings
from siape.analysis.schemas import ReporteEjecutivo

PROMPT_PATH = Path(__file__).parent / "prompts" / "analyst_system.md"

USER_INSTRUCTIONS = (
    "Datos del periodo (JSON). Responde solo con el JSON de ReporteEjecutivo "
    "descrito en la Sección 10 del prompt de sistema, sin texto adicional ni "
    "bloques de código markdown.\n\n"
)


def load_system_prompt() -> str:
    return PROMPT_PATH.read_text(encoding="utf-8")


def load_period_data(period_file: str | Path) -> dict[str, Any]:
    return json.loads(Path(period_file).read_text(encoding="utf-8"))


def build_client() -> anthropic.Anthropic:
    if not settings.anthropic_api_key:
        raise RuntimeError(
            "ANTHROPIC_API_KEY no configurada. Copia .env.example a .env y agrega tu API key."
        )
    return anthropic.Anthropic(api_key=settings.anthropic_api_key)


def parse_response(raw_text: str) -> ReporteEjecutivo:
    data = json.loads(raw_text)
    return ReporteEjecutivo.model_validate(data)


def run_analysis(
    period_file: str | Path, client: anthropic.Anthropic | None = None
) -> ReporteEjecutivo:
    """Genera el reporte ejecutivo a partir de un archivo de datos del periodo.

    `client` es inyectable para pruebas (evita llamadas reales a la API).
    """
    period_data = load_period_data(period_file)
    system_prompt = load_system_prompt()
    client = client or build_client()

    response = client.messages.create(
        model=settings.siape_model,
        max_tokens=settings.siape_max_tokens,
        system=system_prompt,
        messages=[
            {
                "role": "user",
                "content": USER_INSTRUCTIONS
                + json.dumps(period_data, ensure_ascii=False, indent=2),
            }
        ],
    )

    raw_text = response.content[0].text
    return parse_response(raw_text)
SIAPE_EOF_18_MARK

mkdir -p 'siape/analysis/prompts'
cat > 'siape/analysis/prompts/analyst_system.md' <<'SIAPE_EOF_19_MARK'
# Prompt de sistema — Analista SIAPE

## 1. Rol

Actúas como **analista senior de inteligencia política y estrategia electoral**,
especializado en política municipal mexicana, medición de redes sociales, análisis
de narrativas y lectura del entorno competitivo local. Tu trabajo es riguroso,
verificable, comparativo y orientado a la decisión: no produces opinión, produces
evidencia procesada y recomendaciones accionables, con explicitud sobre el grado
de confianza de cada hallazgo.

## 2. Objetivo

Monitorear, medir y analizar el **posicionamiento político** del actor principal
frente a su entorno competitivo, integrando fuentes verificables (redes sociales,
medios, datos oficiales y encuestas), para informar decisiones estratégicas
orientadas a un proyecto político viable y competitivo.

## 3. Contexto fijo del proyecto

- **Ámbito:** San Pedro Cholula, Puebla, México (elección municipal).
- **Actor principal:** Tonanzin Fernández, presidenta municipal, aspiración de reelección.
- **Proceso electoral:** local 2027, Puebla.
- **Autoridades electorales de referencia:** INE, Instituto Electoral del Estado
  (IEE Puebla), Tribunal Electoral del Estado de Puebla.

El resto del contexto (horizonte temporal, fecha de corte, adversarios, temas
locales dominantes) se recibe en cada ejecución como datos del periodo — no lo
asumas ni lo inventes si no viene en los datos proporcionados.

## 4. Fuentes y jerarquía de verificabilidad

Clasifica **toda** información según su verificabilidad y no mezcles niveles sin marcarlos:

- **Nivel 1 — Oficial/documental:** INE, IEE Puebla, DOF/Periódico Oficial del Estado,
  boletines de gobierno, resultados electorales históricos, listado nominal (datos agregados).
- **Nivel 2 — Medios establecidos:** prensa local/regional/nacional con línea editorial identificable.
- **Nivel 3 — Redes sociales y contenido público:** X, Facebook, Instagram, TikTok, YouTube,
  grupos y páginas locales.
- **Nivel 4 — No verificado:** rumores, versiones anónimas, trascendidos. Se registran pero
  **siempre etiquetados como no confirmados** y nunca se tratan como hecho.

Regla: **ningún hallazgo relevante se sostiene en una sola fuente de Nivel 3 o 4** sin triangulación.
Si los datos del periodo no traen triangulación suficiente, dilo explícitamente en
"Vacíos de información" en vez de afirmar el hallazgo.

## 5. Dimensiones de análisis

**A. Medición de redes sociales.** Alcance, crecimiento e interacción por plataforma; volumen
de menciones; *share of voice* frente a adversarios; temas que generan mayor interacción;
identificación de contenido orgánico vs. amplificado; sospechas de actividad inauténtica.

**B. Posicionamiento comparativo.** Ubicación relativa del actor frente a cada adversario por
notoriedad, valoración y temas propios; mapa de posicionamiento (qué "posee" cada actor).

**C. Sentimiento y narrativas.** Tono predominante (positivo/negativo/neutro) por tema y por
plataforma; narrativas dominantes a favor y en contra; evolución en el tiempo; puntos de
inflexión y sus disparadores.

**D. Agenda temática.** Qué temas domina el actor, cuáles domina la oposición, cuáles están
vacíos ("océanos azules" temáticos) y cuáles son de riesgo.

**E. Mapeo de actores e influencia.** Aliados, adversarios, actores bisagra, líderes de opinión
locales, medios clave, redes de amplificación; nivel de influencia estimado de cada uno.

**F. Detección temprana de crisis.** Señales de riesgo reputacional, temas que escalan,
ataques coordinados; recomendación de respuesta y ventana de reacción.

**G. Ventanas de oportunidad.** Coyunturas, agravios ciudadanos no atendidos por rivales,
efemérides y hitos locales aprovechables.

Analiza solo las dimensiones para las que los datos del periodo aportan evidencia. No
rellenes una dimensión sin datos: repórtala como vacío de información.

## 6. Métricas e indicadores (KPI)

Para cada KPI que venga en los datos del periodo reporta: **valor actual, variación vs.
periodo anterior, y nivel de confianza** (alto/medio/bajo) según la calidad de las fuentes.
No inventes KPIs que no estén en los datos proporcionados.

## 7. Metodología

1. **Triangulación** obligatoria entre niveles de fuente antes de afirmar.
2. **Etiquetado de confianza** en cada afirmación (alto/medio/bajo) y de la fecha del dato.
3. **Comparabilidad temporal:** mismos indicadores, mismos cortes, para ver tendencia.
4. **Separación hecho / inferencia / recomendación** en todo momento.
5. **Trazabilidad:** cada dato relevante cita su fuente y fecha.

## 8. Entregables (ver formato de salida, Sección 10)

- Reporte ejecutivo con hallazgos clave y recomendaciones priorizadas.
- Tablero de indicadores (KPIs con valor, variación y nivel de confianza).
- Alertas de crisis o de oportunidad, con acción sugerida y plazo.
- Vacíos de información: qué falta y cómo obtenerlo lícitamente.

## 9. Restricciones éticas y legales (no negociables)

- Usa **solo información pública, lícita y verificable**. No solicites, deduzcas ni proceses
  datos personales sensibles ni información de origen ilícito.
- **No generes desinformación**, contenido engañoso, perfiles falsos ni estrategias de
  amplificación inauténtica. El análisis es para **entender** el entorno, no para manipularlo.
- Respeta la **legislación electoral vigente** (INE / IEE Puebla): tiempos de campaña,
  veda electoral, propaganda y fiscalización.
- **Separación de recursos públicos:** cualquier actividad de carácter electoral debe operarse
  con recursos, tiempos y personal ajenos a la función pública, conforme al principio de
  imparcialidad (Art. 134 constitucional) y a la Ley General en Materia de Delitos Electorales.
- Ante duda legal, **marca la duda** y recomienda consulta jurídica; no la resuelvas por defecto.

## 10. Formato de salida

Responde **únicamente** con un objeto JSON válido que cumpla el esquema `ReporteEjecutivo`
provisto por el sistema (no agregues texto fuera del JSON, ni bloques de código markdown).
El JSON debe incluir:

1. `resumen_ejecutivo`: 5-7 viñetas de lo más relevante.
2. `indicadores`: lista de KPIs (kpi, valor, variación, confianza).
3. `analisis_por_dimension`: solo las dimensiones (A-G) con novedades relevantes en los datos.
4. `alertas`: crisis u oportunidad, cada una con acción sugerida y plazo.
5. `recomendaciones`: máximo 5, cada una con justificación basada en evidencia.
6. `vacios_informacion`: qué falta y cómo obtenerlo lícitamente.
7. `fecha_corte` y `nivel_confianza_general`.

Marca siempre el **nivel de confianza** y la **fecha de corte** de los datos.
SIAPE_EOF_19_MARK

mkdir -p 'siape/analysis'
cat > 'siape/analysis/schemas.py' <<'SIAPE_EOF_20_MARK'
"""Esquemas Pydantic de la salida del motor de análisis (Sección 10 del prompt)."""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

NivelConfianza = Literal["alto", "medio", "bajo"]
DimensionId = Literal["A", "B", "C", "D", "E", "F", "G"]


class Indicador(BaseModel):
    kpi: str
    valor: float | None = None
    variacion: float | None = None
    confianza: NivelConfianza


class AnalisisDimension(BaseModel):
    dimension: DimensionId
    titulo: str
    contenido: str
    confianza: NivelConfianza
    fuentes: list[str] = Field(default_factory=list)


class Alerta(BaseModel):
    tipo: Literal["crisis", "oportunidad"]
    descripcion: str
    accion_sugerida: str
    plazo: str
    confianza: NivelConfianza


class Recomendacion(BaseModel):
    texto: str
    justificacion: str
    prioridad: int = Field(ge=1, le=5)


class VacioInformacion(BaseModel):
    descripcion: str
    como_obtenerlo: str


class ReporteEjecutivo(BaseModel):
    resumen_ejecutivo: list[str]
    indicadores: list[Indicador] = Field(default_factory=list)
    analisis_por_dimension: list[AnalisisDimension] = Field(default_factory=list)
    alertas: list[Alerta] = Field(default_factory=list)
    recomendaciones: list[Recomendacion] = Field(default_factory=list, max_length=5)
    vacios_informacion: list[VacioInformacion] = Field(default_factory=list)
    fecha_corte: str
    nivel_confianza_general: NivelConfianza
SIAPE_EOF_20_MARK

mkdir -p 'siape/ingest'
cat > 'siape/ingest/__init__.py' <<'SIAPE_EOF_21_MARK'
SIAPE_EOF_21_MARK

mkdir -p 'siape/ingest'
cat > 'siape/ingest/base.py' <<'SIAPE_EOF_22_MARK'
"""Interfaz que debe cumplir todo conector de ingesta (manual o automatizado)."""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class RawObservation:
    """Dato crudo producido por un conector, previo a persistirse.

    `source_level` y `confianza` son obligatorios: ningún conector puede
    producir una observación sin declarar su verificabilidad (Sección 4 del
    prompt de analista / CLAUDE.md).
    """

    fuente_nombre: str
    source_level: int  # 1 oficial, 2 medios, 3 redes, 4 no verificado
    tipo_fuente: str  # 'oficial' | 'medios' | 'redes' | 'no_verificado'
    tipo: str  # tipo de observación, p. ej. 'mencion', 'publicacion', 'encuesta'
    fecha: str  # ISO 8601 (YYYY-MM-DD)
    confianza: str  # 'alto' | 'medio' | 'bajo'
    actor_nombre: str | None = None
    plataforma: str | None = None
    tema: str | None = None
    sentimiento: str | None = None
    texto: str | None = None
    valor_numerico: float | None = None
    url: str | None = None
    no_confirmado: bool = False

    def __post_init__(self) -> None:
        if self.source_level not in (1, 2, 3, 4):
            raise ValueError(f"source_level inválido: {self.source_level}")
        if self.confianza not in ("alto", "medio", "bajo"):
            raise ValueError(f"confianza inválida: {self.confianza}")
        if self.source_level >= 4 and not self.no_confirmado:
            # Nivel 4 (no verificado) siempre se marca como no confirmado.
            self.no_confirmado = True


class BaseConnector(ABC):
    """Todo conector de captura (manual o de API) implementa `fetch`."""

    @abstractmethod
    def fetch(self) -> list[RawObservation]:
        """Devuelve las observaciones crudas capturadas por este conector."""
        raise NotImplementedError
SIAPE_EOF_22_MARK

mkdir -p 'siape/ingest/manual'
cat > 'siape/ingest/manual/__init__.py' <<'SIAPE_EOF_23_MARK'
SIAPE_EOF_23_MARK

mkdir -p 'siape/ingest/manual'
cat > 'siape/ingest/manual/csv_loader.py' <<'SIAPE_EOF_24_MARK'
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

from sqlalchemy.orm import Session

from siape.ingest.base import BaseConnector, RawObservation
from siape.storage.models import Actor, Fuente, Observacion


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
SIAPE_EOF_24_MARK

mkdir -p 'siape/reports'
cat > 'siape/reports/__init__.py' <<'SIAPE_EOF_25_MARK'
SIAPE_EOF_25_MARK

mkdir -p 'siape/reports'
cat > 'siape/reports/executive.py' <<'SIAPE_EOF_26_MARK'
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
SIAPE_EOF_26_MARK

mkdir -p 'siape/storage'
cat > 'siape/storage/__init__.py' <<'SIAPE_EOF_27_MARK'
SIAPE_EOF_27_MARK

mkdir -p 'siape/storage'
cat > 'siape/storage/db.py' <<'SIAPE_EOF_28_MARK'
"""Engine y factoría de sesiones SQLAlchemy, controlados por DATABASE_URL."""
from __future__ import annotations

from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session, sessionmaker

from config.settings import settings


def make_engine(database_url: str | None = None) -> Engine:
    return create_engine(database_url or settings.database_url)


def make_session_factory(engine: Engine) -> sessionmaker[Session]:
    return sessionmaker(bind=engine)
SIAPE_EOF_28_MARK

mkdir -p 'siape/storage'
cat > 'siape/storage/models.py' <<'SIAPE_EOF_29_MARK'
"""Modelos ORM (SQLAlchemy 2.x) — reflejan db/schema.sql."""
from __future__ import annotations

import datetime as dt

from sqlalchemy import CheckConstraint, ForeignKey, String, Text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

SOURCE_LEVELS = (1, 2, 3, 4)
TIPOS_FUENTE = ("oficial", "medios", "redes", "no_verificado")
SENTIMIENTOS = ("positivo", "negativo", "neutro")
NIVELES_CONFIANZA = ("alto", "medio", "bajo")


class Base(DeclarativeBase):
    pass


class Actor(Base):
    __tablename__ = "actores"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String, nullable=False)
    cargo_actual: Mapped[str | None] = mapped_column(String)
    partido: Mapped[str | None] = mapped_column(String)
    es_principal: Mapped[bool] = mapped_column(default=False)
    aspiracion: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[dt.datetime] = mapped_column(default=dt.datetime.utcnow)

    observaciones: Mapped[list["Observacion"]] = relationship(back_populates="actor")
    metricas: Mapped[list["Metrica"]] = relationship(back_populates="actor")


class Fuente(Base):
    __tablename__ = "fuentes"
    __table_args__ = (
        CheckConstraint("source_level BETWEEN 1 AND 4", name="ck_fuentes_source_level"),
        CheckConstraint(f"tipo IN {TIPOS_FUENTE}", name="ck_fuentes_tipo"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String, nullable=False)
    source_level: Mapped[int] = mapped_column(nullable=False)
    tipo: Mapped[str] = mapped_column(String, nullable=False)
    plataforma: Mapped[str | None] = mapped_column(String)
    url: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[dt.datetime] = mapped_column(default=dt.datetime.utcnow)

    observaciones: Mapped[list["Observacion"]] = relationship(back_populates="fuente")


class Observacion(Base):
    """Dato crudo: mención, publicación, resultado de encuesta, etc."""

    __tablename__ = "observaciones"
    __table_args__ = (
        CheckConstraint(f"sentimiento IN {SENTIMIENTOS}", name="ck_observaciones_sentimiento"),
        CheckConstraint(f"confianza IN {NIVELES_CONFIANZA}", name="ck_observaciones_confianza"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    actor_id: Mapped[int | None] = mapped_column(ForeignKey("actores.id"))
    fuente_id: Mapped[int] = mapped_column(ForeignKey("fuentes.id"), nullable=False)
    tipo: Mapped[str] = mapped_column(String, nullable=False)
    tema: Mapped[str | None] = mapped_column(String)
    sentimiento: Mapped[str | None] = mapped_column(String)
    texto: Mapped[str | None] = mapped_column(Text)
    valor_numerico: Mapped[float | None] = mapped_column()
    url: Mapped[str | None] = mapped_column(String)
    fecha: Mapped[str] = mapped_column(String, nullable=False)
    confianza: Mapped[str] = mapped_column(String, nullable=False)
    no_confirmado: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[dt.datetime] = mapped_column(default=dt.datetime.utcnow)

    actor: Mapped[Actor | None] = relationship(back_populates="observaciones")
    fuente: Mapped[Fuente] = relationship(back_populates="observaciones")


class Metrica(Base):
    __tablename__ = "metricas"
    __table_args__ = (
        CheckConstraint(f"confianza IN {NIVELES_CONFIANZA}", name="ck_metricas_confianza"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    actor_id: Mapped[int] = mapped_column(ForeignKey("actores.id"), nullable=False)
    kpi: Mapped[str] = mapped_column(String, nullable=False)
    valor: Mapped[float | None] = mapped_column()
    variacion: Mapped[float | None] = mapped_column()
    confianza: Mapped[str] = mapped_column(String, nullable=False)
    fecha_corte: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(default=dt.datetime.utcnow)

    actor: Mapped[Actor] = relationship(back_populates="metricas")
SIAPE_EOF_29_MARK

mkdir -p 'tests'
cat > 'tests/__init__.py' <<'SIAPE_EOF_30_MARK'
SIAPE_EOF_30_MARK

mkdir -p 'tests'
cat > 'tests/conftest.py' <<'SIAPE_EOF_31_MARK'
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from siape.storage.models import Base


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as session:
        yield session
SIAPE_EOF_31_MARK

mkdir -p 'tests'
cat > 'tests/test_analysis_schemas.py' <<'SIAPE_EOF_32_MARK'
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
SIAPE_EOF_32_MARK

mkdir -p 'tests'
cat > 'tests/test_engine.py' <<'SIAPE_EOF_33_MARK'
import dataclasses
import json
from pathlib import Path
from types import SimpleNamespace

import pytest

from siape.analysis import engine
from siape.analysis.engine import build_client, load_period_data, load_system_prompt, run_analysis

REPO_ROOT = Path(__file__).parent.parent
PERIODO_EJEMPLO = REPO_ROOT / "data" / "periodo_ejemplo.json"

REPORTE_JSON = json.dumps(
    {
        "resumen_ejecutivo": ["Hallazgo de prueba"],
        "indicadores": [],
        "analisis_por_dimension": [],
        "alertas": [],
        "recomendaciones": [],
        "vacios_informacion": [],
        "fecha_corte": "2026-08-07",
        "nivel_confianza_general": "medio",
    }
)


class FakeMessages:
    def __init__(self, text: str):
        self._text = text
        self.last_call: dict | None = None

    def create(self, **kwargs):
        self.last_call = kwargs
        return SimpleNamespace(content=[SimpleNamespace(text=self._text)])


class FakeAnthropicClient:
    def __init__(self, text: str = REPORTE_JSON):
        self.messages = FakeMessages(text)


def test_load_system_prompt_no_vacio():
    prompt = load_system_prompt()
    assert "analista senior de inteligencia política" in prompt.lower()


def test_load_period_data_lee_json_de_ejemplo():
    data = load_period_data(PERIODO_EJEMPLO)
    assert data["actor_principal"]["nombre"] == "Tonanzin Fernández"


def test_build_client_sin_api_key_lanza_error(monkeypatch):
    sin_api_key = dataclasses.replace(engine.settings, anthropic_api_key=None)
    monkeypatch.setattr(engine, "settings", sin_api_key)
    with pytest.raises(RuntimeError):
        build_client()


def test_run_analysis_con_cliente_simulado():
    fake_client = FakeAnthropicClient()

    reporte = run_analysis(PERIODO_EJEMPLO, client=fake_client)

    assert reporte.fecha_corte == "2026-08-07"
    assert reporte.resumen_ejecutivo == ["Hallazgo de prueba"]
    # el motor debe mandar el system prompt y los datos del periodo en el mensaje
    assert "analista senior" in fake_client.messages.last_call["system"].lower()
    assert "Tonanzin Fernández" in fake_client.messages.last_call["messages"][0]["content"]
SIAPE_EOF_33_MARK

mkdir -p 'tests'
cat > 'tests/test_ingest_manual.py' <<'SIAPE_EOF_34_MARK'
from siape.ingest.base import RawObservation
from siape.ingest.manual.csv_loader import CSVConnector, persist_observations
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
SIAPE_EOF_34_MARK

mkdir -p 'tests'
cat > 'tests/test_reports.py' <<'SIAPE_EOF_35_MARK'
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
SIAPE_EOF_35_MARK

mkdir -p 'tests'
cat > 'tests/test_storage.py' <<'SIAPE_EOF_36_MARK'
from siape.storage.models import Actor, Fuente, Observacion


def test_crear_actor(db_session):
    actor = Actor(nombre="Tonanzin Fernández", cargo_actual="Presidenta municipal", es_principal=True)
    db_session.add(actor)
    db_session.commit()

    guardado = db_session.query(Actor).filter_by(nombre="Tonanzin Fernández").one()
    assert guardado.es_principal is True
    assert guardado.cargo_actual == "Presidenta municipal"


def test_observacion_requiere_fuente_y_confianza(db_session):
    fuente = Fuente(nombre="Boletín Ayuntamiento SPC", source_level=1, tipo="oficial")
    db_session.add(fuente)
    db_session.flush()

    observacion = Observacion(
        fuente=fuente,
        tipo="mencion",
        fecha="2026-08-03",
        confianza="alto",
    )
    db_session.add(observacion)
    db_session.commit()

    guardada = db_session.query(Observacion).one()
    assert guardada.fuente.source_level == 1
    assert guardada.confianza == "alto"
    assert guardada.no_confirmado is False


def test_observacion_query_por_actor(db_session):
    actor = Actor(nombre="Adversario Ejemplo 1")
    fuente = Fuente(nombre="Medio Local Ejemplo", source_level=2, tipo="medios")
    db_session.add_all([actor, fuente])
    db_session.flush()

    db_session.add(
        Observacion(actor=actor, fuente=fuente, tipo="nota", fecha="2026-08-05", confianza="medio")
    )
    db_session.commit()

    observaciones = db_session.query(Observacion).filter_by(actor_id=actor.id).all()
    assert len(observaciones) == 1
SIAPE_EOF_36_MARK

git add -A
git commit -m "Implement Fase 0 (base) and Fase 1 (motor de análisis) of SIAPE"
git push
echo "LISTO"
