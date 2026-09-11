// CSS contract tests. These two rules were found by measuring the rendered editor in a browser,
// not by reading the stylesheet, so they get explicit guards against silent regression.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const css = fs.readFileSync(path.join(__dirname, '..', 'ui', 'mods', 'bro_ledger', 'ledger.css'), 'utf8');

// Every declaration block whose selector list contains this exact selector, concatenated.
function declarationsFor(selector) {
    let out = '';
    for (const rule of css.split('}')) {
        const at = rule.indexOf('{');
        if (at === -1) continue;
        // Selector lists may span lines and carry comments; normalise before comparing.
        const head = rule.slice(0, at).replace(/\/\*[\s\S]*?\*\//g, '');
        const selectors = head.split(',').map(s => s.trim().replace(/\s+/g, ' ')).filter(Boolean);
        if (selectors.includes(selector)) out += rule.slice(at + 1) + ';';
    }
    return out;
}

test('the error panel outranks the native scroll control', () => {
    // The native list sets z-index 10001; a lower value let perk rows paint over the message.
    const block = declarationsFor('.bl-error');
    assert.ok(block, '.bl-error rule is missing');
    const z = /z-index\s*:\s*(\d+)/.exec(block);
    assert.ok(z, '.bl-error must declare a z-index');
    assert.ok(Number(z[1]) > 10001, `.bl-error z-index ${z[1]} must exceed the native 10001`);
});

test('the perk order list can scroll instead of overflowing', () => {
    // Without min-height:0 the absolutely positioned host adopted the content height, the
    // viewport measured 0px, no scrollbar appeared and the last perk was unreachable.
    assert.match(declarationsFor('.bl-order-list-host'), /min-height\s*:\s*0/,
        'the order list host must keep min-height:0 so it can scroll');
    const scroll = declarationsFor('.bl-order-scroll');
    assert.match(scroll, /min-height\s*:\s*0/, 'the scroll control must keep min-height:0');
    assert.match(scroll, /height\s*:\s*100%/, 'the scroll control needs a definite height');
});
