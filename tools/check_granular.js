#!/usr/bin/env node
// Phase 137 — proves the granular validator catches a biome whose surfaceMaterial declares no
// `granular`, and that the shipped fabric passes.
//   node tools/check_granular.js
'use strict';
const g = require('../fabric/world/materials/granular');
const materials = require('../fabric/world/materials');
const biomes = require('../fabric/world/biomes');

let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

expect('the shipped fabric is valid', g.granularProblems(biomes, materials), null);
expect('Sand, Snow and Soil are granular', ['Sand', 'Snow', 'Soil'].filter((n) => materials[n].fields.granular.defaultValue !== true), null);
expect('rock and metal are not granular', Object.keys(materials).filter((n) => !['Sand', 'Snow', 'Soil'].includes(n) && materials[n].fields.granular.defaultValue !== false), null);

const odd = { Odd: { fields: { surfaceMaterial: { defaultValue: 'Mystery' } } } };
expect('a biome whose cover declares no granular fails', g.granularProblems(odd, materials), /surfaceMaterial "Mystery" does not declare/);

const bare = { Sand: { fields: {} } };
expect('a material with no granular field fails', g.granularProblems({}, bare), /declares no `granular` field/);

process.exit(failed ? 1 : 0);
