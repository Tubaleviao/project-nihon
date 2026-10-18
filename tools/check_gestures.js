#!/usr/bin/env node
// Phase 158 — proves the gesture validator catches bad tables: an unknown kind, two gestures sharing
// a chat command and a restRegen below 1.0 all fail, and the shipped table passes.
//   node tools/check_gestures.js
'use strict';
const gestures = require('../fabric/gameplay/gestures');

const fresh = () => JSON.parse(JSON.stringify(gestures.gestureTable()));
let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

expect('the shipped table is valid', gestures.gestureProblems(fresh()), null);

const kind = fresh(); kind.Wave.kind = 'dance-party';
expect("kind 'dance-party' fails", gestures.gestureProblems(kind), /kind must be one of/);

const dup = fresh(); dup.SitGround.chatCommand = '/sit';
expect('two gestures sharing /sit fail', gestures.gestureProblems(dup), /share chatCommand \/sit/);

const regen = fresh(); regen.Sit.restRegen = 0.9;
expect('restRegen below 1.0 fails', gestures.gestureProblems(regen), /restRegen must be >= 1\.0/);

let threw = false;
try { gestures.validateGestures(kind); } catch (e) { threw = true; }
expect('validateGestures throws on a bad table', threw ? [] : ['did not throw'], null);

process.exit(failed ? 1 : 0);
