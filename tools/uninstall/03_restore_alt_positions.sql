-- Manual Warband Camp uninstall: run this WHOLE file in a fresh connection.
-- Read tools/uninstall/README.md first. Defaults make NO persistent changes.
-- Select your characters database with the client; there is deliberately no USE statement.
-- Edit these settings in a PRIVATE COPY. Settings reset on every import.
SET @wc_expected_database = ''; -- Exact database name selected by the client.
SET @wc_execute = 0;           -- 1 only after reviewing the previews.
SET @wc_server_stopped = 0;    -- 1 confirms worldserver is stopped and stays stopped.
SET @wc_backup_confirmed = 0;  -- 1 confirms a current database backup was made.
SET @wc_restore_guids = ''; -- Reviewed numeric GUIDs, comma-separated, NO spaces; e.g. '123,456'.
SET @wc_destinations_verified = 0; -- 1 confirms each saved destination is safe ground in an open-world map.
-- Instance and transport origin context was NOT saved. Never guess it.
SET @wc_context_ok = COALESCE(
    @wc_expected_database <> '' AND BINARY DATABASE() = BINARY @wc_expected_database
    AND @wc_execute = 1 AND @wc_server_stopped = 1 AND @wc_backup_confirmed = 1, 0);
SELECT DATABASE() AS selected_database, @wc_context_ok AS execution_enabled;
-- These confirmations are operator declarations, not automatic detection.

SET @wc_schema_ok = EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'characters' AND table_type = 'BASE TABLE') AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_alt_origin' AND table_type = 'BASE TABLE') AND (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'characters' AND column_name IN ('guid', 'account', 'name', 'map', 'position_x', 'position_y', 'position_z', 'orientation', 'online', 'instance_id', 'transguid', 'taxi_path', 'deleteInfos_Account', 'zone')) = 14 AND (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'mod_warband_alt_origin' AND column_name IN ('guid', 'map', 'pos_x', 'pos_y', 'pos_z', 'orientation')) = 6 AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'mod_warband_camp' AND table_type = 'BASE TABLE') AND (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'mod_warband_camp' AND column_name IN ('account_id', 'map', 'pos_x', 'pos_y')) = 4 AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'characters' AND engine = 'InnoDB');
SET @wc_list_ok = @wc_restore_guids REGEXP '^[1-9][0-9]*(,[1-9][0-9]*)*$';

SET @wc_sql = IF(@wc_schema_ok AND @wc_list_ok,
    'SELECT c.guid, c.name, c.map AS current_map, o.map AS saved_map, o.pos_x, o.pos_y, o.pos_z, (c.online = 0 AND c.deleteInfos_Account IS NULL
 AND c.instance_id = 0 AND COALESCE(c.transguid, 0) = 0 AND COALESCE(c.taxi_path, '''') = ''''
 AND c.map = camp.map
 AND POW(c.position_x - camp.pos_x, 2) + POW(c.position_y - camp.pos_y, 2) < 3600
 AND o.map IN (0, 1, 530, 571)
 AND ABS(o.pos_x) < 17066.666 AND ABS(o.pos_y) < 17066.666 AND ABS(o.pos_z) < 17066.666
 AND o.orientation >= 0 AND o.orientation <= 6.283186) AS passes_location_checks FROM characters c JOIN mod_warband_alt_origin o ON o.guid = c.guid JOIN mod_warband_camp camp ON camp.account_id = c.account WHERE FIND_IN_SET(CAST(c.guid AS CHAR), @wc_restore_guids) > 0',
    'SELECT ''No valid selection or unsupported schema; no restoration'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
DEALLOCATE PREPARE wc_uninstall_stmt;

SET @wc_sql = IF(@wc_context_ok AND @wc_schema_ok AND @wc_list_ok AND @wc_destinations_verified = 1,
    'UPDATE characters c JOIN mod_warband_alt_origin o ON o.guid = c.guid
JOIN mod_warband_camp camp ON camp.account_id = c.account
SET c.map = o.map, c.position_x = o.pos_x, c.position_y = o.pos_y,
    c.position_z = o.pos_z, c.orientation = o.orientation, c.zone = 0
WHERE FIND_IN_SET(CAST(c.guid AS CHAR), @wc_restore_guids) > 0 AND c.online = 0 AND c.deleteInfos_Account IS NULL
 AND c.instance_id = 0 AND COALESCE(c.transguid, 0) = 0 AND COALESCE(c.taxi_path, '''') = ''''
 AND c.map = camp.map
 AND POW(c.position_x - camp.pos_x, 2) + POW(c.position_y - camp.pos_y, 2) < 3600
 AND o.map IN (0, 1, 530, 571)
 AND ABS(o.pos_x) < 17066.666 AND ABS(o.pos_y) < 17066.666 AND ABS(o.pos_z) < 17066.666
 AND o.orientation >= 0 AND o.orientation <= 6.283186',
    'SELECT ''SKIPPED restoration: confirmations, GUID list, or schema checks not satisfied'' AS status');
PREPARE wc_uninstall_stmt FROM @wc_sql;
EXECUTE wc_uninstall_stmt;
SELECT ROW_COUNT() AS affected_rows; -- -1 means a status SELECT, not a mutation.
DEALLOCATE PREPARE wc_uninstall_stmt;

-- A single InnoDB UPDATE is atomic. Use a fresh default-autocommit connection.
-- Origin records are intentionally retained for review/export before table removal.
-- zone=0 clears the cached zone; the core recomputes it from the position on login.
