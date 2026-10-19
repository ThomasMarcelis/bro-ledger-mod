::BroLedger.SchemaFlag <- "BroLedger.Schema";
::BroLedger.BlobFlag <- "MSU.mod_bro_ledger.Plan";
::BroLedger.CollapsedFlag <- "BroLedger.Collapsed";

// A plain native flag: the brother's own flag container is saved and loaded with the campaign,
// so a collapsed panel stays collapsed across restarts without touching the plan schema.
::BroLedger.readCollapsed <- function(actor)
{
    local flags = actor.getFlags();
    return flags.has(this.CollapsedFlag) && flags.get(this.CollapsedFlag) == true;
};

::BroLedger.writeCollapsed <- function(actor, collapsed)
{
    local flags = actor.getFlags();
    if (collapsed) flags.set(this.CollapsedFlag, true);
    else flags.remove(this.CollapsedFlag);
};

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

::BroLedger.validPlan <- function(plan)
{
    if (typeof plan != "table" || !("schema" in plan) || typeof plan.schema != "integer" ||
        plan.schema != 5 || plan.len() != 12) return false;
    foreach(k in ["revision","enabled","build","label","weights","route","targets","preferredTargets","flex","weaponTags","playstyleTags"]) if(!(k in plan)) return false;
    local build={id=plan.build,label=plan.label,weights=plan.weights,route=plan.route,targets=plan.targets,preferred=plan.preferredTargets,
        flex=plan.flex,weaponTags=plan.weaponTags,playstyleTags=plan.playstyleTags};
    return typeof plan.revision=="integer" && plan.revision>0 && typeof plan.enabled=="bool" && this.validBuild(build);
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
    if ([1, 2, 3, 4].find(flags.get(this.SchemaFlag)) != null) return;
    if (flags.get(this.SchemaFlag) != 5)
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
