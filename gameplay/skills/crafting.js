const { defineEntity, skillStateMachine, SKILL_TIERS } = require('./shared')

module.exports = {

  // ─── Smithing ─────────────────────────────────────────────────────────────
  Smithing: defineEntity({
    tags: ['skill'],
    description:
      'Metalworking at a forge — shaping ingots into weapons, armor, and structural components. ' +
      'Covers hammer technique, heat management, and alloy timing. ' +
      'Required for ferrite tools early-game and veilsteel gear mid-game.',
    goal: 'Gate weapon and armor quality behind craft investment; make forges worth building',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: SKILL_TIERS },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'enum', values: ['combat', 'crafting', 'magic', 'exploration', 'social'], description: 'Skill domain: crafting' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated smithing XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      craftBasicWeapon: {
        description: 'Forge a basic ferrite tool or weapon at a standard forge',
        rules: ['Requires Smithing: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      craftAlloyIngot: {
        description: 'Produce a veilsteel ingot by alloying ferrite and aethermite in a master forge',
        rules: ['Requires Smithing: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      craftMasterwork: {
        description: 'Apply masterwork techniques to improve item base stats beyond standard rolls',
        rules: ['Requires Smithing: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Carpentry ────────────────────────────────────────────────────────────
  Carpentry: defineEntity({
    tags: ['skill'],
    description:
      'Working with Thornwood, Duskfiber, and other woody materials to craft furniture, ' +
      'structural building components, hafts, bows, and vehicles.',
    goal: 'Gate construction quality and wooden equipment crafting behind dedicated investment',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: SKILL_TIERS },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'enum', values: ['combat', 'crafting', 'magic', 'exploration', 'social'], description: 'Skill domain: crafting' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated carpentry XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      craftBuildingFrame: {
        description: 'Assemble load-bearing wooden frames for player structures',
        rules: ['Requires Carpentry: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      craftVehicleComponent: {
        description: 'Build wagon chassis, ship hulls, or cart frames from seasoned timber',
        rules: ['Requires Carpentry: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      craftDuskfiberLoom: {
        description: 'Construct a Duskfiber processing loom for weaving magical textiles',
        rules: ['Requires Carpentry: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Alchemy ──────────────────────────────────────────────────────────────
  Alchemy: defineEntity({
    tags: ['skill'],
    description:
      'Brewing potions, reagents, poisons, and catalysts from raw materials. ' +
      'Discovery-driven: recipes are not shown until a player experiments with ingredient combinations.',
    goal: 'Gate consumable power and support ArcaneForging through reagent supply; reward experimentation',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: SKILL_TIERS },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'enum', values: ['combat', 'crafting', 'magic', 'exploration', 'social'], description: 'Skill domain: crafting' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated alchemy XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      brewBasicPotion: {
        description: 'Produce a minor healing or stamina potion from common reagents',
        rules: ['Requires Alchemy: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      brewEnchantmentCatalyst: {
        description: 'Synthesise a magical catalyst used by ArcaneForging to stabilise enchantments',
        rules: ['Requires Alchemy: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      brewVoidReagent: {
        description: 'Distil void-touched materials into a stabilising reagent for void smithing',
        rules: ['Requires Alchemy: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── ArcaneForging ────────────────────────────────────────────────────────
  ArcaneForging: defineEntity({
    tags: ['skill'],
    description:
      'Specialized metalworking at arcane forges that processes magical materials — primarily ' +
      'Aethermite — which shatter in standard forges. ' +
      'Prerequisite for all enchanted material production and catalyst crafting.',
    goal: 'Gate magical material processing behind dedicated study; makes arcane forges economically critical',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: SKILL_TIERS },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'enum', values: ['combat', 'crafting', 'magic', 'exploration', 'social'], description: 'Skill domain: crafting' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated arcane forging XP',
        rules: ['XP threshold for the target tier must be met'],
        auth: { roles: ['maintainer'] },
      },
      refineAethermite: {
        description: 'Process raw aethermite into dust or shards at an arcane forge without shattering it',
        rules: ['Requires Arcane Forging: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      craftArcaneComponent: {
        description: 'Produce enchanted components used in magical item assembly',
        rules: ['Requires Arcane Forging: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      craftArcaneForgeUpgrade: {
        description: 'Install structural upgrades to an existing arcane forge to raise its tier',
        rules: ['Requires Arcane Forging: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── VoidSmithing ─────────────────────────────────────────────────────────
  VoidSmithing: defineEntity({
    tags: ['skill'],
    description:
      'Esoteric art of working with void-touched materials, primarily Voidite, inside a specially ' +
      'shielded forge room. Cannot be taught — must be discovered through experimentation. ' +
      'A player who survives a void burst during Voidite refining may unlock this skill.',
    goal: 'Act as the highest-tier crafting gate, accessible only to players who survive void exposure',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      tier:     { type: 'enum', values: SKILL_TIERS },
      xpCurve:  { type: 'enum', values: ['linear', 'quadratic', 'exponential'], description: 'XP required per tier' },
      maxLevel: { type: 'integer', description: 'Maximum XP level within a tier before tier advance is required' },
      category: { type: 'enum', values: ['combat', 'crafting', 'magic', 'exploration', 'social'], description: 'Skill domain: crafting' },
    },
    stateMachine: skillStateMachine(),
    behaviors: {
      advanceTier: {
        description: 'Progress to the next mastery tier through accumulated void smithing XP',
        rules: [
          'XP threshold for the target tier must be met',
          'Skill is not tutored — only players with voidBurstSurvivor flag may unlock it',
        ],
        auth: { roles: ['maintainer'] },
      },
      constructShieldedForge: {
        description: 'Build or upgrade a void-shielded forge room that safely contains void energy during smithing',
        rules: ['Requires Void Smithing: Apprentice'],
        auth: { roles: ['maintainer'] },
      },
      refineVoidite: {
        description: 'Stabilise raw voidite in a shielded forge; failure may cause a void burst',
        rules: ['Requires Void Smithing: Journeyman'],
        auth: { roles: ['maintainer'] },
      },
      craftVoidlinedContainer: {
        description: 'Produce storage containers with void-lining required to safely carry enchanted voidite',
        rules: ['Requires Void Smithing: Expert'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
