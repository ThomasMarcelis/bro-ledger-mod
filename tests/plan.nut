local B=::BroLedger, cases={}, defs=dofile("tests/perk_unlocks.nut"), legacy=dofile("tests/legacy.nut");
function legacyPlan(id) {local p=B.makePlan(legacy[id]);p.revision=2;return p;}

cases.replacement_conflicts_and_sunk_perks <- function() {
    local p=legacyPlan("nimble_2h_berserk");
    local q=B.replacePlan(p,0,{});
    check(rejects(@() B.replacePlan(q,1,{})),"conflicting masteries accepted");
    check(rejects(@() B.replacePlan(p,0,{["perk.mastery.axe"]=true})),"acquired default refunded");
    check(B.replacePlan(q,0,{}).route.find("perk.mastery.axe")!=null,"cannot reverse unspent choice");
};

cases.permitted_support_can_fill_flex_without_dropping_identity <- function() {
    local b=B.findBuild("bf_2h_hammer_berserk"),s=calibratedBro(b);
    s.perks.clear();foreach(id in b.route) if(id!="perk.killing_frenzy") s.perks[id]<-true;
    s.perks["perk.gifted"]<-true;s.spent=10;s.free=0;
    local p=B.candidatePlan(b,s),e=B.evaluate(s,b,defs);
    check(B.validPlan(p) && p.route.find("perk.gifted")!=null && p.route.find("perk.killing_frenzy")==null,"spent Gifted not accommodated in explicit flex");
    check(e.grade=="S" && e.route.feasible,"suitable mature support perk caused a cliff");
    s.perks["perk.nimble"]<-true;s.spent++; // Extra point cannot repair this declared armour identity.
    check(B.evaluate(s,b,defs).grade=="D","opposite armour identity accepted as a valid Hammer build");
};

foreach(id in ["fencer","qatal_duelist"])
{
    local b=B.findBuild(id);
    cases["gifted_flex_"+id] <- function() {
        foreach(mature in [false,true])
        {
            local s=calibratedBro(b,false);
            s.perks.clear();s.stats.matk=b.targets.matk-3;
            // Fencer's nine-spent/one-free Initiative155 witness also needs the native +5 row.
            if(mature && b.id=="fencer") {s.stats.matk=b.targets.matk;s.stats.initiative=155;s.ranges.initiative=[3,5];}
            if(mature) foreach(perk in b.route) if(b.flex.find(perk)==null) s.perks[perk]<-true;
            local support=mature && b.id=="fencer" ? "perk.pathfinder" : "perk.steel_brow";
            s.perks[support]<-true;s.spent=s.perks.len();s.free=10-s.spent;
            local adapted=B.candidatePlan(b,s),e=B.evaluate(s,b,defs);
            check(adapted.route.find("perk.gifted")!=null,"stat-essential Gifted removed: "+b.id);
            check(B.validPlan(adapted) && e.route.feasible && e.grade=="B","legal Gifted fit lost: "+b.id);
            // Both declared slots must still accommodate acquired support; Gifted cannot add an eleventh point.
            s.perks["perk.nine_lives"]<-true;s.spent++;s.free--;
            adapted=B.candidatePlan(b,s);e=B.evaluate(s,b,defs);
            check(B.validPlan(adapted) && e.route.feasible && adapted.route.find(support)!=null &&
                adapted.route.find("perk.nine_lives")!=null && adapted.route.find("perk.gifted")==null,
                "multiple supports exceeded declared flex slots");
            check(!B.feasibility(B.forPlan(s,adapted),adapted.targets,"mean").feasible,"exhausted flex slots manufactured Gifted growth");
        }
    };
}

cases.gifted_needs_obtainable_capacity <- function() {
    local b=B.findBuild("nimble_2h_axe"),s=calibratedBro(b,false),p=B.makePlan(b);
    s.perks.clear();foreach(id in b.route) if(id!="perk.gifted") s.perks[id]<-true;
    s.perks["perk.steel_brow"]<-true;s.spent=10;s.free=0;s.stats.hp=b.targets.hp-4;
    check(!B.route(p,s,defs).feasible,"exhausted saved route witness changed");
    check(B.forPlan(s,p).giftRows==0 && !B.feasibility(B.forPlan(s,p),p.targets,"mean").feasible,
        "unobtainable Gifted supplied phantom tracked fit");
    s.free=1;check(B.forPlan(s,p).giftRows==1,"free Gifted point ignored");
    s.free=0;s.futurePerks=1;check(B.forPlan(s,p).giftRows==1,"future Gifted point ignored");
    s.perks["perk.gifted"]<-true;s.spent++;check(B.forPlan(s,p).giftRows==0,"acquired Gifted counted twice");
};

