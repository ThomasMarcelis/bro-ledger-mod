local B=::BroLedger,cases={},defs=dofile("tests/perk_unlocks.nut");
function commandFixture() {
    local a={m={},getID=@() 7,getName=@() "Test",isPerkUnlockable=@(id) true},flags=libraryFlags();
    ::World<-{Flags=flags};B.ownedActor=@(id) id==7?a:null;B.readActor=@(actor) fixture();B.perkDefs=@() defs;
    local screen={m={BroLedgerContext={epoch=91,seq=-1,actor=null,settings={Enabled=true,LevelUpRecommendations=false,PerkHighlights=true}}}};
    return {actor=a,flags=flags,screen=screen,seq=0,request=function(action,extra={}) {
        local d={action=action,actor=7,seq=++this.seq,epoch=91,revision=B.actorState(a).revision};
        foreach(k,v in extra)d[k]<-v;return B.command(screen,d);
    }};
}
cases.empty_startup_uses_production_actor_library_and_view <- function() {
    local a=actorFixture(),flags=libraryFlags();
    a.getID<-@() 7;a.getName<-@() "Test";a.isGuest<-@() false;a.isAlive<-@() true;
    ::World.Flags<-flags;::World.getPlayerRoster<-@() {getAll=@() [a]};
    ::Const.Perks<-{Perks=[[{ID="perk.colossus",Unlocks=0,Name="Colossus",Icon="ui/perks/perk_01.png"}]]};
    local screen={m={BroLedgerContext={epoch=91,seq=-1,actor=null,
        settings={Enabled=true,LevelUpRecommendations=true,PerkHighlights=true}}}};
    foreach(seq,action in ["refresh","evaluate"]) {
        local r=B.command(screen,{action=action,actor=7,seq=seq});
        check(!("error" in r),"initial "+action+" failed: "+("error" in r?r.error:""));
        check(r.library.len()==0 && r.builds.len()==0 && r.libraryIssue==null && r.plan==null && r.newBuildID=="user_1",
            "empty campaign did not reach creator-ready response");
    }
    check(!flags.has(B.LibraryFlag) && B.actorState(a).revision==0,"initial reads wrote campaign or actor intent");
    local has=flags.has;flags.has=function(k){throw "Diagnostic simulated library read failure";};
    local r=B.command(screen,{action="refresh",actor=7,seq=2});
    check("error" in r && screen.m.BroLedgerContext.seq==1,"failed read invented success or authority");
    flags.has=has;r=B.command(screen,{action="evaluate",actor=7,seq=3});
    check(!("error" in r) && r.library.len()==0 && !flags.has(B.LibraryFlag),"retry did not recover empty library");
};
cases.create_edit_track_delete_disabled_continuity <- function() {
    local f=commandFixture();check(!("error" in f.request("refresh")),"refresh failed");
    local b=userBuild(),r=f.request("saveBuild",{definition=b,create=true});check(!("error" in r)&&r.builds.len()==1,"creation failed");
    r=f.request("track",{build=b.id});check(!("error" in r)&&r.plan.label==b.label,"tracking failed");
    local saved=B.copy(B.actorState(f.actor).plan);b.label="Changed";b.preferred.matk=99;
    r=f.request("saveBuild",{definition=b,create=false});check(!("error" in r)&&same(saved,B.actorState(f.actor).plan),"edit changed tracked snapshot");
    r=f.request("deleteBuild",{build=b.id});check(!("error" in r)&&r.builds.len()==0&&same(saved,B.actorState(f.actor).plan),"delete lost plan");
    check(!f.request("enabled",{enabled=false}).plan.enabled,"disable failed");
    check(f.request("enabled",{enabled=true}).plan.enabled&&same(saved,B.actorState(f.actor).plan),"reenable replaced intent");
};
cases.import_export_and_failure_rollbacks <- function() {
    local f=commandFixture();f.request("evaluate");local b=userBuild(),wire=B.encodeBuilds([b],defs);
    check(!("error" in f.request("import",{text=wire,policy="reject"})),"import failed");
    local original=f.flags.get(B.LibraryFlag),before=B.copy(B.actorState(f.actor));
    check("error" in f.request("import",{text=wire,policy="reject"}),"duplicate silently overwrote");
    check(original==f.flags.get(B.LibraryFlag)&&same(before,B.actorState(f.actor)),"rejected import changed owner");
    check(f.request("export",{build=b.id}).share==wire&&f.request("export",{build=null}).share==wire,"single/bulk export changed");
    B.view=function(...){throw "read failed";};
    check("error" in f.request("deleteBuild",{build=b.id}),"read failure ignored");
    check(original==f.flags.get(B.LibraryFlag)&&same(before,B.actorState(f.actor)),"read failure partially deleted");
};
cases.persistence_set_failure_keeps_plan_and_revision <- function() {
    local f=commandFixture();f.request("evaluate");local before=B.copy(B.actorState(f.actor));
    f.flags.set=function(k,v){throw "storage write rejected";};
    check("error" in f.request("saveBuild",{definition=userBuild(),create=true}),"write failure ignored");
    check(!f.flags.has(B.LibraryFlag)&&same(before,B.actorState(f.actor)),"write failure changed owner");
};
cases.first_block_import_single_bulk_and_notice <- function() {
    local a=userBuild(),b=userBuild("user_2");b.label="Second";
    local different=B.encodeBuilds([b],defs);
    foreach(builds in [[a],[a,b]]) {
        local wire=B.encodeBuilds(builds,defs);
        foreach(suffix in ["",wire,wire.slice(0,wire.len()-1),different+format("%c",0)+"junk"]) {
            local f=commandFixture();f.request("evaluate");
            local r=f.request("import",{text=wire+suffix,policy="reject"});
            check(!("error" in r) && f.flags.get(B.LibraryFlag)==wire,"first declared block was not imported exactly");
            check(("notice" in r)==(suffix!=""),"notice did not match ignored bytes");
            if(suffix!="") check(r.notice=="Extra text after the first build block was ignored.","notice missing from successful reply");
        }
    }
    local f=commandFixture(),wire=B.encodeBuilds([a],defs);f.request("evaluate");
    f.request("import",{text=wire,policy="reject"});f.request("track",{build=a.id});
    local plan=B.copy(B.actorState(f.actor).plan),r=f.request("import",{text=wire+different,policy="skip"});
    check(!("error" in r) && "notice" in r && f.flags.get(B.LibraryFlag)==wire,"skip imported excess or suppressed notice");
    r=f.request("import",{text=wire+different,policy="copy"});
    check(!("error" in r) && r.library.len()==2 && same(plan,B.actorState(f.actor).plan),"copy policy or tracked snapshot changed");
};
cases.invalid_first_block_import_is_atomic <- function() {
    local f=commandFixture();f.request("evaluate");local wire=B.encodeBuilds([userBuild()],defs);
    f.request("import",{text=wire,policy="reject"});f.request("track",{build="user_1"});
    local original=f.flags.get(B.LibraryFlag),before=B.copy(B.actorState(f.actor)),context=B.copy(f.screen.m.BroLedgerContext);
    local at=wire.find("perk.colossus"),illegal=wire.slice(0,at)+"perk.invalidx"+wire.slice(at+13),oversized=wire;
    while(oversized.len()<=B.ShareLimit) oversized+=wire;
    local writes=0;f.flags.set=function(k,v){writes++;};
    foreach(source in ["BL1|1:x"+wire,wire.slice(0,wire.len()-1),illegal+wire,"BL1|1:2"+wire.slice(7)+wire.slice(7),oversized]) {
        local r=f.request("import",{text=source,policy="copy"});
        check("error" in r && !("notice" in r),"invalid first block was salvaged or reported success");
        check(writes==0 && original==f.flags.get(B.LibraryFlag) && same(before,B.actorState(f.actor)) &&
            same(context,f.screen.m.BroLedgerContext),"invalid first block changed library, intent or authority");
    }
    check("error" in f.request("import",{text=wire+wire,policy="reject"}) && writes==0,"duplicate rejection weakened");
};
cases.first_block_import_keeps_saved_library_strict <- function() {
    local wire=B.encodeBuilds([userBuild()],defs);
    foreach(suffix in [wire,"junk",format("%c",0)]) {
        local damaged=wire+suffix,f=commandFixture();f.flags.set(B.LibraryFlag,damaged);
        check(rejects(@() B.decodeBuilds(damaged,defs)),"default decoder accepted trailing bytes");
        local read=B.readLibrary(f.flags,defs);
        check(read.issue!=null && read.issue.find("Diagnostic 0.4.3-d1")!=null && read.token==damaged && read.builds.len()==0,
            "saved malformed library lost strict validation or diagnostic");
        check(rejects(@() B.writeLibrary(f.flags,[],defs)) && f.flags.get(B.LibraryFlag)==damaged,"damaged saved bytes overwritten");
        f.request("evaluate");
        check("error" in f.request("import",{text=wire,policy="skip"}) && f.flags.get(B.LibraryFlag)==damaged,"import repaired damaged saved library");
    }
};
cases.stale_actor_epoch_library_and_revision <- function() {
    local f=commandFixture();f.request("evaluate");f.request("saveBuild",{definition=userBuild(),create=true});
    foreach(extra in [{actor=8},{epoch=90},{revision=0},{seq=0}]) {
        extra.build<-"user_1";check("error" in f.request("track",extra),"stale callback accepted");
    }
    f.flags.set(B.LibraryFlag,B.encodeBuilds([],defs));check("error" in f.request("track",{build="user_1"}),"stale library selection accepted");
    f.screen.m.BroLedgerContext=null;check("error" in f.request("refresh"),"closed screen accepted request");
};
cases.future_schema_global_disable_and_locked_perks <- function() {
    local f=commandFixture();f.request("evaluate");f.request("saveBuild",{definition=userBuild(),create=true});
    B.actorState(f.actor).issue="future schema retained";
    check("error" in f.request("track",{build="user_1"}),"future plan overwritten");
    B.actorState(f.actor).issue=null;f.actor.isPerkUnlockable=@(id) false;
    local r=f.request("track",{build="user_1"});check(r.plan.route.next==null,"locked native perk highlighted next");
    local before=B.copy(B.actorState(f.actor));f.screen.m.BroLedgerContext.settings.Enabled=false;
    check(f.request("refresh").plan==null,"global disable exposed plan");
    foreach(action in ["track","saveBuild","deleteBuild","import","enabled"])check("error" in f.request(action),"disabled mutation accepted");
    check(same(before,B.actorState(f.actor)),"disable changed intent");
};
cases.stock_offer_isolation <- function() {
    local actor={m={},getLevel=@() 3,getLevelUps=@() 1},dto={levelUp={}};
    foreach(k,fields in B.Fields)dto.levelUp[fields[1]+"Increase"]<-2;
    B.captureOffer(actor,dto);dto.levelUp.hitpointsIncrease=4;
    check(B.actorState(actor).offer.values.hp==2,"held stock payload by reference");
    B.captureOffer(actor,{levelUp=null});check(B.actorState(actor).offer==null,"stale offer retained");
};
return cases;
