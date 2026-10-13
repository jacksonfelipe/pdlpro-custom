"""Authenticated loopback client for the L2Journey character-edit bridge."""

from __future__ import annotations

import hashlib
import hmac
import re
import secrets
import socket
import time

from django.conf import settings

from apps.server.domain.character_edit import (
    EnchantedSkillTransfer,
    ICharacterEditBridge,
    SubclassDisposition,
)
from apps.server.domain.exceptions import CharacterServiceUnavailableError


class JourneyCharacterEditBridge(ICharacterEditBridge):
    """Sends one signed command to the Journey core; the browser never sees the secret."""

    _ALLOWED_COMMANDS = frozenset({"PING", "LOCK", "UNLOCK", "KICK"})
    _ACCOUNT_NAME = re.compile(r"^[A-Za-z0-9_.-]{1,45}$")

    def ping(self) -> None:
        """Raises a domain error unless the locally authenticated core replies to PING."""

        self.command("PING", 1)

    def lock_character(self, character_id: int) -> None:
        self.command("LOCK", character_id)

    def unlock_character(self, character_id: int) -> None:
        self.command("UNLOCK", character_id)

    def transfer_character(self, character_id: int, *, from_account: str, to_account: str) -> None:
        if not self._ACCOUNT_NAME.fullmatch(from_account) or not self._ACCOUNT_NAME.fullmatch(to_account):
            raise ValueError("Conta de custódia inválida.")
        self.command(f"TRANSFER:{from_account}:{to_account}", character_id)

    def change_base_class(
        self,
        character_id: int,
        *,
        target_class_id: int,
        disposition: SubclassDisposition,
        transfers: tuple[EnchantedSkillTransfer, ...],
    ) -> None:
        if target_class_id < 0 or target_class_id > 999 or len(transfers) > 32:
            raise ValueError("Troca de classe inválida.")
        serialized = ";".join(
            f"{item.source_skill_id},{item.target_skill_id},{item.source_enchant}"
            for item in transfers
        ) or "-"
        self.command(
            f"BASECLASS:{target_class_id}:{disposition.value.upper()}:{serialized}",
            character_id,
        )

    def preview_base_class_skills(self, character_id: int, *, target_class_id: int) -> tuple[tuple[int, int], ...]:
        if target_class_id < 0 or target_class_id > 999:
            raise ValueError("Classe de destino inválida.")
        response = self.command(f"PREVIEWCLASS:{target_class_id}", character_id)
        prefix = "OK class_skills:"
        if not response.startswith(prefix):
            raise CharacterServiceUnavailableError("O gameserver não retornou as skills da classe.")
        raw = response.removeprefix(prefix)
        if not raw:
            return ()
        try:
            return tuple(
                (int(skill_id), int(level))
                for skill_id, level in (item.split(",", 1) for item in raw.split(";"))
            )
        except ValueError as exc:
            raise CharacterServiceUnavailableError("O gameserver retornou skills inválidas.") from exc

    def command(self, command: str, character_id: int) -> str:

        if (
            command not in self._ALLOWED_COMMANDS
            and not self._is_transfer_command(command)
            and not self._is_base_class_command(command)
            and not self._is_preview_class_command(command)
        ):
            raise ValueError("Comando de bridge inválido.")
        secret = settings.LINEAGE_JOURNEY_BRIDGE_SECRET
        if not secret:
            raise CharacterServiceUnavailableError("A ponte de edição Journey não está configurada.")
        timestamp, nonce = str(int(time.time() * 1000)), secrets.token_urlsafe(18)
        payload = f"{timestamp}|{nonce}|{command}|{int(character_id)}"
        signature = hmac.new(secret.encode(), payload.encode(), hashlib.sha256).hexdigest()
        try:
            with socket.create_connection((settings.LINEAGE_JOURNEY_BRIDGE_HOST, settings.LINEAGE_JOURNEY_BRIDGE_PORT), timeout=3) as connection:
                connection.sendall(f"{payload}|{signature}\n".encode())
                response = connection.makefile("rb").readline(8192).decode().strip()
        except OSError as exc:
            raise CharacterServiceUnavailableError("A ponte de edição Journey não está disponível.") from exc
        if not response.startswith("OK "):
            raise CharacterServiceUnavailableError("O gameserver recusou a edição do personagem.")
        return response

    def _is_transfer_command(self, command: str) -> bool:
        parts = command.split(":")
        return (
            len(parts) == 3
            and parts[0] == "TRANSFER"
            and all(self._ACCOUNT_NAME.fullmatch(account) for account in parts[1:])
        )

    @staticmethod
    def _is_base_class_command(command: str) -> bool:
        parts = command.split(":", 3)
        if len(parts) != 4 or parts[0] != "BASECLASS":
            return False
        target_class, disposition, transfers = parts[1:]
        if not target_class.isdecimal() or disposition not in {"KEEP", "DELETE", "RESERVE"}:
            return False
        if transfers == "-":
            return True
        rows = transfers.split(";")
        return len(rows) <= 32 and all(
            len(values := row.split(",")) == 3 and all(value.isdecimal() and int(value) > 0 for value in values)
            for row in rows
        )

    @staticmethod
    def _is_preview_class_command(command: str) -> bool:
        parts = command.split(":")
        return len(parts) == 2 and parts[0] == "PREVIEWCLASS" and parts[1].isdecimal()
