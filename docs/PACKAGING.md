# Building RLMmods (1.0.0)

Current artifact: `dist/RLMmods-1.0.0.zip` (distributable, no game bytecode).
Disable all previous RLMmods packages before replacing. Feature changes are recorded in
the UPDATE documents (latest: [0.5](UPDATE-0.5.0.md)).

The build owns **only `boot.lua`**. Bingus Shared Loader owns
`core/wwise/lua/wwise_flow_callbacks`; that resource is absent from the patch.
Bingus is optional, not installed, bundled, copied or required by RLMmods.
See [한국어 공존 안내](history/COEXISTENCE.md).

Implemented: save/load/randomize of stratagems, booster and the six equipment slots,
mouse and keyboard/controller buttons, mod-manager icon. The builder compiles and
packages only; it does not run the game, a mod manager or tests.

## Button images and mod icon

`src/ui_images.lua` and `docs/design/rlmmods-mod-icon-256.png` are generated from the
finished design PNGs. After changing those PNGs run:

```powershell
python tools/make_ui_images.py
```

## Code pins

Native code checks are `pin:<length>:<wildcards>:<FNV-1a 64>` strings, not byte patterns.
After adding a pattern as hex while researching, convert it and confirm none remain:

```powershell
python tools/hash_pins.py
python tools/hash_pins.py --check
```

## Local build

Inputs are Python 3.10+, the owned vanilla **boot.lua.main** including its
8-byte envelope, and either an explicit non-GC64 LuaJIT compiler (`--luajit`)
or the fingerprint-pinned owned `bin/lua51.dll` (`--compiler-dll`).
Unpacked data is supported directly; slim DSAR/NXA data requires the reviewed
Filediver v0.7.61 Windows CLI through `--filediver`. It is a build-time tool only.
All original game files are read-only. The builder neither deploys nor installs.

The command used on this installation:

Distributable build (no game bytecode; `STANDALONE_BOOT` replaces the original boot):

```powershell
python -B tools/build_patch.py build `
  --compiler-dll 'C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2in\lua51.dll' `
  --output dist/RLMmods-1.0.0.zip
```

Source package for a release (GPL source; no game files or build outputs):

```powershell
python -B tools/build_patch.py source --output dist/RLMmods-1.0.0-source.zip
```

Private build that embeds the exact original boot (kept for comparison):

```powershell
python -B tools/build_patch.py build `
  --game-data 'C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2\data' `
  --filediver '.work\filediver\filediver-cli\filediver.exe' `
  --compiler-dll 'C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2\bin\lua51.dll' `
  --expect-original-sha256 85d7c6a9981e3288286c63bdb75e4256dcf859d6fc5f712cb72e9b329b1712e6 `
  --output dist/RLMmods-private-local.zip
