local B=::BroLedger, cases={}, defs=dofile("tests/perk_unlocks.nut");

cases.perk_definitions_retain_live_tree_positions_without_mutation <- function() {
    local tree=[
        [{ID="perk.z",Name="Zulu",Unlocks=0,Icon="z.png"}, {ID="perk.a",Name="Alpha",Unlocks=0}],
        [], [{ID="perk.m",Name="Middle",Unlocks=0,Icon="m.png"}], [], [], [], []
    ];
    ::Const <- {Perks={Perks=tree}};
    local before=B.copy(tree), actual=B.perkDefs();
    check(actual.len()==3,"defined perks lost or empty padding emitted");
    foreach(row,perks in tree) foreach(column,perk in perks) {
        local def=actual[perk.ID];
        check("row" in def && "column" in def,"live perk position discarded");
        check(def.row==row && def.column==column,"tree position inferred from name or unlock");
        check(def.name==perk.Name && def.unlock==perk.Unlocks,"definition changed");
        check(def.icon==("Icon" in perk ? perk.Icon : null),"optional icon changed");
    }
    check(same(tree,before),"definition read mutated native tree");
};

cases.normalization_once <- function() {
    local raw=fixture().stats; raw.hp=60; raw.fatigue=100;
    local skills={["trait.strong"]=true,["trait.tough"]=true,["perk.colossus"]=true,["perk.fortified_mind"]=true};
    local n=B.normalize(raw,skills);
    check(n.stats.hp==70 && n.stats.fatigue==110 && raw.hp==60,"lasting gains or multipliers counted twice");
    skills["injury.weakened_heart"]<-true; skills["injury.collapsed_lung_part"]<-true;
    n=B.normalize(raw,skills);
    check(n.stats.hp==49 && n.stats.fatigue==66,"permanent injury not applied to natural stats");
    local s=fixture();s.scale=n.scale;s.stats=n.stats;s.rawStats=n.rawStats;
    check(B.endpoint(s,"hp",1)==51,"future raw growth missed native injury rounding");
};

cases.reader_maps_all_eight_talents_without_changing_actor <- function() {
    local a=actorFixture();a.talents=[0,1,2,3,null,3,2,1];
    local before=clone a.talents,s=B.readActor(a);
    check(s.stars.len()==8,"talent mapping omitted an attribute");
    foreach(i,k in B.Stats)
        check(s.stars[k]==before[i] && a.talents[i]==before[i],"talent mapped to wrong attribute or mutated: "+k);
    foreach(bad in [null,-1,4,1.0,1.5,"3",true,[],{}]) {
        a.talents=array(8,bad);before=B.copy(a.talents);s=B.readActor(a);
        foreach(k in B.Stats) check(s.stars[k]==null,"malformed talent manufactured: "+k);
        check(same(a.talents,before),"validation changed actor talents");
    }
    foreach(missing in [null,[],{}]) {
        a.talents=missing;s=B.readActor(a);
        foreach(k in B.Stats) check(s.stars[k]==null,"missing talents became zero");
    }
};

cases.manhunters_indebted_cap_and_student_refund <- function() {
    local a=actorFixture();a.origin="scenario.manhunters";a.background="background.slave";
    a.level=7;a.pending=0;a.spent=6;a.free=0;
    local s=B.readActor(a);
    check(s.normalRows==0 && s.veteranRows==0 && s.futurePerks==0,"capped Indebted given unearnable levels");
    a.skills.push(skill("perk.student",1));a.free=1;
    check(B.readActor(a).futurePerks==0,"already-refunded Student counted again at cap");
    a.level=6;a.pending=1;a.free=0;
    s=B.readActor(a);
    check(s.normalRows==2 && s.veteranRows==0 && s.futurePerks==2,"approaching-cap rows/refund wrong");
    a.skills.clear();check(B.readActor(a).futurePerks==1,"Student refund without Student");
    a.background="background.militia";check(B.readActor(a).futurePerks==5,"free Manhunter capped");
    a.background="background.slave";a.origin="scenario.tutorial";
    check(B.readActor(a).futurePerks==5,"Indebted capped outside Manhunters");
};

cases.reader_stored_student_veteran_and_gifted <- function() {
    local a=actorFixture(),s=B.readActor(a);
    check(s.normalRows==10 && s.veteranRows==0 && s.futurePerks==8,"stored ordinary horizon wrong");
    a.skills.push(skill("perk.student",1));a.spent=1;a.free=1;
    check(B.readActor(a).futurePerks==9,"Student refund omitted");
    a.level=13;a.pending=3;a.spent=11;
    s=B.readActor(a);check(s.normalRows==1 && s.veteranRows==2 && s.futurePerks==0,"stored/veteran partition wrong");
    a.skills.push(skill("perk.gifted",1));
    check(!B.readActor(a).growthKnown,"Gifted history invented without current offer");
    local dto={levelUp={}};
    foreach(k,fields in B.Fields) dto.levelUp[fields[1]+"Increase"]<-1;
    a.pending=2;B.captureOffer(a,dto);
    s=B.readActor(a);check(s.growthKnown && s.normalRows==0 && s.veteranRows==2,"visible veterans did not resolve spent Gifted");
    a.level=10;a.pending=2;
    foreach(i,k in B.Stats) dto.levelUp[B.Fields[k][1]+"Increase"]=::Const.AttributesLevelUp[i].Max;
    B.captureOffer(a,dto);check(!B.readActor(a).growthKnown,"ambiguous maximum row was claimed as known");
    dto.levelUp.hitpointsIncrease=2;B.captureOffer(a,dto);
    check(B.readActor(a).growthKnown,"non-Gifted visible row not recognized");
    a.pending=0;check(B.readActor(a).growthKnown,"allocated Gifted remained uncertain");
};

