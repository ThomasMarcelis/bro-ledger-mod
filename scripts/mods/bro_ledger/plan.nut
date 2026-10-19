::BroLedger.makePlan <- function(build)
{
    return {schema=5,revision=this.Revision,enabled=true,build=build.id,label=build.label,weights=this.buildWeights(build),
        route=this.copy(build.route),targets=this.copy(build.targets),preferredTargets=this.copy(build.preferred),
        flex=this.copy(build.flex),weaponTags=this.copy(build.weaponTags),playstyleTags=this.copy(build.playstyleTags)};
};
::BroLedger.planFlex <- function(plan) {return "flex" in plan ? plan.flex : [];};
::BroLedger.planPreferred <- function(plan) {return this.copy(plan.preferredTargets);};

// Resolve manual acquisitions on a copy.
::BroLedger.guidancePlan <- function(plan, snapshot)
{
    local out = this.copy(plan);
    if (!out.enabled) return out;
    local acquired=[];foreach(id,_ in snapshot.perks) if(out.route.find(id)==null && id!="perk.student") acquired.push(id);
    acquired.sort();
    foreach(id in acquired) foreach(flex in out.flex) {
        local at=out.route.find(flex);
        if(at!=null && !(flex in snapshot.perks)) {out.route[at]=id;break;}
    }
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
    local out = [];
    // Blue denotes a future choice, not unlockability; native locked appearance remains.
    foreach (id in ids)
        if (id in defs && !(id in snapshot.perks) && out.find(id) == null) out.push(id);
    return out;
};

::BroLedger.route <- function(plan, snapshot, defs)
{
    local remaining = [], unknown = [], acquired = [], offplan = [];
    foreach (id in plan.route)
    {
        if (!(id in defs)) unknown.push(id);
        if (id in snapshot.perks) acquired.push(id);
        else remaining.push(id);
    }
    // Flexible picks are alternates rather than commitments, so only mandatory ones must fit the budget.
    local flex = this.planFlex(plan), mandatoryRemaining = [];
    foreach (id in remaining) if (flex.find(id) == null && id in defs) mandatoryRemaining.push(id);
    foreach (id, _ in snapshot.perks)
        if (id != "perk.student" && plan.route.find(id) == null) offplan.push(id);
    local pointsKnown = snapshot.free >= 0 && snapshot.spent >= snapshot.perks.len() && snapshot.futurePerks >= 0;
    local order = [], spent = snapshot.spent, work = this.copy(remaining);
    local points = pointsKnown ? snapshot.free + snapshot.futurePerks : 0;
    // An unowned Student costs a point before its single refund, even at the cap.
    // Owned Student's still-future refund is already in futurePerks.
    local refund = points >= 1 && remaining.find("perk.student") != null && "perk.student" in defs;
    if (refund) {
        if (mandatoryRemaining.find("perk.student") == null) mandatoryRemaining.push("perk.student");
        points++;
    }
    local needed = this.picksNeeded(mandatoryRemaining, defs, snapshot.spent);
    while (work.len() > 0)
    {
        local found = null, known = false;
        foreach (index, id in work) {
            if (!(id in defs)) continue;
            known = true;
            if (defs[id].unlock <= spent)
            {
                found = index;
                break;
            }
        }
        if (found == null) {
            if (!known) break;
            spent++;
            continue;
        }
        local id = work[found];
        order.push(id);
        work.remove(found);
        spent++;
    }
    return {remaining = order, blocked = work, acquired = acquired, offplan = offplan, unknown = unknown,
        pointsKnown = pointsKnown, points = points, studentRefund = refund,
        needed = needed, filler = ::Math.max(0, needed - mandatoryRemaining.len()),
        feasible = pointsKnown && unknown.len() == 0 && needed <= points,
        next = pointsKnown && snapshot.free > 0 && order.len() > 0 && defs[order[0]].unlock <= snapshot.spent ? order[0] : null};
};
