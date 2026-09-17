// Perk-adjusted stat reach.
//
// Native source (data_001.dat, build 23856902) carries exactly two perks that scale a tracked
// base attribute, both retroactive on the maximum:
//   perk.colossus       Hitpoints x1.25   (onUpdate -> HitpointsMax, Math.floor)
//   perk.fortified_mind Bravery   x1.25   (onUpdate -> BraveryMult)
// Every other perk's Mult/Max write targets damage, morale or armour, not a planner stat.
// Brawny has no property hook at all; it changes equipment fatigue weight.
//
// Contract under test:
//   snapshot.perkScale[k]  multiplier from ACQUIRED perks      -> what the bro has now
//   snapshot.planScale[k]  acquired + perks in plan.route      -> what the build will reach
//   B.currentStat(s,k)     current sheet value (acquired only)
//   B.endpoint(...)        projection math (planned scale)
// Targets are read as final sheet values, so a build that plans Colossus is judged on the
// hitpoints it will actually have.
local B=::BroLedger, cases={}, defs=dofile("tests/perk_unlocks.nut");

// Asgeir, the live case that exposed this: level 7, natural 66 HP, Colossus already taken,
// tracked build wants 100 HP. The sheet reads 82; the planner reads 66 and calls 100 impossible.
local function asgeirActor(perks=["perk.colossus"]) {
    local a=actorFixture();
    a.natural.Hitpoints=66;a.natural.Bravery=51;
    a.level=7;a.pending=0;a.free=0;a.spent=perks.len();
    a.skills=[];foreach(id in perks) a.skills.push(skill(id,::Const.SkillType.Perk));
    return a;
}
// A plan whose route is exactly the given perks.
local function planFor(route, targets, preferred, weights=null) {
    local b=userBuild();b.route=B.copy(route);b.flex=[];b.targets=B.copy(targets);b.preferred=B.copy(preferred);
    if(weights!=null) b.weights=B.copy(weights);
    return B.makePlan(b);
}
local function rowFor(assessment, key) {
    foreach(row in assessment.statRows) if(row.key==key) return row;
    return null;
}

cases.stat_perks_are_exactly_the_two_native_attribute_multipliers <- function() {
    check("StatPerks" in B,"no StatPerks table: perk stat effects are undefined");
    local ids=[];foreach(id,_ in B.StatPerks) ids.push(id);ids.sort();
    check(same(ids,["perk.colossus","perk.fortified_mind"]),"StatPerks does not match the two native attribute multipliers");
    check(same(B.StatPerks["perk.colossus"],{hp=1.25}),"Colossus is not hitpoints x1.25");
    check(same(B.StatPerks["perk.fortified_mind"],{resolve=1.25}),"Fortified Mind is not resolve x1.25");
    // Perks that merely look stat-like must stay out: Brawny is equipment fatigue weight,
    // Steel Brow is head-hit damage, Dodge and Nimble are already separate live effects.
    foreach(id in ["perk.brawny","perk.steel_brow","perk.dodge","perk.nimble","perk.battle_forged","perk.fearsome"])
        check(!(id in B.StatPerks),id+" wrongly treated as a base-attribute multiplier");
};

cases.acquired_perks_adjust_the_current_sheet_value <- function() {
    local s=B.readActor(asgeirActor(["perk.colossus"]));
    // The game's own sheet shows 82 for this brother. floor(66 * 1.25) = 82.
    check(B.currentStat(s,"hp")==82,"acquired Colossus did not raise current hitpoints to the sheet value");
    check(s.stats.hp==82,"snapshot current hitpoints still report the pre-perk value");
    check(B.currentStat(s,"resolve")==51,"Colossus leaked into resolve");
    local f=B.readActor(asgeirActor(["perk.fortified_mind"]));
    check(B.currentStat(f,"resolve")==63,"acquired Fortified Mind did not raise current resolve");
    check(B.currentStat(f,"hp")==66,"Fortified Mind leaked into hitpoints");
    local both=B.readActor(asgeirActor(["perk.colossus","perk.fortified_mind"]));
    check(B.currentStat(both,"hp")==82 && B.currentStat(both,"resolve")==63,"stacked perks did not apply independently");
    local none=B.readActor(asgeirActor([]));
    check(B.currentStat(none,"hp")==66 && B.currentStat(none,"resolve")==51,"unperked brother changed");
};

