// Per-attribute satisfaction is capped; surplus above Ideal never contributes.
::BroLedger.satisfaction <- function(value, minimum, ideal)
{
    if(value>=ideal) return 100.0;
    if(value<0) return 0.0;
    if(ideal==minimum) return 100.0*value/ideal;
    return value<minimum ? 50.0*value/minimum : 50+50.0*(value-minimum)/(ideal-minimum);
};
// Optimize capped weighted satisfaction with one shared, finite allocation.
::BroLedger.potential <- function(snapshot, targets, preferred, weights=null)
{
    local result={score=null,allocation={}},active=[],totalWeight=0,ceiling={},upper=0.0;
    if(preferred==null || !snapshot.growthKnown) return result;
    local caps=[snapshot.normalRows,snapshot.veteranRows,snapshot.giftRows];
    foreach(k in this.Stats) {
        if(!(k in targets) || this.statWeight(weights,k)==0) continue;
        if(!(k in preferred)) return result;
        local maximum=this.endpoint(snapshot,k,caps[0],caps[1],caps[2]);
        if(this.endpoint(snapshot,k)==null || maximum==null) return result;
        active.push(k);totalWeight+=this.statWeight(weights,k);
        ceiling[k]<-maximum<preferred[k] ? maximum : preferred[k];
        upper+=this.statWeight(weights,k)*this.satisfaction(maximum,targets[k],preferred[k]);
    }
    if(totalWeight==0) return result;
    // When individual capped maxima fit together, their witness is already optimal.
    local bound=this.feasibility(snapshot,ceiling,"mean",true);
    if(bound.feasible) {
        result.score=::Math.floor(upper/totalWeight*100)/100.0;result.allocation=bound.picks;return result;
    }
    // In a single linear satisfaction segment with affine native endpoints, each row type
    // has constant marginal values. Its three highest values give the exact optimum.
    // Certify endpoints over the finite domain: native rounding/sign changes must not be assumed linear.
    local rates={},linear=true;
    foreach(k in active) {
        local current=this.endpoint(snapshot,k),maximum=this.endpoint(snapshot,k,caps[0],caps[1],caps[2]);
        local minimum=targets[k],ideal=preferred[k],slope=0.0;
        if(current==maximum || current>=ideal || maximum<0) slope=0.0;
        else if(current>=0 && maximum<=ideal && (minimum==ideal || maximum<=minimum || current>=minimum))
            slope=this.statWeight(weights,k)*(minimum==ideal ? 100.0/ideal : maximum<=minimum ? 50.0/minimum : 50.0/(ideal-minimum));
        else {linear=false;break;}
        local gains=[caps[0]>0 ? this.endpoint(snapshot,k,1,0,0)-current : 0,
            caps[1]>0 ? this.endpoint(snapshot,k,0,1,0)-current : 0,caps[2]>0 ? this.endpoint(snapshot,k,0,0,1)-current : 0];
        for(local n=0;n<=caps[0] && linear;n++) for(local v=0;v<=caps[1] && linear;v++) for(local g=0;g<=caps[2];g++)
            if(this.endpoint(snapshot,k,n,v,g)!=current+n*gains[0]+v*gains[1]+g*gains[2]) {linear=false;break;}
        if(!linear) break;
        rates[k]<-[slope*gains[0],slope*gains[1],slope*gains[2]];
    }
    if(linear) {
        foreach(k in active) result.allocation[k]<-[0,0,0];
        for(local i=0;i<3;i++) {
            local order=this.copy(active),column=i;
            order.sort(function(a,b) {return rates[a][column]!=rates[b][column] ? rates[b][column]<=>rates[a][column] : ::BroLedger.Stats.find(a)<=>::BroLedger.Stats.find(b);});
            for(local j=0;j<order.len() && j<3;j++) result.allocation[order[j]][i]=caps[i];
        }
        local value=0.0;
        foreach(k,c in result.allocation) value+=this.statWeight(weights,k)*this.satisfaction(this.endpoint(snapshot,k,c[0],c[1],c[2]),targets[k],preferred[k]);
        result.score=::Math.floor(value/totalWeight*100)/100.0;return result;
    }
    local choices={};
    foreach(k in active) {
        local options=[],weight=this.statWeight(weights,k);
        for(local g=0;g<=caps[2];g++) for(local n=0;n<=caps[0];n++) {
            local previous=-1.0;
            for(local v=0;v<=caps[1];v++) {
                local value=weight*this.satisfaction(this.endpoint(snapshot,k,n,v,g),targets[k],preferred[k]);
                // Equal utility at fewer picks dominates this choice. Saturation ends the row.
                if(value>previous) options.push({n=n,v=v,g=g,value=value});
                previous=value;
                if(value==100*weight) break;
            }
            if(this.endpoint(snapshot,k,n,0,g)>=preferred[k]) break;
        }
        choices[k]<-options;
    }
    local prices=[0.0,0.0,0.0],suffix=[],incumbent=0.0,budgets=[3*caps[0],3*caps[1],3*caps[2]];
    // Pricing overhead pays off only for larger finite domains. Search limits below
    // affect bound quality and speed; the DP still proves the returned optimum.
    local bounded=(caps[0]+1)*(caps[1]+1)*(caps[2]+1)>120;
    if(bounded) {
        // A legal greedy schedule supplies only a lower bound, never the returned optimum.
        local counts={};foreach(k in active) counts[k]<-[0,0,0];
        foreach(i in [2,0,1]) for(local row=0;row<caps[i];row++) {
            local gains={},order=this.copy(active);
            foreach(k,c in counts) {
                local before=this.satisfaction(this.endpoint(snapshot,k,c[0],c[1],c[2]),targets[k],preferred[k]);
                c[i]++;gains[k]<-this.statWeight(weights,k)*(this.satisfaction(this.endpoint(snapshot,k,c[0],c[1],c[2]),targets[k],preferred[k])-before);c[i]--;
            }
            order.sort(function(a,b){return gains[b]<=>gains[a];});
            for(local j=0;j<3;j++) counts[order[j]][i]++;
        }
        // Transfers and exchanges retain per-stat and shared row capacities.
        for(local step=0;step<64;step++) {
            local gain=0.001,move=null,values={};
            foreach(k,c in counts) values[k]<-this.statWeight(weights,k)*this.satisfaction(this.endpoint(snapshot,k,c[0],c[1],c[2]),targets[k],preferred[k]);
            foreach(a,ca in counts) foreach(b,cb in counts) {
                if(a==b) continue;
                for(local i=0;i<3;i++) {
                    if(ca[i]==0 || cb[i]==caps[i]) continue;
                    for(local j=-1;j<3;j++) {
                        if(j==i) continue;
                        for(local amount=1;amount<=(j<0 ? 1 : 4);amount++) {
                            if(j>=0 && (cb[j]<amount || ca[j]+amount>caps[j])) continue;
                            ca[i]--;cb[i]++;if(j>=0) {cb[j]-=amount;ca[j]+=amount;}
                            local value=this.statWeight(weights,a)*this.satisfaction(this.endpoint(snapshot,a,ca[0],ca[1],ca[2]),targets[a],preferred[a])+
                                this.statWeight(weights,b)*this.satisfaction(this.endpoint(snapshot,b,cb[0],cb[1],cb[2]),targets[b],preferred[b])-values[a]-values[b];
                            ca[i]++;cb[i]--;if(j>=0) {cb[j]+=amount;ca[j]-=amount;}
                            if(value>gain) {gain=value;move=[a,b,i,j,amount];}
                        }
                    }
                }
            }
            if(move==null) break;
            counts[move[0]][move[2]]--;counts[move[1]][move[2]]++;
            if(move[3]>=0) {counts[move[1]][move[3]]-=move[4];counts[move[0]][move[3]]+=move[4];}
        }
        foreach(k,c in counts) incumbent+=this.statWeight(weights,k)*this.satisfaction(this.endpoint(snapshot,k,c[0],c[1],c[2]),targets[k],preferred[k]);
        // Nonnegative resource prices give an upper bound for every continuation:
        // price * remaining capacity + sum(max(value - price * counts)).
        // Finite demand bisection improves the bound; any prices remain admissible.
        local ratio=[0.0,0.0,0.0];
        foreach(k in active) {
            local now=this.endpoint(snapshot,k);
            if(caps[0]>0) ratio[0]=::Math.max(ratio[0],this.endpoint(snapshot,k,1,0,0)-now);
            if(caps[1]>0) ratio[1]=::Math.max(ratio[1],this.endpoint(snapshot,k,0,1,0)-now);
            if(caps[2]>0) ratio[2]=::Math.max(ratio[2],this.endpoint(snapshot,k,0,0,1)-now);
        }
        local low=0.0,high=1024.0,capacity=0.0;
        for(local i=0;i<3;i++) capacity+=ratio[i]*budgets[i];
        for(local step=0;step<18;step++) {
            local price=(low+high)/2,used=0.0;
            foreach(k in active) {
                local value=null,demand=0.0;
                foreach(c in choices[k]) {
                    local cost=ratio[0]*c.n+ratio[1]*c.v+ratio[2]*c.g,net=c.value-price*cost;
                    if(value==null || net>value) {value=net;demand=cost;}
                }
                used+=demand;
            }
            if(used>capacity) low=price;else high=price;
        }
        for(local i=0;i<3;i++) prices[i]=high*ratio[i];
        for(local pass=0;pass<3;pass++) for(local column=0;column<3;column++) {
            if(caps[column]==0) continue;
            local low=0.0,high=1024.0;
            for(local step=0;step<16;step++) {
                prices[column]=(low+high)/2;
                local used=0;
                foreach(k in active) {
                    local best=null,value=null;
                    foreach(c in choices[k]) {
                        local net=c.value-prices[0]*c.n-prices[1]*c.v-prices[2]*c.g;
                        if(best==null || net>value) {best=c;value=net;}
                    }
                    used+=column==0 ? best.n : column==1 ? best.v : best.g;
                }
                if(used>budgets[column]) low=prices[column];else high=prices[column];
            }
            prices[column]=high;
        }
        suffix.resize(active.len()+1,0.0);
        for(local i=active.len()-1;i>=0;i--) {
            local best=null;foreach(c in choices[active[i]]) {
                local net=c.value-prices[0]*c.n-prices[1]*c.v-prices[2]*c.g;
                if(best==null || net>best) best=net;
            }
            suffix[i]=suffix[i+1]+best;
        }
        local margin=suffix[0]+prices[0]*budgets[0]+prices[1]*budgets[1]+prices[2]*budgets[2]-incumbent+1.0;
        foreach(i,k in active) {
            local viable=[],best=suffix[i]-suffix[i+1];
            foreach(c in choices[k])
                if(c.value-prices[0]*c.n-prices[1]*c.v-prices[2]*c.g+margin>=best) viable.push(c);
            choices[k]=viable;
        }
    }
    local states=[{n=0,v=0,g=0,value=0.0,previous=null,key=null,counts=null}];
    foreach(index,k in active) {
        local next=[],indices={};
        foreach(state in states) foreach(choice in choices[k]) {
            local n=state.n+choice.n,v=state.v+choice.v,g=state.g+choice.g;
            if(n>3*caps[0] || v>3*caps[1] || g>3*caps[2]) continue;
            local id=(n*(3*caps[1]+1)+v)*(3*caps[2]+1)+g,value=state.value+choice.value;
            // Slack protects the bound against the game's 32-bit float cancellation.
            if(bounded && value+suffix[index+1]+prices[0]*(budgets[0]-n)+prices[1]*(budgets[1]-v)+prices[2]*(budgets[2]-g)+1.0<incumbent) continue;
            if(id in indices && next[indices[id]].value>=value) continue;
            local node={n=n,v=v,g=g,value=value,previous=state,key=k,counts=[choice.n,choice.v,choice.g]};
            if(id in indices) next[indices[id]]=node;
            else {indices[id]<-next.len();next.push(node);}
        }
        states=next;
    }
    local best=states[0];
    foreach(state in states) if(state.value>best.value || (state.value==best.value && state.n+state.v+state.g<best.n+best.v+best.g)) best=state;
    result.score=::Math.floor(best.value/totalWeight*100)/100.0;
    while(best.key!=null) {result.allocation[best.key]<-best.counts;best=best.previous;}
    return result;
};
::BroLedger.project <- function(snapshot, plan, preferred, potential)
{
    local out={known=potential.score!=null,stats={},allocation={},horizon=snapshot.horizon};
    local caps=[snapshot.normalRows,snapshot.veteranRows,snapshot.giftRows],used=[0,0,0];
    foreach(k in this.Stats) {
        local counts=k in potential.allocation ? this.copy(potential.allocation[k]) : [0,0,0];
        out.allocation[k]<-counts;for(local i=0;i<3;i++) used[i]+=counts[i];
        local current=this.endpoint(snapshot,k);out.stats[k]<-current;
        if(current==null || this.endpoint(snapshot,k,caps[0],caps[1],caps[2])==null) out.known=false;
    }
    if(!out.known) return out;
    // Complete the witness to three distinct picks per row. These extra picks cannot lower capped fit.
    for(local i=0;i<3;i++) foreach(k in this.Stats) {
        local room=caps[i]-out.allocation[k][i],remaining=3*caps[i]-used[i],add=room<remaining ? room : remaining;
        out.allocation[k][i]+=add;used[i]+=add;
    }
    foreach(k,c in out.allocation) out.stats[k]=this.endpoint(snapshot,k,c[0],c[1],c[2]);
    return out;
};
::BroLedger.assess <- function(snapshot, plan, preferred)
{
    local weights=this.buildWeights(plan),fit=this.potential(snapshot,plan.targets,preferred,weights);
    local projection=this.project(snapshot,plan,preferred,fit),rows=[],goals={};
    if(preferred!=null) foreach(k,v in preferred) if(k in plan.targets && weights[k]>0) goals[k]<-v;
    local joint=preferred==null ? {known=false,feasible=false,shortfalls=[]} : this.feasibility(snapshot,goals,"high");
    foreach(k in this.Stats) {
        local now=this.endpoint(snapshot,k),ideal=preferred!=null && k in preferred ? preferred[k] : null;
        local maximum=snapshot.growthKnown ? this.endpoint(snapshot,k,snapshot.normalRows,snapshot.veteranRows,snapshot.giftRows,"high") : null;
        rows.push({key=k,now=now,minimum=k in plan.targets ? plan.targets[k] : null,ideal=ideal,weight=weights[k],
            expected=projection.known ? projection.stats[k] : null,maximum=maximum,
            idealState=ideal==null ? "none" : weights[k]==0 ? "ignored" : now==null ? "unknown" : now>=ideal ? "met" : maximum!=null && maximum<ideal ? "impossible" : "grow"});
    }
    return {score=fit.score,projection=projection,statRows=rows,
        jointState=preferred!=null && goals.len()==0 ? "untargeted" : !joint.known ? "unknown" : joint.feasible ? "possible" : joint.shortfalls.len()>0 ? "individual" : "impossible"};
};
::BroLedger.evaluate <- function(snapshot, build, defs)
{
    local plan=this.candidatePlan(build,snapshot),e=this.assess(this.forPlan(snapshot,plan),plan,build.preferred);
    e.id<-build.id;e.label<-build.label;e.route<-this.route(plan,snapshot,defs);
    e.order<-this.copy(build.route);e.flex<-this.copy(build.flex);
    e.weaponTags<-this.copy(build.weaponTags);e.playstyleTags<-this.copy(build.playstyleTags);
    return e;
};
::BroLedger.compare <- function(snapshot, defs, library, starters=null)
{
    local builds=[];
    foreach(b in library) {local e=this.evaluate(snapshot,b,defs);e.source<-"library";builds.push(e);}
    if(starters!=null) foreach(b in starters) {local e=this.evaluate(snapshot,b,defs);e.source<-"starter";builds.push(e);}
    builds.sort(function(a,b) {
        if(a.score!=b.score) return (b.score==null ? -1 : a.score==null ? 1 : b.score<=>a.score);
        if(a.source!=b.source) return a.source<=>b.source;
        return a.id<=>b.id;
    });return {builds=builds};
};
::BroLedger.adviseOffer <- function(snapshot, plan, offer)
{
    foreach(k in this.Stats) if(!(k in offer) || !this.number(offer[k]) || offer[k]<=0 || this.endpoint(snapshot,k)==null) return null;
    snapshot=this.forPlan(snapshot,plan);local preferred=this.planPreferred(plan),weights=this.buildWeights(plan),best=null;
    // Older plans without saved Ideals can still aim at their retained Minimum.
    if(preferred==null) preferred=plan.targets;
    for(local a=0;a<6;a++) for(local b=a+1;b<7;b++) for(local c=b+1;c<8;c++) {
        local picks=[this.Stats[a],this.Stats[b],this.Stats[c]],after=this.copy(snapshot);
        if(after.normalRows>0) after.normalRows--;else if(after.veteranRows>0) after.veteranRows--;else return null;
        local immediate=0.0;
        foreach(k in picks) {
            after.rawStats[k]+=offer[k];
            if(k in plan.targets && weights[k]>0) immediate+=weights[k]*(this.satisfaction(this.endpoint(after,k),plan.targets[k],preferred[k])-
                this.satisfaction(this.endpoint(snapshot,k),plan.targets[k],preferred[k]));
        }
        local fit=this.potential(after,plan.targets,preferred,weights),score=fit.score==null ? -1 : fit.score;
        if(best==null || score>best.score || (score==best.score && immediate>best.immediate)) best={picks=picks,score=score,immediate=immediate};
    }
    local recommended=[];foreach(k in best.picks) if(k in plan.targets && weights[k]>0) recommended.push(k);
    return {picks=recommended,considered=56,reason=recommended.len()==0 ? "No weighted stat recommendations. Choose stats normally." : snapshot.growthKnown ? "Best weighted fit from these visible rolls. Fill any remaining choices manually." : "Provisional: growth unknown. These visible rolls improve current target progress.",forecast=null};
};
