-- L2J Premium offline shop queue.

-- name: list_private_stores
SELECT C.charId AS char_id, C.char_name AS name, COALESCE(O.mode, 1) AS store_type, COALESCE(O.title, '') AS title,
       COALESCE(C.x, 0) AS x, COALESCE(C.y, 0) AS y, COALESCE(C.z, 0) AS z,
       COALESCE(D.clan_name, '') AS clan_name, COALESCE(C.sex, 0) AS sex, COALESCE(C.classid, 0) AS class_id
FROM character_offline O INNER JOIN characters C ON C.charId = O.charId
LEFT JOIN clan_data D ON D.clan_id = C.clanid
WHERE O.mode IN (1, 3, 4) ORDER BY C.char_name ASC

-- name: list_private_store_items
SELECT O.charId AS char_id, S.itemid AS item_id, S.count AS quantity, S.price, 0 AS enchant
FROM character_offline O INNER JOIN character_offline_shop S ON S.shopid = O.shopid
WHERE O.mode IN (1, 3, 4)
