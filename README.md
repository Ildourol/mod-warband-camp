# Warband Camp for AzerothCore (mod-warband-camp)

<p align="center">
  <img src="assets/banner.png" alt="Warband Camp Banner" width="850">
</p>

<p align="center">
  <a href="https://github.com/azerothcore/azerothcore-wotlk"><img src="https://img.shields.io/badge/AzerothCore-WotLK%203.3.5a-blue.svg" alt="AzerothCore"></a>
  <a href="https://github.com/Ildourol/mod-warband-camp/blob/main/conf/mod_warband_camp.conf.dist"><img src="https://img.shields.io/badge/Configuration-Fully%20Configurable-brightgreen.svg" alt="Configurable"></a>
  <a href="https://github.com/Ildourol/mod-warband-camp/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-GNU%20AGPL%20v3-lightgrey.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/Zero%20Core%20Edits-100%25-success.svg" alt="Zero Core Edits">
  <img src="https://img.shields.io/badge/Architecture-In--Memory%20Async-orange.svg" alt="In-Memory Async">
</p>

---

## Description

**mod-warband-camp** is a comprehensive player housing, open-world campsite, warband gathering, and native in-game 3D construction module for AzerothCore (WotLK 3.3.5a).

It seamlessly unifies the **Warband Camp** system (account-wide campsite, custom dynamic phasing, rest bonuses, and camp customization) with a high-performance **3D Construction Engine** into ONE coherent camp-owned construction system. Players use integrated 3D building tools (compass keypad, elevation, rotation, scale, ground-target placement, and 3D model browser) strictly for their own camp-owned objects—sharing identical database persistence, phase isolation, limits, and cleanup—while Game Masters retain unrestricted administrative world-building capabilities.

Designed from the ground up for high-population production servers, the module features **zero core edits**, fully in-memory caching to eliminate world-thread stalls, non-blocking asynchronous database writes, atomic transactions, and selective script hook registration.

---

## Key Features

- **Personal Open-World Camps**: Claim ground where you stand (`.camp claim`) almost anywhere across the open world (restrictions apply to capital cities, sanctuaries, instances, battlegrounds/arenas, water surfaces, moving transports, and mid-air).
- **Dynamic Phasing Isolation**:
  - Each camp is allocated a dynamic phase bit (1 to 31).
  - Up to 31 distinct camps can coexist within 600 yards of each other; phase bits are reused beyond 600 yards across the realm.
  - Stepping within 40 yards seamlessly phases the player into `PHASEMASK_NORMAL | (1 << campBit)`. Players continue viewing normal world terrain, buildings, NPCs, and regular players.
- **320+ Stock 3.3.5a Scenery Props & Camp NPCs**:
  - Extensive tents, shelters, pavilions, watchtowers, furniture, beds, chairs, tables, rugs, bookcases, wardrobes, lights, braziers, fire bowls, food platters, harvest crates, barrels, chests, garden flora, trees, portals, and faction banners.
  - Thematic categories: Shelter, Fire & Light, Furniture, Storage & Amenities, Yard, Craft, Defenses & Fortifications, Banners, Lights, Food & Provisions, Trophies & The Hunt, Graveyard & Dark Arts, Treasures & Curios, Atmosphere, Nature, Professions, Buildings, Portals, and Trainers & NPCs.
  - Fully deduplicated: every item has a unique command key, unique display label, unique entry ID, and unique 3D model, appearing in exactly one category.
  - Camp service NPCs & trainers: Banker, Stable Master (pet care), Vendor/Repairs, Reagents, Poison & Alchemy Specialist, Camp Guards (Stormwind & Orgrimmar), Innkeeper, Auctioneer, class trainers, and profession trainers.
  - Inert scenery objects are validated against `GameObjectDisplayInfo.dbc` and NPCs against `creature_template` on startup.
- **Native 3D Camp Construction Engine**:
  - In-game GameObject placement, directional nudging (compass, axis, rotation), scaling, and deletion.
  - Search `gameobject_template` with 3D model preview via `.gomovesearch`.
  - Ground-target spell placement mode (Spell ID: 27651 - *Picnic Blanket Ritual Effect*).
  - Automatically grants the placement spell to Game Master level accounts upon login.
  - Per-instance GameObject scale overrides persisted across server restarts.
