const { defineEntity, skillStateMachine } = require('./shared')

module.exports = {

  // ─── Swordsmanship ────────────────────────────────────────────────────────
  Swordsmanship: defineEntity({
    tags: ['skill'],
    description:
      'Mastery of bladed weapons — from crude ferrite daggers to enchanted veilsteel longswords. ' +
      'Covers footwork, swing mechanics, and dueling composure.',
    goal: 'Gate melee combat power behind practiced investment',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: combat' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated combat XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      executePowerStrike: {
        description: 'Land a heavy blow that deals bonus damage and staggers the target',
        rules: ['Requires Swordsmanship: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      executeCounterSlash: {
        description: 'Exploit an enemy opening after a successful dodge to deal a precision strike',
        rules: ['Requires Swordsmanship: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      executeWhirlwindBlade: {
        description: 'Spin attack hitting all adjacent enemies simultaneously; high stamina cost',
        rules: ['Requires Swordsmanship: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Archery ──────────────────────────────────────────────────────────────
  Archery: defineEntity({
    tags: ['skill'],
    description:
      'Proficiency with bows and crossbows, covering aim stability, draw timing, and trajectory reading. ' +
      'Enables ranged combat, hunting, and siege support.',
    goal: 'Gate ranged combat capability and enable non-combat uses like hunting and signal flares',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: combat' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated ranged XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      executeSteadyShot: {
        description: 'Hold breath to eliminate aim sway for a precise single shot',
        rules: ['Requires Archery: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      executeMultiShot: {
        description: 'Loose three arrows in rapid succession at the same target',
        rules: ['Requires Archery: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      executePierceShot: {
        description: 'Fire a hardened-tip arrow that penetrates armor and hits the target behind',
        rules: ['Requires Archery: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Shieldcraft ──────────────────────────────────────────────────────────
  Shieldcraft: defineEntity({
    tags: ['skill'],
    description:
      'Techniques for using a shield offensively and defensively — blocking, parrying, bashing, and ' +
      'forming protective stances. Works with any shield material.',
    goal: 'Reward dedicated defenders and create a viable tank archetype',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: combat' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated defensive XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      executeParry: {
        description: 'Time a block precisely to deflect an attack and create a counterattack window',
        rules: ['Requires Shieldcraft: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      executeShieldBash: {
        description: 'Strike with the shield to stun a target briefly and break their combo',
        rules: ['Requires Shieldcraft: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      activateFortify: {
        description: 'Enter a rooted defensive stance that dramatically reduces incoming damage',
        rules: ['Requires Shieldcraft: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Unarmed ──────────────────────────────────────────────────────────────
  Unarmed: defineEntity({
    tags: ['skill'],
    description:
      'Hand-to-hand fighting techniques including strikes, grapples, and throws. ' +
      'Effective for disarming opponents and operating in no-weapon zones.',
    goal: 'Provide a no-equipment combat path and enable creature-taming interactions',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: combat' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated close-combat XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      executeDisarm: {
        description: 'Strike the weapon arm to force an enemy to drop their equipped weapon',
        rules: ['Requires Unarmed: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      executeGrapple: {
        description: 'Seize a target and pin them, preventing movement for several seconds',
        rules: ['Requires Unarmed: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      executeKnockdown: {
        description: 'Throw a target to the ground, leaving them prone and vulnerable',
        rules: ['Requires Unarmed: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
