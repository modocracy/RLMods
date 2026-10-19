#!/usr/bin/env python3
"""Build a source ZIP, or a private standalone HD2 patch from owned local inputs.

Python 3.10+ standard library only. The local patch build additionally requires
an explicitly selected LuaJIT compiler; it compiles but never executes game/mod
Lua. This tool does not install anything, contact the network, or start the game.
See docs/PACKAGING.md and tools/LICENSES for format sources and attribution.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zipfile

# Do not leave import-cache files in the delivered source tree.
sys.dont_write_bytecode = True

from archive_codec import (
    BYTECODE_HEADER,
    STARTUP_NAME,
    STARTUP_PATH,
    STARTUP_SHA256,
    WWISE_PATH,
    LUA_TYPE,
    MAX_RESOURCE_SIZE,
    PATCH_NAME,
    PackagingError,
    load_original_resource,
    make_lua_resource,
    make_patch,
    original_bytecode,
    sha256,
)


ROOT = Path(__file__).resolve().parents[1]
GUID = "9e753d42-a2f4-49ca-90c9-f47539fdf87e"
# Mod-manager icon (overlapping dice). Copied byte for byte; HD2MM reads the
# manifest's top-level IconPath as a file name inside the mod archive.
MOD_ICON = Path("docs/design/rlmmods-mod-icon-256.png")  # from rlmmods-mod-icon-512-v1.png by tools/make_ui_images.py
MOD_ICON_NAME = "icon.png"
DEFAULT_VERSION = "1.0.0"
DEFAULT_SOURCES = (
    "src/bootstrap.lua",
    "src/platform.lua",
    "src/signatures.lua",
    "src/randomizer.lua",
    "src/ownership.lua",
    "src/stratagem_rules.lua",
    "src/stratagems.lua",
    "src/ui_images.lua",
    "src/ui.lua",
    "src/navigation.lua",
    "src/boosters.lua",
    "src/equipment.lua",
    "src/main.lua",
)
MAX_SOURCE_SIZE = 8 * 1024 * 1024
FIXED_ZIP_TIME = (1980, 1, 1, 0, 0, 0)
SOURCE_DIRS = ("src", "tools", "docs", "research", "config", "examples")
SOURCE_EXTENSIONS = {".lua", ".py", ".md", ".txt", ".json", ".ini", ".toml", ".cfg"}
SOURCE_ROOT_FILES = (
    "README.md", "README.ko.md", "INSTALL.txt", "LICENSE", "LICENSE.txt",
    "CHANGELOG.md", "THIRD_PARTY.md", ".gitignore", "mod.json",
)


def json_bytes(value: object) -> bytes:
    return (json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n").encode("utf-8")


def within(path: Path, directory: Path) -> bool:
    try:
        path.resolve().relative_to(directory.resolve())
        return True
    except ValueError:
        return False


def check_output_path(output: Path, game_data: Path | None, original: Path | None) -> None:
    if output.suffix.lower() != ".zip":
        raise PackagingError("--output must name a .zip file.")
    if output.exists():
        raise PackagingError(f"Output already exists; choose a new filename: {output}")
    if game_data is not None and within(output, game_data.parent):
        raise PackagingError("Output must be outside the game installation; this is not an installer.")
    if original is not None and output.resolve() == original.resolve():
        raise PackagingError("Output must not replace the original resource.")


def write_zip(output: Path, files: dict[str, bytes]) -> None:
    """Deterministic metadata, exclusive creation, and no external executable calls."""
    output.parent.mkdir(parents=True, exist_ok=True)
    created = False
    try:
        with output.open("xb") as handle:
            created = True
            with zipfile.ZipFile(handle, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
                for name, contents in sorted(files.items()):
                    info = zipfile.ZipInfo(name, date_time=FIXED_ZIP_TIME)
                    info.create_system = 3
                    info.external_attr = 0o100644 << 16
                    info.compress_type = zipfile.ZIP_DEFLATED
                    archive.writestr(info, contents)
    except BaseException:
        if created:
            output.unlink(missing_ok=True)
        raise


def source_files() -> dict[str, bytes]:
    """An allowlisted source export never sweeps up dist or local game assets."""
    paths = []
    for name in SOURCE_ROOT_FILES:
        path = ROOT / name
        if path.is_file():
            paths.append(path)
    for name in SOURCE_DIRS:
        directory = ROOT / name
        if not directory.is_dir():
            continue
        for path in directory.rglob("*"):
            relative = path.relative_to(ROOT)
            if any(part.startswith(".") or part == "__pycache__" for part in relative.parts):
                continue
            if path.is_symlink():
                raise PackagingError(f"Source export refuses symlinks: {relative.as_posix()}")
            if path.is_file() and (
                path.suffix.lower() in SOURCE_EXTENSIONS or "LICENSES" in relative.parts
            ):
                paths.append(path)
    for relative in DEFAULT_SOURCES:
        if not (ROOT / relative).is_file():
            raise PackagingError(f"{relative} is missing; no source release was packaged.")
    files = {}
    for path in sorted(set(paths)):
        if path.is_symlink() or not within(path, ROOT):
            raise PackagingError(f"Source export refuses a path outside the project: {path.name}")
        if path.stat().st_size > MAX_SOURCE_SIZE:
            raise PackagingError(f"Unexpectedly large source file: {path.relative_to(ROOT).as_posix()}")
        data = path.read_bytes()
        # Exports are text-only. Compiled resources belong in private local build output.
        try:
            data.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise PackagingError(f"Source export refuses non-UTF-8 input: {path.name}") from exc
        if b"\x00" in data or data.startswith(b"\x1bLJ"):
            raise PackagingError(f"Source export refuses binary input: {path.name}")
        files["RLMmods/" + path.relative_to(ROOT).as_posix()] = data
    return files


def package_source(args: argparse.Namespace) -> None:
    output = args.output.resolve()
    check_output_path(output, None, None)
    files = source_files()
    manifest = {
        "name": "RLMmods",
        "version": args.version,
        "artifact_kind": "source-only",
        "installable": False,
        "contains_game_resources": False,
        "requires_bingus_loader": False,
        "runtime_verified": False,
        "tests_run": False,
        "game_executed": False,
        "feature_scope": "Save, load and randomize stratagems, booster and six equipment slots.",
        "status": "Source and local builder only; not a ready-to-install mod archive.",
        "files": {name: sha256(data) for name, data in sorted(files.items())},
    }
    files["RLMmods/SOURCE-MANIFEST.json"] = json_bytes(manifest)
    write_zip(output, files)
    print(f"Created source-only ZIP: {output}")
    print("Contains no .patch_0 files or game bytecode. No tests or game execution were performed.")


def read_sources(paths: list[Path] | None) -> tuple[str, dict[str, str]]:
    paths = paths or [ROOT / relative for relative in DEFAULT_SOURCES]
    chunks = []
    hashes = {}
    for index, path in enumerate(paths, 1):
        path = path.resolve()
        if not path.is_file():
            raise PackagingError(f"Lua source not found: {path}")
        if path.stat().st_size > MAX_SOURCE_SIZE:
            raise PackagingError(f"Lua source is too large: {path.name}")
        data = path.read_bytes()
        try:
            source = data.decode("utf-8-sig")
        except UnicodeDecodeError as exc:
            raise PackagingError(f"Lua source is not UTF-8: {path.name}") from exc
        if "\x00" in source or source.startswith("\x1bLJ"):
            raise PackagingError(f"--source must be Lua source text: {path.name}")
        # Numeric chunk labels avoid exposing local paths or injecting filename text into Lua.
        chunks.append(f"-- RLMmods source chunk {index}\n" + source + "\n")
        label = path.relative_to(ROOT).as_posix() if within(path, ROOT) else path.name
        hashes[f"{index}:{label}"] = sha256(data)
    return "\n".join(chunks), hashes


# The game's boot resource for the supported build (SHA-256 STARTUP_SHA256), written
# out as plain Lua from its bytecode structure: four global callbacks, Wwise startup in
# init, and two developer-build checks. No original bytes are copied. It defines, in
# order: init (requires the Wwise flow callbacks, returns nothing), shutdown, update(dt)
# and render (empty), then requires 'debug' when Application.build() is not 'release',
# then calls jit.off() when rawget(_G, jit) is truthy (the original passes the global
# value jit, not the string, so on the shipped game it stays a no-op).
STANDALONE_BOOT = """local function __rlm_original()
    local env = __rlm_env
    env.init = function() env.require("core/wwise/lua/wwise_flow_callbacks") end
    env.shutdown = function() end
    env.update = function(dt) end
    env.render = function() end
    if env.stingray.Application.build() ~= "release" then env.require("debug") end
    if env.rawget(env._G, env.jit) then env.jit.off() end
