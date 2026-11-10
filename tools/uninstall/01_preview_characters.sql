-- READ ONLY. Run against your characters database; missing tables are reported.
SELECT DATABASE() AS selected_database;

SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_camp_object' AND table_type = 'BASE TABLE'),
    'SELECT ''mod_warband_camp_object'' AS table_name, COUNT(*) AS row_count FROM `mod_warband_camp_object`',
    'SELECT ''mod_warband_camp_object: absent (or not a base table); legacy tables are never removed'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_camp_creature' AND table_type = 'BASE TABLE'),
    'SELECT ''mod_warband_camp_creature'' AS table_name, COUNT(*) AS row_count FROM `mod_warband_camp_creature`',
    'SELECT ''mod_warband_camp_creature: absent (or not a base table); legacy tables are never removed'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_camp' AND table_type = 'BASE TABLE'),
    'SELECT ''mod_warband_camp'' AS table_name, COUNT(*) AS row_count FROM `mod_warband_camp`',
    'SELECT ''mod_warband_camp: absent (or not a base table); legacy tables are never removed'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_alt_origin' AND table_type = 'BASE TABLE'),
    'SELECT ''mod_warband_alt_origin'' AS table_name, COUNT(*) AS row_count FROM `mod_warband_alt_origin`',
    'SELECT ''mod_warband_alt_origin: absent (or not a base table); legacy tables are never removed'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'wowlegends_warband_camp' AND table_type = 'BASE TABLE'),
    'SELECT ''wowlegends_warband_camp'' AS table_name, COUNT(*) AS row_count FROM `wowlegends_warband_camp`',
    'SELECT ''wowlegends_warband_camp: absent (or not a base table); legacy tables are never removed'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'wowlegends_warband_camp_object' AND table_type = 'BASE TABLE'),
    'SELECT ''wowlegends_warband_camp_object'' AS table_name, COUNT(*) AS row_count FROM `wowlegends_warband_camp_object`',
    'SELECT ''wowlegends_warband_camp_object: absent (or not a base table); legacy tables are never removed'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'characters' AND table_type = 'BASE TABLE') AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_alt_origin' AND table_type = 'BASE TABLE') AND (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'characters' AND column_name IN ('guid', 'account', 'name', 'map', 'position_x', 'position_y', 'position_z', 'orientation', 'online', 'instance_id', 'transguid', 'taxi_path', 'deleteInfos_Account', 'zone')) = 14 AND (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'mod_warband_alt_origin' AND column_name IN ('guid', 'map', 'pos_x', 'pos_y', 'pos_z', 'orientation')) = 6,
    'SELECT o.guid, c.name, c.account, c.online, c.map AS current_map, c.position_x, c.position_y, c.position_z, o.map AS saved_map, o.pos_x AS saved_x, o.pos_y AS saved_y, o.pos_z AS saved_z, o.orientation AS saved_orientation FROM mod_warband_alt_origin o LEFT JOIN characters c ON c.guid = o.guid ORDER BY o.guid',
    'SELECT ''Origin review unavailable: required tables or columns absent'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'characters' AND table_type = 'BASE TABLE') AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_alt_origin' AND table_type = 'BASE TABLE') AND (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'characters' AND column_name IN ('guid', 'account', 'name', 'map', 'position_x', 'position_y', 'position_z', 'orientation', 'online', 'instance_id', 'transguid', 'taxi_path', 'deleteInfos_Account', 'zone')) = 14 AND (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'mod_warband_alt_origin' AND column_name IN ('guid', 'map', 'pos_x', 'pos_y', 'pos_z', 'orientation')) = 6 AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_camp' AND table_type = 'BASE TABLE') AND (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'mod_warband_camp' AND column_name IN ('account_id', 'map', 'pos_x', 'pos_y')) = 4,
    'SELECT c.guid, c.name, (c.online = 0 AND c.deleteInfos_Account IS NULL
 AND c.instance_id = 0 AND COALESCE(c.transguid, 0) = 0 AND COALESCE(c.taxi_path, '''') = ''''
 AND c.map = camp.map
 AND POW(c.position_x - camp.pos_x, 2) + POW(c.position_y - camp.pos_y, 2) < 3600
 AND o.map IN (0, 1, 530, 571)
 AND ABS(o.pos_x) < 17066.666 AND ABS(o.pos_y) < 17066.666 AND ABS(o.pos_z) < 17066.666
 AND o.orientation >= 0 AND o.orientation <= 6.283186) AS passes_location_checks FROM characters c JOIN mod_warband_alt_origin o ON o.guid = c.guid JOIN mod_warband_camp camp ON camp.account_id = c.account ORDER BY c.guid',
    'SELECT ''Eligibility review unavailable: required tables or columns absent'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'character_spell' AND table_type = 'BASE TABLE') AND (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'character_spell' AND column_name IN ('guid', 'spell')) = 2,
    'SELECT guid, spell FROM character_spell WHERE spell = 27651 ORDER BY guid',
    'SELECT ''character_spell absent or incompatible'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SELECT 'Location checks do not prove origin ownership or safe terrain. Review every destination. Missing camps and missing characters require manual review.' AS limitation;
