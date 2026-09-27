#!/usr/bin/env python3
"""Exercise uninstall SQL in a NEW temporary MariaDB datadir, without network access.

Example:
  python3 tests/test_uninstall.py --server /usr/sbin/mariadbd --basedir /usr
Only Python's standard library and an installed MariaDB server are required.
Never accepts an existing datadir, server address, or database credentials.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SQL = ROOT / 'tools/uninstall'
FILES = sorted(SQL.glob('*.sql'))
CHAR_DB = 'wc_test_characters'
WORLD_DB = 'wc_test_world'


def statements(source):
    """Split SQL outside quotes/comments; emit single-line bootstrap statements."""
    result, buf, quote, i = [], [], None, 0
    while i < len(source):
        c = source[i]
        if quote:
            buf.append(c)
            if c == '\\' and i + 1 < len(source):
                i += 1
                buf.append(source[i])
            elif c == quote:
                if i + 1 < len(source) and source[i + 1] == quote:
                    i += 1
                    buf.append(source[i])
                else:
                    quote = None
        elif c in "'\"`":
            quote = c
            buf.append(c)
        elif source.startswith('--', i) and (i + 2 == len(source) or source[i + 2].isspace()):
            end = source.find('\n', i)
            i = len(source) if end == -1 else end
            buf.append(' ')
        elif source.startswith('/*', i):
            end = source.find('*/', i + 2)
            if end == -1:
                raise ValueError('Unterminated SQL comment')
            i = end + 1
            buf.append(' ')
        elif c == ';':
            statement = ''.join(buf).strip()
            if statement:
                result.append(statement.replace('\n', ' ') + ';')
            buf = []
        else:
            buf.append(c)
        i += 1
    if quote or ''.join(buf).strip():
        raise ValueError('Unterminated SQL statement')
    return result


def literal(value):
    return str(value) if isinstance(value, int) else "'" + value.replace("'", "''") + "'"


def script(number, **settings):
    path = next(p for p in FILES if p.name.startswith(f'{number:02}_'))
    text = path.read_text()
    for key, value in settings.items():
        pattern = rf'(SET @{re.escape(key)} = )[^;]*;'
        text, n = re.subn(pattern, lambda m: m[1] + literal(value) + ';', text, count=1)
        if n != 1:
            raise AssertionError(f'Missing setting {key} in {path}')
    return text


def enabled(db, **extra):
    return dict(wc_expected_database=db, wc_execute=1, wc_server_stopped=1,
                wc_backup_confirmed=1, **extra)


def check(expression, name):
    # A failed SQL assertion deliberately references a nonexistent table and aborts.
    failure = 'SELECT * FROM assertion_failed_' + name
    return f"""SET @wc_assert = IF(COALESCE(({expression}), 0), 'DO 0', '{failure}');
PREPARE wc_assert_stmt FROM @wc_assert;
EXECUTE wc_assert_stmt;
DEALLOCATE PREPARE wc_assert_stmt;
"""


def table_count(names):
    quoted = ','.join(literal(name) for name in names)
    return f"(SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name IN ({quoted}))"


TABLES = ['mod_warband_camp', 'mod_warband_camp_object',
          'mod_warband_camp_creature', 'mod_warband_alt_origin']


def character_fixture():
    text = f"""CREATE DATABASE {CHAR_DB}; USE {CHAR_DB};
CREATE TABLE characters (
 guid INT UNSIGNED PRIMARY KEY, account INT UNSIGNED, name VARCHAR(20),
 map SMALLINT UNSIGNED, position_x FLOAT, position_y FLOAT, position_z FLOAT,
 orientation FLOAT, online TINYINT, instance_id INT, transguid INT, taxi_path TEXT,
 deleteInfos_Account INT NULL, zone INT, money INT, xp INT
) ENGINE=InnoDB;
CREATE TABLE character_spell (guid INT, spell INT, specMask INT, PRIMARY KEY(guid, spell)) ENGINE=InnoDB;
CREATE TABLE wowlegends_warband_camp (account_id INT PRIMARY KEY);
CREATE TABLE wowlegends_warband_camp_object (id INT PRIMARY KEY);
INSERT INTO wowlegends_warband_camp VALUES (999);
INSERT INTO wowlegends_warband_camp_object VALUES (999);
"""
    text += (ROOT / 'data/sql/db-characters/base/mod_warband_camp.sql').read_text()
    text += """
