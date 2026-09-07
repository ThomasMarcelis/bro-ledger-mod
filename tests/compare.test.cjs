const {test, afterEach} = require('node:test');
const assert = require('node:assert/strict');
const {Controller} = require('../ui/mods/bro_ledger/ledger.js');
const catalog = [
    {id: 'frontline', label: 'Frontline fixture', role: 'Two-handed', weaponTags: ['Axe']},
    {id: 'ranged', label: 'Ranged fixture', role: 'Ranged', weaponTags: ['Bow']},
    {id: 'support', label: 'Support fixture', role: 'Hybrid', weaponTags: ['Bow', 'Throwing']}
];
const globals = {SQ: global.SQ, $: global.$, Path: global.Path};
afterEach(() => {
    for (const [key, value] of Object.entries(globals)) {
        if (value === undefined) delete global[key];
        else global[key] = value;
    }
});

// Records native control calls; rendered layout requires the game.
function comparison(plan = null, issue = null) {
    const nodes = [], calls = [], notices = [];
    function node(markup = '') {
        const n = {classes: new Set((/class="([^"]*)"/.exec(markup) || ['', ''])[1].split(' ')),
            children: [], handlers: {}, value: '', attributes: {}, parent: null,
            addClass(s) { s.split(' ').forEach(c => this.classes.add(c)); return this; },
            removeClass(s) { s.split(' ').forEach(c => this.classes.delete(c)); return this; },
            text(s) { this.value = s; return this; },
            attr(k, v) { if (v === undefined) return this.attributes[k]; this.attributes[k] = v; return this; },
            appendTo(p) { p.append(this); return this; },
            append(child) { this.children.push(child); child.parent = this; return this; },
            empty() { this.children = []; return this; },
            remove() { this.parent.children = this.parent.children.filter(c => c !== this); this.removed = true; return this; },
            hide() { this.hidden = true; return this; },
            show() { this.hidden = false; return this; },
            toggle(v) { this.hidden = !v; return this; },
            on(event, fn) { this.handlers[event] = fn; return this; },
            find(selector) {
                const matches = [];
                function visit(p) { p.children.forEach(c => { if (c.classes.has(selector.slice(1))) matches.push(c); visit(c); }); }
                visit(this);
                return {append(child) { matches[0].append(child); }, closest() { return matches[0].closest(); }, find(selector) { return matches[0].find(selector); }, each(fn) { matches.forEach(c => fn.call(c)); },
                    removeClass(s) { matches.forEach(c => c.removeClass(s)); },
                    empty() { matches.forEach(c => c.empty()); return matches[0]; }};
            },
            createList() { const list = node('class="bl-scroll"').appendTo(this); list.content = node().appendTo(list); return list; },
            findListScrollContainer() { return this.content; },
            closest() { return this.parent; },
            trigger(event) { if (event === 'hide-tooltip') this.tooltipTimer = false; return this; }, scrollListToElement() { return this; },
            destroyList() {},
            css() { return this; }, position() { return {top: 0}; }, outerHeight() { return 0; },
            bindTooltip(data) { this.tooltip = data; this.tooltipTimer = true; },
            unbindTooltip() { this.tooltip = null; },
            enableButton(v) { this.disabled = !v; return this; },
            createTextButton(label, action) {
                const b = node().text(label).appendTo(this); b.handlers.click = action; return b;
            },
            createPopupDialog() {
                const popup = node().appendTo(this);
                popup.content = node().appendTo(popup); popup.buttons = {};
                popup.findPopupDialogContentContainer = () => popup.content;
                popup.addPopupDialogButton = (label, cls, fn, disabled) => {
                    const b = node().appendTo(popup); b.value = label; b.handlers.click = fn; b.disabled = !!disabled;
                    popup.buttons[cls] = b; return popup;
                };
                popup.addPopupDialogCancelButton = fn => popup.addPopupDialogButton('Cancel', 'l-cancel-button', fn);
                popup.findPopupDialogOkButton = () => popup.buttons['l-ok-button'];
                popup.findPopupDialogButton = cls => popup.buttons[cls];
                popup.destroyPopupDialog = () => { popup.children = []; };
                return popup;
            }};
        nodes.push(n); return n;
    }
    global.$ = input => typeof input === 'string' ? node(input) : input;
    global.Path = {GFX: 'coui://gfx/'};
    global.SQ = {call(handle, method, data) { calls.push(data); }};
    const owner = new Controller({mContainer: node(), mSQHandle: 'fixture',
        mDataSource: {notifyBackendPopupDialogIsVisible: v => notices.push(v)}});
    owner.visible = true; owner.actor = 7;
    const route = {next: null, remaining: ['perk.a'], acquired: [], offplan: [], unknown: [], blocked: [], conflicts: [], feasible: true};
    const data = {actor: 7, epoch: 42, revision: 3, title: 'Planner', warnings: [], name: '<Test brother>',
        settings: {Enabled: true, PerkHighlights: true, EquipmentAdvice: true}, issue, plan,
        stars: {hp: 0, resolve: 0, fatigue: 0, initiative: 0, matk: 0, ratk: 0, mdef: 0, rdef: 0}, defs: {'perk.a': {name: 'Perk A'}}, notes: ['Fixture assumption'],
        builds: catalog.map(build => ({...build, grade: 'B', nowGrade: 'D', projection: {horizon: 11, known: true,
            allocation: {hp: [4, 0, 0], resolve: [0, 0, 0], fatigue: [6, 0, 0], initiative: [0, 0, 0],
                matk: [10, 0, 1], ratk: [0, 0, 0], mdef: [10, 0, 1], rdef: [0, 0, 1]}},
            statRows: ['hp', 'resolve', 'fatigue', 'initiative', 'matk', 'ratk', 'mdef', 'rdef'].map(key =>
                ({key, now: 60, expected: 80, minimum: key === 'hp' ? 80 : null, ideal: key === 'hp' ? 90 : null,
                    minimumState: key === 'hp' ? 'grow' : 'none', idealState: key === 'hp' ? 'grow' : 'none', expectedShortfall: false})),
            note: 'Strategy assumption', weapons: 'Equipment sentinel', adjustments: [],
            route}))};
    owner.data = data;
    owner.compare(data);
    return {owner, data, nodes, calls, notices, node, rows: () => nodes.filter(n => n.classes.has('bl-build-row')),
        button: key => owner.popup.buttons[key], lines: () => nodes.map(n => n.value)};
}
function click(n) { assert.ok(n, 'action/row missing'); n.handlers.click(); }
function renderedText(n) { return n.value + n.children.map(renderedText).join(''); }

