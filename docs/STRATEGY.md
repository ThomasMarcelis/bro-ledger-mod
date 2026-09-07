# Strategy and calculations

The catalog has 44 builds, each with a ten-perk plan (definitions revision 3). Grades measure how well a brother fits a role's targets. A high grade does not tell you which weapon is strongest or what your company needs.

## Stat basis and growth

Targets use natural attributes before equipment, Colossus, Fortified Mind, and Dodge. They include permanent base gains, lasting trait/origin changes, and permanent injuries. Temporary damage, morale, accumulated fatigue, repair condition, and situational combat bonuses do not affect grades.

Natural Initiative follows the native relationship with Stamina: after Initiative multipliers, subtract `max(0, base Stamina - lasting additive Stamina)`, then apply native final rounding. Equipment and accumulated fatigue remain excluded from Potential.

Growth uses the game's level-up ranges and visible talent stars, with exactly three distinct attributes per remaining row. The allocation covers normal rows, earned veteran `+1` rows, and one maximum-roll Gifted row if the route can still obtain it. Future offers are never read or created.

The ordinary horizon is level 11 or the current veteran level, whichever is higher. Manhunters Indebted stop at level 7. Student adds a future refunded perk point only when its native refund has not happened. If a pending row could be either Gifted or ordinary after load, Potential remains unknown until visible history distinguishes it; current offered rolls can still be advised.

**Projected at level …** shows one achievable average-roll allocation. It first preserves an allocation that supports the best feasible grade, then spends remaining picks toward Minimum, Ideal, and saved priority. All eight attributes appear; a dash means the build has no target for that stat. Expand **Forecast allocation** to see each attribute's ordinary, veteran, and Gifted picks.

## Grades

Potential uses the same finite allocation for every required attribute:

| Grade | Meaning |
| --- | --- |
| S | Expected growth can meet every Ideal target. |
| A | Expected growth can meet each Minimum/Ideal midpoint; Ideal-only support targets meet Ideal. |
| B | Expected growth can meet every Minimum. |
| C | Minimum needs better-than-average growth but remains optimistically feasible. |
| D | At least one Minimum is not optimistically feasible, or the perk route is incompatible. |
| F | At least two Minimum targets are individually unreachable. |
| ? | Required stats, growth, spent-point counts, or legacy Ideals are unknown or inconsistent. |

Each required attribute matters; a surplus elsewhere cannot offset a shortfall. **Now** uses the same bands without future rows, so talents do not change it. An incompatible route caps both known grades at D. Tempo Shield Spear, Sword, and Flail are stopgaps: they use the same grades but cannot be preferred endgame roles.

Current-offer advice evaluates all 56 ways to choose three of eight visible rolls. It preserves Minimum feasibility first, then improves Minimum progress, Ideal feasibility and progress, and saved priority. It never spends the points.

## Perk plans and role selection

Acquired perks are never refunded. Colossus, Gifted, Pathfinder, Nine Lives, Steel Brow, Fortified Mind, and Recover can fill declared flexible slots within the ten-point budget. Gifted is retained when another unacquired flex slot can absorb a support perk, because only Gifted adds projected stats. Acquiring Mace Mastery cannot turn an Axe build into a Mace build; an unrelated mastery stays off-plan. Older plans use their saved mastery options.

The catalog uses pure Nimble or Battle Forged strategies, so the opposite armour perk conflicts with the plan. Refreshing guidance uses a copy and cannot rewrite the saved route, targets, replacements, or revision. Only **Track build** or **Change build** stores a new plan.

Schema-2 plans snapshot Minimum and Ideal targets. Schema-1 plans remain unchanged: matching revision and Minimum targets can use the current Ideals; otherwise grades stay unknown while Minimum guidance continues. Unsupported future schemas remain untouched.

Preferred endgame roles must have known, legal B-or-better fit. Among eligible builds, acquired perks that define a build take priority, followed by grade. Ties stay visible: the mod cannot infer company needs, enemies, or positioning from a recruit.

Comparison order is grade `S, A, B, C, D, F, ?`, then endgame before stopgap, preferred roles before alternatives, and stable build-ID order. Sorting never changes the tracked build.

## Equipment advice

Advice reads live items and skills, retaining named-item modifiers and current action costs. Future loadouts use the catalog's limited action examples, not an inventory or combat simulation.

### Fatigue and armour

For action cost `C`, recovery `R`, turns `T`, and reserve `B`, required capacity from rest is:

```text
C + max(0, C - R) × (T - 1) + B
```

The armour budget removes current head/body stamina costs from live capacity. Weapons, shields, ammunition, bags, and other modifiers remain counted by the game. Body stamina modifiers use floor after Brawny; helmet modifiers use ceil. Nimble uses raw armour weight and is not reduced by Brawny. Battle Forged has no universal armour cap.

### Current perk effects

Learned-perk effects use live native values:

- Dodge defence: `max(0, floor(current Initiative × 0.15))`.
- Nimble HP damage reduction: `100 × (1 - acquired Nimble chance)`.
- Battle Forged armour damage reduction: `(remaining head armour + remaining body armour) × 0.05` percentage points; 500 total armour gives 25%.

`Not learned`, an unreadable effect, and an owned zero effect remain distinct. Displayed percentages round to the nearest tenth. These values describe the individual perk's current contribution, not combined protection or future equipment.

### One-handed weapon comparisons

