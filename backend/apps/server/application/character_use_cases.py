from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

from apps.server.application.paid_services import execute_paid_service
from apps.server.domain.access import IAccountAccessService
from apps.server.domain.appearance import (
    appearance_catalog,
    appearance_value,
    parse_appearance,
)
from apps.server.domain.character_edit import (
    EnchantedSkillTransfer,
    ICharacterEditBridge,
    SubclassDisposition,
    validate_enchanted_skill_transfers,
)
from apps.server.domain.class_catalog import available_class_ids, class_race
from apps.server.domain.exceptions import CharacterServiceUnavailableError
from apps.server.domain.gateways import ILineageGateway
from apps.server.domain.repositories import (
    ICharacterServiceOperationRepository,
    IIndexConfigRepository,
    ILinkSlotRepository,
    IServicePriceRepository,
)
from apps.server.domain.services import TAVERN_SERVICES
from apps.server.domain.skill_catalog import ISkillCatalog
from apps.server.domain.towns import get_town, town_catalog
from apps.server.domain.unstuck import normalize_unstuck
from apps.wallet.domain.repositories import IWalletRepository
from common.architecture.base import UnitOfWork, UseCase
from common.architecture.exceptions import (
    AuthorizationError,
    ConflictError,
    ValidationDomainError,
)

_NICK_MIN, _NICK_MAX = 2, 16


@dataclass(frozen=True, slots=True)
class CharacterServiceInput:
    """Identifica usuário, conta e personagem para a execução de serviços no jogo.

    Construa após validar a requisição. A dataclass transporta os campos abaixo, mas não valida
    permissões nem regras de negócio por conta própria. Os dados de identidade do ator devem vir
    da sessão autenticada.
    """

    user_id: UUID
    username: str
    login: str
    char_id: int
    request_key: UUID | None = None


@dataclass(frozen=True, slots=True)
class ChangeBaseClassInput:
    """Pedido de troca de classe-base processado exclusivamente pelo core Journey."""

    actor: CharacterServiceInput
    target_class_id: int
    disposition: SubclassDisposition
    transfers: tuple[EnchantedSkillTransfer, ...]


@dataclass(frozen=True, slots=True)
class PreviewBaseClassSkillsInput:
    """Consulta autenticada das skills que o core aceita para uma classe alvo."""

    actor: CharacterServiceInput
    target_class_id: int


class ChangeNicknameUseCase(UseCase[tuple[CharacterServiceInput, str], None]):
    """Verifica acesso e nome, reserva o saldo e então altera o personagem.

    A reserva é durável antes da chamada ao jogo. Respostas incertas exigem conciliação;
    repetir a chave não reaplica a operação nem cobra novamente.

    Uso: resolva pelo container e chame ``execute(data)`` com ``tuple[CharacterServiceInput,
    str]``. O retorno é ``None``.
    """

    def __init__(
        self,
        lineage: ILineageGateway,
        access: IAccountAccessService,
        prices: IServicePriceRepository,
        wallets: IWalletRepository,
        operations: ICharacterServiceOperationRepository,
        unit_of_work: UnitOfWork,
    ) -> None:
        self._lineage = lineage
        self._access = access
        self._prices = prices
        self._wallets = wallets
        self._operations = operations
        self._unit_of_work = unit_of_work

    def execute(self, data: tuple[CharacterServiceInput, str]) -> None:
        actor, name = data
        self._assert_access(actor)
        cleaned = name.strip()
        if not cleaned.isalnum() or not (_NICK_MIN <= len(cleaned) <= _NICK_MAX):
            raise ValidationDomainError("Nick inválido. Use 2 a 16 letras ou números.")
        price = self._prices.get_price("CHANGE_NICKNAME")
        execute_paid_service(
            actor,
            service="CHANGE_NICKNAME",
            value=cleaned,
            price=price,
            lineage=self._lineage,
            access=self._access,
            wallets=self._wallets,
            operations=self._operations,
            unit_of_work=self._unit_of_work,
        )

    def _assert_access(self, actor: CharacterServiceInput) -> None:
        if not self._access.can_access(actor.user_id, actor.username, actor.login):
            raise AuthorizationError()


