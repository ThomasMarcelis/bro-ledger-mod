local B=::BroLedger, cases={}, defs=dofile("tests/perk_unlocks.nut");

cases.stock_offer_isolation <- function() {
    local actor={m={},getLevel=@() 3,getLevelUps=@() 1},dto={levelUp={}};
    foreach (k,fields in B.Fields) dto.levelUp[fields[1]+"Increase"]<-2;
    B.captureOffer(actor,dto);dto.levelUp.hitpointsIncrease=4;
    check(B.actorState(actor).offer.values.hp==2,"held stock payload by reference");
    B.captureOffer(actor,{levelUp=null});check(B.actorState(actor).offer==null,"stale offer retained");
};

cases.command_rejects_stale_and_invalid_writes <- function() {
    local a={m={},getID=@() 7};local screen={m={BroLedgerContext={epoch=91,seq=-1,actor=null,settings={Enabled=true}}}};
    B.ownedActor=function(id){return id==7 ? a : null;};
    B.readActor=function(actor){return fixture();};
    B.view=function(actor,catalog,settings){return {actor=7,revision=B.actorState(actor).revision};};
    local r=B.command(screen,{action="refresh",actor=7,seq=1});
    check(!("error" in r),"cannot refresh");
    check("error" in B.command(screen,{action="track",actor=7,seq=2,epoch=90,revision=0,build="forged_neutral_axe"}),"old campaign epoch accepted");
    r=B.command(screen,{action="track",actor=7,seq=3,epoch=91,revision=0,build="forged_neutral_axe"});
    check(!("error" in r) && B.actorState(a).plan.build=="forged_neutral_axe","deliberate track failed");
    check("error" in B.command(screen,{action="enabled",actor=7,seq=4,epoch=91,revision=0,enabled=false}),"late disable edited newer intent");
    r=B.command(screen,{action="enabled",actor=7,seq=5,epoch=91,revision=1,enabled=false});
    check(!("error" in r) && !B.actorState(a).plan.enabled,"disable failed");
    check("error" in B.command(screen,{action="track",actor=9,seq=6,epoch=91,revision=0,build="forged_neutral_axe"}),"unowned actor accepted");
    screen.m.BroLedgerContext=null;
    check("error" in B.command(screen,{action="track",actor=7,seq=7,epoch=91,revision=2,build="fencer"}),"closed screen accepted a write");
};

cases.track_commits_only_the_reviewed_current_candidate <- function() {
    local b=B.findBuild("nimble_2h_axe"),s=calibratedBro(b),a={m={},getID=@() 7};
    s.perks.clear();foreach(id in b.route) if(id!="perk.mastery.axe") s.perks[id]<-true;
    s.perks["perk.mastery.mace"]<-true;s.spent=10;s.free=0;
    local old=B.makePlan(b);old.revision=1;old.enabled=false;B.actorState(a).plan=old;
    local preview=B.candidatePlan(b,s);
    check(B.actorState(a).plan==old && old.route.find("perk.mastery.axe")!=null,"preview changed old metadata");
    B.readActor=@(actor) s;B.ownedActor=@(id) id==7 ? a : null;
    B.view=@(actor,catalog,settings) {actor=7,revision=B.actorState(actor).revision};
    local screen={m={BroLedgerContext={actor=7,epoch=31,seq=0,settings={Enabled=true}}}};
    local result=B.command(screen,{actor=7,epoch=31,seq=1,revision=0,action="track",build=b.id});
    local chosen=B.actorState(a).plan;
    check(!("error" in result) && chosen.revision==3 && B.validPlan(chosen),"deliberate Track failed");
    foreach(i,id in preview.route) check(chosen.route[i]==id,"Track differed from candidate preview");
    check(old.revision==1 && !old.enabled && old.route.find("perk.mastery.axe")!=null,"old plan object was edited");
    check(s.spent==10 && s.free==0 && !("perk.mastery.axe" in s.perks),"Track spent or refunded gameplay points");
};

