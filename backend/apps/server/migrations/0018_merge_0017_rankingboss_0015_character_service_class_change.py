from django.db import migrations


class Migration(migrations.Migration):
    """Unifica as linhas local de serviços e a atualização pública v2.7.4."""

    dependencies = [
        ("server", "0017_rankingboss"),
        ("server", "0015_character_service_class_change"),
    ]

    operations = []
