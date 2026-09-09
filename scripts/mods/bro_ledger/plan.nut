::BroLedger.makePlan <- function(build)
{
    return {schema=5,revision=this.Revision,enabled=true,build=build.id,label=build.label,weights=this.buildWeights(build),
        route=this.copy(build.route),targets=this.copy(build.targets),preferredTargets=this.copy(build.preferred),
        flex=this.copy(build.flex),weaponTags=this.copy(build.weaponTags),playstyleTags=this.copy(build.playstyleTags)};
};
::BroLedger.planFlex <- function(plan) {return "flex" in plan ? plan.flex : [];};
::BroLedger.planPreferred <- function(plan) {return "preferredTargets" in plan ? this.copy(plan.preferredTargets) : null;};

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
    local out = this.copy(plan);
    if (!out.enabled) return out;
    if(out.schema>=4) {
        local acquired=[];foreach(id,_ in snapshot.perks) if(out.route.find(id)==null && id!="perk.student") acquired.push(id);
        acquired.sort();
        foreach(id in acquired) foreach(flex in out.flex) {
            local at=out.route.find(flex);
            if(at!=null && !(flex in snapshot.perks)) {out.route[at]=id;break;}
        }
        return out;
    }
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
        foreach (flex in this.planFlex(out))
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
    local ids = [];
    if (snapshot.free < 0 || snapshot.futurePerks < 0 || snapshot.free + snapshot.futurePerks == 0) return ids;
    foreach (id in this.planFlex(plan)) if (plan.route.find(id) != null) ids.push(id);
    foreach (option in ("options" in plan ? plan.options : []))
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
    local pointsKnown = snapshot.free >= 0 && snapshot.spent >= snapshot.perks.len() && snapshot.futurePerks >= 0;
    local order = [], spent = snapshot.spent, work = this.copy(remaining);
    local points = pointsKnown ? snapshot.free + snapshot.futurePerks : 0;
    local refund = false;
    // An unowned Student costs a point before its single refund, even at the cap.
    // Owned Student's still-future refund is already in futurePerks.
    local available = points;
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
        local id = work[found];
        order.push(id);
        work.remove(found);
        spent++;
        if (available > 0)
        {
            available--;
            if (id == "perk.student") { available++; points++; refund = true; }
        }
        else available--;
    }
    return {remaining = order, blocked = work, acquired = acquired, offplan = offplan, unknown = unknown, conflicts = conflicts,
        pointsKnown = pointsKnown, points = points, studentRefund = refund,
        feasible = pointsKnown && conflicts.len() == 0 && unknown.len() == 0 && work.len() == 0 &&
            remaining.len() <= points,
        next = pointsKnown && snapshot.free > 0 && order.len() > 0 && defs[order[0]].unlock <= snapshot.spent ? order[0] : null};
};