test('comparison previews first or saved ID without writes; selected footer action commits once', () => {
    for (const plan of [null, {build: catalog[1].id, label: 'Old saved label', enabled: true}]) {
        const s = comparison(plan), before = JSON.stringify(s.data);
        const rows = s.rows(); assert.equal(rows.length, catalog.length);
        assert.equal(rows.findIndex(r => r.classes.has('is-selected')), plan ? 1 : 0);
        rows.forEach(click);
        assert.deepEqual(rows.map(r => r.attributes['data-build']), catalog.map(b => b.id));
        assert.equal(rows.filter(r => r.classes.has('is-selected')).length, 1);
        assert.deepEqual(s.calls, []); assert.equal(JSON.stringify(s.data), before);
        const commit = s.button('l-ok-button'); click(commit); click(commit);
        assert.deepEqual(s.calls.map(c => [c.action, c.build, c.actor, c.epoch, c.revision]), [['track', catalog.at(-1).id, 7, 42, 3]]);
        assert.deepEqual(s.notices, [true, false]);
    }
});
test('server role alternatives and acquired adaptations stay honest without implicit tracking', () => {
    const s = comparison();
    s.data.primary = [catalog[0].id, catalog[1].id]; s.data.recommended = null;
    Object.assign(s.data.builds[0], {preferred: true, niche: 'Role niche sentinel',
        adjustments: [{replace: 'perk.a', with: 'perk.mace'}]});
    s.data.defs['perk.mace'] = {name: 'Mace Mastery'};
    s.owner.compare(s.data);
    assert.ok(s.lines().some(line => /One of 2 preferred roles/.test(line)));
    assert.ok(s.lines().includes('Role niche sentinel'));
    assert.ok(s.lines().some(line => line.includes('Mace Mastery') && line.includes('Perk A')));
    s.data.builds[0].fallback = true; s.data.builds[0].preferred = false;
    s.owner.compare(s.data);
    assert.ok(s.lines().includes('Now D') && s.lines().includes('Potential B'));
    assert.deepEqual(s.calls, []);
});
test('Cancel and closed/replaced/invalidated comparison callbacks never mutate metadata', () => {
    for (const invalidate of ['cancel', 'replace', 'refresh', 'hide', 'actor', 'global']) {
        const s = comparison(), old = s.button('l-ok-button');
        if (invalidate === 'cancel') click(s.button('l-cancel-button'));
        if (invalidate === 'replace') s.owner.compare(s.data);
        if (invalidate === 'refresh') s.owner.invalidate();
        if (invalidate === 'hide') s.owner.visible = false;
        if (invalidate === 'actor') s.owner.actor = 8;
        if (invalidate === 'global') s.data.settings.Enabled = false;
        click(old); assert.deepEqual(s.calls, [], invalidate);
    }
});
test('dormant resume is separate from template replacement and blocked state stays read-only', () => {
    const s = comparison({build: catalog[1].id, label: 'Saved variant', enabled: false});
    const before = JSON.stringify(s.data.plan), resume = s.button('bl-resume-button');
    click(s.rows()[2]); click(resume); click(resume);
    assert.equal(JSON.stringify(s.data.plan), before);
    assert.deepEqual(s.calls.map(c => [c.action, c.enabled, c.build]), [['enabled', true, undefined]]);
    const blocked = comparison(null, 'Newer schema: retained without changes');
    blocked.rows().forEach(click); const commit = blocked.button('l-ok-button');
    assert.equal(commit.disabled, true); click(commit);
    assert.deepEqual(blocked.calls, []);
    assert.ok(blocked.lines().includes('Newer schema: retained without changes'));
});
test('preview keeps targets, route, assumptions and gated equipment; errors leave Cancel usable', () => {
    const s = comparison();
    assert.ok(s.lines().includes('Equipment sentinel'));
    s.data.settings.EquipmentAdvice = false; const start = s.nodes.length;
    s.owner.compare(s.data);
    const shown = s.nodes.slice(start).map(n => n.value);
    assert.ok(!shown.includes('Equipment sentinel'));
    for (const line of ['Strategy assumption', 'Fixture assumption', '1. Perk A']) assert.ok(shown.includes(line), line);
    const commit = s.button('l-ok-button'); s.owner.data = null;
    s.owner.showError('Read failed; reopen Evaluate.');
    assert.ok(s.lines().includes('Read failed; reopen Evaluate.'));
    assert.equal(commit.disabled, true);
    click(commit); click(s.button('l-cancel-button')); assert.deepEqual(s.calls, []);
});
test('comparison preserves the complete numbered route without writing intent', () => {
    const s = comparison(), route = s.data.builds[0].route;
    const names = ['Colossus', 'Pathfinder', 'Dodge', 'Quick Hands', 'Gifted', 'Nimble',
        'Underdog', 'Berserk', 'Fearsome', 'Killing Frenzy'];
    route.remaining = names.map((name, i) => {
        const id = 'perk.test_' + i; s.data.defs[id] = {name}; return id;
    });
    route.feasible = false;
    const before = JSON.stringify(s.data), start = s.nodes.length;
    s.owner.compare(s.data);
    const shown = s.nodes.slice(start).map(n => n.value);
    assert.deepEqual(shown.filter(line => /^\d+\. /.test(line)), names.map((name, i) => (i + 1) + '. ' + name));
    assert.equal(JSON.stringify(s.data), before); assert.deepEqual(s.calls, []);
});