cases.reader_natural_and_current_separate_nonmutation <- function() {
    local a=actorFixture();a.skills.push(skill("trait.strong",2));a.skills.push(skill("trait.tough",2));
    a.skills.push(skill("effects.kraken_potion",8));a.skills.push(skill("effects.apotheosis_potion",8));
    a.skills.push(skill("effects.cat_potion",8));
    ::Math.rand <- function(...){throw "RNG called";};
    local s=B.readActor(a);
    check(s.stats.hp==121 && s.stats.fatigue==111 && s.stats.initiative==100,"permanent/temporary effect normalization wrong");
    check(a.natural.Hitpoints==60 && a.natural.Stamina==100 && a.pending==2 && a.fatigue==17,"reader mutated gameplay");
    a.capacity=40;a.fatigue=39;
    local later=B.readActor(a);
    check(later.stats.hp==s.stats.hp && later.stats.fatigue==s.stats.fatigue,"equipment/fatigue changed natural potential");
    a.talents[6]=null;check(B.gain(B.readActor(a),"mdef","mean")==null,"unknown talent manufactured");
};

cases.fat_initiative_uses_native_final_capacity_loss <- function() {
    local a=actorFixture();a.natural.Initiative=108;
    a.skills.push(skill("trait.fat",2));
    local s=B.readActor(a);
    check(s.stats.initiative==98 && s.stats.fatigue==90,"Fat: native rested Initiative is 98, not 108");
    a.natural.InitiativeMult<-0.75;
    check(B.readActor(a).stats.initiative==71,"capacity loss must follow Initiative multiplier");
    a.skills.push(skill("injury.collapsed_lung_part",4));
    check(B.readActor(a).stats.initiative==71,"Stamina multiplier incorrectly counted as native additive loss");
    a.skills.push(skill("trait.strong",2));
    check(B.readActor(a).stats.initiative==81,"Strong offsets Fat's additive Stamina loss");
    check(a.natural.Initiative==108 && a.natural.Stamina==100,"reader changed base properties");
};

cases.native_initiative_rounding <- function() {
    local a=actorFixture();a.natural.Initiative=155;a.skills.push(skill("injury.missing_ear",4));
    check(B.readActor(a).stats.initiative==140,"Missing Ear155 must round139.5 to140");
    a=actorFixture();a.natural.Initiative=108;a.natural.InitiativeMult<-0.75;a.skills.push(skill("trait.old",2));
    check(B.readActor(a).stats.initiative==64,"Old multiplier must round63.5 to64 after Stamina loss");
    a.skills.clear();a.skills.push(skill("trait.fat",2));a.natural.StaminaMult<-0.6;
    check(B.readActor(a).stats.initiative==71,"Fat multiplier or additive Stamina deduction changed");
    foreach(pair in [[108.65,71],[108.666667,72],[108.68,72]])
    {
        a.natural.Initiative=pair[0];
        check(B.readActor(a).stats.initiative==pair[1],"Initiative half boundary rounded at the wrong stage");
    }
};

cases.live_reads_distinguish_absent_unknown_and_zero <- function() {
    ::Const <- {BodyPart={Head=0,Body=1}};
    local perks={},a={getInitiative=@() 99,getArmor=@(part) part==0 ? 43 : 58,
        getSkills=@() {getSkillByID=@(id) id=="perk.nimble" ? {getChance=@() 0.47} : null}};
    local e=B.currentEffects(a,perks);
    foreach(k in ["dodge","nimble","battleForged"])check(!e[k].owned && e[k].value==null,"planned/unowned perk active");
    foreach(id in ["perk.dodge","perk.nimble","perk.battle_forged"])perks[id]<-true;
    e=B.currentEffects(a,perks);
    check(e.dodge.value==14 && e.nimble.value==53 && e.battleForged.value==5.1,
        "live contribution/HP reduction/current armour reduction wrong");
    a.getInitiative=@() -1;a.getArmor=@(part) 0;a.getSkills=@() {getSkillByID=@(id) {getChance=@() 1.0}};
    e=B.currentEffects(a,perks);
    foreach(k in ["dodge","nimble","battleForged"])check(e[k].owned && e[k].value==0,"zero effect became N/A");
    a.getInitiative=function(){throw "unreadable";};a.getArmor=@(part) null;
    a.getSkills=@() {getSkillByID=@(id) {}};
    e=B.currentEffects(a,perks);
    foreach(k in ["dodge","nimble","battleForged"])check(e[k].owned && e[k].value==null,"unknown became zero or N/A");
    a.getSkills=@() {getSkillByID=@(id) {getChance=@() 0.4}};
    check(B.currentEffects(a,perks).nimble.value==60,"one failed getter hid another valid effect");
};

return cases;
