# Manual database cleanup

Use this package when removing Warband Camp, including when no pre-install backup
exists. It removes explicitly approved module data and restores only reviewed alt
locations. It cannot recreate database values the module never recorded.

## Strict execution protocol

1. **Stop the worldserver and keep it stopped.** Include any other worldserver or
   process that writes to the same characters/world databases. Do not permit logins
   while reviewing or applying cleanup. A configuration toggle is insufficient:
   camp startup creates tables even when disabled and GOMove has independent hooks.
2. **Back up the current characters and world databases**, even if the original
   pre-install backup was forgotten. This backup protects against a cleanup mistake;
   it does not recreate the pre-install state. Save the preview output too.
3. Run `01_preview_characters.sql` and `02_preview_world.sql` against the appropriate
   databases. Review ownership and whether another GOMove module still needs the
   commands, spell binding, spells, or scale table. The scripts cannot detect that
   dependency automatically. Review any legacy `wowlegends_*` tables separately.
4. Copy scripts you intend to execute to a private working directory outside the
   checkout. In each copy, set `@wc_expected_database` to the exact selected database
   name. Keep `@wc_execute = 0` while reviewing the configured selection. Set
   `@wc_server_stopped = 1` and `@wc_backup_confirmed = 1` only when those statements
   are true. Set the relevant action switches, then `@wc_execute = 1` to apply it.
   These flags are declarations by the operator, **not automatic verification**.
5. If there are saved alt origins, run the configured `03_restore_alt_positions.sql`
   **before** dropping camp tables. Review every remaining origin, export the records,
   and resolve or explicitly accept any position that could not be restored. Origins
   remain in the table even after successful restoration to retain the evidence.
6. Optionally run `06_optional_remove_placement_spell.sql` for selected characters.
   Run `04_remove_characters.sql` and the approved parts of `05_remove_world.sql`.
   Rerun both preview scripts afterward and check every retained/skipped item.
7. Remove the module from the core's modules directory and regenerate/rebuild/install
   the server without it **before restarting**. Remove its server configuration and
   client addon if no longer wanted. Client saved variables are separate from the
   server database; no SQL script touches them.

Run each entire file in a **fresh, default-autocommit connection**, using a UTF-8
client and the correct database. Do not execute isolated fragments or use a client's
`--force` option to continue after SQL errors. A `SKIPPED` status means the action
did not run; inspect it instead of assuming the uninstall is complete.

For example, read-only previews can be run as follows, substituting your user,
database names, and paths:

```bash
mysql --default-character-set=utf8mb4 -u acore -p acore_characters < tools/uninstall/01_preview_characters.sql
mysql --default-character-set=utf8mb4 -u acore -p acore_world < tools/uninstall/02_preview_world.sql
```

Execute a reviewed private copy similarly:

```bash
mysql --default-character-set=utf8mb4 -u acore -p acore_characters < /path/to/private/04_remove_characters.sql
```

The files deliberately contain no `USE` statement or hard-coded database names.
Every destructive file resets its switches to safe defaults on import; setting a
variable in a previous session does not enable it. Edit the settings at the top of
the private copy. Never put these files in `data/sql`, `base`, or `updates` import
directories. Normal installation and startup do not invoke them.

## Scripts and controls

| File | Scope and additional controls |
| --- | --- |
| `01_preview_characters.sql` | Read-only counts, legacy table detection, saved/current alt locations, location eligibility, and all holders of spell 27651. |
| `02_preview_world.sql` | Read-only commands, spell bindings, and scale overrides. |
| `03_restore_alt_positions.sql` | Requires `@wc_restore_guids = '123,456'` and `@wc_destinations_verified = 1`. Only eligible selected characters are updated. |
| `04_remove_characters.sql` | Requires `@wc_remove_camp_tables = 1`. Any remaining origin rows also require `@wc_origins_reviewed_and_exported = 1`. |
| `05_remove_world.sql` | Independent switches: `@wc_remove_commands`, `@wc_remove_spell_binding`, `@wc_remove_scale_table`. Leave shared resources at 0. |
| `06_optional_remove_placement_spell.sql` | Requires `@wc_remove_spell_guids = '123,456'` and `@wc_spell_ownership_confirmed = 1`. Removes only spell 27651 for those GUIDs. |

