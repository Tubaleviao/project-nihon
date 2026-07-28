const { defineEntity } = require('@newel/core')

const CREATURE_TIERS = ['1', '2', '3', '4', '5']
const AGGRESSION_LEVELS = ['passive', 'neutral', 'aggressive', 'territorial']
const CREATURE_STATES = ['idle', 'alert', 'aggressive', 'fleeing', 'dead', 'respawning']

function creatureStateMachine() {
  return {
    field: 'state',
    initial: 'idle',
    states: {
      idle:       'Creature is at rest; not pursuing any target',
      alert:      'Creature has detected a threat; preparing to fight or flee',
      aggressive: 'Creature is actively attacking a target',
      fleeing:    'Creature is retreating from danger; cannot attack',
      dead:       'Creature has been killed; drops are available',
      respawning: { description: 'Creature is regenerating at its spawn point; not yet interactable', terminal: false },
    },
    transitions: [
      { from: 'idle',       to: 'alert',      trigger: 'detect' },
      { from: 'alert',      to: 'aggressive', trigger: 'attack' },
      { from: 'alert',      to: 'idle',       trigger: 'calm' },
      { from: 'alert',      to: 'fleeing',    trigger: 'flee' },
      { from: 'aggressive', to: 'fleeing',    trigger: 'flee' },
      { from: 'aggressive', to: 'dead',       trigger: 'die' },
      { from: 'fleeing',    to: 'dead',       trigger: 'die' },
      { from: 'fleeing',    to: 'idle',       trigger: 'calm' },
      { from: 'dead',       to: 'respawning', trigger: 'respawn' },
      { from: 'respawning', to: 'idle',       trigger: 'calm' },
    ],
  }
}

module.exports = { defineEntity, creatureStateMachine, CREATURE_TIERS, AGGRESSION_LEVELS, CREATURE_STATES }
