-- L2J Premium world, olympiad, clans and siege.

-- name: olympiad_ranking
SELECT C.char_name AS name, O.olympiad_points AS value, C.online, COALESCE(D.clan_name, '') AS clan_name, C.classid AS class_id, C.sex
FROM olympiad_nobles O LEFT JOIN characters C ON C.charId = O.charId LEFT JOIN clan_data D ON D.clan_id = C.clanid
ORDER BY O.olympiad_points DESC, C.classid ASC, C.char_name ASC

-- name: olympiad_all_heroes
SELECT C.char_name AS name, H.count AS value, C.online, COALESCE(D.clan_name, '') AS clan_name, C.classid AS class_id, C.sex
FROM heroes H LEFT JOIN characters C ON C.charId = H.charId LEFT JOIN clan_data D ON D.clan_id = C.clanid
WHERE H.played > 0 AND H.count > 0 ORDER BY H.count DESC, C.classid ASC, C.char_name ASC

-- name: olympiad_current_heroes
SELECT C.char_name AS name, C.classid AS value, C.online, COALESCE(D.clan_name, '') AS clan_name
FROM heroes H LEFT JOIN characters C ON C.charId = H.charId LEFT JOIN clan_data D ON D.clan_id = C.clanid
WHERE H.played > 0 AND H.count > 0 ORDER BY C.classid ASC

-- name: grandboss_status
SELECT boss_id AS boss_id, respawn_time AS respawn FROM grandboss_data ORDER BY respawn_time DESC

-- name: siege
SELECT W.id AS castle_id, W.name, W.siegeDate AS sdate, W.treasury AS stax, W.taxPercent AS tax,
       P.char_name AS leader, D.clan_name, D.clan_id, D.ally_name
FROM castle W LEFT JOIN clan_data D ON D.hasCastle = W.id LEFT JOIN characters P ON P.charId = D.leader_id

-- name: siege_participants
SELECT S.type, D.clan_name, D.clan_id FROM siege_clans S LEFT JOIN clan_data D ON D.clan_id = S.clan_id WHERE S.castle_id = :castle_id

-- name: search_characters
SELECT C.charId AS char_id, C.char_name AS name, C.level AS value, C.classid AS class_id, C.sex, C.online, COALESCE(D.clan_name, '') AS clan_name
FROM characters C LEFT JOIN clan_data D ON D.clan_id = C.clanid
WHERE C.accesslevel = 0 AND C.char_name LIKE :query ORDER BY C.level DESC, C.char_name ASC LIMIT :limit

-- name: get_clan_details
SELECT D.clan_id, D.clan_name, D.clan_level AS level, D.reputation_score AS reputation, D.ally_id,
       (SELECT COUNT(*) FROM characters WHERE clanid = D.clan_id) AS member_count
FROM clan_data D WHERE D.clan_name = :clan_name LIMIT 1

-- name: clan_members
SELECT C.char_name AS name, C.online, C.pvpkills AS pvp, C.pkkills AS pk, C.level, C.classid AS class_id
FROM characters C WHERE C.clanid = :clan_id ORDER BY C.online DESC, C.level DESC, C.char_name ASC
