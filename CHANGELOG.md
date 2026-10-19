# Changelog

## 1.0.0 — 2026-10-19

First public release, for Helldivers 2 game build 25480438.

- **Save / Load / Randomize** buttons on the Hellpod loadout card.
- Randomize covers the four stratagems, the booster, helmet, armor, cape, primary,
  secondary and grenade, using only what the game lists as selectable.
- Randomize rules: at most one backpack, one vehicle (any kind) and one support weapon
  among the stratagems; the booster is never "none" and never a squadmate's.
- Load restores one locally saved loadout and skips slots that are not selectable now.
- Mouse, keyboard and controller: Up from the "R Equipment" bar reaches the buttons.
- Buttons appear with the card on the loadout tab, with a slide-up entrance.
- Turns itself off on any other game build; no Bingus dependency.
- The package contains no game bytecode or game machine code (fingerprint checks,
  re-implemented boot callbacks). Table sizes are read from the game's own code.

Development notes for each step (0.1.x–0.6.x) are in [docs](docs/).
