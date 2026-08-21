const { defineEntity, creatureStateMachine, creatureStateValues, dropsData, CREATURE_TIERS, AGGRESSION_LEVELS, CREATURE_STATES, BIOME_KEYS } = require('./shared')

module.exports = {

  // ─── VoidSerpent ──────────────────────────────────────────────────────────
  VoidSerpent: defineEntity({
    tags: ['creature'],
    description:
      'A massive serpentine entity born from void-rift energy given form. ' +
      'Its scales shift between physical and incorporeal, making conventional weapons unreliable. ' +
      'VoidTouched players deal full damage regardless of phase state. ' +
      'Its shed scale fragments are the only material that can line a void-safe container.',
    goal: 'Gate endgame void-zone content behind the VoidTouched profession and team co-ordination',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      state:          { type: 'enum', values: CREATURE_STATES },
      tier:           { type: 'enum', values: CREATURE_TIERS, description: 'Combat difficulty tier; highest tier', defaultValue: '5' },
      aggressionLevel: { type: 'enum', values: AGGRESSION_LEVELS, defaultValue: 'aggressive' },
      baseHp:         { type: 'integer', description: 'Hit points at tier baseline; very high', defaultValue: 800 },
      baseDamage:     { type: 'integer', description: 'Damage per strike at tier baseline; very high', defaultValue: 60 },
      alertRadius:    { type: 'decimal', description: 'Distance in metres at which creature enters alert state', defaultValue: 5.0 },
      attackRadius:   { type: 'decimal', description: 'Distance in metres at which creature begins attacking', defaultValue: 4.0 },
      fleeThreshold:  { type: 'decimal', description: 'HP fraction (0–1) below which creature flees', defaultValue: 0.15 },
      respawnSeconds: { type: 'integer', description: 'Seconds before a dead creature respawns', defaultValue: 3600 },
      spawnCount:     { type: 'integer', description: 'Number of instances spawned per game world', defaultValue: 1 },
      biome:          { type: 'enum', values: BIOME_KEYS, description: 'Biome this creature belongs to', defaultValue: 'VoidRift' },
      drops: dropsData([
        { item: 'void_scale',        chance: 1.0,  minQty: 2, maxQty: 4 },
        { item: 'void_serpent_fang', chance: 1.0,  minQty: 1, maxQty: 1 },
        { item: 'phase_locked_core', chance: 0.25, minQty: 1, maxQty: 1 },
      ]),
    },
    stateMachine: creatureStateMachine({ conditionalAlertSkip: true }),
    behaviors: {
      detect: {
        description: 'Sense void corruption accumulation in nearby players',
        rules: [
          'Detects any player with void corruption above 10 within 20 tiles',
          'Detects any player regardless of stealth within 5 tiles',
          'When corruption threshold is exceeded while idle, fires attack trigger immediately — skips the alert state for this path only',
        ],
        auth: { roles: ['maintainer'] },
      },
      attack: {
        description: 'Void-phase bite and tail sweep combination',
        rules: [
          'Bite: baseDamage + 20 void corruption to target; 50% physical damage reduction applies unless attacker is VoidTouched',
          'Tail sweep: half baseDamage in a 4-tile arc; knocks targets back 2 tiles',
          'Every 3rd attack the serpent fully phases for 2 seconds; all non-magical, non-void attacks pass through harmlessly — VoidTouched players deal full damage regardless',
        ],
        auth: { roles: ['maintainer'] },
      },
      flee: {
        description: 'Retreat into the rift boundary when health drops below 15%',
        rules: [
          'Can only be pursued by players with VoidTouched profession into the rift boundary',
          'Regenerates 10 HP per second inside the rift boundary; cannot be damaged there',
          'Once health is restored, fires attack trigger to re-engage any player still in range',
        ],
        auth: { roles: ['maintainer'] },
      },
      die: {
        description: 'Transition to dead state; void form dissipates and drops materialise',
        rules: ['Death emits a death event; scales and fang solidify from the void form over 3 seconds'],
        auth: { roles: ['maintainer'] },
      },
      drop: {
        description: 'Drop loot on death',
        rules: [
          'Always drops: void serpent scale (2–4), void serpent fang (1)',
          'Chance drop: phase-locked core (25%) — endgame crafting material for void-lined containers',
        ],
        auth: { roles: ['maintainer'] },
      },
      respawn: {
        description: 'Reconstitute from the rift energy after cooldown',
        rules: [
          'Respawn cooldown: 60 in-game minutes',
          'Respawn is blocked if the rift is closed by player action (rare world event)',
        ],
        auth: { roles: ['maintainer'] },
      },
      calm: {
        description: 'Phase back into dormancy at rift edge when threats leave the zone',
        rules: ['Enters dormancy 3 in-game minutes after losing all targets'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RiftWarden ───────────────────────────────────────────────────────────
  RiftWarden: defineEntity({
    tags: ['creature'],
    description:
      'An ancient construct of crystallised voidite that guards the innermost rift boundary. ' +
      'Moves slowly but is virtually immune to physical damage. ' +
      'Warden fragments are the rarest material in the game — a single Warden kill can supply a guild ' +
      'with enough voidite-grade components for weeks.',
    goal: 'Serve as the ultimate endgame encounter; require guild-level preparation and sustained void knowledge',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      state:          { type: 'enum', values: creatureStateValues({ canFlee: false, skipAlert: true }) },
      tier:           { type: 'enum', values: CREATURE_TIERS, description: 'Combat difficulty tier; highest tier', defaultValue: '5' },
      aggressionLevel: { type: 'enum', values: AGGRESSION_LEVELS, defaultValue: 'aggressive' },
      baseHp:         { type: 'integer', description: 'Hit points at tier baseline; extreme value', defaultValue: 2000 },
      baseDamage:     { type: 'integer', description: 'Damage per slam at tier baseline; extreme value', defaultValue: 90 },
      alertRadius:    { type: 'decimal', description: 'Distance in metres at which creature detects and attacks; no alert phase', defaultValue: 20.0 },
      attackRadius:   { type: 'decimal', description: 'Distance in metres at which creature begins attacking', defaultValue: 6.0 },
      fleeThreshold:  { type: 'decimal', description: 'HP fraction (0–1) below which creature flees; 0 = never flees', defaultValue: 0.0 },
      respawnSeconds: { type: 'integer', description: 'Seconds before a dead creature respawns', defaultValue: 7200 },
      spawnCount:     { type: 'integer', description: 'Number of instances spawned per game world; singleton per rift zone', defaultValue: 1 },
      biome:          { type: 'enum', values: BIOME_KEYS, description: 'Biome this creature belongs to', defaultValue: 'VoidRift' },
      drops: dropsData([
        { item: 'rift_shard',        chance: 1.0,  minQty: 4, maxQty: 8 },
        { item: 'void_core_crystal', chance: 1.0,  minQty: 1, maxQty: 1 },
        { item: 'warden_sigil',      chance: 0.05, minQty: 1, maxQty: 1 },
      ]),
    },
    stateMachine: creatureStateMachine({ canFlee: false, skipAlert: true }),
    behaviors: {
      detect: {
        description: 'Detect intrusion into the innermost rift boundary',
        rules: [
          'Detects all players inside the innermost rift boundary zone unconditionally',
          'Cannot be avoided by stealth; rift proximity triggers detection',
          'Fires attack trigger directly from idle — no alert phase',
        ],
        auth: { roles: ['maintainer'] },
      },
      attack: {
        description: 'Ground slam pulse and void beam discharge',
        rules: [
          'Ground slam: baseDamage in 6-tile radius; all targets knocked down (prone for 3 seconds)',
          'Void beam: 3× baseDamage in a straight 10-tile line; also adds 50 void corruption to each target hit',
          'Physical damage reduced by 90%; magical and void damage is fully effective',
          'VoidTouched players receive only 50% corruption from void beam (partial resistance)',
        ],
        auth: { roles: ['maintainer'] },
      },
      die: {
        description: 'Transition to dead state; crystalline body shatters releasing shards',
        rules: ['Death emits a death event; shard fragments scatter in a 4-tile radius and must be individually collected'],
        auth: { roles: ['maintainer'] },
      },
      drop: {
        description: 'Drop loot on death',
        rules: [
          'Always drops: rift warden shard (4–8), void-core crystal (1)',
          'Chance drop: warden sigil (5%) — grants permanent void corruption resistance +25% when carried',
        ],
        auth: { roles: ['maintainer'] },
      },
      respawn: {
        description: 'Reconstitute at the rift core after an extended cooldown',
        rules: [
          'Respawn cooldown: 120 in-game minutes (longest in the game)',
          'Only one Warden instance exists per VoidRift zone; does not multi-spawn',
        ],
        auth: { roles: ['maintainer'] },
      },
      calm: {
        description: 'Return to slow patrol of the innermost boundary',
        rules: ['Returns to idle if all players leave the innermost rift boundary zone'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
