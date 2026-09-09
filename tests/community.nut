local B=::BroLedger, cases={}, defs=dofile("tests/perk_unlocks.nut");
function userBuild(id="user_1") {
    return {id=id,label="TankFighter",targets={matk=60,mdef=10},preferred={matk=80,mdef=30},
        route=["perk.colossus","perk.dodge","perk.gifted"],flex=["perk.gifted"],
        weaponTags=["Shield","Hammer","Axe","Mace","Flail"],playstyleTags=["Tank","Frontline"]};
}
function libraryFlags() {
    local values={};return {has=@(k) k in values,get=@(k) k in values?values[k]:null,
        set=function(k,v){values[k]<-v;},remove=function(k){if(k in values) delete values[k];}};
}
cases.empty_library_and_roundtrip <- function() {
    local flags=libraryFlags();check(B.readLibrary(flags,defs).builds.len()==0,"initial library not empty");
    local a=userBuild(),b=userBuild("user_2");b.label="<b>[color=red]literal & text";
    foreach(list in [[],[a],[a,b]]) check(same(B.decodeBuilds(B.encodeBuilds(list,defs),defs),list),"share roundtrip lost data");
};
cases.reject_invalid_data <- function() {
    local b=userBuild();check(B.validBuild(b,defs),"valid multi-tag board rejected");
    foreach(edit in [function(x){x.targets.matk=0.0/0.0;},function(x){x.preferred.matk=59;},
        function(x){x.route=["perk.nimble"];x.flex=[];},function(x){x.flex=["perk.nine_lives"];},
        function(x){x.route.push(x.route[0]);},function(x){x.weaponTags.push("Laser");},
        function(x){x.extra<-true;},function(x){x.label="";}]) {
        local bad=B.copy(b);edit(bad);check(!B.validBuild(bad,defs),"invalid build accepted");
    }
    foreach(value in ["BL9|0:","compilestring(attack())", "BL1|99999999999999999:","BL1|1:x",B.encodeBuilds([b],defs)+"junk"])
        check(rejects(@() B.decodeBuilds(value,defs)),"invalid envelope accepted");
};
cases.trailing_diagnostic_integrity <- function() {
    local empty="BL1|1:0",one="BL1|1:11:a1:A";
    for(local i=0;i<16;i++) one+="0:";
    one+="1:01:01:01:0";
    check(B.decodeBuilds(empty,defs).len()==0 && B.decodeBuilds(one,defs).len()==1,"valid shares rejected");
    local maximum=empty;for(local i=7;i<48000;i++) maximum+=format("%c",255);
    // Adler-32 known answers computed independently with Python zlib.adler32.
    local vectors=[
        [empty+format("%c",0),7,0,"0","2448:471"],
        [empty+format("%c",255),7,0,"255","2703:726"],
        [empty+"\xE2\x80\x8B",7,0,"226,128,139","4463:964"],
        [empty+empty,7,0,"66,76,49,124","7244:941"],
        [empty+"abcdefghijklmnop",7,0,"97,98,99,100","23385:2143"],
        [empty+"abcdefghijklmnoq",7,0,"97,98,99,100","23386:2144"],
        [one+format("%c",0),57,1,"0","33355:3164"],
        [empty+one.slice(7),7,0,"49,58,97,49","30140:3163"],
        [maximum,7,0,"255,255,255,255","58897:51780"]
    ];
    foreach(v in vectors) {
        local error=null;try {B.decodeBuilds(v[0],defs);} catch(e) {error=e;}
        check(error!=null && error.find("Diagnostic 0.4.3-d1")!=null,"diagnostic identity missing or malformed share accepted");
        check(error.find("consumed "+v[1]+"/"+v[0].len()+" bytes")!=null &&
            error.find("decoded "+v[2]+"/"+v[2]+" builds")!=null,"diagnostic position/count incorrect");
        check(error.find("next "+v[3]+"; adler32 "+v[4])!=null,"boundary bytes or whole-input fingerprint incorrect");
        check(error.len()<200 && error.find("abcdefghijklmnop")==null,"diagnostic leaked payload or grew unbounded");
    }
};
cases.library_collision_and_rollback <- function() {
    local flags=libraryFlags(),lib=B.readLibrary(flags,defs),a=userBuild();
    B.writeLibrary(flags,[a],defs);local before=flags.get(B.LibraryFlag);
    check(rejects(@() B.mergeBuilds([a],[a],"reject",defs)),"duplicate silently accepted");
    check(B.mergeBuilds([a],[a],"skip",defs).len()==1,"explicit skip changed library");
    local copy=B.mergeBuilds([a],[a],"copy",defs);check(copy.len()==2 && copy[0].id!=copy[1].id,"copy collision not resolved");
    local occupied=userBuild("user_3");occupied.label="TankFighter (copy 2)";
    copy=B.mergeBuilds([a,occupied],[a],"copy",defs);
    check(copy[2].label!=occupied.label && same(copy[0],a) && same(copy[1],occupied),"generated copy name collided with an existing build");
    local firstCopy=userBuild("user_4");firstCopy.label="TankFighter (copy 1)";
    copy=B.mergeBuilds([a,occupied,firstCopy],[a],"copy",defs);
    check(copy[3].label!=occupied.label && copy[3].label!=firstCopy.label,"copy suffix search did not skip occupied names");
    local broken={has=flags.has,get=flags.get,set=function(k,v){throw "disk failure";},remove=flags.remove};
    check(rejects(@() B.writeLibrary(broken,[],defs)) && flags.get(B.LibraryFlag)==before,"failed save changed library");
    flags.set(B.LibraryFlag,"BL99|private future bytes");lib=B.readLibrary(flags,defs);
    check(lib.issue!=null && rejects(@() B.writeLibrary(flags,[],defs)) && flags.get(B.LibraryFlag)=="BL99|private future bytes","future library overwritten");
};
cases.gradual_threshold_and_joint_budget <- function() {
    local b=userBuild(),p=B.makePlan(b),s=fixture();s.normalRows=0;s.free=0;s.futurePerks=0;
    s.stats.matk=59;s.stats.mdef=10;local low=B.assess(s,p,b.preferred);
    s.stats.matk=60;local middle=B.assess(s,p,b.preferred);
    s.stats.matk=61;local high=B.assess(s,p,b.preferred);
    check(low.score<middle.score && middle.score==high.score && middle.score-low.score<1,"Minimum creates a cliff or irrelevant excess compensates");
    b.targets={hp=1,resolve=1,fatigue=1,initiative=1};b.preferred={hp=3,resolve=3,fatigue=3,initiative=3};b.route=[];b.flex=[];
    s=fixture();s.normalRows=1;local e=B.evaluate(s,b,defs);
    check(e.score==0 && e.jointState=="impossible","independent maxima treated as joint feasible");
    foreach(row in e.statRows) if(row.ideal!=null) check(row.idealState=="grow","joint deficit falsely painted individual red");
};
cases.arnold_and_hadebrand_no_letter_cliff <- function() {
    local b=userBuild();b.targets={ratk=85,mdef=10};b.preferred={ratk=90,mdef=15};
    b.route=[];b.flex=[];local s=fixture();s.normalRows=0;s.stats.ratk=83;s.stats.mdef=9;
    local e=B.evaluate(s,b,defs);check(e.score==45 && !("nowGrade" in e) && !("grade" in e),"Arnold retains letter grading");
    s.stats.ratk=85;s.stats.mdef=10;check(B.evaluate(s,b,defs).score==50,"Minimum anchor changed");
    // Synthetic level-one reconstruction: 39 RAtk + ten two-star rows + Gifted = 83 even at maximum.
    s=fixture();s.stats.ratk=39;s.stats.mdef=9;s.stars.ratk=2;
    b.route=["perk.colossus","perk.gifted"];b.flex=[];
    e=B.evaluate(s,b,defs);
    check(e.projection.stats.ratk==83&&e.score>48&&e.score<50,"83-versus-85 Potential received a hard cliff");
    b.route=[];
    s=fixture();s.stats.ratk=45;s.stats.mdef=0;s.normalRows=10;
    e=B.evaluate(s,b,defs);check(e.score>0 && !("nowGrade" in e),"Hadebrand forced to NOW F");
};
cases.snapshot_and_many_library_matches <- function() {
    local b=userBuild(),p=B.makePlan(b),saved=B.copy(p),s=fixture(),list=[];
    check(p.schema==4 && B.validPlan(p),"community snapshot invalid");
    b.label="Edited";b.preferred.matk=100;check(same(p,saved),"library edit rewrote tracked intent");
    for(local i=0;i<14;i++){local x=userBuild("build_"+i);x.targets={hp=20+i};x.preferred={hp=40+i};list.push(x);}
    local ranked=B.compare(s,defs,list).builds;check(ranked.len()==14,"results truncated before top ten");
    for(local i=1;i<ranked.len();i++) check(ranked[i-1].score>=ranked[i].score,"ranking not potential-only");
    b.targets={};b.preferred={};check(B.evaluate(s,b,defs).score==null,"untargeted build fabricated score");
};

