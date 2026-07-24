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

  // ─── Cartography ──────────────────────────────────────────────────────────
  Cartography: defineEntity({
    tags: ['skill'],
    description:
      'Charting unexplored territories and producing maps that can be sold or shared with other players. ' +
      'Higher tiers reveal elevation, resource deposits, and ley-line positions.',
    goal: 'Make exploration economically meaningful and create a player-driven cartography market',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: exploration' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated cartography XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      draftBasicMap: {
        description: 'Produce a surface terrain map of a visited region from field notes',
        rules: ['Requires Cartography: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      draftResourceMap: {
        description: 'Overlay a resource deposit layer showing material vein locations',
        rules: ['Requires Cartography: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      draftLeylineMap: {
        description: 'Chart ley-line positions and arcane anomalies invisible to untrained eyes',
        rules: ['Requires Cartography: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Tracking ─────────────────────────────────────────────────────────────
  Tracking: defineEntity({
    tags: ['skill'],
    description:
      'Reading environmental signs — footprints, disturbed foliage, scent trails — to follow ' +
      'creatures or players across terrain. Higher tiers identify creature type, size, and age of trail.',
    goal: 'Enable hunting professions and make the world feel inhabited and readable',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: exploration' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated tracking XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      identifyTrail: {
        description: 'Determine the species and rough size of a creature from tracks',
        rules: ['Requires Tracking: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      ageTrail: {
        description: 'Estimate how recently a trail was made to determine whether prey is near',
        rules: ['Requires Tracking: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      detectConcealedTrail: {
        description: 'Uncover Stealth-obscured movement trails left by other players',
        rules: ['Requires Tracking: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Stealth ──────────────────────────────────────────────────────────────
  Stealth: defineEntity({
    tags: ['skill'],
    description:
      'Moving, hiding, and acting without detection. Affects footstep volume, trail signature, and ' +
      'enemy detection radius. Higher tiers enable sustained stealth while performing actions.',
    goal: 'Create a viable non-combat exploration and infiltration path',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: exploration' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated stealth XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      activateCrouchHide: {
        description: 'Enter a stationary hiding state that reduces detection radius significantly',
        rules: ['Requires Stealth: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      activateShadowMove: {
        description: 'Move at half speed while remaining hidden — trail signature is fully suppressed',
        rules: ['Requires Stealth: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      executeSilentAction: {
        description: 'Perform an interaction — opening a container, looting — without breaking stealth',
        rules: ['Requires Stealth: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Navigation ───────────────────────────────────────────────────────────
  Navigation: defineEntity({
    tags: ['skill'],
    description:
      'Wayfinding without landmarks using stars, moss growth, wind direction, and terrain features. ' +
      'Reduces travel time penalties in unmapped regions and enables leading groups efficiently.',
    goal: 'Make geography meaningful by rewarding players who invest in spatial knowledge',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: ['novice', 'apprentice', 'journeyman', 'expert', 'master'] },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'string', description: 'Skill domain: exploration' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated navigation XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      orientByStars: {
        description: 'Determine cardinal direction and rough position from night-sky observations',
        rules: ['Requires Navigation: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      plotOverlandRoute: {
        description: 'Plan an efficient multi-biome route that avoids hazards and minimises travel time',
        rules: ['Requires Navigation: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      leadExpedition: {
        description: 'Guide a group of up to 10 players through unmapped terrain without travel penalty',
        rules: ['Requires Navigation: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
