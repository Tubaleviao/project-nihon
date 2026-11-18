#!/usr/bin/env node
// Phase 272 — proves the focus validator rejects a negative bonus and a window of zero; the shipped table passes.
//   node tools/check_skill_focus.js
'use strict';
const f = require('../fabric/gameplay/skill_focus');
let failed = 0;
function expect(label, mutate, pattern) {
  const d = f.skillFocusData();
  mutate(d);
  const problems = f.skillFocusProblems(d);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
expect('the shipped table is valid', () => {}, null);
expect('a window of zero fails', (d) => { d.focusWindowMinutes = 0; }, /focusWindowMinutes/);
expect('a fractional window fails', (d) => { d.focusWindowMinutes = 1.5; }, /focusWindowMinutes/);
expect('a window over the 600 minutes a record keeps fails', (d) => { d.focusWindowMinutes = 601; }, /focusWindowMinutes/);
expect('a negative bonus fails', (d) => { d.maxBonus = -0.1; }, /maxBonus/);
expect('a zero bonus is valid', (d) => { d.maxBonus = 0; }, null);
if (failed) { console.error(`${failed} check(s) failed`); process.exit(1); }
console.log('all skill-focus checks passed');