cases.reader_view_stored_offer <- function() {
    local a=actorFixture(),b=B.findBuild("fencer"),p=B.makePlan(b);
    a.level=12;a.pending=2;a.free=0;a.spent=10;
    a.getID<-@() 7;a.getName<-@() "Stored offer fixture";a.isPerkUnlockable<-@(id) true;
    a.natural={Hitpoints=65,Bravery=39,Stamina=103,Initiative=159,MeleeSkill=88,RangedSkill=30,MeleeDefense=30,RangedDefense=0};
    foreach(id in b.route) if(id!="perk.gifted") a.skills.push(skill(id,1));
    a.skills.push(skill("perk.footwork",1));
    local offer={hp=4,resolve=2,fatigue=2,initiative=3,matk=1,mdef=3,ratk=2,rdef=2},dto={levelUp={}};
    foreach(k,v in offer) dto.levelUp[B.Fields[k][1]+"Increase"]<-v;
    B.captureOffer(a,dto);B.actorState(a).plan=p;B.perkDefs=@() defs;
    local s=B.readActor(a),view=B.view(a,false,{EquipmentAdvice=false,LevelUpRecommendations=true});
    check(s.normalRows==1 && s.veteranRows==1 && s.futurePerks==0 && s.growthKnown,"stored row partition changed");
    check(view.offer.picks.find("hp")!=null && view.offer.picks.find("fatigue")!=null && view.offer.picks.find("matk")!=null,
        "unaffordable Gifted displaced essential Melee skill from current offer");
    foreach(k in view.offer.picks) s.stats[k]+=offer[k];s.normalRows--;
    check(B.feasibility(B.forPlan(s,p),p.targets,"mean").feasible,"next veteran row cannot complete advised minima");
    check(B.actorState(a).plan==p && p.route.find("perk.gifted")!=null && a.free==0 && a.pending==2,"offer rewrote saved intent or actor");
};

cases.failed_track_is_atomic <- function() {
    local a={m={},getID=@() 7},state=B.actorState(a),old=B.makePlan(B.findBuild("nimble_2h_axe"));
    old.revision=1;old.enabled=false;state.plan=old;state.revision=17;
    local screen={m={BroLedgerContext={actor=7,epoch=31,seq=0,settings={Enabled=true}}}};
    B.readActor=@(actor) fixture();B.ownedActor=@(id) a;
    B.view=function(actor,catalog,settings){throw "injected projection failure";};
    ::logError <- function(message) {};
    local result=B.command(screen,{actor=7,epoch=31,seq=1,revision=17,action="track",build="fencer"});
    local intact=state.plan==old && state.revision==17 && !old.enabled && old.revision==1;
    local enabled=B.command(screen,{actor=7,epoch=31,seq=2,revision=17,action="enabled",enabled=true});
    local enabledIntact=state.plan==old && state.revision==17 && !old.enabled;
    B.view=@(actor,catalog,settings) {actor=7,revision=B.actorState(actor).revision};
    local retry=B.command(screen,{actor=7,epoch=31,seq=3,revision=17,action="track",build="fencer"});
    check("error" in result && intact,"failed Track changed plan or revision");
    check("error" in enabled && enabledIntact,"failed enable changed dormant intent");
    check(!("error" in retry) && state.plan.build=="fencer" && state.revision==18,"retry cannot commit exactly once after failed Track");
    check(!old.enabled && old.revision==1 && old.build=="nimble_2h_axe","Track mutated inherited plan object");
};

