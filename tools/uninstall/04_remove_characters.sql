-- Manual Warband Camp uninstall: run this WHOLE file in a fresh connection.
-- Read tools/uninstall/README.md first. Defaults make NO persistent changes.
-- Select your characters database with the client; there is deliberately no USE statement.
-- Edit these settings in a PRIVATE COPY. Settings reset on every import.
SET @wc_expected_database = ''; -- Exact database name selected by the client.
SET @wc_execute = 0;           -- 1 only after reviewing the previews.
SET @wc_server_stopped = 0;    -- 1 confirms worldserver is stopped and stays stopped.
SET @wc_backup_confirmed = 0;  -- 1 confirms a current database backup was made.
SET @wc_remove_camp_tables = 0; -- 1 confirms the four tables belong to this installation.
SET @wc_origins_reviewed_and_exported = 0; -- Required if ANY origin rows remain.
-- Restore eligible alts first; export and resolve or explicitly accept every remaining origin.
-- Legacy wowlegends_* tables are always preserved.
SET @wc_context_ok = COALESCE(
    @wc_expected_database <> '' AND BINARY DATABASE() = BINARY @wc_expected_database
    AND @wc_execute = 1 AND @wc_server_stopped = 1 AND @wc_backup_confirmed = 1, 0);
SELECT DATABASE() AS selected_database, @wc_context_ok AS execution_enabled;
-- These confirmations are operator declarations, not automatic detection.

SET @wc_origin_count = NULL;
SET @wc_sql = IF(EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_alt_origin' AND table_type = 'BASE TABLE'),
    'SELECT COUNT(*) INTO @wc_origin_count FROM mod_warband_alt_origin',
    'SELECT ''Origin table absent or not a base table'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_origins_safe = (NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_alt_origin' AND table_type = 'BASE TABLE'))
    OR @wc_origin_count = 0 OR @wc_origins_reviewed_and_exported = 1;
SET @wc_cleanup_ok = @wc_context_ok AND @wc_remove_camp_tables = 1 AND @wc_origins_safe;
SELECT @wc_origin_count AS saved_origins, @wc_origins_safe AS origins_handled,
       @wc_cleanup_ok AS table_removal_enabled;
-- DROP TABLE implicitly commits. Each guarded drop is independent and repeatable.

SET @wc_sql = IF(@wc_cleanup_ok AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_camp_object' AND table_type = 'BASE TABLE'),
    'DROP TABLE IF EXISTS `mod_warband_camp_object`',
    'SELECT ''SKIPPED mod_warband_camp_object: disabled, origins unresolved, or table absent'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(@wc_cleanup_ok AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_camp_creature' AND table_type = 'BASE TABLE'),
    'DROP TABLE IF EXISTS `mod_warband_camp_creature`',
    'SELECT ''SKIPPED mod_warband_camp_creature: disabled, origins unresolved, or table absent'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(@wc_cleanup_ok AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_camp' AND table_type = 'BASE TABLE'),
    'DROP TABLE IF EXISTS `mod_warband_camp`',
    'SELECT ''SKIPPED mod_warband_camp: disabled, origins unresolved, or table absent'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(@wc_cleanup_ok AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_alt_origin' AND table_type = 'BASE TABLE'),
    'DROP TABLE IF EXISTS `mod_warband_alt_origin`',
    'SELECT ''SKIPPED mod_warband_alt_origin: disabled, origins unresolved, or table absent'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;
