const {test, afterEach} = require('node:test');
const assert = require('node:assert/strict');
const {Controller, safe} = require('../ui/mods/bro_ledger/ledger.js');

const originalSQ = global.SQ;
afterEach(() => {
    if (originalSQ === undefined) delete global.SQ;
    else global.SQ = originalSQ;
});

function session() {
    const calls = [], renders = [], errors = [];
    global.SQ = {call(handle, method, data, callback) { calls.push({handle, method, data, callback}); }};
    const owner = new Controller({mSQHandle: 'test-screen'});
    owner.visible = true; owner.actor = 7;
    owner.render = () => renders.push(owner.data);
    owner.showError = message => errors.push(message);
    const reply = (i, extra = {}) => calls[i].callback({actor: calls[i].data.actor,
        seq: calls[i].data.seq, epoch: 42, revision: 0,
        settings: {Enabled: true, PerkHighlights: true, LevelUpRecommendations: true}, ...extra});
    return {owner, calls, renders, errors, reply};
}
test('disable sends the observed epoch and revision and ignores late earlier replies', () => {
    const s = session();
    s.owner.request('refresh'); s.reply(0, {revision: 3});
    s.owner.request('enabled', {enabled: false});
    assert.equal(s.calls[1].data.epoch, 42); assert.equal(s.calls[1].data.revision, 3);
    s.reply(1, {revision: 4, plan: {enabled: false}});
    s.reply(0, {plan: {enabled: true}});
    assert.equal(s.owner.data.plan.enabled, false);
});
test('wrong actor, wrong sequence and disconnected requests are ignored', () => {
    const s = session(); s.owner.request('refresh');
    s.reply(0, {actor: 9}); s.reply(0, {seq: -1});
    assert.equal(s.renders.length, 0);
    s.owner.screen.mSQHandle = null; s.owner.request('track', {build: 'fencer'});
    assert.equal(s.calls.length, 1);
});
test('native button labels escape player-provided text', () => {
    assert.equal(safe('<img src=x onerror="bad()"> &'), '&lt;img src=x onerror=&quot;bad()&quot;&gt; &amp;');
});
test('actual offer fields mark native rows through their sized button references', () => {
    const marked = [];
    function row(key, field) {
        return {StatValueIdentifier: field, Button: {closest(selector) {
            assert.equal(selector, '.row');
            return {addClass(value) { assert.equal(value, 'bl-recommended'); marked.push(key); }};
        }}};
    }
    // Shipped keys and field values; the native buttons have .button-8, not .button.
    const header = {
        mLevelUpLeftStatsRows: {
            Hitpoints: row('hp', 'hitpointsIncrease'), Bravery: row('resolve', 'braveryIncrease'),
            Fatigue: row('fatigue', 'fatigueIncrease'), Initiative: row('initiative', 'initiativeIncrease')},
        mLevelUpRightStatsRows: {
            MeleeSkill: row('matk', 'meleeSkillIncrease'), RangeSkill: row('ratk', 'rangeSkillIncrease'),
            MeleeDefense: row('mdef', 'meleeDefenseIncrease'), RangeDefense: row('rdef', 'rangeDefenseIncrease')}
    };
    const owner = new Controller({mCharacterPanelModule: {mCharacterPanelHeaderModule: header}});
    owner.markOfferRows(['hp', 'ratk', 'rdef']);
    assert.deepEqual(marked.sort(), ['hp', 'ratk', 'rdef']);
    marked.length = 0;
    owner.markOfferRows(['matk', 'mdef', 'resolve']);
    assert.deepEqual(marked.sort(), ['matk', 'mdef', 'resolve']);
});
test('global disable on reopen rejects old replies and never opens comparison', () => {
    const s = session(); let comparisons = 0;
    s.owner.compare = () => comparisons++;
    s.owner.evaluate();
    s.owner.visible = false; s.owner.invalidate();
    s.owner.visible = true; s.owner.request('refresh');
    s.reply(1, {settings: {Enabled: false}, plan: null});
    s.reply(0); assert.equal(s.owner.data.settings.Enabled, false);
    assert.equal(comparisons, 0);
    s.owner.evaluate(); s.reply(2, {settings: {Enabled: false}, plan: null});
    assert.equal(comparisons, 0, 'disabled Evaluate opened comparison');
    s.owner.visible = false; s.owner.invalidate(); s.owner.visible = true;
    s.owner.request('refresh'); s.reply(3, {plan: {enabled: false}});
    assert.equal(s.owner.data.plan.enabled, false, 'global re-enable changed dormant actor intent');
});
test('perk highlights gate both colours and keep original containers', () => {
    const marks = []; let clears = 0;
    const cell = id => ({ID: id, Container: {addClass: value => marks.push([id, value])}});
    const owner = new Controller({mContainer: {find: () => ({removeClass: () => clears++})},
        mRightPanelModule: {mPerksModule: {mPerkTree: [[cell('route'), cell('optional'), cell('flex-route'), cell('acquired')]]}}});
    owner.data = {settings: {Enabled: true, PerkHighlights: false},
        plan: {enabled: true, route: {remaining: ['route'], acquired: ['acquired'], blocked: ['flex-route']}, flex: ['optional', 'flex-route']}};
    owner.markPerks(); assert.deepEqual(marks, []); assert.equal(clears, 1);
    owner.data.settings.PerkHighlights = true; owner.markPerks();
    assert.deepEqual(marks, [['route', 'bl-route'], ['optional', 'bl-optional'], ['flex-route', 'bl-optional'], ['acquired', 'bl-route']]);
    marks.length = 0; owner.data.settings.Enabled = false; owner.markPerks();
    assert.deepEqual(marks, []);
});
test('disabled recommendations restore the ordinary popup without reading its offer', () => {
    const removed = [];
    const popup = {removeClass(value) { removed.push(value); return this; }};
    const content = {closest: () => popup, removeClass(value) { removed.push(value); return this; },
        find(selector) { return {remove() { removed.push(selector); }, removeClass(value) { removed.push(value); }}; }};
    const owner = new Controller({mDataSource: {getSelectedBrother() { throw new Error('disabled advice read offer'); }}});
    owner.offerContent = content;
    owner.data = {settings: {Enabled: true, LevelUpRecommendations: false}, plan: {enabled: true}};
    owner.renderOffer();
    assert.deepEqual(removed, ['bl-levelup-popup', 'bl-levelup', '.bl-offer', 'bl-recommended']);
});
test('render hides global UI while retaining the compact plan', () => {
    // Native control boundary double: collect text/visibility, not a DOM/layout emulator.
    const lines = [], visibility = [], classes = [];
    const node = {find() { return this; }, each() {}, empty() { return this; }, hide() { return this; },
        show() { return this; }, toggleClass() { return this; }, addClass(value) { classes.push(value); return this; }, removeClass() { return this; },
        text(value) { lines.push(value); return this; }, appendTo() { return this; },
        css() { return this; }, position() { return {top: 0}; }, outerHeight() { return 0; },
        bindTooltip() {}, unbindTooltip() {},
        attr() { return this; }, on() { return this; }, closest() { return this; }, trigger() { return this; },
        createTextButton() { return this; }, createList() { return this; }, findListScrollContainer() { return this; }};
    const previous = global.$; global.$ = () => node;
    try {
        const owner = new Controller({mContainer: node});
        owner.visible = true; owner.actor = 7;
        owner.panel = node; owner.entry = {toggle(value) { visibility.push(value); }};
        owner.markPerks = () => {}; owner.renderOffer = () => {};
        const route = {next: 'perk.a', remaining: ['perk.a'], offplan: [], unknown: [], blocked: [], conflicts: [], feasible: true};
        owner.data = {settings: {Enabled: true, PerkHighlights: false}, defs: {'perk.a': {name: 'Perk sentinel'}}, notes: [], warnings: [],
            effects: Object.fromEntries(['dodge', 'nimble', 'battleForged'].map(id => [id, {owned: false, value: null}])),
            plan: {label: 'Saved route', enabled: true, score: 50, projection: {horizon: 11}, statRows: [], route,
                weapons: 'Equipment sentinel', equipment: null}};
        owner.render();
        assert.equal(visibility.at(-1), true); assert.ok(lines.includes('Saved route'));
        assert.ok(!lines.includes('Equipment sentinel'));
        lines.length = 0; classes.length = 0; owner.data.settings.Enabled = false;
        owner.render();
        assert.equal(visibility.at(-1), false); assert.deepEqual(lines, []); assert.deepEqual(classes, []);
        assert.equal(owner.data.plan.label, 'Saved route');
    } finally { global.$ = previous; }
});

