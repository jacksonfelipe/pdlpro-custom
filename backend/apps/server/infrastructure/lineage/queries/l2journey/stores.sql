-- L2Journey offline trade tables.

-- name: list_private_stores
SELECT C.charId AS char_id, C.char_name AS name, COALESCE(T.type, 1) AS store_type, COALESCE(T.title, '') AS title,
       COALESCE(C.x, 0) AS x, COALESCE(C.y, 0) AS y, COALESCE(C.z, 0) AS z,
       COALESCE(D.clan_name, '') AS clan_name, COALESCE(C.sex, 0) AS sex, COALESCE(C.classid, 0) AS class_id
FROM character_offline_trade T INNER JOIN characters C ON C.charId = T.charId
LEFT JOIN clan_data D ON D.clan_id = C.clanid ORDER BY C.char_name ASC

-- name: list_private_store_items
SELECT charId AS char_id, item AS item_id, count AS quantity, price, COALESCE(enchant, 0) AS enchant
FROM character_offline_trade_items
