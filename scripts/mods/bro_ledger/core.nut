::BroLedger <- {
    ID = "mod_bro_ledger", Name = "Bro Planner", Version = "0.5.0", Revision = 6,
    Stats = ["hp", "resolve", "fatigue", "initiative", "matk", "ratk", "mdef", "rdef"],
    StatNames = {hp="HP",resolve="Resolve",fatigue="Fatigue",initiative="Initiative",matk="Melee Skill",ratk="Ranged Skill",mdef="Melee Defence",rdef="Ranged Defence"}
};

::BroLedger.copy <- function(value)
{
    if (typeof value == "array") { local out=[]; foreach(item in value) out.push(this.copy(item)); return out; }
    if (typeof value == "table") { local out={}; foreach(key,item in value) out[key]<-this.copy(item); return out; }
    return value;
};

::BroLedger.number <- function(value)
{
    return (typeof value == "integer" || typeof value == "float") && value == value && value > -1000000 && value < 1000000;
};

// Ordinary growth stays in raw units until finalStat applies lasting modifiers once.
::BroLedger.gain <- function(snapshot, key, mode)
{
    local stars=snapshot.stars[key];
    if (stars == null) return null;
    local low=snapshot.ranges[key][0]+(stars==3 ? 2 : stars), high=snapshot.ranges[key][1]+(stars==3 ? 1 : 0);
    return (mode=="low" ? low : mode=="high" ? high : (low+high)/2.0);
};

::BroLedger.finalStat <- function(key, raw, scale, initiativeLoss)
{
    if (key=="initiative") return ::Math.round(raw*scale-initiativeLoss);
    if (key=="hp" || key=="fatigue") return ::Math.floor(raw*scale);
    return ::Math.floor(raw*(raw>=0 ? scale : 1.0/scale));
};

// Add raw growth before the native getter's one final rounding/sign operation.
::BroLedger.endpoint <- function(snapshot, key, normal=0, veteran=0, gifted=0, mode="mean")
{
    if (!(key in snapshot.rawStats) || !this.number(snapshot.rawStats[key]) ||
        !(key in snapshot.scale) || !this.number(snapshot.scale[key]) || snapshot.scale[key]<=0) return null;
    local scale=snapshot.scale[key], raw=snapshot.rawStats[key], gain=normal>0 ? this.gain(snapshot,key,mode) : 0;
    if (gain==null) return null;
    raw+=normal*gain+veteran+gifted*snapshot.ranges[key][1];
    return this.finalStat(key,raw,scale,snapshot.initiativeLoss);
};

// Per-stat counts <= row counts and totals <= three times each row count admit a legal schedule.
::BroLedger.feasibility <- function(snapshot, targets, mode, witness=false)
{
    local normal=snapshot.normalRows, veteran=snapshot.veteranRows, gifted=snapshot.giftRows;
    local result={known=snapshot.growthKnown,feasible=false,picks={},required=0,
        capacity=3*(normal+veteran+gifted),shortfalls=[]};
    local states=[{n=0,v=0,g=0,picks=witness ? {} : null}];
    foreach(key in this.Stats)
    {
        if (!(key in targets)) continue;
        local current=this.endpoint(snapshot,key), maximum=this.endpoint(snapshot,key,normal,veteran,gifted,mode);
        if (current==null || maximum==null)
        {
            result.known=false; result.picks[key]<-null; continue;
        }
        if (maximum<targets[key]) result.shortfalls.push(key);
        local options=[], needed=normal+veteran+gifted+1;
        for(local gp=0;gp<=gifted;gp++)
        {
            local lastVeteran=veteran+1;
            for(local np=0;np<=normal;np++)
            {
                // Monotone native endpoints allow a bounded search, including signed and rounded gains.
                local low=0, high=lastVeteran;
                while(low<high)
                {
                    local vp=(low+high)/2;
                    local meets=this.endpoint(snapshot,key,np,vp,gp,mode)>=targets[key];
                    if (meets) high=vp; else low=vp+1;
                }
                if (low<lastVeteran)
                {
                    options.push([np,low,gp]);lastVeteran=low;
                    needed=::Math.min(needed,np+low+gp);
                }
            }
        }
        result.picks[key]<-needed;result.required+=needed;
        local next={};
        foreach(state in states) foreach(choice in options)
        {
            local n=state.n+choice[0],v=state.v+choice[1],g=state.g+choice[2];
            if (n>3*normal || v>3*veteran || g>3*gifted) continue;
            local id=(n*(3*veteran+1)+v)*(3*gifted+1)+g;
            if (id in next) continue;
            local picks=null;
            if (witness) { picks=this.copy(state.picks);picks[key]<-this.copy(choice); }
            next[id]<-{n=n,v=v,g=g,picks=picks};
        }
        local ids=[];foreach(id,_ in next) ids.push(id);ids.sort();
        states=[];foreach(id in ids) states.push(next[id]);
    }
    if (result.known && states.len()>0)
    {
        states.sort(function(a,b) {
            local total=(a.n+a.v+a.g)<=>(b.n+b.v+b.g);
            if(total!=0) return total;
            if(a.n!=b.n) return a.n<=>b.n;
            if(a.v!=b.v) return a.v<=>b.v;
            return a.g<=>b.g;
        });
        result.feasible=true;
        if(witness) result.picks=states[0].picks;
        result.required=states[0].n+states[0].v+states[0].g;
    }
    return result;
};

::BroLedger.forPlan <- function(snapshot, plan)
{
    local out=this.copy(snapshot);out.giftRows=0;
    if (plan.route.find("perk.gifted")!=null && !("perk.gifted" in snapshot.perks))
    {
        local known=snapshot.free>=0 && snapshot.futurePerks>=0 && snapshot.spent>=snapshot.perks.len();
        if (!known) out.growthKnown=false;
        else if (snapshot.free+snapshot.futurePerks>0)
        {
            local student = plan.route.find("perk.student")!=null && !("perk.student" in snapshot.perks) ? 1 : 0;
            if (snapshot.spent+snapshot.free+snapshot.futurePerks+student>=2) out.giftRows=1;
        }
    }
    return out;
};
