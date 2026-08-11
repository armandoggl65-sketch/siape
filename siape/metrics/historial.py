"""Persistencia y comparación histórica de métricas (Sección 6: "variación vs. periodo anterior").

Separado de `build_indicadores.py`: ese módulo calcula el periodo actual "en
vivo" (usado por el tablero en cada carga). Este módulo registra *cortes*
deliberados — semanales/quincenales, según la periodicidad del prompt de
analista (Sección 7.6) — y calcula la variación real contra el corte
anterior. No se registra un corte automáticamente en cada render del
tablero: eso inflaría `metricas` con duplicados sin valor.
"""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from siape.analysis.schemas import Indicador
from siape.metrics.build_indicadores import construir_indicadores
from siape.storage.models import Metrica


def valor_ultimo_corte(
    session: Session, actor_id: int, kpi: str, antes_de: str
) -> float | None:
    """Último valor registrado de `kpi` para el actor, en un corte anterior a `antes_de`."""
    stmt = (
        select(Metrica.valor)
        .where(Metrica.actor_id == actor_id, Metrica.kpi == kpi, Metrica.fecha_corte < antes_de)
        .order_by(Metrica.fecha_corte.desc())
        .limit(1)
    )
    return session.scalar(stmt)


def calcular_variacion(valor_actual: float, valor_anterior: float | None) -> float | None:
    """% de cambio contra el corte anterior. None si no hay corte previo o este era 0."""
    if valor_anterior is None or valor_anterior == 0:
        return None
    return round((valor_actual - valor_anterior) / abs(valor_anterior) * 100, 2)


def enriquecer_con_variacion(
    session: Session, actor_id: int, indicadores: list[Indicador], fecha_corte: str
) -> list[Indicador]:
    """Copia los indicadores agregando `variacion` contra el último corte registrado."""
    enriquecidos = []
    for ind in indicadores:
        anterior = valor_ultimo_corte(session, actor_id, ind.kpi, fecha_corte)
        variacion = calcular_variacion(ind.valor, anterior)
        enriquecidos.append(ind.model_copy(update={"variacion": variacion}))
    return enriquecidos


def registrar_corte(
    session: Session, actor_id: int, indicadores: list[Indicador], fecha_corte: str
) -> list[Metrica]:
    """Guarda un snapshot de los indicadores como el corte oficial de `fecha_corte`."""
    registros = []
    for ind in indicadores:
        metrica = Metrica(
            actor_id=actor_id,
            kpi=ind.kpi,
            valor=ind.valor,
            variacion=ind.variacion,
            confianza=ind.confianza,
            fecha_corte=fecha_corte,
        )
        session.add(metrica)
        registros.append(metrica)
    session.commit()
    return registros


def construir_indicadores_con_historial(
    session: Session,
    actor_id: int,
    fecha_inicio: str,
    fecha_fin: str,
    fecha_corte: str,
    tipo_seguidores: str = "seguidores",
) -> list[Indicador]:
    """Indicadores del periodo, con `variacion` real contra el último corte registrado.

    No persiste nada — es de solo lectura, apta para el tablero. Para cerrar
    un periodo y dejarlo disponible como referencia futura, llamar aparte a
    `registrar_corte` con el resultado.
    """
    indicadores = construir_indicadores(session, actor_id, fecha_inicio, fecha_fin, tipo_seguidores)
    return enriquecer_con_variacion(session, actor_id, indicadores, fecha_corte)
