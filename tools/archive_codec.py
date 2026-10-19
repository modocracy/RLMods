"""Read one Lua resource and write a minimal Helldivers 2 patch archive.

The archive layout and Murmur64A implementation are adapted from
CowboyBingus/BingusSharedLoader scripts/archive.py (Copyright 2026 CowboyBingus,
0BSD) and informed by xypwn/filediver stingray/archive.go and hash.go (Copyright
2026 Filediver contributors, BSD-3-Clause). See tools/LICENSES and PACKAGING.md.
No game resources are included in this file.
"""

from __future__ import annotations

import hashlib
import re
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO


MAGIC = 0xF0000011
LUA_TYPE = 0xA14E8DFA2CD117E2
STARTUP_NAME = 0xF476DF93691895FA
STARTUP_PATH = "boot"
# Exact vanilla input inspected in the user's build 25480438. Never wrap a
# different startup mod and label it the original boot resource.
STARTUP_SHA256 = "85d7c6a9981e3288286c63bdb75e4256dcf859d6fc5f712cb72e9b329b1712e6"
WWISE_NAME = 0x7251FDD9BB62480A
WWISE_PATH = "core/wwise/lua/wwise_flow_callbacks"
PATCH_NAME = "9ba626afa44a3aa3.patch_0"
HEADER = struct.Struct("<III20sQQ24s")
TYPE_ENTRY = struct.Struct("<IIQIIII")
FILE_ENTRY = struct.Struct("<7Q6I")
LUA_ENVELOPE = struct.Struct("<II")
BYTECODE_HEADER = b"\x1bLJ\x02\x02"
MAX_RESOURCE_SIZE = 64 * 1024 * 1024
BASE_ARCHIVE_NAME = re.compile(r"[0-9a-fA-F]{16}\Z")


class PackagingError(ValueError):
    """An unsupported or ambiguous input must not produce an installable ZIP."""


@dataclass(frozen=True)
class OriginalResource:
    data: bytes
    origins: tuple[str, ...]
    method: str


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def resource_hash(name: str) -> int:
    """Stingray's MurmurHash64A, UTF-8 bytes, seed zero."""
    data = name.encode("utf-8")
    mask = (1 << 64) - 1
    mix = 0xC6A4A7935BD1E995
    value = len(data) * mix & mask
    end = len(data) // 8 * 8
    for (word,) in struct.iter_unpack("<Q", data[:end]):
        word = word * mix & mask
        word ^= word >> 47
        value = (value ^ (word * mix & mask)) * mix & mask
    if data[end:]:
        value = (value ^ int.from_bytes(data[end:], "little")) * mix & mask
    value ^= value >> 47
    value = value * mix & mask
    return value ^ (value >> 47)


def read_exact(stream: BinaryIO, size: int, label: str) -> bytes:
    data = stream.read(size)
    if len(data) != size:
        raise PackagingError(f"Truncated {label}: expected {size} bytes, got {len(data)}.")
    return data


def read_callback_from_archive(path: Path) -> bytes | None:
    """Read metadata and the target only; never load a whole game archive.

    This accepts unpacked Stingray archives, not compressed NXA/DSAR bundles.
    The resource is identified by BOTH name hash and type hash.
    """
    with path.open("rb") as stream:
        size = path.stat().st_size
        if size < HEADER.size:
            raise PackagingError(f"{path.name}: archive is shorter than its header.")
        header = HEADER.unpack(read_exact(stream, HEADER.size, path.name))
        magic, type_count, file_count = header[:3]
        if magic != MAGIC:
            raise PackagingError(
                f"{path.name}: unsupported archive magic. For slim/NXA installations, "
                "extract the original .lua.main resource with Filediver and use "
                "--original-resource instead."
            )
        table_end = HEADER.size + type_count * TYPE_ENTRY.size + file_count * FILE_ENTRY.size
        if table_end > size:
            raise PackagingError(f"{path.name}: truncated or invalid archive table.")
        has_lua = False
        for _ in range(type_count):
            entry = TYPE_ENTRY.unpack(read_exact(stream, TYPE_ENTRY.size, path.name))
            has_lua = has_lua or entry[2] == LUA_TYPE
        if not has_lua:
            return None
        selected = None
        for _ in range(file_count):
            entry = FILE_ENTRY.unpack(read_exact(stream, FILE_ENTRY.size, path.name))
            if entry[:2] != (STARTUP_NAME, LUA_TYPE):
                continue
            if selected is not None:
                raise PackagingError(f"{path.name}: duplicate callback resource entries.")
            main_offset, main_size = entry[2], entry[7]
            if entry[8] or entry[9]:
                raise PackagingError(f"{path.name}: callback unexpectedly uses stream/GPU data.")
            if not LUA_ENVELOPE.size < main_size <= MAX_RESOURCE_SIZE:
                raise PackagingError(f"{path.name}: unsupported callback resource size {main_size}.")
            if main_offset < table_end or main_offset + main_size > size:
                raise PackagingError(f"{path.name}: callback points outside the archive payload.")
            selected = (main_offset, main_size)
        if selected is None:
            return None
        stream.seek(selected[0])
        return read_exact(stream, selected[1], f"{path.name} callback")