cases.view_refresh_and_disabled_contract <- function() {
    local a=actorFixture(),p=B.makePlan(B.findBuild("tempo_spear"));
    a.level=7;a.pending=0;a.spent=1;a.free=5;
    a.getID<-@() 7;a.getName<-@() "Manual flex";a.isPerkUnlockable<-@(id) true;
    a.skills.push(skill("perk.dodge",1));
    a.skills.push(skill("injury.missing_hand",4));a.skills.push(skill("trait.tiny",2));
    B.perkDefs=@() defs;B.actorState(a).plan=p;
    local settings={EquipmentAdvice=false,LevelUpRecommendations=false},v=B.view(a,false,settings);
    check(v.plan.equipment==null && v.plan.effects.dodge.value==9 && !v.plan.effects.nimble.owned,
        "equipment toggle hid current effects or planned Nimble became active");
    check(v.warnings.len()==1 && v.notes.len()==1,"material equipment warning lost with narrative removal");
    a.getInitiative=@() 40;v=B.view(a,false,settings);
    check(v.plan.effects.dodge.value==6,"refresh retained stale equipment/fatigue value");
    p.enabled=false;v=B.view(a,false,settings);
    check(!("effects" in v.plan) && !v.plan.enabled,"effects revived disabled plan");
    B.actorState(a).plan=null;check(B.view(a,false,settings).plan==null,"effects created missing plan");
};
cases.feature_gates_skip_advice_without_changing_grades_or_intent <- function() {
    local actor={m={},getID=@() 7,getName=@() "Feature gates",isPerkUnlockable=@(id) true};
    local state=B.actorState(actor),source=fixture();
    state.plan=B.makePlan(B.findBuild("forged_neutral_axe"));
    source.level=3;source.pending=1;
    foreach(k in B.Stats) source.stats[k]=60;
    local options={PerkHighlights=true,LevelUpRecommendations=true,EquipmentAdvice=true};
    B.readActor=@(actor) source;B.perkDefs=@() defs;
    local equipment=0,offers=0;
    B.readEquipment=function(actor){equipment++;return {};};B.equipmentAdvice=@(g,p,perks) {capacity=50};
    B.adviseOffer=function(s,p,o){offers++;return {picks=["hp","matk","mdef"]};};
    state.offer={level=3,pending=1,values={}};
    local before=B.copy(state),on=B.view(actor,true,options);
    check(equipment==1 && offers==1 && on.plan.equipment!=null && on.offer!=null,"default feature missing");
    foreach(id in ["PerkHighlights","LevelUpRecommendations","EquipmentAdvice"]) options[id]=false;
    local off=B.view(actor,true,options);
    check(equipment==1 && offers==1 && off.plan.equipment==null && off.offer==null,"disabled advice still calculated");
    check(same(on.builds,off.builds) && same(state,before),"feature toggle changed grade/strategy or saved intent");
    options.LevelUpRecommendations=true;B.view(actor,false,options);
    check(offers==2 && equipment==1,"recommendation toggle affected equipment");
    options.LevelUpRecommendations=false;options.EquipmentAdvice=true;
    B.view(actor,false,options);check(offers==2 && equipment==2,"equipment toggle affected recommendations");
};

cases.catalog_preview_identifies_saved_build_without_replacing_intent <- function() {
    local actor={m={},getID=@() 7,getName=@() "Saved preview",isPerkUnlockable=@(id) true};
    local state=B.actorState(actor),source=fixture(),options={EquipmentAdvice=false,LevelUpRecommendations=false};
    state.plan=B.makePlan(B.findBuild("forged_neutral_axe"));
    B.readActor=@(actor) source;B.perkDefs=@() defs;

    local before=B.copy(state.plan),active=B.view(actor,true,options);
    check("build" in active.plan && active.plan.build==before.build,"saved preview cannot identify its catalog row");
    check(same(state.plan,before),"catalog preview replaced saved route or revision");
    state.plan.enabled=false;before=B.copy(state.plan);
    local dormant=B.view(actor,true,options);
    check(dormant.plan.build==before.build && !dormant.plan.enabled,"disabled preview lost saved identity");
    check(same(state.plan,before),"disabled preview changed dormant intent");
    state.issue="Future schema";
    check(B.view(actor,true,options).plan==null && same(state.plan,before),"read-only schema exposed or changed saved intent");
};

cases.view_projects_all_talents_per_actor_without_saving_them <- function() {
    local a={m={},getID=@() 17,getName=@() "A",isPerkUnlockable=@(id) true};
    local b={m={},getID=@() 18,getName=@() "B",isPerkUnlockable=@(id) true};
    local source=fixture();source.free=0;source.futurePerks=10;
    B.perkDefs=@() defs;
    local talents=[0,1,2,3,null,3,2,1];
    foreach(i,k in B.Stats) {source.stats[k]=60;source.stars[k]=talents[i];}
    local other=B.copy(source);foreach(k in B.Stats) other.stars[k]=0;
    B.readActor=@(actor) actor.getID()==17 ? source : other;
    local state=B.actorState(a);state.plan=B.makePlan(B.findBuild("nimble_2h_axe"));
    local before=B.copy(state),raw=B.copy(source),options={EquipmentAdvice=false,LevelUpRecommendations=false};
    foreach(catalog in [true,false]) {
        local view=B.view(a,catalog,options);
        check("stars" in view && view.stars.len()==8 && same(view.stars,source.stars),"view dropped or remapped talents");
        local next=B.view(b,catalog,options);
        check(same(next.stars,other.stars) && same(view.stars,raw.stars),"actor switch leaked talents");
    }
    check(same(state,before) && same(source,raw),"talent display changed intent or source payload");

};

return cases;
