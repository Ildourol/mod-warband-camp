-- ============================================================================
-- GOMove — Character spell cleanup
-- Ground-placement spell 27651 is now only granted while a placement is queued.
-- Remove it from any characters that were permanently granted it.
-- ============================================================================

DELETE FROM `character_spell` WHERE `spell` = 27651;
