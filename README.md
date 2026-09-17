# Warband Camp for AzerothCore (mod-warband-camp)

<p align="center">
  <img src="assets/banner.png" alt="Warband Camp Banner" width="850">
</p>

<p align="center">
  <a href="https://github.com/azerothcore/azerothcore-wotlk"><img src="https://img.shields.io/badge/AzerothCore-WotLK%203.3.5a-blue.svg" alt="AzerothCore"></a>
  <a href="https://github.com/Ildourol/mod-warband-camp/blob/master/conf/mod_warband_camp.conf.dist"><img src="https://img.shields.io/badge/Configuration-Fully%20Configurable-brightgreen.svg" alt="Configurable"></a>
  <a href="https://github.com/Ildourol/mod-warband-camp/blob/master/LICENSE"><img src="https://img.shields.io/badge/License-GNU%20AGPL%20v3-lightgrey.svg" alt="License"></a>
</p>

---

## Description

**mod-warband-camp** is a standalone player housing, open-world campsite, and warband module for AzerothCore (WotLK 3.3.5a).

A camp is a shared plot of land that belongs to your **ACCOUNT**, rather than a single character. Every character you create shares the same campsite, and visiting players can explore what you have designed and built.

---

## Features

- **Personal Open-World Camps**: Claim ground where you stand (`.camp claim`) almost anywhere across the open world (restrictions apply to capital cities, sanctuaries, instances, battlegrounds/arenas, water surfaces, moving transports, and mid-air).
- **Dynamic Phasing Isolation**:
  - Each camp is allocated a dynamic phase bit (1 to 31).
  - Up to 31 distinct camps can coexist within 600 yards of each other; phase bits are reused beyond 600 yards across the realm.
  - Stepping within 40 yards seamlessly phases the player into `PHASEMASK_NORMAL | (1 << campBit)`. Players continue viewing normal world terrain, buildings, NPCs, and regular players.
- **50+ Stock 3.3.5a Scenery Props**:
  - Tents (Alliance, Horde, neutral, large), campfires, bonfires, braziers, lanterns, tables, chairs, benches, rugs, bookshelves, crates, barrels, kegs, cauldrons, wagons, haystacks, fences, anvils, forges, banners, skulls, totems, outhouses, doghouses, pavilions, and cottages.
  - All scenery objects are inert type-5 generic gameobjects (`GAMEOBJECT_TYPE_GENERIC`) validated against `GameObjectDisplayInfo.dbc` on startup.
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
- **Integrated GOMove GameObject Management**:
  - In-game GameObject placement, directional nudging (compass, axis, rotation), scaling, and deletion.
  - Search `gameobject_template` with 3D model preview via `.gomovesearch`.
  - Ground-target spell placement mode (Spell ID: 27651 - *Picnic Blanket Ritual Effect*).
  - Automatically grants the placement spell to Game Master level accounts upon login.
  - Per-instance GameObject scale overrides persisted across server restarts.

---

## Directory Structure

```
mod-warband-camp/
├── conf/
│   └── mod_warband_camp.conf.dist       # Module configuration template
├── data/
│   └── sql/
│       ├── db-characters/
│       │   └── base/
│       │       ├── mod_warband_camp.sql         # Character database schema
│       │       └── mod_gomove_characters.sql    # GOMove GM character spell grant
│       └── db-world/
│           └── base/
│               └── mod_gomove.sql               # GOMove world DB schema & commands
├── src/
│   ├── mod_warband_camp_loader.cpp      # Script loader entry point
│   ├── warband_camp.cpp                 # Core C++ implementation
│   ├── GOMove.h                         # GOMove header
│   ├── GOMove.cpp                       # GOMove core operations
│   └── GOMoveScripts.cpp                # GOMove commands & placement spell script
├── CMakeLists.txt                       # Build script
├── assets/                              # Documentation media
├── acore-module.json                    # Module metadata
├── include.sh                           # Build script hook
└── LICENSE                              # GNU AGPL v3 License
```

---

## Installation

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
   - Database tables are automatically verified and created in your `characters` database upon worldserver startup.
   - Alternatively, import manually if desired:
     ```bash
     mysql -u acore -p acore_characters < ../modules/mod-warband-camp/data/sql/db-characters/base/mod_warband_camp.sql
     ```

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
| `.gomove <id> [guid] [arg]` | Game Master | GOMove core command for spawning, moving, nudging, and deleting GameObjects. |
| `.gomovesearch <name\|entry>` | Game Master | GOMove browser search. Queries `gameobject_template` and returns results. |

---

## Configuration

Detailed configuration options are documented in `conf/mod_warband_camp.conf.dist`. Key settings include:

| Option | Default | Description |
| :--- | :---: | :--- |
| `WarbandCamp.Enabled` | `1` | Enable or disable the Warband Camp system |
| `WarbandCamp.MaxProps` | `200` | Maximum number of props allowed per camp (0 = unlimited) |
| `WarbandCamp.ViewDistance` | `40` | Yards before a camp phases into view (clamped 20–250) |
| `WarbandCamp.AutoAlts` | `1` | Automatically wake account alts around the camp upon login |
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
  - [QOLAddon](https://github.com/Ildourol/QOLAddon)

---

## Credits

- **Rochet2** — Original GOMove addon and server implementation.
- **Project Rx** — AzerothCore GOMove port and GameObject Browser extension.
- **WOW Legends** — Original Warband Camp implementation.

---

## License

Released under the GNU AGPL v3 License. See [`LICENSE`](file:///C:/Users/Admin/AntigravityProfiles/Projects%20Azerothcore/Azerothcore%20modules/mod-warband-camp/LICENSE) for details.
