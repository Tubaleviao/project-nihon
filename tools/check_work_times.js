#!/usr/bin/env node
// Phase 259 — proves the work-time validator rejects bad tables: a material with no time, a tool with no speed
// for its own class, a tool no faster than bare hands, an unknown tool class,
// a shovel slower than the stone one (Phase 290); the shipped tables pass.
//   node tools/check_work_times.js
'use strict';
const w = require('../fabric/gameplay/work_times');
const refs = w.workTimesRefs();
let failed = 0;
function expect(label, mutate, pattern) {
  const d = w.workTimesData();
  const r = JSON.parse(JSON.stringify(refs));
  mutate(d, r);
  const problems = w.workTimesProblems(d, r);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
expect('the shipped tables are valid', () => {}, null);
expect('a material with no time fails', (d) => { delete d.workSeconds.Soil; }, /workSeconds\.Soil is missing/);
expect('a zero time fails', (d) => { d.workSeconds.Ashite = 0; }, /workSeconds\.Ashite is missing/);
expect('an item no faster than bare hands fails', (d, r) => { d.bareHandsSpeed = 0.99; r.itemWorks.FerritePick = { mine: 0.5 }; }, /FerritePick does mine at 0\.5: it must beat bare hands/);
expect('an action naming no work fails', (d) => { d.actions.mine.work = 'spoon'; }, /actions\.mine\.work "spoon" is not a work/);
expect('an action whose work bare hands cannot do fails', (d) => { d.actions.mine.work = 'dissect'; }, /cannot be done by bare hands/);
expect('a family no action works fails', (d) => { delete d.actions.chop; }, /no action works the wood family/);
expect('the stone shovel unable to dig fails', (d, r) => { delete r.itemWorks.StoneShovel; }, /StoneShovel cannot dig/);
// Phase 290 — a digger slower than the stone shovel is rejected (a made-up forged shovel stands in for the next one).
{
  const d = w.workTimesData();
  const floor = refs.itemWorks.StoneShovel.dig;
  const slow = w.workTimesProblems(d, { ...refs, itemWorks: { ...refs.itemWorks, ForgedShovel: { dig: floor - 0.1 } } });
  const even = w.workTimesProblems(d, { ...refs, itemWorks: { ...refs.itemWorks, ForgedShovel: { dig: floor } } });
  const ok = slow.some((p) => /ForgedShovel digs at .* slower than StoneShovel/.test(p)) && even.length === 0;
  console.log(`${ok ? 'ok  ' : 'FAIL'} a shovel slower than StoneShovel fails, one as fast passes${ok ? '' : ' — ' + JSON.stringify({ slow, even })}`);
  if (!ok) failed++;
}
if (failed) { console.error(`${failed} check(s) failed`); process.exit(1); }
console.log('all work-time checks passed');
