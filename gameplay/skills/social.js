const { defineEntity, skillStateMachine } = require('./shared')

module.exports = {

  // ─── Diplomacy ────────────────────────────────────────────────────────────
  Diplomacy: defineEntity({
    tags: ['skill'],
    description:
      'Negotiating with NPC factions, guilds, and governing bodies to obtain favourable terms, ' +
      'treaties, or permissions. Does not work on players — only system-driven entities.',
    goal: 'Gate faction interaction quality behind investment; make non-combat paths viable for territory acquisition',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: social' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated diplomacy XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      negotiateTrade: {
        description: 'Broker a favourable trade agreement with an NPC faction',
        rules: ['Requires Diplomacy: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      proposeTreaty: {
        description: 'Submit a formal treaty proposal to an NPC faction for ratification',
        rules: ['Requires Diplomacy: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      requestTerritoryCession: {
        description: 'Petition an NPC faction to yield a land grant in exchange for services or payment',
        rules: ['Requires Diplomacy: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Trade ────────────────────────────────────────────────────────────────
  Trade: defineEntity({
    tags: ['skill'],
    description:
      'Commercial acumen that improves buy/sell spreads with NPC vendors and enables merchant-tier ' +
      'operations like bulk deals, consignment, and market stalls.',
    goal: 'Reward commercial specialisation; make player economy roles viable and distinct from combat roles',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: social' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated trade XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      operateMarketStall: {
        description: 'Set up a persistent player-run market stall at a settlement location',
        rules: ['Requires Trade: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      executeBulkDeal: {
        description: 'Negotiate a high-volume transaction with an NPC faction at reduced unit price',
        rules: ['Requires Trade: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      establishConsignment: {
        description: 'Place goods with an NPC vendor on commission; vendor sells while player is offline',
        rules: ['Requires Trade: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Speechcraft ──────────────────────────────────────────────────────────
  Speechcraft: defineEntity({
    tags: ['skill'],
    description:
      'Persuasion, intimidation, and deception aimed at NPC targets. ' +
      'Can unlock hidden dialogue options, reduce hostility, or extract information from NPCs.',
    goal: 'Enable a social manipulation path; prevent combat from being the only solution to NPC obstacles',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: social' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated speechcraft XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      convinceNpc: {
        description: 'Persuade an NPC to comply with a request using reasoned argument',
        rules: ['Requires Speechcraft: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      intimidateNpc: {
        description: 'Compel an NPC through veiled or direct threat; risks reputation damage on failure',
        rules: ['Requires Speechcraft: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      deceiveNpc: {
        description: 'Plant false information with an NPC to redirect their behaviour',
        rules: ['Requires Speechcraft: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Leadership ───────────────────────────────────────────────────────────
  Leadership: defineEntity({
    tags: ['skill'],
    description:
      'Inspiring and coordinating allies in combat and in civic roles. ' +
      'Grants persistent aura buffs to nearby party members and unlocks group command actions.',
    goal: 'Create a dedicated support-combat role that scales with group size',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: social' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated leadership XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      rallyParty: {
        description: 'Issue a rally call that temporarily boosts movement speed for all nearby allies',
        rules: ['Requires Leadership: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      commandFormation: {
        description: 'Position up to 10 allies in a combat formation granting a shared defensive bonus',
        rules: ['Requires Leadership: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      inspireBreakthrough: {
        description: 'Deliver a rallying speech before a siege or major battle; grants all participants a temporary combat buff',
        rules: ['Requires Leadership: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
