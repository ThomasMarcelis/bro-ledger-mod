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

0.7.0 is an unverified prerelease. It passes automated tests but has not been checked in a full in-game loop or on Windows/Proton. Back up your saves.

## Use

Open a brother and select **Bro Planner**.

**Builds.** A build is a name, Minimum/Ideal targets with 0–10 weights per attribute, a perk order, and weapon/playstyle tags. Ten **Starter** builds are included: shield tank, nimble frontliner, forged two-hander, fatigue neutral, cleaver/whip, sword duelist, thrower, archer, crossbow/polearm hybrid, banner sergeant. Track one directly or **Copy & edit** it. They may be suboptimal, so tune them to your company.

**Perk order.** Mandatory perks must fit a brother's points (10, or 11 with Student) and respect unlock tiers. Mark a perk **Flexible** to keep it as an alternate that yields to whatever you learn manually. Flexible perks sit on top of the budget, up to 20 perks in total. Hover a perk for its description.

**Compare.** **Potential** scores how well a brother can satisfy a build's weighted targets with one legal allocation at average rolls. It measures fit to the creator's targets, not combat power. Filter by weapon, playstyle and source. Ten results per page.

**Track.** **Track build** saves a snapshot to the brother. The character sheet then shows progress per goal (green met, yellow in progress, red unreachable), the perk route, current Dodge/Nimble/Battle Forged contributions, and rates level-up rolls by the build's weights. **Disable** pauses a plan, **Re-enable** restores it, **Change build** swaps it. Editing a library build doesn't change tracked brothers; track it again to update them.

**Share.** **Export** copies one build, or **Export my builds** for all, as text; Ctrl+C to copy. **Import** accepts BL1/BL2 text, pasted or via **Paste clipboard**. Duplicates are rejected unless you choose **Skip duplicates** or **Import copies**. Nothing goes over the network.

**Library.** Up to 32 personal builds, stored with your MSU mod settings and shared across campaigns. Builds saved inside a campaign by older versions are moved over once when that campaign loads.

**Settings.** Mod Options toggles the planner, perk highlights and level-up advice. Turn off **Show starter builds** to compare only personal builds; copies and tracked plans are kept. Turn off **Show current perk effects** to hide the Dodge, Nimble and Battle Forged readouts. Both default to on. Reopen the sheet after changing settings. If a request fails, use **Retry**.

## More

- [Strategy](docs/STRATEGY.md): how scoring and guidance work, and their limits.
- [Development](docs/DEVELOPMENT.md): architecture, limits, checks and verification.
- See [Third-party notices](THIRD_PARTY.md). Report issues with game/mod versions, platform, resolution and UI scale on [GitHub Issues](https://github.com/ThomasMarcelis/bro-ledger-mod/issues).