test('disclosures reveal advice without writing intent; route warnings stay outside collapsed content', () => {
    const s = comparison(), route = s.data.builds[0].route;
    route.feasible = false; route.unknown = ['perk.missing']; route.offplan = ['perk.a'];
    s.owner.compare(s.data);
    const before = JSON.stringify(s.data);
    const toggles = s.nodes.filter(n => n.classes.has('bl-disclosure-toggle'));
    assert.ok(toggles.length >= 3);
    toggles.forEach(n => {
        assert.equal(n.attr('aria-expanded'), 'false');
        click(n); assert.equal(n.attr('aria-expanded'), 'true');
        click(n); assert.equal(n.attr('aria-expanded'), 'false');
    });
    const warnings = s.nodes.filter(n => n.classes.has('bl-warning'));
    assert.ok(warnings.some(n => /cannot currently be completed/.test(n.value)));
    assert.ok(warnings.some(n => /Missing definitions/.test(n.value)));
    warnings.forEach(n => {
        for (let p = n.parent; p; p = p.parent) assert.ok(!p.hidden, 'warning hidden by disclosure');
    });
    assert.equal(JSON.stringify(s.data), before); assert.deepEqual(s.calls, []);
});

test('both layouts present server target states and forecast without recalculating or mutating them', () => {
    for (const compact of [false, true]) {
        const s = comparison(), build = s.data.builds[0];
        Object.assign(build.statRows[0], {now: 79.99999, expected: 79.99999, minimum: 80, ideal: 90,
            minimumState: 'grow', idealState: 'grow', expectedShortfall: true});
        Object.assign(build.statRows[3], {now: 110, expected: 110, minimum: null, ideal: 110,
            minimumState: 'none', idealState: 'met'});
        Object.assign(build.statRows[4], {now: null, expected: null, minimum: 80, ideal: 90,
            minimumState: 'unknown', idealState: 'unknown'});
        Object.assign(build.statRows[5], {ideal: null, idealState: 'unknown'});
        s.data.stars = {hp: 1, resolve: 0, fatigue: 2, initiative: 3, matk: null, ratk: 0, mdef: 2, rdef: 0};
        const before = structuredClone(s.data), start = s.nodes.length;
        s.owner.targets(s.node(), build, s.data.stars, compact);
        const fresh = s.nodes.slice(start);
        const expected = fresh.filter(n => n.tooltip?.elementId === 'expected').map(n => n.value);
        assert.ok(expected.includes(compact ? 'L11 80 !' : '80 !'), 'rounded display lost server shortfall');
        const goals = fresh.filter(n => n.tooltip?.elementId === 'targets');
        assert.ok(goals.some(n => renderedText(n) === (compact ? 'Min 80' : '80') && n.classes.has('bl-target-grow')));
        const met = goals.find(n => n.classes.has('bl-target-met'));
        assert.ok(met);
        assert.equal(renderedText(met), compact ? 'Ideal 110' : '110');
        assert.ok(goals.some(n => n.value === (compact ? 'Min —' : '—')));
        assert.ok(goals.some(n => n.value === (compact ? 'Min 80' : '80') && n.classes.has('bl-target-unknown')), 'unknown current value hid known target');
        assert.ok(goals.some(n => n.value === (compact ? 'Ideal 90' : '90') && n.classes.has('bl-target-unknown')), 'unknown current value hid known Ideal');
        assert.ok(goals.some(n => n.value === (compact ? 'Ideal ?' : '?') && n.classes.has('bl-target-unknown')));
        const attributes = fresh.filter(n => n.classes.has('bl-attribute'));
        attributes.forEach((n, i) => {
            const talent = n.children[0], count = Object.values(s.data.stars)[i];
            assert.equal(talent.tooltip.elementId, 'talents');
            assert.equal(talent.attributes.src, count == null ? undefined : 'coui://gfx/ui/icons/talent_' + count + '.png');
            if (count === null) assert.equal(talent.value, '?');
        });
        assert.deepEqual(s.data, before); assert.deepEqual(s.calls, []);
    }
});
test('native tooltip bindings are released on preview change and close', () => {
    const s = comparison();
    const first = s.nodes.filter(n => n.tooltip);
    assert.ok(first.length > 0);
    click(s.rows()[1]);
    assert.ok(first.some(n => n.tooltip === null), 'old detail bindings retained');
    s.owner.closeCompare();
    assert.ok(s.nodes.every(n => !n.tooltip && !n.tooltipTimer), 'closed popup retained tooltip bindings or a pending native show timer');
});

