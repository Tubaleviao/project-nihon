const { defineEntity, skillStateMachine, SKILL_TIERS, SKILL_CATEGORIES } = require('./shared')
const { SKINNING } = require('../harvest')

module.exports = {

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
      category: { type: 'enum', values: SKILL_CATEGORIES, defaultValue: 'survival', description: 'Skill domain: survival' },
      levelCap:     { type: 'integer', description: 'Highest Skinning level; the tables below have one entry per level 0..levelCap', defaultValue: SKINNING.levelCap },
      xpPerHarvest: { type: 'integer', description: 'Skinning XP a finished harvest grants', defaultValue: SKINNING.xpPerHarvest },
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
          'A finished harvest grants xpPerHarvest',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
