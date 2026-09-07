local B=::BroLedger, cases={}, defs=dofile("tests/perk_unlocks.nut");

cases.schema_and_actor_ownership <- function() {
    local values={}, flags={has=@(k) k in values,get=@(k) k in values ? values[k] : null,
        set=function(k,v){values[k]<-v;},remove=function(k){if(k in values) delete values[k];}};
    local a={m={},getFlags=@() flags},b={m={},getFlags=@() flags};
    local calls=0, saved=null;
    B.Mod <- {Serialization={
        flagDeserialize=function(id,def,obj,f){ calls++; f.remove(B.BlobFlag); return saved; },
        flagSerialize=function(id,p,f){ calls++; saved=B.copy(p); f.set(B.BlobFlag,1); }
    }};
    B.actorState(a).plan=B.makePlan(B.findBuild("forged_neutral_mace"));
    B.actorState(a).plan.enabled=false;
    B.savePlan(a);
    check(saved!=null && flags.has("BroLedger.Schema") && flags.has("MSU.mod_bro_ledger.Plan"),"saved flag identity changed");
    B.loadPlan(a);
    check(!B.actorState(a).plan.enabled && B.actorState(a).plan.route.find("perk.mastery.mace")!=null,"dormant choice lost on restore");
    check(flags.has(B.BlobFlag),"read consumed original flags");
    check(B.actorState(b).plan==null,"plan shared across actors");
    local fresh=B.copy(saved);
    // Real schema-1 shape must round-trip without a hidden migration.
    saved.schema=1;delete saved.preferredTargets;flags.set(B.SchemaFlag,1);
    B.loadPlan(a);B.savePlan(a);
    check(B.actorState(a).issue==null && saved.schema==1 && saved.len()==13 && flags.get(B.SchemaFlag)==1,"schema 1 was upgraded or lost");
    saved=fresh;flags.set(B.SchemaFlag,1);local mismatch=calls;
    B.loadPlan(a);B.savePlan(a);
    check(B.actorState(a).issue!=null && calls==mismatch+1 && flags.get(B.SchemaFlag)==1,"header/blob mismatch was written");
    flags.set(B.SchemaFlag,3);local before=calls;
    B.loadPlan(a); B.savePlan(a);
    check(calls==before && B.actorState(a).issue!=null && flags.get(B.SchemaFlag)==3,"future schema touched");
    flags.set(B.SchemaFlag,1);saved={schema=1};
    B.loadPlan(a);B.savePlan(a);
    check(B.actorState(a).issue!=null && flags.has(B.BlobFlag),"malformed known bytes lost");
};

cases.validation_and_revision_continuity <- function() {
    local build=B.findBuild("forged_neutral_axe"),p=B.makePlan(build);
    local edited=B.copy(p);edited.route.push(edited.route[0]);check(!B.validPlan(edited),"duplicate saved route accepted");
    edited=B.copy(p);edited.targets.hp=0.0/0.0;check(!B.validPlan(edited),"NaN target accepted");
    local old=build.targets.hp;build.targets.hp=999;
    check(p.targets.hp==old,"definition update changed saved targets");build.targets.hp=old;
    edited=B.copy(p);edited.enabled=false;check(B.validPlan(edited),"disabled intent invalid");
};

cases.saved_ideal_snapshot_and_legacy_read_only <- function() {
    local b=B.findBuild("nimble_2h_axe"),p=B.makePlan(b);
    check(p.schema==2 && B.validPlan(p),"new plan schema not valid");
    local ideal=p.preferredTargets.hp,old=b.preferred.hp;b.preferred.hp=999;
    check(p.preferredTargets.hp==ideal,"saved Ideal follows mutable catalog");b.preferred.hp=old;
    local legacy=B.copy(p);legacy.schema=1;delete legacy.preferredTargets;
    check(B.validPlan(legacy) && B.planPreferred(legacy).hp==ideal,"matching schema 1 cannot show Ideal");
    legacy.revision=1;
    check(B.planPreferred(legacy)==null && legacy.len()==13,"older intent silently upgraded");
    p.preferredTargets.hp=p.targets.hp-1;
    check(!B.validPlan(p),"Ideal below Minimum accepted");
};
return cases;
