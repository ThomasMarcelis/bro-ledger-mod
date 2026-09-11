::BroLedger.Fields <- {
    hp = ["Hitpoints", "hitpoints"], resolve = ["Bravery", "bravery"], fatigue = ["Stamina", "fatigue"],
    initiative = ["Initiative", "initiative"], matk = ["MeleeSkill", "meleeSkill"], ratk = ["RangedSkill", "rangeSkill"],
    mdef = ["MeleeDefense", "meleeDefense"], rdef = ["RangedDefense", "rangeDefense"]
};

// Lasting natural-stat adjustments only; source and interpretation: docs/STRATEGY.md.
::BroLedger.TraitAdds <- {
    strong = {fatigue = 10}, tough = {hp = 10}, fat = {hp = 10, fatigue = -10}, fragile = {hp = -10},
    brave = {resolve = 5}, fearless = {resolve = 10}, fainthearted = {resolve = -5}, craven = {resolve = -10},
    dexterous = {matk = 5}, clumsy = {matk = -5}, brute = {matk = -5}, drunkard = {resolve = 5, matk = -5, ratk = -10},
    cocky = {resolve = 5, mdef = -5, rdef = -5}, tiny = {mdef = 5, rdef = 5}, huge = {mdef = -5, rdef = -5},
    sure_footing = {mdef = 5}, swift = {rdef = 5}, quick = {initiative = 10}, hesitant = {initiative = -10},
    paranoid = {initiative = -30, mdef = 5, rdef = 5}, old = {hp = -10, fatigue = -10, initiative = -10, resolve = 10},
    player = {resolve = 10}, arena_fighter = {resolve = 5}, arena_veteran = {resolve = 10},
    cultist_fanatic = {resolve = 5}, cultist_zealot = {resolve = 10}, cultist_acolyte = {resolve = 10},
    cultist_disciple = {hp = 20, resolve = 10}, cultist_chosen = {hp = 20, resolve = 10, mdef = 5, rdef = 5},
    cultist_prophet = {hp = 20, resolve = 10, mdef = 5, rdef = 5}
};
::BroLedger.InjuryMults <- {
    brain_damage = {resolve = 1.15, initiative = 0.75}, broken_elbow_joint = {matk = 0.8, ratk = 0.8, mdef = 0.7},
    broken_knee = {mdef = 0.6, rdef = 0.6, initiative = 0.6}, collapsed_lung_part = {fatigue = 0.6},
    maimed_foot = {initiative = 0.8}, missing_ear = {initiative = 0.9}, missing_eye = {ratk = 0.5},
    missing_finger = {matk = 0.95, ratk = 0.95}, missing_hand = {}, missing_nose = {fatigue = 0.9},
    traumatized = {resolve = 0.6, initiative = 0.7}, weakened_heart = {hp = 0.7}
};

::BroLedger.normalize <- function(natural, skills)
{
    local stats = this.copy(natural), scale = {}, notes = [], warnings = [];
    foreach (key in this.Stats) scale[key] <- 1.0;
    foreach (id, values in this.TraitAdds)
        if (("trait." + id) in skills) foreach (key, value in values) stats[key] += value;
    if ("effects.kraken_potion" in skills) stats.hp += 50;
    if ("effects.apotheosis_potion" in skills)
    {
        stats.hp++;
        stats.fatigue++;
    }
    foreach (id, values in this.InjuryMults)
        if (("injury." + id) in skills) foreach (key, value in values) scale[key] *= value;
    if ("trait.addict" in skills)
        notes.push("Addiction is conditional on withdrawal; natural targets exclude that temporary penalty.");
    if ("injury.missing_hand" in skills)
        warnings.push("Missing hand: weapon/shield choices are restricted; follow the actual equipment slots.");
    foreach (id in ["huge", "tiny", "brute", "drunkard"])
        if (("trait." + id) in skills)
            notes.push("Damage effects of " + id + " are tactical context, not extra stat points in this target fit.");
    foreach (id, _ in skills)
        if (id.find("trait.oath_") == 0 || id.find("trait.hate_") == 0 || id.find("trait.fear_") == 0)
            notes.push("Enemy/oath-dependent bonuses are excluded from natural targets: " + id + ".");
    // Native Initiative subtracts additive Stamina loss after multipliers; equipment/fatigue are separate.
    local initiativeLoss = ::Math.maxf(0.0, natural.fatigue - stats.fatigue);
    local rawStats=this.copy(stats);
    foreach (key in this.Stats) stats[key]=this.finalStat(key,rawStats[key],scale[key],initiativeLoss);
    return {stats = stats, rawStats=rawStats, scale = scale, notes = notes, warnings = warnings, initiativeLoss = initiativeLoss};
};

::BroLedger.ownedActor <- function(id)
{
    foreach (actor in ::World.getPlayerRoster().getAll())
        if (actor.getID() == id && !actor.isGuest() && actor.isAlive()) return actor;
    return null;
};

::BroLedger.perkDefs <- function()
{
    local defs = {};
    foreach (row, perks in ::Const.Perks.Perks) foreach (column, perk in perks)
        if ("ID" in perk && "Unlocks" in perk) defs[perk.ID] <- {unlock = perk.Unlocks, name = perk.Name,
            icon = "Icon" in perk ? perk.Icon : null, row = row, column = column,
            // The native tree entry carries the same description the game's own perk tooltip shows.
            description = "Tooltip" in perk && this.plainName(perk.Tooltip, 800) ? perk.Tooltip : null};
    return defs;
};

