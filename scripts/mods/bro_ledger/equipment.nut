::BroLedger.armourCost <- function(head, body, brawny)
{
    local multiplier = brawny ? 0.7 : 1.0;
    return -(::Math.ceil(head * multiplier) + ::Math.floor(body * multiplier));
};

// Nimble exposes a safe getter. Dodge/Battle Forged use bounded formulas from 1.5.2.3;
// never invoke their combat/update hooks to obtain these contributions.
::BroLedger.currentEffects <- function(actor, perks)
{
    local out = {};
    foreach (key, id in {dodge = "perk.dodge", nimble = "perk.nimble", battleForged = "perk.battle_forged"})
    {
        local effect = {owned = id in perks, value = null};
        out[key] <- effect;
        if (!effect.owned) continue;
        try
        {
            if (key == "dodge")
            {
                local initiative = actor.getInitiative();
                if (this.number(initiative)) effect.value = ::Math.max(0, ::Math.floor(initiative * 0.15));
            }
            else if (key == "nimble")
            {
                local perk = actor.getSkills().getSkillByID(id);
                local taken = perk == null ? null : perk.getChance();
                if (this.number(taken) && taken >= 0 && taken <= 1)
                    effect.value = ::Math.round((1.0 - taken) * 1000) / 10.0;
            }
            else
            {
                local head = actor.getArmor(::Const.BodyPart.Head), body = actor.getArmor(::Const.BodyPart.Body);
                if (this.number(head) && this.number(body) && head >= 0 && body >= 0)
                    effect.value = ::Math.round((head + body) * 0.05 * 10) / 10.0;
            }
        }
        catch (error) { /* This effect stays unknown; other readouts remain available. */ }
    }
    return out;
};

::BroLedger.readEquipment <- function(actor)
{
    local items = actor.getItems(), properties = actor.getCurrentProperties(), skills = actor.getSkills();
    local head = items.getItemAtSlot(::Const.ItemSlot.Head), body = items.getItemAtSlot(::Const.ItemSlot.Body);
    local gear = {
        head = head == null ? 0 : head.getStaminaModifier(), body = body == null ? 0 : body.getStaminaModifier(),
        headArmour = head == null ? 0 : head.getArmorMax(), bodyArmour = body == null ? 0 : body.getArmorMax(),
        brawny = skills.hasSkill("perk.brawny"), capacity = actor.getFatigueMax(), fatigue = actor.getFatigue(),
        stamina = properties.Stamina, mult = properties.StaminaMult,
        recovery = ::Math.max(0, properties.FatigueRecoveryRate) * properties.FatigueRecoveryRateMult,
        ap = actor.getActionPointsMax(), actions = {}, items = []
    };
    foreach (slot in [::Const.ItemSlot.Mainhand, ::Const.ItemSlot.Offhand, ::Const.ItemSlot.Ammo, ::Const.ItemSlot.Accessory])
    {
        local item = items.getItemAtSlot(slot);
        if (item != null) gear.items.push({name = item.getName(), raw = item.getStaminaModifier(), bag = false});
    }
    for (local index = 0; index < items.getUnlockedBagSlots(); index++)
    {
        local item = items.getItemAtBagSlot(index);
        if (item != null) gear.items.push({name = item.getName(), raw = item.getStaminaModifier(), bag = true});
    }
    // Cost getters require a real, attached actor.
    foreach (skill in skills.query(::Const.SkillType.Active, true))
        if (skill.getContainer() != null && skill.getContainer().getActor() != null)
            gear.actions[skill.getID()] <- {fat = skill.getFatigueCost(), ap = skill.getActionPointCost(),
                polearm = skill.getID() == "actives.smite" && "IsPolearm" in skill.m ? skill.m.IsPolearm : false};
    return gear;
};

