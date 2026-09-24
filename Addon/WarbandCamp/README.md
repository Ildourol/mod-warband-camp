# WarbandCamp Addon

A dedicated in-game player housing, camp management, and 3D construction toolkit for World of Warcraft: Wrath of the Lich King (3.3.5a) and AzerothCore (`mod-warband-camp`).

## Features

- **Warband Camp Management**: Claim ground, fast-travel, visit allies, gather alts, set privacy (public/guild/party/private), station training dummies, configure signpost greetings, and spawn from an extensive catalogue of 320+ props and service NPCs.
- **Native 3D Camp Builder**: Interactive 3D GameObject manipulation engine:
  - Directional compass keypad (North, South, East, West) with customizable step distance.
  - Elevation adjustment (Up, Down).
  - Fine rotation and per-object scaling.
  - Ground-target placement mode using the picnic blanket placement spell (Spell ID: 27651).
  - Pop-out floating movement HUD and floating object selection list.
- **Interactive 3D Camp Object Browser**: Full search engine (`.gomovesearch`) with 3D model preview and instant placement into your camp.
- **Favorites & Command History**: Pin frequently used camp actions and track real-time command execution history with instant re-run shortcuts.
- **Clean & Client-Safe**: Operates strictly via standard game chat protocols and server addon messages. Requires no custom client binaries or elevated privileges.

## Directory Structure

```
WarbandCamp/
├── Core/
│   ├── CommandRunner.lua        # Dot-command dispatcher
│   ├── GOMove.lua               # 3D building engine & protocol handler
│   ├── Init.lua                 # Namespace, defaults, and slash commands (/wb, /warband)
│   ├── SavedVars.lua            # SavedVariables persistence (WarbandCampDB)
│   ├── Util.lua                 # Palette and formatting helpers
│   └── Warband.lua              # Server .camp reply parser and session state
├── Data/
│   └── WarbandProps.lua         # 320+ prop & NPC definitions across 19 categories
├── UI/
│   ├── Tabs/
│   │   ├── Builder.lua          # 3D building keypad, elevation, rotation, and scaling
│   │   ├── Camp.lua             # Camp claim, travel, privacy, alts, and prop catalogue
│   │   ├── Favorites.lua        # Pinned camp & builder actions
│   │   └── History.lua          # Execution history
│   ├── CampObjectBrowser.lua    # 3D model viewer and search engine
│   ├── ConfirmDialog.lua        # Popups for dangerous commands and breaking camp
│   ├── MainFrame.lua            # Main tabbed panel with header and footer
│   ├── ToggleButton.lua         # Thematic Campfire launcher button
│   └── Widgets.lua              # UI components, rows, and buttons
├── README.md
└── WarbandCamp.toc
```

## Installation

1. Copy the `WarbandCamp` folder into your World of Warcraft client directory:
   ```
   World of Warcraft 3.3.5a/Interface/AddOns/WarbandCamp/
   ```

2. Ensure the folder name is strictly `WarbandCamp`.
3. Log into the game and verify that **Warband Camp** is checked and enabled in your character selection screen's **AddOns** menu (check "Load out of date AddOns" if required).

## Usage

- Click the mini **Campfire** toggle button on your screen or type `/wb` (or `/warband`, `/campui`) to open the main interface.
- Navigate across the **Camp**, **Builder**, **Favorites**, and **History** tabs to manage your campsite and construct objects in 3D.
- Type `/wb icon` (or `/wb minimap`) to toggle launcher button visibility, or `/wb reset` to restore positions to default.

## Compatibility

- World of Warcraft: Wrath of the Lich King 3.3.5a (Build 12340)
- Fully native to AzerothCore module `mod-warband-camp`

## Credits

- **AzerothCore Community**
- **Rochet2** — Original GOMove engine
- **Project Rx** — 3D GameObject model browser

## License

Released under the GNU AGPL v3 / MIT License.
