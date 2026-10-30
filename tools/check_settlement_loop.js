#!/usr/bin/env node
// Phase 197 — proves the settlement loop validator catches bad tables: a project with no materials or an
// unknown item, an effect outside the closed set, a specialty naming an unknown skill or attribute, a raid
// loss share above 1 or with no warning, a raid table without offline protection, and upkeep that falls as
// the tier rises all fail; the shipped tables pass.
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
d = fresh(); d.projects.projects.workshop.effects[0].kind = 'flight';
expect('an effect outside the closed set fails', d, /workshop\.effects\[0\]\.kind "flight" must be one of/);
d = fresh(); d.specialties.specialties.smith.skills.Juggling = 1;
expect('a specialty naming an unknown skill fails', d, /smith: unknown skill "Juggling"/);
d = fresh(); d.specialties.specialties.hunter.attributes.charm = 1;
expect('a specialty naming an unknown attribute fails', d, /hunter: unknown attribute "charm"/);
d = fresh(); d.raids.stakes.stockpileShareMax = 1.5;
expect('a raid loss share above 1 fails', d, /stakes\.stockpileShareMax must be a share in \[0, 1\]/);
d = fresh(); d.raids.warningSeconds = 0;
expect('a raid with no warning time fails', d, /warningSeconds must be > 0/);
d = fresh(); delete d.raids.warningSeconds;
expect('a raid table missing its warning time fails', d, /warningSeconds must be > 0/);
d = fresh(); delete d.raids.offlineProtection;
expect('a raid table without offline protection fails', d, /offlineProtection must be true/);
d = fresh(); d.upkeep.costs.town = [{ item: 'ThornwoodPlank', quantity: 1 }];
expect('upkeep that falls as the tier rises fails', d, /costs\.town: ThornwoodPlank 1 falls below growing's 6/);
d = fresh(); d.upkeep.shrinksClaim = true;
expect('upkeep that shrinks the claim fails', d, /shrinksClaim must be false/);
d = fresh(); d.raids.packs.TemperateForest[0].creature = 'LavaSlug';
expect('a raid pack from another biome fails', d, /LavaSlug lives in VolcanicBadlands, not TemperateForest/);
d = fresh(); d.raids.packs.TemperateForest[0].creature = 'Dragon';
expect('a raid pack with an unknown creature fails', d, /unknown creature "Dragon"/);
d = fresh(); d.projects.projects.workshop.labour[0].specialty = 'baker';
expect('a project step for an unknown specialty fails', d, /specialty "baker" is not a specialty/);
d = fresh(); d.projects.projects.workshop.places.stations = ['spaceport'];
expect('a project placing an unknown station fails', d, /"spaceport" is not a placeable station type/);
d = fresh(); d.projects.projects.watchtower.minTier = 'city';
expect('a project with an unknown minTier fails', d, /watchtower\.minTier "city" is not a settlement tier/);

const rules = JSON.parse(JSON.stringify(s.RULES));
rules.tiers.town.minProjects = 4;
const tierProblems = s.settlementProblems(rules, ['Hearth']);
const ok = tierProblems.some((p) => /town keeps its day threshold/.test(p));
console.log(`${ok ? 'ok  ' : 'FAIL'} a town tier reached by projects fails${ok ? '' : ' — ' + JSON.stringify(tierProblems)}`);
if (!ok) failed++;

let threw = false;
try { s.validateSettlementLoop(d, refs); } catch (e) { threw = true; }
console.log(`${threw ? 'ok  ' : 'FAIL'} validateSettlementLoop throws on bad data`);
if (!threw) failed++;

process.exit(failed ? 1 : 0);
