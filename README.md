# Bro Planner

A native Battle Brothers build board, weighted evaluator, and per-brother tracker. Open a brother and select **Bro Planner** to compare starter templates and your campaign's builds, then deliberately track one. Every gameplay choice remains yours: the mod never spends points, equips items, switches builds, renames brothers, or generates future rolls.

**0.5.1 is an unverified prerelease.** Automated checks and native browser fixtures provide supporting evidence. The complete in-game player loop, clipboard success, save/removal/reinstall lifecycle, and Windows/Proton compatibility remain unverified.

## Install

The development baseline is Battle Brothers **1.5.2.3 with all DLC**, [Modern Hooks](https://github.com/MSUTeam/Modern-Hooks) **0.6.0+**, and [MSU](https://github.com/MSUTeam/MSU) **1.9.0+**. Dependencies are installed separately. Other versions and UI mods have not been verified.

[Download mod_bro_ledger-0.5.1.zip](https://github.com/ThomasMarcelis/bro-ledger-mod/releases/download/v0.5.1/mod_bro_ledger-0.5.1.zip), or build it locally with `python3 tools/package.py`. With the game closed, place the ZIP in its `data/` folder **without extracting it**. Keep only one planner ZIP and restart the game fully after updating. The technical ID and ZIP prefix remain `mod_bro_ledger` to preserve save identity.

To remove, close the game and remove the ZIP. Namespaced plans and the campaign library are intended to remain dormant for a compatible reinstall; verify this lifecycle on a save copy before relying on it. Back up your saves before trying the candidate.

## Create, compare, and share

Ten **Starter** templates are immediately available. These original examples of common community archetypes **may be suboptimal**; use them as starting guides and adjust them to your brothers and playstyle. They cover shield tank, nimble frontliner, forged two-hander, fatigue neutral, cleaver/whip, sword duelist, thrower, archer, crossbow/polearm hybrid, and banner sergeant.

Track a starter directly, or select **Copy & edit** to make a personal draft. Saving adds the copy to your library; Cancel leaves the template and library unchanged. Built-in templates cannot be edited or deleted and do not consume the personal library's 32 slots.

**Create build** opens the board: name, **Attributes Ranges**, weights, native perk tree, acquisition order, flexible picks, and weapon/equipment and playstyle tags. Minimum and Ideal allow 0–500 with two decimal places. Leave a range pair blank to omit that attribute. **Weight** is a whole number from 0–10: 2 counts twice as much as 1; 0 ignores the attribute while retaining its range. Builds with no weighted targets are unrated.

Checked **Flexible** means the suggested perk can yield to an off-route perk you learn manually. Unchecked means mandatory. Move picks with Up/Down; routes must respect native unlocks and the ten-point budget (eleven picks with Student). Long perk orders scroll independently, keeping the build name, order heading, and Save/Cancel controls visible. Adding or moving a perk keeps it in view; other editor fields scroll separately when needed.

**Potential** is the best weighted average of capped target satisfaction from one legal shared allocation at average rolls. Higher weights have more influence; excess above Ideal contributes nothing. An overall 50 does not mean every Minimum is met. Scores measure creator-defined target fit, not combat power or win probability. Comparison shows ten matches per page, with every remaining match reachable through Next/Previous. Weapon, Playstyle, and Source filters combine; Source separates My builds and Starters.

Your personal library belongs to **this campaign's save**. Save the campaign to retain edits. Names allow 40 UTF-8 bytes. Editing or deleting a library build leaves tracked brothers' snapshots intact; deliberately track the edited build again to apply new ranges or weights.

**Import** accepts old `BL1` and weighted `BL2` share text. Paste manually or use **Paste clipboard**, then select **Import builds**. A failed clipboard read retains your text. Imports commit together; duplicate IDs or names are rejected unless you choose **Skip duplicates** or **Import copies**. **Export** shares a selected build or starter; **Export my builds** shares only your personal library. Copy the output with Ctrl+C. There is no network service.

## Follow a saved plan

**Track build** saves an independent definition to that brother. The attached panel shows Ideal progress, perk order, and current learned Dodge, Nimble, and Battle Forged contributions. Green goals are met; yellow goals need development; red goals exceed a proven individual maximum within the displayed horizon. A separate message identifies competing goals. Weight-zero goals are marked Ignored. Natural stats exclude equipment and perk multipliers; the native sheet keeps its effective stats and ordinary perk confirmation.

Visible-roll advice uses the same weights. If fewer than three attributes are targeted, fill the remaining choices manually. **Disable** retains a dormant plan; **Re-enable plan** restores it. **Change build** deliberately replaces it. Older saved plans retain their data and use equal weights until deliberately replaced. Unknown saved schemas stay untouched.

**Saved perk alternatives** belong to older plans. For example, **Replace Rotation with Pathfinder** changes that future pick in saved guidance; the reverse action restores Rotation. It does not learn, refund, or spend a perk.

Mod Options controls the planner, perk highlights, and level-up advice. Close and reopen the sheet after changing settings. If a request fails, use the visible **Retry** control.

[Strategy](docs/STRATEGY.md) explains scoring and its limits. [Development](docs/DEVELOPMENT.md) covers ownership and verification. Original code, templates, and documentation are [MIT licensed](LICENSE); see [Third-party notices](THIRD_PARTY.md). Report reproducible issues with game/mod versions, platform, resolution, and UI scale through [GitHub Issues](https://github.com/ThomasMarcelis/bro-ledger-mod/issues).
