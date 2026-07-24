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

module.exports = {

  // ─── ElementalMagic ───────────────────────────────────────────────────────
  ElementalMagic: defineEntity({
    tags: ['skill'],
    description:
      'Manipulation of the four classical elements — fire, earth, air, and water. ' +
      'The most broadly accessible magical discipline; balanced against martial skill per the ' +
      'MagicBalancedWithMartial design decision.',
    goal: 'Provide the primary magic combat and utility path, balanced against melee in cost and effect',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: magic' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated elemental XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      castElementalBolt: {
        description: 'Hurl a single-element bolt of fire, earth, air, or water at a target',
        rules: ['Requires Elemental Magic: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      castElementalField: {
        description: 'Conjure a persistent area-of-effect field that applies elemental conditions',
        rules: ['Requires Elemental Magic: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      castElementalStorm: {
        description: 'Unleash a wide elemental storm; high mana cost, massive area damage',
        rules: ['Requires Elemental Magic: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── VoidMagic ────────────────────────────────────────────────────────────
  VoidMagic: defineEntity({
    tags: ['skill'],
    description:
      'Channelling of void energy — entropic, corrupting, and capable of bypassing conventional ' +
      'magical resistance. Accessible only to players who have survived void exposure. ' +
      'The only magic school that can bypass veilsteel anti-magic absorption.',
    goal: 'Provide a high-risk, high-reward magic path that counters anti-magic martial builds',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: magic' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated void XP',
        rules: [
          'XP threshold for the target tier must be met',
          'Skill is not tutored — only players with voidBurstSurvivor flag may unlock it',
        ],
        auth: { roles: ['maintainer'] },
      },
      castVoidTendrils: {
        description: 'Reach through the void to grip and corrode a target; bypasses physical armour',
        rules: ['Requires Void Magic: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      castVoidRift: {
        description: 'Tear a localised void rift that disrupts magical items and enchantments in an area',
        rules: ['Requires Void Magic: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      castVoidAnnihilation: {
        description: 'Collapse a void pocket to deal devastation-tier damage; corrupts the caster temporarily',
        rules: ['Requires Void Magic: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RestorationMagic ─────────────────────────────────────────────────────
  RestorationMagic: defineEntity({
    tags: ['skill'],
    description:
      'Healing, shielding, and cleansing magic. Operates on living targets and can purge negative ' +
      'status effects including minor void corruption.',
    goal: 'Enable a support-focused magic path that remains viable without offensive output',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: magic' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated restoration XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      castHeal: {
        description: "Restore a portion of a target's health pool",
        rules: ['Requires Restoration Magic: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      castCleanse: {
        description: 'Remove a negative status effect from a target; removes minor void corruption',
        rules: ['Requires Restoration Magic: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      castRegenerationField: {
        description: 'Create a pulsing area that heals all allies within it each tick',
        rules: ['Requires Restoration Magic: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Enchanting ───────────────────────────────────────────────────────────
  Enchanting: defineEntity({
    tags: ['skill'],
    description:
      'Imbuing refined items and materials with persistent magical effects using aethermite catalysts. ' +
      'Enchanting strength and complexity scale with tier; requires ArcaneForging-produced components.',
    goal: 'Gate item enchantment behind combined magic and crafting investment; make enchanted gear feel earned',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: magic' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated enchanting XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      applyMinorEnchantment: {
        description: 'Bind a simple single-property enchantment to a refined item',
        rules: ['Requires Enchanting: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      applyCompoundEnchantment: {
        description: 'Layer two compatible enchantments onto a single item without cancellation',
        rules: ['Requires Enchanting: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      applyVoidBinding: {
        description: 'Bind a void-aligned enchantment onto a voidite-core item using VoidSmithing co-processing',
        rules: [
          'Requires Enchanting: Expert',
          'Requires Void Smithing: Journeyman',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
