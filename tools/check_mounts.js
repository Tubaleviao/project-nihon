#!/usr/bin/env node
// Phase 216 — proves the mount validator rejects a speed factor of 1 or less, a mount on a creature that
// cannot be tamed into a companion, and a bad stamina, terrain or rider offset, and that the shipped fabric
// passes and declares at least one mount.
//   node tools/check_mounts.js
'use strict';
const shared = require('../fabric/world/creatures/shared');
const creatures = require('../fabric/world/creatures');

let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

const good = { speedFactor: 2, staminaSeconds: 0, terrain: ['ground'], riderOffset: [0, 0.8, 0] };
const tameable = { result: 'companion' };
const beast = (mount, tame = tameable) => ({ fields: { tame: { defaultValue: tame }, mount: shared.mountData(mount) } });
const wrap = (mount, tame) => ({ fields: { tame: { defaultValue: tame }, mount: { defaultValue: mount } } });

expect('the shipped fabric is valid', shared.mountProblems(creatures), null);
expect('the shipped fabric declares at least one mount',
  Object.values(creatures).some((c) => c.fields && c.fields.mount) ? [] : ['no mount'], null);
expect('a valid mount passes', shared.mountProblems({ Horse: beast(good) }), null);
expect('a speed factor of 1 fails', shared.mountProblems({ Snail: beast({ ...good, speedFactor: 1 }) }), /Snail: mount.speedFactor must be greater than 1/);
expect('a slower mount fails', shared.mountProblems({ Slug: beast({ ...good, speedFactor: 0.5 }) }), /Slug: mount.speedFactor/);
expect('a speed factor past the cap fails', shared.mountProblems({ Rocket: beast({ ...good, speedFactor: 50 }) }), /Rocket: mount.speedFactor/);
expect('a mount on a yield-only creature fails', shared.mountProblems({ Sheep: beast(good, { result: 'yield' }) }), /Sheep: only a tameable creature/);
expect('a mount on an untameable creature fails', shared.mountProblems({ Troll: wrap(good, undefined) }), /Troll: only a tameable creature/);
expect('negative stamina fails', shared.mountProblems({ Tired: beast({ ...good, staminaSeconds: -1 }) }), /Tired: mount.staminaSeconds/);
expect('an unknown terrain fails', shared.mountProblems({ Bird: beast({ ...good, terrain: ['air'] }) }), /Bird: mount.terrain/);
expect('an empty terrain list fails', shared.mountProblems({ Stuck: beast({ ...good, terrain: [] }) }), /Stuck: mount.terrain/);
expect('a rider far above the mount fails', shared.mountProblems({ Tall: beast({ ...good, riderOffset: [0, 9, 0] }) }), /Tall: mount.riderOffset/);
expect('a malformed rider offset fails', shared.mountProblems({ Odd: beast({ ...good, riderOffset: [0, 1] }) }), /Odd: mount.riderOffset/);

process.exit(failed ? 1 : 0);
