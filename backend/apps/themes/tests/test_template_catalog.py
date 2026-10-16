from apps.themes.application.template_catalog import home_sections_for, is_supported_renderer


def test_hallow_verde_renderer_exposes_only_its_supported_sections():
    """O pacote Hallow Verde pode ser instalado sem liberar seções não renderizadas."""

    assert is_supported_renderer("hallowverde") is True
    assert home_sections_for("hallowverde") == (
        "hero", "stats", "news", "ranking", "features", "cta",
    )
