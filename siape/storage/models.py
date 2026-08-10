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