end
"""


def make_wrapper(stock: bytes | None, source: str) -> str:
    """Preserve boot, then wrap its init AFTER boot has defined the callbacks.

    stock is the original boot bytecode for a private build, or None for a
    distributable build that uses STANDALONE_BOOT instead.

    The inspected vanilla init requires Wwise. Calling it before RLM startup
    allows Bingus and its addons to finish hooking update/shutdown first.
    Original chunk/init errors propagate once, with no retry. Only our startup
    is protected. Tail-forward both argument/result tuples, including nils.
    """
    if stock is None:
        header = "-- RLMmods boot. Re-implements the game's boot callbacks; contains no game bytecode.\n"
        original = STANDALONE_BOOT
    else:
        literal = '"' + "".join(f"\\{byte:03d}" for byte in stock) + '"'
        header = "-- Private local build. Contains original game bytecode. Do not distribute.\n"
        original = (f'local __rlm_original = assert(loadstring({literal}, "@vanilla_boot"))\n'
                    "if setfenv then setfenv(__rlm_original, __rlm_env) end\n")
    return (
        header
        + "local __rlm_pcall, __rlm_rawset, __rlm_tostring, __rlm_type = pcall, rawset, tostring, type\n"
        "local __rlm_globals = _G\n"
        "local __rlm_env = getfenv and getfenv(1) or _G\n"
        "local function __rlm_initialize()\n"
        + source
        + "\nend\n"
        + "local function __rlm_report(reason)\n"
        + "    __rlm_pcall(function()\n"
        + '        __rlm_rawset(__rlm_globals, "RLMmods_bootstrap_error", __rlm_tostring(reason))\n'
        + "    end)\nend\n"
        + "local function __rlm_install()\n"
        + "    local original_init = __rlm_env.init\n"
        + "    assert(__rlm_type(original_init) == 'function', 'Original boot init unavailable')\n"
        + "    local attempted = false\n"
        + "    local function after_init(...)\n"
        + "        if not attempted then\n"
        + "            attempted = true\n"
        + "            local ok, reason = __rlm_pcall(__rlm_initialize)\n"
        + "            if not ok then __rlm_report(reason) end\n"
        + "        end\n"
        + "        return ...\n"
        + "    end\n"
        + "    __rlm_env.init = function(...)\n"
        + "        return after_init(original_init(...))\n"
        + "    end\n"
        + "end\n"
        + original
        + "return (function(...)\n"
        + "    local ok, reason = __rlm_pcall(__rlm_install)\n"
        + "    if not ok then __rlm_report(reason) end\n"
        + "    return ...\n"
        + "end)(__rlm_original(...))\n"
    )


def compile_wrapper(wrapper: str, compiler: Path, work: Path, library_backend: bool = False) -> bytes:
    compiler = compiler.resolve()
    if not compiler.is_file():
        raise PackagingError(f"Explicit LuaJIT compiler executable not found: {compiler}")
    source = work / "callbacks.wrapper.lua"
    compiled = work / "callbacks.ljbc"
    source.write_text(wrapper, encoding="utf-8", newline="\n")
    env = dict(os.environ)
    # A caller's unrelated init script must not run as a side effect of compilation.
    env.pop("LUA_INIT", None)
    env.pop("LUA_INIT_5_1", None)
    if not library_backend and (compiler.parent / "jit/bcsave.lua").is_file():
        env["LUA_PATH"] = str(compiler.parent / "?.lua") + ";;"
    command = ([sys.executable, "-B", str(ROOT / "tools/compile_lua_dll.py"),
                "--library", str(compiler), "--source", str(source), "--output", str(compiled)]
               if library_backend else [str(compiler), "-bsdW", str(source), str(compiled)])
    try:
        result = subprocess.run(
            command,
            cwd=work,
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
            check=False,
            shell=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise PackagingError("LuaJIT compilation exceeded 120 seconds. No patch was created.") from exc
    except OSError as exc:
        raise PackagingError(f"Could not run the selected LuaJIT compiler: {exc}") from exc
    if result.returncode:
        detail = (result.stdout + result.stderr).decode("utf-8", errors="replace").strip()
        raise PackagingError(f"LuaJIT compilation failed (exit {result.returncode}):\n{detail}")
    if not compiled.is_file() or compiled.stat().st_size > MAX_RESOURCE_SIZE:
        raise PackagingError("LuaJIT did not produce a supported bytecode output file.")
    bytecode = compiled.read_bytes()
    if not bytecode.startswith(BYTECODE_HEADER):
        raise PackagingError(
            "Compiler output must start 1b 4c 4a 02 02. Use compatible LuaJIT "
            "non-GC64 output with -bsdW; PUC Lua and GC64 bytecode cannot be packaged."
        )
    return bytecode


PRIVATE_NOTE = """It contains original game bytecode extracted from your owned
installation. Keep this ZIP private. Original game bytecode must not be published.
"""
LOCAL_INSTALL_README = """RLMmods - Hellpod loadout buttons for Helldivers 2