- **Dedicated In-Game Client UI (`WarbandCamp`)**:
  - Bundled in-game UI addon (`Addon/WarbandCamp`) with dedicated Camp management, 3D Builder tab, and interactive 3D model browser.
  - Full camp management UI: claim, teleport, customize, and place 320+ props and NPCs.
  - Real-time 3D object manipulation: nudge, rotate, scale, ground-target placement spell (Spell ID: 27651), and nearby target selection.
  - Thematic Campfire launcher button and slash commands (`/wb`, `/warband`, `/campui`).
- **Rested XP and Instant Logout**:
  - Standing inside your camp perimeter grants resting status (`REST_FLAG_IN_TAVERN`), allowing instant logout without the 20-second timer, and accumulates Rested XP while logged off.
- **Personal Camp Mailbox**:
  - Place a functioning personal mailbox (`.camp place mailbox`) inside your camp (limit: 1 per camp).
- **Camp Training Dummy**:
  - Station a combat training dummy (`.camp dummy [80|boss|normal]`) inside your camp's phase for rotation and DPS testing.
- **Fine-Tuned Placement and Undo**:
  - Place props with customized rotation angles: `.camp place <prop> [angle_in_degrees]`.
  - Undo and pack away your last placed object with `.camp undo`.
- **Custom Welcome Greeting**:
  - Set a custom signpost greeting message (`.camp message <text>`) displayed to visitors as they cross your camp threshold.
- **Granular Privacy Controls**:
  - Manage who can discover and enter your camp: `.camp privacy <public|guild|party|private>`.
- **Social and Fast Travel**:
  - `.camp go`: Teleport to your camp (5-minute cooldown).
  - `.camp visit <player>`: Travel to another player's camp (respects privacy settings).
  - `.camp list`: Discover nearby accessible camps on the same continent.
- **Server Health and Automated Cleanup**:
  - Camps inactive past the configured threshold (`WarbandCamp.InactivityDays`) are pruned on startup to free land.
  - Blacklist specific maps and zones to prevent claims in restricted areas.
  - Live configuration reload (`.camp reload`) without restarting the worldserver.
- **Optional Warband Alts Integration (with `mod-playerbots`)**:
  - When `mod-playerbots` is installed, `.camp alts` and `WarbandCamp.AutoAlts` rouse the player's offline alts to gather around the campfire and stroll along the perimeter.
  - Logging into a parked alt restores the character to their previous location in the world.
  - Zero hard dependencies: If `mod-playerbots` is not present, the module compiles and runs cleanly.

---

## High-Performance Architecture & Stability Engine

To guarantee zero tick-drop and high concurrency even under heavy server load, `mod-warband-camp` implements a high-performance backend architecture:

1. **In-Memory Caching (0ms World-Thread Stalls)**:
   - All camp props and phased creatures are bulk-loaded into RAM on startup.
   - Proximity phasing checks (`UpdatePlayerCampPhase`), builder nudges, elevation tweaks, and scaling operate directly against in-memory records, completely eliminating blocking SQL queries from the server update loop.
2. **Non-Blocking Asynchronous Database I/O**:
   - 3D manipulations (`MoveCampObject`, `ScaleCampObject`, `DeleteCampObject`) apply updates to memory immediately and dispatch persistent database writes asynchronously via `CharacterDatabase.Execute(...)`.
3. **Atomic Multi-Table Transactions**:
   - Critical multi-table state modifications (e.g. `.camp leave confirm` or abandoned camp pruning on startup) are wrapped in atomic `SQLTransaction` blocks, guaranteeing referential integrity across `mod_warband_camp`, `mod_warband_camp_object`, and `mod_warband_camp_creature`.
4. **Selective Event Hook Registration**:
   - `PlayerScript` and `WorldScript` constructors declare explicit hook vectors (e.g. `{ PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT }`), preventing AzerothCore from registering all 150+ player hooks and eliminating unnecessary virtual method dispatch across every action on the realm.
5. **Thread-Safe Concurrency**:
   - All shared global state (`g_camps`, `g_liveProps`, `g_liveCreatures`, `g_parkedAlts`, and scale caches) is synchronized via `std::mutex` guards, guaranteeing safe execution across command threads and map worker threads.
