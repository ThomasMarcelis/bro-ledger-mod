# Bro Ledger

A Battle Brothers mod for comparing builds and keeping a plan for each brother. It appears in the character sheet as **Bro Build Planner**.

Choose **Evaluate**, compare 44 builds, and track the one you want. The plan stays with that brother as you level him and change his equipment. You make every gameplay choice: the mod never spends points, equips items, renames brothers, or chooses builds for you. It does not reveal future rolls or advance the game's random state.

**0.2.0 is an unverified prerelease.** Automated checks pass, but the complete in-game loop, UI fit, save/removal/reinstall lifecycle, and Windows/Proton compatibility still need testing. Back up your saves before trying it.

## Install

The development baseline is **Battle Brothers 1.5.2.3 with all DLC**, [Modern Hooks](https://github.com/MSUTeam/Modern-Hooks) **0.6.0+**, and [MSU](https://github.com/MSUTeam/MSU) **1.9.0+**. Other versions and UI mods have not been verified. Dependencies are installed separately.

1. Close the game and install Modern Hooks and MSU using their maintainers' instructions.
2. Download **`mod_bro_ledger-0.2.0.zip`** from the [0.2.0 prerelease](https://github.com/ThomasMarcelis/bro-ledger-mod/releases/tag/v0.2.0). Choose this asset, not GitHub's source-code archive.
3. Put the ZIP, **without extracting it**, in your Battle Brothers `data/` folder. Keep only one Bro Ledger ZIP there, then restart the game fully.

To update, replace the old Bro Ledger ZIP while the game is closed. Saved plans retain their names, routes, targets, and options; **Change build** adopts a current build. To remove the mod, close the game and remove its ZIP. Plans are stored in namespaced brother flags for a compatible reinstall; that lifecycle remains unverified. Keep dependencies that other mods still need.

## Use

Open a company brother and select **Evaluate**. Filter by **Role** or **Weapon**; hybrids match either weapon. Select a build to see its targets, ten-perk route, mastery rationale, and equipment advice. **Track build** saves your choice. Closing or cancelling the comparison leaves the saved plan alone.

The attached panel follows the brother's attributes, perks, and equipment:

- **Now** grades current role fit; **Potential** includes remaining growth. Neither ranks weapon strength or company composition.
- **Projected** stats share three distinct attribute picks per level. They are one achievable average-roll allocation; expand **Forecast allocation** to see the picks. **Minimum** and **Ideal** show the build's targets.
- Level-up advice recommends three of the actual offered rolls.
- Green perk marks show the tracked route; blue marks show flexible choices and alternatives. The game's normal confirmation still controls spending.
- Equipment advice explains conditional weapon choices and fatigue/armour budgets. Learned Dodge, Nimble, and Battle Forged effects show their current contribution.

**Disable** hides one brother's guidance while keeping his plan. Reopen **Evaluate** and use **Re-enable plan** to restore it. **Change build** replaces it.

Under **Mod Options → Bro Build Planner**, you can toggle the planner, perk highlights, level-up recommendations, and equipment advice. All start enabled; turning them off retains saved plans. Close and reopen the character sheet after changing settings. A campaign's saved settings can override startup preferences.

## Details and feedback

[Strategy](docs/STRATEGY.md) explains grades, all 44 builds, and calculation limits. [Development](docs/DEVELOPMENT.md) covers architecture, tests, packaging, and acceptance checks.

Report problems through [GitHub Issues](https://github.com/ThomasMarcelis/bro-ledger-mod/issues) with reproduction steps, game/mod versions, platform, and other installed mods. For layout issues, include resolution and UI scale. Remove personal information from log excerpts.

Original code and documentation are [MIT licensed](LICENSE). Battle Brothers and the required frameworks remain their owners' work; see [Third-party notices](THIRD_PARTY.md).