class ChangeSexUseCase(UseCase[tuple[CharacterServiceInput, str], None]):
    """Verifica acesso e sexo, reserva o saldo e então chama o gateway.

    Repetições são deduplicadas; uma resposta incerta mantém a reserva para conciliação.

    Uso: resolva pelo container e chame ``execute(data)`` com ``tuple[CharacterServiceInput,
    str]``. O retorno é ``None``.
    """

    def __init__(
        self,
        lineage: ILineageGateway,
        access: IAccountAccessService,
        prices: IServicePriceRepository,
        wallets: IWalletRepository,
        operations: ICharacterServiceOperationRepository,
        unit_of_work: UnitOfWork,
    ) -> None:
        self._lineage = lineage
        self._access = access
        self._prices = prices
        self._wallets = wallets
        self._operations = operations
        self._unit_of_work = unit_of_work

    def execute(self, data: tuple[CharacterServiceInput, str]) -> None:
        actor, sex_label = data
        if not self._access.can_access(actor.user_id, actor.username, actor.login):
            raise AuthorizationError()
        sex = 0 if sex_label.upper() == "M" else 1
        if sex_label.upper() not in {"M", "F"}:
            raise ValidationDomainError("Sexo deve ser M ou F.")
        price = self._prices.get_price("CHANGE_SEX")
        execute_paid_service(
            actor,
            service="CHANGE_SEX",
            value=str(sex),
            price=price,
            lineage=self._lineage,
            access=self._access,
            wallets=self._wallets,
            operations=self._operations,
            unit_of_work=self._unit_of_work,
        )


class UnstuckCharacterUseCase(UseCase[CharacterServiceInput, None]):
    """Reposiciona um personagem por meio do gateway após verificar acesso à conta.

    Chame execute com CharacterServiceInput. Este serviço não debita a carteira;
    ListServicePricesUseCase informa UNSTUCK como gratuito. O gateway verifica as condições do
    personagem e o retorno é None. O destino é lido da configuração ativa do admin;
    None preserva o padrão do adaptador.
    """

    def __init__(self, lineage: ILineageGateway, access: IAccountAccessService, index_config: IIndexConfigRepository) -> None:
        self._lineage = lineage
        self._access = access
        self._index_config = index_config

    def execute(self, data: CharacterServiceInput) -> None:
        if not self._access.can_access(data.user_id, data.username, data.login):
            raise AuthorizationError()
        config = self._index_config.get_active()
        location = normalize_unstuck(getattr(config, "unstuck_location", None))
        self._lineage.unstuck(data.login, data.char_id, location)


@dataclass(frozen=True, slots=True)
class PurchaseLinkSlotInput:
    """Dados de entrada de ``PurchaseLinkSlotUseCase.execute``.

    Construa após validar a requisição. A dataclass transporta os campos abaixo, mas não valida
    permissões nem regras de negócio por conta própria. Os dados de identidade do ator devem vir
    da sessão autenticada.
    """

    user_id: UUID
    quantity: int


class ListServicePricesUseCase(UseCase[None, dict]):
    """Lista preços, destinos e serviços da taverna disponíveis neste servidor.

    Uso: resolva pelo container e chame ``execute(data)`` com ``None`` (ou omita o argumento). O
    retorno é ``dict``.
    """

    def __init__(self, prices: IServicePriceRepository, lineage: ILineageGateway) -> None:
        self._prices = prices
        self._lineage = lineage

    def execute(self, data: None = None) -> dict:
        rows = {row.code: row for row in self._prices.list_all()}
        payload = {
            "CHANGE_NICKNAME": str(self._prices.get_price("CHANGE_NICKNAME")),
            "CHANGE_SEX": str(self._prices.get_price("CHANGE_SEX")),
            "LINK_SLOT": str(self._prices.get_price("LINK_SLOT")),
            "UNSTUCK": "0.00",
            "available": ["CHANGE_NICKNAME", "CHANGE_SEX", "UNSTUCK", "LINK_SLOT"],
            "catalog": {"towns": town_catalog(), "appearance": appearance_catalog()},
        }
        for code in TAVERN_SERVICES:
            if not self._lineage.supports(code):
                continue
            row = rows.get(code)
            if row is not None and not row.active:
                continue
            payload[code] = str(row.price if row else self._prices.get_price(code))
            payload["available"].append(code)
        class_price_codes = (
            "CLASS_CHANGE_SAME_RACE",
            "CLASS_CHANGE_CROSS_RACE",
            "SUBCLASS_KEEP",
            "SUBCLASS_RESERVE",
        )
        class_prices = {item.code: item for item in self._prices.list_all()}
        if all(class_prices.get(code) is not None and class_prices[code].active for code in class_price_codes):
            payload.update({code: str(class_prices[code].price) for code in class_price_codes})
            payload["available"].append("CHANGE_BASE_CLASS")
            payload["catalog"]["class_change"] = {"class_ids": available_class_ids()}
        return payload


