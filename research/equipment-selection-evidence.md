# Equipment-selection evidence and remaining blockers

**0.1.5 correction:** the direct-only ownership policy below is NOT sufficient
for stratagems. The user's 0.1.4 trace resolves the code successfully, but reports
all 91 child offers at state 1. Current `snapshot('stratagem')` uses direct OR
linked-parent ownership with native enabled/selectable row flags. The generic
clothing observer remains separate. See [sources and exact rule](../docs/history/UPDATE-0.1.5.md).

**0.1.4 correction:** the user's 0.1.3 log reports that the ownership signature
did not match at the earlier inferred RVA. The fixed-address/pinned-displacement
description below is historical. The current observer searches for the complete
published pattern with only its documented four-byte RIP relocation masked,
requires uniqueness, and cross-checks the derived global and layout with the
stratagem offer readers. See [the 0.1.4 change record](../docs/history/UPDATE-0.1.4.md).
The relocated match and actual equip result are not yet runtime-confirmed.

**Continuation, 2026-10-19:** the user's installed original files have now been
read and the callback extracted. See [installed-image metadata](installed-build-25480438.json)
and [current implementation/blockers](../docs/history/IMPLEMENTATION-2026-10-19.md).
The original notes below describe the prior public-source investigation. Their
statement that no local files/compilation were available is historical.
The packed installed images did not establish the missing equipment ABI.

Additional source review: FlexibleLoadouts' pinned `clear_loadout` demonstrates
the widget/slots-changed/save path with widget argument **zero** (clear). It does
not demonstrate this project's nonzero random-selection transaction. The public
`set_slot` signature contains a conversion call before forwarding its result to
the lower-level widget setter. Its meaning is not independently established by
the packed disk image. The current nonzero setter path remains experimental;
no additional native ABI was inferred or enabled from that conversion alone.

Research date: 2026-10-18. Target: Steam build 25480438, executable 1.8.46015.0.

This document records public source evidence only. No game, test suite, validation command, installation, anticheat workaround, or unlock modification was run. No clothing/weapon/booster adapter is enabled by this research.

## Result

The native clothing data path is substantially mapped, including legitimate ownership and local-player identity. A complete, independently usable pre-mission transaction covering all requested categories is **not established**. Do not label the whole-loadout randomizer functional on the strength of these findings.

- Armor: a concrete pre-mission payload assignment plus native actor setter is published. The source does not establish this project's complete save/card-refresh transaction.
- Helmet and cape: native actor setters are published, but that source deliberately refuses pre-mission accessory commits and allows ordinary accessory commits in ship Armory only.
- Primary, secondary, grenade: no complete ownership-preserving selection/commit API was located in the examined sources.
- Booster: neither a verified ordinary selection transaction nor the complete squad-duplicate/availability check was located. A booster tuning API or an actor-state field is not that API.

## Primary source references

