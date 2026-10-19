#!/usr/bin/env python3
"""Read PE files and locate existing source signatures without loading game code.

Produces metadata, hashes and match counts only. Never dumps original bytes or
equates a packed on-disk image with its runtime memory layout.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]


def inspect(path: Path, signatures=()):
    if path.stat().st_size > 256 * 1024 * 1024:
        raise ValueError("PE exceeds analysis size limit")
    data = path.read_bytes()
    if data[:2] != b"MZ":
        raise ValueError("Not a PE image")
    pe, = struct.unpack_from("<I", data, 60)
    if data[pe:pe + 4] != b"PE\0\0":
        raise ValueError("Missing PE signature")
    machine, count, timestamp, _, _, optional_size, _ = struct.unpack_from("<HHIIIHH", data, pe + 4)
    if machine != 0x8664 or not 0 < count < 128:
        raise ValueError("Unsupported PE architecture/section count")
    sections = []
    for i in range(count):
        name, virtual_size, rva, raw_size, offset, _, _, _, _, flags = struct.unpack_from(
            "<8sIIIIIIHHI", data, pe + 24 + optional_size + i * 40)
        if raw_size and offset + raw_size > len(data):
            raise ValueError("PE raw section extends outside file")
        sections.append(dict(name=name.rstrip(b"\0").decode("ascii", errors="replace"),
                             rva=rva, virtual_size=virtual_size, raw_size=raw_size,
                             file_offset=offset, executable=bool(flags & 0x20000000)))
    findings = []
    for name, rva, pattern in signatures:
        parts = pattern.split()
        section = next((s for s in sections if s["rva"] <= rva and
                        rva + len(parts) <= s["rva"] + s["virtual_size"]), None)
        backed = section is not None and rva + len(parts) <= section["rva"] + section["raw_size"]
        regex = b"".join(b"." if part == "??" else re.escape(bytes([int(part, 16)])) for part in parts)
        matches = [match.start() for match in re.finditer(regex, data, re.DOTALL)]
        expected_match = None
        if backed:
            offset = section["file_offset"] + rva - section["rva"]
            expected_match = re.fullmatch(regex, data[offset:offset + len(parts)], re.DOTALL) is not None
        findings.append(dict(name=name, candidate_rva=hex(rva), signature_size=len(parts),
                             rva_has_file_bytes=backed, match_at_candidate=expected_match,
                             file_match_count=len(matches), file_offsets=matches,
                             reason=None if backed else "Candidate RVA has no corresponding raw section bytes"))
    return dict(filename=path.name, size=len(data), sha256=hashlib.sha256(data).hexdigest(),
                pe_timestamp=hex(timestamp), sections=sections, signatures=findings)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    signatures = [(name, int(rva, 16), pattern) for name, rva, pattern in re.findall(
        r"name = '([^']+)', rva = (0x[0-9a-f]+).*?text = '([^']+)'",
        (ROOT / "src/signatures.lua").read_text(encoding="utf-8"))]
    report = dict(analysis="static-file-inspection-only", game_executed=False, tests_run=False,
                  runtime_verified=False, loaded_game_modules=False,
                  game=inspect(args.game_root / "data/game/game.dll", signatures),
                  engine=inspect(args.game_root / "bin/helldivers2.exe"),
                  limitations=["No unpacking, process memory read, native call or live state observation",
                               "No match in packed file does not establish a runtime signature mismatch",
                               "Equipment selection, save, widget registration and booster rules remain unresolved"])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8") as handle:
        json.dump(report, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"Wrote static metadata to {args.output}")


if __name__ == "__main__":
    main()
