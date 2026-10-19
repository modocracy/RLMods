#!/usr/bin/env python3
"""Extract only the vanilla startup callback from a slim install with Filediver.

Filediver v0.7.61 source (BSD-3-Clause), not bundled:
https://github.com/xypwn/filediver/blob/d4f598567089722b939db4ea087793e79065f7fb/stingray/slim_edition.go
That reader indexes DSAA base archives and extensionless single-archive bundles;
it does not resolve deployed .patch_* overrides. Multiple base copies are
refused because the CLI archive filter does not select a particular copy.
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import tempfile

from archive_codec import STARTUP_NAME, STARTUP_PATH, LUA_TYPE, OriginalResource, PackagingError, original_bytecode


def extract_callback(game_data: Path, executable: Path) -> OriginalResource:
    game_data = game_data.resolve(strict=True)
    executable = executable.resolve(strict=True)
    if game_data.name.lower() != "data" or not (game_data / "bundles.nxa").is_file():
        raise PackagingError("Filediver backend requires the slim install's data/bundles.nxa.")
    # Pin the reviewed reader. Changed precedence semantics require source review.
    from archive_codec import sha256
    if sha256(executable.read_bytes()) != FILEDIVER_SHA256:
        raise PackagingError("Filediver executable is not the reviewed v0.7.61 Windows CLI.")
    common = [str(executable), "--gamedir", str(game_data.parent), "--include",
              STARTUP_PATH + ".lua", "--types", "lua"]

    def run(arguments, work):
        try:
            result = subprocess.run(common + arguments, cwd=work, stdin=subprocess.DEVNULL,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                    timeout=180, check=False, shell=False)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise PackagingError(f"Filediver extraction failed: {exc}") from exc
        if result.returncode:
            raise PackagingError("Filediver extraction failed: " +
                                 (result.stdout + result.stderr).decode("utf-8", errors="replace")[-3000:])
        return result.stdout.decode("utf-8", errors="strict")

    scratch = Path(__file__).resolve().parents[1] / ".work"
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="extract-", dir=scratch) as folder:
        work = Path(folder)
        listing = run(["--list"], work)
        pattern = (re.escape(STARTUP_PATH + ".lua") +
                   rf", 0x{STARTUP_NAME:016x}\.0x{LUA_TYPE:016x} <- ([0-9a-f, ]+)")
        lines = [line.strip() for line in listing.splitlines() if line.strip()]
        if len(lines) != 1 or not (match := re.fullmatch(pattern, lines[0])):
            raise PackagingError("Ambiguous Filediver callback identity/provenance listing.")
        origins = tuple(sorted(set(re.split(r"[, ]+", match[1]))))
        if not origins or any(not re.fullmatch(r"[0-9a-f]{16}", name) for name in origins):
            raise PackagingError("Callback origins are not vanilla base archive names.")
        if len(origins) != 1:
            raise PackagingError("Multiple base callback copies; Filediver CLI cannot disambiguate them.")
        original = None
        for index, origin in enumerate(origins):
            out = work / str(index)
            run(["--archives", "0x" + origin, "--raw-format", "separate", "--out", str(out)], work)
            path = out / (STARTUP_PATH + ".lua.main")
            if not path.is_file() or path.stat().st_size > 64 * 1024 * 1024:
                raise PackagingError("Filediver did not emit a bounded original .lua.main resource.")
            data = path.read_bytes()
            original_bytecode(data)
            if original is not None and original != data:
                raise PackagingError("Vanilla archives contain differing callbacks; refusing to choose.")
            original = data
        return OriginalResource(original, origins, "filediver-0.7.61-slim-base-archives")


# Filled from the official Windows v0.7.61 release asset during source preparation.
FILEDIVER_SHA256 = "c661b5d7cc5325eecd4103b3d053e729f92bafdc09f409ab6b0ced33fddd31b4"
