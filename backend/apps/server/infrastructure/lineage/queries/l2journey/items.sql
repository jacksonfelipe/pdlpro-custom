-- L2Journey — object_id, item_id, count, enchant_level and loc.
-- Item delivery is handled via custom_mail consumed by CustomMailManager.

-- name: list_character_items
SELECT item_id, count AS quantity, enchant_level AS enchant, loc AS location
FROM items WHERE owner_id = :char_id AND loc IN ('INVENTORY', 'WAREHOUSE') ORDER BY loc, item_id

-- name: list_character_equipment
SELECT item_id, count AS quantity, enchant_level AS enchant, loc_data AS slot
FROM items WHERE owner_id = :char_id AND loc = 'PAPERDOLL' ORDER BY loc_data, item_id

-- name: list_character_skills
SELECT skill_id, skill_level AS level, class_index FROM character_skills WHERE charId = :char_id ORDER BY skill_id, class_index

-- name: delete_item_stack
DELETE FROM items
WHERE owner_id = :char_id AND item_id = :item_id AND enchant_level = :enchant
  AND loc IN ('INVENTORY', 'WAREHOUSE')
ORDER BY object_id
LIMIT 1

-- name: update_item_amount
UPDATE items SET count = count - :qty
WHERE owner_id = :char_id AND item_id = :item_id AND enchant_level = :enchant
  AND loc IN ('INVENTORY', 'WAREHOUSE')
ORDER BY object_id
LIMIT 1

-- The Journey gameserver CustomMailManager delivers items via in-game mail.
-- Format: itemId count enchant;itemId count enchant...
-- name: deposit_item
INSERT INTO custom_mail (receiver, subject, message, items)
VALUES (:owner_id, 'Entrega PDL PRO', 'Seus itens adquiridos no painel foram entregues com sucesso.', CONCAT(:item_id, ' ', :qty, ' ', :enchant))

-- name: delivery_character
SELECT charId AS char_id, online FROM characters WHERE char_name = :name FOR UPDATE

-- Online delivery capability: the gameserver CustomMailManager consumes custom_mail periodically.
-- name: online_delivery_ready
SELECT 1 FROM custom_mail WHERE 1=0

