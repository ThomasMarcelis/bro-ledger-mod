::BroLedger.Epoch <- 0;

::BroLedger.registerSettings <- function()
{
    local page = this.Mod.ModSettings.addPage("General", this.Name);
    local timing = " Close and reopen the character sheet to apply.";
    page.addBooleanSetting("Enabled", true, "Enable planner",
        "Show Evaluate and saved-plan guidance. Turning this off retains every brother's plan." + timing);
    page.addBooleanSetting("PerkHighlights", true, "Perk highlights",
        "Show green route and blue flexible-perk marks. Perk choices stay manual." + timing);
    page.addBooleanSetting("LevelUpRecommendations", true, "Level-up recommendations",
        "Suggest three attributes from the actual offered rolls. Spend points yourself." + timing);
    page.addBooleanSetting("EquipmentAdvice", true, "Equipment advice",
        "Show weapon/action costs and conditional armour budgets. Equip items yourself." + timing);
};

::BroLedger.registerTooltips <- function()
{
    local tips = {
        now = ["Now fit", "This build's fit using permanent stats already gained. Talent stars improve future growth, not Now. Gear, Colossus, Fortified Mind and Dodge are excluded; lasting traits and injuries count."],
        stats = ["Underlying stats", "Before gear, Colossus, Fortified Mind and Dodge. Lasting traits, permanent injuries and already allocated Gifted gains count. The character sheet shows effective stats. Values here are rounded to two decimal places."],
        potential = ["Potential fit", "This build's fit with remaining levels and talent growth. S: all Ideal targets. A: halfway from Minimum to Ideal. Where Minimum is a dash, A requires the full Ideal. B: all Minimum targets at average rolls. C: needs better rolls. D/F: one or several major shortfalls. An incompatible or impossible perk route caps either grade at D; missing future perks alone do not. These grades are separate, not averaged."],
        expected = ["Expected stats", "One possible allocation at average rolls: three different attributes per level, including planned Gifted when available. All eight values share the same limited picks. Actual rolls and your choices can change the result. Veteran gains already available are included; future veteran levels are not."],
        targets = ["Minimum and Ideal", "Minimum: entry target for this build. Ideal: target for an S fit. A dash means this build has no target for that attribute. Green check: already reached. Amber arrow: needs more investment. Expected values marked ! still fall below Minimum in this allocation. Comparisons use unrounded values."],
        talents = ["Talent stars", "Stars improve an attribute's future level-up rolls. They do not add to current stats. Gifted grants maximum ordinary rolls without talent bonuses."],
        weapons = ["Conditional weapon choices", "Spear Thrust adds 20 percentage points to hit chance; Sword Slash adds 10. Early accuracy helps meet these builds' entry targets, but fit is not weapon strength. Armour and enemy resistances can favour other weapons. Reference comparisons disclose their targets and loadout; no universal switch level applies."],
        dodge = ["Dodge defence", "Current bonus to both melee and ranged defence: 15% of current Initiative. Equipment and accumulated fatigue affect it."],
        nimble = ["Nimble HP reduction", "Current reduction of damage to hitpoints. At most 60%, with raw head and body fatigue penalty of 15 or less. Brawny does not reduce that raw weight."],
        battleForged = ["Battle Forged armour reduction", "Current reduction of damage to armour, using remaining head and body armour. It falls as armour is damaged; it does not measure HP damage reduction."]
    };
    foreach (id, pair in tips) tips[id] = ::MSU.Class.BasicTooltip(pair[0], pair[1]);
    this.Mod.Tooltips.setTooltips(tips);
};

::BroLedger.readSettings <- function()
{
    local settings = {};
    foreach (id in ["Enabled", "PerkHighlights", "LevelUpRecommendations", "EquipmentAdvice"])
        settings[id] <- this.Mod.ModSettings.getSetting(id).getValue();
    return settings;
};

