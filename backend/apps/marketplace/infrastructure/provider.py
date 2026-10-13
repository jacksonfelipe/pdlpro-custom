from django.conf import settings

from apps.marketplace.application.use_cases import (
    CancelListingUseCase,
    CreateListingUseCase,
    DeliverPendingMarketplacePurchasesUseCase,
    ListMyListingsUseCase,
    ListPublicListingsUseCase,
    PurchaseListingUseCase,
)
from apps.marketplace.domain.repositories import ICharacterListingRepository
from apps.marketplace.infrastructure.account_delivery import (
    MarketplaceAccountLinkedHandler,
)
from apps.marketplace.infrastructure.repositories import (
    DjangoCharacterListingRepository,
)
from apps.server.domain.character_edit import ICharacterCustodyService
from apps.server.infrastructure.character_custody import (
    GatewayCharacterCustodyService,
    JourneyCharacterCustodyService,
)
from common.di.container import Container
from common.di.lifetime import Lifetime
from common.di.provider import AppProvider
from common.hooks import IHookBus


class MarketplaceProvider(AppProvider):
    """Registra portas, adaptadores e casos de uso do módulo marketplace.

    O AppConfig inclui este provider no catálogo de DependencyInjection. Acrescente novos
    registros em ``register`` e escolha o lifetime conforme o estado mantido pelo serviço; views
    resolvem essas classes pelo container.
    """

    def register(self, container: Container) -> None:
        container.register(ICharacterListingRepository, DjangoCharacterListingRepository, lifetime=Lifetime.SCOPED)
        custody = (
            JourneyCharacterCustodyService
            if getattr(settings, "LINEAGE_QUERY_MODULE", "") == "l2journey"
            else GatewayCharacterCustodyService
        )
        container.register(ICharacterCustodyService, custody, lifetime=Lifetime.SCOPED)
        for use_case in (
            ListPublicListingsUseCase,
            ListMyListingsUseCase,
            CreateListingUseCase,
            PurchaseListingUseCase,
            CancelListingUseCase,
            DeliverPendingMarketplacePurchasesUseCase,
        ):
            container.register_self(use_case, lifetime=Lifetime.TRANSIENT)
        container.resolve(IHookBus).add(MarketplaceAccountLinkedHandler(container))

