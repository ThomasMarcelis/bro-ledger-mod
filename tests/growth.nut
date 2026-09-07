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

cases.projection_is_one_finite_allocation <- function() {
    foreach(b in B.Builds) {
        local s=fixture();s.stats={hp=60,fatigue=100,resolve=40,initiative=105,matk=60,ratk=55,mdef=5,rdef=0};
        s.stars.matk=2;s.stars.ratk=2;s.stars.mdef=2;
        local e=B.evaluate(s,b,defs),p=e.projection,prepared=B.forPlan(s,B.candidatePlan(b,s));
        check(p.known,"known fixture lost projection: "+b.id);
        local totals=[0,0,0],caps=[prepared.normalRows,prepared.veteranRows,prepared.giftRows];
        foreach(k in B.Stats) {
            local counts=p.allocation[k],gain=B.gain(prepared,k,"mean");
            for(local i=0;i<3;i++) {check(counts[i]>=0 && counts[i]<=caps[i],"stat picked twice on one row");totals[i]+=counts[i];}
            local expected=s.stats[k]+counts[0]*gain+counts[1]+counts[2]*s.ranges[k][1];
            check(fabs(expected-p.stats[k])<0.001,"displayed growth does not match allocation");
            if(["S","A","B"].find(e.grade)!=null && k in b.targets) check(p.stats[k]>=b.targets[k],"feasible grade lost a minimum");
            if(e.grade=="S" && k in b.preferred) check(p.stats[k]>=b.preferred[k],"S forecast lost an Ideal");
        }
        for(local i=0;i<3;i++) check(totals[i]==3*caps[i],"projection did not use three picks per row");
    }
};

cases.offer_minimum_then_ideal <- function() {
    local s=fixture();s.normalRows=1;
    foreach(k in B.Stats) s.stats[k]=80;
    local p={route=[],targets={hp=80,matk=80,mdef=80},preferredTargets={hp=84,matk=83,mdef=83},
        priority=["initiative","ratk","rdef","resolve"]},offer={};
    foreach(k in B.Stats) offer[k]<-3;
    offer.hp=4;
    local advice=B.adviseOffer(s,p,offer);
    foreach(k in ["hp","matk","mdef"]) check(advice.picks.find(k)!=null,"met minima stopped Ideal investment");
    p.targets.resolve<-81;p.preferredTargets.resolve<-81;
    check(B.adviseOffer(s,p,offer).picks.find("resolve")!=null,"Ideal displaced missing Minimum");
    delete p.preferredTargets;
    advice=B.adviseOffer(s,p,offer);
    check(advice.picks.find("resolve")!=null && advice.reason.find("Ideal")==null,"legacy plan lost honest Minimum guidance");
};

cases.fractional_growth_and_determinism <- function() {
    local s=fixture(),p=B.makePlan(B.findBuild("tempo_spear"));
    s.normalRows=2;s.veteranRows=1;s.giftRows<-1;s.scale.hp=0.7;
    s.stats={hp=59.5,resolve=40,fatigue=88,initiative=100,matk=54,ratk=40,mdef=12,rdef=0};
    local a=B.assess(s,p,p.preferredTargets,true);
    for(local i=0;i<5;i++) {
        local b=B.assess(s,p,p.preferredTargets,true);
        foreach(k in B.Stats) {
            check(a.projection.stats[k]==b.projection.stats[k],"forecast varies on refresh");
            foreach(j,n in a.projection.allocation[k]) check(n==b.projection.allocation[k][j],"witness varies on refresh");
        }
    }
    local n=a.projection.allocation.hp;
    check(fabs(a.projection.stats.hp-(59.5+0.7*(n[0]*3+n[1]+n[2]*4)))<0.001,"permanent injury gain scaled incorrectly");
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

cases.fractional_shortfall_and_offer_progress <- function()
{
    local s=fixture(); s.normalRows=1; s.stars.mdef=1;
    check(B.feasibility(s,{mdef=4.5},"mean").required==2,"fractional gain truncated in shortfall count");
    s.stats.hp=10; s.stats.resolve=40;
    local offer={}; foreach(k in B.Stats) offer[k]<-1;
    local p={route=[],targets={hp=10.5,resolve=40.25,matk=1,mdef=1},priority=["resolve","hp","matk","mdef"]};
    local advice=B.adviseOffer(s,p,offer);
    check(advice.picks.find("hp")!=null && advice.picks.find("matk")!=null && advice.picks.find("mdef")!=null,
        "fractional target progress lost to priority tie-break");
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
