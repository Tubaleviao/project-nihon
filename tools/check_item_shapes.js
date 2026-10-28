#!/usr/bin/env node
// Phase 151 — proves the item-shape validator catches bad shapes, and that every entity tagged
// `item` in the shipped fabric has a valid one.
//   node tools/check_item_shapes.js
'use strict';
const s = require('../fabric/gameplay/items/shape');
const fabric = require('../fabric/index');
const materials = Object.keys(require('../fabric/world/materials'));

let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
const item = (shape, relations) => ({ Fixture: { tags: ['item'], relations, fields: shape ? { shape: s.itemShape(shape) } : {} } });
const madeOf = (target) => ({ [target.toLowerCase()]: { name: target.toLowerCase(), kind: 'hasOne', target } });

const items = Object.fromEntries(Object.entries(fabric.entities).filter(([, e]) => (e.tags || []).includes('item')));
expect('the shipped fabric has 28 items', Object.keys(items).length === 28 ? [] : ['count ' + Object.keys(items).length], null);
expect('every shipped item has a valid shape', s.shapeProblems(items, materials), null);

expect('a valid fixture passes', s.shapeProblems(item({ archetype: 'sword', parts: { blade: 'Ferrite', grip: 'Thornwood' } }), materials), null);
expect('an item with no shape fails', s.shapeProblems(item(null), materials), /has no shape/);
expect('archetype spaceship fails', s.shapeProblems(item({ archetype: 'spaceship', parts: { hull: 'Ferrite' } }), materials), /unknown archetype "spaceship"/);
expect('parts.blade naming a missing material fails', s.shapeProblems(item({ archetype: 'sword', parts: { blade: 'Unobtainium', grip: 'Thornwood' } }), materials), /missing material "Unobtainium"/);
expect('a part outside the archetype fails', s.shapeProblems(item({ archetype: 'ingot', parts: { body: 'Ferrite', blade: 'Ferrite' } }), materials), /part "blade" is not in archetype/);
expect('a missing part fails', s.shapeProblems(item({ archetype: 'sword', parts: { blade: 'Ferrite' } }), materials), /part "grip" has no material/);
expect('a non-positive scale fails', s.shapeProblems(item({ archetype: 'ingot', parts: { body: 'Ferrite' }, scale: 0 }), materials), /scale/);
expect('a hasOne material no part draws fails', s.shapeProblems(item({ archetype: 'ingot', parts: { body: 'Ferrite' } }, madeOf('Veilsteel')), materials), /made of "Veilsteel"/);
expect('a hasOne material listed in unshown passes', s.shapeProblems(item({ archetype: 'ingot', parts: { body: 'Ferrite' }, unshown: ['Veilsteel'] }, madeOf('Veilsteel')), materials), null);
expect('an unshown material that a part draws fails', s.shapeProblems(item({ archetype: 'ingot', parts: { body: 'Ferrite' }, unshown: ['Ferrite'] }), materials), /unshown "Ferrite" is drawn/);
expect('validateShapes throws on a bad item', (() => { try { s.validateShapes(item(null), materials); return []; } catch (e) { return [e.message]; } })(), /no shape/);

process.exit(failed ? 1 : 0);