INSERT INTO mod_warband_camp (account_id,map,pos_x,pos_y,pos_z,orientation,phase_bit)
VALUES (10,0,0,0,0,0,1);
INSERT INTO mod_warband_camp_object (account_id,spawn_guid,entry,pos_x,pos_y,pos_z,orientation)
VALUES (10,1,100,0,0,0,0);
INSERT INTO mod_warband_camp_creature (account_id,entry,pos_x,pos_y,pos_z,orientation)
VALUES (10,100,0,0,0,0);
"""
    for guid in range(1, 18):
        text += f"INSERT INTO characters VALUES ({guid},10,'Alt{guid}',0,1,1,1,0,0,0,0,'',NULL,12,1234,5678);\n"
        text += f"INSERT INTO character_spell VALUES ({guid},27651,255),({guid},133,1);\n"
        if guid != 14:
            text += f"INSERT INTO mod_warband_alt_origin (guid,map,pos_x,pos_y,pos_z,orientation,parked_at) VALUES ({guid},1,100,200,300,1,1);\n"
    text += """
UPDATE characters SET position_x = 1000 WHERE guid=2;
UPDATE characters SET map=530 WHERE guid=3;
UPDATE characters SET online=1 WHERE guid=4;
UPDATE characters SET account=11 WHERE guid=5;
UPDATE characters SET deleteInfos_Account=10 WHERE guid=6;
UPDATE characters SET instance_id=1 WHERE guid=7;
UPDATE characters SET taxi_path='1 2' WHERE guid=8;
UPDATE characters SET transguid=1 WHERE guid=9;
UPDATE mod_warband_alt_origin SET map=33 WHERE guid=10;
UPDATE mod_warband_alt_origin SET pos_x=20000 WHERE guid=11;
UPDATE mod_warband_alt_origin SET orientation=-1 WHERE guid=12;
UPDATE mod_warband_alt_origin SET map=999 WHERE guid=15;
UPDATE characters SET position_x=60, position_y=0 WHERE guid=16;
UPDATE characters SET account=11 WHERE guid=17;
INSERT INTO mod_warband_alt_origin VALUES (999,1,100,200,300,1,1);
CREATE TABLE before_characters AS SELECT * FROM characters;
"""
    return text


def world_fixture():
    return f"""CREATE DATABASE {WORLD_DB}; USE {WORLD_DB};