def _require_priced_service(prices: IServicePriceRepository, lineage: ILineageGateway, code: str):
    if not lineage.supports(code):
        raise CharacterServiceUnavailableError()
    row = next((item for item in prices.list_all() if item.code == code), None)
    if row is not None and not row.active:
        raise CharacterServiceUnavailableError()
    return prices.get_price(code)


class PurchaseLinkSlotUseCase(UseCase[PurchaseLinkSlotInput, dict]):
    """Compra de 1 a 10 slots adicionais para vincular contas Lineage.

    Recebe PurchaseLinkSlotInput, calcula o preço total, debita a carteira e acrescenta os slots
    dentro do mesmo UnitOfWork. Retorna extra_slots e paid.
    """

    def __init__(
        self,
        prices: IServicePriceRepository,
        slots: ILinkSlotRepository,
        wallets: IWalletRepository,
        unit_of_work: UnitOfWork,
    ) -> None:
        self._prices = prices
        self._slots = slots
        self._wallets = wallets
        self._unit_of_work = unit_of_work

    def execute(self, data: PurchaseLinkSlotInput) -> dict:
        if data.quantity < 1 or data.quantity > 10:
            raise ValidationDomainError("Compre entre 1 e 10 slots.")
        unit = self._prices.get_price("LINK_SLOT")
        total = unit * data.quantity
        with self._unit_of_work:
            wallet = self._wallets.get_or_create(data.user_id)
            self._wallets.debit(wallet.id, total, destination="link-slot", description=f"{data.quantity} slot(s)")
            extra = self._slots.add_slots(data.user_id, data.quantity)
        return {"extra_slots": extra, "paid": str(total)}


class TeleportCharacterUseCase(UseCase[tuple[CharacterServiceInput, str], None]):
    """Cobra o teleporte e move o personagem offline para a vila escolhida."""

    def __init__(
        self,
        lineage: ILineageGateway,
        access: IAccountAccessService,
        prices: IServicePriceRepository,
        wallets: IWalletRepository,
        operations: ICharacterServiceOperationRepository,
        unit_of_work: UnitOfWork,
    ) -> None:
        self._lineage = lineage
        self._access = access
        self._prices = prices
        self._wallets = wallets
        self._operations = operations
        self._unit_of_work = unit_of_work

    def execute(self, data: tuple[CharacterServiceInput, str]) -> None:
        actor, town_code = data
        if not self._access.can_access(actor.user_id, actor.username, actor.login):
            raise AuthorizationError()
        town = get_town(town_code)
        price = _require_priced_service(self._prices, self._lineage, "TELEPORT")
        execute_paid_service(
            actor,
            service="TELEPORT",
            value=town.code,
            price=price,
            lineage=self._lineage,
            access=self._access,
            wallets=self._wallets,
            operations=self._operations,
            unit_of_work=self._unit_of_work,
        )


