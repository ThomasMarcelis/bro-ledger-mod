local B=::BroLedger, cases={}, defs=dofile("tests/perk_unlocks.nut");

// Independent integer-cent oracle: one weighted roll is 1200 units.
function goalUtility(x, goal, k, w) {
    local factors={hp=4,resolve=4,fatigue=4,initiative=3,matk=6,ratk=4,mdef=6,rdef=4};
    local gap=floor(goal*100+0.5)-100*x;return gap>0 ? -w*factors[k]*gap : 0;
}
cases.weights_change_fit_and_ignore_without_losing_ranges <- function() {
    local b=userBuild(),s=fixture();b.route=[];b.flex=[];s.normalRows=0;
    b.weights<-B.buildWeights(b);b.weights.matk=3;b.weights.mdef=1;
    s.stats.matk=80;s.stats.mdef=0;
    check(B.evaluate(s,b,defs).score==1.5,"relative weights did not control overall fit");
    b.weights.mdef=0;local e=B.evaluate(s,b,defs);
    check(e.score==0 && e.statRows[6].idealState=="ignored" && e.jointState=="possible","ignored goal affected fit or bounds");
    check(b.targets.mdef==10 && b.preferred.mdef==30,"ignoring lost the saved range");
    b.weights.matk=0;check(B.evaluate(s,b,defs).score==null,"all ignored build received a score");
    s.normalRows=1;local offer={};foreach(k in B.Stats) offer[k]<-2;
    check(B.adviseOffer(s,B.makePlan(b),offer).picks.len()==0,"ignored attributes recommended");
};

cases.weighted_score_matches_exhaustive_legal_schedules <- function() {
    local triples=[];for(local a=0;a<6;a++)for(local b=a+1;b<7;b++)for(local c=b+1;c<8;c++)triples.push([a,b,c]);
    foreach(veteran in [false,true]) foreach(start in [-1,1,3]) {
        local s=fixture();s.normalRows=veteran ? 0 : 1;s.veteranRows=veteran ? 1 : 0;s.giftRows=1;
        local b=userBuild();b.route=[];b.flex=[];b.targets={};b.preferred={};b.weights<-B.buildWeights(b);
        foreach(i,k in B.Stats) {s.stats[k]=start;s.ranges[k]=[1,3];s.scale[k]=i%2 ? 1.0 : 0.75;
            b.targets[k]<-i%3;b.preferred[k]<-4+i%3;b.weights[k]=i%4;}
        local best=null,bestMin=null;
        foreach(n in triples)foreach(g in triples) {
            local value=0.0,minimum=0.0;
            foreach(i,k in B.Stats) {
                local x=B.endpoint(s,k,!veteran && n.find(i)!=null ? 1 : 0,veteran && n.find(i)!=null ? 1 : 0,g.find(i)!=null ? 1 : 0);
                value+=goalUtility(x,b.preferred[k],k,b.weights[k]);
                minimum+=goalUtility(x,b.targets[k],k,b.weights[k]);
            }
            if(best==null || value>best || (value==best && minimum>bestMin)) {best=value;bestMin=minimum;}
        }
        local p=B.makePlan(b),fit=B.assess(s,p,b.preferred),actual=0.0,actualMin=0.0,used=[0,0,0];
        check(fabs(fit.score+best/12000.0)<0.0001,"weighted optimizer disagrees with exhaustive schedules");
        foreach(k,c in fit.projection.allocation) {
            actual+=goalUtility(fit.projection.stats[k],b.preferred[k],k,b.weights[k]);
            actualMin+=goalUtility(fit.projection.stats[k],b.targets[k],k,b.weights[k]);
            for(local i=0;i<3;i++){used[i]+=c[i];check(c[i]<=[s.normalRows,s.veteranRows,s.giftRows][i],"repeated attribute within a row");}
        }
        check(same(used,[3*s.normalRows,3*s.veteranRows,3]) && actual==best && actualMin==bestMin,"forecast is not an optimal shared witness");
    }
};

cases.weighted_formats_and_old_snapshots <- function() {
    local b=userBuild();b.weights<-B.buildWeights(b);b.weights.matk=10;b.weights.mdef=0;
    local wire=B.encodeBuilds([b],defs);check(wire.slice(0,4)=="BL2|" && same(B.decodeBuilds(wire,defs),[b]),"weighted sharing lost data");
    local p=B.makePlan(b);check(p.schema==5 && B.validPlan(p) && same(p.weights,b.weights),"weighted plan snapshot invalid");
    foreach(value in [-1,11,1.5,true,"2",0.0/0.0]) {local bad=B.copy(b);bad.weights.hp=value;check(!B.validBuild(bad,defs),"invalid weight accepted");}
    local old=B.copy(p);old.schema=4;delete old.weights;check(B.validPlan(old),"schema 4 became unreadable");
    local before=B.copy(old);B.assess(fixture(),old,old.preferredTargets);check(same(old,before),"old snapshot rewritten on read");
    local legacy="BL1|1:11:a1:A";for(local i=0;i<16;i++)legacy+="0:";legacy+="1:01:01:01:0";
    local decoded=B.decodeBuilds(legacy,defs)[0];foreach(k,w in B.buildWeights(decoded))check(w==1,"BL1 weight default changed");
};