GUID lists must contain positive decimal numbers separated by commas, with no spaces.
Invalid or empty lists prevent the corresponding mutation. Lists are used as data,
never concatenated into executable SQL. The expected database name must match the
selected database exactly. All cleanup switches default to 0.

## What can be removed

After recovery and review, the character cleanup drops only these four tables:

- `mod_warband_camp_object`
- `mod_warband_camp_creature`
- `mod_warband_camp`
- `mod_warband_alt_origin`

This permanently removes every account's saved camps and camp contents. Current camp
props and creatures are recreated in memory from these records; the cleanup does
not delete ordinary `gameobject` or `creature` rows. In this implementation a camp
object's `spawn_guid` is its module record ID, not proof of a corresponding world
spawn's ownership. Never use it as a cross-database deletion key.

World cleanup can delete the exact `(27651, 'spell_gomove_place')` binding, the two
`gomove`/`gomovesearch` command rows, and `gomove_scale`. Command deletion additionally
requires security 0 and an exact match to the current installer help text. Customized
rows are shown afterward and preserved for manual handling. Matching help text alone
does not prove ownership: keep the switch at 0 if those rows predate this module.

Spell 27651 can be learned by ordinary builders **and GMs**, including at runtime.
No pre-existing-spell ledger exists. Review ownership per selected character; do not
assume account security or camp ownership proves the module originally granted it.

Legacy `wowlegends_warband_camp` and `wowlegends_warband_camp_object` tables are always
preserved. Current startup copies from them; it does not own their historical data.
The auth database and SQL updater history are not modified. If reinstalling later,
check the core updater's recorded imports and explicitly re-import the required base
SQL as needed; don't clear unrelated update history. Keeping legacy data can cause
the current module to import those camps again on a later installation.

## Alt recovery limits

Recovery requires the expected columns and an InnoDB `characters` table. A selected
character must be offline, not soft-deleted, not in an instance/transport/taxi state,
and on the same map within **less than 60 yards** of its account's existing camp.
That follows the current module's parked-alt location check. An origin without a
character or camp is shown in the preview and is never restored automatically.

Only saved maps 0, 1, 530, and 571 are accepted, with bounded coordinates and a valid
orientation. These checks do not validate terrain or prove that an origin is still
appropriate. Verify each destination manually; origin records do not contain the
old instance ID or transport context. Custom maps and uncertain origins need manual
recovery. Do not change the allowlist merely to bypass a failed check.

The script updates only map, position, orientation, and cached zone (reset to 0 for
the core to recompute on login). It leaves inventory, money, quests, XP, spells,
homebinds, and other progression untouched. Recovery is one atomic InnoDB update;
origin records are retained until the separate table cleanup. Repeating it while
the server remains stopped does not accumulate position changes.

## Limits and failure handling

- GM building mode can create, move, and delete persistent world objects without
  recording their previous state or complete ownership. These scripts preserve
  world spawn rows. A scale override is not evidence that an object was created by
  this module. Restoring such edits needs a backup or another reliable change record.
- Installation can overwrite existing command security with 0. Its previous value
  is unknown; cleanup never invents a permission level or deletes customized rows.
- Earned rested XP, historical group changes, and other gameplay effects cannot be
  reconstructed from the available module records.
- `DROP TABLE` implicitly commits in MySQL/MariaDB. The uninstall as a whole is
  **not transactional**. Missing tables are skipped and completed removals can be
  rerun. If any statement errors, stop, inspect, and resume from a reviewed state.
- The scripts need visibility of the relevant tables in `information_schema`, SELECT
  for previews, and only the UPDATE/DELETE/DROP privileges needed by chosen actions.
  They create no procedures, install no triggers, and change no core schema.

Example: a tester creates a camp with ten props and gathers two alts. The previews
show the camp, props, and saved origins. After checking the alts' saved destinations,
the administrator restores the eligible selected alts, exports/reviews the origins,
removes the camp tables and exclusively owned registrations, then removes/rebuilds
the module. An unrelated world object edited by a GM remains for manual recovery.

## Developer verification

`tests/test_uninstall.py` executes the shipped SQL against an isolated temporary
MariaDB data directory through the server's bootstrap mode. It never connects to a
running server and requires no existing database credentials. See its `--help` for
the server path and basedir options. No AzerothCore configure or build is needed.
