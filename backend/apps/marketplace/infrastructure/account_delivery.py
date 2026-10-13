"""Adaptador do evento de vínculo de conta para a entrega de compras pendentes."""

from __future__ import annotations

from uuid import UUID

from apps.marketplace.application.use_cases import (
    DeliverPendingMarketplacePurchasesInput,
    DeliverPendingMarketplacePurchasesUseCase,
)
from common.di.container import Container
from common.hooks import HookEvent, HookNames, IHookHandler


class MarketplaceAccountLinkedHandler(IHookHandler):
    """Aciona entrega pós-compra somente depois de o vínculo do jogo confirmar."""

    names = frozenset({HookNames.ACCOUNT_LINKED})

    def __init__(self, container: Container) -> None:
        self._container = container

    def handle(self, event: HookEvent) -> None:
        """Ignora eventos malformados; o evento válido vem dos casos de uso de conta."""

        try:
            buyer_id = UUID(str(event.payload["user_id"]))
            login = str(event.payload["login"]).strip()
        except (KeyError, TypeError, ValueError):
            return
        if not login:
            return
        scope = self._container.create_scope()
        scope.resolve(DeliverPendingMarketplacePurchasesUseCase).execute(
            DeliverPendingMarketplacePurchasesInput(buyer_id=buyer_id, login=login)
        )