test('forecast allocation preserves supplied row types and distinguishes unknown from zero', () => {
    const s = comparison(), build = s.data.builds[0];
    build.projection.allocation.hp = [0, 2, 1];
    build.projection.allocation.matk = [1, 1, 0];
    const before = structuredClone(s.data), parent = s.node();
    s.owner.allocation(parent, build);
    const shown = renderedText(parent);
    for (const line of ['HP: 0 picks + 2 veteran + Gifted', 'Resolve: 0 picks',
        'Melee skill: 1 pick + 1 veteran', 'Melee defence: 10 picks + Gifted', 'Ranged defence: 0 picks + Gifted'])
        assert.ok(shown.includes(line), line);
    assert.deepEqual(s.data, before); assert.deepEqual(s.calls, []);
    build.projection.known = false;
    const unknown = s.node();
    s.owner.allocation(unknown, build);
    assert.ok(renderedText(unknown).includes('Unavailable'));
    assert.ok(!renderedText(unknown).includes('picks'), 'unknown growth presented initialized allocation counts');
});

test('allocation follows build previews and refreshed brother guidance without writes', () => {
    const s = comparison();
    function allocationShown() {
        const toggle = s.nodes.findLast(n => n.value === '+ Forecast allocation' && n.handlers.click);
        click(toggle);
        return renderedText(toggle.parent);
    }
    assert.ok(allocationShown().includes('HP: 4 picks'));
    s.data.builds[1].projection.allocation.hp = [7, 0, 1];
    click(s.rows()[1]);
    assert.ok(allocationShown().includes('HP: 7 picks + Gifted'));
    s.owner.closeCompare();
    s.owner.panel = s.node(); s.owner.entry = s.node(); s.owner.markPerks = () => {};
    const effects = Object.fromEntries(['dodge', 'nimble', 'battleForged'].map(id => [id, {owned: false, value: null}]));
    s.data.plan = {...s.data.builds[0], enabled: true, effects};
    s.owner.render();
    assert.ok(allocationShown().includes('HP: 4 picks'));
    s.owner.actor = s.data.actor = 8;
    s.data.plan = {...s.data.builds[1], enabled: true, effects};
    const before = structuredClone(s.data);
    s.owner.render();
    const current = allocationShown();
    assert.ok(current.includes('HP: 7 picks + Gifted'));
    assert.ok(!current.includes('HP: 4 picks'), 'previous brother allocation retained');
    assert.deepEqual(s.data, before); assert.deepEqual(s.calls, []);
});

