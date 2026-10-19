# RLMmods

**Save, Load and Randomize buttons for the Helldivers 2 Hellpod loadout screen.**

[한국어 안내](README.ko.md) · [Download (Releases)](https://github.com/modocracy/RLMods/releases)

> Uses research from HD2Runtime by SkyeShade — https://github.com/SkyeShade/HD2Runtime

## Features

| Button | What it does |
| --- | --- |
| **Save** | Stores your current stratagems, booster, helmet, armor, cape, primary, secondary and grenade. |
| **Load** | Restores the saved loadout. Slots already matching are left alone; anything not selectable right now (mission rules, a squadmate's booster, not owned) is skipped. |
| **Randomize** | Picks a random loadout from what the game lists as selectable for you. |

Randomize rules:

- Four stratagems with **at most one** backpack, **one** vehicle (exosuit, FRV or tank) and **one** support weapon.
- The booster is never "none" and never one a squadmate already brought.
- Helmet, armor, cape, primary, secondary and grenade change too.

Everything goes through the game's own lists and equip routines, so locked items, mission restrictions and squad rules are respected. Load does not apply the randomize-only rules above; it keeps the game's own one-per-kind vehicle rule.

## Controls

The three buttons sit on the right edge of your player card and appear with the card on the **loadout tab** (not while choosing the drop site).

- **Mouse:** click a button.
- **Keyboard / controller:** move up to the **R Equipment** bar, press **Up** again to reach Randomize, **Up/Down** to move between buttons, **Select** to run one. **Down** from Randomize, **Left/Right** or **Back** return to the bar.

## Install

1. Close the game.
2. In **HD2MM** or **Arsenal**, disable any older RLMmods package.
3. Import `RLMmods-1.0.0.zip` from [Releases](https://github.com/modocracy/RLMods/releases), enable it and **Deploy**.

Remove: close the game, disable RLMmods in the same manager, then Purge/Deploy.

## Compatibility

- **Game build 25480438 only.** On any other build RLMmods enables nothing and the game runs normally. After a game update, **disable RLMmods until a new release is out**.
- RLMmods replaces the game's `boot.lua`, so it **cannot be used with other mods that replace `boot.lua`**. Bingus Shared Loader can stay enabled.
- Multiplayer and play after deployment have been tried less than the loadout screen itself. Please report problems with your log.

## Files on your PC

| Path | Purpose |
| --- | --- |
| `%LOCALAPPDATA%\RLMmods\loadout-1.txt` | Your saved loadout (one slot, local only). |
| `%LOCALAPPDATA%\RLMmods\RLMmods.log` | What each action did. Rotated to `RLMmods.old.log` past 1 MiB. |

Nothing is sent anywhere, nothing bypasses anti-cheat and nothing unlocks content. Use at your own risk.

## Credits

- **HD2Runtime by SkyeShade** — https://github.com/SkyeShade/HD2Runtime: stratagem families and backpack weapons, ownership rule, menu input layout.
- **[Alomare/FlexibleLoadouts](https://github.com/Alomare/FlexibleLoadouts)** (GPL-3.0-or-later): loadout screen instruction signatures.
- **[SHODAN-HORAI/SHODAN-Stat-Editor](https://github.com/SHODAN-HORAI/SHODAN-Stat-Editor)** (GPL-3.0): engine GUI and font usage.
- **[tyrypyrking/HD2-Transmog](https://github.com/tyrypyrking/HD2-Transmog)**: progression table layout facts.
- Everything else comes from this project's own analysis, recorded in [docs](docs/).

## License and source

GPL-3.0-or-later ([LICENSE](LICENSE)). The release package contains no game bytecode or game machine code; code checks use fingerprints. Build instructions: [docs/PACKAGING.md](docs/PACKAGING.md). Changes: [CHANGELOG.md](CHANGELOG.md).

Helldivers 2 is a trademark of Sony Interactive Entertainment / Arrowhead Game Studios. RLMmods is an unofficial fan project, not affiliated with or endorsed by them.
