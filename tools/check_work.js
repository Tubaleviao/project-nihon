#!/usr/bin/env node
// Phase 203 — proves the work-skill validator catches bad tables: a crafting domain, a material family or a kind
// of work (building, dismantling, repairing, lockpicking) that grows no skill, an unknown skill, a row that credits
// a clan, an XP of zero, a new skill's XP curve that falls and a tier table that does not rise all fail; the
// shipped tables pass. Phase 274: a gather row naming a skill outside the gathering category, a skill whose
// category is not in SKILL_CATEGORIES, a gathering skill with no tier bonus and a tier bonus that does not rise
// or names unknown work all fail.
//   node tools/check_work.js
'use strict';
const w = require('../fabric/gameplay/work');
const refs = w.workRefs();
let failed = 0;
function expect(label, mutate, pattern, mutateRefs = () => {}) {
  const d = w.workData();
  mutate(d);
  const r = JSON.parse(JSON.stringify(refs));
  mutateRefs(r);
  const problems = w.workProblems(d, r);
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
expect('a tier table that falls fails', (d) => { d.tiers.expert = 10; }, /tiers\.expert does not rise above journeyman/);
expect('a tier table missing a tier fails', (d) => { delete d.tiers.master; }, /tiers\.master must be an integer >= 0/);
expect('a novice threshold above 0 fails', (d) => { d.tiers.novice = 5; }, /tiers\.novice must be 0/);
expect('an unknown tier fails', (d) => { d.tiers.legend = 9000; }, /tiers\.legend is not a tier/);
expect('a missing new skill curve fails', (d) => { delete d.curves.Lockpicking; }, /curves\.Lockpicking is missing/);

// Phase 274 — gathering skills.
expect('mining stone for Building fails', (d) => { d.work.gather.stone.skill = 'Building'; }, /gather\.stone\.skill "Building" is a crafting skill: gathering grows only gathering skills/);
expect('mining ore for Smithing fails', (d) => { d.work.gather.metal.skill = 'Smithing'; }, /gather\.metal\.skill "Smithing" is a crafting skill/);
expect('a skill whose category is not in SKILL_CATEGORIES fails', () => {}, /skill Mining: category "survival" is not in SKILL_CATEGORIES/, (r) => { r.categories.Mining = 'survival'; });
expect('a gathering skill with no tier bonus fails', (d) => { delete d.bonuses.Woodcutting; }, /bonuses\.Woodcutting is missing/);
expect('a tier that gives nothing fails', (d) => { d.bonuses.Mining.byTier.expert = d.bonuses.Mining.byTier.journeyman; }, /bonuses\.Mining\.byTier\.expert does not rise above journeyman/);
expect('a novice bonus fails', (d) => { d.bonuses.Mining.byTier.novice = 1.2; }, /bonuses\.Mining\.byTier\.novice must be 1/);
expect('an unknown bonus effect fails', (d) => { d.bonuses.Foraging.effect = 'luck'; }, /bonuses\.Foraging\.effect "luck"/);
expect('a bonus on unknown work fails', (d) => { d.bonuses.Mining.work.push('fish'); }, /bonuses\.Mining\.work "fish"/);
expect('two speed bonuses on one action fail', (d) => { d.bonuses.Woodcutting.work.push('mine'); }, /work "mine" already has a speed bonus from Mining/);
expect('a tier bonus on a crafting skill fails', (d) => { d.bonuses.Smithing = JSON.parse(JSON.stringify(d.bonuses.Foraging)); }, /bonuses\.Smithing: Smithing is not a gathering skill/);
expect('a gathering skill with no curve fails', (d) => { delete d.curves.Mining; }, /curves\.Mining is missing/);

let threw = false;
try { const d = w.workData(); delete d.work.build; w.validateWork(d, refs); } catch (e) { threw = true; }
console.log(`${threw ? 'ok  ' : 'FAIL'} validateWork throws on bad data`);
if (!threw) failed++;
process.exit(failed ? 1 : 0);
