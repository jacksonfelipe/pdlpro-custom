-- L2J Premium — characters.charId is the primary key; base data is on characters.

-- name: list_characters
SELECT C.charId AS char_id, C.char_name AS name, COALESCE(C.level, 0) AS level,
       C.online, C.sex, COALESCE(C.pvpkills, 0) AS pvp, COALESCE(C.pkkills, 0) AS pk,
       COALESCE(C.classid, 0) AS class_id, COALESCE(C.title, '') AS title,
       COALESCE(D.clan_name, '') AS clan_name,
       CASE WHEN D.leader_id = C.charId THEN 1 ELSE 0 END AS is_clan_leader,
       COALESCE(C.karma, 0) AS karma, COALESCE(I.adenas, 0) AS adena,
       COALESCE(C.onlinetime, 0) AS online_time, COALESCE(C.lastAccess, 0) AS last_access,
       COALESCE(C.clanid, 0) AS clan_id, COALESCE(D.ally_id, 0) AS ally_id,
       COALESCE(D.ally_name, '') AS ally_name, D.crest AS clan_crest, NULL AS ally_crest,
       COALESCE(C.hairStyle, 0) AS hair_style, COALESCE(C.hairColor, 0) AS hair_color,
       COALESCE(C.face, 0) AS face
FROM characters C
LEFT JOIN clan_data D ON D.clan_id = C.clanid
LEFT JOIN (SELECT owner_id, SUM(count) AS adenas FROM items WHERE item_id = 57 GROUP BY owner_id) I ON I.owner_id = C.charId
WHERE C.account_name = :login
ORDER BY C.level DESC, C.char_name ASC

-- name: get_character
SELECT C.charId AS char_id, C.char_name AS name, COALESCE(C.level, 0) AS level,
       C.online, C.sex, COALESCE(C.pvpkills, 0) AS pvp, COALESCE(C.pkkills, 0) AS pk,
       COALESCE(C.classid, 0) AS class_id, COALESCE(C.title, '') AS title,
       COALESCE(D.clan_name, '') AS clan_name,
       CASE WHEN D.leader_id = C.charId THEN 1 ELSE 0 END AS is_clan_leader,
       COALESCE(C.karma, 0) AS karma, COALESCE(I.adenas, 0) AS adena,
       COALESCE(C.onlinetime, 0) AS online_time, COALESCE(C.lastAccess, 0) AS last_access,
       COALESCE(C.clanid, 0) AS clan_id, COALESCE(D.ally_id, 0) AS ally_id,
       COALESCE(D.ally_name, '') AS ally_name, D.crest AS clan_crest, NULL AS ally_crest,
       COALESCE(C.hairStyle, 0) AS hair_style, COALESCE(C.hairColor, 0) AS hair_color,
       COALESCE(C.face, 0) AS face
FROM characters C
LEFT JOIN clan_data D ON D.clan_id = C.clanid
LEFT JOIN (SELECT owner_id, SUM(count) AS adenas FROM items WHERE item_id = 57 GROUP BY owner_id) I ON I.owner_id = C.charId
WHERE C.account_name = :login AND C.charId = :char_id
LIMIT 1

-- name: nickname_exists
SELECT charId AS char_id FROM characters WHERE char_name = :name LIMIT 1

-- name: change_nickname
UPDATE characters SET char_name = :name WHERE charId = :cid AND account_name = :login LIMIT 1

-- name: change_sex
UPDATE characters SET sex = :sex WHERE charId = :cid AND account_name = :login LIMIT 1

-- name: unstuck
UPDATE characters SET x = :x, y = :y, z = :z WHERE charId = :cid AND account_name = :login LIMIT 1

-- name: count_characters
SELECT COUNT(*) AS total FROM characters WHERE account_name = :login

-- name: verify_character_ownership
SELECT COUNT(*) AS total FROM characters WHERE charId = :char_id AND account_name = :login

-- name: transfer_character
UPDATE characters SET account_name = :acc WHERE charId = :cid AND account_name = :from_acc

-- name: find_character_id_by_name
SELECT charId AS char_id FROM characters WHERE char_name = :name LIMIT 1

-- name: change_appearance
UPDATE characters SET hairStyle = :hair_style, hairColor = :hair_color, face = :face WHERE charId = :cid AND account_name = :login LIMIT 1

-- name: clear_karma
UPDATE characters SET karma = 0 WHERE charId = :cid AND account_name = :login LIMIT 1

-- name: clear_pk
UPDATE characters SET pkkills = 0 WHERE charId = :cid AND account_name = :login LIMIT 1
