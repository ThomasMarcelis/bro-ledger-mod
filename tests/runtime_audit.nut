// OPTIONAL DISPOSABLE-CAMPAIGN OBSERVER. Never included in the player ZIP.
local audit=::Hooks.register("mod_bro_ledger_audit","0.1.0","Bro Build Planner runtime audit");
audit.require("mod_bro_ledger >= 0.1.0");
audit.queue(">mod_bro_ledger",function() {
    ::BroLedger.Audit <- {active=false,calls=0,rng=0};
    local random=::Math.rand;
    ::Math.rand=function(min,max) {
        if (::BroLedger.Audit.active) ::BroLedger.Audit.rng++;
        return random(min,max);
    };
    ::BroLedger.auditFacts <- function(actor) {
        local s=this.readActor(actor),equipment=this.readEquipment(actor),facts=[];
        foreach (k in this.Stats) { facts.push(s.stats[k]); facts.push(s.stars[k]); }
        foreach (v in [actor.getName(),s.level,s.pending,s.free,s.spent,actor.getHitpoints(),actor.getFatigue(),actor.getActionPoints(),
            equipment.capacity,equipment.head,equipment.body,equipment.headArmour,equipment.bodyArmour]) facts.push(v);
        local perks=[];foreach (id,_ in s.perks) perks.push(id);perks.sort();foreach (id in perks) facts.push(id);
        foreach (item in equipment.items) { facts.push(item.name);facts.push(item.raw);facts.push(item.bag); }
        return facts;
    };
    local command=::BroLedger.command;
    ::BroLedger.command=function(screen,data) {
        local actor=typeof data=="table" && "actor" in data ? this.ownedActor(data.actor) : null;
        if (actor==null) return command(screen,data);
        local before=this.auditFacts(actor),a=this.Audit;
        a.calls=0;a.rng=0;a.active=true;
        local result;
        try { result=command(screen,data); }
        catch(e) { a.active=false;throw e; }
        a.active=false;
        local after=this.auditFacts(actor),same=before.len()==after.len();
        if (same) foreach (i,v in before) if (after[i]!=v) same=false;
        ::logInfo("BRO_LEDGER_AUDIT actor="+actor.getID()+" action="+data.action+" sameFacts="+same+" mutators="+a.calls+" rng="+a.rng);
        return result;
    };
});
// Count only during our handler, forwarding every original call unchanged.
audit.hook("scripts/entity/tactical/player",function(q) {
    foreach (method in ["unlockPerk","setAttributeLevelUpValues","setName","setTitle","setPerkPoints"])
        q[method]=@(__original) function(...) {
            if ("Audit" in ::BroLedger && ::BroLedger.Audit.active) ::BroLedger.Audit.calls++;
            return __original.acall([this].extend(vargv));
        };
});
audit.hook("scripts/entity/tactical/actor",function(q) {
    foreach (method in ["setHitpoints","setFatigue","setActionPoints","setCurrentProperties"])
        q[method]=@(__original) function(...) {
            if ("Audit" in ::BroLedger && ::BroLedger.Audit.active) ::BroLedger.Audit.calls++;
            return __original.acall([this].extend(vargv));
        };
});
audit.hook("scripts/items/item_container",function(q) {
    foreach (method in ["equip","unequip","addToBag","removeFromBag"])
        q[method]=@(__original) function(...) {
            if ("Audit" in ::BroLedger && ::BroLedger.Audit.active) ::BroLedger.Audit.calls++;
            return __original.acall([this].extend(vargv));
        };
});
