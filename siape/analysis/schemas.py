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
