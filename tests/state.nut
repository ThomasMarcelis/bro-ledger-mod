local B=::BroLedger,cases={},defs=dofile("tests/perk_unlocks.nut"),legacy=dofile("tests/legacy.nut");
cases.schemas_roundtrip_and_unknown_retention <- function() {
    local flags=libraryFlags(),a={m={},getFlags=@() flags},saved=null,calls=0;
    B.Mod<-{Serialization={flagSerialize=function(id,p,f){saved=B.copy(p);f.set(B.BlobFlag,1);calls++;},
        flagDeserialize=function(id,def,obj,f){f.remove(B.BlobFlag);calls++;return B.copy(saved);}}};
    foreach(schema in [1,2,3,4,5]) {
        local p=schema>=4 ? B.makePlan(userBuild()) : oldPlan(legacy.nimble_2h_berserk);
        p.schema=schema;if(schema==4)delete p.weights;
        if(schema==1)delete p.preferredTargets;
        if(schema==3){p.core<-["matk","mdef"];p.flex<-["perk.pathfinder"];p.hands<-true;p.variant<-"ordinary";}
        p.enabled=false;check(B.validPlan(p),"historical shape rejected: "+schema);
        B.actorState(a).plan=p;B.savePlan(a);local before=B.copy(saved);B.loadPlan(a);B.savePlan(a);
        check(B.actorState(a).issue==null&&same(saved,before)&&flags.has(B.BlobFlag),"snapshot changed/consumed: "+schema);
    }
    foreach(schema in [6,999]) {
        flags.set(B.SchemaFlag,schema);local before=calls;B.loadPlan(a);B.savePlan(a);
        check(calls==before&&B.actorState(a).issue!=null&&flags.get(B.SchemaFlag)==schema,"future schema touched");
    }
    flags.set(B.SchemaFlag,3);saved={schema=3};B.loadPlan(a);B.savePlan(a);
    check(B.actorState(a).issue!=null&&flags.has(B.BlobFlag),"malformed bytes lost");
};
cases.snapshot_deletion_and_legacy_guidance <- function() {
    local flags=libraryFlags(),b=userBuild(),p=B.makePlan(b);B.writeLibrary(flags,[b],defs);
    b.label="Edited";b.targets.matk=75;B.writeLibrary(flags,[b],defs);B.writeLibrary(flags,[],defs);
    check(p.label=="TankFighter"&&p.targets.matk==60&&B.validPlan(p),"library changed saved snapshot");
    foreach(id,build in legacy) {
        local p=oldPlan(build),before=B.copy(p),s=fixture();s.perks["perk.colossus"]<-true;s.spent=1;
        local view=B.guidancePlan(p,s);B.assess(B.forPlan(s,view),view,B.planPreferred(view));
        check(same(p,before)&&B.validPlan(p),"retired plan changed: "+id);
    }
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