cases.linear_fit_handles_a_constant_zero_endpoint <- function() {
    local s=fixture(),b=userBuild();s.normalRows=1;s.veteranRows=1;s.giftRows=1;
    b.targets={};b.preferred={};
    foreach(i,k in B.Stats) {s.stats[k]=40;b.targets[k]<-200;b.preferred[k]<-500;b.weights[k]=i+1;}
    s.stats.hp=0;s.scale.hp=0.01;b.targets.hp=0;
    // HP remains zero. Ordinary/Gifted picks favor MDef, RDef and RAtk;
    // veteran +1 picks favor MDef, RDef and MAtk under fixed roll units.
    local fit=B.assess(s,B.makePlan(b),b.preferred);
    local expected=0.0;foreach(k,x in fit.projection.stats) expected+=goalUtility(x,b.preferred[k],k,b.weights[k]);
    check(fabs(fit.score+expected/12000.0)<0.0001,"constant zero endpoint broke gap calculation");
    check(same(fit.projection.allocation.mdef,[1,1,1]) && same(fit.projection.allocation.rdef,[1,1,1]) &&
        same(fit.projection.allocation.ratk,[1,0,1]) && same(fit.projection.allocation.matk,[0,1,0]),"linear witness spent shared rows incorrectly");
};

cases.visible_offer_obeys_weights_and_leaves_ignored_choices_manual <- function() {
    local s=fixture(),b=userBuild(),offer={};s.normalRows=1;b.route=[];b.flex=[];b.targets={};b.preferred={};
    foreach(k in B.Stats) offer[k]<-2;
    foreach(i,k in ["hp","resolve","fatigue","initiative"]) {b.targets[k]<-100;b.preferred[k]<-100;offer[k]=5-i;}
    local before=B.copy(s);
    check(same(B.adviseOffer(s,B.makePlan(b),offer).picks,["hp","resolve","fatigue"]),"equal weights did not choose the best visible gains");
    b.weights.initiative=10;
    check(same(B.adviseOffer(s,B.makePlan(b),offer).picks,["hp","resolve","initiative"]),"priority did not change visible advice");
    b.weights.hp=0;b.weights.fatigue=0;
    check(same(B.adviseOffer(s,B.makePlan(b),offer).picks,["resolve","initiative"]),"ignored choices were not left to the player");
    check(same(s,before),"advice changed its input snapshot");
};

cases.large_budget_pruning_matches_exhaustive_counts <- function() {
    local s=fixture(),b=userBuild(),choices=[],utilities=[],keys=["hp","resolve","matk","mdef"];
    s.normalRows=5;s.veteranRows=10;s.giftRows=1;b.route=[];b.flex=[];b.targets={};b.preferred={};
    for(local n=0;n<=5;n++)for(local v=0;v<=10;v++)for(local g=0;g<=1;g++)choices.push([n,v,g]);
    foreach(i,k in keys) {
        s.stats[k]=[-2,1,4,0][i];s.stars[k]=[2,0,1,3][i];s.scale[k]=[0.6,1.15,0.75,0.95][i];
        b.targets[k]<-[12,9,14,5][i];b.preferred[k]<-[64,55,72,41][i];b.weights[k]=[8,3,10,6][i];
        local values=[];foreach(c in choices) values.push(goalUtility(B.endpoint(s,k,c[0],c[1],c[2]),b.preferred[k],k,b.weights[k]));utilities.push(values);
    }
    // Enumerate three attributes independently. Monotonicity gives the fourth
    // every remaining legal pick; this covers an optimum without using the DP.
    local best=null;
    foreach(i,a in choices)foreach(j,c in choices)foreach(l,d in choices) {
        local n=::Math.min(5,15-a[0]-c[0]-d[0]),v=::Math.min(10,30-a[1]-c[1]-d[1]),g=::Math.min(1,3-a[2]-c[2]-d[2]);
        local value=utilities[0][i]+utilities[1][j]+utilities[2][l]+utilities[3][(n*11+v)*2+g];
        if(best==null || value>best) best=value;
    }
    local fit=B.assess(s,B.makePlan(b),b.preferred),actual=0.0;
    foreach(k in keys) actual+=goalUtility(fit.projection.stats[k],b.preferred[k],k,b.weights[k]);
    check(fabs(actual-best)<0.001 && fabs(fit.score+best/12000.0)<0.0001,"pruning lost an optimal legal allocation");
};
return cases;
