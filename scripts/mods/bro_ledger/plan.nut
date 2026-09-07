::BroLedger.makePlan <- function(build)
{
    return {schema = 2, revision = this.Revision, enabled = true, build = build.id, label = build.label,
        route = this.copy(build.route), targets = this.copy(build.targets), priority = this.copy(build.priority),
        preferredTargets = this.copy(build.preferred), armour = build.armour, swaps = [],
        options = this.copy(build.swaps), weapons = build.weapons, patterns = this.copy(build.patterns)};
};

::BroLedger.planPreferred <- function(plan)
{
    if ("preferredTargets" in plan) return this.copy(plan.preferredTargets);
    if (!("build" in plan)) return null;
    local build = this.findBuild(plan.build);
    if (build == null || plan.revision != this.Revision || plan.targets.len() != build.targets.len()) return null;
    foreach (key, value in plan.targets)
        if (!(key in build.targets) || value != build.targets[key]) return null;
    return this.copy(build.preferred);
};

::BroLedger.replacePlan <- function(plan, index, perks)
{
    if (typeof index != "integer" || index < 0 || index >= plan.options.len()) throw "Unknown replacement";
    local out = this.copy(plan), option = out.options[index], active = out.swaps.find(index);
    local from = active == null ? option.replace : option.with;
    local to = active == null ? option.with : option.replace;
    local slot = out.route.find(from);
    if (from in perks) throw "That perk is already acquired; it cannot be refunded. Change build deliberately instead.";
    if (slot == null || out.route.find(to) != null) throw "Conflicting replacement; undo the other replacement first.";
    out.route[slot] = to;
    if (active == null) out.swaps.push(index);
    else out.swaps.remove(active);
    return out;
};

// Resolve manual acquisitions on a copy; older revisions retain only their saved options.
::BroLedger.guidancePlan <- function(plan, snapshot)
{
    local out = this.copy(plan), build = this.findBuild(out.build);
    if (!out.enabled) return out;
    foreach (index, option in out.options)
    {
        if (out.swaps.find(index) != null && option.replace in snapshot.perks && !(option.with in snapshot.perks))
            out = this.replacePlan(out, index, snapshot.perks);
        // A saved Axe -> Mace choice also permits a manually acquired Hammer.
        if (option.with in snapshot.perks && !(option.replace in snapshot.perks) && out.route.find(option.replace) == null)
            foreach (selected in out.swaps)
                if (out.options[selected].replace == option.replace && !(out.options[selected].with in snapshot.perks))
                {
                    out = this.replacePlan(out, selected, snapshot.perks);
                    break;
                }
        if (option.with in snapshot.perks && !(option.replace in snapshot.perks) &&
            out.route.find(option.replace) != null && out.route.find(option.with) == null)
            out = this.replacePlan(out, index, snapshot.perks);
    }
    local support = ["perk.colossus", "perk.gifted", "perk.pathfinder", "perk.nine_lives",
        "perk.steel_brow", "perk.fortified_mind", "perk.recover"];
    local acquired = [];
    foreach (id, _ in snapshot.perks) acquired.push(id);
    acquired.sort();
    foreach (id in acquired)
    {
        if (out.route.find(id) != null || support.find(id) == null) continue;
        local slot = null;
        foreach (flex in build != null && out.revision == this.Revision ? build.flex : [])
        {
            local from = flex;
            foreach (index in out.swaps) if (out.options[index].replace == flex) from = out.options[index].with;
            local at = out.route.find(from);
            if (at == null || from in snapshot.perks) continue;
            slot = at;
            // Preserve Gifted's future stat row while another unacquired flex slot can absorb the perk.
            if (from != "perk.gifted") break;
        }
        if (slot != null) out.route[slot] = id;
    }
    local options = [], swaps = [];
    foreach (index, option in out.options)
    {
        local from = option.replace;
        foreach (selected in out.swaps)
            if (out.options[selected].replace == option.replace) from = out.options[selected].with;
        if (out.route.find(from) == null) continue;
        if (out.swaps.find(index) != null) swaps.push(options.len());
        options.push(option);
    }
    out.options = options;
    out.swaps = swaps;
    return out;
};

::BroLedger.candidatePlan <- function(build, snapshot)
{
    return this.guidancePlan(this.makePlan(build), snapshot);
};

::BroLedger.flexPerks <- function(plan, snapshot, defs)
{
    local ids = [], build = this.findBuild(plan.build);
    if (snapshot.free < 0 || snapshot.futurePerks < 0 || snapshot.free + snapshot.futurePerks == 0) return ids;
    if (build != null && plan.revision == this.Revision)
        foreach (id in build.flex) if (plan.route.find(id) != null) ids.push(id);
    foreach (option in plan.options)
    {
        local from = option.replace;
        foreach (index in plan.swaps)
            if (plan.options[index].replace == option.replace) from = plan.options[index].with;
        if (plan.route.find(from) == null || from in snapshot.perks) continue;
        ids.push(from);
        ids.push(option.replace);
        ids.push(option.with);
    }
    local out = [];
    // Blue denotes a future choice, not unlockability; native locked appearance remains.
    foreach (id in ids)
        if (id in defs && !(id in snapshot.perks) && out.find(id) == null) out.push(id);
    return out;
};

::BroLedger.route <- function(plan, snapshot, defs)
{
    local remaining = [], unknown = [], acquired = [], offplan = [], conflicts = [];
    if ("armour" in plan)
    {
        local opposite = plan.armour == "nimble" ? "perk.battle_forged" : "perk.nimble";
        if (opposite in snapshot.perks) conflicts.push(opposite);
    }
    foreach (id in plan.route)
    {
        if (!(id in defs)) unknown.push(id);
        if (id in snapshot.perks) acquired.push(id);
        else remaining.push(id);
    }
    foreach (id, _ in snapshot.perks)
        if (id != "perk.student" && plan.route.find(id) == null) offplan.push(id);
    local order = [], spent = snapshot.spent, work = this.copy(remaining);
    while (work.len() > 0)
    {
        local found = null;
        foreach (index, id in work)
            if (id in defs && defs[id].unlock <= spent)
            {
                found = index;
                break;
            }
        if (found == null) break;
        order.push(work[found]);
        work.remove(found);
        spent++;
    }
    local pointsKnown = snapshot.free >= 0 && snapshot.spent >= snapshot.perks.len() && snapshot.futurePerks >= 0;
    return {remaining = order, blocked = work, acquired = acquired, offplan = offplan, unknown = unknown, conflicts = conflicts,
        feasible = pointsKnown && conflicts.len() == 0 && unknown.len() == 0 && work.len() == 0 &&
            remaining.len() <= snapshot.free + snapshot.futurePerks,
        next = pointsKnown && snapshot.free > 0 && order.len() > 0 && defs[order[0]].unlock <= snapshot.spent ? order[0] : null};
};
