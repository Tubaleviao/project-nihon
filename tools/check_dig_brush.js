#!/usr/bin/env node
// Phase 300 — proves the dig-brush validator rejects bad tables: a radius over the cap or not positive, an unknown
// shape, a cut material that does not exist, a digging tool with no brush, a brush for an unknown item, a bad unit
// volume; the shipped table passes.
//   node tools/check_dig_brush.js
'use strict';
const b = require('../fabric/gameplay/dig_brushes');
const refs = b.digBrushesRefs();
let failed = 0;
function expect(label, mutate, pattern) {
  const d = b.digBrushesData();
  const r = JSON.parse(JSON.stringify(refs));
  mutate(d, r);
  const problems = b.digBrushesProblems(d, r);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
expect('the shipped table is valid', () => {}, null);
expect('a radius over the cap fails', (d) => { d.brushes.StoneShovel.radius = d.radiusCap + 0.1; }, /StoneShovel\.radius .* over radiusCap/);
expect('a zero radius fails', (d) => { d.brushes.hands.radius = 0; }, /hands\.radius must be > 0/);
expect('an unknown shape fails', (d) => { d.brushes.StonePick.shape = 'cone'; }, /StonePick\.shape "cone"/);
expect('a cut material that does not exist fails', (d) => { d.brushes.StonePick.cuts.push('Unobtainium'); }, /cuts "Unobtainium" is not a natural terrain material/);
expect('an empty cuts list fails', (d) => { d.brushes.hands.cuts = []; }, /hands\.cuts must list/);
expect('a digging tool with no brush fails', (d) => { delete d.brushes.FerritePick; }, /FerritePick is a digging tool with no brush/);
expect('a brush for an unknown item fails', (d) => { d.brushes.Spoon = { shape: 'sphere', radius: 0.4, cuts: ['Soil'] }; }, /brushes\.Spoon is not a digging tool/);
expect('no hands brush fails', (d) => { delete d.brushes.hands; }, /brushes\.hands is missing/);
expect('a zero unit volume fails', (d) => { d.unitVolume.default = 0; }, /unitVolume\.default must be > 0/);
expect('an override for an unknown material fails', (d) => { d.unitVolume.overrides.Mud = 0.1; }, /overrides\.Mud is not a natural terrain material/);
expect('a zero cap fails', (d) => { d.radiusCap = 0; }, /radiusCap must be/);
expect('a pick cutting Concrete fails', (d) => { d.brushes.StonePick.cuts.push('Concrete'); }, /cuts "Concrete" is not a natural/);
expect('a pick cutting wood fails', (d) => { d.brushes.StonePick.cuts.push('Thornwood'); }, /cuts "Thornwood" is not a natural/);
expect('a shovel cutting stone fails', (d) => { d.brushes.StoneShovel.cuts.push('Ashite'); }, /StoneShovel\.cuts "Ashite" is beyond a shovel/);
expect('hands cutting an ore metal fails', (d) => { d.brushes.hands.cuts.push('Ferrite'); }, /hands\.cuts "Ferrite" is beyond a hands/);
expect('hands missing a biome soil fails', (d) => { d.brushes.hands.cuts = d.brushes.hands.cuts.filter((m) => m !== 'Soil'); }, /hands\.cuts misses "Soil"/);
expect('a pick missing a rock fails', (d) => { d.brushes.StonePick.cuts = d.brushes.StonePick.cuts.filter((m) => m !== 'Voidite'); }, /StonePick\.cuts misses "Voidite"/);
expect('a duplicate cut fails', (d) => { d.brushes.hands.cuts.push('Soil'); }, /lists "Soil" twice/);
expect('a null brush fails without throwing', (d) => { d.brushes.hands = null; }, /hands must be an object/);
expect('an unknown brush key fails', (d) => { d.brushes.hands.speed = 2; }, /hands\.speed is not a brush key/);
expect('a negative blend fails', (d) => { d.blend = -1; }, /blend must be/);
expect('a NaN blend fails', (d) => { d.blend = NaN; }, /blend must be/);
expect('a negative override fails', (d) => { d.unitVolume.overrides.Soil = -1; }, /overrides\.Soil must be > 0/);
expect('minRadius at the cap fails', (d) => { d.minRadius = d.radiusCap; }, /minRadius must be under radiusCap/);
expect('a radius under minRadius fails', (d) => { d.brushes.hands.radius = d.minRadius / 2; }, /hands\.radius .* under minRadius/);
expect('a zero skill step fails', (d) => { d.skillRadiusPerTier = 0; }, /skillRadiusPerTier must be/);
if (failed) { console.error(`${failed} check(s) failed`); process.exit(1); }
console.log('all dig-brush checks passed');
