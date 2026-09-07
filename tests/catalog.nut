local B=::BroLedger, cases={}, defs=dofile("tests/perk_unlocks.nut");

cases.weapon_destinations_are_deliberate <- function() {
    check(B.Builds.len()==44,"curated catalog must expose all 44 destinations");
    foreach(id in ["nimble_2h_berserk","dodge_qh_axe","early_tempo","double_gunner","tempo_hybrid_thrower","nimble_polearm"])
        check(B.findBuild(id)==null,"mixed legacy destination still selectable: "+id);
    foreach(b in B.Builds) {
        check(b.role.len()>0 && b.weaponTags.len()>0 && typeof b.stopgap=="bool","missing filters or phase");
        foreach(o in b.swaps)
            check(o.replace.find("perk.mastery.")!=0 && o.with.find("perk.mastery.")!=0,"weapon identity still changes via mastery swap");
    }
};

cases.new_weapon_masteries_and_pure_ranged_requirements <- function() {
    foreach(pair in [["estoc_skewer","dagger"],["estoc_perforate","dagger"],["pollaxe","polearm"],["executioner_sword","sword"]]) {
        local b=B.findBuild(pair[0]);
        check(b.route.find("perk.mastery."+pair[1])!=null,"wrong mastery: "+pair[0]);
    }
    foreach(id in ["pure_bow","pure_crossbow","pure_handgonne","nimble_thrower","handgonne_thrower","crossbow_thrower","nimble_bow_thrower"]) {
        local b=B.findBuild(id);
        check(!("matk" in b.targets) && !("matk" in b.preferred) && !("mdef" in b.targets),"ranged build inherits melee requirements");
    }
};

cases.acquired_mastery_cannot_change_destination <- function() {
    local b=B.findBuild("nimble_2h_axe"),s=fixture();s.perks["perk.mastery.mace"]<-true;s.spent=1;
    local p=B.makePlan(b),before=B.copy(p),q=B.guidancePlan(p,s);
    check(q.route.find("perk.mastery.axe")!=null && q.route.find("perk.mastery.mace")==null,"Mace acquisition rewrote Axe identity");
    check(B.route(q,s,defs).offplan.find("perk.mastery.mace")!=null && same(p,before),"off-plan fact lost or saved intent changed");
};

return cases;
