const { defineEntity } = require('@newel/core')

function skillStateMachine() {
  return {
    field: 'tier',
    initial: 'novice',
    states: {
      novice:     'Entry-level practitioner; basic techniques only',
      apprentice: 'Growing competence; intermediate techniques unlock',
      journeyman: 'Solid practitioner; advanced techniques and profession gates open',
      expert:     'Near-mastery; most advanced abilities available',
      master:     { description: 'Complete mastery; all abilities unlocked', terminal: true },
    },
    transitions: [
      { from: 'novice',     to: 'apprentice', trigger: 'advanceTier' },
      { from: 'apprentice', to: 'journeyman', trigger: 'advanceTier' },
      { from: 'journeyman', to: 'expert',     trigger: 'advanceTier' },
      { from: 'expert',     to: 'master',     trigger: 'advanceTier' },
    ],
  }
}

module.exports = { defineEntity, skillStateMachine }
