::BroLedger.SchemaFlag <- "BroLedger.Schema";
::BroLedger.BlobFlag <- "MSU.mod_bro_ledger.Plan";

::BroLedger.validString <- function(value, maxLength = 160)
{
    return typeof value == "string" && value.len() > 0 && value.len() <= maxLength;
};

::BroLedger.uniqueStrings <- function(values, limit)
{
    if (typeof values != "array" || values.len() > limit) return false;
    local seen = {};
    foreach (value in values)
    {
        if (!this.validString(value) || value in seen) return false;
        seen[value] <- true;
    }
    return true;
};

::BroLedger.validTargets <- function(targets)
{
    if (typeof targets != "table" || targets.len() > 8) return false;
    foreach (key, value in targets)
        if (this.Stats.find(key) == null || !this.number(value) || value <= 0 || value > 500) return false;
    return true;
};

::BroLedger.validPlan <- function(plan)
{
    if (typeof plan != "table" || !("schema" in plan) || typeof plan.schema != "integer" ||
        (plan.schema != 1 && plan.schema != 2)) return false;
    if (plan.len() != (plan.schema == 1 ? 13 : 14)) return false;
    foreach (key in ["revision", "enabled", "build", "label", "route", "targets", "priority", "armour", "swaps", "options", "patterns", "weapons"])
        if (!(key in plan)) return false;
    if (typeof plan.revision != "integer" || plan.revision < 1 || plan.revision > 1000000 || typeof plan.enabled != "bool" ||
        !this.validString(plan.build) || !this.validString(plan.label) || !this.validString(plan.weapons, 800) ||
        !this.uniqueStrings(plan.route, 12) || plan.route.len() == 0 || !this.uniqueStrings(plan.priority, 8) ||
        !this.validTargets(plan.targets) || plan.targets.len() == 0 ||
        (plan.armour != "nimble" && plan.armour != "battle_forged") ||
        typeof plan.swaps != "array" || plan.swaps.len() > 5 || typeof plan.options != "array" || plan.options.len() > 5 ||
        typeof plan.patterns != "array" || plan.patterns.len() > 4) return false;
    if (plan.schema == 2)
    {
        if (!("preferredTargets" in plan) || !this.validTargets(plan.preferredTargets)) return false;
        foreach (key, value in plan.targets)
            if (!(key in plan.preferredTargets) || plan.preferredTargets[key] < value) return false;
    }
    foreach (key in plan.priority) if (this.Stats.find(key) == null) return false;
    foreach (option in plan.options)
        if (typeof option != "table" || !("replace" in option) || !("with" in option) || !("condition" in option) ||
            !this.validString(option.replace) || !this.validString(option.with) || !this.validString(option.condition, 800)) return false;
    local seen = {};
    foreach (index in plan.swaps)
    {
        if (typeof index != "integer" || index < 0 || index >= plan.options.len() || index in seen) return false;
        seen[index] <- true;
        if (plan.route.find(plan.options[index].with) == null || plan.route.find(plan.options[index].replace) != null) return false;
    }
    foreach (cycle in plan.patterns)
    {
        if (typeof cycle != "table") return false;
        foreach (key in ["label", "steps", "turns", "buffer", "move", "kill"]) if (!(key in cycle)) return false;
        if (!this.validString(cycle.label, 800) || typeof cycle.steps != "array" || cycle.steps.len() == 0 || cycle.steps.len() > 3 ||
            typeof cycle.turns != "integer" || cycle.turns < 1 || cycle.turns > 5 || !this.number(cycle.buffer) || cycle.buffer < 0 || cycle.buffer > 50 ||
            !this.number(cycle.move) || cycle.move < 0 || cycle.move > 10 || typeof cycle.kill != "bool") return false;
        foreach (step in cycle.steps)
        {
            if (typeof step != "table") return false;
            foreach (key in ["ids", "count", "fat", "ap", "mastery"]) if (!(key in step)) return false;
            if (!this.uniqueStrings(step.ids, 4) || step.ids.len() == 0 || typeof step.count != "integer" || step.count < 1 || step.count > 3 ||
                !this.number(step.fat) || step.fat < 0 || step.fat > 100 || !this.number(step.ap) || step.ap < 0 || step.ap > 9 ||
                typeof step.mastery != "string" || step.mastery.len() > 80) return false;
        }
    }
    return true;
};

::BroLedger.actorState <- function(actor)
{
    if (!("BroLedger" in actor.m)) actor.m.BroLedger <- {plan = null, issue = null, offer = null, revision = 0};
    return actor.m.BroLedger;
};

::BroLedger.loadPlan <- function(actor)
{
    local state = this.actorState(actor), flags = actor.getFlags();
    state.plan = null;
    state.offer = null;
    state.issue = null;
    state.revision++;
    if (!flags.has(this.SchemaFlag))
    {
        if (flags.has(this.BlobFlag)) state.issue = "Unrecognized saved plan; retained without changes.";
        return;
    }
    if ([1, 2].find(flags.get(this.SchemaFlag)) == null)
    {
        state.issue = "Saved by a newer or unsupported " + this.Name + " schema; retained without changes.";
        return;
    }
    try
    {
        local length = flags.get(this.BlobFlag);
        if (typeof length != "integer" || length < 1 || length > 4096) throw "Invalid plan length";
        // MSU consumes its reader flags. A non-consuming view preserves bytes even on partial failure.
        local view = {has = @(key) flags.has(key), get = @(key) flags.get(key), remove = function(key) {}};
        local plan = this.Mod.Serialization.flagDeserialize("Plan", null, null, view);
        if (!this.validPlan(plan) || plan.schema != flags.get(this.SchemaFlag)) throw "Invalid plan";
        state.plan = plan;
    }
    catch (error) { state.issue = "Saved plan could not be read; retained without changes."; }
};

::BroLedger.savePlan <- function(actor)
{
    local state = this.actorState(actor);
    if (state.issue != null || state.plan == null) return;
    if (!this.validPlan(state.plan))
    {
        state.issue = "Invalid owned plan; previous flags retained. Normal saving continues.";
        return;
    }
    this.Mod.Serialization.flagSerialize("Plan", state.plan, actor.getFlags());
    actor.getFlags().set(this.SchemaFlag, state.plan.schema);
};
