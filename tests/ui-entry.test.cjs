const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const vm = require('node:vm');
const {Controller} = require('../ui/mods/bro_ledger/ledger.js');
const {fixture, click} = require('./ui-fixture.cjs');

// Keep the production renderer and start at selection, before any backend data or comparison.
function entryFixture() {
    const f = fixture(0), owner = f.owner, Node = owner.screen.mContainer.constructor;
    owner.closeCompare();
    owner.render = Controller.prototype.render;
    owner.panel = new Node().appendTo(owner.screen.mContainer);
    owner.entry = new Node().appendTo(owner.screen.mContainer);
    owner.entry.createTextButton('Bro Planner', () => owner.evaluate());
    owner.screen.mDataSource.getSelectedBrother = () => ({id: 7});
    owner.select();
    return f;
}
function descendants(node) { return [node, ...node.children.flatMap(descendants)]; }
function retry(f) { return descendants(f.owner.screen.mContainer).find(n => n.value === 'Retry' && n.handlers.click); }

test('selected brother can Evaluate before initial data and reach empty-library Create and Import', () => {
    const f = entryFixture();
    assert.equal(f.owner.data, null);
    assert.equal(f.owner.entry.hidden, false, 'initial entry disappeared');
    click(f.owner.entry.children[0]);
    assert.equal(f.calls.at(-1).request.action, 'evaluate');
    f.reply();
    assert.deepEqual(f.owner.data.library, []);
    assert.equal(f.button('Source: All'),undefined);
    click(f.button('Create build'));
    assert.ok(f.byClass('bl-name-field').length, 'creator did not open');
    f.owner.evaluate(); f.reply();
    click(f.button('Import'));
    assert.ok(f.button('Import builds'), 'import did not open');
});

test('hidden effect payloads clear readouts across plan states without hiding the planner or reviving stale effects', () => {
    const active={enabled:true,label:'Saved route',projection:{horizon:11},jointState:'possible',statRows:[],route:{feasible:true}};
    const effects={dodge:{owned:true,value:17},nimble:{owned:true,value:60},battleForged:{owned:true,value:32.7}};
    for(const plan of [active,{enabled:false,label:'Saved route'},null]) {
        const f=entryFixture(),panel=f.owner.panel;
        f.reply({plan,effects});
        assert.equal(panel.find('.bl-effect').length,3);
        const old=f.calls.at(-1);
        f.owner.request('refresh');f.reply({plan,effects:null});
        old.callback({...f.data,seq:old.request.seq,plan,effects});
        assert.equal(panel.find('.bl-effect').length,0);
        assert.equal(f.owner.entry.hidden,false);
        assert.equal(panel.hidden,!(plan && plan.enabled));
        if(plan && plan.enabled) assert.ok(descendants(panel).some(n=>n.value===plan.label));
        assert.equal(f.owner.data.plan,plan);
        f.owner.request('refresh');f.reply({plan,effects});
        assert.equal(panel.find('.bl-effect').length,3);
    }
});

for (const failure of ['backend', 'empty response', 'transport throw']) {
    test('initial ' + failure + ' is visible and Retry recovers without invented data', () => {
        const f = entryFixture();
        if (failure === 'backend') f.calls.at(-1).callback({error: 'Diagnostic simulated backend error'});
        else if (failure === 'empty response') f.calls.at(-1).callback(null);
        else {
            const call = global.SQ.call;
            global.SQ.call = () => { throw new Error('Diagnostic simulated transport error'); };
            assert.doesNotThrow(() => f.owner.request('refresh'));
            global.SQ.call = call;
        }
        assert.equal(f.owner.data, null);
        assert.equal(f.owner.panel.hidden, false, 'error is inside a hidden panel');
        assert.equal(f.owner.panel.find('.bl-error').length, 1);
        assert.equal(f.owner.entry.hidden, false);
        click(retry(f)); f.reply();
        assert.ok(f.button('Create build')); assert.ok(f.button('Import'));
        assert.equal(f.owner.panel.find('.bl-error').length, 0);
        assert.equal(f.owner.panel.hidden, true);
    });
}

