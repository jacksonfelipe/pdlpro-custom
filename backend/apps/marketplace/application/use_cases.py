from __future__ import annotations

from dataclasses import asdict, dataclass
from decimal import Decimal
from uuid import UUID

from django.conf import settings

from apps.auction.domain.repositories import IAuctionRepository
from apps.marketplace.domain.entities import CharacterListingEntity
from apps.marketplace.domain.exceptions import (
    CannotBuyOwnListingError,
    CharacterAlreadyListedError,
    CharacterSlotLimitError,
    InvalidListingPriceError,
    ListingNotForSaleError,
    ListingNotFoundError,
)
from apps.marketplace.domain.repositories import ICharacterListingRepository
from apps.server.domain.access import IAccountAccessService, same_linked_user
from apps.server.domain.character_edit import ICharacterCustodyService
from apps.server.domain.exceptions import (
    CharacterOfflineRequiredError,
    GameAccountNotFoundError,
)
from apps.server.domain.gateways import ILineageGateway
from apps.wallet.domain.entities import InsufficientBalanceError
from apps.wallet.domain.repositories import IWalletRepository
from common.architecture.base import UnitOfWork, UseCase
from common.architecture.exceptions import AuthorizationError


class ListPublicListingsUseCase(UseCase[None, list[CharacterListingEntity]]):
    """Lista os anúncios de personagens que ainda estão disponíveis para compra.

    Uso: resolva pelo container e chame ``execute(data)`` com ``None`` (ou omita o argumento). O
    retorno é ``list[CharacterListingEntity]``.
    """

    def __init__(self, listings: ICharacterListingRepository) -> None:
        self._listings = listings

    def execute(self, data: None = None) -> list[CharacterListingEntity]:
        return self._listings.list_for_sale()


@dataclass(frozen=True, slots=True)
class ListMyListingsInput:
    """Dados de entrada de ``ListMyListingsUseCase.execute``.

    Construa após validar a requisição. A dataclass transporta os campos abaixo, mas não valida
    permissões nem regras de negócio por conta própria. Os dados de identidade do ator devem vir
    da sessão autenticada.
    """

    user_id: UUID


class ListMyListingsUseCase(UseCase[ListMyListingsInput, list[CharacterListingEntity]]):
    """Lista anúncios pertencentes ao vendedor informado, incluindo seu estado atual.

    Uso: resolva pelo container e chame ``execute(data)`` com ``ListMyListingsInput``. O retorno
    é ``list[CharacterListingEntity]``.
    """

    def __init__(self, listings: ICharacterListingRepository) -> None:
        self._listings = listings

    def execute(self, data: ListMyListingsInput) -> list[CharacterListingEntity]:
        return self._listings.list_by_seller(data.user_id)


@dataclass(frozen=True, slots=True)
class CreateListingInput:
    """Dados de entrada de ``CreateListingUseCase.execute``.

    Construa após validar a requisição. A dataclass transporta os campos abaixo, mas não valida
    permissões nem regras de negócio por conta própria. Os dados de identidade do ator devem vir
    da sessão autenticada. Use Decimal para valores monetários, evitando conversão intermediária
    por float.
    """

    user_id: UUID
    username: str
    login: str
    char_id: int
    price: Decimal
    notes: str = ""


class CreateListingUseCase(UseCase[CreateListingInput, CharacterListingEntity]):
    """Valida preço, acesso e personagem offline, captura equipamentos, bag/warehouse e
    skills, e transfere o personagem à conta de custódia antes de criar o anúncio.

    Uso: resolva pelo container e chame ``execute(data)`` com ``CreateListingInput``. O retorno
    é ``CharacterListingEntity``.
    """

    def __init__(
        self,
        listings: ICharacterListingRepository,
        auctions: IAuctionRepository,
        lineage: ILineageGateway,
        custody: ICharacterCustodyService,
        access: IAccountAccessService,
        unit_of_work: UnitOfWork,
    ) -> None:
        self._listings = listings
        self._auctions = auctions
        self._lineage = lineage
        self._custody = custody
        self._access = access
        self._unit_of_work = unit_of_work

    def execute(self, data: CreateListingInput) -> CharacterListingEntity:
        if data.price <= 0:
            raise InvalidListingPriceError()
        login = data.login or data.username
        if not self._access.can_access(data.user_id, data.username, login):
            raise AuthorizationError()
        char = self._lineage.get_character(login, data.char_id)
        if char is None:
            raise GameAccountNotFoundError("Personagem não encontrado nesta conta.")
        if char.online:
            raise CharacterOfflineRequiredError()
        if self._listings.find_active_by_char(data.char_id):
            raise CharacterAlreadyListedError()
        if self._auctions.find_open_character_auction(data.char_id):
            raise CharacterAlreadyListedError()
        equipment = [asdict(item) for item in self._lineage.list_character_equipment(char.char_id)]
        bag_items = [asdict(item) for item in self._lineage.list_character_items(char.char_id)]
        skills = [asdict(skill) for skill in self._lineage.list_character_skills(char.char_id)]
        master = getattr(settings, "MARKETPLACE_MASTER_ACCOUNT", "MARKETPLACE_SYSTEM")
        in_custody = False
        try:
            with self._unit_of_work:
                self._custody.place_in_custody(data.char_id, from_account=login, custody_account=master)
                in_custody = True
                return self._listings.create(
                    data.user_id,
                    char_id=char.char_id,
                    char_name=char.name,
                    char_level=char.level,
                    char_class=char.class_id,
                    char_title=char.title,
                    char_sex=char.sex,
                    char_pvp=char.pvp,
                    char_pk=char.pk,
                    char_clan_name=char.clan_name,
                    char_is_clan_leader=char.is_clan_leader,
                    equipment=equipment,
                    bag_items=bag_items,
                    skills=skills,
                    old_account=login,
                    price=data.price,
                    notes=data.notes,
                )
        except Exception:
            if in_custody:
                self._custody.release_from_custody(
                    data.char_id, custody_account=master, to_account=login
                )
                self._custody.unlock_character(data.char_id)
            raise


