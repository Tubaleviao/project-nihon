#!/usr/bin/env node
// Phase 281 — proves the work-clip validator rejects a clip name not on the rig contract and a work kind with no
// clip; the shipped table passes.   node tools/check_work_clips.js
'use strict';
const w = require('../fabric/gameplay/work_clips');
let failed = 0;
function expect(label, mutate, pattern) {
  const d = w.workClipsData();
  mutate(d);
  const problems = w.workClipsProblems(d);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
expect('the shipped table is valid', () => {}, null);
expect('a clip not on the rig contract fails', (d) => { d.clips.chop.clip = 'swing_axe'; }, /clips\.chop: clip "swing_axe" is not on the rig contract/);
expect('a work kind with no clip fails', (d) => { delete d.clips.dig; }, /work kind "dig" has no clip/);
expect('an unknown mode fails', (d) => { d.clips.mine.mode = 'forever'; }, /mode "forever"/);
expect('an impact outside (0,1) fails', (d) => { d.clips.build.impact = 1.5; }, /impact must be a fraction/);
expect('a fallback off the rig contract fails', (d) => { d.fallbackClip = 'nope'; }, /fallbackClip/);
if (failed) { console.error(`${failed} check(s) failed`); process.exit(1); }
console.log('all work-clip checks passed');