6. **Self-Healing Schema & Lifecycle Management**:
   - Schema tables, missing columns, and database indexes (`idx_account_entry`, `gomove_scale`) are verified and created automatically on startup.
   - Character deletion events (`PLAYERHOOK_ON_DELETE` and `PLAYERHOOK_ON_DELETE_FROM_DB`) automatically cascade to clean up alt origin records, preventing orphaned database rows.
7. **Zero Core Edits**:
   - Integrates 100% via AzerothCore's modular script engine without modifying a single line of core server code.

---

## Directory Structure

```
mod-warband-camp/
├── Addon/
│   └── WarbandCamp/                     # Client-side UI addon (WotLK 3.3.5a)
│       ├── Core/                        # Command runner & 3D client controller
│       ├── Data/                        # Prop & NPC definitions (WarbandProps.lua)
│       ├── UI/                          # Tabbed interface, 3D browser, & widgets
│       ├── README.md                    # Addon documentation
│       └── WarbandCamp.toc              # Addon manifest (WarbandCampDB, GOMoveSV)
├── conf/
│   └── mod_warband_camp.conf.dist       # Module configuration template
├── data/
│   └── sql/
│       ├── db-characters/
│       │   └── base/
│       │       ├── mod_warband_camp.sql         # Character database schema & indexes
│       │       └── mod_gomove_characters.sql    # GM character spell grant
│       └── db-world/
│           └── base/
│               └── mod_gomove.sql               # 3D building world DB schema & commands
├── src/
│   ├── mod_warband_camp_loader.cpp      # Script loader entry point
│   ├── warband_camp.cpp                 # Core C++ implementation & memory cache
│   ├── WarbandCamp.h                    # Camp services & permissions header
│   ├── GOMove.h                         # 3D building engine header
│   ├── GOMove.cpp                       # 3D building operations & scale cache
│   └── GOMoveScripts.cpp                # 3D building commands & placement spell script
├── CMakeLists.txt                       # Build script
├── assets/                              # Documentation media
├── acore-module.json                    # Module metadata
├── include.sh                           # Build script hook
└── LICENSE                              # GNU AGPL v3 License
```

---

## Installation

### 1. Module Setup
1. Clone this repository into your AzerothCore `modules/` directory:
   ```bash
   cd azerothcore-wotlk/modules
   git clone https://github.com/Ildourol/mod-warband-camp.git
   ```

2. Re-generate CMake and compile the core:
   ```bash
   cd azerothcore-wotlk/build
   cmake ../ -DCMAKE_INSTALL_PREFIX=/path/to/server
   make -j $(nproc)
   make install
   ```

3. Copy the configuration template:
   ```bash
   cp ../modules/mod-warband-camp/conf/mod_warband_camp.conf.dist /path/to/server/etc/mod_warband_camp.conf
   ```

4. Database Setup:
   - Database tables and indexes are automatically verified and created in your `characters` and `world` databases on worldserver startup.
   - Alternatively, import manually if desired:
     ```bash
     mysql -u acore -p acore_characters < ../modules/mod-warband-camp/data/sql/db-characters/base/mod_warband_camp.sql
     mysql -u acore -p acore_characters < ../modules/mod-warband-camp/data/sql/db-characters/base/mod_gomove_characters.sql
     mysql -u acore -p acore_world < ../modules/mod-warband-camp/data/sql/db-world/base/mod_gomove.sql
     ```

### 2. Client Addon Installation
1. Copy the bundled `Addon/WarbandCamp` folder into your World of Warcraft client directory:
   ```
   World of Warcraft/
   └── Interface/
       └── AddOns/
           └── WarbandCamp/
   ```
2. Verify that **Warband Camp** is enabled in your character selection screen's **AddOns** menu (check "Load out of date AddOns" if required).
3. Open the interface in-game by clicking the mini **Campfire** toggle button or by typing `/wb` (or `/warband`, `/campui`).

---

## Commands

