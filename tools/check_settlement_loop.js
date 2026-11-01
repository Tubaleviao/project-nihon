#!/usr/bin/env node
// Phase 197 — proves the settlement loop validator catches bad tables: a project with no materials or an
// unknown item, a specialty naming an unknown skill or attribute, an unknown station or tier all fail.
// Phase 203 — project labour (steps, work units), project effects, the specialty labour bonus, raids and
// upkeep all fail; the shipped tables pass. Phase 207 — a tier with minProjects fails.
//   node tools/check_settlement_loop.js
'use strict';
const s = require('../fabric/gameplay/settlement');
const refs = s.settlementLoopRefs();
const fresh = () => s.settlementLoopData();
let failed = 0;
function expect(label, data, pattern) {
  const problems = s.settlementLoopProblems(data, refs);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

expect('the shipped tables are valid', fresh(), null);
let d = fresh(); d.projects.projects.palisade.materials = [];
expect('a project with no materials fails', d, /palisade\.materials must list at least one/);
d = fresh(); d.projects.projects.palisade.materials[0].item = 'Nope';
expect('a project material that is not an item fails', d, /palisade\.materials\[0\]: item "Nope" is not a defined item/);
d = fresh(); d.specialties.specialties.smith.skills.Juggling = 1;
expect('a specialty naming an unknown skill fails', d, /smith: unknown skill "Juggling"/);
d = fresh(); d.specialties.specialties.hunter.attributes.charm = 1;
expect('a specialty naming an unknown attribute fails', d, /hunter: unknown attribute "charm"/);
d = fresh(); d.projects.projects.workshop.labour = [{ step: 'walls', specialty: 'builder', work: 60 }];
expect('a project with labour steps fails', d, /workshop\.labour: a project is complete once its materials are in/);
d = fresh(); d.projects.projects.palisade.work = 10;
expect('a project with work units fails', d, /palisade\.work: a project is complete once its materials are in/);
d = fresh(); d.projects.workSecondsPerUnit = 2;
expect('a work-seconds-per-unit rate fails', d, /SettlementProjects\.workSecondsPerUnit: projects have no labour/);
d = fresh(); d.projects.projects.workshop.effects = [{ kind: 'craftSpeed', value: 0.2 }];
expect('a project effect fails', d, /workshop\.effects: a project is complete once its materials are in/);
d = fresh(); d.specialties.bonusLabour = 0.5;
expect('a specialty labour bonus fails', d, /SettlementSpecialties\.bonusLabour: projects have no labour/);
d = fresh(); d.raids = { warningSeconds: 120 };
expect('a raid table fails', d, /"raids": raids and upkeep were removed/);
d = fresh(); d.upkeep = { periodHours: 24 };
expect('an upkeep table fails', d, /"upkeep": raids and upkeep were removed/);
d = fresh(); d.projects.projects.workshop.places.stations = ['spaceport'];
expect('a project placing an unknown station fails', d, /"spaceport" is not a placeable station type/);
d = fresh(); d.projects.projects.watchtower.minTier = 'city';
expect('a project with an unknown minTier fails', d, /watchtower\.minTier "city" is not a settlement tier/);

const rules = JSON.parse(JSON.stringify(s.RULES));
rules.tiers.growing.minProjects = 2;
const tierProblems = s.settlementProblems(rules, ['Hearth']);
const ok = tierProblems.some((p) => /growing\.minProjects: completed projects count toward no tier/.test(p));
console.log(`${ok ? 'ok  ' : 'FAIL'} a tier reached by projects fails (Phase 207)${ok ? '' : ' — ' + JSON.stringify(tierProblems)}`);
if (!ok) failed++;

let threw = false;
try { s.validateSettlementLoop(d, refs); } catch (e) { threw = true; }
console.log(`${threw ? 'ok  ' : 'FAIL'} validateSettlementLoop throws on bad data`);
if (!threw) failed++;

process.exit(failed ? 1 : 0);
