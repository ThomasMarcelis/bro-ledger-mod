// Real pinned MSU settings classes; only other systems, disk and JS transport are doubles.
try
{
    ::Math <- {ceil=ceil,floor=floor,round=@(v) floor(v+0.5),max=@(a,b) a.tointeger()>b.tointeger()?a.tointeger():b.tointeger(),
        min=@(a,b) a.tointeger()<b.tointeger()?a.tointeger():b.tointeger(),maxf=@(a,b) a>b?a:b,minf=@(a,b) a<b?a:b};
    ::MSU <- {Class={},System={},SystemID={ModSettings="ModSettings",Tooltips="Tooltips"},
        requireTable=function(v){if(typeof v!="table") throw "Expected table";},
        requireOneFromTypes=function(types,v){if(types.find(typeof v)==null) throw "Unexpected type";},
        requireBool=function(v){if(typeof v!="bool") throw "Expected boolean";},
        requireString=function(...){foreach(v in vargv) if(typeof v!="string") throw "Expected string";},
        SemVer={getTable=@(v) {Version=v,PreRelease=null,Metadata=null}}};
    foreach(file in ["classes/ordered_map","systems/system","systems/system_mod_addon","systems/mod",
        "systems/mod_settings/settings_element","systems/mod_settings/abstract_setting",
        "systems/mod_settings/elements/boolean_setting","systems/mod_settings/settings_page",
        "systems/mod_settings/settings_panel","systems/mod_settings/mod_settings_mod_addon",
        "systems/mod_settings/mod_settings_system", "systems/tooltips/abstract_tooltip",
        "systems/tooltips/tooltips/basic_tooltip", "systems/tooltips/tooltips_mod_addon", "systems/tooltips/tooltips_system"]) dofile(".tools/msu-contract/msu/"+file+".nut");
    local disk={},writes=0;
    ::MSU.Mod <- {PersistentData={hasFile=@(id) id in disk,readFile=@(id) disk[id],
        createFile=function(id,data){disk[id]<-data;writes++;}}};
    foreach(id in ["Registry","Debug","Keybinds","Serialization","PersistentData"])
        ::MSU.System[id]<-{registerMod=function(mod){}};
    ::MSU.System.Tooltips <- ::MSU.Class.TooltipsSystem();
    ::MSU.System.ModSettings <- ::MSU.Class.ModSettingsSystem();
    ::MSU.System.ModSettings.Screen={updateSettingInJS=function(mod,id,value){}};
    ::getModSetting <- @(mod,id) ::MSU.System.ModSettings.getPanel(mod).getSetting(id);
    local hooks={},registration=null,queued=null;
    ::Hooks <- {
        register=function(id,version,name) {
            registration={id=id,version=version,name=name};
            return {require=function(...){},queue=function(order,fn){queued=fn;},hook=function(path,fn){hooks[path]<-fn;}};
        },registerLateJS=function(path){},registerCSS=function(path){}
    };
    ::include <- @(path) dofile(path+".nut");
    dofile("scripts/!mods_preload/mod_bro_ledger.nut");
    if(queued==null || "readLibrary" in ::BroLedger) throw "Modules must load in the queued startup callback";
    queued.call(getroottable());
    local B=::BroLedger,system=::MSU.System.ModSettings,settings=B.Mod.ModSettings;
    function check(v,message) {if(!v) throw message;}
    function same(a,b) {
        if(typeof a!=typeof b) return false;
        if(typeof a=="table" || typeof a=="array") {
            if(a.len()!=b.len()) return false;
            foreach(k,v in a) if(!(k in b) || !same(v,b[k])) return false;
            return true;
        }
        return a==b;
    }
    local count=0;
    function test(name,fn){try {fn();} catch(e) {throw name+": "+e;} count++;print("PASS "+name+"\n");}
    test("queued_startup_refresh_and_evaluate_empty_library",function(){
        dofile("tests/fixtures.nut");
        local actor=actorFixture(),flags={has=@(key) false,set=function(...){throw "Startup wrote library";}};
        actor.getID<-@() 7;actor.getName<-@() "Test";actor.isGuest<-@() false;actor.isAlive<-@() true;
        ::World.Flags<-flags;::World.getPlayerRoster<-@() {getAll=@() [actor]};
        ::Const.Perks<-{Perks=[]};
        local screen={m={},show=function(){},hide=function(){},destroy=function(){}};
        local show=screen.show;
        hooks["scripts/ui/screens/character/character_screen"](screen);
        screen.show=screen.show(show);screen.show();
        foreach(seq,action in ["refresh","evaluate"]) {
            local r=screen.onBroLedger({action=action,actor=7,seq=seq});
            check(!("error" in r),"startup "+action+" failed: "+("error" in r ? r.error : ""));
            check(r.library.len()==0 && r.builds.len()==0 && r.libraryIssue==null && r.plan==null && r.newBuildID=="user_1",
                "startup did not return the empty editable library");
        }
        check(B.actorState(actor).revision==0,"startup changed actor intent");
    });
    test("msu_native_tooltips_dispatch",function(){
        foreach(id in ["stats","potential","expected","targets","dodge","nimble","battleForged"])
        {
            local data=::MSU.System.Tooltips.getTooltip(B.ID,id).getUIData({});
            check(data.len()==2 && data[0].type=="title" && data[1].type=="description" && data[1].text.len()>0,"native tooltip dispatch failed: "+id);
        }
    });
    test("msu_registration_defaults_and_native_persistence",function(){
        check(registration.id=="mod_bro_ledger" && registration.version==B.Version && registration.name==B.Name,"registration changed save identity or disagrees with mod metadata");
        local panel=system.getUIData()[B.ID];
        check(panel.name==B.Name && !panel.hidden && panel.pages.len()==1 && panel.pages[0].name==B.Name,"settings page missing/hidden/misnamed");
        check(panel.pages[0].settings.len()==3,"expected exactly three settings");
        foreach(id in ["Enabled","PerkHighlights","LevelUpRecommendations"])
            check(settings.getSetting(id).getValue() && settings.getSetting(id).getPersistence(),"default or persistence missing: "+id);
        check(writes==0,"registration overwrote persistent preferences");
        system.updateSettingsFromJS({[B.ID]={PerkHighlights={type="bool",value=false}}});
        check(writes==1 && disk.ModSettings[B.ID].PerkHighlights==false,"native settings update did not persist");
        // Fresh registration defaults then MSU import, as on next game startup.
        B.Mod=::MSU.Class.Mod(B.ID,B.Version,B.Name);B.registerSettings();
        check(B.Mod.ModSettings.getSetting("PerkHighlights").getValue(),"registration default changed");
        system.importPersistentSettings();settings=B.Mod.ModSettings;
        check(!B.readSettings().PerkHighlights && B.readSettings().Enabled && writes==1,"MSU import lost value or rewrote storage");
    });
    test("msu_campaign_settings_restore_without_rewriting_startup_preferences",function(){
        local campaign={};
        B.Mod.Serialization={flagSerialize=function(id,value){campaign[id]<-B.copy(value);},
            flagDeserialize=function(id,fallback){return id in campaign ? B.copy(campaign[id]) : fallback;}};
        ::MSU.Mod.Serialization <- {isSavedVersionAtLeast=@(version,metadata) true};
        system.flagSerialize(null);
        settings.getSetting("Enabled").set(false);local before=writes;
        system.flagDeserialize({getMetaData=@() {}});
        check(B.readSettings().Enabled && writes==before,"campaign restore missed saved value or rewrote preferences");
        system.importPersistentSettings();
        check(!B.readSettings().Enabled && writes==before,"startup preference was overwritten by campaign restore");
        settings.getSetting("Enabled").set(true);
    });
    local shown=0,hidden=0;
    local screen={m={},show=function(){shown++;},hide=function(){hidden++;},destroy=function(){},onBroLedger=null};
    local originalShow=screen.show,originalHide=screen.hide,originalDestroy=screen.destroy;
    hooks["scripts/ui/screens/character/character_screen"](screen);
    screen.show=screen.show(originalShow);screen.hide=screen.hide(originalHide);screen.destroy=screen.destroy(originalDestroy);
    local actor={m={},getID=@() 7,getName=@() "Test brother",isPerkUnlockable=@(id) true};
    local state=B.actorState(actor),legacy={schema=4,revision=5,enabled=true,build="user_1",label="Saved",targets={},preferredTargets={},route=[],flex=[],weaponTags=[],playstyleTags=[]};
    ::World <- {Flags={has=@(k) false}};B.perkDefs=@() {};
    legacy.revision=1;state.plan=legacy;
    B.ownedActor=function(id){if(id!=7) throw "Wrong actor";return actor;};
    local view=B.view,reads=0;
    B.view=function(actor,catalog,options,library=null){reads++;return {actor=7,revision=state.revision,plan=B.copy(state.plan)};};
    test("settings_close_reopen_global_disable_preserves_old_intent",function(){
        settings.getSetting("PerkHighlights").set(true);
        screen.show();local first=screen.m.BroLedgerContext,original=B.copy(state);
        settings.getSetting("Enabled").set(false);
        check(first.settings.Enabled,"setting mutated open-screen snapshot");
        screen.hide();screen.show();local disabled=screen.m.BroLedgerContext;
        check(disabled.epoch!=first.epoch && !disabled.settings.Enabled && shown==2 && hidden==1,"ordinary screen/boundary changed");
        local response=B.command(screen,{action="refresh",actor=7,seq=1});
        check(!response.settings.Enabled && response.plan==null && reads==0,"global disable evaluated actor or exposed plan");
        foreach(action in ["track","enabled","swap"])
            check("error" in B.command(screen,{action=action,actor=7,seq=2,epoch=disabled.epoch,revision=state.revision,build="fencer",enabled=false,index=0}),"disabled command mutated intent");
        check(same(state,original),"global toggle changed old plan or actor state");
        settings.getSetting("Enabled").set(true);screen.hide();screen.show();
        check("error" in B.command(screen,{action="track",actor=7,seq=3,epoch=first.epoch,revision=state.revision,build="fencer"}),"old epoch changed reopened plan");
        response=B.command(screen,{action="refresh",actor=7,seq=4});
        check(response.settings.Enabled && same(response.plan,legacy),"re-enable lost 0.1.0 intent");
        state.plan.enabled=false;screen.hide();screen.show();
        check(!B.command(screen,{action="refresh",actor=7,seq=5}).plan.enabled,"global re-enable enabled a dormant brother");
        state.issue="Future schema";local future=B.copy(state);
        check("error" in B.command(screen,{action="track",actor=7,seq=6,epoch=screen.m.BroLedgerContext.epoch,revision=state.revision,build="fencer"}),"future schema unlocked");
        check(same(state,future),"future schema state changed");
        state.issue=null;state.plan.enabled=true;
    });
    B.view=view;
    print("BRO_LEDGER_TESTS_PASSED "+count+"\n");
}
catch(e){print("FAIL "+e+"\n");}
