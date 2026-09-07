local B=::BroLedger, cases={}, defs=dofile("tests/perk_unlocks.nut");

cases.brawny_rounding_and_raw_nimble <- function() {
    check(B.armourCost(-11,-31,true)==29,"head ceil/body floor mismatch");
    check(B.armourCost(-1,-1,true)==1,"negative fractional boundary");
    local p=B.makePlan(B.findBuild("forged_neutral_axe")),g=gearFixture(); g.brawny=true;
    local r=B.equipmentAdvice(g,p,{});
    check(r.rawArmour==40 && r.effectiveArmour==28,"raw Nimble and Brawny weight conflated");
};

cases.actual_and_conditional_capacity <- function() {
    local p=B.makePlan(B.findBuild("forged_neutral_axe")),g=gearFixture();
    g.actions["actives.split_man"]<-{name="Split Man",fat=18,ap=6};
    local r=B.equipmentAdvice(g,p,{["perk.pathfinder"]=true});
    check(r.cycles[0].currentFat==21 && r.cycles[0].projectedFat==15,"instance cost replaced by generic cost");
    check(r.cycles[0].armourBudget==60,"other weapon/bag costs dropped from budget");
    check(r.headroom==37 && r.capacity==45,"headroom substituted for capacity");
    g.recovery=12;
    check(B.equipmentAdvice(g,p,{}).cycles[0].reserve==31,"Asthmatic recurrence ignored");
    g.mult=0.6; g.stamina=75;
    r=B.equipmentAdvice(g,p,{});
    check(r.cycles[0].armourBudget==63,"stamina multiplier not inverted for armour allowance");
};

cases.catalog_action_corrections <- function() {
    local g=gearFixture();
    local bow=B.makePlan(B.findBuild("nimble_bow_thrower"));
    local cycles=B.equipmentAdvice(g,bow,{}).cycles;
    check(cycles.len()==3 && cycles[0].projectedFat==24 && cycles[1].projectedFat==15 && cycles[2].projectedFat==24,"bow still throw-only");
    local hammer=B.makePlan(B.findBuild("bf_2h_hammer_berserk"));
    hammer.route.remove(hammer.route.find("perk.berserk"));
    cycles=B.equipmentAdvice(g,hammer,{}).cycles;
    check(!cycles[0].projectedLegal && cycles[1].projectedLegal,"removed Berserk still funded AP");
    local gun=B.makePlan(B.findBuild("pure_handgonne"));
    cycles=B.equipmentAdvice(g,gun,{}).cycles;
    check(cycles[0].projectedAP==9 && cycles[0].projectedFat==19,"gun fire/reload wrong");
    check(!("matk" in gun.targets) && !("mdef" in gun.targets),"pure gun route inherited melee targets");
};

cases.reference_comparisons_obey_hit_caps_and_conditional_crossovers <- function() {
    local c=B.weaponComparisons(60),rows=c.matches[0].rows;
    check(c.matches.len()==3 && rows.len()==8,"bounded matchups or named alternatives missing");
    check(fabs(rows[0].hit-70)<0.001 && fabs(rows[1].hit-60)<0.001 && fabs(rows[3].hit-50)<0.001,"attack hit bonuses conflated with natural skill");
    // Native integer max truncates non-penetrating damage before final rounding.
    check(fabs(rows[0].hp-26.133333)<0.0001 && fabs(rows[1].hp-25.3)<0.0001,"damage rounding lost");
    check(rows[1].wins.len()==1 && rows[1].wins[0][0]==78 && rows[1].wins[0][1]==150,
        "Arming Sword crossover must use the disclosed item, target and hit caps");
    check(rows[2].wins[0][0]==38 && rows[5].wins.len()==0,"item tier or lower damage ignored");
    check(B.exampleHit(-20,20,10)==0.05 && B.exampleHit(200,20,10)==0.95,"hit caps missing");
    local reversed=B.exampleCrossover(40,41,0,30);
    check(reversed.len()==2 && reversed[0][1]<reversed[1][0],"cap-induced reversal collapsed into a universal threshold");
    check(B.weaponComparisons(null)==null,"unknown attack supplied a threshold");
};

