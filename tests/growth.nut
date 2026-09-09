local B=::BroLedger, cases={}, defs=dofile("tests/perk_unlocks.nut");

cases.gifted_is_three_choices <- function() {
    local s=fixture(); s.normalRows=0; s.giftRows<-1;
    check(B.feasibility(s,{hp=4,matk=3,mdef=3},"mean").feasible,"Gifted maxima missing");
    check(!B.feasibility(s,{hp=4,matk=3,mdef=3,resolve=4},"mean").feasible,"Gifted granted four picks");
    s.perks["perk.gifted"]<-true;
    check(B.forPlan(s,{route=["perk.gifted"]}).giftRows==0,"already acquired Gifted added again");
};

cases.veteran_and_stored_finite_rows <- function() {
    local s=fixture(); s.normalRows=1; s.veteranRows=2;
    check(B.feasibility(s,{hp=6,matk=4,mdef=4},"high").feasible,"stored/veteran allocation lost");
    check(!B.feasibility(s,{hp=7},"high").feasible,"veteran gains used ordinary rolls");
    s.normalRows=0;
    check(!B.feasibility(s,{matk=3},"mean").feasible,"infinite veteran projection");
};

cases.finite_solver_matches_two_real_row_enumerations <- function() {
    local triples=[];
    for(local a=0;a<6;a++) for(local b=a+1;b<7;b++) for(local c=b+1;c<8;c++) triples.push([a,b,c]);
    local outcomes=[];
    foreach(n in triples) foreach(g in triples)
    {
        local score=[0,0,0,0];
        foreach(i in n) if(i<4) score[i]+=2;
        foreach(i in g) if(i<4) score[i]+=3;
        outcomes.push(score);
    }
    local s=fixture();s.normalRows=1;s.giftRows<-1;
    foreach(k in B.Stats) s.ranges[k]=[1,3];
    foreach(a in [0,2,3,5]) foreach(b in [0,2,3,5]) foreach(c in [0,2,3,5]) foreach(d in [0,2,3,5])
    {
        local possible=false;
        foreach(o in outcomes) if(o[0]>=a && o[1]>=b && o[2]>=c && o[3]>=d) {possible=true;break;}
        check(B.feasibility(s,{hp=a,resolve=b,fatigue=c,initiative=d},"mean").feasible==possible,"finite solver disagrees with explicit row triples");
    }
};

cases.fractional_threshold <- function()
{
    local s = fixture();
    s.stats.mdef = 19;
    s.stars.mdef = 1;
    s.normalRows = 1;
    local f = B.feasibility(s, {mdef = 22}, "mean");
    check(!f.feasible && f.picks.mdef == 2, "21.5 must stay below 22");
};

cases.joint_budget <- function()
{
    local s = fixture();
    s.normalRows = 1;
    local f = B.feasibility(s, {hp=1, fatigue=1, resolve=1, matk=1}, "mean");
    check(!f.feasible && f.required == 4 && f.capacity == 3, "joint budget exceeded");
};

cases.unknown_is_not_zero <- function()
{
    local s = fixture(); s.stars.mdef = null;
    check(!B.feasibility(s, {mdef=10}, "mean").known, "null talent became zero");
};

cases.current_offer <- function()
{
    local s = fixture(); s.normalRows = 1;
    local offer = {hp=4, resolve=3, fatigue=2, initiative=3, matk=1, ratk=2, mdef=3, rdef=2};
    local advice = B.adviseOffer(s, {route=[],targets={hp=4, matk=1, mdef=3}, priority=["matk","mdef","hp"]}, offer);
    check(advice.picks.len()==3 && advice.picks.find("hp")!=null && advice.picks.find("mdef")!=null && advice.picks.find("matk")!=null, "offered triple does not reach targets");
    check(s.stats.hp==0 && offer.hp==4, "advice mutated source");
    check(advice.considered==56, "ordinary choices not fully enumerated");
};

return cases;