foreach(revision in [1,2])
    cases["saved_flex_revision_"+revision] <- function() {
        local b=legacy.nimble_2h_berserk,p=B.replacePlan(legacyPlan(b.id),0,{}),s=fixture();
        p.revision=revision;
        local intent=B.copy(p),build=B.copy(b),source=B.copy(s);
        local resolved=B.guidancePlan(p,s),flex=B.flexPerks(resolved,s,defs);
        check(resolved.route.find("perk.mastery.mace")!=null && B.validPlan(resolved),"unacquired saved choice discarded");
        foreach(id in ["perk.mastery.axe","perk.mastery.mace","perk.mastery.hammer"])
            check(flex.find(id)!=null,"saved unacquired variant hid a still-supported alternative: "+id);
        local available=B.copy(defs);delete available["perk.mastery.hammer"];
        check(B.flexPerks(resolved,s,available).find("perk.mastery.hammer")==null,"unavailable saved sibling marked");
        check(same(s,source),"unspent projection mutated actor source");
        foreach(earned in [["axe"],["mace"],["hammer"],["mace","axe"],["mace","hammer"],["axe","hammer"]]) {
            s=fixture();foreach(name in earned) s.perks["perk.mastery."+name]<-true;
            s.spent=earned.len();s.free=10-s.spent;s.futurePerks=0;source=B.copy(s);
            resolved=B.guidancePlan(p,s);flex=B.flexPerks(resolved,s,defs);
            local r=B.route(resolved,s,defs);
            check(resolved.route.len()==10 && B.validPlan(resolved) && r.acquired.len()==1 &&
                r.acquired[0]=="perk.mastery."+earned[0] && r.remaining.len()==9 && r.offplan.len()==earned.len()-1 &&
                r.feasible==(earned.len()==1),"earned mastery lost or two spent masteries collapsed into one point");
            foreach(id in ["perk.mastery.axe","perk.mastery.mace","perk.mastery.hammer"])
                check(flex.find(id)==null,"earned mastery slot still offers blue alternatives: "+id);
            check(same(s,source) && same(p,intent) && same(b,build),"guidance mutated actor source, saved intent or catalog");
        }
    };

cases.every_saved_option_counts_manual_acquisition_once <- function() {
    foreach(b in legacy) foreach(i,o in b.swaps) {
        local p=legacyPlan(b.id),s=fixture();
        s.perks[o.with]<-true;s.spent=1;
        local resolved=B.guidancePlan(p,s),r=B.route(resolved,s,defs);
        check(p.route.find(o.replace)!=null && p.swaps.len()==0,"refresh wrote saved option: "+b.id);
        check(resolved.route.len()==10 && resolved.route.find(o.with)!=null && resolved.route.find(o.replace)==null &&
            r.acquired.len()==1 && r.remaining.len()==9 && r.offplan.len()==0 && B.validPlan(resolved),
            "acquired option counted twice: "+b.id+" "+o.with);
    }
};

cases.support_flex_preserves_gifted_and_legacy_intent <- function() {
    local p=B.makePlan(B.findBuild("fencer")),s=fixture();
    s.perks["perk.steel_brow"]<-true;s.spent=1;
    local resolved=B.guidancePlan(p,s);
    check(resolved.route.find("perk.steel_brow")!=null && resolved.route.find("perk.gifted")!=null,
        "support choice not absorbed or Gifted unnecessarily removed");
    s.perks["perk.nine_lives"]<-true;s.spent=2;
    resolved=B.guidancePlan(p,s);
    check(resolved.route.len()==10 && resolved.route.find("perk.gifted")==null && B.forPlan(s,resolved).giftRows==0,
        "two acquired flex choices left phantom Gifted growth");
    check(p.route.find("perk.gifted")!=null && p.route.find("perk.steel_brow")==null,"guidance overwrote saved route");
    p.revision=1;resolved=B.guidancePlan(p,s);
    check(resolved.route.find("perk.steel_brow")==null,"new catalog flex silently changed older revision");
};