CREATE TABLE command (name VARCHAR(50) PRIMARY KEY, security INT, help TEXT) ENGINE=InnoDB;
CREATE TABLE spell_script_names (spell_id INT, ScriptName VARCHAR(100), PRIMARY KEY(spell_id,ScriptName)) ENGINE=InnoDB;
CREATE TABLE gameobject (guid INT PRIMARY KEY, position_x FLOAT) ENGINE=InnoDB;
CREATE TABLE creature (guid INT PRIMARY KEY, position_x FLOAT) ENGINE=InnoDB;
INSERT INTO gameobject VALUES (1,555), (2,666);
INSERT INTO creature VALUES (1,777);
INSERT INTO command VALUES ('unrelated',3,'Keep me');
INSERT INTO spell_script_names VALUES (27651,'other_script'),(897,'spell_gomove_place');
""" + (ROOT / 'data/sql/db-world/base/mod_gomove.sql').read_text() + "INSERT INTO gomove_scale VALUES (1,2.5);\n"


def unchanged_characters(exclude='0'):
    columns = 'account name map position_x position_y position_z orientation online instance_id transguid taxi_path deleteInfos_Account zone money xp'.split()
    equal = ' AND '.join(f'c.{col} <=> b.{col}' for col in columns)
    return f'NOT EXISTS (SELECT 1 FROM characters c JOIN before_characters b USING(guid) WHERE c.guid NOT IN ({exclude}) AND NOT ({equal}))'


def suite():
    text = character_fixture() + world_fixture()
    text += f'USE {CHAR_DB};\n'
    # Defaults, even with stale enabled session variables, must not mutate anything.
    for num in [1, 3, 4, 6]:
        text += 'SET @wc_execute=1; SET @wc_remove_camp_tables=1;\n' + script(num)
    text += check(unchanged_characters(), 'default_character_positions')
    text += check(table_count(TABLES) + '=4', 'default_character_tables')
    text += check('(SELECT COUNT(*) FROM character_spell)=34', 'default_spells')
    text += f'USE {WORLD_DB};\n' + script(2) + script(5)
    text += check('(SELECT COUNT(*) FROM command)=3 AND (SELECT COUNT(*) FROM gomove_scale)=1', 'default_world')

    # Every common guard must independently block all four mutation scripts.
    cases = [(3, CHAR_DB, dict(wc_restore_guids='1', wc_destinations_verified=1)),
             (4, CHAR_DB, dict(wc_remove_camp_tables=1, wc_origins_reviewed_and_exported=1)),
             (5, WORLD_DB, dict(wc_remove_commands=1, wc_remove_spell_binding=1, wc_remove_scale_table=1)),
             (6, CHAR_DB, dict(wc_remove_spell_guids='1', wc_spell_ownership_confirmed=1))]
    for num, db, extra in cases:
        for guard, value in [('wc_execute',0), ('wc_server_stopped',0),
                             ('wc_backup_confirmed',0), ('wc_expected_database','wrong_database')]:
            settings = enabled(db, **extra)
            settings[guard] = value
            text += f'USE {db};\n' + script(num, **settings)
            if db == CHAR_DB:
                text += check(unchanged_characters()+' AND '+table_count(TABLES)+'=4 AND (SELECT COUNT(*) FROM character_spell)=34', f'guard_{num}_{guard}')
            else:
                text += check('(SELECT COUNT(*) FROM command)=3 AND (SELECT COUNT(*) FROM gomove_scale)=1 AND (SELECT COUNT(*) FROM spell_script_names)=3', f'guard_{num}_{guard}')

    text += f'USE {CHAR_DB};\n'
    for invalid in ['', '1, 2', '1); DROP TABLE characters; --', '0', '-1']:
        text += script(3, **enabled(CHAR_DB, wc_restore_guids=invalid, wc_destinations_verified=1))
        text += script(6, **enabled(CHAR_DB, wc_remove_spell_guids=invalid, wc_spell_ownership_confirmed=1))
    text += script(3, **enabled(CHAR_DB, wc_restore_guids='1'))
    text += script(6, **enabled(CHAR_DB, wc_remove_spell_guids='1'))
    text += check(unchanged_characters()+' AND (SELECT COUNT(*) FROM character_spell)=34', 'invalid_lists_and_ownership')
    text += script(4, **enabled(CHAR_DB, wc_remove_camp_tables=1))
    text += check(table_count(TABLES)+'=4', 'origins_block_all_drops')

    # Only selected eligible alt 1 recovers; alt 13 is eligible but not selected.
    selected = ','.join(str(x) for x in range(1,18) if x != 13) + ',999'
    recovery = script(3, **enabled(CHAR_DB, wc_restore_guids=selected, wc_destinations_verified=1))
    text += recovery
    text += check('(SELECT map=1 AND position_x=100 AND position_y=200 AND position_z=300 AND orientation=1 AND zone=0 AND money=1234 AND xp=5678 FROM characters WHERE guid=1)', 'eligible_alt_restored')
    text += check(unchanged_characters('1'), 'ineligible_and_unselected_alts_unchanged')
    text += check('(SELECT COUNT(*) FROM mod_warband_alt_origin)=17', 'origins_retained')
    text += recovery + check(unchanged_characters('1'), 'repeated_recovery')

    # Incompatible character schema must skip restoration, not partially update.
    text += 'ALTER TABLE characters DROP COLUMN zone;\n'
    text += script(3, **enabled(CHAR_DB, wc_restore_guids='13', wc_destinations_verified=1))
    text += check('(SELECT map=0 AND position_x=1 FROM characters WHERE guid=13)', 'incompatible_schema_skipped')
    text += 'ALTER TABLE characters ADD COLUMN zone INT DEFAULT 12;\n'
    text += 'ALTER TABLE characters ENGINE=MyISAM;\n'
    text += script(3, **enabled(CHAR_DB, wc_restore_guids='13', wc_destinations_verified=1))
    text += check('(SELECT map=0 AND position_x=1 FROM characters WHERE guid=13)', 'nontransactional_engine_skipped')
    text += 'ALTER TABLE characters ENGINE=InnoDB;\n'

    spell = script(6, **enabled(CHAR_DB, wc_remove_spell_guids='1,13', wc_spell_ownership_confirmed=1))
    text += spell + spell
    text += check('(SELECT COUNT(*) FROM character_spell)=32 AND (SELECT COUNT(*) FROM character_spell WHERE spell=133)=17 AND (SELECT COUNT(*) FROM character_spell WHERE guid=2 AND spell=27651)=1', 'precise_spell_removal')
    cleanup = script(4, **enabled(CHAR_DB, wc_remove_camp_tables=1, wc_origins_reviewed_and_exported=1))
    text += cleanup + cleanup + script(1) + recovery
    text += check(table_count(TABLES)+'=0', 'camp_tables_removed')
    text += check('(SELECT COUNT(*) FROM wowlegends_warband_camp)=1 AND (SELECT COUNT(*) FROM wowlegends_warband_camp_object)=1 AND (SELECT COUNT(*) FROM characters)=17', 'legacy_and_characters_preserved')

    text += f'USE {WORLD_DB};\n'
    text += "UPDATE command SET help='Custom help', security=2 WHERE name='gomovesearch';\n"
    text += script(5, **enabled(WORLD_DB))
    text += check('(SELECT COUNT(*) FROM command)=3 AND (SELECT COUNT(*) FROM gomove_scale)=1', 'shared_resources_preserved')
    world = script(5, **enabled(WORLD_DB, wc_remove_commands=1, wc_remove_spell_binding=1, wc_remove_scale_table=1))
    text += world + world + script(2)
    text += check("(SELECT COUNT(*) FROM command)=2 AND (SELECT security=2 AND help='Custom help' FROM command WHERE name='gomovesearch')", 'custom_commands_preserved')
    text += check("(SELECT COUNT(*) FROM spell_script_names)=2 AND (SELECT COUNT(*) FROM spell_script_names WHERE spell_id=897)=1", 'exact_binding_only')
    text += check(table_count(['gomove_scale'])+'=0', 'scale_removed')
    text += check('(SELECT SUM(position_x) FROM gameobject)=1221 AND (SELECT COUNT(*) FROM gameobject)=2 AND (SELECT position_x FROM creature WHERE guid=1)=777', 'world_spawns_preserved')

    # Partial / never installed schemas tolerate every script and enabled cleanup.
    text += 'CREATE DATABASE wc_empty; USE wc_empty;\n'
    for path in FILES:
        text += path.read_text()
    for num in [3,4,5,6]:
        settings = dict(cases[[3,4,5,6].index(num)][2])
        text += script(num, **enabled('wc_empty', **settings))
    text += check(table_count(TABLES+['gomove_scale','characters'])+'=0', 'empty_database_untouched')
    # A partially installed character schema with an empty origin table is removable.
    text += (ROOT / 'data/sql/db-characters/base/mod_warband_camp.sql').read_text()
    text += 'DROP TABLE mod_warband_camp_object;\n'
    text += script(4, **enabled('wc_empty', wc_remove_camp_tables=1))
    text += check(table_count(TABLES)+'=0', 'partial_install_removed')
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--server', required=True, help='Path to mariadbd')
    parser.add_argument('--basedir', required=True, help='MariaDB installation prefix')
    args = parser.parse_args()
    if len(FILES) != 6:
        raise AssertionError('Expected six shipped SQL scripts')
    with tempfile.TemporaryDirectory(prefix='warband-uninstall-test-') as directory:
        command = [str(Path(args.server).resolve()), '--no-defaults', '--bootstrap',
                   '--skip-grant-tables', '--skip-networking', f'--datadir={directory}',
                   f'--basedir={Path(args.basedir).resolve()}', '--innodb-buffer-pool-size=32M']
        if hasattr(os, 'geteuid') and os.geteuid() == 0:
            command.append('--user=root')
        # Confirm the assertion harness actually fails on a false condition.
        probe_sql = 'CREATE DATABASE wc_harness; USE wc_harness;\n' + check('0', 'probe')
        probe = subprocess.run(command, input='\n'.join(statements(probe_sql)) + '\n',
                               text=True, capture_output=True, timeout=90)
        if probe.returncode == 0 or 'assertion_failed_probe' not in probe.stderr:
            raise AssertionError('SQL assertion harness did not fail as expected:\n'+probe.stderr)
        body = '\n'.join(statements(suite())) + '\n'
        result = subprocess.run(command, input=body, text=True, capture_output=True, timeout=120)
        if result.returncode:
            raise AssertionError('Uninstall SQL integration test failed:\n'+result.stderr)
        print('PASS: defaults, all execution gates, precise recovery, schema/engine checks,')
        print('      origin protection, ownership controls, unrelated data preservation,')
        print('      partial/absent installs, and repeated execution (MariaDB bootstrap).')


if __name__ == '__main__':
    main()
