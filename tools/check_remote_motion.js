#!/usr/bin/env node
// Phase 294 — proves the remote-motion validator catches bad tables: a buffer shorter than the send interval,
// extrapolation longer than one send interval, a run speed not above the walk speed, a teleport distance a
// runner covers between two states and an unknown field all fail, and the shipped table passes.
//   node tools/check_remote_motion.js
'use strict';
const motion = require('../fabric/gameplay/remote_motion');

const fresh = () => JSON.parse(JSON.stringify(motion.MOTION));
let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

expect('the shipped table is valid', motion.motionProblems(fresh()), null);

const buf = fresh(); buf.players.bufferMs = 50;
expect('a buffer shorter than the send interval fails', motion.motionProblems(buf), /players\.bufferMs must be at least sendIntervalMs/);

const ex = fresh(); ex.creatures.extrapolateMaxMs = 250;
expect('extrapolating past one send interval fails', motion.motionProblems(ex), /creatures\.extrapolateMaxMs must be in 0\.\.sendIntervalMs/);

const run = fresh(); run.runSpeed = 0.1;
expect('a run speed not above the walk speed fails', motion.motionProblems(run), /runSpeed must be greater than walkSpeed/);

const tp = fresh(); tp.teleportDistanceM = 0.2;
expect('a teleport distance a runner covers between two states fails', motion.motionProblems(tp), /teleportDistanceM \(0\.2\) must exceed/);

const far = fresh(); far.creatures.farSendIntervalMs = 50;
expect('a far send interval below the near one fails', motion.motionProblems(far), /farSendIntervalMs must be in sendIntervalMs/);

const unk = fresh(); unk.players.lagMs = 3;
expect('an unknown field fails', motion.motionProblems(unk), /unknown field "lagMs"/);

let threw = false;
try { motion.validateMotion(buf); } catch (e) { threw = true; }
expect('validateMotion throws on a bad table', threw ? [] : ['did not throw'], null);

process.exit(failed ? 1 : 0);