class ChangeAppearanceUseCase(UseCase[tuple[CharacterServiceInput, str], None]):
    """Cobra e altera cabelo, cor e rosto do personagem offline."""

    def __init__(
        self,
        lineage: ILineageGateway,
        access: IAccountAccessService,
        prices: IServicePriceRepository,
        wallets: IWalletRepository,
        operations: ICharacterServiceOperationRepository,
        unit_of_work: UnitOfWork,
    ) -> None:
        self._lineage = lineage
        self._access = access
        self._prices = prices
        self._wallets = wallets
        self._operations = operations
        self._unit_of_work = unit_of_work

    def execute(self, data: tuple[CharacterServiceInput, str]) -> None:
        actor, raw = data
        if not self._access.can_access(actor.user_id, actor.username, actor.login):
            raise AuthorizationError()
        char = self._lineage.get_character(actor.login, actor.char_id)
        if char is None:
            raise ValidationDomainError("Personagem não encontrado.")
        hair_style, hair_color, face = parse_appearance(raw, char.sex)
        price = _require_priced_service(self._prices, self._lineage, "APPEARANCE")
        execute_paid_service(
            actor,
            service="APPEARANCE",
            value=appearance_value(hair_style, hair_color, face),
            price=price,
            lineage=self._lineage,
            access=self._access,
            wallets=self._wallets,
            operations=self._operations,
            unit_of_work=self._unit_of_work,
        )


class ClearKarmaUseCase(UseCase[CharacterServiceInput, None]):
    """Cobra e zera o karma do personagem offline."""

    def __init__(
        self,
        lineage: ILineageGateway,
        access: IAccountAccessService,
        prices: IServicePriceRepository,
        wallets: IWalletRepository,
        operations: ICharacterServiceOperationRepository,
        unit_of_work: UnitOfWork,
    ) -> None:
        self._lineage = lineage
        self._access = access
        self._prices = prices
        self._wallets = wallets
        self._operations = operations
        self._unit_of_work = unit_of_work

    def execute(self, data: CharacterServiceInput) -> None:
        if not self._access.can_access(data.user_id, data.username, data.login):
            raise AuthorizationError()
        price = _require_priced_service(self._prices, self._lineage, "CLEAR_KARMA")
        execute_paid_service(
            data,
            service="CLEAR_KARMA",
            value="",
            price=price,
            lineage=self._lineage,
            access=self._access,
            wallets=self._wallets,
            operations=self._operations,
            unit_of_work=self._unit_of_work,
        )


class ClearPkUseCase(UseCase[CharacterServiceInput, None]):
    """Cobra e zera a contagem de PK do personagem offline."""

    def __init__(
        self,
        lineage: ILineageGateway,
        access: IAccountAccessService,
        prices: IServicePriceRepository,
        wallets: IWalletRepository,
        operations: ICharacterServiceOperationRepository,
        unit_of_work: UnitOfWork,
    ) -> None:
        self._lineage = lineage
        self._access = access
        self._prices = prices
        self._wallets = wallets
        self._operations = operations
        self._unit_of_work = unit_of_work

    def execute(self, data: CharacterServiceInput) -> None:
        if not self._access.can_access(data.user_id, data.username, data.login):
            raise AuthorizationError()
        price = _require_priced_service(self._prices, self._lineage, "CLEAR_PK")
        execute_paid_service(
            data,
            service="CLEAR_PK",
            value="",
            price=price,
            lineage=self._lineage,
            access=self._access,
            wallets=self._wallets,
            operations=self._operations,
            unit_of_work=self._unit_of_work,
        )