Comparisons enumerate independent uniform integer regular/armour rolls for eight ordinary attacks. The reference loadout holds a shield, has no offensive perks or trait modifiers, and targets the body against 10 defence without an enemy shield or other hit modifiers. Body armour is 0 for unarmoured living targets and 100 for armoured living targets and Ancient Dead. Ancient Dead apply their racial HP multiplier to Thrust, not to armour damage. These hypothetical matchups do not describe the next enemy or your equipped weapon.

Hit chance is `clamp(natural Melee Skill + attack bonus - defence, 5, 95)%`. Armour damage is capped at available armour with native integer `Math.min`; penetrating HP loses 10% of the armour remaining after that hit. When armour breaks, the non-penetrating part subtracts armour removed with integer `Math.max` before the final native HP rounding. Batter retains its minimum 10 HP. Expected damage includes misses. The UI shows all winning integer-skill intervals from 0 through 150 against Fighting Spear for immediate HP damage, alongside armour removal and base/mastered fatigue. All compared attacks cost 4 AP. Armour resets between examples; this does not calculate attacks to kill.

Under the stated unarmoured conditions, Arming Sword first exceeds Fighting Spear at 78 natural Melee Skill; Noble Sword does so at 38. These are conditional crossovers, not universal equip thresholds. Headshots, shields/Shieldwall, armour, Double Grip, Duelist, trait effects, mastery, bleed, control, morale, and subsequent attacks can change the decision. The player chooses the weapon, build, and company composition. An S spear fit does not make a company of spearmen an optimal late-game composition.

## The 44 builds

Each build has Minimum/Ideal targets, a legal ten-perk route, mastery rationale, and action examples. Shared requirements can produce equal grades. Hit bonuses do not automatically reduce Melee Skill targets: defensive tanks need no offensive target, Spearwall needs accuracy and fatigue, and pure ranged/ranged hybrids need no melee target. All builds use Nimble unless named Battle Forged.

| Job | Builds |
| --- | --- |
| Defensive tank (2) | Nimble; Battle Forged. Utility spear/dagger is equipment, not another route. |
| Shield fighter (6) | Tempo Spear; Tempo Sword; Tempo Flail; Mace control; Hammer armour breaker; Spearwall. |
| Two-handed (8) | Nimble Axe, Mace, Greatsword, Flail, Cleaver; Battle Forged fatigue-neutral Axe/Mace; Battle Forged Hammer flank. |
| Duelist (6) | Sword; Axe; Mace; Hammer; Cleaver; Flail. |
| Specialist (7) | Qatal; Puncture Dagger + Shield; Fencer; Estoc Skewer; Estoc Perforate; Pollaxe; Executioner's Sword. |
| Backline (3) | Billhook; Swordlance/Reaper; Banner. |
| Ranged (4) | Bow; Crossbow; Thrower; Handgonne. |
| Hybrid (8) | Bow + Throwing; Crossbow + Throwing; Crossbow + Billhook; Handgonne + Throwing; Throwing + 2H Mace; Banner + Throwing; 2H Mace + Qatal; 2H Cleaver + Whip. |

Javelins and throwing axes share a route but suit different enemies. Reach backups, bucklers, item tiers, and famed weapons are equipment choices within builds.

Tempo Spear/Sword and defensive tanks skip weapon mastery. Spearwall, Flail attacks, Mace stuns and Hammer armour removal justify different investments. Estoc uses Dagger Mastery, Pollaxe uses Polearm Mastery, and Executioner's Sword uses Sword Mastery. Execution adds headshot chance, not Greatsword's accuracy or flat damage bonus. Skewer values current Initiative; Perforate values existing temporary injuries. Those conditions are not guaranteed by a recruit's grade.

Action examples distinguish ordinary turns from setup and bursts. Mastered fatigue costs round up. Dagger/Polearm AP reductions and gun reload apply only to their actual skills. Mace + Qatal is a 6+3 AP burst starting with the mace; it needs preparation before repeating because Quick Hands gives one free eligible swap per turn. Crossbow + Billhook alternates shot/strike and strike/reload turns. A bagged second gun starts unloaded. Swapping away from the banner removes its aura; swapping weapons loses Reach Advantage stacks. Spears/swords help early accuracy, while bows, bolts, javelins, thrusts and other piercing attacks have different Ancient Dead HP penalties. Damage, armour removal and control remain separate tactical values.

## Evidence boundary

Mechanics were checked against Steam build 23856902 (Battle Brothers 1.5.2.3): player/actor logic, Manhunters, lasting traits and injuries, armour updates, and the catalog's active skills. Public references include [Talents](https://battlebrothers.fandom.com/wiki/Talents), [Gifted](https://battlebrothers.fandom.com/wiki/Gifted), [Student](https://battlebrothers.fandom.com/wiki/Student), [Hit Chance](https://battlebrothers.fandom.com/wiki/Hit_Chance), [Dodge](https://battlebrothers.fandom.com/wiki/Dodge), [Nimble](https://battlebrothers.fandom.com/wiki/Nimble), and [Battle Forged](https://battlebrothers.fandom.com/wiki/Battle_Forged).

The June 2026 additions were cross-checked against the [official update](https://steamcommunity.com/games/365360/announcements/detail/694264313911708073), [turtle225's current mechanics/perk guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2001196860), and the [Damage reference](https://battlebrothers.fandom.com/wiki/Damage). Public descriptions can lag the installed skills. Integer rounding was checked against the installed damage closure in an isolated fixture; native Math bindings and full runtime behaviour still need the game baseline.

Targets, perk routes, reserves, identity choices, and reference matchups are versioned strategy judgments. Source inspection and standalone tests do not certify exact game-VM behavior or tactical outcomes.
