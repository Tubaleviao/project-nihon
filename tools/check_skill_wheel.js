#!/usr/bin/env node
// Phase 271 — proves the skill-wheel validator rejects bad tables: affinities that sum to neither 0 nor 1, an
// unknown profession, a depth that does not grow along a skill; the shipped table passes.
//   node tools/check_skill_wheel.js
'use strict';
const w = require('../fabric/gameplay/skill_wheel');
const refs = w.skillWheelRefs();
let failed = 0;
function expect(label, mutate, pattern) {
  const d = w.skillWheelData();
  mutate(d);
  const problems = w.skillWheelProblems(d, refs);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
expect('the shipped table is valid', () => {}, null);
expect('affinities summing to 0.5 fail', (d) => { d.nodes['Smithing:novice'].affinity = { Blacksmith: 0.5 }; }, /sum to 0.5, not 0 or 1/);
expect('affinities summing to 1.4 fail', (d) => { d.nodes['Smithing:novice'].affinity = { Blacksmith: 0.7, Warrior: 0.7 }; }, /not 0 or 1/);
expect('an unknown profession fails', (d) => { d.nodes['Smithing:novice'].affinity = { Wizard: 1 }; }, /unknown profession Wizard/);
expect('a depth that decreases along a skill fails', (d) => { d.nodes['Smithing:expert'].depth = 0.1; }, /Smithing: depth does not grow at tier expert/);
expect('a flat depth fails', (d) => { d.nodes['Smithing:master'].depth = d.nodes['Smithing:expert'].depth; }, /depth does not grow at tier master/);
expect('a tier with nothing unlocked fails', (d) => { d.nodes['Smithing:novice'].unlock = null; }, /unlocks nothing/);
expect('a skill with no affinity is valid', (d) => { d.nodes['Smithing:novice'].affinity = {}; }, null);
if (failed) { console.error(`${failed} check(s) failed`); process.exit(1); }
console.log('all skill-wheel checks passed');
