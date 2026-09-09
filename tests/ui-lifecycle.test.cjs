const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const vm = require('node:vm');

// Execute the production prototype hooks as well as the Controller. The ordinary
// unit imports skip these hooks because CharacterScreen is absent in Node.
function session() {
    const calls = [], errors = [], renders = [], roots = new Set();
    let disconnected = 0;
    function node() {
        return {hide() { return this; }, appendTo() { return this; }, createTextButton() {},
            find() { return {each() {}}; }, remove() { roots.delete(this); }};
    }
    const foreign = () => {};
    const source = {mEventListener: {'brother.selected': [foreign], 'brother.updated': [foreign]},
        selected: {id: 7}, getSelectedBrother() { return this.selected; },
        addListener(channel, callback) { this.mEventListener[channel].push(callback); },
        // The shipped API calls Array.remove, which does not exist in the game VM.
        removeListener() { throw new Error('native Array.remove is unavailable'); },
        notifyBackendPopupDialogIsVisible() {}};
    function CharacterScreen() {}
    CharacterScreen.prototype.onConnection = function (handle) {
        this.mSQHandle = handle;
        this.mContainer = node(); roots.add(this.mContainer);
        this.mCharacterScreen = node();
        this.mCharacterPanelModule = {mCharacterPanelHeaderModule: {mContainer: node()}};
    };
    CharacterScreen.prototype.onDisconnection = function () {
        disconnected++; this.mSQHandle = null; this.mContainer.remove();
    };
    const context = vm.createContext({CharacterScreen,
        CharacterScreenPerksModule: function () {}, CharacterScreenLeftPanelHeaderModule: function () {},
        CharacterScreenDatasourceIdentifier: {Brother: {Selected: 'brother.selected', Updated: 'brother.updated'}},
        $: node, console: {error: message => errors.push(message)},
        SQ: {call(handle, method, data, callback) { calls.push({handle, method, data, callback}); }}});
    vm.runInContext(readFileSync(require.resolve('../ui/mods/bro_ledger/ledger.js'), 'utf8'), context);
    const screen = new CharacterScreen(); screen.mDataSource = source;
    function connect() {
        screen.onConnection('game-screen');
        const owner = screen.broLedger;
        owner.visible = true; owner.actor = 7;
        owner.data = {epoch: 42, revision: 1, plan: {enabled: true}};
        owner.render = () => renders.push(owner.data);
        return owner;
    }
    const reply = index => calls[index].callback({actor: calls[index].data.actor,
        seq: calls[index].data.seq, epoch: 42, revision: 2, settings: {Enabled: true}, plan: {enabled: true}});
    return {screen, source, connect, reply, calls, errors, renders, roots, foreign,
        disconnectCount: () => disconnected};
}

test('disconnect and reconnect remove only planner listeners and leave no stale screen', () => {
    const s = session();
    const selectedListeners = s.source.mEventListener['brother.selected'];
    for (let cycle = 0; cycle < 3; cycle++) {
        const owner = s.connect(); owner.request('refresh');
        assert.equal(s.roots.size, 1);
        assert.equal(selectedListeners.length, 2);
        s.screen.onDisconnection();
        assert.equal(s.disconnectCount(), cycle + 1);
        assert.equal(s.roots.size, 0);
        assert.equal(s.screen.mSQHandle, null);
        assert.equal(s.screen.broLedger, null);
        assert.equal(s.source.broLedger, null);
        assert.equal(owner.visible, false);
        assert.equal(owner.data, null);
        for (const listeners of Object.values(s.source.mEventListener)) assert.deepEqual(listeners, [s.foreign]);
        assert.equal(s.source.mEventListener['brother.selected'], selectedListeners);
        s.reply(cycle); assert.equal(s.renders.length, 0, 'disconnected response rendered');
    }
    assert.deepEqual(s.errors, []);
});

test('failed optional UI disposal still releases ownership and runs native teardown', () => {
    const s = session(), owner = s.connect();
    owner.panel.find = () => { throw new Error('tooltip disposal failed'); };
    assert.doesNotThrow(() => s.screen.onDisconnection());
    assert.equal(s.disconnectCount(), 1); assert.equal(s.roots.size, 0);
    assert.equal(s.screen.broLedger, null); assert.equal(s.source.broLedger, null);
    for (const listeners of Object.values(s.source.mEventListener)) assert.deepEqual(listeners, [s.foreign]);
    assert.equal(s.errors.length, 1); assert.match(s.errors[0], /tooltip disposal failed/);
});

test('equipment updates retain the rendered sheet and live offer while refreshing authority', () => {
    const s = session(), owner = s.connect(), offer = {};
    let comparisonsClosed = 0;
    owner.offerContent = offer; owner.closeCompare = () => comparisonsClosed++;
    owner.updated(s.source, {id: 8}); assert.equal(s.calls.length, 0);
    owner.updated(s.source, {id: 7});
    assert.equal(s.renders.length, 0, 'pending refresh moved or cleared the sheet');
    assert.equal(owner.offerContent, offer);
    assert.equal(owner.data, null, 'outdated revision stayed writable');
    assert.equal(comparisonsClosed, 1);
    owner.request('enabled', {enabled: false});
    assert.equal(s.calls.length, 1, 'pending refresh accepted a stale write');
    owner.updated(s.source, {id: 7});
    s.reply(0); assert.equal(s.renders.length, 0);
    s.reply(1); assert.equal(s.renders.length, 1);
    assert.equal(owner.data.revision, 2);
    owner.request('enabled', {enabled: false});
    assert.equal(s.calls[2].data.revision, 2);
});

test('changing brother clears the old guidance and ignores the previous actor response', () => {
    const s = session(), owner = s.connect(); owner.offerContent = {};
    owner.updated(s.source, {id: 7});
    s.source.selected = {id: 8}; owner.selected();
    assert.equal(owner.actor, 8); assert.equal(owner.offerContent, null);
    assert.equal(s.renders.length, 1); assert.equal(s.renders[0], null);
    s.reply(0); assert.equal(s.renders.length, 1);
    s.reply(1); assert.equal(s.renders.length, 2); assert.equal(owner.data.actor, 8);
});
