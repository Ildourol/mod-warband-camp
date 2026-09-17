-- ============================================================================
-- GOMove — AzerothCore SQL setup
-- Run against your acore_world database.
-- ============================================================================

-- Per-instance GameObject scale overrides
CREATE TABLE IF NOT EXISTS `gomove_scale` (
    `guid`  INT UNSIGNED NOT NULL,
    `scale` FLOAT        NOT NULL DEFAULT 1.0,
    PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Per-instance GameObject scale overrides (mod-gomove)';

-- GOMove command registrations
INSERT IGNORE INTO command (name, security, help) VALUES
('gomove', 2, 'Syntax: .gomove <id> [guid] [arg] — GOMove addon command for spawning, moving, and deleting GameObjects.'),
('gomovesearch', 2, 'Syntax: .gomovesearch <name|entry> — GOMove browser search. Queries gameobject_template and returns results to the addon.');

-- Placement spell binding (spell 27651 = ground-target placement)
INSERT IGNORE INTO spell_script_names (spell_id, ScriptName) VALUES (27651, 'spell_gomove_place');
