# Bro Ledger repository instructions

Bro Ledger is a small, solo-maintained native Battle Brothers evaluator and per-brother build tracker. The product owner decides behavior and publication; the supervisor escalates real ambiguity; Codex owns implementation judgment within the settled scope. [Development](docs/DEVELOPMENT.md) defines architecture and invariants. [Strategy](docs/STRATEGY.md) defines grading and tactical assumptions.

## Product boundary

The player loop is: open a brother → Evaluate → create/import and compare community builds → deliberately track one → follow saved perk and stat guidance with current learned effects through ordinary manual play.

- Target vanilla mechanics with all DLC. Modern Hooks and MSU are required; compatibility claims need evidence.
- Squirrel owns evaluation, guidance, community definition validation, and persistence. JavaScript/CSS only present results and relay actions.
- Preserve the native sheet, roster, stash, controls, and acquired/locked perk readability.
- Never choose builds, spend points, equip items, rename brothers, reveal future rolls, advance RNG, or simulate by mutating a live actor.
- Read safe live objects and definitions. Keep only versioned strategy and bounded source-backed hypothetical calculations.
- Persist namespaced intent, not duplicate live state. Disable retains dormant intent; Change build is separate. Preserve unknown future schemas unchanged.
- Distribute only work covered by this repository's MIT license. Do not redistribute game assets, decompiled source, dependencies, saves, or private captures.

## Engineering

- Prefer one direct implementation per behavior. Do not add speculative abstractions, a second evaluator, a plugin framework, server, database, telemetry, or compatibility layer.
- Keep state and mutation at the owning boundary. Fix root causes. Add a dependency or layer only for a demonstrated need.
- State the invariant or scenario, write the smallest useful proof, implement, and verify. Keep tests focused on finite choices, normalization, legal routes, payload validation, plan continuity, settings, and stale callbacks.
- Avoid tests for static copy, CSS, or DOM structure. Do not retain historical suites as release gates when they duplicate stronger behavior checks.
- Substantial code changes require three independent final-diff reviews in parallel: correctness/architecture, simplicity/ownership, and changed-line value. Resolve material findings, subtract unnecessary work, and rerun proportionate checks. Documentation-only work does not require this ceremony.
- Keep maintained docs small. Store temporary status, plans, questions, evidence, tools, dependencies, saves, captures, and generated output only in ignored paths.

## UI

Use the game's visual language and controls. Keep text readable and structure obvious. Do not squeeze content to satisfy a viewport measurement. Source-derived geometry remains a hypothesis until rendered in game.

## Authorization

Research, repository-local edits and tooling, tests, packaging, and local commits are authorized. Other repositories, installed game files, and source snapshots are read-only evidence.

Runtime preparation may inspect the installed Steam edition and copy relevant saves for testing. Preserve originals byte-for-byte, prevent Cloud writeback, and keep private data out of Git and releases. Use the existing Steam client/session; do not create another installation or isolation framework. **The current owner restriction prohibits foreground game launch, input, or capture until explicitly lifted.** This restriction does not block independent code, tests, packaging, or read-only preparation.

Ask before creating or pushing a public repository, publishing a release, contacting suppliers or other people, making purchases, changing global/system configuration, changing the installed mod stack, or overwriting an original save. Stop at account or licensing barriers; never copy credentials.

Use ordinary reversible engineering judgment. Escalate product ambiguity, disputed strategy, scope changes, rights questions, or permission boundaries. If a decision is needed, record it briefly in ignored `questions.md` and continue independent work.

## Evidence and completion

Record exact commands, results, versions, and remaining gaps privately. Standalone Squirrel tests, source inspection, fixtures, and ZIP creation do not prove in-game fit, lifecycle safety, or platform compatibility.

A verified release requires the complete player loop, access to every library match, manual-choice updates, current learned effects, and campaign/library/plan save and ZIP removal/reinstall lifecycle on the declared baseline. Publish only as an unverified prerelease when runtime evidence is missing.
