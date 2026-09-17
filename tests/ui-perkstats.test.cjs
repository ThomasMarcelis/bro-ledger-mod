// Perk-adjusted presentation.
//
// Evaluation board: the Potential column carries the icon of every stat perk the BUILD plans,
// so a player reading a 102 knows Colossus produced it.
// Lateral side panel: Current shows what the brother has NOW; its Ideal colour follows that
// reality, flipping to met only once the perk is actually picked.
const {test, afterEach} = require('node:test');
const assert = require('node:assert/strict');
const {Controller} = require('../ui/mods/bro_ledger/ledger.js');
const {fixture, click, dom} = require('./ui-fixture.cjs');

const original = {SQ: global.SQ, $: global.$, Path: global.Path, window: global.window};
afterEach(() => { for (const [k, v] of Object.entries(original)) { if (v === undefined) delete global[k]; else global[k] = v; } });

// Asgeir's real numbers: natural 66 HP, Colossus acquired -> sheet 82, reachable 102, ideal 100.
function hpRow(extra = {}) {
    return {key: 'hp', now: 82, minimum: 70, ideal: 100, weight: 10, expected: 97, maximum: 102,
        idealState: 'grow', statPerks: [{id: 'perk.colossus', acquired: true}], ...extra};
}
function plainRow(extra = {}) {
    return {key: 'fatigue', now: 108, minimum: 100, ideal: 110, weight: 2, expected: 110, maximum: 120,
        idealState: 'grow', statPerks: [], ...extra};
}
// Render one build through the production evaluation board and return its Potential cells.
function board(rows, defs) {
    const s = fixture(1);
    if (defs) Object.assign(s.data.defs, defs);
    s.data.builds[0].statRows = rows;
    s.owner.compare(s.data);
    click(s.byClass('bl-build-row')[0]);
    const table = s.byClass('bl-targets')[0];
    assert.ok(table, 'evaluation board drew no target table');
    return {session: s, table, cells: s.byClass('bl-potential')};
}

test('the evaluation board marks perk-driven potential with that perk icon', () => {
    const defs = {'perk.colossus': {name: 'Colossus', unlock: 0, row: 0, column: 0, icon: 'perks/colossus.png'}};
    const {cells} = board([hpRow(), plainRow()], defs);
    assert.equal(cells.length, 2, 'every stat row needs a potential cell');
    // The perk-driven row carries an icon; the ordinary row stays clean.
    const marks = cells[0].children.filter(n => n.classes.has('bl-perk-mark'));
    assert.equal(marks.length, 1, 'perk-driven potential has no perk mark');
    const img = marks[0].children.filter(n => n.attributes.src)[0];
    assert.ok(img, 'perk mark drew no image');
    assert.equal(img.attributes.src, 'coui://gfx/perks/colossus.png', 'perk mark does not use the real perk icon');
    assert.equal(cells[1].children.filter(n => n.classes.has('bl-perk-mark')).length, 0,
        'a stat with no perk was marked');
    // The value itself must still be readable next to the icon.
    assert.ok(cells[0].value.indexOf('97') !== -1, 'potential value lost from the marked cell');
    assert.equal(cells[1].value, '110');
});

test('the potential mark names its perk and survives a perk with no icon art', () => {
    const defs = {'perk.fortified_mind': {name: 'Fortified Mind', unlock: 1, row: 1, column: 0}};
    const row = hpRow({key: 'resolve', now: 51, ideal: 60, expected: 63,
        statPerks: [{id: 'perk.fortified_mind', acquired: false}]});
    const {cells} = board([row], defs);
    const mark = cells[0].children.filter(n => n.classes.has('bl-perk-mark'))[0];
    assert.ok(mark, 'planned perk produced no mark');
    // No art: keep a readable name rather than a broken image.
    assert.ok(!mark.attributes.src, 'a perk without art still requested an image');
    assert.ok((mark.value || '').indexOf('Fortified Mind') !== -1, 'iconless mark does not name its perk');
    assert.ok((mark.tooltip || mark.attributes.title || '').toString().indexOf('Fortified Mind') !== -1,
        'perk mark does not identify its perk on hover');
});

test('several perks and unknown ids stay safe on the board', () => {
    const defs = {
        'perk.colossus': {name: 'Colossus', unlock: 0, row: 0, column: 0, icon: 'perks/colossus.png'},
        'perk.fortified_mind': {name: 'Fortified Mind', unlock: 1, row: 1, column: 0, icon: 'perks/fm.png'}};
    const two = hpRow({statPerks: [{id: 'perk.colossus', acquired: true}, {id: 'perk.fortified_mind', acquired: false}]});
    const {cells} = board([two], defs);
    assert.equal(cells[0].children.filter(n => n.classes.has('bl-perk-mark')).length, 2, 'second perk mark missing');
    // An id the definitions do not know must not break the row or invent art.
    const {cells: unknown} = board([hpRow({statPerks: [{id: 'perk.not_real', acquired: true}]})], defs);
    const mark = unknown[0].children.filter(n => n.classes.has('bl-perk-mark'))[0];
    if (mark) assert.ok(!mark.attributes.src, 'unknown perk requested an image');
    assert.ok(unknown[0].value.indexOf('97') !== -1, 'unknown perk destroyed the potential value');
});

test('the side panel shows the brother reality and recolours when the perk is picked', () => {
    // Compact panel: no Potential column at all, so no perk marks belong there.
    const d = dom();
    const before = new Controller({mSQHandle: 'x'});
    const parent = d.root();
    // Ideal 80, brother currently 66 without Colossus -> still growing.
    before.targets(parent, {statRows: [hpRow({now: 66, ideal: 80, maximum: 82, idealState: 'grow',
        statPerks: [{id: 'perk.colossus', acquired: false}]})],
        projection: {horizon: 11}, jointState: 'possible'}, {}, true);
    const growCell = parent.find('.bl-target-grow');
    assert.equal(growCell.length, 1, 'unmet goal is not painted as growing');
    assert.equal(parent.find('.bl-potential').length, 0, 'compact panel drew a potential column');
    assert.equal(parent.find('.bl-perk-mark').length, 0, 'compact panel drew perk marks');

    // Same brother after picking Colossus: current becomes 82, so the goal is met and green.
    const after = new Controller({mSQHandle: 'x'});
    const parent2 = d.root();
    after.targets(parent2, {statRows: [hpRow({now: 82, ideal: 80, maximum: 102, idealState: 'met',
        statPerks: [{id: 'perk.colossus', acquired: true}]})],
        projection: {horizon: 11}, jointState: 'possible'}, {}, true);
    assert.equal(parent2.find('.bl-target-met').length, 1, 'picking the perk did not recolour the goal to met');
    assert.equal(parent2.find('.bl-target-grow').length, 0, 'met goal still painted as growing');
    // The current value the player reads must be the perk-adjusted sheet number.
    const cells = parent2.find('.bl-current');
    assert.ok(cells.length === 1 && cells.items[0].value === '82', 'side panel does not show the perk-adjusted current value');
});

test('an impossible goal stays red in the side panel even with the perk', () => {
    const d = dom();
    const c = new Controller({mSQHandle: 'x'});
    const parent = d.root();
    c.targets(parent, {statRows: [hpRow({now: 82, ideal: 110, maximum: 102, idealState: 'impossible'})],
        projection: {horizon: 11}, jointState: 'individual'}, {}, true);
    assert.equal(parent.find('.bl-target-impossible').length, 1, 'a goal beyond the perk-adjusted maximum lost its red state');
});
