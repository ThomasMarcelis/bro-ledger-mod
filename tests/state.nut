local B=::BroLedger,cases={},defs=dofile("tests/perk_unlocks.nut");
// Schema-5 snapshots retain all mandatory picks and their saved weights.
cases.full_mandatory_plan_snapshot_roundtrip <- function() {
    local flags=libraryFlags(),a={m={},getFlags=@() flags},saved=null;
    B.Mod<-{Serialization={flagSerialize=function(id,p,f){saved=B.copy(p);f.set(B.BlobFlag,1);},
        flagDeserialize=function(id,def,obj,f){f.remove(B.BlobFlag);return B.copy(saved);}}};
    // Eleven perks with Student, none marked flexible.
    local wide=userBuild();
    wide.route=["perk.student","perk.colossus","perk.gifted","perk.fortified_mind","perk.mastery.hammer",
        "perk.reach_advantage","perk.battle_forged","perk.underdog","perk.killing_frenzy","perk.berserk","perk.fearsome"];
    wide.flex=[];
    local plan=B.makePlan(wide);
    check(B.validPlan(plan),"full mandatory snapshot rejected");
    B.actorState(a).plan=plan;B.savePlan(a);
    local before=B.copy(saved);
    B.loadPlan(a);
    local state=B.actorState(a);
    check(state.issue==null,"loading a schema-5 plan reported an issue: "+(state.issue==null?"":state.issue));
    check(state.plan!=null,"the tracked build was dropped on upgrade");
    check(state.plan.build==wide.id && state.plan.label==wide.label,"the plan lost the build it tracked");
    check(same(state.plan.route,wide.route),"the tracked perk order changed on upgrade");
    B.savePlan(a);
    check(same(saved,before),"re-saving a plan rewrote its snapshot");
    // The same plan with a couple of picks marked flexible must survive too.
    local marked=B.copy(plan);marked.flex=["perk.fearsome","perk.berserk"];
    check(B.validPlan(marked),"an upgraded plan with flexible picks was rejected");
};
cases.schemas_roundtrip_and_unknown_retention <- function() {
    local flags=libraryFlags(),a={m={},getFlags=@() flags},saved=null,calls=0;
    B.Mod<-{Serialization={flagSerialize=function(id,p,f){saved=B.copy(p);f.set(B.BlobFlag,1);calls++;},
        flagDeserialize=function(id,def,obj,f){f.remove(B.BlobFlag);calls++;return B.copy(saved);}}};
    local p=B.makePlan(userBuild());p.enabled=false;
    check(B.validPlan(p),"schema-5 shape rejected");
    B.actorState(a).plan=p;B.savePlan(a);local snapshot=B.copy(saved);B.loadPlan(a);B.savePlan(a);
    check(B.actorState(a).issue==null && same(saved,snapshot) && flags.has(B.BlobFlag),"snapshot changed/consumed");
    foreach(schema in [1,2,3,4]) {
        local retired=B.copy(p);retired.schema=schema;check(!B.validPlan(retired),"retired schema accepted");
        flags.set(B.SchemaFlag,schema);local before=calls;B.loadPlan(a);B.savePlan(a);
        check(calls==before && B.actorState(a).plan==null && B.actorState(a).issue==null &&
            flags.get(B.SchemaFlag)==schema && flags.has(B.BlobFlag),"retired plan read, blocked or changed");
    }
    foreach(schema in [6,999]) {
        flags.set(B.SchemaFlag,schema);local before=calls;B.loadPlan(a);B.savePlan(a);
        check(calls==before&&B.actorState(a).issue!=null&&flags.get(B.SchemaFlag)==schema,"future schema touched");
    }
    flags.set(B.SchemaFlag,5);saved={schema=5};B.loadPlan(a);B.savePlan(a);
    check(B.actorState(a).issue!=null&&flags.has(B.BlobFlag),"malformed bytes lost");
};
cases.snapshot_survives_library_edits_and_deletion <- function() {
    local store=libraryStore(),b=userBuild(),p=B.makePlan(b);B.writeLibrary(store,[b],defs);
    b.label="Edited";b.targets.matk=75;B.writeLibrary(store,[b],defs);B.writeLibrary(store,[],defs);
    check(p.label=="TankFighter"&&p.targets.matk==60&&B.validPlan(p),"library changed saved snapshot");
};
cases.community_manual_flex_preserves_mandatory_order <- function() {
    local p=B.makePlan(userBuild()),before=B.copy(p),s=fixture();s.perks["perk.nine_lives"]<-true;s.spent=1;
    local q=B.guidancePlan(p,s);
    check(q.route.find("perk.nine_lives")!=null&&q.route.find("perk.colossus")!=null&&q.route.find("perk.dodge")!=null,"flex failed or mandatory displaced");
    check(same(p,before),"guidance persisted manual choice");
    s.perks["perk.gifted"]<-true;s.spent=2;q=B.guidancePlan(p,s);
    check(q.route.find("perk.gifted")!=null,"acquired flex refunded");
    p.enabled=false;check(same(B.guidancePlan(p,s),p),"dormant plan reconciled");
};
return cases;
