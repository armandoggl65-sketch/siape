from siape.analysis.schemas import Indicador
from siape.dashboard.semaforo import (
    AMARILLO,
    ROJO,
    VERDE,
    semaforo_confianza,
    semaforo_indicador,
    semaforo_variacion,
)


def test_semaforo_confianza():
    assert semaforo_confianza("alto") == VERDE
    assert semaforo_confianza("medio") == AMARILLO
    assert semaforo_confianza("bajo") == ROJO


def test_semaforo_variacion():
    assert semaforo_variacion(5.0) == VERDE
    assert semaforo_variacion(-5.0) == ROJO
    assert semaforo_variacion(0) == AMARILLO
    assert semaforo_variacion(None) == AMARILLO


def test_semaforo_indicador_prioriza_variacion_sobre_confianza():
    indicador = Indicador(kpi="x", valor=1, variacion=-2.0, confianza="alto")
    assert semaforo_indicador(indicador) == ROJO


def test_semaforo_indicador_usa_confianza_sin_variacion():
    indicador = Indicador(kpi="x", valor=1, variacion=None, confianza="bajo")
    assert semaforo_indicador(indicador) == ROJO
