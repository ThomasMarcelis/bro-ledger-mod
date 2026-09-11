local B=::BroLedger, cases={}, defs=dofile("tests/perk_unlocks.nut"), legacy=dofile("tests/legacy.nut");
function legacyPlan(id) {return oldPlan(legacy[id]);}

cases.replacement_conflicts_and_sunk_perks <- function() {
    local p=legacyPlan("nimble_2h_berserk");
    local q=B.replacePlan(p,0,{});
    check(rejects(@() B.replacePlan(q,1,{})),"conflicting masteries accepted");
    check(rejects(@() B.replacePlan(p,0,{["perk.mastery.axe"]=true})),"acquired default refunded");
    check(B.replacePlan(q,0,{}).route.find("perk.mastery.axe")!=null,"cannot reverse unspent choice");
};

cases.gifted_needs_obtainable_capacity <- function() {
    local b=userBuild(),s=calibratedBro(b,false),p=B.makePlan(b);
    // Gifted must be mandatory here: a flexible pick is an alternate and no longer forces infeasibility.
    p.flex=[];
    b.targets.hp<-60;p.targets.hp<-60;p.preferredTargets.hp<-70;
    s.perks.clear();foreach(id in b.route) if(id!="perk.gifted") s.perks[id]<-true;
    s.perks["perk.steel_brow"]<-true;s.spent=10;s.free=0;s.stats.hp=b.targets.hp-4;
    check(!B.route(p,s,defs).feasible,"exhausted saved route witness changed");
    check(B.forPlan(s,p).giftRows==0 && !B.feasibility(B.forPlan(s,p),p.targets,"mean").feasible,
        "unobtainable Gifted supplied phantom tracked fit");
    s.free=1;check(B.forPlan(s,p).giftRows==1,"free Gifted point ignored");
    s.free=0;s.futurePerks=1;check(B.forPlan(s,p).giftRows==1,"future Gifted point ignored");
    s.perks["perk.gifted"]<-true;s.spent++;check(B.forPlan(s,p).giftRows==0,"acquired Gifted counted twice");
};

cases.student_can_unlock_gifted_but_cannot_start_without_a_point <- function() {
    local s=fixture();s.free=1;s.futurePerks=0;s.normalRows=0;
    local p={route=["perk.student","perk.gifted"]};
    check(B.route(p,s,defs).feasible && B.forPlan(s,p).giftRows==1,"paid Student did not unlock planned Gifted");
    s.free=0;
    check(!B.route(p,s,defs).feasible && B.forPlan(s,p).giftRows==0,"Student borrowed an acquisition point");
};

return cases;
