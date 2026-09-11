local B=::BroLedger, cases={}, defs=dofile("tests/perk_unlocks.nut");
cases.empty_library_and_roundtrip <- function() {
    local store=libraryStore();check(B.readLibrary(store,defs).builds.len()==0,"initial library not empty");
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
    local store=libraryStore(),lib=B.readLibrary(store,defs),a=userBuild();
    B.writeLibrary(store,[a],defs);local before=store.get();
    check(rejects(@() B.mergeBuilds([a],[a],"reject",defs)),"duplicate silently accepted");
    check(B.mergeBuilds([a],[a],"skip",defs).len()==1,"explicit skip changed library");
    local copy=B.mergeBuilds([a],[a],"copy",defs);check(copy.len()==2 && copy[0].id!=copy[1].id,"copy collision not resolved");
    local occupied=userBuild("user_3");occupied.label="TankFighter (copy 2)";
    copy=B.mergeBuilds([a,occupied],[a],"copy",defs);
    check(copy[2].label!=occupied.label && same(copy[0],a) && same(copy[1],occupied),"generated copy name collided with an existing build");
    local firstCopy=userBuild("user_4");firstCopy.label="TankFighter (copy 1)";
    copy=B.mergeBuilds([a,occupied,firstCopy],[a],"copy",defs);
    check(copy[3].label!=occupied.label && copy[3].label!=firstCopy.label,"copy suffix search did not skip occupied names");
    local broken={has=store.has,get=store.get,set=function(v){throw "disk failure";}};
    check(rejects(@() B.writeLibrary(broken,[],defs)) && store.get()==before,"failed save changed library");
    store.set("BL99|private future bytes");lib=B.readLibrary(store,defs);
    check(lib.issue!=null && rejects(@() B.writeLibrary(store,[],defs)) && store.get()=="BL99|private future bytes","future library overwritten");
};
// The library belongs to the player: a second campaign sees the same builds, and the campaign that
// donated its legacy bytes never re-donates them after the player deletes builds globally.
cases.library_survives_campaigns_and_adopts_once <- function() {
    local a=userBuild(),b=userBuild("user_2");b.label="Second";
    local store=libraryStore(),first=libraryFlags(),second=libraryFlags();
    B.writeLibrary(store,[a],defs);
    check(B.readLibrary(store,defs,second).builds.len()==1,"new campaign lost the player's library");
    check(!second.has(B.MovedFlag),"campaign without legacy bytes was marked migrated");
    local legacy=libraryFlags();legacy.set(B.LibraryFlag,B.encodeBuilds([b],defs));
    local lib=B.readLibrary(store,defs,legacy);
    check(lib.builds.len()==2 && lib.issue==null && lib.notice==null,"legacy campaign builds were not adopted");
    check(legacy.has(B.MovedFlag) && legacy.get(B.LibraryFlag)!=null,"adoption did not mark or preserve the legacy campaign");
    check(B.readLibrary(store,defs,legacy).builds.len()==2,"repeated load duplicated adopted builds");
    B.writeLibrary(store,[a],defs);
    check(B.readLibrary(store,defs,legacy).builds.len()==1,"a deleted build reappeared from the donating campaign");
    local damaged=libraryFlags();damaged.set(B.LibraryFlag,"BL99|unreadable");
    lib=B.readLibrary(store,defs,damaged);
    check(lib.notice!=null && lib.issue==null && lib.builds.len()==1 && !damaged.has(B.MovedFlag),
        "unreadable campaign bytes were not reported or destroyed the player's library");
};
cases.gradual_threshold_and_joint_budget <- function() {
    local b=userBuild(),p=B.makePlan(b),s=fixture();s.normalRows=0;s.free=0;s.futurePerks=0;
    s.stats.matk=59;s.stats.mdef=10;local low=B.assess(s,p,b.preferred);
    s.stats.matk=60;local middle=B.assess(s,p,b.preferred);
    s.stats.matk=61;local high=B.assess(s,p,b.preferred);
    check(low.score<middle.score && middle.score<high.score && middle.score-low.score<1,"Minimum creates a cliff or irrelevant excess compensates");
    b.targets={hp=1,resolve=1,fatigue=1,initiative=1};b.preferred={hp=3,resolve=3,fatigue=3,initiative=3};b.route=[];b.flex=[];
    s=fixture();s.normalRows=1;local e=B.evaluate(s,b,defs);
    check(e.score==75 && e.jointState=="impossible","independent maxima treated as joint feasible");
    foreach(row in e.statRows) if(row.ideal!=null) check(row.idealState=="grow","joint deficit falsely painted individual red");
};
cases.arnold_and_hadebrand_no_letter_cliff <- function() {
    local b=userBuild();b.targets={ratk=85,mdef=10};b.preferred={ratk=90,mdef=15};
    b.route=[];b.flex=[];local s=fixture();s.normalRows=0;s.stats.ratk=83;s.stats.mdef=9;
    local e=B.evaluate(s,b,defs);check(e.score>46 && e.score<47 && !("nowGrade" in e) && !("grade" in e),"Arnold retains letter grading");
    s.stats.ratk=85;s.stats.mdef=10;check(B.evaluate(s,b,defs).score==50,"Minimum anchor changed");
    // Synthetic level-one reconstruction: 39 RAtk + ten two-star rows + Gifted = 83 even at maximum.
    s=fixture();s.stats.ratk=39;s.stats.mdef=9;s.stars.ratk=2;
    b.route=["perk.colossus","perk.gifted"];b.flex=[];
    e=B.evaluate(s,b,defs);
    check(e.projection.stats.ratk==83&&e.score>74&&e.score<75,"83-versus-85 Potential received a hard cliff");
    b.route=[];
    s=fixture();s.stats.ratk=45;s.stats.mdef=0;s.normalRows=10;
    e=B.evaluate(s,b,defs);check(e.score>0 && !("nowGrade" in e),"Hadebrand forced to NOW F");
};
cases.snapshot_and_many_library_matches <- function() {
    local b=userBuild(),p=B.makePlan(b),saved=B.copy(p),s=fixture(),list=[];
    check(p.schema==5 && B.validPlan(p),"community snapshot invalid");
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
    b.flex=[];check(B.validBuild(b,defs),"legal full mandatory route rejected");
    local delayed=B.copy(b);delayed.route.remove(0);delayed.route.push("perk.student");
    check(!B.validBuild(delayed,defs),"Student borrowed its own eleventh acquisition point");
    // Student last is legal once it is flexible: it is an alternate, not the eleventh commitment.
    local flexible=B.copy(delayed);flexible.flex=["perk.student"];
    check(B.validBuild(flexible,defs),"flexible Student in the last position rejected");
    b.route[0]="perk.pathfinder";check(!B.validBuild(b,defs),"11 mandatory non-Student perks accepted");
    // Hélder's case: 10 mandatory perks plus several flexible alternates on top.
    local wide=userBuild();
    wide.route=["perk.colossus","perk.gifted","perk.fortified_mind","perk.mastery.hammer","perk.reach_advantage",
        "perk.battle_forged","perk.underdog","perk.killing_frenzy","perk.berserk","perk.fearsome",
        "perk.pathfinder","perk.student","perk.nine_lives","perk.dodge"];
    wide.flex=["perk.pathfinder","perk.student","perk.nine_lives","perk.dodge"];
    check(B.validBuild(wide,defs),"10 mandatory plus 4 flexible perks rejected");
    check(same(B.decodeBuilds(B.encodeBuilds([wide],defs),defs)[0],wide),"wide build lost data in share roundtrip");
    local overCommitted=B.copy(wide);overCommitted.flex=["perk.dodge"];
    check(!B.validBuild(overCommitted,defs),"13 mandatory perks accepted");
    local tooMany=userBuild();tooMany.route=[];tooMany.flex=[];
    for(local i=0;i<B.RouteLimit+1;i++) tooMany.route.push("perk.slot_"+i);
    check(!B.validBuild(tooMany,defs),"route beyond the list limit accepted");
    b.route=[];b.flex=[];check(B.validBuild(b,defs),"deliberately empty route rejected");
};
// Hélder could not tell why a save was refused. Each cause must name itself.
cases.save_problems_name_their_cause <- function() {
    local ok=userBuild();
    check(B.buildProblems(ok,defs).len()==0,"valid build reported a problem");
    local named=function(b,needle,why) {
        local problems=B.buildProblems(b,defs);
        check(problems.len()>0,why+" produced no problem");
        local hit=false;foreach(p in problems) if(p.find(needle)!=null) hit=true;
        check(hit,why+" was not named: "+B.joinProblems(problems));
    };
    local long=userBuild();long.label="";for(local i=0;i<41;i++) long.label+="x";
    named(long,"40","overlong name");
    local blank=userBuild();blank.label="   ";named(blank,"Name","blank name");
    local badWeight=userBuild();badWeight.weights.hp=11;
    named(badWeight,"Weight","out-of-range weight");
    local textWeight=userBuild();textWeight.weights.hp="";
    named(textWeight,"Weight","non-numeric weight");
    // A missing Ideal beside a Minimum is a real cause and must say so.
    local lonely=userBuild();lonely.preferred={};named(lonely,"Ideal","minimum without an ideal");
    local over=userBuild();over.route=[];over.flex=[];
    for(local i=0;i<12;i++) over.route.push("perk.slot_"+i);
    named(over,"mandatory","12 mandatory perks");
    local badTarget=userBuild();badTarget.targets.matk=501;named(badTarget,"0-500","out-of-range target");
    // A zero weight must be as acceptable as an omitted one: ignoring a stat is not an error.
    local ignored=userBuild();ignored.weights.rdef=0;ignored.weights.ratk=0;
    check(B.buildProblems(ignored,defs).len()==0,"ignoring individual stats was refused");
    // Several faults at once are reported together, not one at a time.
    local many=B.copy(long);many.targets.matk=501;
    check(B.buildProblems(many,defs).len()>=2,"multiple faults collapsed into one message");
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
