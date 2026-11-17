const { defineEntity, skillStateMachine, SKILL_TIERS, SKILL_CATEGORIES } = require('./shared')
const { SKINNING } = require('../harvest')
const { SKILL_CURVES, TIER_BONUSES } = require('../work')

// Phase 274 — the gathering category: skills that grow from taking things from the world, each from the work
// its tool does (WorkSkills.gather). Mining, Woodcutting and Foraging read their XP curve from
// WorkSkills.curves and what each tier gives from WorkSkills.bonuses; Skinning keeps its harvest table.
// None of them names a profession: anyone uses them. Fishing and Farming join with their systems.
function gatheringSkill(name, { description, goal, work, tierNote }) {
  const curve = SKILL_CURVES[name]
  return defineEntity({
    tags: ['skill'],
    description,
    goal,
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      tier:      { type: 'enum', values: SKILL_TIERS },
      xpCurve:   { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel:  { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required; the same as levelCap', defaultValue: curve.levelCap },
      category:  { type: 'enum', values: SKILL_CATEGORIES, defaultValue: 'gathering', description: 'Skill domain: gathering' },
      levelCap:  { type: 'integer', description: `Highest ${name} level (WorkSkills.curves)`, defaultValue: curve.levelCap },
      xpToLevel: { type: 'json', description: 'Cumulative XP needed to reach each level, index = level (WorkSkills.curves)', defaultValue: curve.xpToLevel },
      tierBonus: { type: 'json', description: `What each tier gives (WorkSkills.bonuses): ${tierNote}`, defaultValue: TIER_BONUSES[name] },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: `Reach the next tier from accumulated ${name} XP (WorkSkills.tiers)`,
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      [work]: {
        description: `Grow ${name} from the work its rows in WorkSkills.gather name`,
        rules: [
          'The host grants the XP per unit gathered from WorkSkills.gather, never from a client message',
          `Each tier applies its WorkSkills.bonuses.${name} factor`,
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  })
}

module.exports = {

  // ─── Mining ───────────────────────────────────────────────────────────────
  Mining: gatheringSkill('Mining', {
    description:
      'Breaking stone, ore and soil with a pick or a shovel. Every unit mined or dug grows it; each tier ' +
      'makes mining and digging faster, on top of the tool\'s own speed.',
    goal: 'Record that a player is a miner, apart from the smith who works the ore',
    work: 'mine',
    tierNote: 'a work-speed factor on mining and digging',
  }),

  // ─── Woodcutting ──────────────────────────────────────────────────────────
  Woodcutting: gatheringSkill('Woodcutting', {
    description:
      'Felling trees and cutting wood with an axe. Every unit of wood cut grows it; each tier makes chopping ' +
      'faster, on top of the axe\'s own speed.',
    goal: 'Record that a player is a woodcutter, apart from the carpenter who works the wood',
    work: 'chop',
    tierNote: 'a work-speed factor on chopping',
  }),

  // ─── Foraging ─────────────────────────────────────────────────────────────
  Foraging: gatheringSkill('Foraging', {
    description:
      'Gathering plants, herbs and fruit by hand. Every plant gathered grows it; each tier takes more from ' +
      'the same plant.',
    goal: 'Record that a player is a forager, apart from the alchemist who brews what is found',
    work: 'forage',
    tierNote: 'a yield factor on plants gathered',
  }),

  // ─── Skinning ─────────────────────────────────────────────────────────────
  Skinning: defineEntity({
    tags: ['skill'],
    description:
      'Working a creature body with a knife or bone tool. A higher level takes more from the same body ' +
      '(quantity runs from the table\'s minimum at level 0 to its maximum at the cap), more reliably, ' +
      'and of better quality. It also lets a harvester carry heavier bodies.',
    goal: 'Make a kill a body to work rather than a pile of finished drops, and reward practice with the knife',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: SKILL_TIERS },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required; the same as levelCap', defaultValue: SKINNING.levelCap },
      category: { type: 'enum', values: SKILL_CATEGORIES, defaultValue: 'gathering', description: 'Skill domain: gathering' },
      levelCap:     { type: 'integer', description: 'Highest Skinning level; the tables below have one entry per level 0..levelCap', defaultValue: SKINNING.levelCap },
      xpToLevel:    { type: 'json', description: 'Cumulative XP needed to reach each level, index = level', defaultValue: SKINNING.xpToLevel },
      yieldCurve:   { type: 'json', description: 'Fraction 0..1 of the minQty..maxQty range a harvest reaches, index = effective level', defaultValue: SKINNING.yieldCurve },
      chanceCurve:  { type: 'json', description: 'Chance added to each entry (total capped at 1.0), index = effective level', defaultValue: SKINNING.chanceCurve },
      qualityCurve: { type: 'json', description: 'Quality grade (poor, common, fine, prime) of raw creature materials, index = effective level', defaultValue: SKINNING.qualityCurve },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated skinning XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      harvest: {
        description: 'Work a creature body with the right tool',
        rules: [
          'Effective level is floor(level * tool efficiency); it indexes yieldCurve, chanceCurve and qualityCurve',
          'Quality is a property of the item instance, not a separate item id',
          'A finished harvest grants the Skinning XP of the WorkSkills carcass row',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
