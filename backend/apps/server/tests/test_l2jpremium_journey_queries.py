"""Contracts for the inspected L2J Premium and Journey database schemas.

The tests load only the PDL SQL catalogs. They never connect to or mutate the
source databases used to derive the dialects.
"""

import pytest

from apps.server.domain.exceptions import CharacterServiceUnavailableError
from apps.server.infrastructure.lineage.catalog import LineageQueryCatalog
from apps.server.infrastructure.sqlalchemy_gateway import SqlAlchemyLineageGateway


@pytest.mark.parametrize("dialect", ("l2jpremium", "l2journey"))
def test_catalog_loads_the_required_read_and_inventory_contract(dialect):
    catalog = LineageQueryCatalog.load(dialect)

    assert set(catalog.REQUIRED) <= catalog._statements.keys()
    assert "charId AS char_id" in catalog["list_characters"]
    assert "object_id" in catalog["delete_item_stack"]
    assert "loc IN ('INVENTORY', 'WAREHOUSE')" in catalog["update_item_amount"]
    assert "accessLevel" in catalog["set_account_access_level"]


def test_l2jpremium_uses_the_verified_web_delivery_queue_without_enchant_loss():
    catalog = LineageQueryCatalog.load("l2jpremium")

    assert catalog.has("deposit_item")
    assert "web_item_delivery" in catalog["deposit_item"]
    assert ":enchant = 0" in catalog["deposit_item"]


def test_l2journey_uses_the_verified_custom_mail_queue():
    catalog = LineageQueryCatalog.load("l2journey")
    gateway = SqlAlchemyLineageGateway(catalog)

    assert catalog.has("deposit_item")
    assert "custom_mail" in catalog["deposit_item"]
    assert "receiver" in catalog["deposit_item"]
    assert "delivery_character" in catalog._statements
    assert catalog.has("online_delivery_ready")
    with pytest.raises(RuntimeError, match="fila de entrega transacional"):
        gateway.assert_exchange_ready()



def test_dialects_without_an_inspected_character_creation_contract_fail_closed():
    gateway = SqlAlchemyLineageGateway(LineageQueryCatalog.load("l2journey"))

    with pytest.raises(CharacterServiceUnavailableError, match="Criação de personagem"):
        gateway.create_character("journey", "NewCharacter", 0, 0, 0)
