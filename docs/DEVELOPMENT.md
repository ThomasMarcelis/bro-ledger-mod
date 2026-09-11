# Development

Squirrel owns actor reads, the finite evaluator, definition validation, library persistence, and tracked intent. JavaScript/CSS present data in the native character sheet and relay deliberate actions.

## Ownership

| File | Responsibility |
| --- | --- |
| `core.nut` | Constants, native stat endpoints, Gifted availability, finite allocation feasibility. |
| `library.nut` | Player-wide library via MSU PersistentData, one-way adoption of legacy campaign flags, bounded definitions/weights, inert BL1/BL2 sharing, duplicate policy. |
| `starters.nut` | Ten original read-only templates, independent of campaign flags. |
| `fit.nut` | Weighted shared-allocation Potential, progression bounds, comparison order, visible-roll advice. |
| `plan.nut` | Snapshot creation, manual perk reconciliation, legal routes and legacy alternatives. |
| `actor.nut` / `equipment.nut` | Safe live facts and current learned perk effects. |
| `state.nut` | Namespaced actor flags and immutable plan schemas 1–5. |
| `screen.nut` / preload | Settings, view/command boundary, native hooks, actor/epoch/revision guards. |
| `ledger.js` / `ledger.css` | Native board, comparison, sharing, compact guidance, tooltips and controls. |

Runtime Squirrel files live under `scripts/mods/bro_ledger/`; the preload is `scripts/!mods_preload/mod_bro_ledger.nut`; presentation is under `ui/mods/bro_ledger/`.

The library is one bounded BL2 string in the MSU PersistentData file `library` under `mod_config/`, outside any campaign save and shared across campaigns. Versions before 0.7.0 stored it as `BroLedger.Library` in native `World.Flags`; that flag is now a legacy source only. On first read, a campaign holding legacy bytes is merged into the store with the skip-duplicates policy and marked `BroLedger.LibraryMoved`, so it never contributes again and builds deleted from the store cannot reappear. Unreadable legacy bytes produce a notice and stay untouched. Validation and response generation precede the single store write; failed parsing, validation, or reads retain the previous bytes and actor revision. Store access errors propagate.

`BL2|` is followed by length-prefixed UTF-8 tokens: build count, each build's ID/name, eight fixed-order Minimum/Ideal/Weight triples, then count-prefixed route, flex, weapon-tag and playstyle-tag lists. BL1's eight Minimum/Ideal pairs remain readable with implicit weight 1. Limits remain 48,000 bytes, 32 personal builds, 40-byte names/IDs, 0–500 targets with two decimals, and whole weights 0–10 (an empty weight is 0). Mandatory perks must fit the point budget (10, or 11 with Student, which cannot be the last mandatory pick); flexible perks sit on top up to 20 perks in total. Blank ranges and zero weights are excluded from scoring. Plans written under the pre-0.7.0 rule (11 perks, none flexible) still load. Save validation names the specific problem: name length, missing range, too many mandatory perks, unlock order. No recursion, eval, compilestring, HTML or BBCode parsing occurs. Unknown versions, unsupported perks and damaged libraries remain read-only. Explicit import validates the first declared block and reports ignored extra bytes; default decoding and saved-library reads reject trailing bytes. Import collisions reject by default; skip/copy are explicit, atomic choices. New writes/exports use BL2.

Ten built-in templates are compared separately and do not occupy personal slots or touch the store. Result and selection identities include `source` (`library` or `starter`) and build ID. Track/export resolve that pair; editing a starter creates a personal draft. Personal IDs may equal template IDs without changing source ownership. Personal library damage does not authorize repair through a starter action.

Tracked intent remains `BroLedger.Schema` plus MSU `MSU.mod_bro_ledger.Plan` flags. Schema 5 (definitions revision 6) snapshots name, targets, weights, route, flex and tags. Schemas 1–4 remain readable without migration. Reads use a non-consuming flag view. Unknown schemas remain unchanged and disable plan writes. Template/library changes never modify tracked snapshots. Disable retains intent; Change build replaces it.

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

Packaging reads the version from `core.nut` and creates a deterministic `dist/mod_bro_ledger-<version>.zip` (currently 0.7.0, an unverified prerelease candidate) from original runtime files, README, MIT license, notices, and these two guides. Tools, dependencies, game assets, saves, fixtures and private evidence are excluded. `--audit` builds the separate owned runtime observer for disposable-campaign checks; it is not part of the player ZIP. Its queued command wrapper has a regression for forwarding, gameplay changes, RNG calls, and exception cleanup.

## Acceptance boundary

Before claiming a verified release, verify the complete starter/copy/create/import → compare/filter → track → manual play loop, ten-plus results, 0/1/many libraries, all targets/perks/tags, duplicates, current effects, Disable/re-enable and stale actor/dialog transitions. Verify the player-wide library, legacy campaign-flag adoption, and legacy/new/unknown plan save/reload plus ZIP removal/reinstall on a copied save with a declared game/platform/mod baseline. Until then, publish only as an unverified prerelease.

Editor checkboxes explicitly initialize the game's iCheck orange skin, consume its checked/unchecked callbacks, and destroy instances on rebuild/close. Browser fixtures must load that native plugin and skin, await fonts/images, and exercise real label clicks.

The editor keeps the build name and footer fixed. Perk order uses a persistent native list beneath a fixed heading; the other editor fields scroll separately when needed. Hovering a perk shows its native tooltip. The scroll host propagates its height and the error panel paints above the native scroll control; both are covered by CSS contract tests. Reordering follows the moved perk and restores an enabled control's focus; adding reveals the new pick, while removing clamps the retained position. Dispose the native list and window resize callback on close. Exercise the native mousewheel event path and both scroll boundaries in browser fixtures.

Use production/native browser fixtures at 1920×1080, 2560×1440 and 1600×900. Record scrollHeight/clientHeight, text overflow, input reachability, and separation from native sheet/roster/inventory/perk controls using longest legal content. Source-derived geometry is a hypothesis until rendered. Browser measurements remain distinct from in-game acceptance. Keep commands, captures, fixtures, reviews and remaining gaps in ignored `.local/`; do not redistribute proprietary evidence.
