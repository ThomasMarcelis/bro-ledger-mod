# Development

Squirrel owns actor reads, the finite evaluator, definition validation, library persistence, and tracked intent. JavaScript/CSS present data in the native character sheet and relay deliberate actions.

## Ownership

| File | Responsibility |
| --- | --- |
| `core.nut` | Constants, native stat endpoints, Gifted availability, finite allocation feasibility. |
| `library.nut` | Empty campaign library, bounded build validation, inert BL1 sharing, duplicate policy. |
| `fit.nut` | Gradual shared-allocation Potential, progression bounds, comparison order, visible-roll advice. |
| `plan.nut` | Snapshot creation, manual perk reconciliation, legal routes and legacy alternatives. |
| `actor.nut` / `equipment.nut` | Safe live facts and current learned perk effects. |
| `state.nut` | Namespaced actor flags and immutable plan schemas 1–4. |
| `screen.nut` / preload | Settings, view/command boundary, native hooks, actor/epoch/revision guards. |
| `ledger.js` / `ledger.css` | Native board, comparison, sharing, compact guidance, tooltips and controls. |

Runtime Squirrel files live under `scripts/mods/bro_ledger/`; the preload is `scripts/!mods_preload/mod_bro_ledger.nut`; presentation is under `ui/mods/bro_ledger/`.

The library is one bounded `BroLedger.Library` string in native `World.Flags`, serialized by the game's campaign save lifecycle. It starts empty in a new campaign; it is not global storage. Validation and response generation precede the single flag assignment. Failed parsing, validation, or reads retain the previous bytes and actor revision. The flag primitive is the commit boundary; campaign disk-save failures remain the game's responsibility.

`BL1|` is followed by length-prefixed UTF-8 tokens: build count, then each build's ID/name, eight fixed-order Minimum/Ideal pairs (empty means absent), then count-prefixed route, flex, weapon-tag and playstyle-tag lists. Limits are 48,000 bytes, 32 builds, 40-byte names/IDs, eight stat pairs, 0–500 with two decimals, and ten perks plus Student. No recursion, eval, compilestring, HTML or BBCode parsing occurs. Unknown versions, unsupported perks and damaged libraries remain read-only and are never reset implicitly. Explicit import validates the first declared BL1 block and ignores subsequent bytes with a notice; default decoding and saved-library reads still reject trailing bytes. Import collisions default to rejection; skip/copy are explicit and imports commit together.

Tracked actor intent remains separate: `BroLedger.Schema` plus MSU `MSU.mod_bro_ledger.Plan` flags. Schema 4 (definitions revision 5) snapshots name, targets, creator route, flex and tags. Schemas 1–3 remain readable without migration. Reads use a non-consuming flag view. Unknown schemas remain unchanged and disable plan writes. Library changes never modify tracked snapshots. Disable retains intent; Change build replaces it.

Every mutation checks the selected owned actor, screen epoch, observed actor revision, request sequence, and last observed library bytes. Native callbacks and closures reject stale actor/dialog state. Never mutate live actors to forecast, reveal future rolls, spend/equip/rename, or replace native perk confirmation or drag/drop.

## Checks and package

Use Node.js 22+, Python 3, and the pinned Squirrel 3.2 runner at ignored `.tools/sq` (commit `f92bc298784ceea459b12e2de33bdff672bfeb83`). Build `sq_static` with CMake from [Squirrel](https://github.com/albertodemichelis/squirrel), then copy it locally. The game uses Squirrel 3.0.4 with 32-bit integers/floats; standalone behavior is supporting evidence.

Place the pinned `mod_msu-1.9.0.zip` in `.tools/`; `check.py` verifies the [documented hash](../THIRD_PARTY.md) before extracting its settings/tooltip contract fixtures. No npm install is required.

```sh
python3 tools/check.py
python3 tools/package.py
```

Checks require a Squirrel success marker and empty stderr, run Node behavior tests, and check JS syntax. Tests cover allocation against exhaustive legal schedules, normalization, target scoring, import/export and corruption limits, persistence rollback, old snapshots, native settings, manual/locked perks and stale callbacks. Obsolete tactical catalog gates are retired.

Before packaging, also run `tests/run.nut` and `tests/settings.nut` with a Squirrel 3.0.x runner, requiring the same success marker and empty stderr. The settings suite executes queued preload includes and registered refresh/Evaluate callbacks. Squirrel 3.2 accepts adjacent same-line `if` statements that 3.0.x rejects without a separating newline or semicolon; a compile failure prevents the entire library chunk from registering.

Packaging creates deterministic `dist/mod_bro_ledger-0.4.8.zip` (unverified prerelease) from original runtime files, README, MIT license, notices, and these two guides. Tools, dependencies, game assets, saves, fixtures and private evidence are excluded. `--audit` builds the separate owned runtime observer for disposable-campaign checks; it is not part of the player ZIP. Its queued command wrapper has a regression for forwarding, gameplay changes, RNG calls, and exception cleanup.

## Acceptance boundary

Before claiming a verified release, verify the complete create/import → compare/filter → track → manual play loop, ten-plus results, 0/1/many libraries, all targets/perks/tags, duplicates, current effects, Disable/re-enable and stale actor/dialog transitions. Verify campaign/library and legacy/new/unknown plan save/reload plus ZIP removal/reinstall on a copied save with a declared game/platform/mod baseline. Until then, publish only as an unverified prerelease.

Use production/native browser fixtures at 1920×1080, 2560×1440 and 1600×900. Record scrollHeight/clientHeight, text overflow, input reachability, and separation from native sheet/roster/inventory/perk controls using longest legal content. Source-derived geometry is a hypothesis until rendered. Browser measurements remain distinct from in-game acceptance. Keep commands, captures, fixtures, reviews and remaining gaps in ignored `.local/`; do not redistribute proprietary evidence.
