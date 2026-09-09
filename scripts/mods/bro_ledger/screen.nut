::BroLedger.Epoch <- 0;

::BroLedger.registerSettings <- function()
{
    local page = this.Mod.ModSettings.addPage("General", this.Name);
    local timing = " Close and reopen the character sheet to apply.";
    page.addBooleanSetting("Enabled", true, "Enable planner",
        "Show Evaluate and saved-plan guidance. Turning this off retains every brother's plan." + timing);
    page.addBooleanSetting("PerkHighlights", true, "Perk highlights",
        "Show green route and blue flexible-perk marks. Perk choices stay manual." + timing);
    page.addBooleanSetting("LevelUpRecommendations", true, "Level-up recommendations",
        "Suggest three attributes from the actual offered rolls. Spend points yourself." + timing);

};

::BroLedger.registerTooltips <- function()
{
    local tips = {
        stats = ["Underlying stats", "Permanent stats before equipment, Colossus, Fortified Mind and Dodge. Lasting traits and injuries count."],
        potential = ["Potential target fit", "Best weakest-target satisfaction in one finite allocation at average rolls. Minimum = 50; Ideal = 100. Equal Minimum and Ideal use one 0–100 ramp. Excess stats never compensate. This is target fit, not combat strength or win probability."],
        expected = ["Shared forecast", "All eight projected stats share three selections per remaining level. Average rolls are assumptions, not revealed future rolls. Red requires a maximum-roll bound within this horizon."],
        targets = ["Ideal progress", "Green: already met. Yellow: needs development. Red: impossible even with every remaining row invested here at maximum rolls, within the displayed level horizon. Joint shortfalls are shown separately."],
        dodge = ["Dodge defence", "Current bonus to both melee and ranged defence: 15% of current Initiative. Equipment and accumulated fatigue affect it."],
        nimble = ["Nimble HP reduction", "Current reduction of damage to hitpoints. At most 60%, with raw head and body fatigue penalty of 15 or less. Brawny does not reduce that raw weight."],
        battleForged = ["Battle Forged armour reduction", "Current reduction of damage to armour, using remaining head and body armour. It falls as armour is damaged; it does not measure HP damage reduction."]
    };
    foreach (id, pair in tips) tips[id] = ::MSU.Class.BasicTooltip(pair[0], pair[1]);
    this.Mod.Tooltips.setTooltips(tips);
};

::BroLedger.readSettings <- function()
{
    local settings = {};
    foreach (id in ["Enabled", "PerkHighlights", "LevelUpRecommendations"])
        settings[id] <- this.Mod.ModSettings.getSetting(id).getValue();
    return settings;
};

