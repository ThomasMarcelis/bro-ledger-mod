// Fit is the greatest common satisfaction reachable with ONE allocation at mean rolls.
// Minimum = 50, Ideal = 100; equal goals use a single 0..100 ramp. No excess compensation.
::BroLedger.targetAt <- function(minimum, ideal, score)
{
    if(ideal==minimum) return ideal*score/100.0;
    return score<=50 ? minimum*score/50.0 : minimum+(ideal-minimum)*(score-50)/50.0;
};
::BroLedger.satisfaction <- function(value, minimum, ideal)
{
    if(value>=ideal) return 100.0;
    if(value<0) return 0.0;
    if(ideal==minimum) return 100.0*value/ideal;
    return value<minimum ? 50.0*value/minimum : 50+50.0*(value-minimum)/(ideal-minimum);
};
::BroLedger.potential <- function(snapshot, targets, preferred)
{
    local result={score=null,seed={}};
    if(preferred==null || targets.len()==0) return result;
    foreach(k,v in targets) if(!(k in preferred)) return result;
    if(!this.feasibility(snapshot,targets,"mean").known) return result;
    local thresholds=function(score) {local out={};foreach(k,v in targets) out[k]<-::BroLedger.targetAt(v,preferred[k],score);return out;};
    // 0.01-point resolution, rounded down. At most fourteen calls to the finite solver.
    local low=0,high=10000;
    while(low<high) {
        local mid=(low+high+1)/2;
        if(this.feasibility(snapshot,thresholds(mid/100.0),"mean").feasible) low=mid;else high=mid-1;
    }
    result.score=low/100.0;result.seed=thresholds(result.score);return result;
};
::BroLedger.project <- function(snapshot, plan, preferred, potential)
{
    local out={known=snapshot.growthKnown && preferred!=null && plan.targets.len()>0,stats={},allocation={},horizon=snapshot.horizon};
    local caps=[snapshot.normalRows,snapshot.veteranRows,snapshot.giftRows],used=[0,0,0];
    foreach(k in this.Stats) {
        out.allocation[k]<-[0,0,0];local current=this.endpoint(snapshot,k);
        if(current==null || this.endpoint(snapshot,k,caps[0],caps[1],caps[2])==null) out.known=false;
        if(current!=null) out.stats[k]<-current;
    }
    if(!out.known) return out;
    local seed=this.feasibility(snapshot,potential.seed,"mean",true);
    if(!seed.feasible) {
        // A negative current attribute can make even zero unattainable. Keep its real value.
        seed=this.feasibility(snapshot,{},"mean",true);
    }
    foreach(k,c in seed.picks) {out.allocation[k]=c;for(local i=0;i<3;i++) used[i]+=c[i];}
    // Fill remaining legal picks, preferring the least-satisfied targeted attribute. Fixed stat order breaks ties.
    for(local i=0;i<3;i++) while(used[i]<3*caps[i]) {
        local best=null,lowest=101.0;
        foreach(k in this.Stats) {
            if(out.allocation[k][i]>=caps[i]) continue;
            local c=out.allocation[k],value=this.endpoint(snapshot,k,c[0],c[1],c[2]);
            local fit=k in plan.targets && preferred!=null && k in preferred ? this.satisfaction(value,plan.targets[k],preferred[k]) : 100.0;
            if(fit<lowest) {best=k;lowest=fit;}
        }
        out.allocation[best][i]++;used[i]++;
    }
    foreach(k,c in out.allocation) {
        out.stats[k]<-this.endpoint(snapshot,k,c[0],c[1],c[2]);
    }
    return out;
};
::BroLedger.assess <- function(snapshot, plan, preferred)
{
    local fit=this.potential(snapshot,plan.targets,preferred),projection=this.project(snapshot,plan,preferred,fit),rows=[];
    local joint=preferred==null ? {known=false,feasible=false,shortfalls=[]} : this.feasibility(snapshot,preferred,"high");
    foreach(k in this.Stats) {
        local now=this.endpoint(snapshot,k),ideal=preferred!=null && k in preferred ? preferred[k] : null;
        local maximum=snapshot.growthKnown ? this.endpoint(snapshot,k,snapshot.normalRows,snapshot.veteranRows,snapshot.giftRows,"high") : null;
        rows.push({key=k,now=now,minimum=k in plan.targets ? plan.targets[k] : null,ideal=ideal,
            expected=projection.known ? projection.stats[k] : null,maximum=maximum,
            idealState=ideal==null ? "none" : now==null ? "unknown" : now>=ideal ? "met" : maximum!=null && maximum<ideal ? "impossible" : "grow"});
    }
    return {score=fit.score,projection=projection,statRows=rows,
        jointState=!joint.known ? "unknown" : joint.feasible ? "possible" : joint.shortfalls.len()>0 ? "individual" : "impossible"};
};
::BroLedger.evaluate <- function(snapshot, build, defs)
{
    local plan=this.candidatePlan(build,snapshot),e=this.assess(this.forPlan(snapshot,plan),plan,build.preferred);
    e.id<-build.id;e.label<-build.label;e.route<-this.route(plan,snapshot,defs);
    e.order<-this.copy(build.route);e.flex<-this.copy(build.flex);
    e.weaponTags<-this.copy(build.weaponTags);e.playstyleTags<-this.copy(build.playstyleTags);
    return e;
};
::BroLedger.compare <- function(snapshot, defs, library)
{
    local builds=[];foreach(b in library) builds.push(this.evaluate(snapshot,b,defs));
    builds.sort(function(a,b) {
        if(a.score!=b.score) return (b.score==null ? -1 : a.score==null ? 1 : b.score<=>a.score);
        return a.id<=>b.id;
    });return {builds=builds};
};
::BroLedger.adviseOffer <- function(snapshot, plan, offer)
{
    foreach(k in this.Stats) if(!(k in offer) || !this.number(offer[k]) || offer[k]<=0 || this.endpoint(snapshot,k)==null) return null;
    snapshot=this.forPlan(snapshot,plan);local preferred=this.planPreferred(plan),best=null;
    // Older plans without saved Ideals can still aim at their retained Minimum.
    if(preferred==null) preferred=plan.targets;
    for(local a=0;a<6;a++) for(local b=a+1;b<7;b++) for(local c=b+1;c<8;c++) {
        local picks=[this.Stats[a],this.Stats[b],this.Stats[c]],after=this.copy(snapshot);
        if(after.normalRows>0) after.normalRows--;else if(after.veteranRows>0) after.veteranRows--;else return null;
        local immediate=0.0;
        foreach(k in picks) {
            after.rawStats[k]+=offer[k];
            if(k in plan.targets) immediate+=this.satisfaction(this.endpoint(after,k),plan.targets[k],preferred[k])-
                this.satisfaction(this.endpoint(snapshot,k),plan.targets[k],preferred[k]);
        }
        local fit=this.potential(after,plan.targets,preferred),score=fit.score==null ? -1 : fit.score;
        if(best==null || score>best.score || (score==best.score && immediate>best.immediate)) best={picks=picks,score=score,immediate=immediate};
    }
    return {picks=best.picks,considered=56,reason=snapshot.growthKnown ? "Best shared target fit from these visible rolls; tied choices prefer immediate target progress." : "Provisional: growth unknown. These visible rolls improve current target progress.",forecast=null};
};