1. HD2-Transmog, revision `f469851dcb5bf241a08be5329728ca649710896c`:
   - [Native selection, bindings and commit guards](https://github.com/tyrypyrking/HD2-Transmog/blob/f469851dcb5bf241a08be5329728ca649710896c/src/native_grid.lua)
   - [Catalog and ownership observation](https://github.com/tyrypyrking/HD2-Transmog/blob/f469851dcb5bf241a08be5329728ca649710896c/src/catalog_probe.lua)
   - [Catalog/ownership instruction signatures](https://github.com/tyrypyrking/HD2-Transmog/blob/f469851dcb5bf241a08be5329728ca649710896c/src/catalog_compat.lua)
   - [Local customization request/cache identity](https://github.com/tyrypyrking/HD2-Transmog/blob/f469851dcb5bf241a08be5329728ca649710896c/src/player_customization_probe.lua)
   - [DiverKit integration only](https://github.com/tyrypyrking/HD2-Transmog/blob/f469851dcb5bf241a08be5329728ca649710896c/src/diverkit_bridge.lua)
2. MatchYourColors, revision `517856949828f13fc817b182775fa0350c26e2ac`:
   - [Build-25480438 local player and customization globals](https://github.com/CowboyBingus/MatchYourColors/blob/517856949828f13fc817b182775fa0350c26e2ac/src/avatar.lua)
   - [License](https://github.com/CowboyBingus/MatchYourColors/blob/517856949828f13fc817b182775fa0350c26e2ac/LICENSE)
3. VanillaPlusMegapack, revision `da110a81bf6ac60ba74f04a3c71a2ab5e8cfccfd`:
   - [ArmoryPreviewCache native catalog lookup](https://github.com/CowboyBingus/VanillaPlusMegapack/blob/da110a81bf6ac60ba74f04a3c71a2ab5e8cfccfd/components/ArmoryPreviewCache/src/native.lua)
4. HD2Runtime, revision `34fba0887b196130df4142933fbe1b6ff6be5020`:
   - [Scope of authoring API](https://github.com/SkyeShade/HD2Runtime/blob/34fba0887b196130df4142933fbe1b6ff6be5020/sdk/README.md)
   - [License](https://github.com/SkyeShade/HD2Runtime/blob/34fba0887b196130df4142933fbe1b6ff6be5020/LICENSE)

## Clothing identity and ownership

These are data observations, not permission to write the corresponding memory.

- `game.dll + 0x33264F8` holds the customization manager pointer. MatchYourColors explicitly identifies Steam build 25480438 for this chain.
- Manager `+0x00` is a pointer array of kit records; `+0x08` is its count. Kit `+0x00` is the 32-bit item ID; kit `+0x28` is category: armor 0, helmet 1, cape 2.
- `game.dll + 0x347CEF8` holds the progression/offer manager pointer, corroborated by ArmoryPreviewCache.
- Progression `+0x1CE0` is the offer count. Offer entries begin at `+0xB9CE4` with stride 24 bytes. The first three 32-bit fields are state index, offer ID, and item ID.
- An offer's state is at `progression + 0x1CE4 + state_index * 184`. The ownership-eligible state at `+0x14` is 2 or 4, and the disabled byte at `+0xB4` must be zero.
- Several offers can reference one item. One qualifying enabled offer is positive ownership evidence; a different locked offer does not revoke that evidence.
- Re-read the exact qualifying offer, its state, catalog slot, manager pointers and count immediately before any proposed operation. Catalog presence and currently worn gear are not ownership proof.

The source bounds progression to 4096 offers and verifies categories and item identities against its retained catalog. A new implementation needs equivalent structural/category evidence rather than trusting arbitrary table contents.

## Local player and clothing state

- Player manager pointer: `game.dll + 0x3326468`.
- Total/local counts: player manager `+0x84`/`+0x88`. The Transmog reader requires exactly one local player.
- First local player pointer: player manager `+0xE8`; its player ID is `+0x08`.
- Customization manager `+0x930` is an open-addressing map from player ID to customization index. Header fields are table pointer, capacity, empty key, multiplier; entries are `{uint32 key, uint32 value}`. Source bounds and verifies every probe.
- Customization request: manager `+0xA7C + index * 64`.
- Applied/cache state: manager `+0x96C + index * 68`.
- Both begin with 32-bit body type, helmet ID, cape ID, armor ID at offsets 0, 4, 8, 12.

The current request and applied cache must agree before a new operation. Manager addresses alone are insufficient session identity because objects can be reused.

## Pre-mission payload and native calls

HD2-Transmog's pre-mission controller observation establishes:

- Payload: `controller + 0x10 + local_slot * 0x9F0`.
- Clothing IDs relative to payload: helmet `+0x124`, cape `+0x128`, armor `+0x12C`.
- Player cards start at controller `+0x53A78`, stride `0x1EE18`. Each card's `+0x1EDF0` is its payload pointer, `+0x1EDF8` the player ID, and `+0x1EDFC` the local slot index.
- The controller's local slot is `+0x27D0`. Peer identity is cross-checked against the current session and `controller + slot * 0x9F0 + 0x9F8`.
- Native clothing setter ABI: `void (void *customization_manager, uint32_t player_id, uint32_t item_id)`.

### Candidate current-build RVAs, inferred rather than executed

The published 98-byte `deployment_apply` caller carries three RIP-relative loads of the same customization global. Combining those displacements with the independently published `0x33264F8` global gives the same caller start, `0x146E785`, for all three loads. Its direct calls then resolve to:

- Cape setter: `0x875EC0`
- Helmet setter: `0x875CD0`
- Armor setter: `0x8760B0`

The calculation uses caller-relative load displacement offsets 23, 49, 75 with next-instruction offsets 27, 53, 79; direct-call displacement offsets 40, 66, 92 with next-instruction offsets 44, 70, 96. These values are candidates until the complete caller and callee semantics are checked against the user's supported image. They are not executable fallbacks.

Published caller bytes (98 bytes; stored only as a fingerprint since 0.6.1, the same
confirm-branch code that `src/equipment.lua` pins at `0x146E785`):

```text
pin:98::e9dbc5de54f1fd17
```

The source checks the armor callee's player map at `+0x938`, 64-byte request stride, and armor request field at `+0xA88`; helmet and cape setters have independent field checks. A short function prologue alone does not establish these contracts.

The same RIP arithmetic proposes `0x136F880` for the published `progression_owned_layout` signature and `0x196E30A` for `gear_catalog_categories`. These are also unexecuted candidates; full matching and semantic checks remain required.

## Read-only ownership adapter

`src/ownership.lua` is an original bounded observation adapter, not an equipment setter. `RLM.create_ownership(platform)` returns an object whose `snapshot()` reads one bounded item/offer index per transaction. `snapshot.owns(item_id, expected_offer_id)` returns `true, opaque_proof` only when an actual progression offer row has both the requested item ID and, when supplied, the expected offer ID; its state index is within the observed count; its freshly read status is 2 or 4; and its disabled byte is zero. Failures return `false, nil, reason`. A failed snapshot is an object with `available=false` whose `owns` always refuses. `recheck(proof, optional_item_id, optional_offer_id)` re-reads the same qualifying row, state, manager pointer and count. Proofs are private to their adapter instance and are not serialized. The adapter also supplies `owns(item_id, expected_offer_id)` as a single-item convenience.

The adapter requires the platform's supported image timestamp and an exact full 150-byte match at candidate RVA `0x136F880`, without wildcard displacements. It derives the progression global from those bytes and additionally requires the published `0x347CEF8` slot. Any mismatch disables ownership observation. Reads are capped at 4096 bytes each, the offer count at 4096, and every observed state index is bounded by that count. The index stores row identities only; each ownership request re-reads the relevant row/state and never relies on a cached owned-state decision. Multiple offers use positive-union semantics within the requested item and optional exact-offer filter, with the qualifying offer retained for rechecking.

This adapter proves only the progression-owned state for a matched offer row. In particular, its presence does not establish a stratagem category, current picker availability, a local-player session, mission legality, equipment selection, persistence, or booster squad legality. A caller must independently establish those facts and recheck the proof immediately before any separately justified operation. These observations are sequential reads, not an atomic game transaction. The implementation has not been run or validated.

## Exact local inputs needed for remaining mappings

Further independent mapping needs the user's own files from the same installed game build:

- `<Helldivers 2>/data/game/game.dll` is the native gameplay DLL. It is **not** `<Helldivers 2>/bin/game.dll`.
- `<Helldivers 2>/bin/helldivers2.exe` is the engine executable.

Here `<Helldivers 2>` means the installation root actually selected in Steam, not an assumed drive or default library. Both files must belong to the same Steam build, targeted here as 25480438 / executable version 1.8.46015.0. These paths specify input prerequisites, not a claim that the files were supplied, read, or matched in this work. No game binaries should be bundled with this source project.

With separate authorization for any future binary analysis or validation, the missing evidence is the native UI selection paths for primary, secondary, grenade and booster; item/offer/category mapping; all applicable ownership and availability branches; booster squad-duplicate rules; and the complete clothing and equipment profile-save/card-refresh transaction. The published source findings alone do not establish those remaining contracts. No game execution or installation is required merely to provide the two files, and neither was performed here.

## Why no equipment.lua is supplied

The pre-mission clothing payload matches the shape of the stratagem loadout block, but this alone does not prove a full transaction. The native Transmog deployment branch writes only the armor field and invokes the armor actor setter; its public code explicitly rejects accessories in that branch. Its ship Armory path instead modifies a different pending buffer and invokes a separate native commit routine. Its headless clothing path changes the live actor request without persisting the game profile.

DiverKit's optional bridge additionally invokes its own `commit` and `refresh` bindings, but their independent resolution is not supplied by that bridge. Substituting an invented `ApplyLoadout`, calling an actor setter as if it were profile persistence, or assuming the stratagem save routine is sufficient would overstate the evidence.

Required remaining work before enabling full loadout randomization:

1. Independently establish primary, secondary, grenade and booster item/offer mapping, selection ABI, and commit/refresh path.
2. Establish booster squad legality immediately before commit, including duplicate claims and changes in squad state.
3. Establish complete clothing selection, profile save and card refresh in the intended pre-mission screen, for all three clothing categories.
4. Preserve native restrictions, unready/transition guards, local ownership identity and exact readback. If evidence is unavailable or changed, refuse the operation.
5. Obtain the user's separate permission for any future testing or validation work; the current work did not run it.

## Source reuse limits

- HD2-Transmog has no repository license declared and no root license file in the examined tree. Its implementation has not been copied into this project. This note records factual ABI/layout evidence and citations; it does not imply permission to redistribute its source.
- MatchYourColors publishes the Zero-Clause BSD license. A standalone implementation does not need its loader merely to use documented facts.
- HD2Runtime's custom license permits reuse of parts of its code/findings with visible user-facing credit. It forbids redistributing the runtime in whole or large part without prior written permission. It does not provide the missing whole-loadout API found here.
- Alomare/FlexibleLoadouts is GPL-3.0 and is handled separately by this project's existing notices. Its stratagem selection code does not establish the missing equipment categories.