def load_original_resource(game_data: Path | None, original_file: Path | None) -> OriginalResource:
    """Extract from base archives only, or read an explicitly supplied envelope."""
    if (game_data is None) == (original_file is None):
        raise PackagingError("Choose exactly one of --game-data or --original-resource.")
    if original_file is not None:
        if not original_file.is_file():
            raise PackagingError(f"Original resource file not found: {original_file}")
        if original_file.stat().st_size > MAX_RESOURCE_SIZE:
            raise PackagingError("Original resource exceeds the supported size limit.")
        return OriginalResource(original_file.read_bytes(), (original_file.name,), "explicit-resource")
    if not game_data.is_dir():
        raise PackagingError(f"Game data directory not found: {game_data}")
    archives = sorted(
        (p for p in game_data.iterdir() if BASE_ARCHIVE_NAME.fullmatch(p.name) and p.is_file()),
        key=lambda p: p.name.lower(),
    )
    if not archives:
        raise PackagingError(
            "No unpacked 16-hex-digit base archives found. Slim/NXA installations "
            "need a Filediver-extracted original .lua.main file with --original-resource."
        )
    # Patch files are deliberately excluded: their callbacks may already contain a mod.
    found = None
    origins = []
    for archive in archives:
        data = read_callback_from_archive(archive)
        if data is None:
            continue
        if found is not None and data != found:
            raise PackagingError(
                "Base archives contain different versions of the callback resource. "
                "Use --original-resource with a known clean resource from this installation."
            )
        found = data
        origins.append(archive.name)
    if found is None:
        raise PackagingError(f"Original {STARTUP_PATH}.lua was not found in the base archives.")
    return OriginalResource(found, tuple(origins), "unpacked-base-archives")


def original_bytecode(resource: bytes) -> bytes:
    if len(resource) < LUA_ENVELOPE.size + len(BYTECODE_HEADER):
        raise PackagingError("Original input is not a complete .lua.main resource.")
    size, version = LUA_ENVELOPE.unpack_from(resource)
    if version != 2 or size != len(resource) - LUA_ENVELOPE.size:
        raise PackagingError(
            "Expected an original .lua.main envelope: uint32 bytecode length, uint32 2, "
            "then exactly that many bytecode bytes. Raw .ljbc input is not accepted."
        )
    bytecode = resource[LUA_ENVELOPE.size:]
    if not bytecode.startswith(BYTECODE_HEADER):
        raise PackagingError(
            "Unsupported original LuaJIT format; expected 1b 4c 4a 02 02 "
            "(stripped, little-endian, non-GC64). No patch was built."
        )
    return bytecode


def make_lua_resource(bytecode: bytes) -> bytes:
    if not bytecode.startswith(BYTECODE_HEADER):
        raise PackagingError("Compiler did not produce the required non-GC64 LuaJIT bytecode.")
    if len(bytecode) > MAX_RESOURCE_SIZE - LUA_ENVELOPE.size:
        raise PackagingError("Compiled callback exceeds the supported resource size limit.")
    return LUA_ENVELOPE.pack(len(bytecode), 2) + bytecode


def make_patch(resource: bytes) -> bytes:
    """One Lua type, one resource, 16-byte aligned main payload, no stream/GPU data."""
    if resource_hash("lua") != LUA_TYPE or resource_hash(STARTUP_PATH) != STARTUP_NAME:
        raise PackagingError("Internal resource identities do not match the documented hashes.")
    if STARTUP_NAME == WWISE_NAME:
        raise PackagingError("The independent boot patch must not own Bingus' Wwise resource.")
    offset = (HEADER.size + TYPE_ENTRY.size + FILE_ENTRY.size + 15) & ~15
    total_size = (offset + len(resource) + 15) & ~15
    header = HEADER.pack(MAGIC, 1, 1, b"", total_size, 0, b"")
    type_entry = TYPE_ENTRY.pack(0, 0, LUA_TYPE, 1, 0, 16, 16)
    file_entry = FILE_ENTRY.pack(
        STARTUP_NAME, LUA_TYPE, offset, 0, 0, 0, 0, len(resource), 0, 0, 16, 16, 0
    )
    archive = bytearray(total_size)
    archive[:HEADER.size + TYPE_ENTRY.size + FILE_ENTRY.size] = header + type_entry + file_entry
    archive[offset:offset + len(resource)] = resource
    return bytes(archive)
