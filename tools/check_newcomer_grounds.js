#!/usr/bin/env node
// Phase 261 — proves the newcomer-grounds validator rejects bad tables: an aggressive creature in the allowed
// list, a creature above the tier cap, a radius below the tutorial's needs, and more; the shipped fabric passes.
//   node tools/check_newcomer_grounds.js
'use strict';
const g = require('../fabric/gameplay/newcomer_grounds');
let failed = 0;
function expect(label, mutate, pattern) {
  const d = g.newcomerGroundsData();
  const refs = JSON.parse(JSON.stringify(g.newcomerGroundsRefs()));
  mutate(d, refs);
  const problems = g.newcomerGroundsProblems(d, refs);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
expect('the shipped fabric is valid', () => {}, null);
expect('an aggressive creature in the list fails', (d) => { d.allowedCreatures.push('VeilStalker'); }, /VeilStalker: aggressive creature is not allowed/);
expect('a territorial creature in the list fails', (d) => { d.allowedCreatures.push('GraywolfPack'); }, /GraywolfPack: territorial creature is not allowed/);
expect('a creature above the tier cap fails', (d) => { d.allowedCreatures.push('SteppeBison'); }, /SteppeBison: tier 2 is above the cap/);
expect('an unknown creature fails', (d) => { d.allowedCreatures.push('Nope'); }, /Nope is not a creature/);
expect('an empty creature list fails', (d) => { d.allowedCreatures = []; }, /allowedCreatures is empty/);
expect('aggressive in allowedAggression fails', (d) => { d.allowedAggression.push('aggressive'); }, /must not include aggressive/);
expect('a radius below the tutorial needs fails', (d) => { d.radiusMetres = 300; d.spawnRadiusMetres = 200; d.resourceRadiusMetres = 100; }, /radiusMetres 300 is below/);
expect('a resource radius outside the ground fails', (d) => { d.resourceRadiusMetres = 2000; }, /resourceRadiusMetres must fit/);
expect('a resource radius too small fails', (d) => { d.resourceRadiusMetres = 10; }, /resourceRadiusMetres must be at least/);
expect('no grounds fails', (d) => { d.count = 0; }, /count must be/);
expect('an unknown biome fails', (d) => { d.biomes.push('Nowhere'); }, /Nowhere is not a biome/);
expect('outside density above inside fails', (d) => { d.looseDensityOutside = 0.9; }, /looseDensityOutside/);
expect('a claim radius beyond the spawn radius fails', (d) => { d.claimRadiusMetres = 400; }, /claimRadiusMetres/);
if (failed) { console.error(`${failed} check(s) failed`); process.exit(1); }
console.log('all newcomer-grounds checks passed');
