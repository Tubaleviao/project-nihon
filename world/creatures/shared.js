const { defineEntity } = require('@newel/core')

const CREATURE_TIERS = ['1', '2', '3', '4', '5']
const AGGRESSION_LEVELS = ['passive', 'neutral', 'aggressive', 'territorial']
const CREATURE_STATES = ['idle', 'alert', 'aggressive', 'fleeing', 'dead', 'respawning']

// Returns the CREATURE_STATES subset appropriate for a creature's canFlee/skipAlert settings.
function creatureStateValues({ canFlee = true, skipAlert = false } = {}) {
  return CREATURE_STATES.filter(s => {
    if (s === 'fleeing' && !canFlee) return false
    if (s === 'alert'   && skipAlert) return false
    return true
  })
}

// canFlee: set to false for creatures whose design forbids the fleeing state (e.g. RiftWarden).
// skipAlert: set to true for creatures that fire attack directly from idle on detection, bypassing alert (e.g. RiftWarden).
function creatureStateMachine({ canFlee = true, skipAlert = false } = {}) {
  const fleeTransitions = canFlee
    ? [
        ...(!skipAlert ? [{ from: 'alert', to: 'fleeing', trigger: 'flee' }] : []),
        { from: 'aggressive', to: 'fleeing', trigger: 'flee' },
        { from: 'fleeing',    to: 'dead',    trigger: 'die' },
        { from: 'fleeing',    to: 'idle',    trigger: 'calm' },
        { from: 'fleeing',    to: 'aggressive', trigger: 'attack' },
      ]
    : []

  const alertTransitions = skipAlert
    ? []
    : [
        { from: 'idle',  to: 'alert',      trigger: 'detect' },
        { from: 'alert', to: 'aggressive', trigger: 'attack' },
        { from: 'alert', to: 'idle',       trigger: 'calm' },
      ]

  return {
    field: 'state',
    initial: 'idle',
    states: {
      idle:       'Creature is at rest; not pursuing any target',
      ...(skipAlert ? {} : { alert: 'Creature has detected a threat; preparing to fight or flee' }),
      aggressive: 'Creature is actively attacking a target',
      ...(canFlee ? { fleeing: 'Creature is retreating from danger; cannot attack' } : {}),
      dead:       'Creature has been killed; drops are available',
      respawning: 'Creature is regenerating at its spawn point; not yet interactable',
    },
    transitions: [
      ...(skipAlert ? [{ from: 'idle', to: 'aggressive', trigger: 'detect' }] : []),
      ...alertTransitions,
      { from: 'idle',       to: 'aggressive', trigger: 'attack' },
      { from: 'aggressive', to: 'dead',       trigger: 'die' },
      { from: 'aggressive', to: 'idle',       trigger: 'calm' },
      ...fleeTransitions,
      { from: 'dead',       to: 'respawning', trigger: 'respawn' },
      { from: 'respawning', to: 'idle',       trigger: 'calm' },
    ],
  }
}

module.exports = { defineEntity, creatureStateMachine, creatureStateValues, CREATURE_TIERS, AGGRESSION_LEVELS, CREATURE_STATES }
