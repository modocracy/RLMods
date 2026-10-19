#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Replace literal game-code byte patterns in src/*.lua with fingerprints.

RLMmods checks the game's machine code before it calls or reads it. Instead of
keeping those bytes in the source, each pattern becomes a pin string

    'pin:<length>:<wildcard offsets>:<FNV-1a 64 hex>'

where wildcard offsets are the 0-based '??' positions written as ranges
("3-6,99-102", empty when none). platform.lua's P.match reads <length> bytes from
the game, skips the wildcard offsets and compares the FNV-1a 64 fingerprint.

Usage:
  python tools/hash_pins.py           convert every hex pattern in src/*.lua
  python tools/hash_pins.py --check   fail if any hex pattern remains
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# A quoted run of at least three space-separated hex or ?? bytes.
PATTERN = re.compile(r"'((?:(?:[0-9A-Fa-f]{2}|\?\?) ){2,}(?:[0-9A-Fa-f]{2}|\?\?))'")


def fnv1a64(data: bytes, skip: set[int]) -> str:
    value = 0xCBF29CE484222325
    for index, byte in enumerate(data):
        if index not in skip:
            value = ((value ^ byte) * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return f"{value:016x}"


def ranges(offsets: list[int]) -> str:
    out, start, last = [], None, None
    for offset in offsets:
        if start is None:
            start = last = offset
        elif offset == last + 1:
            last = offset
        else:
            out.append(f"{start}-{last}" if last != start else str(start))
            start = last = offset
    if start is not None:
        out.append(f"{start}-{last}" if last != start else str(start))
    return ",".join(out)


def pin(text: str) -> str:
    parts = text.split()
    skip = [i for i, part in enumerate(parts) if part == "??"]
    data = bytes(0 if part == "??" else int(part, 16) for part in parts)
    return f"pin:{len(parts)}:{ranges(skip)}:{fnv1a64(data, set(skip))}"


def main() -> int:
    check = "--check" in sys.argv[1:]
    remaining = 0
    for path in sorted((ROOT / "src").glob("*.lua")):
        source = path.read_text(encoding="utf-8")
        found = PATTERN.findall(source)
        if check:
            for text in found:
                remaining += 1
                print(f"{path.relative_to(ROOT)}: hex pattern of {len(text.split())} bytes remains")
            continue
        if not found:
            continue
        converted = PATTERN.sub(lambda m: "'" + pin(m.group(1)) + "'", source)
        path.write_text(converted, encoding="utf-8", newline="")
        print(f"{path.relative_to(ROOT)}: {len(found)} patterns converted")
    if check:
        print("No hex code patterns in src." if remaining == 0 else f"{remaining} hex patterns remain.")
        return 1 if remaining else 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
