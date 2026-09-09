# Bro Ledger

A native Battle Brothers build board, evaluator, and per-brother tracker. Open a brother and select **Evaluate** to manage your campaign's build library, compare Potential fit, and deliberately track a build. You make every gameplay choice; the mod never spends points, equips items, switches builds, renames brothers, or generates future rolls.

**0.4.8 is an unverified prerelease.** Automated behavior checks and browser fixtures provide supporting evidence. Native clipboard success, the complete in-game player loop, save/removal/reinstall lifecycle, and Windows/Proton compatibility remain unverified. Back up your saves before trying it.

## Install

The development baseline is Battle Brothers **1.5.2.3 with all DLC**, [Modern Hooks](https://github.com/MSUTeam/Modern-Hooks) **0.6.0+**, and [MSU](https://github.com/MSUTeam/MSU) **1.9.0+**. Dependencies are installed separately. Other versions and UI mods have not been verified.

Download [**mod_bro_ledger-0.4.8.zip**](https://github.com/ThomasMarcelis/bro-ledger-mod/releases/download/v0.4.8/mod_bro_ledger-0.4.8.zip) from the [0.4.8 prerelease](https://github.com/ThomasMarcelis/bro-ledger-mod/releases/tag/v0.4.8), or build locally with `python3 tools/package.py`. With the game closed, place the ZIP in its `data/` folder **without extracting it**. Keep only one Bro Ledger ZIP and restart the game fully after updating.

To remove, close the game and remove the ZIP. Namespaced plans and the campaign library are intended to remain dormant for a compatible reinstall; verify this lifecycle on a save copy before relying on it.

## Create, compare, and share

The library starts **empty**. No tactical builds or starter targets are bundled.

**Create build** opens the board: name, eight Minimum/Ideal pairs, perks, creator order, flex picks, and multiple weapon/equipment and playstyle tags. Leave both inputs blank to deliberately omit a stat. Unchecked **F** means mandatory; checked **F** means the suggested perk can yield to a manual off-route acquisition. Reorder with Up/Down. The route must respect native perk unlocks and the ten-point budget (eleven picks with Student).

The picker follows the native perk-tree order with centered tiers and circular selection. Creator acquisition order is edited separately. If Evaluate encounters a request failure, use its visible **Retry** control.

The library holds up to 32 builds **in this campaign's save**. Save the campaign to retain edits. It is not an account-wide library. Editing or deleting a library build leaves tracked brothers' snapshots intact. Names allow 40 UTF-8 bytes; targets allow 0–500 with up to two decimal places.

**Import** accepts a single or bulk `BL1` text string. Click **Paste clipboard** to replace the field, or paste manually, then select **Import builds**. If clipboard paste fails, your existing text is retained. Imports apply together. Duplicate IDs or names are rejected by default; explicitly choose **Skip duplicates** or **Import copies** to handle them. **Export** shares one selected build; **Export all** shares the entire library. Select the output text and press Ctrl+C. There is no network service.

Comparison sorts by **Potential** only and presents ten matches per page when available. Every remaining match is reachable with Next/Previous. Weapon and Playstyle filters match every selected tag. Click either filter for in-page choices; **All** clears that filter and **Close** dismisses the choices. A build with no stat targets is unrated. Fit measures creator-defined targets, not combat power or win probability.

**Track build** saves the selected definition to that brother. The attached panel shows Ideal progress, creator perk order, and current learned Dodge, Nimble, and Battle Forged contributions. Green goals are met; yellow goals need development; red goals exceed a proven individual maximum within the shown level horizon. A separate message identifies competing goals that cannot all share the available picks. Natural stats exclude equipment and perk multipliers. The native sheet retains its effective stats and normal perk confirmation.

**Disable** retains a dormant plan. **Evaluate → Re-enable plan** restores it. **Change build** deliberately replaces it. Legacy plans retain their saved routes, targets, and options; legacy perk alternatives remain available through Change build. Unknown saved schemas stay untouched.

Mod Options toggles the planner, perk highlights, and advice for the actual offered level-up rolls. Close and reopen the sheet after changing settings. Current effects distinguish an unlearned perk (—), an unreadable value (?), and an owned zero.

[Strategy](docs/STRATEGY.md) documents the formula and its limits. [Development](docs/DEVELOPMENT.md) covers ownership, tests, and acceptance. Original code and documentation are [MIT licensed](LICENSE); see [Third-party notices](THIRD_PARTY.md). Report reproducible issues with game/mod versions, platform, resolution, and UI scale through [GitHub Issues](https://github.com/ThomasMarcelis/bro-ledger-mod/issues).
