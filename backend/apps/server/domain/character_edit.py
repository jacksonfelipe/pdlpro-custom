"""Políticas puras para edição transacional de personagens.

O gameserver é a autoridade para aplicar uma troca de classe e atualizar a
árvore de skills. Este módulo apenas representa a escolha do jogador antes de
ela cruzar essa fronteira: nunca executa SQL, não debita carteira e não assume
que uma alteração em ``characters`` seja suficiente para mudar uma classe.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import StrEnum

from common.architecture.exceptions import ValidationDomainError


class ICharacterEditBridge(ABC):
    """Porta para o canal autenticado de edição no gameserver.

    A implementação nunca recebe comandos vindos do navegador. Ela serve para
    verificar a disponibilidade do core e, nos casos de uso aprovados, manter
    um personagem bloqueado durante uma alteração transacional.
    """

    @abstractmethod
    def ping(self) -> None:
        """Confirma que o bridge Journey autenticado está disponível."""

    @abstractmethod
    def lock_character(self, character_id: int) -> None:
        """Bloqueia a seleção e desconecta o personagem no gameserver."""

    @abstractmethod
    def unlock_character(self, character_id: int) -> None:
        """Remove um bloqueio previamente aplicado pelo gameserver."""

    @abstractmethod
    def transfer_character(self, character_id: int, *, from_account: str, to_account: str) -> None:
        """Transfere um personagem já bloqueado dentro da transação do gameserver."""

    @abstractmethod
    def change_base_class(
        self,
        character_id: int,
        *,
        target_class_id: int,
        disposition: SubclassDisposition,
        transfers: tuple[EnchantedSkillTransfer, ...],
    ) -> None:
        """Troca a classe-base e as skills no core, mantendo o bloqueio ativo.

        O implementador deve validar a classe, as skills e o limite de enchant
        com a árvore carregada pelo gameserver e aplicar tudo numa transação.
        """

    @abstractmethod
    def preview_base_class_skills(self, character_id: int, *, target_class_id: int) -> tuple[tuple[int, int], ...]:
        """Lista IDs e níveis-base que o core aceita para a classe escolhida."""


class ICharacterCustodyService(ABC):
    """Porta de custódia de personagem usada por marketplace e leilões.

    No Journey a implementação chama o bridge local do GameServer. Outros
    dialetos mantêm o adaptador legado até possuírem um bridge equivalente.
    A aplicação nunca escreve a tabela ``characters`` diretamente.
    """

    @abstractmethod
    def place_in_custody(self, character_id: int, *, from_account: str, custody_account: str) -> None:
        """Bloqueia e move o personagem para a conta de custódia."""

    @abstractmethod
    def release_from_custody(self, character_id: int, *, custody_account: str, to_account: str) -> None:
        """Move o personagem da custódia sem remover o bloqueio ainda."""

    @abstractmethod
    def unlock_character(self, character_id: int) -> None:
        """Libera o personagem somente após a transação do painel terminar."""


class SubclassDisposition(StrEnum):
    """Destino explícito das subclasses durante uma troca de classe-base."""

    KEEP = "keep"
    DELETE = "delete"
    RESERVE = "reserve"


@dataclass(frozen=True, slots=True)
class EnchantedSkillTransfer:
    """Uma skill da classe nova que receberá o encanto da skill antiga.

    ``source_enchant`` é uma quantidade, não o ``skill_level`` codificado do
    banco. O adaptador do gameserver converte-a somente depois de validar a
    rota de enchant da skill destino.
    """

    source_skill_id: int
    target_skill_id: int
    source_enchant: int


def validate_subclass_disposition(
    *,
    disposition: SubclassDisposition,
    has_subclasses: bool,
) -> None:
    """Recusa cobrar preservação/reserva quando o personagem não tem subclass.

    Excluir sem subclasses é idempotente e permanece permitido, pois a ação
    não precisa produzir erro ao ser retomada depois de uma queda de conexão.
    """

    if has_subclasses or disposition is SubclassDisposition.DELETE:
        return
    raise ValidationDomainError("O personagem não possui subclasses para manter ou reservar.")


def validate_enchanted_skill_transfers(
    *,
    transfers: tuple[EnchantedSkillTransfer, ...],
    available_source_enchants: dict[int, int],
) -> None:
    """Valida a transferência sem permitir duplicar uma skill ou um encanto.

    A validação de a skill destino pertencer à nova classe é feita pelo bridge
    instalado no gameserver, que possui a árvore real e a rota de enchant da
    distribuição. Aqui se protege o contrato que o painel já consegue provar:
    cada skill antiga só pode financiar uma skill nova e nunca com nível maior.
    """

    sources: set[int] = set()
    targets: set[int] = set()
    for transfer in transfers:
        if min(transfer.source_skill_id, transfer.target_skill_id, transfer.source_enchant) < 1:
            raise ValidationDomainError("A transferência de skill é inválida.")
        if transfer.source_skill_id in sources or transfer.target_skill_id in targets:
            raise ValidationDomainError("Cada skill só pode participar uma vez da transferência.")
        if transfer.source_enchant > available_source_enchants.get(transfer.source_skill_id, 0):
            raise ValidationDomainError("O enchant informado é maior que o da skill original.")
        sources.add(transfer.source_skill_id)
        targets.add(transfer.target_skill_id)
