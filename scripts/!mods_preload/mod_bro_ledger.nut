::include("scripts/mods/bro_ledger/core");
::BroLedger.Hooks <- ::Hooks.register(::BroLedger.ID, ::BroLedger.Version, ::BroLedger.Name);
::BroLedger.Hooks.require("mod_msu >= 1.9.0", "mod_modern_hooks >= 0.6.0");
::BroLedger.Hooks.queue(">mod_msu", function() {
    ::BroLedger.Mod <- ::MSU.Class.Mod(::BroLedger.ID, ::BroLedger.Version, ::BroLedger.Name);
    foreach (file in ["catalog", "plan", "state", "actor", "equipment", "fit", "screen"])
        ::include("scripts/mods/bro_ledger/" + file);
    ::BroLedger.registerSettings();
    ::BroLedger.registerTooltips();
    ::Hooks.registerLateJS("ui/mods/bro_ledger/ledger.js");
    ::Hooks.registerCSS("ui/mods/bro_ledger/ledger.css");
    ::BroLedger.Hooks.hook("scripts/entity/tactical/player", function(q) {
        q.onSerialize = @(__original) function(out) {
            try { ::BroLedger.savePlan(this); }
            catch (error) {
                ::BroLedger.actorState(this).issue = "Plan could not be saved; normal campaign saving continues. See the game log.";
                ::logError(::BroLedger.Name + " serialization failed: " + error);
            }
            return __original(out);
        };
        q.onDeserialize = @(__original) function(input) {
            local result = __original(input);
            ::BroLedger.loadPlan(this);
            return result;
        };
        q.setAttributeLevelUpValues = @(__original) function(values) {
            local state = ::BroLedger.actorState(this);
            state.offer = null;
            state.revision++;
            return __original(values);
        };
        q.unlockPerk = @(__original) function(id) {
            local result = __original(id);
            ::BroLedger.actorState(this).revision++;
            return result;
        };
    });
    ::BroLedger.Hooks.hook("scripts/ui/global/data_helper", function(q) {
        q.addCharacterToUIData = @(__original) function(actor, data) {
            local result = __original(actor, data);
            try { if (::BroLedger.ownedActor(actor.getID()) != null) ::BroLedger.captureOffer(actor, data); }
            catch (error) { ::logError(::BroLedger.Name + " offer capture failed: " + error); }
            return result;
        };
    });
    ::BroLedger.Hooks.hook("scripts/ui/screens/character/character_screen", function(q) {
        q.m.BroLedgerContext <- null;
        q.show = @(__original) function() {
            ::BroLedger.Epoch++;
            this.m.BroLedgerContext = {epoch = ::BroLedger.Epoch, seq = -1, actor = null, settings = ::BroLedger.readSettings()};
            return __original();
        };
        q.hide = @(__original) function() {
            this.m.BroLedgerContext = null;
            return __original();
        };
        q.destroy = @(__original) function() {
            this.m.BroLedgerContext = null;
            return __original();
        };
        q.onBroLedger <- function(data) { return ::BroLedger.command(this, data); };
    });
});
