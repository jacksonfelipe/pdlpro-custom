import pytest

from apps.server.domain.character_edit import (
    EnchantedSkillTransfer,
    SubclassDisposition,
    validate_enchanted_skill_transfers,
    validate_subclass_disposition,
)
from common.architecture.exceptions import ValidationDomainError


def test_allows_deleting_subclasses_when_no_subclass_exists():
    validate_subclass_disposition(disposition=SubclassDisposition.DELETE, has_subclasses=False)


@pytest.mark.parametrize("disposition", [SubclassDisposition.KEEP, SubclassDisposition.RESERVE])
def test_rejects_subclass_fee_when_character_has_no_subclasses(disposition):
    with pytest.raises(ValidationDomainError, match="não possui subclasses"):
        validate_subclass_disposition(disposition=disposition, has_subclasses=False)


def test_rejects_transferring_more_enchant_than_the_original_skill_has():
    with pytest.raises(ValidationDomainError, match="maior que o da skill original"):
        validate_enchanted_skill_transfers(
            transfers=(EnchantedSkillTransfer(1001, 2001, 6),),
            available_source_enchants={1001: 5},
        )


def test_rejects_reusing_a_source_or_target_skill():
    with pytest.raises(ValidationDomainError, match="só pode participar uma vez"):
        validate_enchanted_skill_transfers(
            transfers=(
                EnchantedSkillTransfer(1001, 2001, 4),
                EnchantedSkillTransfer(1001, 2002, 4),
            ),
            available_source_enchants={1001: 4},
        )


def test_accepts_one_for_one_enchant_transfer():
    validate_enchanted_skill_transfers(
        transfers=(
            EnchantedSkillTransfer(1001, 2001, 5),
            EnchantedSkillTransfer(1002, 2002, 3),
        ),
        available_source_enchants={1001: 5, 1002: 3},
    )