{private_note}Adds Save, Load and Randomize buttons to your player card on the Hellpod
loadout screen.

  Save      - stores your current stratagems, booster, helmet, armor, cape,
              primary, secondary and grenade (one slot, on this PC only:
              %LOCALAPPDATA%\\RLMmods\\loadout-1.txt)
  Load      - restores the saved loadout; slots that are not selectable right
              now are skipped
  Randomize - picks among what the game lists as selectable. Stratagems hold at
              most one backpack, one vehicle and one support weapon; the booster
              is never "none".

Mouse, or keyboard/controller: from the "R Equipment" bar press Up to reach the
buttons, Up/Down to move, Select to run, Down/Left/Right/Back to return.

INSTALL: close the game, disable older RLMmods packages, import this ZIP into
HD2MM or Arsenal, enable it and Deploy. REMOVE: disable it and Purge/Deploy.
Conflicts with other mods that replace boot.lua. Bingus Shared Loader may stay on.

GAME UPDATES: built for game build 25480438 only. On another build it does
nothing. Disable it after a game update until a new RLMmods release is out.

Log: %LOCALAPPDATA%\\RLMmods\\RLMmods.log. Nothing bypasses anti-cheat or
unlocks content. Use at your own risk.

Uses research from HD2Runtime by SkyeShade - https://github.com/SkyeShade/HD2Runtime
(see LICENSES/HD2Runtime.txt; HD2Runtime is not bundled or required).
Also based on research from Alomare/FlexibleLoadouts (GPL-3.0-or-later),
SHODAN-HORAI/SHODAN-Stat-Editor (GPL-3.0) and tyrypyrking/HD2-Transmog.
License: GPL-3.0-or-later (RLMmods-source-license.txt). Source code is published
with each release.
"""


def package_patch(args: argparse.Namespace) -> None:
    output = args.output.resolve()
    game_data = args.game_data.resolve() if args.game_data else None
    original_file = args.original_resource.resolve() if args.original_resource else None
    check_output_path(output, game_data, original_file)
    if args.compiler_dll:
        library = args.compiler_dll.resolve()
        if library.parent.name.lower() == "bin" and within(output, library.parent.parent):
            raise PackagingError("Output must be outside the compiler's game installation.")
    # Without an original input the build is distributable: STANDALONE_BOOT replaces
    # the game's boot bytecode. With one, the private build embeds that exact original.
    private = bool(game_data or original_file)
    original, actual_sha, stock = None, None, None
    if args.filediver and not game_data:
        raise PackagingError("--filediver requires --game-data, not --original-resource.")
    if private:
        if args.filediver:
            from extract_callback import extract_callback
            original = extract_callback(game_data, args.filediver)
        else:
            original = load_original_resource(game_data, original_file)
        actual_sha = sha256(original.data)
        if actual_sha != STARTUP_SHA256:
            raise PackagingError("Original must be the supported vanilla boot.lua.main, not a Wwise or modded resource.")
        if args.expect_original_sha256 and args.expect_original_sha256.lower() != actual_sha:
            raise PackagingError(
                f"Original resource SHA-256 differs from the requested pin. Actual: {actual_sha}"
            )
        stock = original_bytecode(original.data)
    source, source_hashes = read_sources(args.source)
    wrapper = make_wrapper(stock, source)
    # Only the user's explicit compiler is executed, only in bytecode compilation mode.
    # Temporary files include private game bytes and are removed when compilation ends.
    scratch = ROOT / ".work"
    scratch.mkdir(exist_ok=True)
    compiler = args.compiler_dll or args.luajit
    with tempfile.TemporaryDirectory(prefix="build-", dir=scratch) as temp:
        bytecode = compile_wrapper(wrapper, compiler, Path(temp), bool(args.compiler_dll))
    resource = make_lua_resource(bytecode)
    files = {
        "data/" + PATCH_NAME: make_patch(resource),
        "data/" + PATCH_NAME + ".stream": b"",
        "data/" + PATCH_NAME + ".gpu_resources": b"",
        "RLMmods-README.txt": LOCAL_INSTALL_README.replace(
            "{private_note}", PRIVATE_NOTE if private else "").encode("utf-8"),
        "RLMmods-source-license.txt": (ROOT / "LICENSE").read_bytes(),
    }
    for path in sorted((ROOT / "tools/LICENSES").glob("*")):
        if path.is_file():
            files["LICENSES/" + path.name] = path.read_bytes()
    description = (
        "Hellpod loadout buttons: save, load and randomize stratagems, booster, helmet, armor, cape and weapons. "
        "Independent boot startup, no shared loader dependency; conflicts with other boot replacements."
        + (" Private local build containing owned game bytecode." if private else "")
    )
    icon = ROOT / MOD_ICON
    icon_bytes = icon.read_bytes()
    if not icon_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
        raise PackagingError(f"{MOD_ICON.as_posix()} is not a PNG file.")
    files[MOD_ICON_NAME] = icon_bytes
    display_name = "RLMmods " + args.version
    files["manifest.json"] = json_bytes({
        "Version": 1,
        "Guid": GUID,
        "Name": display_name,
        "Description": description,
        "IconPath": MOD_ICON_NAME,
        "Options": [{"Name": display_name, "Description": description, "Include": ["data"]}],
    })
    report = {
        "name": "RLMmods",
        "version": args.version,
        "artifact_kind": "private-local-patch" if private else "distributable-patch",
        "format": "Stingray F0000011 Lua-only patch with HD2MM V1 manifest",
        "contains_game_resources": private,
        "redistribution": ("Do not distribute. Share the source-only package instead." if private
                           else "GPL-3.0-or-later; contains no game bytecode (boot callbacks re-implemented)."),
        "requires_bingus_loader": False,
        "startup": {
            "resource": STARTUP_PATH + ".lua",
            "initialization": "after-original-init",
            "boot": "embedded-original" if private else "re-implemented (STANDALONE_BOOT, modelled on boot SHA-256 "
                    + STARTUP_SHA256 + ")",
            "existing_update_shutdown": "chain-existing-functions",
            "bingus_resource": WWISE_PATH + ".lua",
            "bingus_resource_included": False,
            "bingus_runtime_dependency": False,
            "coexistence_runtime_verified": False,
            "reviewed_bingus_revision": "9471bcb16f3a479efdff3e0520def4573ae0a028",
            "remove_legacy_rlmmods_wwise_patch": True,
        },
        "runtime_verified": False,
        "mod_manager_verified": False,
        "tests_run": False,
        "game_executed": False,
        "compilation_only": True,
        "feature_scope": "Save, load and randomize stratagems, booster and six equipment slots.",
        "game_build_compatibility": "game.dll timestamp 0x6AB3B43F (Steam build 25480438) only; off on other builds.",
        "original_resource": None if not private else {
            "path": STARTUP_PATH,
            "name_hash": f"0x{STARTUP_NAME:016X}",
            "type": "lua",
            "type_hash": f"0x{LUA_TYPE:016X}",
            "sha256": actual_sha,
            "method": original.method,
            "origins": list(original.origins),
            "bytecode_header": stock[:5].hex(" "),
        },
        "compiled_resource_sha256": sha256(resource),
        "source_sha256": source_hashes,
        "compiler": {"filename": compiler.name, "sha256": sha256(compiler.read_bytes()),
                     "backend": "owned-lua51-library" if args.compiler_dll else "luajit-cli",
                     "operation": "loadbuffer-text/string.dump-strip" if args.compiler_dll else "-bsdW",
                     "input_chunk_executed": False,
                     "deterministic_mode": not bool(args.compiler_dll)},
        "conflicting_resource": STARTUP_PATH + ".lua",
        "files": {name: sha256(data) for name, data in sorted(files.items())},
    }
    files["RLMmods-build.json"] = json_bytes(report)
    write_zip(output, files)
    if private:
        print(f"Created private, untested patch ZIP: {output}")
        print(f"Original boot SHA-256: {actual_sha}")
        print("Keep this ZIP private. No installation, tests, mod-manager checks, or game execution were performed.")
    else:
        print(f"Created distributable patch ZIP (no game bytecode): {output}")
        print("No installation, tests, mod-manager checks, or game execution were performed.")
    print("Replaces only boot.lua; Bingus Wwise resource is not included. Live coexistence remains untested.")
    print("Remove the legacy RLMmods Wwise patch. Other boot.lua replacements still conflict.")


def version_argument(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}", value):
        raise argparse.ArgumentTypeError("Version must use 1-64 letters, digits, dots, underscores or hyphens.")
    return value


def sha_argument(value: str) -> str:
    if not re.fullmatch(r"[0-9a-fA-F]{64}", value):
        raise argparse.ArgumentTypeError("Expected exactly 64 hexadecimal SHA-256 digits.")
    return value.lower()


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    commands = result.add_subparsers(dest="command", required=True)
    source = commands.add_parser("source", help="Package only source/docs; never an installable mod.")
    source.add_argument("--output", type=Path, default=ROOT / "dist/RLMmods-source.zip")
    source.add_argument("--version", type=version_argument, default=DEFAULT_VERSION)
    source.set_defaults(action=package_source)
    build = commands.add_parser("build", help="Build a private standalone patch from owned local game input.")
    original = build.add_mutually_exclusive_group(required=False)
    original.add_argument("--game-data", type=Path, help="Read-only unpacked game data directory; excludes .patch_* files.")
    original.add_argument("--original-resource", type=Path, help="Original boot.lua.main, including its 8-byte envelope; exact supported hash required.")
    compiler = build.add_mutually_exclusive_group(required=True)
    compiler.add_argument("--luajit", type=Path, help="Explicit compatible LuaJIT compiler executable path.")
    compiler.add_argument("--compiler-dll", type=Path, help="Owned, fingerprint-pinned bin/lua51.dll; compilation only, no input chunk execution.")
    build.add_argument("--filediver", type=Path, help="Reviewed Filediver v0.7.61 CLI for a slim --game-data directory.")
    build.add_argument("--source", type=Path, action="append", help="Replace the default module list; repeat for ordered concatenation. See PACKAGING.md for the default order.")
    build.add_argument("--expect-original-sha256", type=sha_argument, help="Optional exact original-resource SHA-256 pin.")
    build.add_argument("--output", type=Path, default=ROOT / "dist/RLMmods-private-local.zip")
    build.add_argument("--version", type=version_argument, default=DEFAULT_VERSION)
    build.set_defaults(action=package_patch)
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        args.action(args)
    except (PackagingError, OSError, zipfile.BadZipFile) as exc:
        print(f"Build stopped: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
