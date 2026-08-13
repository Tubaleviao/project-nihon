const { defineEntity, RARITIES, DURABILITY_STATES, itemStateMachine, consumableStateMachine } = require('./shared')

module.exports = {

  // ─── FerriteIngot ─────────────────────────────────────────────────────────
  FerriteIngot: defineEntity({
    tags: ['item'],
    description:
      'Smelted ferrite bar ready for smithing. The most common crafting intermediate; ' +
      'used in tools, weapons, armour, and as a construction material for forges and workshops.',
    goal: 'Backbone crafting component; drives early-game trade and material loops',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg per ingot', defaultValue: 1.0 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'common' },
      stackable: { type: 'boolean', description: 'True; stacks up to 50 per slot', defaultValue: true },
      durability: { type: 'integer', description: 'Structural integrity; degrades only under deliberate stress', defaultValue: 200 },
    },
    relations: {
      ferrite: { name: 'ferrite', kind: 'hasOne', target: 'Ferrite' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Ingot degrades only when used as a structural load-bearing component in a damaged building',
        rules: ['Normal inventory storage never degrades an ingot'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Re-smelt a degraded ingot back to pristine quality',
        rules: ['Requires a forge; no additional materials consumed'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── ThornwoodPlank ───────────────────────────────────────────────────────
  ThornwoodPlank: defineEntity({
    tags: ['item'],
    description:
      'Rough-cut plank milled from thornwood logs. Primary construction and crafting lumber; ' +
      'used in furniture, workshop frames, bows, handles, and basic structures.',
    goal: 'Primary wood component; creates a lumber supply chain from Temperate Forest biomes',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg per plank', defaultValue: 0.7 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'common' },
      stackable: { type: 'boolean', description: 'True; stacks up to 30 per slot', defaultValue: true },
      durability: { type: 'integer', description: 'Structural integrity', defaultValue: 150 },
    },
    relations: {
      thornwood: { name: 'thornwood', kind: 'hasOne', target: 'Thornwood' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Plank degrades when exposed to rain without shelter or used in a damaged structure',
        rules: ['Planks stored indoors or in a covered workshop do not degrade'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Plane and re-treat warped planks at a carpentry bench',
        rules: ['Requires Carpentry: Novice; no additional materials consumed'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── AethermiteDust ───────────────────────────────────────────────────────
  AethermiteDust: defineEntity({
    tags: ['item'],
    description:
      'Fine powder ground from raw aethermite ore at an arcane forge. ' +
      'Used as an enchanting reagent and in potion brewing; the ground form is not interchangeable with shards.',
    goal: 'Lower-cost alchemical reagent derived from aethermite; drives arcane crafting economy',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg per unit', defaultValue: 0.02 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'uncommon' },
      stackable: { type: 'boolean', description: 'True; stacks up to 99 per slot', defaultValue: true },
      durability: { type: 'integer', description: 'Magical potency; dissipates if stored poorly', defaultValue: 80 },
    },
    relations: {
      aethermite: { name: 'aethermite', kind: 'hasOne', target: 'Aethermite' },
    },
    stateMachine: consumableStateMachine(),
    behaviors: {
      degrade: {
        description: 'Potency dissipates if stored without magical containment',
        rules: ['Stored in an enchanted container: no degradation; exposed to open air: degrades one tier per in-game week'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── VeilsteelIngot ───────────────────────────────────────────────────────
  VeilsteelIngot: defineEntity({
    tags: ['item'],
    description:
      'Refined veilsteel bar alloyed in a master forge from ferrite ingots and an aethermite shard. ' +
      'The intermediate material required for all mid-tier veilsteel weapons and armour.',
    goal: 'Mid-tier crafting component; creates a material processing step before veilsteel gear can be produced',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg per ingot', defaultValue: 1.4 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'uncommon' },
      stackable: { type: 'boolean', description: 'True; stacks up to 30 per slot', defaultValue: true },
      durability: { type: 'integer', description: 'Structural integrity; degrades only under deliberate stress', defaultValue: 200 },
    },
    relations: {
      veilsteel: { name: 'veilsteel', kind: 'hasOne', target: 'Veilsteel' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Ingot degrades only when used as a structural load-bearing component in a damaged building',
        rules: ['Normal inventory storage never degrades an ingot'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Re-smelt a degraded ingot back to pristine quality at a master forge',
        rules: ['Requires a master forge; no additional materials consumed'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── AethermiteShard ──────────────────────────────────────────────────────
  AethermiteShard: defineEntity({
    tags: ['item'],
    description:
      'Raw aethermite refined into a crystalline shard at an arcane forge. ' +
      'The solid form of processed aethermite; used as a smithing input for veilsteel alloying. ' +
      'Not interchangeable with aethermite dust — the shard form retains structural integrity under forge heat.',
    goal: 'Discrete shard form of refined aethermite; unambiguous input for the veilsteel alloying recipe',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg per shard', defaultValue: 0.08 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'uncommon' },
      stackable: { type: 'boolean', description: 'True; stacks up to 20 per slot', defaultValue: true },
      durability: { type: 'integer', description: 'Crystal integrity; shatters under standard forge temperatures — must be processed in an arcane forge', defaultValue: 60 },
    },
    relations: {
      aethermite: { name: 'aethermite', kind: 'hasOne', target: 'Aethermite' },
    },
    stateMachine: consumableStateMachine(),
    behaviors: {
      degrade: {
        description: 'Shard integrity degrades under non-magical heat exposure',
        rules: ['Stored in a standard forge area: degrades one tier per in-game day; safe in arcane storage'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── AshiteBlock ──────────────────────────────────────────────────────────
  AshiteBlock: defineEntity({
    tags: ['item'],
    description:
      'Quarried ashite stone block cut to standard building dimensions. ' +
      'Dense volcanic stone; excellent heat resistance makes it the preferred material for forges, ' +
      'furnaces, and firebreak walls.',
    goal: 'Construction component from volcanic biomes; creates supply dependency between biome specialists',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg per block', defaultValue: 3.5 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'common' },
      stackable: { type: 'boolean', description: 'True; stacks up to 20 per slot', defaultValue: true },
      durability: { type: 'integer', description: 'Structural integrity', defaultValue: 300 },
    },
    relations: {
      ashite: { name: 'ashite', kind: 'hasOne', target: 'Ashite' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Ashite blocks degrade only under siege weapon impact or prolonged void exposure',
        rules: ['Normal use never degrades an ashite block'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Chip-fill damaged blocks with ashite mortar at a masonry bench',
        rules: ['Requires Carpentry: Apprentice; ashite mortar (aethermite dust + ashite powder) consumed'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