::BroLedger.equipmentAdvice <- function(gear, plan, perks)
{
    local result = {capacity = gear.capacity, headroom = gear.capacity - gear.fatigue, recovery = gear.recovery,
        rawArmour = -(gear.head + gear.body), effectiveArmour = this.armourCost(gear.head, gear.body, gear.brawny),
        headArmour = gear.headArmour, bodyArmour = gear.bodyArmour, items = gear.items, cycles = []};
    foreach (cycle in plan.patterns)
    {
        local projectedFat = cycle.move, projectedAP = cycle.move > 0 ? 2 : 0;
        local currentFat = cycle.move, currentAP = projectedAP, measured = true;
        foreach (step in cycle.steps)
        {
            local mastery = step.mastery;
            if (plan.revision < 3 && step.ids.find("actives.split_man") != null)
                foreach (weapon in ["axe", "mace", "hammer"])
                    if (plan.route.find("perk.mastery." + weapon) != null) mastery = "perk.mastery." + weapon;
            local mastered = mastery != "" && (plan.route.find(mastery) != null || mastery in perks);
            projectedFat += step.count * ::Math.ceil(step.fat * (mastered ? 0.75 : 1.0));
            local ap = step.ap;
            if (mastered && (mastery == "perk.mastery.polearm" || mastery == "perk.mastery.dagger")) ap--;
            if (mastered && step.ids.find("actives.reload_handgonne") != null) ap = 6;
            projectedAP += step.count * ap;
            local action = null;
            foreach (id in step.ids) if (id in gear.actions)
            {
                local candidate = gear.actions[id];
                // Pollaxe and 2H Hammer share Smite's ID but use different training and AP.
                if (id == "actives.smite" && (! ("polearm" in candidate) ||
                    candidate.polearm != (mastery == "perk.mastery.polearm"))) continue;
                action = candidate;
                break;
            }
            if (action == null) measured = false;
            else
            {
                currentFat += step.count * action.fat;
                currentAP += step.count * action.ap;
            }
        }
        if (cycle.move > 0 && !("perk.pathfinder" in perks)) measured = false;
        local projectedLegal = projectedAP <= gear.ap + (cycle.kill && plan.route.find("perk.berserk") != null ? 4 : 0);
        local currentLegal = measured && currentAP <= gear.ap + (cycle.kill && "perk.berserk" in perks ? 4 : 0);
        local reserve = this.reserve(projectedFat, gear.recovery, cycle.turns, cycle.buffer);
        // Undo only current head/body penalties; other item/bag costs and live multipliers stay counted.
        local budget = this.number(gear.mult) && gear.mult > 0 ?
            ::Math.floor(gear.stamina + result.effectiveArmour - ::Math.ceil(reserve) / gear.mult) : null;
        result.cycles.push({label = cycle.label, turns = cycle.turns, buffer = cycle.buffer, projectedFat = projectedFat,
            projectedAP = projectedAP, projectedLegal = projectedLegal, reserve = reserve, armourBudget = budget,
            currentFat = measured ? currentFat : null, currentAP = measured ? currentAP : null, currentLegal = currentLegal,
            currentReserve = measured ? this.reserve(currentFat, gear.recovery, cycle.turns, cycle.buffer) : null});
    }
    return result;
};

// A rested action cycle; recovery occurs between turns.
::BroLedger.reserve <- function(cost, recovery, turns, buffer)
{
    return cost + ::Math.maxf(0.0, cost - recovery) * (turns - 1) + buffer;
};

// Deliberately bounded ordinary 1H examples, not a combat or inventory model.
// Each entry is an item + its normal attack. See Strategy for source/rounding assumptions.
::BroLedger.WeaponExamples <- [
    {name = "Fighting Spear / Thrust", low = 35, high = 40, armour = 1.0, direct = 0.25, hit = 20, fat = 10, minimum = 0, ancient = 0.5},
    {name = "Arming Sword / Slash", low = 40, high = 45, armour = 0.8, direct = 0.2, hit = 10, fat = 10, minimum = 0, ancient = 1.0},
    {name = "Noble Sword / Slash", low = 45, high = 50, armour = 0.85, direct = 0.2, hit = 10, fat = 10, minimum = 0, ancient = 1.0},
    {name = "Fighting Axe / Chop", low = 35, high = 55, armour = 1.3, direct = 0.3, hit = 0, fat = 13, minimum = 0, ancient = 1.0},
    {name = "Winged Mace / Bash", low = 35, high = 55, armour = 1.1, direct = 0.4, hit = 0, fat = 13, minimum = 0, ancient = 1.0},
    {name = "Warhammer / Batter", low = 30, high = 40, armour = 2.25, direct = 0.5, hit = 0, fat = 14, minimum = 10, ancient = 1.0},
    {name = "Military Cleaver / Cleave", low = 40, high = 60, armour = 0.9, direct = 0.25, hit = 0, fat = 12, minimum = 0, ancient = 1.0},
    {name = "Flail / Flail", low = 25, high = 55, armour = 1.0, direct = 0.3, hit = 0, fat = 13, minimum = 0, ancient = 1.0}
];