::BroLedger.tagIcons <- function(defs)
{
    local icons={},perks={Shield="shield_expert",Spear="mastery.spear",Sword="mastery.sword",Hammer="mastery.hammer",
        Axe="mastery.axe",Mace="mastery.mace",Flail="mastery.flail",Cleaver="mastery.cleaver",Whip="mastery.cleaver",
        Dagger="mastery.dagger",Polearm="mastery.polearm",Bow="mastery.bow",Crossbow="mastery.crossbow",Throwing="mastery.throwing",
        Handgonne="mastery.crossbow",["Light armour"]="nimble",["Heavy armour"]="battle_forged"};
    foreach(tag,perk in perks) {local id="perk."+perk;if(id in defs && "icon" in defs[id] && defs[id].icon!=null) icons[tag]<-defs[id].icon;}
    return icons;
};
::BroLedger.view <- function(actor, catalog, settings, library=null)
{
    local state=this.actorState(actor),snapshot=this.readActor(actor),defs=this.perkDefs();
    if(library==null) library=this.readLibrary(::World.Flags,defs);
    local out={actor=actor.getID(),name=actor.getName(),revision=state.revision,issue=state.issue,plan=null,
        stars=this.copy(snapshot.stars),notes=snapshot.notes,warnings=snapshot.warnings,defs=defs,builds=[],offer=null,
        libraryIssue=library.issue,library=library.builds,tagIcons=this.tagIcons(defs),weaponTags=this.WeaponTags,playstyleTags=this.PlaystyleTags};
    if(catalog) out.builds=this.compare(snapshot,defs,library.builds).builds;
    if(state.issue!=null || state.plan==null) return out;
    local saved=state.plan;
    out.plan={build=saved.build,label=saved.label,enabled=saved.enabled,legacy=saved.schema<4};
    if(!saved.enabled) return out;
    local plan=this.guidancePlan(saved,snapshot);
    out.plan.route<-this.route(plan,snapshot,defs);
    if(out.plan.route.next!=null && !actor.isPerkUnlockable(out.plan.route.next)) out.plan.route.next=null;
    out.plan.order<-this.copy(saved.route);
    out.plan.flex<-this.flexPerks(plan,snapshot,defs);
    out.plan.effects<-this.currentEffects(actor,snapshot.perks);
    out.plan.options<-[];
    foreach(index,option in ("options" in plan ? plan.options : [])) {
        local active=plan.swaps.find(index)!=null,from=active ? option.with : option.replace;
        if(from in snapshot.perks || plan.route.find(from)==null) continue;
        out.plan.options.push({index=index,replace=option.replace,with=option.with,active=active,condition=option.condition});
    }
    foreach(k,v in this.assess(this.forPlan(snapshot,plan),plan,this.planPreferred(plan))) out.plan[k]<-v;
    if(settings.LevelUpRecommendations && state.offer!=null && state.offer.level==snapshot.level &&
        state.offer.pending==snapshot.pending && snapshot.pending>0) {
        out.offer=this.adviseOffer(snapshot,plan,state.offer.values);
        if(out.offer!=null) {out.offer.values<-state.offer.values;out.offer.label<-plan.label;}
    }
    return out;
};

