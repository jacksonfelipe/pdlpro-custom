"""Catálogo estável das classes H5 suportadas pelo bridge Journey.

O core continua sendo a autoridade para a árvore e para a compatibilidade da
classe. Este catálogo só permite ao painel calcular o preço entre raças sem
aceitar um ID arbitrário do navegador.
"""

from __future__ import annotations

from common.architecture.exceptions import ValidationDomainError

_RACE_BY_CLASS_ID = {
    **{class_id: "human" for class_id in (*range(18), *range(88, 99))},
    **{class_id: "elf" for class_id in (*range(18, 31), *range(99, 106))},
    **{class_id: "dark_elf" for class_id in (*range(31, 44), *range(106, 113))},
    **{class_id: "orc" for class_id in (*range(44, 53), *range(113, 117))},
    **{class_id: "dwarf" for class_id in (*range(53, 58), *range(117, 119))},
    **{class_id: "kamael" for class_id in range(123, 137)},
}


def class_race(class_id: int) -> str:
    """Retorna a raça da classe H5 ou recusa IDs que o core não suporta."""

    race = _RACE_BY_CLASS_ID.get(class_id)
    if race is None:
        raise ValidationDomainError("Classe de destino não é suportada neste servidor.")
    return race


def available_class_ids() -> tuple[int, ...]:
    """IDs usados pelo seletor do painel; os nomes são traduzidos na SPA."""

    return tuple(sorted(_RACE_BY_CLASS_ID))
