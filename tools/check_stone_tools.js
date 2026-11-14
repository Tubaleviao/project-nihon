#!/usr/bin/env node
// Phase 260 — proves the stone-tool validator rejects bad tables: a stone tool behind a station, a technology
// that costs research points, has a prerequisite or materials or is not innate, an input that is not a branch
// or a stone, a non-novice guard, and bad yields; the shipped fabric passes.
//   node tools/check_stone_tools.js
'use strict';
const s = require('../fabric/gameplay/stone_tools');
let failed = 0;
function expect(label, mutate, pattern) {
  const d = s.stoneToolsData();
  const refs = JSON.parse(JSON.stringify(s.stoneToolsRefs()));
  mutate(d, refs);
  const problems = s.stoneToolsProblems(d, refs);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
expect('the shipped fabric is valid', () => {}, null);
expect('a stone tool behind a station fails', (d, r) => { r.recipes.RecipeStonePick.station = 'forge'; }, /RecipeStonePick: a stone tool needs no station/);
expect('a technology that costs research points fails', (d, r) => { r.technologies.TechStoneTools.researchCost = 2; }, /costs no research points/);
expect('a technology with a prerequisite fails', (d, r) => { r.technologies.TechStoneTools.requires = ['TechBasicCarpentry']; }, /has no prerequisite/);
expect('a technology with research materials fails', (d, r) => { r.technologies.TechStoneTools.researchMaterials = [{ item: 'Thornwood', quantity: 1 }]; }, /takes no materials/);
expect('a technology that is not innate fails', (d, r) => { delete r.technologies.TechStoneTools.innate; }, /is innate/);
expect('a recipe no technology unlocks fails', (d, r) => { r.technologies.TechStoneTools.unlocks = []; }, /no technology unlocks it/);
expect('an input other than branch or stone fails', (d, r) => { r.recipes.RecipeStoneAxe.inputs.push({ item: 'FerriteIngot', quantity: 1 }); }, /input FerriteIngot is not a branch/);
expect('a journeyman guard fails', (d, r) => { r.recipes.RecipeStoneKnife.skillGuards = [{ skill: 'Carpentry', tier: 'journeyman' }]; }, /must be novice/);
expect('a tool no recipe makes fails', (d) => { d.tools.push('VeilsteelPick'); }, /VeilsteelPick: no recipe makes it/);
expect('zero branches per felled tree fails', (d) => { d.yields.fellBranches = 0; }, /fellBranches/);
expect('a loose-stone chance above 1 fails', (d) => { d.yields.looseStoneChance = 1.5; }, /looseStoneChance/);
if (failed) { console.error(`${failed} check(s) failed`); process.exit(1); }
console.log('all stone-tool checks passed');
