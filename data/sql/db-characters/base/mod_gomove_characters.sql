-- ============================================================================
-- GOMove — Character spell setup
-- Automatically grant ground-placement spell 27651 to GM characters (gmlevel >= 2)
-- Note: The C++ module also automatically learns this spell on login.
-- ============================================================================

INSERT IGNORE INTO `character_spell` (`guid`, `spell`, `specMask`)
SELECT c.`guid`, 27651, 255
FROM `characters` c
JOIN `acore_auth`.`account_access` a ON c.`account` = a.`id`
WHERE a.`gmlevel` >= 2;
