# Inputs needed to finish the requested mod

**0.1.2 startup update:** the current builder uses the exact original
`boot.lua.main`, not the Wwise callback input used by 0.1.1. Original boot/init
and the Wwise require are preserved to coexist with Bingus without depending
on it. See [COEXISTENCE.md](COEXISTENCE.md). Native equipment blockers below remain.

**2026-10-19 update:** the installed files and original callback have now been
located and inspected. The blocker is no longer a missing installation path:
both PE images are packed, and the existing candidate native-code RVAs have no
raw file bytes. See [the current work record](IMPLEMENTATION-2026-10-19.md).

The delivered source is a partial implementation. It does not provide a real stock
Hellpod button or full-loadout selection. The missing native mappings cannot be
filled responsibly with made-up Lua callbacks.

## Minimum files for continued static implementation

From one clean, legitimately owned installation of the exact same game build:

1. `<Helldivers 2>/data/game/game.dll`
   - This is the game DLL, **not** `bin/game.dll`.
   - Needed to establish equipment list/category dispatch, actual selection and
     persistence calls, booster squad-conflict rules, native card refresh, and
     the Hellpod screen's button/focus/callback registration.
2. `<Helldivers 2>/bin/helldivers2.exe`
   - Needed for matching engine APIs, build identity and native GUI registration.
   - A game version string alone does not establish the ABI.
3. The exact game/Steam build number and whether those two files are unmodified.
   - The current prototype targets the published Steam build `25480438`,
     executable version `1.8.46015.0`, and a DLL PE timestamp `0x6AB3B43F`.
   - Different builds require new source research and new pinned signatures;
     disabling the existing checks is not a supported solution.

The paths are corroborated by the mod author's own build tooling, for example
[VanillaPlusMegapack ShallowWaterDiving build.py](https://github.com/CowboyBingus/VanillaPlusMegapack/blob/main/components/ShallowWaterDiving/scripts/build.py).
The native equipment facts already established are recorded in
[equipment-selection-evidence.md](../../research/equipment-selection-evidence.md).

These are local analysis inputs, not redistributable project dependencies. Keep
the files outside the source tree or in the ignored `local_inputs/` directory.
Do not publish them in a repository or source archive. No account credentials,
save files, personal profile data, full game directory or live memory dump is
needed as an initial input.

## Minimum inputs for a private standalone patch build

In addition to the source, provide:

- An unmodified original `boot` resource from the same game build. Filediver raw
  export is named `boot.lua.main`; the builder requires its pinned vanilla hash.
- Preserve its **eight-byte game-resource envelope** followed by the complete
  LuaJIT bytecode. A decompiled `.lua` text file, a modded replacement or a bare
  bytecode chunk is not interchangeable with this input.
- Alternatively, supply the local clean `data/` directory path to the builder;
  it can read supported base Stingray archives without modifying them. It
  supports slim/NXA when the reviewed Filediver v0.7.61 executable is supplied
  through `--filediver`. No deployed patch is used as an original callback.
- An explicitly selected, compatible LuaJIT compiler executable that emits
  Windows non-GC64 bytecode with `-bsdW`; required leading bytes are
  `1b 4c 4a 02 02`. No compiler is bundled or downloaded automatically.
- Alternatively, pass `--compiler-dll <game>/bin/lua51.dll`. The backend accepts
  only the fingerprint recorded in `tools/compile_lua_dll.py`, compiles text,
  and calls native `string.dump`; it never executes the input function.

See [PACKAGING.md](../PACKAGING.md) for the commands and format constraints. A local
patch build includes original game bytes and is private. The source-only ZIP
contains neither those bytes nor an installable patch.

## What still has to be implemented

- Resolve each equipment category's ownership/availability and real native
  selection transaction, including its save and visible-card refresh behavior.
- Resolve booster restrictions against the current squad and mission state.
- Create a stock Hellpod widget with the real focus/activation lifecycle, rather
  than calling the current screen-GUI overlay a native menu insertion.
- Bind an all-categories action only once every requested category is supported.
  The existing pure selection planner is reusable; it is not an equipment API.
- Build/rebuild the private patch using the documented local inputs.

Possessing these files enables additional static research; it does not guarantee
that every remaining mapping can be established without observations from the
game. Tests, game launch, installation and runtime verification are skipped.
Source compilation is explicitly authorized and is not a gameplay check.