cases.damage_applies_resistance_to_hp_and_mitigation_after_armour <- function() {
    local weapon={low=40,high=40,armour=1.0,direct=0.25,minimum=0,ancient=0.5};
    local living=B.exampleDamage(weapon,60,false),dead=B.exampleDamage(weapon,60,true);
    check(living.hp==8 && dead.hp==3 && living.armour==40 && dead.armour==40,
        "remaining-armour mitigation or HP-only racial resistance wrong");
    check(B.exampleDamage(weapon,20,false).hp==20,"overflow subtracts unbounded rolled armour damage");
    weapon.minimum=10;check(B.exampleDamage(weapon,500,false).hp==10,"Batter's HP floor lost");
    local c=B.weaponComparisons(60),livingRows=c.matches[1].rows,deadRows=c.matches[2].rows;
    check(livingRows[0].hp>deadRows[0].hp && livingRows[0].armour==deadRows[0].armour,
        "Ancient Dead resistance reduced armour damage");
    check(livingRows[1].hp==deadRows[1].hp,"Slash inherited piercing resistance");
};

cases.all_current_patterns_have_legal_ap_and_specific_mastery_costs <- function() {
    foreach(b in B.Builds) foreach(c in B.equipmentAdvice(gearFixture(),B.makePlan(b),{}).cycles)
        check(c.projectedLegal,"illegal catalog cycle: "+b.id+"/"+c.label);
    foreach(pair in [["tempo_spear",8,20],["tempo_flail",8,20],["shield_hammer",8,38],
        ["puncture_dagger",9,45],["estoc_skewer",9,28],["estoc_perforate",9,28],["pollaxe",5,12],
        ["mace_qatal",9,23],["pure_crossbow",7,19],["pure_handgonne",9,19]]) {
        local c=B.equipmentAdvice(gearFixture(),B.makePlan(B.findBuild(pair[0])),{}).cycles[0];
        check(c.projectedAP==pair[1] && c.projectedFat==pair[2],"wrong cost/mastery: "+pair[0]);
    }
    local whip=B.equipmentAdvice(gearFixture(),B.makePlan(B.findBuild("cleaver_whip")),{}).cycles[1];
    check(whip.projectedAP==9 && whip.projectedFat==32 && whip.turns==1,"whip combo promises repeated free swaps");
    local mace=B.equipmentAdvice(gearFixture(),B.makePlan(B.findBuild("mace_qatal")),{}).cycles[0];
    check(mace.turns==1,"Mace-Qatal burst repeats two swaps per turn");
};

cases.shared_smite_id_does_not_match_another_weapon <- function() {
    local g=gearFixture(),p=B.makePlan(B.findBuild("pollaxe"));
    g.actions["actives.smite"]<-{fat=12,ap=6,polearm=false};
    check(B.equipmentAdvice(g,p,{}).cycles[0].currentFat==null,"Hammer Smite represented a Pollaxe loadout");
    g.actions["actives.smite"]={fat=9,ap=5,polearm=true};
    check(B.equipmentAdvice(g,p,{}).cycles[0].currentFat==9,"matching named Pollaxe lost its live costs");
    p=B.makePlan(B.findBuild("nimble_2h_axe"));p.route.push("perk.mastery.mace");
    p.route.remove(p.route.find("perk.mastery.axe"));
    check(B.equipmentAdvice(g,p,{}).cycles[0].projectedFat==15,"new Axe action silently inherited Mace Mastery");
};

cases.capacity_not_recovery <- function()
{
    check(B.reserve(15, 15, 1, 10)==25, "neutral action reserve");
    check(B.reserve(30, 15, 3, 0)==60, "burst recurrence");
    check(B.reserve(15, 12, 3, 10)==31, "asthmatic recovery ignored");
    check(B.reserve(15, 14.5, 3, 10)==26, "fractional recovery truncated");
};
return cases;
