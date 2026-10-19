#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Generate src/ui_images.lua and the packaged mod icon from the finished RLMmods PNGs.

The game's Lua GUI cannot load PNG files, so each button is stored as run-length
encoded pixel rows that ui.lua draws as rectangles. The source PNGs are read only.

Each source image is decomposed into "ink amount" maps over its own background
(white and yellow ink on charcoal for the default images, dark ink on yellow for the
random hover image). The rows store only that shape: a class per pixel, 0 for the
background, 1..LEVELS for white-ink levels and LEVELS+1..2*LEVELS for yellow-ink
levels. ui.lua turns classes into colours per state, so one shape serves all states:

  default  charcoal background, white icon and border, yellow corner marks
  hover    yellow background, dark icon, border and corner marks
  disabled dim charcoal background, grey icon, border and corner marks

The random image is supplied as a hover image; its default state takes the corner
marks' yellow from the save image's corner positions (all buttons share the layout).

The mod-manager icon is the overlapping-dice PNG reduced to 256x256 and 256 colours
(docs/design/rlmmods-mod-icon-256.png); managers show it far smaller than 512 px.

Usage: python tools/make_ui_images.py
"""
from __future__ import annotations

import hashlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    "save": ("docs/design/icons/512-v4/save-default.png", "default"),
    "load": ("docs/design/icons/512-v4/load-default.png", "default"),
    "random": ("docs/design/icons/512-v2/random-hover.png", "hover"),
}
OUTPUT = ROOT / "src/ui_images.lua"
ICON_SOURCE = "docs/design/rlmmods-mod-icon-512-v1.png"
ICON_OUTPUT = ROOT / "docs/design/rlmmods-mod-icon-256.png"
ICON_SIZE, ICON_COLOURS = 256, 256
SIZES = (64, 128)          # drawn at the nearest size not smaller than the button
LEVELS = 7                 # ink levels per ink colour after downscaling
MAX_RUN = 89               # run byte = chr(36 + run), always printable ASCII

COLORS = {
    "default": {"bg": (27, 29, 29), "white": (238, 238, 232), "yellow": (240, 230, 36)},
    "hover": {"bg": (245, 236, 60), "ink": (20, 21, 20)},
    "disabled": {"bg": (34, 35, 34), "ink": (104, 106, 100)},
}


def load(path: str) -> np.ndarray:
    image = Image.open(ROOT / path)
    if image.size != (512, 512):
        raise SystemExit(f"{path}: expected 512x512, got {image.size}")
    return np.asarray(image.convert("RGB")).astype(np.float64)


def border_colour(pixels: np.ndarray) -> np.ndarray:
    # Background sampled inside the frame, away from the icon and the corner marks.
    patch = np.concatenate([pixels[200:312, 40:70].reshape(-1, 3), pixels[200:312, 442:472].reshape(-1, 3)])
    return np.median(patch, axis=0)


def decompose_default(pixels: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """White-ink and yellow-ink amounts over the charcoal background."""
    bg = border_colour(pixels)
    r, g, b = pixels[..., 0], pixels[..., 1], pixels[..., 2]
    yellowish = (r - b > 60) & (g - b > 60)
    lum = pixels.mean(axis=2)
    white = np.clip((lum - bg.mean()) / (235.0 - bg.mean()), 0, 1)
    yellow_ref = np.array(COLORS["default"]["yellow"], dtype=np.float64)
    direction = yellow_ref - bg
    yellow = np.clip(((pixels - bg) @ direction) / (direction @ direction), 0, 1)
    return np.where(yellowish, 0.0, white), np.where(yellowish, yellow, 0.0)


def decompose_hover(pixels: np.ndarray) -> np.ndarray:
    """Dark-ink amount over the yellow background."""
    bg = border_colour(pixels)
    lum = pixels.mean(axis=2)
    return np.clip((bg.mean() - lum) / (bg.mean() - 22.0), 0, 1)


def downscale(amount: np.ndarray, size: int) -> np.ndarray:
    image = Image.fromarray((amount * 255).astype(np.uint8), "L").resize((size, size), Image.LANCZOS)
    return np.asarray(image).astype(np.float64) / 255


def classes(white: np.ndarray, yellow: np.ndarray) -> np.ndarray:
    w = np.round(np.clip(white, 0, 1) * LEVELS).astype(int)
    y = np.round(np.clip(yellow, 0, 1) * LEVELS).astype(int)
    # One ink per pixel: the stronger one (they only meet at antialiased edges).
    return np.where(y > w, LEVELS + y, w)


def encode(cls: np.ndarray) -> str:
    data = []
    for row in cls:
        x = 0
        while x < len(row):
            value = int(row[x])
            run = 1
            while x + run < len(row) and run < MAX_RUN and int(row[x + run]) == value:
                run += 1
            data.append(chr(48 + value) + chr(36 + run))
            x += run
    return "".join(data)


def make_icon() -> None:
    icon = Image.open(ROOT / ICON_SOURCE).convert("RGB").resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
    icon = icon.quantize(colors=ICON_COLOURS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    icon.save(ICON_OUTPUT, "PNG", optimize=True)
    print(f"Wrote {ICON_OUTPUT.relative_to(ROOT)} ({ICON_OUTPUT.stat().st_size} bytes)")


def main() -> None:
    save_pixels = load(SOURCES["save"][0])
    _, save_yellow = decompose_default(save_pixels)
    corner_mask = np.asarray(Image.fromarray((save_yellow > 0.25).astype(np.uint8) * 255)
                             .filter(ImageFilter.MaxFilter(9))) > 0

    lines = [
        "-- SPDX-License-Identifier: GPL-3.0-or-later",
        "-- Generated by tools/make_ui_images.py from the RLMmods button PNGs; do not edit.",
        "-- Each image: n x n classes as rows of (class char, run char) pairs, top to bottom:",
        "-- class = byte - 48 (0 background, 1..levels white ink, levels+1..2*levels yellow ink),",
        "-- run length = byte - 36. ui.lua derives each state's colours from `colors`.",
    ]
    for name, (path, kind) in SOURCES.items():
        digest = hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
        lines.append(f"-- {name}: {path} sha256={digest}")
    lines += ["local RLM=assert(rawget(_G,'RLMmods'))", "RLM.ui_images={", f"    levels={LEVELS},", "    colors={"]
    for state, colours in COLORS.items():
        fields = ",".join(f"{key}={{{r},{g},{b}}}" for key, (r, g, b) in colours.items())
        lines.append(f"        {state}={{{fields}}},")
    lines.append("    },")

    for name, (path, kind) in SOURCES.items():
        pixels = load(path)
        if kind == "default":
            white, yellow = decompose_default(pixels)
        else:
            dark = decompose_hover(pixels)
            # Same shapes; corner marks are yellow ink like the other buttons.
            white, yellow = np.where(corner_mask, 0.0, dark), np.where(corner_mask, dark, 0.0)
        lines.append(f"    {name}={{")
        for size in SIZES:
            data = encode(classes(downscale(white, size), downscale(yellow, size)))
            if "]==]" in data:
                raise SystemExit("Encoded data contains the long-string terminator")
            lines.append(f"        [{size}]={{n={size},rows=[==[{data}]==]}},")
        lines.append("    },")
    lines.append("}")
    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"Wrote {OUTPUT.relative_to(ROOT)} ({OUTPUT.stat().st_size} bytes)")
    make_icon()


if __name__ == "__main__":
    main()
