#!/usr/bin/env node
// Phase 129 — proves the status-effect validators catch bad tables: an onHitEffects entry naming an
// undefined effect, a chance outside 0..1, a negative duration and an unknown weather state all fail,
// and the shipped table passes.
//   node tools/check_combat.js
'use strict';
const combat = require('../fabric/gameplay/combat');
const weather = require('../fabric/world/weather');
const creatures = require('../fabric/world/creatures');

const states = Object.keys(weather.RULES.states);
const fresh = () => JSON.parse(JSON.stringify(combat.STATUS_EFFECTS));
const onHit = () => JSON.parse(JSON.stringify(combat.creatureOnHit(creatures)));
let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
const all = (table, hits) => combat.statusEffectProblems(table, states).concat(combat.onHitProblems(hits, table));

expect('the shipped tables are valid', all(combat.STATUS_EFFECTS, onHit()), null);

const undef = onHit(); undef.ForestBoar = [{ effect: 'frostbite', chance: 1 }];
expect('an onHitEffects entry naming an undefined effect fails', all(fresh(), undef), /undefined effect "frostbite"/);

const chance = onHit(); chance.VeilStalker = [{ effect: 'paralysis', chance: 1.5 }];
expect('a chance of 1.5 fails', all(fresh(), chance), /chance must be in 0\.\.1/);

const neg = fresh(); neg.heat_burn.durationSeconds = -1;
expect('a negative duration fails', all(neg, onHit()), /durationSeconds must be in/);

const wet = fresh(); wet.heat_burn.extinguishedBy = ['hail'];
expect('an unknown weather state fails', all(wet, onHit()), /unknown weather state "hail"/);

const stacky = fresh(); stacky.paralysis.stacks = true;
expect('an immobilizing effect that stacks fails', all(stacky, onHit()), /must have stacks: false/);

const far = fresh(); far.knockback.displaceTiles = 99;
expect('a huge displacement fails', all(far, onHit()), /displaceTiles must be an integer/);

if (failed) process.exit(1);