test('tracked advice keeps material warnings visible without writing intent', () => {
    const s = comparison(); s.owner.closeCompare();
    s.owner.panel = s.node(); s.owner.entry = s.node(); s.owner.markPerks = () => {};
    s.data.plan = {...s.data.builds[0], enabled: true,
        effects: Object.fromEntries(['dodge', 'nimble', 'battleForged'].map(id => [id, {owned: false, value: null}])),
        armour: 'nimble', equipment: {capacity: 60, headroom: 50, recovery: 15, headArmour: 100,
            bodyArmour: 200, rawArmour: 15, effectiveArmour: 15, items: [],
            cycles: [{label: 'Two attacks', projectedLegal: false, currentFat: null}]}};
    const before = JSON.stringify(s.data), start = s.nodes.length;
    s.data.warnings = ['Missing hand: weapon choices restricted.'];
    s.owner.render();
    const fresh = s.nodes.slice(start), values = fresh.map(n => n.value);
    const warning = fresh.find(n => /AP requirement is not met/.test(n.value));
    assert.ok(warning && warning.classes.has('bl-warning'));
    for (let p = warning.parent; p; p = p.parent) assert.ok(!p.hidden);
    fresh.filter(n => n.classes.has('bl-disclosure-toggle')).forEach(click);
    assert.ok(values.includes('Missing hand: weapon choices restricted.'));
    s.data.warnings = [];
    assert.equal(JSON.stringify(s.data), before); assert.deepEqual(s.calls, []);
});