::BroLedger.command <- function(screen, data)
{
    if(typeof data!="table" || !("actor" in data) || !("seq" in data) || !("action" in data) ||
        typeof data.actor!="integer" || typeof data.seq!="integer" || data.seq<0 || typeof data.action!="string")
        return {error="Invalid planner request."};
    local context=screen.m.BroLedgerContext;
    if(context==null || data.seq<=context.seq) return {error="Character screen changed. Refresh the planner."};
    local write=["refresh","evaluate","export"].find(data.action)==null;
    if(!context.settings.Enabled) {
        if(write || data.action=="export") return {error="Planner is disabled in Mod Options."};
        context.seq=data.seq;
        return {actor=data.actor,seq=data.seq,epoch=context.epoch,title=this.Name,settings=context.settings,plan=null};
    }
    local actor=this.ownedActor(data.actor);
    if(actor==null) return {error="Select a living company brother."};
    local state=this.actorState(actor),previous=state.plan,revision=state.revision;
    try {
        local defs=this.perkDefs(),library=this.readLibrary(::World.Flags,defs),next=library.builds,changed=false,share=null,notice=null;
        if(write || data.action=="export") {
            if(!("epoch" in data) || !("revision" in data) || data.epoch!=context.epoch ||
                data.actor!=context.actor || data.revision!=state.revision || !("libraryToken" in context) || context.libraryToken!=library.token)
                throw "Plan or library changed; refresh before choosing.";
        }
        if(["track","replace","enabled"].find(data.action)!=null && state.issue!=null) throw state.issue;
        if(["saveBuild","deleteBuild","import","export","track"].find(data.action)!=null && library.issue!=null) throw library.issue;
        if(data.action=="saveBuild") {
            if(!("definition" in data) || !this.validBuild(data.definition,defs) || !("create" in data) || typeof data.create!="bool")
                throw "Check name (40 bytes), target pairs (0–500, two decimals), and legal perk order (10 perks, plus Student).";
            next=this.copy(next);local found=this.findBuild(data.definition.id,next);
            if(data.create && found!=null) throw "Build ID already exists. Refresh before creating.";
            if(!data.create && found==null) throw "Build was removed. Refresh before editing.";
            foreach(b in next) if(b.id!=data.definition.id && b.label.tolower()==data.definition.label.tolower()) throw "A build already has this name.";
            if(found!=null) next.remove(next.find(found));next.push(this.copy(data.definition));changed=true;
        }
        else if(data.action=="deleteBuild") {
            if(!("build" in data) || typeof data.build!="string") throw "Choose a build to delete.";
            next=this.copy(next);local found=this.findBuild(data.build,next);if(found==null) throw "Unknown build.";
            next.remove(next.find(found));changed=true;
        }
        else if(data.action=="import") {
            if(!("text" in data) || !("policy" in data)) throw "Paste share text and choose a duplicate policy.";
            local importInfo={};
            next=this.mergeBuilds(next,this.decodeBuilds(data.text,defs,importInfo),data.policy,defs);changed=true;
            if(importInfo.ignoredExtra) notice="Extra text after the first build block was ignored.";
        }
        else if(data.action=="export") {
            if(!("build" in data) || (data.build!=null && typeof data.build!="string")) throw "Choose one build or the whole library.";
            local selected=data.build==null ? null : this.findBuild(data.build,next);
            if(data.build!=null && selected==null) throw "Unknown build.";
            share=this.encodeBuilds(selected==null ? next : [selected],defs);
        }
        else if(data.action=="track") {
            if(!("build" in data) || typeof data.build!="string") throw "Choose a library build.";
            local build=this.findBuild(data.build,next);if(build==null) throw "Unknown build.";
            state.plan=this.makePlan(build);
        }
        else if(data.action=="enabled") {
            if(!("enabled" in data) || typeof data.enabled!="bool" || state.plan==null) throw "No saved plan.";
            state.plan=this.copy(state.plan);state.plan.enabled=data.enabled;
        }
        else if(data.action=="replace") {
            if(state.plan==null || !state.plan.enabled || state.plan.schema==4) throw "No legacy perk alternative.";
            local snapshot=this.readActor(actor),plan=this.guidancePlan(state.plan,snapshot);
            if(!("index" in data) || typeof data.index!="integer" || data.index<0 || data.index>=plan.options.len() ||
                !("replace" in data) || !("with" in data) || !("active" in data)) throw "Unknown perk alternative.";
            local option=plan.options[data.index];
            if(data.replace!=option.replace || data.with!=option.with || data.active!=(plan.swaps.find(data.index)!=null) ||
                !(option.replace in defs) || !(option.with in defs)) throw "Perk alternatives changed; refresh.";
            state.plan=this.replacePlan(plan,data.index,snapshot.perks);
        }
        else if(data.action!="refresh" && data.action!="evaluate") throw "Unknown command.";
        if(write) {
            if(state.plan!=null && !this.validPlan(state.plan)) throw "Invalid plan; previous intent retained.";
            state.revision++;
        }
        // Prepare the complete response before committing library bytes, so read errors cannot partially import.
        local result=this.view(actor,data.action!="refresh" && data.action!="enabled" && data.action!="replace",context.settings,
            {builds=next,issue=library.issue});
        result.epoch<-context.epoch;result.seq<-data.seq;result.title<-this.Name;result.settings<-context.settings;
        if(share!=null) result.share<-share;
        if(notice!=null) result.notice<-notice;
        result.newBuildID<-this.newBuildID(next);
        local token=changed ? this.writeLibrary(::World.Flags,next,defs) : library.token;
        context.seq=data.seq;context.actor=data.actor;
        context.libraryToken<-token;
        return result;
    }
    catch(error) {state.plan=previous;state.revision=revision;return {error=error.tostring()};}
};
