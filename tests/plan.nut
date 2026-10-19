local B=::BroLedger, cases={}, defs=dofile("tests/perk_unlocks.nut");

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

cases.priority_route_uses_fillers_and_warns_over_budget <- function() {
    local p={route=["perk.battle_forged","perk.berserk","perk.killing_frenzy","perk.indomitable","perk.fearsome"],flex=[]},s=fixture();
    check(B.picksNeeded(["perk.killing_frenzy"],defs,0)==7 && B.picksNeeded(["perk.killing_frenzy"],defs,6)==1,"single high-tier pick count changed");
    local r=B.route(p,s,defs);
    check(r.feasible && r.needed==10 && r.points==10 && r.filler==5,"five core perks did not account for filler picks");
    check(r.blocked.len()==0 && r.next==null && same(r.remaining,p.route),"filler traversal blocked, changed priority or offered a locked next perk");
    s.spent=3;s.futurePerks=6;r=B.route(p,s,defs);
    check(r.feasible && r.needed==7 && r.filler==2,"learned picks did not lower filler count");
    s=fixture();p.route.push("perk.duelist");r=B.route(p,s,defs);
    check(!r.feasible && r.needed==11 && r.points==10 && r.blocked.len()==0,"six core perks hid their point deficit");
};
cases.student_budget_is_independent_of_optional_order <- function() {
    local s=fixture();s.spent=5;s.free=1;s.futurePerks=0;
    local p={route=["perk.killing_frenzy","perk.student"],flex=["perk.student"]},r=B.route(p,s,defs);
    check(r.feasible && r.needed==2 && r.points==2,"flexible Student did not fund a Manhunter's mandatory pick");
    s.spent=9;p.route=["perk.student","perk.killing_frenzy","perk.fearsome"];r=B.route(p,s,defs);
    check(!r.feasible && r.needed==3 && r.points==2,"flexible Student supplied two points without costing its own pick");
    s.spent=5;p.route=["perk.colossus","perk.student","perk.killing_frenzy"];p.flex=["perk.colossus"];r=B.route(p,s,defs);
    check(r.feasible && r.needed==2 && r.points==2,"earlier flexible pick suppressed Student's refund");
    s.free=0;r=B.route(p,s,defs);
    check(!r.feasible && r.points==0,"Student borrowed an unavailable acquisition point");
    s.perks["perk.student"]<-true;s.spent++;s.futurePerks=1;r=B.route(p,s,defs);
    check(r.feasible && r.needed==1 && r.points==1,"owned Student's pending refund counted twice");
};
cases.unavailable_perks_and_unknown_points_stay_infeasible <- function() {
    local s=fixture(),p={route=["perk.unknown","perk.killing_frenzy"],flex=[]},r=B.route(p,s,defs);
    check(!r.feasible && same(r.blocked,["perk.unknown"]) && same(r.unknown,r.blocked) && same(r.remaining,["perk.killing_frenzy"]),"unknown perk did not terminate separately from filler traversal");
    p.route=["perk.killing_frenzy"];
    foreach(field in ["free","futurePerks","spent"]) {
        s=fixture();s[field]=-1;r=B.route(p,s,defs);
        check(!r.pointsKnown && !r.feasible && r.next==null,"unknown points supplied a feasible route");
    }
};
cases.manual_filler_keeps_mandatory_perks_and_saved_intent <- function() {
    local b=userBuild();b.route=["perk.killing_frenzy","perk.gifted"];b.flex=["perk.gifted"];
    local p=B.makePlan(b),saved=B.copy(p),s=fixture(),before=B.route(B.guidancePlan(p,s),s,defs);
    s.perks["perk.colossus"]<-true;s.spent=1;s.futurePerks=8;
    local guidance=B.guidancePlan(p,s),after=B.route(guidance,s,defs);
    check(before.filler==6 && after.filler==5,"learned off-route filler did not lower the count");
    check(same(guidance.route,["perk.killing_frenzy","perk.colossus"]) && same(after.acquired,["perk.colossus"]),"manual filler displaced a mandatory perk or failed to replace flex");
    check(same(p,saved),"manual guidance changed the saved plan");
};

return cases;