::BroLedger.view <- function(actor, catalog, settings)
{
    local state = this.actorState(actor), snapshot = this.readActor(actor), defs = this.perkDefs();
    local out = {actor = actor.getID(), name = actor.getName(), revision = state.revision, issue = state.issue, plan = null,
        stars = this.copy(snapshot.stars), notes = snapshot.notes, warnings = snapshot.warnings, defs = defs, builds = [], offer = null,
        weaponComparisons = settings.EquipmentAdvice && (catalog || (state.issue == null && state.plan != null && state.plan.enabled)) ?
            this.weaponComparisons("matk" in snapshot.stats ? snapshot.stats.matk : null) : null};
    if (catalog)
    {
        local comparison = this.compare(snapshot, defs);
        out.builds = comparison.builds;
        out.primary <- comparison.primary;
        out.recommended <- comparison.recommended;
    }
    if (state.issue != null || state.plan == null) return out;
    local plan = state.plan;
    out.plan = {build = plan.build, label = plan.label, enabled = plan.enabled,
        legacy = plan.revision != this.Revision};
    if (!plan.enabled) return out;
    plan = this.guidancePlan(plan, snapshot);
    out.plan.route <- this.route(plan, snapshot, defs);
    if (out.plan.route.next != null && !actor.isPerkUnlockable(out.plan.route.next)) out.plan.route.next = null;
    out.plan.weapons <- plan.weapons;
    out.plan.armour <- plan.armour;
    local build = this.findBuild(plan.build);
    out.plan.masteryNote <- build != null && plan.revision == this.Revision ? build.masteryNote : null;
    out.plan.flex <- this.flexPerks(plan, snapshot, defs);
    out.plan.effects <- this.currentEffects(actor, snapshot.perks);
    out.plan.equipment <- settings.EquipmentAdvice ? this.equipmentAdvice(this.readEquipment(actor), plan, snapshot.perks) : null;
    local assessment = this.assess(this.forPlan(snapshot, plan), plan, this.planPreferred(plan), out.plan.route.feasible);
    foreach (key, value in assessment) out.plan[key] <- value;
    if (settings.LevelUpRecommendations && state.offer != null && state.offer.level == snapshot.level &&
        state.offer.pending == snapshot.pending && snapshot.pending > 0)
    {
        out.offer = this.adviseOffer(snapshot, plan, state.offer.values);
        if (out.offer != null)
        {
            out.offer.values <- state.offer.values;
            out.offer.label <- plan.label;
        }
    }
    return out;
};

::BroLedger.command <- function(screen, data)
{
    if (typeof data != "table" || !("actor" in data) || !("seq" in data) || !("action" in data) ||
        typeof data.actor != "integer" || typeof data.seq != "integer" || data.seq < 0 || typeof data.action != "string")
        return {error = "Invalid " + this.Name + " request."};
    local context = screen.m.BroLedgerContext;
    if (context == null || data.seq <= context.seq) return {error = "Character screen changed. Refresh " + this.Name + "."};
    local writesPlan = data.action != "refresh" && data.action != "evaluate";
    if (!context.settings.Enabled)
    {
        if (writesPlan) return {error = this.Name + " is disabled in Mod Options."};
        context.seq = data.seq;
        return {actor = data.actor, seq = data.seq, epoch = context.epoch, title = this.Name, settings = context.settings, plan = null};
    }
    local actor = this.ownedActor(data.actor);
    if (actor == null) return {error = "Select a living company brother."};
    local state = this.actorState(actor);
    local previousPlan = state.plan, previousRevision = state.revision;
    if (writesPlan)
    {
        if (!("epoch" in data) || !("revision" in data) || data.epoch != context.epoch ||
            data.actor != context.actor || data.revision != state.revision || state.issue != null)
            return {error = "Plan or screen changed; refresh before choosing."};
        try
        {
            if (data.action == "track")
            {
                if (!("build" in data) || typeof data.build != "string") throw "Choose a catalog build.";
                local build = this.findBuild(data.build);
                if (build == null) throw "Unknown build.";
                state.plan = this.candidatePlan(build, this.readActor(actor));
            }
            else if (data.action == "enabled")
            {
                if (!("enabled" in data) || typeof data.enabled != "bool" || state.plan == null) throw "No saved plan.";
                state.plan = this.copy(state.plan);
                state.plan.enabled = data.enabled;
            }
            else throw "Unknown command.";
            state.revision++;
        }
        catch (error) { return {error = error.tostring()}; }
    }
    context.seq = data.seq;
    context.actor = data.actor;
    try
    {
        local result = this.view(actor, data.action == "evaluate", context.settings);
        result.epoch <- context.epoch;
        result.seq <- data.seq;
        result.title <- this.Name;
        result.settings <- context.settings;
        return result;
    }
    catch (error)
    {
        state.plan = previousPlan;
        state.revision = previousRevision;
        ::logError(this.Name + " read failed: " + error);
        return {error = this.Name + " could not read this actor. See the game log; normal controls remain available."};
    }
};