test('confirmed disable survives invalidated actor data; no selection and hidden screen hide entry', () => {
    const f = entryFixture(); f.reply({settings: {Enabled: false}});
    assert.equal(f.owner.entry.hidden, true);
    f.owner.select();
    assert.equal(f.owner.entry.hidden, true, 'pending actor read forgot confirmed disable');
    f.calls.at(-1).callback(null);
    assert.equal(f.owner.entry.hidden, true);
    assert.equal(f.owner.panel.hidden, true, 'confirmed disable exposed retry UI');
    f.owner.request('refresh'); f.reply();
    assert.equal(f.owner.entry.hidden, false);
    f.owner.screen.mDataSource.getSelectedBrother = () => null;
    f.owner.select(); assert.equal(f.owner.entry.hidden, true);
    f.owner.actor = 7; f.owner.visible = false; f.owner.invalidate(); f.owner.render();
    assert.equal(f.owner.entry.hidden, true);
});

test('late failures and detached Retry controls cannot affect another actor or hidden screen', () => {
    const f = entryFixture(), first = f.calls.at(-1);
    first.callback({error: 'First failure'});
    const oldRetry = retry(f);
    f.owner.screen.mDataSource.getSelectedBrother = () => ({id: 8});
    f.owner.select();
    const count = f.calls.length;
    first.callback({error: 'Late failure'}); click(oldRetry);
    assert.equal(f.calls.length, count);
    assert.equal(f.owner.panel.hidden, true);
    f.owner.visible = false; f.owner.invalidate(); f.owner.render();
    f.calls.at(-1).callback({error: 'After hide'});
    assert.equal(f.owner.panel.hidden, true);
    assert.equal(f.owner.entry.hidden, true);
});

test('production connection/show/hide hooks attach Evaluate and recheck settings on reopen', () => {
    const f = fixture(0), Node = f.owner.screen.mContainer.constructor, calls = [];
    f.owner.closeCompare();
    function CharacterScreen() {}
    CharacterScreen.prototype.onConnection = function (handle) {
        this.mSQHandle = handle; this.mContainer = new Node(); this.mCharacterScreen = new Node().appendTo(this.mContainer);
        this.mCharacterPanelModule = {mCharacterPanelHeaderModule: {mContainer: new Node().appendTo(this.mContainer)}};
    };
    CharacterScreen.prototype.show = CharacterScreen.prototype.hide = function () {};
    const context = vm.createContext({CharacterScreen, CharacterScreenPerksModule: function () {},
        CharacterScreenLeftPanelHeaderModule: function () {}, $: global.$,
        CharacterScreenDatasourceIdentifier: {Brother: {Selected: 'selected', Updated: 'updated'}},
        SQ: {call(handle, method, request, callback) {calls.push({request, callback});}}});
    vm.runInContext(readFileSync(require.resolve('../ui/mods/bro_ledger/ledger.js'), 'utf8'), context);
    const screen = new CharacterScreen();
    screen.mDataSource = {getSelectedBrother: () => ({id: 7}), addListener() {}};
    screen.onConnection('native-screen'); screen.show();
    const owner = screen.broLedger;
    assert.equal(owner.entry.hidden, false);
    click(owner.entry.children[0]); assert.equal(calls.at(-1).request.action, 'evaluate');
    const reply = extra => calls.at(-1).callback({...f.data, seq: calls.at(-1).request.seq, ...extra});
    reply({settings: {Enabled: false}}); assert.equal(owner.entry.hidden, true);
    owner.select(); assert.equal(owner.entry.hidden, true);
    screen.hide(); screen.show(); assert.equal(owner.entry.hidden, false);
    reply(); assert.equal(owner.entry.hidden, false);
    screen.hide(); assert.equal(owner.entry.hidden, true);
    calls.at(-1).callback({error: 'Late native screen response'});
    assert.equal(owner.panel.hidden, true);
});
