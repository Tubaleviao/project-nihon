#!/usr/bin/env node
// Phase 203 — proves the chest and door validator catches bad tables: an unknown access mode, a mode set by
// anyone but the owner, a chest that keeps its contents when destroyed, a lock of an unknown material or
// technology, a multiplier below 1 and a lock that opens instantly all fail; the shipped table passes.
//   node tools/check_chests.js
'use strict';
const c = require('../fabric/gameplay/chests');
const refs = c.chestsRefs();
let failed = 0;
function expect(label, mutate, pattern) {
  const d = c.chestsData();
  mutate(d);
  const problems = c.chestsProblems(d, refs);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

expect('the shipped table is valid', () => {}, null);
expect('an extra access mode fails', (d) => { d.accessModes.push('friends'); }, /accessModes must be/);
expect('a default outside the modes fails', (d) => { d.defaultMode = 'friends'; }, /defaultMode "friends"/);
expect('a mode set by anyone fails', (d) => { d.setBy = 'clan'; }, /only the owner changes a mode/);
expect('a chest that keeps its contents fails', (d) => { d.stations.chest.spillsOnDestroy = false; }, /spills its contents/);
expect('a missing door fails', (d) => { delete d.stations.door; }, /stations\.door is missing/);
expect('a lock of an unknown material fails', (d) => { d.locks.materials.Glass = 2; }, /"Glass" is not a material/);
expect('a lock of an unknown technology fails', (d) => { d.locks.technologies.TechLocks = 2; }, /"TechLocks" is not a technology/);
expect('a lock multiplier below 1 fails', (d) => { d.locks.materials.Thornwood = 0.5; }, /materials\.Thornwood must be >= 1/);
expect('a lock that opens instantly fails', (d) => { d.locks.skillSpeedup = 1; }, /no lock opens instantly/);

let threw = false;
try { const d = c.chestsData(); d.setBy = 'everyone'; c.validateChests(d, refs); } catch (e) { threw = true; }
console.log(`${threw ? 'ok  ' : 'FAIL'} validateChests throws on bad data`);
if (!threw) failed++;
process.exit(failed ? 1 : 0);
