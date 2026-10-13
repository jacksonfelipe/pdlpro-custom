from __future__ import annotations

import hashlib
import hmac
import io
from unittest.mock import patch

import pytest
from django.test import override_settings

from apps.server.application.journey_bridge import GetJourneyBridgeStatusUseCase
from apps.server.domain.character_edit import (
    EnchantedSkillTransfer,
    SubclassDisposition,
)
from apps.server.domain.exceptions import CharacterServiceUnavailableError
from apps.server.infrastructure.journey_bridge import JourneyCharacterEditBridge


class _FakeConnection:
    def __init__(self, response: bytes = b"OK pong\n") -> None:
        self.response = response
        self.payload = b""

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback) -> None:
        return None

    def sendall(self, payload: bytes) -> None:
        self.payload = payload

    def makefile(self, mode: str):
        assert mode == "rb"
        return io.BytesIO(self.response)


@override_settings(
    LINEAGE_JOURNEY_BRIDGE_HOST="127.0.0.1",
    LINEAGE_JOURNEY_BRIDGE_PORT=15433,
    LINEAGE_JOURNEY_BRIDGE_SECRET="test-secret",
)
def test_ping_signs_a_command_and_reports_a_connected_bridge():
    connection = _FakeConnection()
    with patch("apps.server.infrastructure.journey_bridge.socket.create_connection", return_value=connection):
        result = GetJourneyBridgeStatusUseCase(JourneyCharacterEditBridge()).execute()

    timestamp, nonce, command, character_id, signature = connection.payload.decode().strip().split("|")
    signed = f"{timestamp}|{nonce}|{command}|{character_id}"
    expected = hmac.new(b"test-secret", signed.encode(), hashlib.sha256).hexdigest()
    assert command == "PING"
    assert character_id == "1"
    assert hmac.compare_digest(signature, expected)
    assert result == {"configured": True, "connected": True}


@override_settings(LINEAGE_JOURNEY_BRIDGE_SECRET="")
def test_ping_refuses_to_run_without_a_configured_secret():
    with pytest.raises(CharacterServiceUnavailableError):
        JourneyCharacterEditBridge().ping()


@override_settings(LINEAGE_JOURNEY_BRIDGE_SECRET="test-secret")
def test_bridge_rejects_commands_outside_the_explicit_protocol():
    with pytest.raises(ValueError, match="inválido"):
        JourneyCharacterEditBridge().command("CLASS_CHANGE", 1)


@override_settings(LINEAGE_JOURNEY_BRIDGE_SECRET="test-secret")
def test_ping_exposes_a_core_rejection_as_a_domain_error():
    connection = _FakeConnection(b"ERROR unauthorized\n")
    with (
        patch("apps.server.infrastructure.journey_bridge.socket.create_connection", return_value=connection),
        pytest.raises(CharacterServiceUnavailableError),
    ):
        JourneyCharacterEditBridge().ping()


@override_settings(LINEAGE_JOURNEY_BRIDGE_SECRET="test-secret")
def test_transfer_is_signed_with_both_expected_accounts():
    connection = _FakeConnection(b"OK transferred\n")
    with patch("apps.server.infrastructure.journey_bridge.socket.create_connection", return_value=connection):
        JourneyCharacterEditBridge().transfer_character(
            77,
            from_account="seller_01",
            to_account="MARKETPLACE_SYSTEM",
        )

    timestamp, nonce, command, character_id, signature = connection.payload.decode().strip().split("|")
    signed = f"{timestamp}|{nonce}|{command}|{character_id}"
    expected = hmac.new(b"test-secret", signed.encode(), hashlib.sha256).hexdigest()
    assert command == "TRANSFER:seller_01:MARKETPLACE_SYSTEM"
    assert character_id == "77"
    assert hmac.compare_digest(signature, expected)


@override_settings(LINEAGE_JOURNEY_BRIDGE_SECRET="test-secret")
def test_transfer_rejects_account_text_that_cannot_be_encoded_in_the_protocol():
    with pytest.raises(ValueError, match="inválida"):
        JourneyCharacterEditBridge().transfer_character(77, from_account="seller:admin", to_account="buyer")


@override_settings(LINEAGE_JOURNEY_BRIDGE_SECRET="test-secret")
def test_base_class_change_is_signed_with_only_the_bounded_protocol_fields():
    connection = _FakeConnection(b"OK class_changed\n")
    with patch("apps.server.infrastructure.journey_bridge.socket.create_connection", return_value=connection):
        JourneyCharacterEditBridge().change_base_class(
            77,
            target_class_id=107,
            disposition=SubclassDisposition.RESERVE,
            transfers=(EnchantedSkillTransfer(1001, 2001, 7),),
        )

    _, _, command, character_id, _ = connection.payload.decode().strip().split("|")
    assert character_id == "77"
    assert command == "BASECLASS:107:RESERVE:1001,2001,7"


@override_settings(LINEAGE_JOURNEY_BRIDGE_SECRET="test-secret")
def test_base_class_preview_parses_only_the_core_skill_list():
    connection = _FakeConnection(b"OK class_skills:1001,3;1002,4\n")
    with patch("apps.server.infrastructure.journey_bridge.socket.create_connection", return_value=connection):
        skills = JourneyCharacterEditBridge().preview_base_class_skills(77, target_class_id=107)

    assert skills == ((1001, 3), (1002, 4))
    assert "PREVIEWCLASS:107" in connection.payload.decode()
