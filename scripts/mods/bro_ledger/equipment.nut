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
