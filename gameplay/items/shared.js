const { defineEntity } = require('@newel/core')

const RARITIES = ['common', 'uncommon', 'rare', 'epic', 'legendary']
const DURABILITY_STATES = ['pristine', 'worn', 'damaged', 'broken']

function itemStateMachine() {
  return {
    field: 'condition',
    initial: 'pristine',
    states: {
      pristine: 'Freshly crafted or repaired; full stat effectiveness',
      worn:     'Showing use; minor stat penalties apply',
      damaged:  'Significantly degraded; notable stat penalties; repair strongly advised',
      broken:   { description: 'Unusable; must be repaired at a workshop before use', terminal: false },
    },
    transitions: [
      { from: 'pristine', to: 'worn',    trigger: 'degrade' },
      { from: 'worn',     to: 'damaged', trigger: 'degrade' },
      { from: 'damaged',  to: 'broken',  trigger: 'degrade' },
      { from: 'broken',   to: 'pristine', trigger: 'repair' },
      { from: 'damaged',  to: 'pristine', trigger: 'repair' },
      { from: 'worn',     to: 'pristine', trigger: 'repair' },
    ],
  }
}

function consumableStateMachine() {
  return {
    field: 'condition',
    initial: 'pristine',
    states: {
      pristine: 'Full potency or freshness; ready for use',
      worn:     'Reduced potency; still usable',
      damaged:  'Significantly degraded; use with caution',
      broken:   { description: 'Spoiled or fully depleted; cannot be used or repaired', terminal: true },
    },
    transitions: [
      { from: 'pristine', to: 'worn',    trigger: 'degrade' },
      { from: 'worn',     to: 'damaged', trigger: 'degrade' },
      { from: 'damaged',  to: 'broken',  trigger: 'degrade' },
    ],
  }
}

module.exports = { defineEntity, RARITIES, DURABILITY_STATES, itemStateMachine, consumableStateMachine }
