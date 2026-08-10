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