| Command | Security | Description |
| :--- | :--- | :--- |
| `.camp` | Player | Shows camp location, privacy status, greeting, and prop count. |
| `.camp claim` | Player | Claim the ground where you stand as your camp. |
| `.camp go` | Player | Teleport to your camp (5-minute cooldown). |
| `.camp leave` | Player | Strike camp and clear all placed props (requires confirmation). |
| `.camp props` | Player | List all prop keys available to place. |
| `.camp place <prop> [angle]` | Player | Place a prop in front of you, with optional rotation (-360 to 360 degrees). |
| `.camp undo` | Player | Pack away the most recently placed item. |
| `.camp remove` | Player | Pack away the nearest prop in front of you. |
| `.camp dummy [80/boss/normal/remove]` | Player | Station or remove a combat training dummy. |
| `.camp message [text/clear]` | Player | Set or clear welcome message displayed to visitors. |
| `.camp privacy [public/party/guild/private]` | Player | View or update camp privacy permissions. |
| `.camp visit <player>` | Player | Travel to another player's camp (if privacy allows). |
| `.camp list` | Player | List accessible camps on the current continent. |
| `.camp alts` | Player | Gather account alts around the fire (requires `mod-playerbots`). |
| `.camp catalogue` | Game Master | Layout available props in a grid for inspection. |
| `.camp diag <player>` | Administrator | Diagnostic verification of terrain, phases, and prop spawning. |
| `.camp reload` | Administrator | Reload configuration and blacklists without restart. |
| `.gomove <id> [guid] [arg]` | Player / GM | In Camp Builder Mode (Player): spawn, nudge, rotate, scale, or remove camp-owned props. In Admin Mode (GM): manipulate persistent world GameObjects. |
| `.gomovesearch <name\|entry>` | Player / GM | Search object templates with 3D model preview. Non-GM players are filtered to safe decor and camp props. |

---

## Configuration

Detailed configuration options are documented in `conf/mod_warband_camp.conf.dist`. Key settings include:

| Option | Default | Description |
| :--- | :---: | :--- |
| `WarbandCamp.Enabled` | `1` | Enable or disable the Warband Camp system |
| `WarbandCamp.EnableBuilding` | `1` | Enable player camp building and editing via the 3D construction interface and browser |
| `WarbandCamp.MaxProps` | `200` | Maximum number of props allowed per camp (0 = unlimited) |
| `WarbandCamp.ViewDistance` | `40` | Yards before a camp phases into view (clamped 20–250) |
| `WarbandCamp.AutoAlts` | `1` | Automatically wake account alts around the camp upon login (requires `mod-playerbots`) |
| `WarbandCamp.AltsSameFactionOnly` | `1` | Only gather alts belonging to the same faction as the active player |
| `WarbandCamp.EnableRestedXP` | `1` | Grant rested XP and instant logout when players are inside their camp |
| `WarbandCamp.EnableMailbox` | `1` | Allow players to place a personal camp mailbox (`.camp place mailbox`) |
| `WarbandCamp.EnableTrainingDummy` | `1` | Allow players to spawn a training dummy (`.camp dummy`) |
| `WarbandCamp.InactivityDays` | `90` | Automatically release camps inactive for X days (0 = disabled) |
| `WarbandCamp.BlacklistedMaps` | `""` | Comma-separated list of Map IDs where camps cannot be claimed |
| `WarbandCamp.BlacklistedZones` | `""` | Comma-separated list of Zone/Area IDs where camps cannot be claimed |

---

## Compatibility and Requirements

- **AzerothCore WotLK (branch `master`)**
- **Client**: World of Warcraft: Wrath of the Lich King (3.3.5a - Build 12340)
- Compatible with:
  - [mod-playerbots](https://github.com/liyunfan1223/mod-playerbots)
  - Bundled `WarbandCamp` addon (included under `Addon/WarbandCamp`)

---

## Credits

- **AzerothCore Community**
- **Rochet2** — Original GOMove engine
- **Project Rx** — 3D GameObject Browser extension
- **WOW Legends** — Original Warband Camp implementation

---

## License

Released under the GNU AGPL v3 License. See [`LICENSE`](file:///C:/Users/Admin/AntigravityProfiles/Projects%20Azerothcore/Azerothcore%20modules/mod-warband-camp/LICENSE) for details.
