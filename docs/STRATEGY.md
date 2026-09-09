# Target fit and progression

Creators own Minimum/Ideal goals, perk routes, flex picks, and tags. The initial library is empty. Bro Ledger supplies no tactical targets, build priors, preferred roles, or weapon-power ranking.

## Formula

Each targeted stat contributes a continuous, capped satisfaction score. For value `x`, Minimum `m`, and Ideal `i` with `0 ≤ m < i`:

- Below Minimum: `50 × max(0, x) / m`.
- From Minimum to Ideal: `50 + 50 × (x − m) / (i − m)`.
- At or above Ideal: `100`.

When Minimum equals Ideal, use a single ramp `100 × max(0, x) / i`, capped at 100. A zero Ideal is met by any nonnegative value. With a zero Minimum and positive Ideal, nonnegative values start at 50. Negative values contribute zero. Untargeted stats do not contribute; an entirely untargeted build is unrated.

**Potential is the greatest attainable weakest-stat satisfaction, using one shared allocation at average rolls.** The finite feasibility solver searches common thresholds to 0.01 score points, rounding down. Minimum=50 and Ideal=100 are display anchors, not probabilities or tactical cutoffs. There is no letter grade or NOW score. Surplus cannot compensate for another stat's deficit. Ties use stable build-ID order; learned perks never break stat-score ties.

The displayed eight-stat forecast starts from a legal witness for this score. Remaining picks prefer the least-satisfied targeted stat, with fixed stat order breaking ties. It uses exactly three distinct attributes per row. All values share these counts; independent individual maxima are used only to prove impossibility. The allocation is deterministic, not a combat optimizer or a prediction of the player's choices.

This conservative weakest-target formula can be dominated by a single demanding goal. Equal scores need not mean equal practical usefulness. Scores across different creators' targets measure their definitions, not comparable build power. Finite integer outcomes and the 0.01 search resolution introduce small steps; crossing Minimum never introduces a grade cliff. Creator goals at zero or equal Minimum/Ideal have the explicit special cases above.

## Stat basis and finite growth

Targets use permanent natural stats before gear, Colossus, Fortified Mind, and Dodge. Lasting traits, origin effects, injuries, and already allocated Gifted gains count. Raw growth is added before native final rounding and sign-dependent multipliers. Initiative retains its native permanent Stamina deduction. Temporary morale, fatigue, damage, and equipment condition do not affect fit.

Growth uses safe native ranges and visible talents, never future offers. Ordinary growth stops at level 11; Manhunter Indebted stop at level 7. Already earned veteran rows use +1; future veteran levels are not invented. An obtainable, unlearned planned Gifted adds one row of three maximum ordinary gains without talent bonuses. Student's single refund obeys native point availability. Uncertain pending row types or required growth produce an unrated result.

The compact panel compares current permanent values with saved Ideals. Green means already met. Red requires that even investing every remaining row in that attribute with maximum rolls cannot reach its Ideal, within the displayed horizon. Yellow means development is needed; it does not promise eventual success. Unknown growth never supplies a red bound. A separate joint message reports when individually possible goals cannot all fit within the same maximum-roll budget. A shortfall at average rolls alone is not impossibility.

Current-offer advice enumerates all 56 triples of the eight visible rolls. It prefers the best remaining joint Potential, then immediate capped target progress. Unknown growth uses only that immediate tie-break and is labelled provisional. Advice never spends points or modifies the actor. Legacy plans without saved Ideals retain Minimum-only advice and unrated comparison.

## Perks and effects

A community route has up to ten unique perks, or eleven including Student, in creator order respecting native unlock counts. Flex is a subset of those suggested picks. Manual off-route acquisitions can fill unacquired flex positions on a guidance copy; mandatory and already learned picks remain. Library edits, evaluation, and refresh cannot rewrite saved intent. Perk budget/unlock conflicts are shown separately from stat fit; equipment/playstyle tags describe creator intent and do not certify a loadout.

Schemas 1–3 retain their original snapshots and legacy explicit alternatives. Schema 4 snapshots the community definition. No retired catalog is consulted to recover unsaved Ideals. Unknown future schemas remain untouched.

Current learned effects retain the native readouts: Dodge `max(0, floor(current Initiative × .15))`; Nimble HP reduction `100 × (1 − acquired Nimble chance)`; Battle Forged armour reduction `(remaining head + body armour) × .05` percentage points. Percentages round to tenths. These individual current contributions do not forecast equipment, combined protection, or future perks.

Mechanics were inspected against Steam build 23856902 / Battle Brothers 1.5.2.3. The standalone Squirrel runner and synthetic fixtures do not certify game-VM behavior, tactical success, save safety, or UI fit.
