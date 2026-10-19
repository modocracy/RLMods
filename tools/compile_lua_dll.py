#!/usr/bin/env python3
"""Compile text with the owned game's LuaJIT library; never call the input chunk.

This is a compiler backend, not a game/test runner. Only the string library is
opened. The sole lua_pcall invokes the native string.dump serializer, with the
compiled function as DATA. No base, FFI, package, IO or OS libraries are opened.
Lua 5.1 C API: https://www.lua.org/manual/5.1/manual.html
LuaJIT string.dump strip flag: https://github.com/LuaJIT/LuaJIT/blob/v2.1/src/lib_string.c
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
from pathlib import Path
import sys

SUPPORTED_SHA256 = "2c8720c9f446c848436ad993b1a88099d76f0b0b09df53689719b797c3039ce7"
MAX_SOURCE = 16 * 1024 * 1024


def compile_text(library: Path, source: bytes) -> bytes:
    if sys.platform != "win32" or ctypes.sizeof(ctypes.c_void_p) != 8:
        raise ValueError("The owned compiler backend requires 64-bit Windows Python.")
    if not source or len(source) > MAX_SOURCE or source.startswith(b"\x1b") or b"\0" in source:
        raise ValueError("Only bounded UTF-8 source text is accepted.")
    source.decode("utf-8")
    library = library.resolve(strict=True)
    if hashlib.sha256(library.read_bytes()).hexdigest() != SUPPORTED_SHA256:
        raise ValueError("Unsupported lua51.dll fingerprint; compiler not loaded.")
    # Absolute DLL path, default safe DLL search behavior. No game DLL/EXE loaded.
    dll = ctypes.CDLL(str(library))
    state_t, int_t, text_t, size_t = ctypes.c_void_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_size_t

    def bind(name, result, *args):
        fn = getattr(dll, name)
        fn.restype, fn.argtypes = result, list(args)
        return fn

    new = bind("luaL_newstate", state_t)
    close = bind("lua_close", None, state_t)
    open_string = bind("luaopen_string", int_t, state_t)
    field = bind("lua_getfield", None, state_t, int_t, text_t)
    is_c = bind("lua_iscfunction", int_t, state_t, int_t)
    load = bind("luaL_loadbufferx", int_t, state_t, text_t, size_t, text_t, text_t)
    boolean = bind("lua_pushboolean", None, state_t, int_t)
    call = bind("lua_pcall", int_t, state_t, int_t, int_t, int_t)
    to_string = bind("lua_tolstring", state_t, state_t, int_t, ctypes.POINTER(size_t))
    state = new()
    if not state:
        raise ValueError("LuaJIT could not allocate a compilation state.")

    def string_at_top():
        length = size_t()
        address = to_string(state, -1, ctypes.byref(length))
        if not address or length.value > 64 * 1024 * 1024:
            raise ValueError("Compiler returned an invalid string.")
        return ctypes.string_at(address, length.value)

    try:
        if open_string(state) != 1:
            raise ValueError("Compiler string library unavailable.")
        field(state, -1, b"dump")
        if not is_c(state, -1):
            raise ValueError("string.dump is not the compiler's native serializer.")
        # Stack: string table, native dump. Compile, but do NOT execute source.
        if load(state, source, len(source), b"@RLMmods/compiler-input", b"t"):
            raise ValueError(string_at_top().decode("utf-8", errors="replace"))
        boolean(state, 1)  # strip debug data; the game uses non-GC64 bytecode.
        # Stack: string table, native dump, compiled function argument, strip flag.
        if call(state, 2, 1, 0):
            raise ValueError(string_at_top().decode("utf-8", errors="replace"))
        result = string_at_top()
        if not result.startswith(b"\x1bLJ\x02\x02"):
            raise ValueError("Compiler did not emit the game's stripped non-GC64 format.")
        return result
    finally:
        close(state)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--library", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        if args.source.stat().st_size > MAX_SOURCE:
            raise ValueError("Source exceeds compiler size limit.")
        if args.output.exists():
            raise ValueError("Compiler output already exists.")
        bytecode = compile_text(args.library, args.source.read_bytes())
        with args.output.open("xb") as handle:
            handle.write(bytecode)
        print(f"Compiled {len(bytecode)} bytes; input chunk was not executed.")
        return 0
    except (OSError, ValueError, AttributeError) as exc:
        print(f"Compilation stopped: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