cases.acquired_perks_raise_the_reachable_maximum <- function() {
    local s=B.readActor(asgeirActor(["perk.colossus"]));
    // Level 7 -> 11 is four rows; maximum hitpoints roll is 4.
    check(B.endpoint(s,"hp",0,0,0)==82,"perk-adjusted current endpoint wrong");
    check(B.endpoint(s,"hp",4,0,0,"high")==102,"acquired Colossus did not raise the reachable maximum");
    local none=B.readActor(asgeirActor([]));
    check(B.endpoint(none,"hp",4,0,0,"high")==82,"unperked maximum changed");
};

cases.planned_perks_raise_the_maximum_but_never_the_current_value <- function() {
    local s=B.readActor(asgeirActor([]));           // has not taken Colossus yet
    local plan=planFor(["perk.colossus"],{hp=70},{hp=100});
    local p=B.forPlan(s,plan);
    check(B.currentStat(p,"hp")==66,"a merely planned perk was counted as already acquired");
    check(B.endpoint(p,"hp",4,0,0,"high")==102,"a planned perk did not raise the reachable maximum");
    // A perk that is neither acquired nor routed must not count.
    local bare=B.forPlan(s,planFor([],{hp=70},{hp=100}));
    check(B.endpoint(bare,"hp",4,0,0,"high")==82,"an unrouted perk was counted");
};

cases.asgeir_hp_goal_is_reachable_instead_of_impossible <- function() {
    // The reported bug, end to end: ideal 100, Colossus acquired, panel paints it red.
    local s=B.readActor(asgeirActor(["perk.colossus"]));
    local plan=planFor(["perk.colossus"],{hp=70},{hp=100},{hp=10,resolve=0,fatigue=0,initiative=0,matk=0,ratk=0,mdef=0,rdef=0});
    local row=rowFor(B.assess(B.forPlan(s,plan),plan,B.planPreferred(plan)),"hp");
    check(row.now==82,"lateral panel still shows the pre-perk current value");
    check(row.maximum==102,"reachable maximum ignores Colossus");
    check(row.idealState=="grow","a reachable goal is still painted impossible");
};

cases.builds_without_stat_perks_are_unchanged <- function() {
    // Hélder's requirement: no stat-modifier perk in the build means business as usual.
    local s=B.readActor(asgeirActor([]));
    local plan=planFor(["perk.dodge","perk.underdog"],{hp=70},{hp=100},{hp=10,resolve=0,fatigue=0,initiative=0,matk=0,ratk=0,mdef=0,rdef=0});
    local row=rowFor(B.assess(B.forPlan(s,plan),plan,B.planPreferred(plan)),"hp");
    check(row.now==66 && row.maximum==82,"a build with no stat perks changed its numbers");
    check(row.idealState=="impossible","a genuinely unreachable goal stopped being impossible");
    foreach(k in B.Stats) check(B.forPlan(s,plan).planScale[k]==1.0,k+" gained a phantom multiplier");
};

