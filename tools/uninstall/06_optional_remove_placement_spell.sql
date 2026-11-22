-- Manual Warband Camp uninstall: run this WHOLE file in a fresh connection.
-- Read tools/uninstall/README.md first. Defaults make NO persistent changes.
-- Select your characters database with the client; there is deliberately no USE statement.
-- Edit these settings in a PRIVATE COPY. Settings reset on every import.
SET @wc_expected_database = ''; -- Exact database name selected by the client.
SET @wc_execute = 0;           -- 1 only after reviewing the previews.
SET @wc_server_stopped = 0;    -- 1 confirms worldserver is stopped and stays stopped.
SET @wc_backup_confirmed = 0;  -- 1 confirms a current database backup was made.
SET @wc_remove_spell_guids = ''; -- Reviewed numeric GUIDs, comma-separated, NO spaces.
SET @wc_spell_ownership_confirmed = 0; -- 1 confirms these characters learned 27651 from this module.
-- Includes ordinary builders and GMs. Account security is NOT ownership evidence.
SET @wc_context_ok = COALESCE(
    @wc_expected_database <> '' AND BINARY DATABASE() = BINARY @wc_expected_database
    AND @wc_execute = 1 AND @wc_server_stopped = 1 AND @wc_backup_confirmed = 1, 0);
SELECT DATABASE() AS selected_database, @wc_context_ok AS execution_enabled;
-- These confirmations are operator declarations, not automatic detection.

SET @wc_list_ok = @wc_remove_spell_guids REGEXP '^[1-9][0-9]*(,[1-9][0-9]*)*$';
SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'character_spell' AND table_type = 'BASE TABLE') AND @wc_list_ok,
    'SELECT guid, spell FROM character_spell WHERE spell = 27651 AND FIND_IN_SET(CAST(guid AS CHAR), @wc_remove_spell_guids) > 0 ORDER BY guid',
    'SELECT ''No valid selection or character_spell absent'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(@wc_context_ok AND @wc_list_ok AND @wc_spell_ownership_confirmed = 1 AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'character_spell' AND table_type = 'BASE TABLE'),
    'DELETE FROM character_spell WHERE spell = 27651 AND FIND_IN_SET(CAST(guid AS CHAR), @wc_remove_spell_guids) > 0',
    'SELECT ''SKIPPED spell removal: confirmations, GUID list, or table checks not satisfied'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
SELECT ROW_COUNT() AS affected_rows; -- -1 means a status SELECT, not a mutation.
DEALLOCATE PREPARE wc_uninstall_stmt;
