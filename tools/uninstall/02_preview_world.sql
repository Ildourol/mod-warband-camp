-- READ ONLY. Run against your world database.
SELECT DATABASE() AS selected_database;

SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'command' AND table_type = 'BASE TABLE'),
    'SELECT name, security, help FROM command WHERE name IN (''gomove'', ''gomovesearch'')',
    'SELECT ''command table absent'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'spell_script_names' AND table_type = 'BASE TABLE'),
    'SELECT spell_id, ScriptName FROM spell_script_names WHERE spell_id = 27651 OR ScriptName = ''spell_gomove_place''',
    'SELECT ''spell_script_names table absent'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'gomove_scale' AND table_type = 'BASE TABLE'),
    'SELECT guid, scale FROM gomove_scale ORDER BY guid',
    'SELECT ''gomove_scale table absent'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SELECT 'Scale GUIDs are NOT proof that an object was created by this module. World gameobject and creature rows are never deleted by these scripts.' AS limitation;
