const { defineEntity } = require('@newel/core')

// Phase 272 — focus. The host counts, per player and skill, the active minutes of play time inside the last
// `focusWindowMinutes`; XP granted in a skill is multiplied by 1 + maxBonus * activeMinutes / windowMinutes,
// so one straight hour on one skill earns +maxBonus and no focus earns the normal rate (never less).
const FOCUS_WINDOW_MINUTES = 60
const MAX_BONUS = 0.25

function skillFocusData() { return { focusWindowMinutes: FOCUS_WINDOW_MINUTES, maxBonus: MAX_BONUS } }

/** Problems with the focus table, as strings. */
function skillFocusProblems(d) {
  const p = []
  if (!(Number.isInteger(d.focusWindowMinutes) && d.focusWindowMinutes > 0)) p.push('focusWindowMinutes must be a whole number of minutes above zero')
  if (!(typeof d.maxBonus === 'number' && d.maxBonus >= 0 && d.maxBonus <= 5)) p.push('maxBonus must be between 0 and 5 (a negative bonus would punish trying something new)')
  return p
}

function validateSkillFocus(d) {
  const problems = skillFocusProblems(d)
  if (problems.length) throw new Error('Skill focus is invalid:\n  ' + problems.join('\n  '))
}

const SkillFocus = defineEntity({
  tags: ['world-system'],
  description:
    'Dedication: XP in a skill is multiplied by 1 + maxBonus x (active minutes in the last focus window) / window, ' +
    'counted in play time. A skill with no focus earns the normal rate.',
  goal: 'Reward a player for sticking with one skill without ever punishing trying another (Phase 272)',
  fields: {
    id:                 { type: 'uuid', primaryKey: true },
    focusWindowMinutes: { type: 'integer', description: 'Minutes of play time the focus looks back over', defaultValue: FOCUS_WINDOW_MINUTES },
    maxBonus:           { type: 'decimal', description: 'XP bonus (0.25 = +25%) with a full window of activity in one skill', defaultValue: MAX_BONUS },
  },
})

module.exports = { FOCUS_WINDOW_MINUTES, MAX_BONUS, skillFocusData, skillFocusProblems, validateSkillFocus, SkillFocus }
