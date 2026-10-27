#!/usr/bin/env node
// Phase 192 — proves the creature body validator catches a missing or out-of-range footprint and
// squash, and that the shipped fabric passes.
//   node tools/check_bodies.js
'use strict';
const shared = require('../fabric/world/creatures/shared');
const creatures = require('../fabric/world/creatures');

let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

const body = (r, s) => ({ fields: shared.bodyFields({ bodyRadiusMetres: r, squash: s }) });

expect('the shipped fabric is valid', shared.bodyFieldProblems(creatures), null);
expect('a creature with no body fields fails', shared.bodyFieldProblems({ Ghost: { fields: {} } }), /Ghost: creature must declare bodyRadiusMetres/);
expect('a tiny footprint fails', shared.bodyFieldProblems({ Mite: body(0.05, 0.2) }), /Mite: bodyRadiusMetres must be in/);
expect('a huge footprint fails', shared.bodyFieldProblems({ Titan: body(9, 0.2) }), /Titan: bodyRadiusMetres must be in/);
expect('a negative squash fails', shared.bodyFieldProblems({ Rock: body(0.5, -0.1) }), /Rock: squash must be in/);
expect('a squash past the cap fails', shared.bodyFieldProblems({ Jelly: body(0.5, 0.9) }), /Jelly: squash must be in/);

process.exit(failed ? 1 : 0);