@dataclass(frozen=True, slots=True)
class PurchaseListingInput:
    """Dados de entrada de ``PurchaseListingUseCase.execute``.

    Construa após validar a requisição. A dataclass transporta os campos abaixo, mas não valida
    permissões nem regras de negócio por conta própria. Os dados de identidade do ator devem vir
    da sessão autenticada.
    """

    buyer_id: UUID
    buyer_username: str
    listing_id: UUID
    destination_login: str = ""


class PurchaseListingUseCase(UseCase[PurchaseListingInput, CharacterListingEntity]):
    """Valida anúncio, comprador, slots e custódia; reivindica o anúncio com
    compare-and-set, debita o comprador, credita o vendedor e transfere o personagem.
    A reivindicação ocorre antes do dinheiro e do gateway: o perdedor da corrida não
    movimenta saldo. O gateway do jogo não participa do rollback do Django.

    Uso: resolva pelo container e chame ``execute(data)`` com ``PurchaseListingInput``. O
    retorno é ``CharacterListingEntity``.
    """

    def __init__(
        self,
        listings: ICharacterListingRepository,
        lineage: ILineageGateway,
        custody: ICharacterCustodyService,
        access: IAccountAccessService,
        wallets: IWalletRepository,
        unit_of_work: UnitOfWork,
    ) -> None:
        self._listings = listings
        self._lineage = lineage
        self._custody = custody
        self._access = access
        self._wallets = wallets
        self._unit_of_work = unit_of_work

    def execute(self, data: PurchaseListingInput) -> CharacterListingEntity:
        transferred = False
        destination = ""
        listing = None
        master = getattr(settings, "MARKETPLACE_MASTER_ACCOUNT", "MARKETPLACE_SYSTEM")
        try:
            with self._unit_of_work:
                listing = self._listings.get_by_id(data.listing_id, lock=True)
                if listing is None:
                    raise ListingNotFoundError()
                if listing.status != "for_sale":
                    raise ListingNotForSaleError()
                if listing.seller_id == data.buyer_id:
                    raise CannotBuyOwnListingError()
                if not self._lineage.verify_character_ownership(listing.char_id, master):
                    raise ListingNotForSaleError("Personagem não está na conta do marketplace.")
                accounts = self._access.list_accounts(data.buyer_id, data.buyer_username)
                requested = data.destination_login.strip()
                if requested:
                    selected = next((account for account in accounts if account.login.lower() == requested.lower()), None)
                    if selected is None:
                        raise AuthorizationError()
                    destination = selected.login
                else:
                    primary = next((account for account in accounts if account.is_primary), None)
                    ordered = ([primary] if primary else []) + [account for account in accounts if account != primary]
                    limit = int(getattr(settings, "MAX_CHARACTERS_PER_ACCOUNT", 7))
                    destination = next(
                        (account.login for account in ordered if self._lineage.count_characters(account.login) < limit),
                        "",
                    )
                    if accounts and not destination:
                        raise CharacterSlotLimitError()
                if destination:
                    limit = int(getattr(settings, "MAX_CHARACTERS_PER_ACCOUNT", 7))
                    if self._lineage.count_characters(destination) >= limit:
                        raise CharacterSlotLimitError()
                buyer_wallet = self._wallets.get_or_create(data.buyer_id)
                if buyer_wallet.balance < listing.price:
                    raise InsufficientBalanceError()
                seller_wallet = self._wallets.get_or_create(listing.seller_id)
                sold = (
                    self._listings.mark_sold(listing.id, data.buyer_id, destination)
                    if destination
                    else self._listings.mark_pending_delivery(listing.id, data.buyer_id)
                )
                self._wallets.debit(
                    buyer_wallet.id,
                    listing.price,
                    destination=listing.seller_username,
                    description=f"Compra de personagem: {listing.char_name}",
                )
                self._wallets.credit(
                    seller_wallet.id,
                    listing.price,
                    origin=data.buyer_username,
                    description=f"Venda de personagem: {listing.char_name}",
                )
                if destination:
                    self._custody.release_from_custody(
                        listing.char_id, custody_account=master, to_account=destination
                    )
                    transferred = True
            if destination:
                self._custody.unlock_character(sold.char_id)
            return sold
        except Exception:
            if transferred and listing is not None:
                self._custody.release_from_custody(
                    listing.char_id, custody_account=destination, to_account=master
                )
            raise