cases.payload_limits_finite_values_and_known_unsupported_perks <- function() {
    local b=userBuild(),list=[];
    for(local i=0;i<33;i++){local x=userBuild("user_"+i);x.label="Build "+i;list.push(x);}
    check(rejects(@() B.encodeBuilds(list,defs)),"33 builds accepted");list.pop();check(B.decodeBuilds(B.encodeBuilds(list,defs),defs).len()==32,"full library lost");
    foreach(v in [-1,501,0.0/0.0,1.0/0.0,"80",true,1.001]) {local x=B.copy(b);x.targets.matk=v;check(!B.validBuild(x,defs),"invalid finite/precision/shape accepted");}
    b.targets={hp=0,mdef=9.25};b.preferred={hp=0,mdef=30.5};
    local round=B.decodeBuilds(B.encodeBuilds([b],defs),defs)[0];check(round.targets.mdef==9.25&&round.preferred.mdef==30.5,"fractional goals lost");
    b.route.push("perk.unknown");check(!B.validBuild(b,defs),"known unsupported ID accepted");
    local huge="BL1|";for(local i=0;i<48000;i++) huge+="x";
    check(rejects(@() B.decodeBuilds(huge,defs)),"oversized text accepted");
    foreach(v in [null,[],{},17])check(rejects(@() B.decodeBuilds(v,defs)),"non-text accepted");
};
cases.invalid_utf8_cannot_enter_names <- function() {
    local b=userBuild();b.label="Hélder";check(B.validBuild(b,defs),"UTF-8 name rejected");
    b.label=format("%c",255);check(!B.validBuild(b,defs),"invalid UTF-8 accepted");
};
cases.full_student_route_and_empty_perks <- function() {
    local b=userBuild();b.route=["perk.student","perk.colossus","perk.gifted","perk.fortified_mind","perk.mastery.hammer",
        "perk.reach_advantage","perk.battle_forged","perk.underdog","perk.killing_frenzy","perk.berserk","perk.fearsome"];
    b.flex=["perk.gifted","perk.fearsome"];check(B.validBuild(b,defs),"legal full route rejected");
    local delayed=B.copy(b);delayed.route.remove(0);delayed.route.push("perk.student");
    check(!B.validBuild(delayed,defs),"Student borrowed its own eleventh acquisition point");
    b.route[0]="perk.pathfinder";check(!B.validBuild(b,defs),"11 non-Student perks accepted");
    b.route=[];b.flex=[];check(B.validBuild(b,defs),"deliberately empty route rejected");
};
cases.individual_bound_unknown_and_finite_witness <- function() {
    local b=userBuild();b.route=[];b.flex=[];b.targets={};b.preferred={};
    foreach(k in B.Stats){b.targets[k]<-20;b.preferred[k]<-30;}
    local s=fixture();s.normalRows=2;s.veteranRows=1;s.scale.hp=0.7;
    local e=B.evaluate(s,b,defs),again=B.evaluate(s,b,defs),totals=[0,0,0];
    check(same(e,again),"refresh is nondeterministic");
    foreach(k,counts in e.projection.allocation){for(local i=0;i<3;i++){totals[i]+=counts[i];check(counts[i]<=[2,1,0][i],"repeated attribute on one row");}
        check(e.projection.stats[k]==B.endpoint(s,k,counts[0],counts[1],counts[2]),"forecast does not share witness");}
    check(same(totals,[6,3,0]),"not three distinct choices per row");
    foreach(row in e.statRows)check(row.idealState=="impossible"&&row.maximum<row.ideal,"individual red lacks bound");
    s.growthKnown=false;e=B.evaluate(s,b,defs);check(e.score==null,"unknown growth scored");
    foreach(row in e.statRows)check(row.idealState!="impossible","unknown forecast painted red");
    s.stats.hp=30;e=B.evaluate(s,b,defs);check(e.statRows[0].idealState!="met","raw permanent scale ignored");
};
cases.max_min_score_matches_exhaustive_legal_schedules <- function() {
    local triples=[];for(local a=0;a<6;a++)for(local b=a+1;b<7;b++)for(local c=b+1;c<8;c++)triples.push([a,b,c]);
    foreach(startValue in [0,1,3])foreach(goal in [2,4,6]) {
        local s=fixture();s.normalRows=1;s.giftRows=1;foreach(k in B.Stats){s.stats[k]=startValue;s.ranges[k]=[1,3];}
        local targets={hp=goal,resolve=goal,fatigue=goal,initiative=goal},ideal={hp=goal+2,resolve=goal+2,fatigue=goal+2,initiative=goal+2};
        local best=0.0;
        foreach(n in triples)foreach(g in triples) {
            local values=[];for(local i=0;i<8;i++)values.push(startValue);
            foreach(i in n)values[i]+=2;foreach(i in g)values[i]+=3;
            local worst=100.0;for(local i=0;i<4;i++) {
                local value=values[i],score=value>=goal+2?100.0:value<goal?50.0*value/goal:50+25.0*(value-goal);
                if(score<worst)worst=score;
            }
            if(worst>best)best=worst;
        }
        local score=B.potential(s,targets,ideal).score;
        check(score<=best+0.001&&best-score<0.011,"finite score disagrees with 3136 actual schedules");
    }
};
cases.all_supported_cent_targets_roundtrip <- function() {
    local b=userBuild();b.targets={hp=0};b.preferred={hp=500};
    for(local i=0;i<=50000;i++) {
        b.targets.hp=i/100.0;
        check(B.validBuild(b,defs),"valid hundredth rejected: "+i);
        local decoded=B.decodeBuilds(B.encodeBuilds([b],defs),defs)[0];
        check(fabs(decoded.targets.hp-b.targets.hp)<0.00004,"hundredth roundtrip lost: "+i);
    }
};
return cases;
