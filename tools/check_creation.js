#!/usr/bin/env node
// Phase 180 — proves the creation validator catches bad data: a gender with no preset or no hair, a hair style that
// belongs to two genders, a hair colour outside the hair palette region, an invalid default, a non-chibi preset and
// bad name rules all fail, and the shipped fabric passes.
//   node tools/check_creation.js
'use strict';
const creation = require('../fabric/gameplay/characters/creation');
const appearances = require('../fabric/gameplay/characters/appearances');

const fresh = () => JSON.parse(JSON.stringify(creation.creationData()));
let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
const check = (d, apps = appearances) => creation.creationProblems(d, apps);

expect('the shipped creation data is valid', check(fresh()), null);
const noPreset = fresh(); noPreset.presets.feminine = 'Nope';
expect('a gender naming a missing preset fails', check(noPreset), /names no appearance preset/);
const noHair = fresh(); noHair.hair.masculine = [];
expect('a gender with no hair style fails', check(noHair), /has no hair style/);
const shared = fresh(); shared.hair.feminine[0] = shared.hair.masculine[0];
expect('a hair style shared by two genders fails', check(shared), /more than one gender/);
const badColor = fresh(); badColor.hairColors.push(200);
expect('a hair colour outside the hair region fails', check(badColor), /outside the hair palette region/);
const badDefault = fresh(); badDefault.defaultCreation.hair = badDefault.hair.masculine[0];
expect('a default hair from the other gender fails', check(badDefault), /not a feminine style/);
const badColorDefault = fresh(); badColorDefault.defaultCreation.hairColor = 33.5;
expect('a default colour not in the list fails', check(badColorDefault), /not in the list/);
const shortName = fresh(); shortName.nameRules.minLength = 1;
expect('a name minimum under 3 fails', check(shortName), /name length/);
const noReserved = fresh(); noReserved.nameRules.reserved = [];
expect('an empty reserved list fails', check(noReserved), /reserved-name list/);
const tall = { ...appearances, CreationFeminine: { fields: { proportions: { defaultValue: { headScale: 1.0 } } } } };
expect('a preset that is not chibi fails', check(fresh(), tall), /not chibi/);
const noKit = fresh(); noKit.startingKit.outfit = '';
expect('a starting kit with no outfit fails', check(noKit), /names no outfit/);

if (failed) { console.log(`${failed} check(s) failed`); process.exit(1) }
console.log('check_creation: ok');