cases.ideal_state_colours_follow_the_perk_adjusted_values <- function() {
    local weights={hp=10,resolve=0,fatigue=0,initiative=0,matk=0,ratk=0,mdef=0,rdef=0};
    // Already reached only once the acquired perk is counted: 66 < 80 <= 82.
    local acquired=B.readActor(asgeirActor(["perk.colossus"]));
    local metPlan=planFor(["perk.colossus"],{hp=60},{hp=80},weights);
    check(rowFor(B.assess(B.forPlan(acquired,metPlan),metPlan,B.planPreferred(metPlan)),"hp").idealState=="met",
        "an already reached goal is not marked met");
    // Still impossible even with the perk: 102 < 110.
    local hardPlan=planFor(["perk.colossus"],{hp=60},{hp=110},weights);
    check(rowFor(B.assess(B.forPlan(acquired,hardPlan),hardPlan,B.planPreferred(hardPlan)),"hp").idealState=="impossible",
        "a goal beyond even the perk-adjusted maximum is no longer impossible");
    // Planned, not yet taken: must stay a growth goal, never met.
    local future=B.readActor(asgeirActor([]));
    local growPlan=planFor(["perk.colossus"],{hp=60},{hp=80},weights);
    check(rowFor(B.assess(B.forPlan(future,growPlan),growPlan,B.planPreferred(growPlan)),"hp").idealState=="grow",
        "a planned perk was treated as already delivering its goal");
};

cases.potential_score_rewards_builds_that_plan_the_right_perk <- function() {
    // "some builds would fit really well to a bro": the score must see the perk coming.
    local s=B.readActor(asgeirActor([]));
    local weights={hp=10,resolve=0,fatigue=0,initiative=0,matk=0,ratk=0,mdef=0,rdef=0};
    local plain=planFor(["perk.dodge"],{hp=70},{hp=100},weights);
    local colossal=planFor(["perk.colossus"],{hp=70},{hp=100},weights);
    local a=B.assess(B.forPlan(s,plain),plain,B.planPreferred(plain));
    local b=B.assess(B.forPlan(s,colossal),colossal,B.planPreferred(colossal));
    // Average rolls: 66 + 4*3 = 78, and floor(78 * 1.25) = 97.
    check(a.projection.stats.hp==78,"unperked forecast changed");
    check(b.projection.stats.hp==97,"perk-aware forecast did not apply the planned multiplier");
    check(a.score==63.33,"unperked score changed");
    check(b.score==95.0,"planned perk did not improve the fit score");
    check(b.score>a.score,"the perk-planning build does not rank higher");
};

cases.perk_attribution_is_exposed_for_the_icon <- function() {
    local weights={hp=10,resolve=2,fatigue=0,initiative=0,matk=0,ratk=0,mdef=0,rdef=0};
    local s=B.readActor(asgeirActor(["perk.colossus"]));
    local plan=planFor(["perk.colossus","perk.fortified_mind"],{hp=70,resolve=40},{hp=100,resolve=60},weights);
    local e=B.assess(B.forPlan(s,plan),plan,B.planPreferred(plan));
    local hp=rowFor(e,"hp"),resolve=rowFor(e,"resolve"),fatigue=rowFor(e,"fatigue");
    check(same(hp.statPerks,[{id="perk.colossus",acquired=true}]),"acquired Colossus is not attributed to hitpoints");
    check(same(resolve.statPerks,[{id="perk.fortified_mind",acquired=false}]),"planned Fortified Mind is not attributed to resolve");
    check(same(fatigue.statPerks,[]),"an unaffected stat carries perk attribution");
    // Attribution must name a real perk so the UI can resolve its icon.
    foreach(entry in hp.statPerks) check(entry.id in defs,"attributed perk is not a known definition");
};

cases.perk_scale_composes_with_injuries_and_survives_legacy_snapshots <- function() {
    // Weakened heart x0.7 and Colossus x1.25 on 60 natural hitpoints: floor(60*0.7*1.25) = 52,
    // and the same either way round, so this pins the value without pinning an unverified order.
    local a=asgeirActor(["perk.colossus"]);
    a.natural.Hitpoints=60;a.skills.push(skill("injury.weakened_heart",::Const.SkillType.PermanentInjury));
    check(B.currentStat(B.readActor(a),"hp")==52,"perk multiplier does not compose with a permanent injury");
    // Hand-built and saved snapshots predate perkScale; they must read as unperked, not crash.
    local legacy=fixture();legacy.stats.hp=70;legacy.rawStats=legacy.stats;
    check(B.endpoint(legacy,"hp")==70 && B.currentStat(legacy,"hp")==70,"a snapshot without perk scales stopped working");
};

return cases;
