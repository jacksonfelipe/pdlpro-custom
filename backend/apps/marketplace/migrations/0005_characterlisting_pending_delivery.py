# Generated manually for the Marketplace delivery state.

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("marketplace", "0004_characterlisting_bag_skills"),
    ]

    operations = [
        migrations.AlterField(
            model_name="characterlisting",
            name="new_account",
            field=models.CharField(blank=True, default="", max_length=45),
        ),
        migrations.AlterField(
            model_name="characterlisting",
            name="status",
            field=models.CharField(
                choices=[
                    ("for_sale", "À venda"),
                    ("pending_delivery", "Aguardando conta de jogo"),
                    ("sold", "Vendido"),
                    ("cancelled", "Cancelado"),
                    ("disputed", "Em disputa"),
                ],
                default="for_sale",
                max_length=20,
            ),
        ),
    ]
