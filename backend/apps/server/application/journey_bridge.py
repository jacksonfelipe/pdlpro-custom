"""Casos de uso de diagnóstico do canal PDL ↔ L2Journey."""

from __future__ import annotations

from apps.server.domain.character_edit import ICharacterEditBridge
from common.architecture.base import UseCase


class GetJourneyBridgeStatusUseCase(UseCase[None, dict[str, bool]]):
    """Verifica o canal autenticado sem alterar personagem ou banco do jogo."""

    def __init__(self, bridge: ICharacterEditBridge) -> None:
        self._bridge = bridge

    def execute(self, data: None = None) -> dict[str, bool]:
        self._bridge.ping()
        return {"configured": True, "connected": True}
