#!/usr/bin/env node
// Phase 203 — proves the work-skill validator catches bad tables: a crafting domain, a material family or a kind
// of work (building, dismantling, repairing, lockpicking) that grows no skill, an unknown skill, a row that credits
// a clan, an XP of zero and a new skill's XP curve that falls all fail; the shipped tables pass.
//   node tools/check_work.js
'use strict';
const w = require('../fabric/gameplay/work');
const refs = w.workRefs();
let failed = 0;
function expect(label, mutate, pattern) {
  const d = w.workData();
  mutate(d);
  const problems = w.workProblems(d, refs);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

expect('the shipped tables are valid', () => {}, null);
expect('a crafting domain with no skill fails', (d) => { delete d.work.craft.smithing; }, /craft\.smithing is missing/);
expect('sewing with no skill fails', (d) => { delete d.work.craft.tailoring; }, /craft\.tailoring is missing/);
expect('a material family with no skill fails', (d) => { delete d.work.gather.stone; }, /gather\.stone is missing: gathering Ashite, Lumenfite/);
expect('skinning with no skill fails', (d) => { delete d.work.gather.carcass; }, /gather\.carcass is missing/);
for (const k of ['build', 'dismantle', 'repair', 'lockpick']) {
  expect(`${k} with no skill fails`, (d) => { delete d.work[k]; }, new RegExp(`WorkSkills\\.${k} is missing`));
}
expect('an unknown skill fails', (d) => { d.work.craft.alchemy.skill = 'Cooking'; }, /"Cooking" is not a skill/);
expect('a row that credits a clan fails', (d) => { d.work.build.clan = 5; }, /build\.clan: work grows only the worker's own skill/);
expect('a zero XP row fails', (d) => { d.work.repair.xp = 0; }, /repair\.xp must be an integer >= 1/);
expect('an unknown kind of work fails', (d) => { d.work.praying = { skill: 'Building', xp: 1 }; }, /unknown kind of work "praying"/);
expect('a new skill curve that falls fails', (d) => { d.curves.Tailoring.xpToLevel[5] = 1; }, /Tailoring\.xpToLevel does not rise at level 5/);
expect('a missing new skill curve fails', (d) => { delete d.curves.Lockpicking; }, /curves\.Lockpicking is missing/);

let threw = false;
try { const d = w.workData(); delete d.work.build; w.validateWork(d, refs); } catch (e) { threw = true; }
console.log(`${threw ? 'ok  ' : 'FAIL'} validateWork throws on bad data`);
if (!threw) failed++;
process.exit(failed ? 1 : 0);
