#!/usr/bin/env node
// Phase 139 — proves the settlement validator catches bad tables: a stockpile without capacity and out-of-order
// thresholds fail; Phase 203 — any claim field (a tier claim radius, claim decay, hearth separation) fails;
// the shipped table passes.
//   node tools/check_settlement.js
'use strict';
const s = require('../fabric/gameplay/settlement');
const ITEMS = ['Hearth'];
const fresh = () => JSON.parse(JSON.stringify(s.RULES));
let failed = 0;
function expect(label, rules, pattern) {
  const problems = s.settlementProblems(rules, ITEMS);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

expect('the shipped table is valid', s.RULES, null);
let r = fresh(); r.tiers.town.claimRadius = 96;
expect('a tier claim radius fails: settlements have no claim', r, /tiers\.town\.claimRadius: settlements have no claim/);
r = fresh(); r.decayRadiusPerDay = 2;
expect('claim decay fails', r, /decayRadiusPerDay: settlements have no claim/);
r = fresh(); delete r.stockpile.growing.capacityStacks;
expect('a stockpile without capacity fails', r, /capacityStacks must be a positive integer/);
r = fresh(); r.tiers.town.minDays = 1;
expect('a threshold out of order fails', r, /thresholds out of order/);
r = fresh(); r.tiers.town.minMembers = 2;
expect('a member threshold out of order fails', r, /minMembers.*thresholds out of order/);
r = fresh(); r.minSeparation = 200;
expect('a hearth separation fails', r, /minSeparation: settlements have no claim/);
r = fresh(); r.hearthItem = 'Nope';
expect('an unknown hearth item fails', r, /not a defined item/);
process.exit(failed ? 1 : 0);