::BroLedger.exampleHit <- function(attack, bonus, defence)
{
    return ::Math.maxf(5.0, ::Math.minf(95.0, attack + bonus - defence)) / 100.0;
};

::BroLedger.exampleDamage <- function(weapon, armour, ancient)
{
    local hp = 0.0, removed = 0.0, count = 0;
    // Independent uniform integer rolls for regular and armour damage. No RNG calls.
    for (local regular = weapon.low; regular <= weapon.high; regular++)
        for (local roll = weapon.low; roll <= weapon.high; roll++)
        {
            local damageArmour = ::Math.min(armour, roll * weapon.armour);
            local remaining = armour - damageArmour;
            local damageRegular = regular * (ancient ? weapon.ancient : 1.0);
            local damage = ::Math.maxf(0.0, damageRegular * weapon.direct - remaining * 0.1);
            if (remaining <= 0)
                damage += ::Math.max(0, damageRegular * (1.0 - weapon.direct) - damageArmour);
            hp += ::Math.maxf(weapon.minimum, ::Math.round(damage));
            removed += damageArmour;
            count++;
        }
    return {hp = hp / count, armour = removed / count};
};

::BroLedger.exampleCrossover <- function(baseDamage, damage, bonus, defence)
{
    local ranges = [], start = null;
    // Return every winning interval; hit caps can reverse a low-skill advantage.
    for (local attack = 0; attack <= 151; attack++)
    {
        local wins = attack <= 150 && this.exampleHit(attack, bonus, defence) * damage >
            this.exampleHit(attack, 20, defence) * baseDamage + 0.0001;
        if (wins && start == null) start = attack;
        if (!wins && start != null) { ranges.push([start, attack - 1]); start = null; }
    }
    return ranges;
};

::BroLedger.weaponComparisons <- function(attack)
{
    if (!this.number(attack)) return null;
    local out = {attack = attack, matches = [],
        assumptions = "Ordinary 1H weapon switch examples at this brother's natural Melee Skill. Shield held; no mastery, Double Grip, Duelist, damage perks or trait modifiers. One attack, body hit only, 10 defence, no target shield or Shieldwall. Other accuracy modifiers are zero. These reference targets are not enemy predictions.",
        limits = "Expected immediate HP and armour removed per attempt, including misses; armour resets for each example. No headshots, bleed, stuns, morale, injuries, kills or later attacks are valued. All attacks cost 4 AP. Fatigue shows base / with relevant mastery. Winning skill intervals cover 0-150 and compare only immediate HP against Fighting Spear; armour removal can favour a different choice. Equip and choose the build yourself."};
    foreach (target in [
        {label = "Unarmoured living", armour = 0, ancient = false},
        {label = "Armoured living", armour = 100, ancient = false},
        {label = "Ancient Dead", armour = 100, ancient = true}
    ])
    {
        local match = {label = target.label, armour = target.armour, rows = []};
        local reference = this.exampleDamage(this.WeaponExamples[0], target.armour, target.ancient);
        foreach (index, weapon in this.WeaponExamples)
        {
            local damage = index == 0 ? reference : this.exampleDamage(weapon, target.armour, target.ancient);
            local hit = this.exampleHit(attack, weapon.hit, 10);
            match.rows.push({name = weapon.name, hit = hit * 100, hp = hit * damage.hp, armour = hit * damage.armour,
                fat = weapon.fat, masteredFat = ::Math.ceil(weapon.fat * 0.75),
                wins = index == 0 ? null : this.exampleCrossover(reference.hp, damage.hp, weapon.hit, 10)});
        }
        out.matches.push(match);
    }
    return out;
};
