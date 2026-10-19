# Bro Planner

Plan a brother's perks and stats in-game, see how well a build fits them, then get guided on which perks and level-ups to pick. Comes with 10 starter builds and lets you copy/paste builds with other players as text.

[Nexus Mods](https://www.nexusmods.com/battlebrothers/mods/1188) · [GitHub](https://github.com/ThomasMarcelis/bro-ledger-mod) · [MIT](LICENSE)

The mod only advises. It never spends points, equips items, or changes your brothers.

## Install

Requires Battle Brothers 1.5.2.3 with all DLC, [Modern Hooks](https://github.com/MSUTeam/Modern-Hooks) 0.6.0+ and [MSU](https://github.com/MSUTeam/MSU) 1.9.0+.

1. Download the ZIP from [Nexus Mods](https://www.nexusmods.com/battlebrothers/mods/1188?tab=files) or [GitHub Releases](https://github.com/ThomasMarcelis/bro-ledger-mod/releases), or build one with `python3 tools/package.py`.
2. Close the game and drop the ZIP into `data/`. Don't extract it. Keep only one planner ZIP.
3. Restart the game fully.

To remove, delete the ZIP. Your library and tracked plans are left in place for a reinstall.

**1.2.0 is an unverified prerelease.** Free perk order, Copy & edit, the pre-0.7 cleanup and 1.1.0's scoring redesign pass standalone checks. 1.1.0 also passed browser preflight at 1920×1080, 2560×1440, 1600×900 and 1280×800; 1.2.0's editor changes have not had a fresh rendered check. Neither verifies the game VM or real game transport; in-game player-loop and save/removal/reinstall validation remain pending. Earlier 1.0.1 live and Steam Deck layout evidence does not certify this version.

**Since 1.1.0, scoring uses Goal gap for all builds and saved plans.** Weights value progress in fixed ordinary-roll units toward Ideal; Minimum breaks exact ties instead of marking half satisfaction. Saved numbers and plans remain intact, but forecasts, advice and ranking can change. Review your tracked goals when upgrading from 1.0.x. BL1/BL2 text remains readable; versions before 1.1.0 score the same text differently.

## Use

Open a brother and select **Bro Planner**.

**Builds.** A build is a name, Minimum/Ideal targets with 0–10 weights per attribute, a perk order, and weapon/playstyle tags. Ten **Starter** builds are included: shield tank, nimble frontliner, forged two-hander, fatigue neutral, cleaver/whip, sword duelist, thrower, archer, crossbow/polearm hybrid, banner sergeant. Track one directly, or **Copy & edit** any build, starter or your own, to make a variant. Starters may be suboptimal, so tune them to your company.

**Perk order.** List perks in any order and skip earlier tiers freely: the order is your priority, and the picks needed to reach a later tier are **filler picks**, any perks you like (flexible ones count). A brother has 10 perk points, or 11 when the build includes Student. The editor and the character sheet warn when the mandatory perks plus fillers don't fit, but never stop you saving. Mark a perk **Flexible** to keep it as an alternate that yields to whatever you learn manually. Up to 20 perks in total. Hover a perk for its description.

**Compare.** **Goal gap** ranks remaining weighted Ideal shortfall after one legal allocation at average rolls. Lower is closer; zero means the Ideals fit. Weights use a shared 0–10 importance scale; weighted shortfall is divided by a fixed 10. Completed goals add no gap. Scaling every weight equally preserves stat choices but scales the gap and can change cross-build ranking. Inspect the Minimum/Ideal rows: this measures proximity to creator goals, not combat power. The **Potential** stat column shows that allocation. Colossus and Fortified Mind count: acquired perks raise current HP/Resolve; planned perks raise the forecast and carry a perk mark. Perk-route conflicts remain separate. Filter by weapon, playstyle and source. Ten results per page.

**Track.** **Track build** saves a snapshot to the brother. The character sheet then shows progress per goal (green met, yellow in progress, red unreachable), the perk route, current Dodge/Nimble/Battle Forged contributions, and rates level-up rolls by the build's weights. **Disable** pauses a plan, **Re-enable** restores it, **Change build** swaps it. Collapse the sheet panel to free space for other mods' controls; that choice is per brother and survives a restart. Editing a library build doesn't change tracked brothers; track it again to update them.

**Share.** **Export** copies one build, or **Export my builds** for all, as text; Ctrl+C to copy. **Import** accepts BL2 text, and BL1 text from Bro Ledger 0.4, pasted or via **Paste clipboard**. Builds that skip tiers or exceed the point budget need 1.2+ to import. Duplicates are rejected unless you choose **Skip duplicates** or **Import copies**. Nothing goes over the network.

**Library.** Up to 32 personal builds, stored with your MSU mod settings and shared across campaigns. Upgrading from before 0.7: with 1.1.0 installed, load each old campaign, open **Bro Planner** on any brother and check its builds now appear (or export them). 1.2 no longer reads builds stored inside a campaign. Plans tracked before 0.5 can't be read either; those brothers show a notice to track a build again.

**Settings.** Mod Options toggles the planner, perk highlights and level-up advice. Turn off **Show starter builds** to compare only personal builds; copies and tracked plans are kept. Turn off **Show current perk effects** to hide the Dodge, Nimble and Battle Forged readouts. Both default to on. Reopen the sheet after changing settings. If a request fails, use **Retry**.

## More

- [Strategy](docs/STRATEGY.md): how scoring and guidance work, and their limits.
- [Development](docs/DEVELOPMENT.md): architecture, limits, checks and verification.
- See [Third-party notices](THIRD_PARTY.md). Report issues with game/mod versions, platform, resolution and UI scale on [GitHub Issues](https://github.com/ThomasMarcelis/bro-ledger-mod/issues).