@dataclass(frozen=True, slots=True)
class DeliverPendingMarketplacePurchasesInput:
    """Conta recém-vinculada que pode receber compras quitadas em custódia."""

    buyer_id: UUID
    login: str


class DeliverPendingMarketplacePurchasesUseCase(UseCase[DeliverPendingMarketplacePurchasesInput, int]):
    """Entrega compras pendentes quando o comprador vincula uma conta Lineage válida.

    A compra já foi quitada no momento da aquisição. Esta operação só libera a
    custódia para uma conta que o gateway confirma como pertencente ao mesmo
    usuário do painel; nenhuma cobrança é repetida.
    """

    def __init__(
        self,
        listings: ICharacterListingRepository,
        lineage: ILineageGateway,
        custody: ICharacterCustodyService,
        unit_of_work: UnitOfWork,
    ) -> None:
        self._listings = listings
        self._lineage = lineage
        self._custody = custody
        self._unit_of_work = unit_of_work

    def execute(self, data: DeliverPendingMarketplacePurchasesInput) -> int:
        account = self._lineage.get_account(data.login)
        if account is None or not same_linked_user(account.linked_user_id, data.buyer_id):
            return 0
        delivered = 0
        for candidate in self._listings.list_pending_delivery(data.buyer_id):
            transferred = False
            master = getattr(settings, "MARKETPLACE_MASTER_ACCOUNT", "MARKETPLACE_SYSTEM")
            try:
                with self._unit_of_work:
                    listing = self._listings.get_by_id(candidate.id, lock=True)
                    if listing is None or listing.status != "pending_delivery" or listing.buyer_id != data.buyer_id:
                        continue
                    limit = int(getattr(settings, "MAX_CHARACTERS_PER_ACCOUNT", 7))
                    if self._lineage.count_characters(data.login) >= limit:
                        continue
                    if not self._lineage.verify_character_ownership(listing.char_id, master):
                        continue
                    self._custody.release_from_custody(
                        listing.char_id, custody_account=master, to_account=data.login
                    )
                    transferred = True
                    self._listings.mark_delivered(listing.id, data.login)
                self._custody.unlock_character(candidate.char_id)
                delivered += 1
            except Exception:
                if transferred:
                    self._custody.release_from_custody(
                        candidate.char_id, custody_account=data.login, to_account=master
                    )
                raise
        return delivered


@dataclass(frozen=True, slots=True)
class CancelListingInput:
    """Dados de entrada de ``CancelListingUseCase.execute``.

    Construa após validar a requisição. A dataclass transporta os campos abaixo, mas não valida
    permissões nem regras de negócio por conta própria. Os dados de identidade do ator devem vir
    da sessão autenticada.
    """

    user_id: UUID
    listing_id: UUID


class CancelListingUseCase(UseCase[CancelListingInput, CharacterListingEntity]):
    """Confirma o vendedor e a custódia, reivindica o cancelamento com compare-and-set e
    devolve o personagem à conta de origem. A transição de estado ocorre antes da
    transferência no jogo, para não competir com uma compra concorrente.

    Uso: resolva pelo container e chame ``execute(data)`` com ``CancelListingInput``. O retorno
    é ``CharacterListingEntity``.
    """

    def __init__(
        self,
        listings: ICharacterListingRepository,
        lineage: ILineageGateway,
        custody: ICharacterCustodyService,
        unit_of_work: UnitOfWork,
    ) -> None:
        self._listings = listings
        self._lineage = lineage
        self._custody = custody
        self._unit_of_work = unit_of_work

    def execute(self, data: CancelListingInput) -> CharacterListingEntity:
        transferred = False
        listing = None
        master = getattr(settings, "MARKETPLACE_MASTER_ACCOUNT", "MARKETPLACE_SYSTEM")
        try:
            with self._unit_of_work:
                listing = self._listings.get_by_id(data.listing_id, lock=True)
                if listing is None:
                    raise ListingNotFoundError()
                if listing.seller_id != data.user_id:
                    raise AuthorizationError()
                if listing.status != "for_sale":
                    raise ListingNotForSaleError()
                limit = int(getattr(settings, "MAX_CHARACTERS_PER_ACCOUNT", 7))
                if self._lineage.count_characters(listing.old_account) >= limit:
                    raise CharacterSlotLimitError()
                if not self._lineage.verify_character_ownership(listing.char_id, master):
                    raise ListingNotForSaleError("Personagem não está na conta do marketplace.")
                cancelled = self._listings.mark_cancelled(listing.id)
                self._custody.release_from_custody(
                    listing.char_id, custody_account=master, to_account=listing.old_account
                )
                transferred = True
            self._custody.unlock_character(cancelled.char_id)
            return cancelled
        except Exception:
            if transferred and listing is not None:
                self._custody.release_from_custody(
                    listing.char_id, custody_account=listing.old_account, to_account=master
                )
            raise
