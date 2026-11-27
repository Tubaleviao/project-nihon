#!/usr/bin/env node
// Phase 300 — proves the dig-brush validator rejects bad tables: a brush over the radius cap, one that names
// a material that is not a terrain material, an unknown shape, a tool that is not an item, a missing bare-hands
// brush and a non-positive unit volume; the shipped fabric passes.
//   node tools/check_dig_brush.js
'use strict';
const b = require('../fabric/gameplay/dig_brush');
let failed = 0;
function expect(label, mutate, pattern) {
  const d = b.digBrushData();
  const refs = JSON.parse(JSON.stringify(b.digBrushRefs()));
  mutate(d, refs);
  const problems = b.digBrushProblems(d, refs);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
expect('the shipped fabric is valid', () => {}, null);
expect('a radius over the cap fails', (d) => { d.brushes.StoneShovel.radius = 2; d.brushes.StoneShovel.radiusMax = 2; }, /over the cap/);
expect('a skill-grown radius over the cap fails', (d) => { d.brushes.StoneShovel.radiusMax = 1.6; }, /over the cap/);
expect('radiusMax below radius fails', (d) => { d.brushes.StoneShovel.radiusMax = 0.1; }, /below radius/);
expect('a material that is not a terrain material fails', (d) => { d.brushes.StoneShovel.materials.push('Unobtainium'); }, /Unobtainium is not a terrain material/);
expect('an unknown shape fails', (d) => { d.brushes.StoneShovel.shape = 'torus'; }, /shape torus/);
expect('a tool that is not an item fails', (d) => { d.brushes.Spoon = { ...d.brushes.StoneShovel }; }, /Spoon: not an item/);
expect('no bare-hands brush fails', (d) => { delete d.brushes['']; }, /bare hands/);
expect('a work share over 1 fails', (d) => { d.workSlabShare = 2; }, /workSlabShare/);
expect('an empty material list fails', (d) => { d.brushes.StonePick.materials = []; }, /at least one material/);
expect('a non-positive unit volume fails', (d) => { d.unitVolume.Soil = 0; }, /unitVolume.Soil must be positive/);
expect('a unit volume for a non-material fails', (d) => { d.unitVolume.Mud = 0.1; }, /unitVolume.Mud: not a terrain material/);
if (failed) { console.error(`${failed} check(s) failed`); process.exit(1); }
console.log('all dig-brush checks passed');
