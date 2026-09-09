# Target fit and progression

Creators own Minimum/Ideal goals, numeric weights, perk routes, flexible picks, and tags. Bro Planner includes ten original, editable-by-copy starter templates with approachable level-11 natural-stat goals. They may be suboptimal and are starting guides, not build-power ratings or tactical guarantees.

## Formula

Each targeted stat contributes a continuous, capped satisfaction score. For value `x`, Minimum `m`, and Ideal `i` with `0 ≤ m < i`:

- Below Minimum: `50 × max(0, x) / m`.
- From Minimum to Ideal: `50 + 50 × (x − m) / (i − m)`.
- At or above Ideal: `100`.

When Minimum equals Ideal, use a single ramp `100 × max(0, x) / i`, capped at 100. A zero Ideal is met by any nonnegative value. With a zero Minimum and positive Ideal, nonnegative values start at 50. Negative values contribute zero. Attributes with blank ranges or weight 0 do not contribute. Weights are whole numbers from 0–10, defaulting to 1. Zero preserves the stored range for later reuse. A build without positive-weight targets is unrated.

**Potential is the greatest weighted average of capped satisfaction attainable with one shared allocation at average rolls:** `sum(weight × satisfaction) / sum(weight)` over targeted, positive-weight attributes. Scores are rounded down to 0.01 points. Minimum=50 and Ideal=100 are per-attribute anchors; an overall 50 does not prove all Minimums are met. Higher-weight progress may compensate for a secondary shortfall; surplus above Ideal never contributes. Scores are target fit, not probabilities, combat strength, or a universal comparison of creators' goals.

The finite optimizer uses dynamic programming over shared normal, earned veteran, and obtainable Gifted budgets. A joint witness reaching all capped individual maxima is already optimal. When every attribute remains in one linear satisfaction segment and its native endpoints are certified affine over the finite domain, constant marginal values give the same exact optimum directly. These shortcuts use the same objective. Nonlinear native rounding and threshold crossings retain the general optimizer. For larger domains, a legal provisional allocation supplies a lower bound and nonnegative resource prices supply upper bounds. Only choices and continuations proven unable to beat that allocation are pruned, with slack for native floating-point arithmetic; the provisional allocation is never substituted for the exact result.

The eight-stat forecast reconstructs the winning allocation and fills unused slots deterministically to exactly three distinct attributes per row. Filler does not increase an ignored attribute's importance. Ranking ties use source then stable build-ID order; learned perks never break stat-score ties. The forecast is an allocation witness, not a prediction of player choices or revealed rolls.

## Stat basis and finite growth

Targets use permanent natural stats before gear, Colossus, Fortified Mind, and Dodge. Lasting traits, origin effects, injuries, and already allocated Gifted gains count. Raw growth is added before native final rounding and sign-dependent multipliers. Initiative retains its native permanent Stamina deduction. Temporary morale, fatigue, damage, and equipment condition do not affect fit.

Growth uses safe native ranges and visible talents, never future offers. Ordinary growth stops at level 11; Manhunter Indebted stop at level 7. Already earned veteran rows use +1; future veteran levels are not invented. An obtainable, unlearned planned Gifted adds one row of three maximum ordinary gains without talent bonuses. Student's single refund obeys native point availability. Uncertain pending row types or required growth produce an unrated result.

The compact panel compares current permanent values with saved Ideals. Green means already met. Red requires that even investing every remaining row in that attribute with maximum rolls cannot reach its Ideal, within the displayed horizon. Yellow means development is needed; it does not promise eventual success. Unknown growth never supplies a red bound. A separate joint message reports when individually possible goals cannot all fit within the same maximum-roll budget. A shortfall at average rolls alone is not impossibility.

Current-offer advice enumerates all 56 triples of the eight visible rolls. It prefers the best remaining weighted Potential, then immediate weighted capped progress. Ignored attributes are omitted from the displayed recommendation; the player fills any remaining choices. An entirely ignored build gives no stat recommendations. Unknown growth uses only that immediate tie-break and is labelled provisional. Advice never spends points or modifies the actor. Legacy plans without saved Ideals retain Minimum-only advice and unrated comparison.

## Perks and effects

A community route has up to ten unique perks, or eleven including Student, in creator order respecting native unlock counts. Flex is a subset of those suggested picks. Manual off-route acquisitions can fill unacquired flex positions on a guidance copy; mandatory and already learned picks remain. Library edits, evaluation, and refresh cannot rewrite saved intent. Perk budget/unlock conflicts are shown separately from stat fit; equipment/playstyle tags describe creator intent and do not certify a loadout.

Schemas 1–3 retain their original snapshots and legacy explicit alternatives. Schemas 4–5 snapshot the definition; schema 5 also saves all eight weights. Older snapshots use implicit equal weights without being rewritten. Template or library changes never update saved snapshots. No retired catalog is consulted to recover unsaved Ideals. Unknown future schemas remain untouched.

Current learned effects retain the native readouts: Dodge `max(0, floor(current Initiative × .15))`; Nimble HP reduction `100 × (1 − acquired Nimble chance)`; Battle Forged armour reduction `(remaining head + body armour) × .05` percentage points. Percentages round to tenths. These individual current contributions do not forecast equipment, combined protection, or future perks.

Mechanics were inspected against Steam build 23856902 / Battle Brothers 1.5.2.3. The standalone Squirrel runner and synthetic fixtures do not certify game-VM behavior, tactical success, save safety, or UI fit.
