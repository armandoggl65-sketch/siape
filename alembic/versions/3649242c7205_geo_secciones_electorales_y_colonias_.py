"""geo: secciones electorales y colonias (Fase 5, opcional)

Revision ID: 3649242c7205
Revises: e9d32eef416a
Create Date: 2026-08-10 15:13:09.912371

Esta capa solo aplica a PostgreSQL/PostGIS. El fallback de desarrollo
(SQLite) no soporta columnas de geometría, así que upgrade()/downgrade()
se saltan por completo en cualquier otro dialecto (CLAUDE.md, README →
Stack: "Fallback de desarrollo: SQLite, sin capa geográfica").

NOTA 1: `spatial_ref_sys` es una tabla del sistema creada por `CREATE EXTENSION
postgis`, no por nuestros modelos. Autogenerate la detecta como "removida"
por comparación ingenua contra Base.metadata; se ignora deliberadamente
para no borrar una tabla del propio PostGIS.

NOTA 2: no se llama a `op.create_index`/`op.drop_index` para los índices
espaciales — GeoAlchemy2 los crea y elimina automáticamente (columna
`Geometry(..., spatial_index=True)` por defecto) al crear/eliminar la tabla.
Hacerlo explícito además duplica el índice y falla con "already exists".
"""
from typing import Sequence, Union

import geoalchemy2
import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = '3649242c7205'
down_revision: Union[str, Sequence[str], None] = 'e9d32eef416a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    if op.get_bind().dialect.name != "postgresql":
        return

    op.create_table(
        'secciones_electorales',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('clave_ine', sa.String(), nullable=False),
        sa.Column('nombre', sa.String(), nullable=True),
        sa.Column('municipio', sa.String(), nullable=True),
        sa.Column('geom', geoalchemy2.types.Geometry(geometry_type='MULTIPOLYGON', srid=4326), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('clave_ine'),
    )

    op.create_table(
        'colonias',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('nombre', sa.String(), nullable=False),
        sa.Column('seccion_id', sa.Integer(), nullable=True),
        sa.Column('geom', geoalchemy2.types.Geometry(geometry_type='POLYGON', srid=4326), nullable=False),
        sa.ForeignKeyConstraint(['seccion_id'], ['secciones_electorales.id']),
        sa.PrimaryKeyConstraint('id'),
    )

    op.create_table(
        'observacion_seccion',
        sa.Column('observacion_id', sa.Integer(), nullable=False),
        sa.Column('seccion_id', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['observacion_id'], ['observaciones.id']),
        sa.ForeignKeyConstraint(['seccion_id'], ['secciones_electorales.id']),
        sa.PrimaryKeyConstraint('observacion_id', 'seccion_id'),
    )


def downgrade() -> None:
    if op.get_bind().dialect.name != "postgresql":
        return

    op.drop_table('observacion_seccion')
    op.drop_table('colonias')
    op.drop_table('secciones_electorales')
