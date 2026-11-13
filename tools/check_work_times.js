#!/usr/bin/env node
// Phase 259 — proves the work-time validator rejects bad tables: a material with no time, a tool with no speed
// for its own class, a tool no faster than bare hands, an unknown tool class; the shipped tables pass.
//   node tools/check_work_times.js
'use strict';
const w = require('../fabric/gameplay/work_times');
const refs = w.workTimesRefs();
let failed = 0;
function expect(label, mutate, pattern) {
  const d = w.workTimesData();
  mutate(d);
  const problems = w.workTimesProblems(d, refs);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
expect('the shipped tables are valid', () => {}, null);
expect('a material with no time fails', (d) => { delete d.workSeconds.Soil; }, /workSeconds\.Soil is missing/);
expect('a zero time fails', (d) => { d.workSeconds.Ashite = 0; }, /workSeconds\.Ashite is missing/);
expect('a tool with no speed for its class fails', (d) => { d.toolSpeeds.CarpenterAxe = {}; }, /CarpenterAxe: tool of class axe has no workSpeed/);
expect('a tool missing entirely fails', (d) => { delete d.toolSpeeds.FerritePick; }, /FerritePick: tool of class pick/);
expect('bare hands faster than a tool fails', (d) => { d.bareHandsSpeed = 0.99; d.toolSpeeds.FerritePick.pick = 0.5; }, /must beat bare hands/);
expect('an unknown tool class fails', (d) => { d.actions.mine.toolClass = 'spoon'; }, /not a tool class/);
expect('a family no action works fails', (d) => { delete d.actions.chop; }, /no action works the wood family/);
if (failed) { console.error(`${failed} check(s) failed`); process.exit(1); }
console.log('all work-time checks passed');
