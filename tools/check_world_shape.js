#!/usr/bin/env node
// Phase 238 — proves the world-shape validator rejects a bad seed, circumference and continent list.
//   node tools/check_world_shape.js
'use strict';
const { worldShapeProblems } = require('../fabric/world/world_shape');
const { shippedWorld } = require('../fabric/world/hydrology');

let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
const good = shippedWorld();
const with_ = (o) => worldShapeProblems({ ...good, circumferenceKm: 2000, ...o });
const c = (o) => ({ id: 'x', latitude: 0, longitude: 0, radiusKm: 100, open: true, ...o });

expect('the shipped fabric is valid', worldShapeProblems(good), null);
expect('a fractional seed fails', with_({ worldSeed: 1.5 }), /worldSeed/);
expect('a string seed fails', with_({ worldSeed: '7' }), /worldSeed/);
expect('a zero circumference fails', with_({ circumferenceKm: 0 }), /circumferenceKm/);
expect('a negative circumference fails', with_({ circumferenceKm: -5 }), /circumferenceKm/);
expect('no continents fails', with_({ continents: [] }), /at least one open/);
expect('only closed continents fails', with_({ continents: [c({ open: false })] }), /at least one open/);
expect('overlapping continents fail', with_({ continents: [c({ id: 'a' }), c({ id: 'b', longitude: 10 })] }), /overlap/);
expect('overlap across the wrap fails', with_({ continents: [c({ id: 'a', longitude: 179 }), c({ id: 'b', longitude: -179 })] }), /overlap/);
expect('a repeated id fails', with_({ continents: [c({ id: 'a' }), c({ id: 'a', longitude: 180 })] }), /repeats the id/);
expect('a zero radius fails', with_({ continents: [c({ radiusKm: 0 })] }), /radiusKm/);
expect('a latitude past the pole fails', with_({ continents: [c({ latitude: 95 })] }), /latitude/);
expect('a non-boolean open fails', with_({ continents: [c({ open: 'yes' })] }), /open/);
expect('a continent list that is not a list fails', with_({ continents: 'home' }), /continents/);

process.exit(failed ? 1 : 0);
