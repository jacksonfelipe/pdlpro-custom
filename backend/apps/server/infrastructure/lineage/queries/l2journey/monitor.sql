-- L2Journey item observation.

-- name: monitor_items
SELECT i.item_id, SUM(i.count) AS quantity, COUNT(*) AS instances,
       COUNT(DISTINCT CASE WHEN i.loc = 'CLANWH' THEN CONCAT('clan:', i.owner_id) ELSE CONCAT('char:', i.owner_id) END) AS unique_owners
FROM items i LEFT JOIN characters c ON c.charId = i.owner_id AND i.loc <> 'CLANWH'
LEFT JOIN clan_data d ON d.clan_id = i.owner_id AND i.loc = 'CLANWH'
WHERE (i.loc IN ('INVENTORY', 'WAREHOUSE', 'PAPERDOLL') AND c.accesslevel = 0) OR (i.loc = 'CLANWH' AND d.clan_id IS NOT NULL)
GROUP BY i.item_id ORDER BY quantity DESC, i.item_id LIMIT :row_limit

-- name: monitor_details
SELECT i.item_id, i.loc AS location, SUM(i.count) AS quantity, COUNT(*) AS instances, COUNT(DISTINCT i.owner_id) AS unique_owners
FROM items i LEFT JOIN characters c ON c.charId = i.owner_id AND i.loc <> 'CLANWH'
LEFT JOIN clan_data d ON d.clan_id = i.owner_id AND i.loc = 'CLANWH'
WHERE (i.loc IN ('INVENTORY', 'WAREHOUSE', 'PAPERDOLL') AND c.accesslevel = 0) OR (i.loc = 'CLANWH' AND d.clan_id IS NOT NULL)
GROUP BY i.item_id, i.loc ORDER BY i.item_id, location LIMIT :row_limit

-- name: monitor_characters
SELECT COUNT(*) AS total FROM characters WHERE accesslevel = 0