```

Existing outputs are never overwritten. Rebuilding requires a new output name.
For an already extracted input use `--original-resource <path>/boot.lua.main`
instead of `--game-data` and omit `--filediver`. For an unpacked installation
use `--game-data` without `--filediver`.

The boot SHA-256 above is mandatory in the builder even when the optional pin
argument is omitted. A Wwise resource or a modded boot cannot be silently wrapped
and labelled vanilla. The extraction backend checks both resource name and Lua
type hashes, reads vanilla base bundles (not deployed patches), and refuses
ambiguous base copies. Different game builds require source review, not disabling
this pin. Compilation temporary files are kept under the locally excluded
`.work/`, removed on normal completion/errors, and never included in exports.

The DLL compiler backend runs in a separate Python process. It opens only the
string library, compiles text with `luaL_loadbufferx`, and passes the compiled
function as data to native `string.dump(function, true)`. It never calls the input
function. No game/engine DLL or EXE is loaded, and no original or mod Lua chunk is
executed. Both compiler routes must emit stripped non-GC64 `1b 4c 4a 02 02`
bytecode. Only ZIP metadata is deterministic with the DLL compiler route.

## Startup contract

The source order remains bootstrap, platform, signatures, randomizer, ownership,
stratagems, ui, main. Repeated `--source` arguments replace the complete default
list and must provide all required modules in dependency order.

1. Load the exact original boot bytecode in the resource's environment.
2. Run the original boot chunk once, preserving arguments and its complete result tuple.
3. Wrap the `init` function defined by original boot. Do not initialize RLMmods yet.
4. When the engine invokes `init`, call original init first, with all arguments.
   The inspected original init requires the Wwise callback resource. With Bingus
   installed that starts the loader and its addons; without it the vanilla
   callback resource runs. RLMmods does not require or detect a Bingus module.
5. After original init returns, initialize RLMmods once under `pcall`, then return
   all original init results including nils. Original errors propagate without retry.
6. RLMmods captures and forwards the update/shutdown functions that exist after
   original init. This retains callback wrappers installed by Bingus addons.
   No init/update/render/shutdown function is replaced with a blank callback.

The wrapper's global error marker is `RLMmods_bootstrap_error`. Original boot
errors are not swallowed; only new initialization errors are isolated. The main
runtime's existing global guard also prevents a second RLMmods initialization.
This is a source/bytecode-based contract; it has not been exercised in game.

## Contents and compatibility boundaries

The private ZIP contains `manifest.json` (HD2MM V1, stable RLMmods GUID),
`RLMmods-build.json`, installation text, licenses, and:

```text
data/9ba626afa44a3aa3.patch_0
data/9ba626afa44a3aa3.patch_0.stream
data/9ba626afa44a3aa3.patch_0.gpu_resources
```

The main archive has exactly one resource: `boot`, name hash
`0xF476DF93691895FA`, Lua type `0xA14E8DFA2CD117E2`. Stream/GPU companions are
empty. It contains **no** Wwise resource (`0x7251FDD9BB62480A`) and no Bingus addon
entry or loader implementation. Same archive basename is not a resource collision;
a manager must deploy different patches under separate patch indices as usual.
Do not copy two .patch_0 files onto each other manually.

This removes the resource collision with reviewed Bingus Loader v20 revision
`9471bcb16f3a479efdff3e0520def4573ae0a028`, without requiring it. Runtime coexistence
is unverified. Other packages that replace **boot.lua** still conflict, including
HUD+ variants that own boot. A later addon which overwrites callbacks without
forwarding them can still break a callback chain. This is not blanket compatibility
with every mod or future loader release. Generated patches contain owned original
boot bytecode: **keep them private**.

## Installation / removal

Close the game. Disable/remove RLMmods 0.1.1 in the manager and purge/redeploy so
its old Wwise replacement is removed. Import only the new 0.1.2 RLMmods ZIP and
deploy through the same manager. Keep Bingus enabled if other mods need it.
Do not use another boot.lua replacement. No deployment step was run here.

To uninstall, close the game, disable RLMmods 0.1.2 and purge/redeploy using the
same manager. Bingus can remain. After a game update, disable the patch and review
the new original files before rebuilding. Logs remain in
`%LOCALAPPDATA%\RLMmods\RLMmods.log` if initialization reaches logging.

## Source export (not installable)

```powershell
python -B tools/build_patch.py source --output dist/RLMmods-0.1.2-source.zip
```

The source-only allowlist excludes `.work`, dist, local game inputs, binaries,
bytecode and patches. Its manifest says `installable:false`,
`contains_game_resources:false`, `runtime_verified:false`, `tests_run:false`.
Source and private patch ZIPs are separate artifacts.

## Format references and attribution

The Python archive/hash implementation is adapted from the small 0BSD archive
writer below. The wrapper follows its original-bytecode preservation pattern,
without copying or depending on the Bingus runtime. Filediver's source informs
the bounds-aware reader and archive layout. Both notices are retained in
`tools/LICENSES` and copied into local patch ZIPs.

- Bingus Shared Loader, pinned revision
  `9471bcb16f3a479efdff3e0520def4573ae0a028`, 0BSD:
  [archive encoding](https://github.com/CowboyBingus/BingusSharedLoader/blob/9471bcb16f3a479efdff3e0520def4573ae0a028/scripts/archive.py),
  [wrapper and compiler invocation](https://github.com/CowboyBingus/BingusSharedLoader/blob/9471bcb16f3a479efdff3e0520def4573ae0a028/scripts/build.py),
  [package layout](https://github.com/CowboyBingus/BingusSharedLoader/blob/9471bcb16f3a479efdff3e0520def4573ae0a028/scripts/package.py),
  [license](https://github.com/CowboyBingus/BingusSharedLoader/blob/9471bcb16f3a479efdff3e0520def4573ae0a028/LICENSE).
- Filediver, pinned revision `6bf7c1ccc4be465a35b4bc9d41087781b47034e6`, BSD-3-Clause:
  [archive structs](https://github.com/xypwn/filediver/blob/6bf7c1ccc4be465a35b4bc9d41087781b47034e6/stingray/archive.go),
  [hash algorithm](https://github.com/xypwn/filediver/blob/6bf7c1ccc4be465a35b4bc9d41087781b47034e6/stingray/hash.go),
  [base archive reader](https://github.com/xypwn/filediver/blob/6bf7c1ccc4be465a35b4bc9d41087781b47034e6/stingray/fat_edition.go),
  [slim format](https://github.com/xypwn/filediver/blob/6bf7c1ccc4be465a35b4bc9d41087781b47034e6/stingray/slim_edition.go),
  [license](https://github.com/xypwn/filediver/blob/6bf7c1ccc4be465a35b4bc9d41087781b47034e6/LICENSE).
- [LuaJIT command-line documentation](https://luajit.org/running.html).
- Filediver v0.7.61 integration: reviewed source revision
  `d4f598567089722b939db4ea087793e79065f7fb`,
  [slim reader](https://github.com/xypwn/filediver/blob/d4f598567089722b939db4ea087793e79065f7fb/stingray/slim_edition.go),
  [CLI](https://github.com/xypwn/filediver/blob/d4f598567089722b939db4ea087793e79065f7fb/cmd/filediver-cli/main.go),
  [official release](https://github.com/xypwn/filediver/releases/tag/v0.7.61).
- [Lua 5.1 C API](https://www.lua.org/manual/5.1/manual.html#luaL_loadbuffer)
  and [LuaJIT serializer source](https://github.com/LuaJIT/LuaJIT/blob/v2.1/src/lib_string.c).
- [HD2MM V1 manifest documentation](https://teutinsa.github.io/hd2mm-site/docs/manifest/v1.html).
- [Filediver-backed resource extractor CLI source](https://github.com/CowboyBingus/BetterStratagemBounce/blob/main/cmd/hd2-resource-extract/main.go)
  (CLI reference only; its implementation is not copied or bundled).

Resource identities are `MurmurHash64A(path, seed=0)` and
`MurmurHash64A("lua", seed=0)`. The Lua type is `0xA14E8DFA2CD117E2`; the
resource envelope is little-endian `<uint32 bytecode_size, uint32 2>`.
