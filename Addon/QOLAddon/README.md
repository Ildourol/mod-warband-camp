# QOLAddon

A quality-of-life player toolkit addon for World of Warcraft: Wrath of the Lich King (3.3.5a) and AzerothCore.

## Features

- Party and AI Bot Command Suite: Build, configure, and command bot companions with role assignment, talent specifications, formations, and combat behaviors.
- Dungeon Clear Automation: Automated dungeon clearing commands assisting tank companions and path navigation.
- Warband Camp Integration: Manage and interact with your account Warband Camp props, alts, and camp configurations directly from the user interface.
- Favorited Commands and Execution History: Save frequent commands, track run histories, and execute actions with single-click shortcuts.
- Fully Client-Side Safe: Dispatches standard player commands using existing client chat protocols. Does not require custom client binaries or specialized permissions.

## Directory Structure

```
QOLAddon/
├── Core/
│   ├── CommandRunner.lua
│   ├── DungeonClear.lua
│   ├── Init.lua
│   ├── SavedVars.lua
│   ├── Util.lua
│   └── Warband.lua
├── Data/
│   ├── Specs.lua
│   └── WarbandProps.lua
├── UI/
│   ├── Tabs/
│   │   ├── Bots.lua
│   │   ├── DungeonClear.lua
│   │   ├── Favorites.lua
│   │   ├── History.lua
│   │   └── Warband.lua
│   ├── ConfirmDialog.lua
│   ├── MainFrame.lua
│   ├── ToggleButton.lua
│   └── Widgets.lua
└── QOLAddon.toc
```

## Installation

1. Download or clone this repository:
   ```bash
   git clone https://github.com/Ildourol/QOLAddon.git
   ```

2. Place the `QOLAddon` folder into your World of Warcraft client directory:
   ```
   World of Warcraft 3.3.5a/Interface/AddOns/QOLAddon/
   ```

3. Ensure the folder name is strictly `QOLAddon`.
4. Log into the game and verify that **QOL Addon** is checked and enabled in your character selection screen's **AddOns** menu (check "Load out of date AddOns" if required).

## Usage

- Click the mini toggle button on your screen or type `/qol` to open the main interface.
- Navigate across the Bots, Dungeon Clear, Warband, Favorites, and History tabs to manage your party and camp.

## Compatibility

- World of Warcraft: Wrath of the Lich King 3.3.5a (Build 12340)
- Compatible with AzerothCore, `mod-playerbots`, and `mod-warband-camp`

## License

Released under the MIT / AzerothCore Community License.
