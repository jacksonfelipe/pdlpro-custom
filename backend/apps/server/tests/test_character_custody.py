from __future__ import annotations

import pytest

from apps.server.infrastructure.character_custody import JourneyCharacterCustodyService


class FakeBridge:
    def __init__(self, *, transfer_error: Exception | None = None) -> None:
        self.events: list[tuple] = []
        self.transfer_error = transfer_error

    def ping(self) -> None:
        return None

    def lock_character(self, character_id: int) -> None:
        self.events.append(("lock", character_id))

    def unlock_character(self, character_id: int) -> None:
        self.events.append(("unlock", character_id))

    def transfer_character(self, character_id: int, *, from_account: str, to_account: str) -> None:
        self.events.append(("transfer", character_id, from_account, to_account))
        if self.transfer_error:
            raise self.transfer_error


def test_journey_custody_locks_before_transferring_and_keeps_lock_for_commit():
    bridge = FakeBridge()
    custody = JourneyCharacterCustodyService(bridge)

    custody.place_in_custody(11, from_account="seller", custody_account="MARKETPLACE_SYSTEM")

    assert bridge.events == [
        ("lock", 11),
        ("transfer", 11, "seller", "MARKETPLACE_SYSTEM"),
    ]


def test_journey_custody_releases_lock_when_initial_transfer_fails():
    bridge = FakeBridge(transfer_error=RuntimeError("core unavailable"))
    custody = JourneyCharacterCustodyService(bridge)

    with pytest.raises(RuntimeError, match="core unavailable"):
        custody.place_in_custody(11, from_account="seller", custody_account="MARKETPLACE_SYSTEM")

    assert bridge.events == [
        ("lock", 11),
        ("transfer", 11, "seller", "MARKETPLACE_SYSTEM"),
        ("unlock", 11),
    ]
