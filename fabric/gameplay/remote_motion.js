const { defineEntity } = require('@newel/core')

// Phase 294 — how another player's body and a creature move on a client. The host sends states (position, and for
// a player whether it is in the air) at a fixed interval; a client keeps the last few and plays them back a little
// late (the buffer), so it always has a state on each side of the time it draws and moves the body smoothly
// between them. The runtime reads this table from GameData.WORLD_SYSTEMS["RemoteMotion"] (`RemoteMotionRules`).
//
// `players` / `creatures`:
//   `sendIntervalMs`   ms between two states of one body (a player's client reports this often; the host sends
//                      creature deltas this often).
//   `bufferMs`         ms a client plays states back behind the newest one. At least one send interval, so a
//                      state on time is always there before it is needed. A body whose states arrive less often
//                      (a far one) is played back later still, by the gap the client measures.
//   `extrapolateMaxMs` ms a body keeps moving along its last velocity past the newest state when the next one is
//                      late, then it holds. At most one send interval.
// `creatures.farSendIntervalMs` / `creatures.farDistanceM`: a creature farther than `farDistanceM` from every
//   player is sent at most once per `farSendIntervalMs` (nobody is near enough to see the steps).
// `teleportDistanceM`: a new state farther than this from the last one is a teleport (a respawn, a bed, a portal):
//   the body is put there at once, once, and plays on from there.
// `turnRateRadPerSec`: how fast a remote body turns toward where it goes.
// `walkSpeed` / `runSpeed`: horizontal m/s at or above which a body plays `walk` / `run`; below `walkSpeed` it
//   stands (`idle`). The local player's locomotion reads the same two numbers.
const MOTION = {
  players:   { sendIntervalMs: 100, bufferMs: 150, extrapolateMaxMs: 100 },
  creatures: { sendIntervalMs: 100, bufferMs: 150, extrapolateMaxMs: 100, farSendIntervalMs: 400, farDistanceM: 96 },
  teleportDistanceM: 30,
  turnRateRadPerSec: 10,
  walkSpeed: 0.2,
  runSpeed: 3.0,
}

const GROUP_FIELDS = {
  players:   ['sendIntervalMs', 'bufferMs', 'extrapolateMaxMs'],
  creatures: ['sendIntervalMs', 'bufferMs', 'extrapolateMaxMs', 'farSendIntervalMs', 'farDistanceM'],
}
const TOP_FIELDS = ['players', 'creatures', 'teleportDistanceM', 'turnRateRadPerSec', 'walkSpeed', 'runSpeed']
const MAX_INTERVAL_MS = 5000
const num = (v) => typeof v === 'number' && Number.isFinite(v)

