"""Custódia de personagens por dialeto, sem expor escrita do jogo à SPA."""

from __future__ import annotations

from apps.server.domain.character_edit import (
    ICharacterCustodyService,
    ICharacterEditBridge,
)
from apps.server.domain.gateways import ILineageGateway


class JourneyCharacterCustodyService(ICharacterCustodyService):
    """Executa a custódia no GameServer Journey autenticado.

    O bloqueio permanece ativo entre a transferência e o commit do painel; a
    aplicação só chama ``unlock_character`` depois de registrar a venda ou o
    cancelamento. Assim o personagem jamais volta à seleção durante a janela
    de negociação.
    """

    def __init__(self, bridge: ICharacterEditBridge) -> None:
        self._bridge = bridge

    def place_in_custody(self, character_id: int, *, from_account: str, custody_account: str) -> None:
        self._bridge.lock_character(character_id)
        try:
            self._bridge.transfer_character(
                character_id,
                from_account=from_account,
                to_account=custody_account,
            )
        except Exception:
            self._bridge.unlock_character(character_id)
            raise

    def release_from_custody(self, character_id: int, *, custody_account: str, to_account: str) -> None:
        self._bridge.transfer_character(
            character_id,
            from_account=custody_account,
            to_account=to_account,
        )

    def unlock_character(self, character_id: int) -> None:
        self._bridge.unlock_character(character_id)


class GatewayCharacterCustodyService(ICharacterCustodyService):
    """Compatibilidade temporária para dialetos sem bridge de gameserver.

    Esta classe não é selecionada para Journey. Ela preserva a integração
    existente dos outros dialetos enquanto cada core recebe sua própria ponte.
    """

    def __init__(self, lineage: ILineageGateway) -> None:
        self._lineage = lineage

    def place_in_custody(self, character_id: int, *, from_account: str, custody_account: str) -> None:
        self._lineage.transfer_character(character_id, custody_account, from_account=from_account)

    def release_from_custody(self, character_id: int, *, custody_account: str, to_account: str) -> None:
        self._lineage.transfer_character(character_id, to_account, from_account=custody_account)

    def unlock_character(self, character_id: int) -> None:
        return None
