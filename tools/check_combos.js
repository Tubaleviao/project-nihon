#!/usr/bin/env node
// Phase 287 — proves the combo-table validator rejects bad tables: a chain step naming a clip outside the rig
// contract, an impact time outside 0..1, a step without a multiplier, a bad stagger share; the shipped table passes.
//   node tools/check_combos.js
'use strict';
const c = require('../fabric/gameplay/combos');
let failed = 0;
function expect(label, mutate, pattern) {
  const d = c.combosData();
  mutate(d);
  const problems = c.combosProblems(d);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
expect('the shipped table is valid', () => {}, null);
expect('a clip outside the rig contract fails', (d) => { d.chains.one_hand.clips[1] = 'attack_flurry'; }, /attack_flurry" is outside the rig contract/);
expect('an impact time above 1 fails', (d) => { d.chains.one_hand.impact[0] = 1.2; }, /impact needs a time in 0..1/);
expect('an impact time below 0 fails', (d) => { d.chains.unarmed.impact[1] = -0.1; }, /impact needs a time in 0..1/);
expect('a missing impact time fails', (d) => { d.chains.two_hand.impact.pop(); }, /impact needs a time/);
expect('a missing multiplier fails', (d) => { d.chains.unarmed.damageMultipliers.pop(); }, /damageMultipliers needs/);
expect('a zero window fails', (d) => { d.chains.tool.windowSeconds = 0; }, /windowSeconds must be > 0/);
expect('a stagger share of 1 fails', (d) => { d.staggerShare = 1; }, /staggerShare must be in \(0, 1\)/);
expect('a missing chain fails', (d) => { delete d.chains.two_hand; }, /chains.two_hand is missing/);
expect('a heavy knock-back under the light one fails', (d) => { d.knockbackHeavy = 0.1; }, /knockbackHeavy must be at least/);
process.exit(failed ? 1 : 0);