// Hélder's requirement: the three defence lines belong to the brother, not to a tracked build, and a
// perk he never took must not appear at all.
test('learned defence perks show on the sheet without a tracked build and absent perks stay hidden', () => {
    const lines = [], visibility = [], classes = [], removed = [];
    const node = {find() { return this; }, each() {}, empty() { return this; }, hide() { return this; },
        show() { return this; }, toggleClass() { return this; }, addClass(value) { classes.push(value); return this; },
        removeClass(value) { removed.push(value); return this; },
        text(value) { lines.push(value); return this; }, appendTo() { return this; },
        css() { return this; }, position() { return {top: 0}; }, outerHeight() { return 0; },
        bindTooltip() {}, unbindTooltip() {},
        attr() { return this; }, on() { return this; }, closest() { return this; }, trigger() { return this; },
        createTextButton() { return this; }, createList() { return this; }, findListScrollContainer() { return this; }};
    const previous = global.$; global.$ = () => node;
    try {
        const owner = new Controller({mContainer: node});
        owner.visible = true; owner.actor = 7;
        owner.panel = node; owner.entry = {toggle(value) { visibility.push(value); }};
        owner.markPerks = () => {}; owner.renderOffer = () => {};
        owner.data = {settings: {Enabled: true, PerkHighlights: false}, defs: {}, notes: [], warnings: [], plan: null,
            effects: {dodge: {owned: true, value: 17}, nimble: {owned: false, value: null},
                battleForged: {owned: true, value: 32.7}}};
        owner.render();

        assert.equal(visibility.at(-1), true, 'sheet entry hidden without a tracked build');
        assert.ok(lines.includes('Dodge Def') && lines.includes('+17'), 'learned Dodge missing without a plan');
        assert.ok(lines.includes('Forged Armour DR') && lines.includes('32.7%'), 'learned Battle Forged missing without a plan');
        assert.ok(!lines.some(line => line.indexOf('Nimble') !== -1), 'unlearned Nimble was rendered');
        assert.ok(!classes.includes('bl-with-plan'), 'plan-sized frame applied without a plan');

        // An owned-but-unreadable effect still names the perk rather than inventing a number.
        lines.length = 0;
        owner.data.effects = {dodge: {owned: true, value: null}, nimble: {owned: false, value: null},
            battleForged: {owned: false, value: null}};
        owner.render();
        assert.ok(lines.includes('Dodge Def') && lines.includes('?'), 'owned Dodge vanished or invented a value when unreadable');

        // A brother with none of the three keeps the panel closed rather than showing an empty block.
        lines.length = 0; classes.length = 0;
        owner.data.effects = Object.fromEntries(['dodge', 'nimble', 'battleForged'].map(id => [id, {owned: false, value: null}]));
        owner.render();
        assert.deepEqual(lines, [], 'panel rendered text with no learned perks and no plan');
    } finally { global.$ = previous; }
});
