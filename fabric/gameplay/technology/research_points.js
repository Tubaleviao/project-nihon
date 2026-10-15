const { defineEntity } = require('@newel/core')

// Phase 124 — research points. A player earns points from play and `begin_research` spends the
// technology's `researchCost`. The table below is the single source of truth for how many points
// each source grants; the runtime reads it from GameData.WORLD_SYSTEMS["ResearchPointRule"].
//
// `craft`: points for every successful craft. `gather`: points for every gathered resource.
// `firstCraftOfRecipe`: bonus, once per player per recipe, on top of `craft`.
//
// Caps (Phase 130): `maxPoints` bounds a balance; `windowSeconds` / `windowCap` bound what one player
// can EARN inside any window of that many seconds, so gathering or crafting in a loop is not a faucet.
// A `gather` grant is `gather` x the quantity gathered.
const RULES = { craft: 1, gather: 1, firstCraftOfRecipe: 3, maxPoints: 5000, windowSeconds: 600, windowCap: 60 }
const SOURCES = ['craft', 'gather', 'firstCraftOfRecipe']
const KEYS = [...SOURCES, 'maxPoints', 'windowSeconds', 'windowCap']

// A technology's cost is bounded so a typo cannot make it unreachable.
const MAX_RESEARCH_COST = 1000

/** Problems with a rule table, as strings: each value must be a non-negative integer. */
function ruleProblems(rules) {
  const problems = []
  for (const key of KEYS) {
    const v = rules[key]
    if (!Number.isInteger(v) || v < 0) problems.push(`ResearchPointRule.${key} must be a non-negative integer, got ${v}`)
  }
  for (const key of Object.keys(rules)) {
    if (!KEYS.includes(key)) problems.push(`ResearchPointRule has unknown source "${key}"`)
  }
  if (Number.isInteger(rules.maxPoints) && rules.maxPoints < MAX_RESEARCH_COST) problems.push(`ResearchPointRule.maxPoints ${rules.maxPoints} is below the largest technology cost ${MAX_RESEARCH_COST}`)
  if (Number.isInteger(rules.windowSeconds) && rules.windowSeconds < 1) problems.push('ResearchPointRule.windowSeconds must be at least 1')
  return problems
}

/** Problems with `{ techKey: researchCost }`: each cost must be an integer in 0..max. */
function costProblems(costs, max) {
  const problems = []
  for (const [key, v] of Object.entries(costs)) {
    if (!Number.isInteger(v) || v < 0 || v > max) problems.push(`${key}: researchCost ${v} is outside 0..${max}`)
  }
  return problems
}

function validateRules(rules) {
  const problems = ruleProblems(rules)
  if (problems.length) throw new Error('Research point rule table is invalid:\n  ' + problems.join('\n  '))
}

function validateCosts(costs, max) {
  const problems = costProblems(costs, max)
  if (problems.length) throw new Error('Technology research costs are invalid:\n  ' + problems.join('\n  '))
}

const ResearchPointRule = defineEntity({
  tags: ['world-system'],
  description:
    'Points of research a player earns per source: a craft, a gathered resource, and a one-time ' +
    'bonus for the first craft of each recipe. Spent by beginResearch at the technology\'s researchCost.',
  goal: 'Make KnowledgeIsProgression cost something earned by play, not only materials and time',
  fields: {
    id: { type: 'uuid', primaryKey: true },
    rules: {
      type: 'json',
      description: 'Points per source { craft, gather, firstCraftOfRecipe } and caps { maxPoints, windowSeconds, windowCap }, non-negative integers (validated at fabric load)',
      defaultValue: RULES,
    },
    maxResearchCost: {
      type: 'integer',
      description: 'Upper bound a technology researchCost may take (validated at fabric load)',
      defaultValue: MAX_RESEARCH_COST,
    },
  },
  behaviors: {
    grantPoints: {
      description: 'Host-side grant of research points to the player who crafted or gathered',
      rules: ['Granted only by the host; a client\'s own grant call changes nothing'],
      auth: { roles: ['maintainer'] },
    },
  },
})

module.exports = { RULES, MAX_RESEARCH_COST, ResearchPointRule, ruleProblems, costProblems, validateRules, validateCosts }