/** Problems with a remote-motion table, as strings. */
function motionProblems(m) {
  const p = []
  if (m === null || typeof m !== 'object') return ['RemoteMotion must be an object']
  for (const key of Object.keys(m)) if (!TOP_FIELDS.includes(key)) p.push(`RemoteMotion has unknown field "${key}"`)
  for (const [group, fields] of Object.entries(GROUP_FIELDS)) {
    const g = m[group]
    if (g === null || typeof g !== 'object') { p.push(`RemoteMotion.${group} must be an object`); continue }
    for (const key of Object.keys(g)) if (!fields.includes(key)) p.push(`RemoteMotion.${group} has unknown field "${key}"`)
    for (const f of fields) if (!num(g[f])) p.push(`RemoteMotion.${group}.${f} must be a number`)
    if (!num(g.sendIntervalMs) || !num(g.bufferMs) || !num(g.extrapolateMaxMs)) continue
    if (!(g.sendIntervalMs >= 16 && g.sendIntervalMs <= MAX_INTERVAL_MS)) p.push(`RemoteMotion.${group}.sendIntervalMs must be in 16..${MAX_INTERVAL_MS}, got ${g.sendIntervalMs}`)
    if (!(g.bufferMs >= g.sendIntervalMs && g.bufferMs <= MAX_INTERVAL_MS)) p.push(`RemoteMotion.${group}.bufferMs must be at least sendIntervalMs (${g.sendIntervalMs}) and at most ${MAX_INTERVAL_MS}, got ${g.bufferMs}`)
    if (!(g.extrapolateMaxMs >= 0 && g.extrapolateMaxMs <= g.sendIntervalMs)) p.push(`RemoteMotion.${group}.extrapolateMaxMs must be in 0..sendIntervalMs (${g.sendIntervalMs}), got ${g.extrapolateMaxMs}`)
    if (group === 'creatures' && num(g.farSendIntervalMs) && num(g.farDistanceM)) {
      if (!(g.farSendIntervalMs >= g.sendIntervalMs && g.farSendIntervalMs <= MAX_INTERVAL_MS)) p.push(`RemoteMotion.creatures.farSendIntervalMs must be in sendIntervalMs..${MAX_INTERVAL_MS}, got ${g.farSendIntervalMs}`)
      if (!(g.farDistanceM > 0)) p.push(`RemoteMotion.creatures.farDistanceM must be > 0, got ${g.farDistanceM}`)
    }
  }
  if (!num(m.teleportDistanceM) || !(m.teleportDistanceM > 0)) p.push(`RemoteMotion.teleportDistanceM must be > 0, got ${m.teleportDistanceM}`)
  if (!num(m.turnRateRadPerSec) || !(m.turnRateRadPerSec > 0)) p.push(`RemoteMotion.turnRateRadPerSec must be > 0, got ${m.turnRateRadPerSec}`)
  if (!num(m.walkSpeed) || !(m.walkSpeed > 0)) p.push(`RemoteMotion.walkSpeed must be > 0, got ${m.walkSpeed}`)
  if (!num(m.runSpeed) || !(num(m.walkSpeed) && m.runSpeed > m.walkSpeed)) p.push(`RemoteMotion.runSpeed must be greater than walkSpeed (${m.walkSpeed}), got ${m.runSpeed}`)
  // A body running between two states must not read as a teleport: the run speed over the longest gap a near
  // body's states can have stays inside the teleport distance.
  if (num(m.teleportDistanceM) && num(m.runSpeed) && m.players && num(m.players.sendIntervalMs)
      && m.runSpeed * m.players.sendIntervalMs / 1000 >= m.teleportDistanceM) {
    p.push(`RemoteMotion.teleportDistanceM (${m.teleportDistanceM}) must exceed runSpeed × players.sendIntervalMs`)
  }
  return p
}

function validateMotion(m) {
  const problems = motionProblems(m)
  if (problems.length) throw new Error('RemoteMotion table is invalid:\n  ' + problems.join('\n  '))
}

const RemoteMotion = defineEntity({
  tags: ['world-system'],
  description:
    'How a client draws bodies it does not simulate (other players, creatures): it keeps the host\'s last ' +
    'states, plays them back a buffer behind, moves the body between them every frame, extrapolates a late ' +
    'state for at most one send interval, snaps only across a teleport, turns the body at a turn rate and ' +
    'picks idle, walk or run from the speed played back.',
  goal: 'Other players and creatures walk instead of jumping (Phase 294)',
  fields: {
    id: { type: 'uuid', primaryKey: true },
    rules: {
      type: 'json',
      description: 'Motion table: { players: { sendIntervalMs, bufferMs, extrapolateMaxMs }, creatures: { sendIntervalMs, bufferMs, extrapolateMaxMs, farSendIntervalMs, farDistanceM }, teleportDistanceM, turnRateRadPerSec, walkSpeed, runSpeed } (validated at fabric load)',
      defaultValue: MOTION,
    },
  },
  behaviors: {
    playBack: {
      description: 'Each rendered frame, draw a remote body at its states sampled at now minus the buffer',
      rules: [
        'Between two states the body is interpolated; it never moves back along its path',
        'Past the newest state it extrapolates for at most extrapolateMaxMs, then holds',
        'A gap above teleportDistanceM snaps once',
      ],
      auth: { roles: ['maintainer'] },
    },
  },
})

module.exports = { MOTION, RemoteMotion, motionProblems, validateMotion }
