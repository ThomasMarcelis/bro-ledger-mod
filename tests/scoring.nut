local B=::BroLedger,cases={};
function scoringBuild() {
    local b=userBuild();b.route=[];b.flex=[];
    b.targets={hp=60,resolve=40,fatigue=100,mdef=30};b.preferred={hp=63,resolve=43,fatigue=103,mdef=40};
    b.weights={hp=1,resolve=1,fatigue=1,initiative=0,matk=0,ratk=0,mdef=10,rdef=0};return b;
}
function scoringBro() {
    local s=fixture();s.normalRows=1;s.rawStats={hp=60,resolve=40,fatigue=100,initiative=100,matk=60,ratk=40,mdef=20,rdef=0};
    s.ranges.initiative=[3,5];return s;
}
function scoringOffer() {return {hp=3,resolve=3,fatigue=3,initiative=4,matk=2,ratk=3,mdef=2,rdef=3};}
cases.fixed_units_defend_priority_and_negative_progress <- function() {
    local s=scoringBro(),b=scoringBuild(),p=B.makePlan(b),a=B.adviseOffer(s,p,scoringOffer());
    check(a.picks.find("mdef")!=null,"narrow weight-1 completions displaced weight-10 Defence");
    local f=B.assess(s,p,b.preferred);check(f.projection.stats.mdef==22,"forecast missed Defence priority");
    check(fabs(f.score-9.1)<0.0001,"gap not measured on the fixed weight-10 scale");
    s.rawStats.mdef=-1;b.targets.mdef=0;b.preferred.mdef=10;
    check(B.adviseOffer(s,B.makePlan(b),scoringOffer()).picks.find("mdef")!=null,"negative Defence progress lost");
};
cases.equal_endpoints_and_weight_scaling <- function() {
    local s=scoringBro(),b=scoringBuild();s.normalRows=0;b.targets={hp=59};b.preferred={hp=60};s.rawStats.hp=58;
    local a=B.assess(s,B.makePlan(b),b.preferred);b.targets.hp=60;
    check(a.score==B.assess(s,B.makePlan(b),b.preferred).score,"equal endpoints changed Ideal gap");
    b=scoringBuild();b.weights.mdef=5;s=scoringBro();s.normalRows=2;
    local f=B.assess(s,B.makePlan(b),b.preferred),advice=B.adviseOffer(s,B.makePlan(b),scoringOffer());
    foreach(k,w in b.weights)b.weights[k]=w*2;
    local g=B.assess(s,B.makePlan(b),b.preferred);
    check(g.score==2*f.score && g.minimumGap==2*f.minimumGap,"global scaling must linearly scale both gaps");
    check(same(f.projection.allocation,g.projection.allocation) && same(advice.picks,B.adviseOffer(s,B.makePlan(b),scoringOffer()).picks),
        "global scaling changed allocation or visible advice");
};
cases.completed_goals_and_all_met_advice <- function() {
    local s=scoringBro(),b=scoringBuild();s.normalRows=0;b.targets={mdef=30};b.preferred={mdef=40};
    local a=B.assess(s,B.makePlan(b),b.preferred);b.targets.hp<-60;b.preferred.hp<-60;
    check(a.score==B.assess(s,B.makePlan(b),b.preferred).score,"completed secondary diluted gap");
    b.weights.hp=0;check(a.score==B.assess(s,B.makePlan(b),b.preferred).score,"ignored range changed gap");
    s.normalRows=1;s.rawStats.mdef=40;
    check(B.adviseOffer(s,B.makePlan(b),scoringOffer()).picks.len()==0,"met goals advertised zero-benefit advice");
};
cases.minimum_breaks_only_exact_ideal_ties <- function() {
    local s=scoringBro(),b=scoringBuild();s.rawStats.hp=60;s.rawStats.resolve=40;
    b.targets={hp=64,resolve=40,matk=80,mdef=30};b.preferred={hp=90,resolve=70,matk=90,mdef=40};
    b.weights.hp=2;b.weights.resolve=2;b.weights.matk=10;b.weights.mdef=10;
    local a=B.adviseOffer(s,B.makePlan(b),scoringOffer());
    check(same(a.picks,["hp","matk","mdef"]),"Minimum did not break equal Ideal improvement");
    b.weights.resolve=3;a=B.adviseOffer(s,B.makePlan(b),scoringOffer());
    check(same(a.picks,["resolve","matk","mdef"]),"Minimum overrode strictly better Ideal progress");
};
cases.unrounded_offer_and_tightening <- function() {
    local s=scoringBro(),b=scoringBuild();b.targets={hp=60,resolve=40,matk=80,mdef=30};
    b.preferred={hp=60.01,resolve=40.02,matk=90,mdef=40};b.weights.matk=10;
    local before=B.copy(s),plan=B.makePlan(b),saved=B.copy(plan);
    check(same(B.adviseOffer(s,plan,scoringOffer()).picks,["resolve","matk","mdef"]),"display-rounded equality lost a strictly better endpoint");
    check(same(s,before) && same(plan,saved),"advice rewrote inputs");
    local previous=B.assess(s,plan,b.preferred).score;
    foreach(x in [40.03,41,43,100,500]) {
        b.preferred.resolve=x;local next=B.assess(s,B.makePlan(b),b.preferred).score;
        check(next>=previous,"tightening an Ideal improved gap");previous=next;
    }
};
cases.original_two_row_precision_regression <- function() {
    local s=scoringBro(),b=scoringBuild(),offer=scoringOffer();s.normalRows=2;s.rawStats.mdef=28;offer.mdef=3;
    b.targets={hp=60,resolve=40,fatigue=100,mdef=20,matk=100};
    b.preferred={hp=63,resolve=46,fatigue=106,mdef=30.01,matk=110};
    b.weights.hp=1;b.weights.resolve=10;b.weights.fatigue=10;b.weights.mdef=1;b.weights.matk=1;
    check(same(B.adviseOffer(s,B.makePlan(b),offer).picks,["resolve","fatigue","mdef"]),"original display-rounded regression returned");
};
cases.visible_roll_quality_and_known_breakpoint_limit <- function() {
    local s=scoringBro(),b=scoringBuild(),offer=scoringOffer();s.rawStats.hp=70;s.rawStats.resolve=50;s.rawStats.mdef=30;
    b.targets={hp=70,resolve=50,fatigue=100,mdef=30};b.preferred={hp=90,resolve=70,fatigue=120,mdef=40};
    b.weights.hp=8;b.weights.resolve=6;b.weights.fatigue=6;offer.hp=4;offer.resolve=4;offer.fatigue=4;offer.mdef=1;
    check(B.adviseOffer(s,B.makePlan(b),offer).picks.find("mdef")==null,"poor Defence roll displaced stronger weighted progress");
    offer.mdef=3;check(B.adviseOffer(s,B.makePlan(b),offer).picks.find("mdef")!=null,"good Defence roll ignored");
    // Conditional mastered-cleaver burst requires Fatigue +4 for a third attack.
    // These creator priorities do not encode that action/loadout breakpoint.
    b.targets={hp=80,fatigue=100,matk=80,mdef=25};b.preferred={hp=95,fatigue=125,matk=90,mdef=35};
    b.weights.hp=6;b.weights.fatigue=1;b.weights.matk=10;b.weights.mdef=8;
    s.rawStats.hp=80;s.rawStats.matk=80;s.rawStats.mdef=25;offer=scoringOffer();offer.fatigue=4;
    check(B.adviseOffer(s,B.makePlan(b),offer).picks.find("fatigue")==null,"known breakpoint limitation changed; review assumptions");
};
cases.completed_high_weight_goal_preserves_gap_and_rank <- function() {
    local s=scoringBro(),b=scoringBuild();s.normalRows=0;b.targets={mdef=30};b.preferred={mdef=40};b.weights.mdef=1;
    local other=B.copy(b);other.id="closer";other.targets.mdef=20;other.preferred.mdef=30;
    local first=B.assess(s,B.makePlan(b),b.preferred);
    check(B.compare(s,{},[b,other]).builds[0].id==other.id,"closer build did not rank first");
    foreach(w in [1,10]) {
        b.targets.hp<-60;b.preferred.hp<-60;b.weights.hp=w;
        local f=B.assess(s,B.makePlan(b),b.preferred);
        check(f.score==first.score && f.minimumGap==first.minimumGap,"completed goal diluted either gap");
        check(B.compare(s,{},[b,other]).builds[0].id==other.id,"completed goal reversed actual rank");
    }
    check(first.score==1 && first.minimumGap==0.5,"gap must use fixed divisor 10");
};
cases.delayed_rounded_progress_retains_required_pick <- function() {
    local s=scoringBro(),b=scoringBuild(),offer=scoringOffer();s.normalRows=2;s.scale.mdef=0.8;offer.mdef=1;
    b.targets={hp=63,resolve=43,fatigue=103,mdef=18};b.preferred=B.copy(b.targets);b.weights.mdef=1;
    local today=B.copy(s);today.rawStats.mdef++;
    check(B.endpoint(s,"mdef")==16 && B.endpoint(today,"mdef")==16 && B.endpoint(s,"mdef",1)==17 && B.endpoint(today,"mdef",1)==18,
        "native delayed-rounding endpoints changed");
    local advice=B.adviseOffer(s,B.makePlan(b),offer);
    check(same(advice.picks,["hp","resolve","mdef"]),"required Defence pick omitted for zero immediate rounded gain");
    local after=B.copy(s);after.normalRows--;foreach(k in advice.picks)after.rawStats[k]+=offer[k];
    local fit=B.potential(after,b.targets,b.preferred,b.weights);
    check(fit.loss==0 && fit.score==0,"recommended triple did not reach all terminal Ideals");
    after=B.copy(s);after.normalRows--;foreach(k in ["hp","resolve","fatigue"])after.rawStats[k]+=offer[k];
    fit=B.potential(after,b.targets,b.preferred,b.weights);
    check(fit.loss==0.5 && fabs(fit.score-0.05)<0.00001,"Fatigue filler must leave half a weighted roll, gap 0.05");
};
return cases;