class ChangeBaseClassUseCase(UseCase[ChangeBaseClassInput, None]):
    """Cobra e delega uma troca de classe-base atômica ao bridge Journey.

    O bloqueio é criado antes da reserva de saldo, desconectando o personagem
    e impedindo um login durante a alteração. Só é removido após confirmação
    inequívoca; uma resposta perdida mantém o bloqueio e a operação pendente
    para a conciliação administrativa, evitando cobrança duplicada ou escrita
    concorrente no banco do jogo.
    """

    def __init__(
        self,
        lineage: ILineageGateway,
        access: IAccountAccessService,
        prices: IServicePriceRepository,
        wallets: IWalletRepository,
        operations: ICharacterServiceOperationRepository,
        bridge: ICharacterEditBridge,
        unit_of_work: UnitOfWork,
    ) -> None:
        self._lineage = lineage
        self._access = access
        self._prices = prices
        self._wallets = wallets
        self._operations = operations
        self._bridge = bridge
        self._unit_of_work = unit_of_work

    def execute(self, data: ChangeBaseClassInput) -> None:
        actor = data.actor
        if not self._access.can_access(actor.user_id, actor.username, actor.login):
            raise AuthorizationError()
        character = self._lineage.get_character(actor.login, actor.char_id)
        if character is None:
            raise ValidationDomainError("Personagem não encontrado.")
        source_enchants = {
            skill.skill_id: skill.level % 100
            for skill in self._lineage.list_character_skills(actor.char_id)
            if skill.class_index == 0 and skill.level >= 100
        }
        validate_enchanted_skill_transfers(
            transfers=data.transfers,
            available_source_enchants=source_enchants,
        )
        source_race = class_race(character.class_id)
        target_race = class_race(data.target_class_id)
        base_code = (
            "CLASS_CHANGE_SAME_RACE"
            if source_race == target_race
            else "CLASS_CHANGE_CROSS_RACE"
        )
        amount = self._active_price(base_code)
        if data.disposition is SubclassDisposition.KEEP:
            amount += self._active_price("SUBCLASS_KEEP")
        elif data.disposition is SubclassDisposition.RESERVE:
            amount += self._active_price("SUBCLASS_RESERVE")
        value = self._value(data)

        self._bridge.lock_character(actor.char_id)
        keep_locked = False
        try:
            execute_paid_service(
                actor,
                service="CHANGE_BASE_CLASS",
                value=value,
                price=amount,
                lineage=self._lineage,
                access=self._access,
                wallets=self._wallets,
                operations=self._operations,
                unit_of_work=self._unit_of_work,
                require_offline=False,
                apply=lambda: self._bridge.change_base_class(
                    actor.char_id,
                    target_class_id=data.target_class_id,
                    disposition=data.disposition,
                    transfers=data.transfers,
                ),
            )
        except ConflictError as exc:
            # A camada de pagamento usa operation_id exclusivamente quando o
            # core pode ter confirmado antes de a conexão cair.
            keep_locked = "operation_id" in exc.details
            raise
        finally:
            if not keep_locked:
                self._bridge.unlock_character(actor.char_id)

    def _active_price(self, code: str):
        row = next((item for item in self._prices.list_all() if item.code == code), None)
        if row is None or not row.active:
            raise CharacterServiceUnavailableError()
        return row.price

    @staticmethod
    def _value(data: ChangeBaseClassInput) -> str:
        transfers = ";".join(
            f"{item.source_skill_id},{item.target_skill_id},{item.source_enchant}"
            for item in data.transfers
        ) or "-"
        value = f"{data.target_class_id}|{data.disposition.value}|{transfers}"
        if len(value) > 1024:
            raise ValidationDomainError("Há muitas transferências de skill.")
        return value


class PreviewBaseClassSkillsUseCase(UseCase[PreviewBaseClassSkillsInput, list[dict]]):
    """Expõe a árvore real do Journey ao seletor sem permitir qualquer mutação."""

    def __init__(
        self,
        lineage: ILineageGateway,
        access: IAccountAccessService,
        bridge: ICharacterEditBridge,
        skills: ISkillCatalog,
    ) -> None:
        self._lineage = lineage
        self._access = access
        self._bridge = bridge
        self._skills = skills

    def execute(self, data: PreviewBaseClassSkillsInput) -> list[dict]:
        actor = data.actor
        if not self._access.can_access(actor.user_id, actor.username, actor.login):
            raise AuthorizationError()
        if self._lineage.get_character(actor.login, actor.char_id) is None:
            raise ValidationDomainError("Personagem não encontrado.")
        class_race(data.target_class_id)
        return [
            {
                "skill_id": skill_id,
                "level": level,
                "name": self._skills.display_name(skill_id, fallback=f"Skill {skill_id}"),
            }
            for skill_id, level in self._bridge.preview_base_class_skills(
                actor.char_id,
                target_class_id=data.target_class_id,
            )
        ]