cases.current_support_respects_earned_choices_and_ten_point_budget <- function() {
    local b=B.findBuild("qatal_duelist"),p=B.makePlan(b),s=calibratedBro(b),intent=B.copy(p);
    s.perks.clear();foreach(id in p.route) if(id!="perk.killing_frenzy") s.perks[id]<-true;
    s.perks["perk.steel_brow"]<-true;s.spent=10;s.free=0;
    local q=B.guidancePlan(p,s),r=B.route(q,s,defs);
    check(r.feasible && r.offplan.len()==0 && q.route.len()==10,"support not absorbed in remaining flex slot");
    check(q.route.find("perk.gifted")!=null && B.forPlan(s,q).giftRows==0,"earned Gifted refunded or counted again");
    s.perks["perk.nine_lives"]<-true;s.spent++;
    q=B.guidancePlan(p,s);r=B.route(q,s,defs);
    check(r.offplan.len()==1 && q.route.len()==10 && same(p,intent),"earned flex refunded or saved intent changed");
};

cases.legacy_same_id_does_not_adopt_new_route_or_targets <- function() {
    foreach(id in ["qatal_duelist","double_gunner","nimble_2h_berserk"]) {
        local p=legacyPlan(id),before=B.copy(p),s=fixture();
        s.perks["perk.steel_brow"]<-true;s.spent=1;
        local q=B.guidancePlan(p,s);
        check(same(p,before) && same(q.route,p.route) && same(q.targets,p.targets) &&
            same(q.preferredTargets,p.preferredTargets) && q.label==p.label && q.revision==2,
            "legacy intent silently adopted revision-3 identity or support flex: "+id);
    }
};

cases.blue_nodes_respect_acquired_slots_and_definitions <- function() {
    local p=legacyPlan("nimble_2h_berserk"),s=fixture(),d=B.copy(defs);
    delete d["perk.mastery.hammer"];
    local flex=B.flexPerks(p,s,d);
    foreach(id in ["perk.mastery.axe","perk.mastery.mace"])
        check(flex.find(id)!=null,"unacquired flexible node omitted: "+id);
    check(flex.find("perk.mastery.hammer")==null,"unavailable replacement marked");
    check(defs["perk.mastery.axe"].unlock>s.spent,"locked-flex witness changed");
    s.perks["perk.mastery.axe"]<-true;s.perks["perk.pathfinder"]<-true;s.spent=2;
    flex=B.flexPerks(p,s,defs);
    foreach(id in ["perk.mastery.axe","perk.mastery.mace","perk.mastery.hammer","perk.pathfinder"])
        check(flex.find(id)==null,"acquired choice falsely offered as refundable: "+id);
    s.free=0;s.futurePerks=0;check(B.flexPerks(p,s,defs).len()==0,"blue choices offered without remaining points");
};

cases.route_after_deviation <- function()
{
    local s = fixture(); s.perks.a <- true; s.spent = 1; s.free = 1;
    local p = {route=["a", "b", "c"]};
    local defs = {a={unlock=0}, b={unlock=1}, c={unlock=2}};
    local r = B.route(p, s, defs);
    check(r.next == "b" && r.remaining.len()==2, "acquired perk suggested again");
    s.free = 0;
    check(B.route(p, s, defs).next == null, "no free point but next perk offered");
    s.free = 1; s.futurePerks = 0;
    check(!B.route(p, s, defs).feasible, "impossible remaining budget accepted");
};

cases.explicit_replacement <- function()
{
    local b = {id="test", label="Test", route=["a","b"], targets={hp=80}, preferred={hp=90}, priority=["hp"], armour="battle_forged", weapons="Axe", patterns=[],
        swaps=[{replace="b", with="c", condition="mace chosen"}]};
    local p = B.replacePlan(B.makePlan(b), 0, {});
    check(p.route[1]=="c" && b.route[1]=="b", "replacement must resolve without editing definition");
    b.targets.hp = 99;
    check(p.targets.hp==80, "definition change edited selected targets");
};
return cases;
