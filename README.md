# Warband Camp for AzerothCore (`mod-warband-camp`)

A standalone player housing, camp, and warband module for AzerothCore (WotLK 3.3.5a), extracted and decoupled from WOW Legends.

A camp is a patch of ground that belongs to your **ACCOUNT**, not to a single character. Every character you own shares the same camp, and any other player can walk in and see what you have built.

---

## Features

- **Personal Open-World Camps**: Claim ground where you stand (`.camp claim`) almost anywhere in the open world (restrictions apply to capital cities, sanctuaries, instances, arenas, water, transports, and mid-air).
- **Dynamic Phasing Isolation**:
  - Each camp is assigned a dynamic phase bit (1–31).
  - Up to 31 camps can co-exist within 600 yards of each other; phase bits are reused beyond 600 yards across the realm.
  - Stepping within 40 yards seamlessly phases the player into `PHASEMASK_NORMAL | (1 << campBit)`. Players continue seeing normal world terrain, buildings, NPCs, and other players.
- **50+ Stock 3.3.5a Scenery Props**:
  - Tents (Alliance, Horde, neutral, large), campfires, bonfires, braziers, lanterns, tables, chairs, benches, rugs, bookshelves, crates, barrels, kegs, cauldrons, wagons, haystacks, fences, anvils, forges, banners, skulls, totems, outhouses, doghouses, pavilions, and cottages.
  - All props are inert type-5 generic gameobjects (`GAMEOBJECT_TYPE_GENERIC`) validated against `GameObjectDisplayInfo.dbc` on startup.
- **Rested XP & Instant Logout**:
  - Standing inside your camp bubble grants resting status (`REST_FLAG_IN_TAVERN`), allowing instant logout without the 20-second countdown, and accumulates Rested XP while logged out.
- **Personal Camp Mailbox**:
  - Place a functioning personal mailbox (`.camp place mailbox`) in your camp (limit: 1 per camp).
- **Camp Training Dummy**:
  - Station a combat training dummy (`.camp dummy [80|boss|normal]`) inside your camp's phase for rotation and DPS testing.
- **Fine-Tuned Placement & Undo**:
  - Place props with custom rotation angles: `.camp place <prop> [angle_in_degrees]`.
  - Immediately undo and pack away your last placed item with `.camp undo`.
- **Custom Welcome Greeting**:
  - Set a custom signpost greeting message (`.camp message <text>`) displayed to visitors as they enter your camp.
- **Granular Privacy Controls**:
  - Control who can view and enter your camp: `.camp privacy <public|guild|party|private>`.
- **Social & Discovery**:
  - `.camp go`: Travel to your camp (5-minute cooldown).
  - `.camp visit <player>`: Travel to another player's camp (respects privacy settings).
  - `.camp list`: Discover nearby accessible camps on the same continent.
- **Server Health & Administration**:
  - Inactive camps past the configured threshold (`WarbandCamp.InactivityDays`) are automatically pruned on startup to free land.
  - Configurable map and zone blacklists to prevent claims in restricted areas.
  - Live configuration reload (`.camp reload`) without restarting the server.
- **Optional Warband Alts Integration (with `mod-playerbots`)**:
  - If `mod-playerbots` is installed, `.camp alts` and `WarbandCamp.AutoAlts` wake up the player's offline alts and gather them around the campfire.
  - Parked alts stroll around the camp perimeter.
  - When a player logs into one of their parked alts as a human, the character is automatically restored to their previous location in the world.
  - **Zero Core Changes**: If `mod-playerbots` is not installed, the module compiles and runs cleanly with zero errors.

---

## Installation

1. Copy or clone this folder into your AzerothCore `modules/` directory:
   ```
   azerothcore-wotlk/modules/mod-warband-camp/
   ```
2. Re-run CMake to generate build files:
   ```bash
   cd azerothcore-wotlk/build
   cmake ..
   ```
3. Compile the core as usual (e.g. `ninja`, `make`, or Visual Studio).
4. Copy `conf/mod_warband_camp.conf.dist` to your server's config directory (e.g., `etc/mod_warband_camp.conf`) and customize settings as desired.
5. Database tables and columns are automatically created and verified in your `characters` database on startup.

---

## Commands

| Command | Security | Description |
| :--- | :--- | :--- |
| `.camp` | Player | Shows where your camp is, privacy level, greeting, and prop count. |
| `.camp claim` | Player | Claim the ground where you are standing as your camp. |
| `.camp go` | Player | Teleport to your camp (5-minute cooldown). |
| `.camp leave` | Player | Strike camp and clear all placed props (requires confirmation). |
| `.camp props` | Player | List all prop keys you can place. |
| `.camp place <prop> [angle]` | Player | Set up a prop in front of you, with optional rotation angle (-360 to 360 degrees). |
| `.camp undo` | Player | Immediately pack away the most recently placed item. |
| `.camp remove` | Player | Pack away the nearest prop in front of you. |
| `.camp dummy [80/boss/normal/remove]` | Player | Station or remove a combat training dummy in your camp. |
| `.camp message [text/clear]` | Player | Set or view a welcome greeting message shown to visitors. |
| `.camp privacy [public/party/guild/private]` | Player | View or update who can see and enter your camp. |
| `.camp visit <player>` | Player | Travel to another player's camp (if privacy allows). |
| `.camp list` | Player | List accessible camps on this continent. |
| `.camp alts` | Player | Rouse your account's other characters to gather round the fire (requires `mod-playerbots`). |
| `.camp catalogue` | Game Master | Layout all available props in a grid for inspection and screenshots. |
| `.camp diag <player>` | Administrator | Diagnostic test verifying terrain, phase allocation, and prop spawning. |
| `.camp reload` | Administrator | Reload configuration and blacklists without restarting the server. |

---

## Configuration (`mod_warband_camp.conf`)

| Option | Default | Description |
| :--- | :--- | :--- |
| `WarbandCamp.Enabled` | `1` | Enable/disable the Warband Camp system. |
| `WarbandCamp.MaxProps` | `200` | Maximum number of props allowed per camp (0 = unlimited). |
| `WarbandCamp.ViewDistance`| `40` | Yards before a camp phases into view (clamped 20–250). |
| `WarbandCamp.AutoAlts` | `1` | Automatically wake account alts around the camp upon login (requires `mod-playerbots`). |
| `WarbandCamp.AltsSameFactionOnly` | `1` | Only gather alts belonging to the same faction as the active player character. |
| `WarbandCamp.EnableRestedXP` | `1` | Grant rested XP and instant logout when players are inside their camp. |
| `WarbandCamp.EnableMailbox` | `1` | Allow players to place a personal camp mailbox (`.camp place mailbox`). |
| `WarbandCamp.EnableTrainingDummy` | `1` | Allow players to spawn a training dummy in their camp (`.camp dummy`). |
| `WarbandCamp.InactivityDays` | `90` | Automatically release camps inactive for X days (0 = disabled). |
| `WarbandCamp.BlacklistedMaps` | `""` | Comma-separated list of Map IDs where camps cannot be claimed. |
| `WarbandCamp.BlacklistedZones` | `""` | Comma-separated list of Zone/Area IDs where camps cannot be claimed. |

---

## License

GNU AGPL v3. See `LICENSE` for details.
