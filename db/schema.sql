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
