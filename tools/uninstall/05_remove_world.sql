-- Manual Warband Camp uninstall: run this WHOLE file in a fresh connection.
-- Read tools/uninstall/README.md first. Defaults make NO persistent changes.
-- Select your world database with the client; there is deliberately no USE statement.
-- Edit these settings in a PRIVATE COPY. Settings reset on every import.
SET @wc_expected_database = ''; -- Exact database name selected by the client.
SET @wc_execute = 0;           -- 1 only after reviewing the previews.
SET @wc_server_stopped = 0;    -- 1 confirms worldserver is stopped and stays stopped.
SET @wc_backup_confirmed = 0;  -- 1 confirms a current database backup was made.
SET @wc_remove_commands = 0; -- 1 confirms BOTH command rows were added by this installation.
SET @wc_remove_spell_binding = 0; -- 1 confirms this exact binding is not needed elsewhere.
SET @wc_remove_scale_table = 0; -- 1 confirms gomove_scale is exclusively owned and disposable.
-- Keep each switch at 0 if standalone/other GOMove functionality remains installed.
-- Unknown prior command permissions cannot be reconstructed.
SET @wc_context_ok = COALESCE(
    @wc_expected_database <> '' AND BINARY DATABASE() = BINARY @wc_expected_database
    AND @wc_execute = 1 AND @wc_server_stopped = 1 AND @wc_backup_confirmed = 1, 0);
SELECT DATABASE() AS selected_database, @wc_context_ok AS execution_enabled;
-- These confirmations are operator declarations, not automatic detection.

SET @wc_sql = IF(@wc_context_ok AND @wc_remove_commands = 1 AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'command' AND table_type = 'BASE TABLE'),
    'DELETE FROM command WHERE security = 0 AND ((BINARY name = BINARY ''gomove'' AND BINARY help = BINARY ''Syntax: .gomove <id> [guid] [arg] — GOMove command for camp building, spawning, moving, and deleting GameObjects.'') OR (BINARY name = BINARY ''gomovesearch'' AND BINARY help = BINARY ''Syntax: .gomovesearch <name|entry> — GOMove browser search. Queries gameobject_template and returns results.''))',
    'SELECT ''SKIPPED command removal: disabled or table absent'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
SELECT ROW_COUNT() AS affected_rows; -- -1 means a status SELECT, not a mutation.
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(@wc_context_ok AND @wc_remove_spell_binding = 1 AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'spell_script_names' AND table_type = 'BASE TABLE'),
    'DELETE FROM spell_script_names WHERE spell_id = 27651 AND BINARY ScriptName = BINARY ''spell_gomove_place''',
    'SELECT ''SKIPPED spell binding: disabled or table absent'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
SELECT ROW_COUNT() AS affected_rows; -- -1 means a status SELECT, not a mutation.
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(@wc_context_ok AND @wc_remove_scale_table = 1 AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'gomove_scale' AND table_type = 'BASE TABLE'),
    'DROP TABLE IF EXISTS gomove_scale',
    'SELECT ''SKIPPED scale table: disabled or table absent'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'command' AND table_type = 'BASE TABLE'),
    'SELECT name, security, help FROM command WHERE name IN (''gomove'', ''gomovesearch'')',
    'SELECT ''command table absent'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

-- Customized command rows are retained for manual review. No guessed security reset.
-- No mutations to gameobject, creature, templates, auth, or SQL updater history.
