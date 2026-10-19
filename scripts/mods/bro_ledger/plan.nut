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
    local flex = this.planFlex(plan), mandatoryRemaining = 0;
    foreach (id in remaining) if (flex.find(id) == null) mandatoryRemaining++;
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
    return {remaining = order, blocked = work, acquired = acquired, offplan = offplan, unknown = unknown,
        pointsKnown = pointsKnown, points = points, studentRefund = refund,
        // Mandatory picks must fit the point budget. Flexible picks are alternates: a build stays
        // feasible when they do not all fit, so a 10-mandatory build may list extra flexible options.
        feasible = pointsKnown && unknown.len() == 0 && work.len() == 0 &&
            mandatoryRemaining <= points,
        next = pointsKnown && snapshot.free > 0 && order.len() > 0 && defs[order[0]].unlock <= snapshot.spent ? order[0] : null};
};
