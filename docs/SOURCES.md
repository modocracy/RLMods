# Source provenance

## 0.1.5 stratagem ownership correction

Uses research from HD2Runtime by SkyeShade: https://github.com/SkyeShade/HD2Runtime

Revision `34fba0887b196130df4142933fbe1b6ff6be5020` supplies native stratagem
availability facts for the same installed game.dll hash: direct or linked-parent
state 2/4, parent back-link at record +0x10, row enabled/selectable bits, and
five native instruction pins. These facts inform an original bounded observer;
the runtime implementation is not bundled or required. The original license is
retained in `tools/LICENSES/HD2Runtime.txt` and the patch ZIP, with visible credit
in both READMEs and the installation text. See [exact sources](history/UPDATE-0.1.5.md).

## 0.1.2 independent boot startup

The new wrapper owns `boot.lua` only and initializes after original `init` returns.
This follows read-only analysis of the user's 334-byte original boot resource,
whose init requires Wwise, and the already pinned Bingus v20 source contract
below. It does not copy, bundle, install or require the Bingus runtime. The
original-bytecode preservation technique and its 0BSD attribution are retained.
See [the detailed evidence and limits](history/COEXISTENCE.md).

Researched on 2026-10-18. Public repositories are third-party modding research, not an official mod SDK or an anti-cheat safety guarantee.

## Native stratagem ABI and signature data

- [Alomare/FlexibleLoadouts](https://github.com/Alomare/FlexibleLoadouts)
- Pinned revision: `39871d310d3942f718648280fe5c60cc4d2beaac`
- [flexible_stratagems.lua](https://github.com/Alomare/FlexibleLoadouts/blob/39871d310d3942f718648280fe5c60cc4d2beaac/flexible_stratagems.lua)
- License: GPL-3.0-or-later, copyright 2026 Alomare

`src/signatures.lua` adapts only the instruction-signature entries used by this project's selector; since 0.6.1 their byte patterns are stored as fingerprints (`pin:` strings, see [UPDATE-0.6.0](UPDATE-0.6.0.md)), with the field offsets kept. `src/stratagems.lua` implements an original bounded random-selection workflow using the documented screen, offer-list, widget and commit ABI. The upstream's duplicate/vehicle restriction bypass, empty-ready behavior, code-search engine and menu dependencies are not included. No runtime modification behavior is taken from them.

## Engine GUI and font research

- [SHODAN-HORAI/SHODAN-Stat-Editor](https://github.com/SHODAN-HORAI/SHODAN-Stat-Editor)
- Pinned revision: `3e9402699d0b51259a86d3888564e1f3cea26813`
- [src/stat_editor.lua](https://github.com/SHODAN-HORAI/SHODAN-Stat-Editor/blob/3e9402699d0b51259a86d3888564e1f3cea26813/src/stat_editor.lua)
- License: GPL-3.0

This supplied factual references for the current UI font/material/atlas locations, availability checks, screen-GUI creation/destruction and basic draw calls. The present overlay, click workflow, memory layer and layout are newly authored. No stat editing, input interception, window filter, mouse clipping or executable-memory writes are included.

## Startup and packaging research

- [CowboyBingus/BingusSharedLoader](https://github.com/CowboyBingus/BingusSharedLoader)
- [Startup contract](https://github.com/CowboyBingus/BingusSharedLoader/blob/main/docs/TECHNICAL.md)
- License: 0BSD; retained notice under `tools/LICENSES/`
- [xypwn/filediver](https://github.com/xypwn/filediver)
- License: BSD-3-Clause; retained notice under `tools/LICENSES/`

The loader's documented resource is `core/wwise/lua/wwise_flow_callbacks`, name hash `0x7251FDD9BB62480A`, Lua type hash `0xA14E8DFA2CD117E2`. RLMmods 0.1.1 replaced it; 0.1.2 instead wraps original `boot` (`0xF476DF93691895FA`) and leaves Wwise to the game/loader. Original game bytes are excluded from source distributions. This project does not install, require, copy or bundle the Bingus runtime loader; the archive format and preservation technique retain their existing attribution.

## Examined but not copied

- [Hung1510/Super-Earth-Armory-Forge/tools/strat.lua](https://github.com/Hung1510/Super-Earth-Armory-Forge/blob/main/tools/strat.lua): corroborates native preset-selection workflow; no root source license found during inspection, so its implementation was not copied.
- [tyrypyrking/HD2-Transmog](https://github.com/tyrypyrking/HD2-Transmog): native clothing/ownership research; no root license found, so implementation copying was avoided.
- [SkyeShade/HD2Runtime](https://github.com/SkyeShade/HD2Runtime): useful semantic modding reference; requires Bingus at runtime, and gameplay tuning is not a substitute for a loadout-selection API. Not bundled or required.
- [DiverKit author page](https://www.nexusmods.com/helldivers2/mods/16493): demonstrates native pre-drop loadout randomization, but depends on Bingus. Its runtime and proprietary/package content are not bundled.

`src/ownership.lua` is an original read-only observer based on the factual
progression layout documented by HD2-Transmog. It gates that layout on the full
published native signature, reads a bounded
offer index and rechecks enabled ownership state for the exact item/offer.
No unlicensed implementation, native equip behavior or progression mutation is
copied. The detailed pinned references and unresolved category mappings are in
[equipment-selection-evidence.md](../research/equipment-selection-evidence.md).

In 0.1.4 the failed inferred fixed address was replaced with an original bounded
unique-pattern scanner. The only masked bytes are offsets 99..102, as specified
by the pinned Transmog `catalog_compat.lua` mask. The live RIP target must agree
with the independently matched FlexibleLoadouts offer-reader signatures, including
the count and row-table offsets. All 150 matched bytes (including the resolved
displacement) are retained and rechecked. Pattern ambiguity, unreadable scan
regions, disagreement, or changed code disables ownership observation.
This is relocation-aware code identification, not entitlement modification.

## 2026-10-19 continuation

The Filediver v0.7.61 Windows CLI was downloaded from its official GitHub
release and used for read-only extraction of the one original callback. New
integration code is original Python; it does not copy or bundle the executable.
The reviewed DSAR/NXA reader is revision
`d4f598567089722b939db4ea087793e79065f7fb` (BSD-3-Clause). The original format
code's earlier provenance and notices above are retained.

`tools/compile_lua_dll.py` is an original ctypes compiler driver using the
[Lua 5.1 C API](https://www.lua.org/manual/5.1/manual.html) and the
[LuaJIT native serializer contract](https://github.com/LuaJIT/LuaJIT/blob/v2.1/src/lib_string.c).
It uses the installed, hash-pinned `lua51.dll` as a compiler only. No LuaJIT
source or compiler DLL is redistributed. Neither game.dll nor the game EXE is
loaded or run. No Bingus Loader runtime code was added.

## Compilation and verification record

The original delivery ran no compilation or tests. In the 2026-10-19 continuation,
the user explicitly authorized binary analysis, compilation and packaging while
excluding game execution and tests. A private patch was compiled and packaged;
native ABI, gameplay, mod-manager import and original-callback runtime behavior
remain unverified. See [the work record](history/IMPLEMENTATION-2026-10-19.md).
