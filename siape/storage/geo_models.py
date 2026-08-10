"""Modelos geo (Fase 5, opcional): secciones electorales y colonias.

Usan cartografía PÚBLICA del INE — nunca datos de otros sistemas
(CLAUDE.md, "Proyecto autónomo"). Solo disponibles en PostgreSQL/PostGIS;
el fallback de desarrollo (SQLite) no tiene esta capa (README, Stack).

No se modifica el esquema de `Observacion` (Fase 0): el vínculo geográfico
es una tabla puente opcional, para no acoplar las fases anteriores a esta
capa opcional.
"""
from __future__ import annotations

from geoalchemy2 import Geometry
from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from siape.storage.models import Base


class SeccionElectoral(Base):
    __tablename__ = "secciones_electorales"

    id: Mapped[int] = mapped_column(primary_key=True)
    clave_ine: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    nombre: Mapped[str | None] = mapped_column(String)
    municipio: Mapped[str | None] = mapped_column(String)
    geom = mapped_column(Geometry(geometry_type="MULTIPOLYGON", srid=4326), nullable=False)

    colonias: Mapped[list["Colonia"]] = relationship(back_populates="seccion")


class Colonia(Base):
    __tablename__ = "colonias"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String, nullable=False)
    seccion_id: Mapped[int | None] = mapped_column(ForeignKey("secciones_electorales.id"))
    geom = mapped_column(Geometry(geometry_type="POLYGON", srid=4326), nullable=False)

    seccion: Mapped[SeccionElectoral | None] = relationship(back_populates="colonias")


class ObservacionSeccion(Base):
    """Vínculo opcional: en qué sección electoral ocurrió una observación."""

    __tablename__ = "observacion_seccion"

    observacion_id: Mapped[int] = mapped_column(ForeignKey("observaciones.id"), primary_key=True)
    seccion_id: Mapped[int] = mapped_column(ForeignKey("secciones_electorales.id"), primary_key=True)
