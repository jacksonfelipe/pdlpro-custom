from decimal import Decimal

from django.db import migrations, models


def seed_class_change_prices(apps, schema_editor):
    ServicePrice = apps.get_model("server", "ServicePrice")
    rows = (
        ("CLASS_CHANGE_SAME_RACE", "Troca de classe (mesma raça)", Decimal("100.00")),
        ("CLASS_CHANGE_CROSS_RACE", "Troca de classe (outra raça)", Decimal("250.00")),
        ("SUBCLASS_KEEP", "Manter subclasses", Decimal("50.00")),
        ("SUBCLASS_RESERVE", "Reservar subclasses", Decimal("30.00")),
    )
    for code, name, price in rows:
        ServicePrice.objects.get_or_create(
            code=code,
            defaults={"name": name, "price": price, "active": True},
        )


class Migration(migrations.Migration):
    dependencies = [("server", "0014_indexconfig_access_controls")]

    operations = [
        migrations.AlterField(
            model_name="characterserviceoperation",
            name="value",
            field=models.CharField(max_length=1024),
        ),
        migrations.RunPython(seed_class_change_prices, migrations.RunPython.noop),
    ]
