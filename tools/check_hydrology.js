#!/usr/bin/env node
// Phase 217 — proves the hydrology validator rejects bad lake and river parameters and that the shipped fabric passes.
//   node tools/check_hydrology.js
'use strict';
const { hydrologyProblems, shippedWorld } = require('../fabric/world/hydrology');

let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
const good = shippedWorld();
const with_ = (o) => hydrologyProblems({ ...good, ...o });

expect('the shipped fabric is valid', hydrologyProblems(good), null);
expect('a lake frequency above 1 fails', with_({ lakeFrequency: 2 }), /lakeFrequency/);
expect('a negative lake frequency fails', with_({ lakeFrequency: -0.1 }), /lakeFrequency/);
expect('a lake depth under 1 m fails', with_({ lakeMinDepth: 0 }), /lakeMinDepth/);
expect('a river source under sea level fails', with_({ riverSourceHeight: -5 }), /riverSourceHeight must be above/);
expect('a river source above the tallest peak fails', with_({ riverSourceHeight: 99999 }), /riverSourceHeight must be below/);
expect('a river narrower than 2 m fails', with_({ riverWidthMin: 1 }), /riverWidthMin/);
expect('a river max width under its min fails', with_({ riverWidthMin: 10, riverWidthMax: 5 }), /riverWidthMax/);
expect('a non-integer catchment fails', with_({ riverCatchmentSteps: 2.5 }), /riverCatchmentSteps/);
expect('a zero catchment fails', with_({ riverCatchmentSteps: 0 }), /riverCatchmentSteps/);
expect('a blocked-biome list that is not a list fails', with_({ riverBlockedBiomes: 'Desert' }), /riverBlockedBiomes/);
expect('an unknown blocked biome fails', with_({ riverBlockedBiomes: ['Narnia'] }), /unknown biome/);
expect('a repeated blocked biome fails', with_({ riverBlockedBiomes: ['Desert', 'Desert'] }), /repeat/);

process.exit(failed ? 1 : 0);