::BroLedger.readActor <- function(actor)
{
    local natural = actor.getBaseProperties(), talents = actor.getTalents(), skills = {};
    local snapshot = {stats = {}, stars = {}, ranges = {}, perks = {}, growthKnown = true, giftRows = 0,
        level = actor.getLevel(), pending = actor.getLevelUps(), free = actor.getPerkPoints(), spent = actor.getPerkPointsSpent()};
    local mask = ::Const.SkillType.Perk | ::Const.SkillType.Trait | ::Const.SkillType.PermanentInjury | ::Const.SkillType.StatusEffect;
    foreach (skill in actor.getSkills().query(mask, true))
    {
        local id = skill.getID();
        skills[id] <- true;
        if ((skill.getType() & ::Const.SkillType.Perk) != 0) snapshot.perks[id] <- true;
    }
    local attributes = [::Const.Attributes.Hitpoints, ::Const.Attributes.Bravery, ::Const.Attributes.Fatigue, ::Const.Attributes.Initiative,
        ::Const.Attributes.MeleeSkill, ::Const.Attributes.RangedSkill, ::Const.Attributes.MeleeDefense, ::Const.Attributes.RangedDefense];
    foreach (index, key in this.Stats)
    {
        local attribute = attributes[index];
        snapshot.stats[key] <- natural[this.Fields[key][0]];
        local talent = typeof talents == "array" && attribute < talents.len() ? talents[attribute] : null;
        snapshot.stars[key] <- typeof talent == "integer" && talent >= 0 && talent <= 3 ? talent : null;
        snapshot.ranges[key] <- [::Const.AttributesLevelUp[attribute].Min, ::Const.AttributesLevelUp[attribute].Max];
    }
    local normalized = this.normalize(snapshot.stats, skills);
    snapshot.stats = normalized.stats;
    snapshot.rawStats <- normalized.rawStats;
    snapshot.initiativeLoss <- normalized.initiativeLoss;
    snapshot.missingHand <- "injury.missing_hand" in skills;
    snapshot.scale <- normalized.scale;
    snapshot.notes <- normalized.notes;
    snapshot.warnings <- normalized.warnings;
    foreach (key in this.Stats)
    {
        local field = this.Fields[key][0] + "Mult";
        if (field in natural && this.number(natural[field]) && natural[field] > 0)
        {
            snapshot.scale[key] *= natural[field];
        }
        snapshot.stats[key]=this.endpoint(snapshot,key);
    }
    local maxLevel = ::Const.XP.MaxLevelWithPerkpoints;
    // Manhunters onUpdateLevel/onUnlockPerk apply the Indebted cap and Student refund at 7.
    if ("State" in ::World && ::World.State != null && ::World.Assets.getOrigin().getID() == "scenario.manhunters" &&
        actor.getBackground().getID() == "background.slave")
    {
        maxLevel = 7;
        snapshot.warnings.push("Manhunters Indebted stop at level 7; targets and perk budgets use that horizon.");
    }
    if (typeof snapshot.level != "integer" || snapshot.level < 1 || snapshot.level > 50 ||
        typeof snapshot.pending != "integer" || snapshot.pending < 0 || snapshot.pending > 50 ||
        typeof snapshot.free != "integer" || snapshot.free < 0 || snapshot.free > 100 ||
        typeof snapshot.spent != "integer" || snapshot.spent < 0 || snapshot.spent > 100)
        throw "Unsupported level or point values";
    snapshot.horizon <- ::Math.max(snapshot.level, maxLevel);
    snapshot.perkHorizon <- maxLevel;
    local earnedVeterans = ::Math.max(0, snapshot.level - ::Const.XP.MaxLevelWithPerkpoints);
    snapshot.normalRows <- ::Math.max(0, maxLevel - snapshot.level) + ::Math.max(0, snapshot.pending - earnedVeterans);
    snapshot.veteranRows <- ::Math.min(snapshot.pending, earnedVeterans);
    snapshot.futurePerks <- ::Math.max(0, maxLevel - snapshot.level) + (snapshot.level < maxLevel && "perk.student" in snapshot.perks ? 1 : 0);
    if (snapshot.pending > 0 && "perk.gifted" in snapshot.perks)
    {
        // Gifted inserts its maximum row at the front. A different visible row proves it was spent.
        local offer = this.actorState(actor).offer, couldBeGifted = true;
        if (offer != null && offer.level == snapshot.level && offer.pending == snapshot.pending)
            foreach (key in this.Stats) if (offer.values[key] != snapshot.ranges[key][1]) couldBeGifted = false;
        snapshot.growthKnown = !couldBeGifted;
        if (couldBeGifted)
            snapshot.notes.push("Pending maximum rolls may be Gifted or ordinary. Exact remaining row types are unknown; actual offered-roll advice remains available.");
    }
    if (snapshot.perks.len() > snapshot.spent)
        snapshot.notes.push("Acquired perks exceed the recorded spent count; fit and route budget are uncertain.");
    return snapshot;
};

::BroLedger.captureOffer <- function(actor, data)
{
    local state = this.actorState(actor);
    state.offer = null;
    if (typeof data != "table" || !("levelUp" in data) || typeof data.levelUp != "table") return;
    local offer = {};
    foreach (key, fields in this.Fields)
    {
        local field = fields[1] + "Increase";
        if (!(field in data.levelUp) || !this.number(data.levelUp[field]) || data.levelUp[field] <= 0) return;
        offer[key] <- data.levelUp[field];
    }
    state.offer = {values = offer, level = actor.getLevel(), pending = actor.getLevelUps()};
};
