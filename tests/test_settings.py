from config.settings import _get_secret


def test_get_secret_usa_variable_de_entorno_si_existe(monkeypatch):
    monkeypatch.setenv("SIAPE_TEST_KEY", "valor_env")
    assert _get_secret("SIAPE_TEST_KEY") == "valor_env"


def test_get_secret_cae_a_default_sin_env_ni_streamlit_secrets(monkeypatch):
    monkeypatch.delenv("SIAPE_TEST_KEY_INEXISTENTE", raising=False)
    # Sin secrets.toml en este entorno, st.secrets lanza una excepción que
    # _get_secret debe absorber devolviendo el default, sin propagarla.
    assert _get_secret("SIAPE_TEST_KEY_INEXISTENTE", "default") == "default"


def test_get_secret_sin_default_devuelve_none(monkeypatch):
    monkeypatch.delenv("SIAPE_OTRA_KEY_INEXISTENTE", raising=False)
    assert _get_secret("SIAPE_OTRA_KEY_INEXISTENTE") is None