test('current effects show owned zero, not learned and unknown distinctly', () => {
    for (const state of ['owned', 'absent', 'unknown', 'zero']) {
        const s = comparison(); s.owner.closeCompare();
        s.owner.panel = s.node(); s.owner.entry = s.node(); s.owner.markPerks = () => {};
        s.data.settings.EquipmentAdvice = false;
        const effect = value => ({owned: state !== 'absent', value: state === 'zero' ? 0 : state === 'owned' ? value : null});
        s.data.plan = {...s.data.builds[0], enabled: true, equipment: null,
            effects: {dodge: effect(9), nimble: effect(52.79999923706055), battleForged: effect(5.099999904632568)}};
        const before = structuredClone(s.data), start = s.nodes.length;
        s.owner.render();
        const fresh = s.nodes.slice(start), values = fresh.filter(n => n.classes.has('bl-effect-value'));
        assert.deepEqual(values.map(n => n.value), state === 'owned' ? ['+9', '52.8%', '5.1%'] :
            state === 'zero' ? ['+0', '0%', '0%'] : Array(3).fill(state === 'absent' ? 'Not learned' : 'Unknown'));
        for (const n of values) for (let p = n; p; p = p.parent) {
            assert.ok(!p.hidden, 'effect hidden');
        }
        fresh.filter(n => n.classes.has('bl-disclosure-toggle')).forEach(click);
        assert.deepEqual(s.data, before); assert.deepEqual(s.calls, []);
    }
});

function chooseFilter(s, kind, value) {
    click(s.nodes.findLast(n => n.value.startsWith(kind + ': ') && n.handlers.click));
    const option = s.nodes.findLast(n => n.value === value && n.handlers.click);
    click(option); return option;
}
test('Role and Weapon filters intersect, include both hybrid weapons and never write intent', () => {
    const s = comparison(), before = structuredClone(s.data);
    const visible = () => s.rows().filter(r => !r.hidden).map(r => r.attributes['data-build']);
    chooseFilter(s, 'Weapon', 'Bow');
    assert.deepEqual(visible(), ['ranged', 'support']);
    assert.equal(s.button('l-ok-button').disabled, true, 'excluded preview still trackable');
    const staleRow = s.rows()[0]; click(staleRow); click(s.button('l-ok-button'));
    assert.deepEqual(s.calls, [], 'excluded stale row authorized tracking');
    click(s.rows()[1]); assert.equal(s.button('l-ok-button').disabled, false);
    chooseFilter(s, 'Role', 'Hybrid'); assert.deepEqual(visible(), ['support']);
    assert.equal(s.button('l-ok-button').disabled, true);
    chooseFilter(s, 'Weapon', 'Throwing'); assert.deepEqual(visible(), ['support']);
    click(s.rows()[2]); chooseFilter(s, 'Weapon', 'Axe'); assert.deepEqual(visible(), []);
    assert.equal(s.button('l-ok-button').disabled, true);
    chooseFilter(s, 'Role', 'All'); chooseFilter(s, 'Weapon', 'All');
    assert.deepEqual(visible(), ['frontline', 'ranged', 'support']);
    assert.equal(s.button('l-ok-button').disabled, true, 'reset implicitly picked a build');
    assert.deepEqual(s.data, before); assert.deepEqual(s.calls, []);
    click(s.rows()[0]); click(s.button('l-ok-button'));
    assert.deepEqual(s.calls.map(c => c.build), ['frontline']);
});
test('obsolete filter menu callbacks cannot alter the new preview', () => {
    const s = comparison();
    const old = chooseFilter(s, 'Weapon', 'Bow');
    chooseFilter(s, 'Weapon', 'All'); click(s.rows()[0]); click(old);
    assert.equal(s.rows()[0].hidden, false); assert.equal(s.button('l-ok-button').disabled, false);
    s.owner.compare(s.data); click(old); click(s.button('l-ok-button'));
    assert.deepEqual(s.calls.map(c => c.build), ['frontline']);
});
