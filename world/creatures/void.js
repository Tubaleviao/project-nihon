const { defineEntity, creatureStateMachine, CREATURE_TIERS, AGGRESSION_LEVELS } = require('./shared')

module.exports = {

  // ─── VoidSerpent ──────────────────────────────────────────────────────────
  VoidSerpent: defineEntity({
    tags: ['creature'],
    description:
      'A massive serpentine entity born from void-rift energy given form. ' +
      'Its scales shift between physical and incorporeal, making conventional weapons unreliable. ' +
      'Void-touched players deal full damage regardless of phase state. ' +
      'Its shed scale fragments are the only material that can line a void-safe container.',
    goal: 'Gate endgame void-zone content behind the VoidTouched profession and team co-ordination',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      state:          { type: 'enum', values: ['idle', 'alert', 'aggressive', 'fleeing', 'dead', 'respawning'] },
      tier:           { type: 'enum', values: CREATURE_TIERS, description: 'Combat difficulty tier; highest tier' },
      aggressionLevel: { type: 'enum', values: AGGRESSION_LEVELS },
      baseHp:         { type: 'integer', description: 'Hit points at tier baseline; very high' },
      baseDamage:     { type: 'integer', description: 'Damage per strike at tier baseline; very high' },
    },
    stateMachine: creatureStateMachine(),
    behaviors: {
      detect: {
        description: 'Sense void corruption accumulation in nearby players',
        rules: [
          'Detects any player with void corruption above 10 within 20 tiles',
          'Detects any player regardless of stealth within 5 tiles',
          'Aggression is immediate — no alert phase when corruption threshold is exceeded',
        ],
        auth: { roles: ['maintainer'] },
      },
      attack: {
        description: 'Void-phase bite and tail sweep combination',
        rules: [
          'Bite: baseDamage + 20 void corruption to target; 50% physical damage reduction applies unless attacker is VoidTouched',
          'Tail sweep: half baseDamage in a 4-tile arc; knocks targets back 2 tiles',
          'Every 3rd attack the serpent fully phases; all non-magical, non-void attacks pass through harmlessly for 2 seconds',
        ],
        auth: { roles: ['maintainer'] },
      },
      flee: {
        description: 'Retreat into the rift boundary when health drops below 15%',
        rules: [
          'Can only be pursued by players with VoidTouched profession into the rift boundary',
          'Regenerates 10 HP per second inside the rift boundary; cannot be damaged there',
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
      state:          { type: 'enum', values: ['idle', 'alert', 'aggressive', 'fleeing', 'dead', 'respawning'] },
      tier:           { type: 'enum', values: CREATURE_TIERS, description: 'Combat difficulty tier; highest tier' },
      aggressionLevel: { type: 'enum', values: AGGRESSION_LEVELS },
      baseHp:         { type: 'integer', description: 'Hit points at tier baseline; extreme value' },
      baseDamage:     { type: 'integer', description: 'Damage per slam at tier baseline; extreme value' },
    },
    stateMachine: creatureStateMachine(),
    behaviors: {
      detect: {
        description: 'Detect intrusion into the innermost rift boundary',
        rules: [
          'Detects all players inside the innermost rift boundary zone unconditionally',
          'Cannot be avoided by stealth; rift proximity triggers detection',
          'Immediately transitions to aggressive — no alert phase',
        ],
        auth: { roles: ['maintainer'] },
      },
      attack: {
        description: 'Ground slam pulse and void beam discharge',
        rules: [
          'Ground slam: baseDamage in 6-tile radius; all targets knocked prone for 3 seconds',
          'Void beam: 3× baseDamage in a straight 10-tile line; also adds 50 void corruption to each target hit',
          'Physical damage reduced by 90%; magical and void damage is fully effective',
          'VoidTouched players receive only 50% corruption from void beam (partial resistance)',
        ],
        auth: { roles: ['maintainer'] },
      },
      flee: {
        description: 'The Warden does not flee',
        rules: ['Does not transition to fleeing state under any circumstances; fights to dead state'],
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
