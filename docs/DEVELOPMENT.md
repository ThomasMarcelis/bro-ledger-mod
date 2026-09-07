# Development

Squirrel reads game state, evaluates builds, produces guidance, and saves the player's chosen plan. JavaScript and CSS display the result in the native character sheet and relay player actions.

## Architecture

| File | Responsibility |
| --- | --- |
| `scripts/!mods_preload/mod_bro_ledger.nut` | Register dependencies, settings, assets, serialization hooks, and the character-screen bridge. |
| `scripts/mods/bro_ledger/catalog.nut` | Versioned build targets, routes, variants, and action assumptions. |
| `scripts/mods/bro_ledger/core.nut` | Shared constants/helpers, stat growth, finite forecasts, and offered-roll advice. |
| `scripts/mods/bro_ledger/plan.nut` | Create, reconcile, and replace plans; resolve legal routes and flexible perks. |
| `scripts/mods/bro_ledger/fit.nut` | Grade bands, assessments, stat rows, evaluation, and comparison order. |
| `scripts/mods/bro_ledger/equipment.nut` | Live equipment readers, action reserves, bounded weapon comparisons, and advice. |
| `scripts/mods/bro_ledger/actor.nut` | Read and normalize safe live brother facts. |
| `scripts/mods/bro_ledger/state.nut` | Validate and serialize namespaced actor plans. |
| `scripts/mods/bro_ledger/screen.nut` | Settings, view payloads, command validation, stale-response rejection, and rollback. |
| `ui/mods/bro_ledger/ledger.js` | Native character-sheet presentation and callbacks. |
| `ui/mods/bro_ledger/ledger.css` | Mod-owned layout and game-native styling. |

## Invariants

- The player alone selects builds, spends points, equips items, and names brothers.
- Read visible offers and safe live definitions. Never generate future rolls, advance RNG, or mutate a live brother to simulate a forecast.
- Save intent, not copies of live stats. The persistent contract is mod ID `mod_bro_ledger`, definitions revision 3, and plan schemas 1 and 2.
- Schema 1 remains readable without migration. Unknown future schemas stay byte-for-byte intact and disable guidance with an explanation.
- Evaluation and refresh may reconcile guidance on a copy; only Track, Change build, Disable, or re-enable may change saved intent.
- Validate live data, serialized data, and screen commands at their boundaries. Internal functions rely on those validated shapes.
- Preserve the native character sheet, roster, stash, controls, perk state, and tooltip lifecycle.
- Missing or uncertain facts remain unknown. Equipment does not affect build grades.

Formulas and tactical assumptions are in [Strategy](STRATEGY.md). Repository working rules are in [AGENTS.md](https://github.com/ThomasMarcelis/bro-ledger-mod/blob/main/AGENTS.md).

## Local setup

Required tools are Git, CMake, a C/C++ compiler, Python 3, and Node.js 22 or later. No npm installation is needed.

Build the pinned Squirrel 3.2 runner inside the ignored `.tools/` directory:

```sh
mkdir -p .tools/src
git clone https://github.com/albertodemichelis/squirrel.git .tools/src/squirrel
git -C .tools/src/squirrel checkout f92bc298784ceea459b12e2de33bdff672bfeb83
cmake -S .tools/src/squirrel -B .tools/src/squirrel/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build .tools/src/squirrel/build --target sq_static --parallel
cp .tools/src/squirrel/build/bin/sq_static .tools/sq
cp .tools/src/squirrel/COPYRIGHT .tools/SQUIRREL-COPYRIGHT
```

The game uses Squirrel 3.0.4 with 32-bit integers and floats; the local 3.2 runner is a behavioral aid, not the game VM.

Download `mod_msu-1.9.0.zip` from [MSU's releases](https://github.com/MSUTeam/MSU/releases/tag/1.9.0) to `.tools/mod_msu-1.9.0.zip`. `tools/check.py` verifies the hash listed in [Third-party notices](../THIRD_PARTY.md) before extracting its settings and tooltip test fixture. Dependencies stay in ignored `.tools/` and never enter the player ZIP.

## Checks and packaging

```sh
python3 tools/check.py
python3 tools/package.py
```

Checks cover Squirrel behavior, MSU settings/tooltips, Node UI behavior, and JavaScript syntax. When changing behavior, add the smallest useful proof of the scenario: allocation, grading, normalization, legal routes, plan continuity, validation, stale callbacks, settings, or current effects. Avoid tests that only pin prose, CSS, or DOM structure.

Packaging creates a deterministic `dist/mod_bro_ledger-<version>.zip` containing original runtime files, README, license, notices, and the two guides in `docs/`. Inspect its contents and printed SHA-256 before distribution. Tests, tools, game assets, dependencies, saves, and private evidence are excluded. `python3 tools/package.py --audit` also builds a separate observer ZIP for gameplay-mutation and RNG checks in a disposable campaign; it is not part of the player download.

## In-game acceptance

With foreground game control authorized, use the installed Steam edition and a copy of a non-Ironman campaign. Preserve original saves, prevent Cloud writeback, and keep saves and captures out of Git.

1. Install the candidate with the pinned dependencies and no older Bro Ledger ZIP. Record the game, platform, UI scale, and complete mod stack.
2. Evaluate several brothers and inspect all 44 builds, Role/Weapon filters, hybrid membership, empty results, mastery notes, and the disclosed weapon comparisons. Cancel a preview, track a build, switch brothers, and confirm the chosen intent follows the correct actor.
3. Exercise native perk confirmation, level-up offers, equipment changes, Stash/Perks tabs, tooltips, Disable/re-enable, and Change build. Confirm planner actions never spend, equip, or rename.
4. Save, quit, reload, and verify new revision-3 schema-2 plans, saved revision-2 mixed builds, and available schema-1 plans without automatic migration. Repeat across combat/world transitions and character-sheet reopenings.
5. Remove the Bro Ledger ZIP, load/play/save/reload the test copy, reinstall it, and confirm compatible intent returns.
6. Inspect the UI at 1920×1080, 2560×1440, and 1600×900 where available. Record clipping, input failures, game-log errors, and any untested scenario.

Record commands, versions, results, and gaps in ignored `.local/`. Automated checks cannot establish game-VM behavior, UI fit, save safety, or platform support. Until the full checklist is verified on a declared baseline, publish only as an unverified prerelease.
