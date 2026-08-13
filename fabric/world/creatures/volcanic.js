const { defineEntity, creatureStateMachine, CREATURE_TIERS, AGGRESSION_LEVELS, CREATURE_STATES } = require('./shared')

module.exports = {

  // ─── LavaSlug ─────────────────────────────────────────────────────────────
  LavaSlug: defineEntity({
    tags: ['creature'],
    description:
      'A slow-moving, magma-encrusted slug the size of a cart horse that grazes on ashite mineral deposits. ' +
      'Its exterior is inert cooled lava; it secretes superheated slime as a defence mechanism. ' +
      'A reliable source of mineral-rich slug shell shards used in high-temperature forge linings.',
    goal: 'Teach players to respect environmental hazards; reward patience over aggression',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      state:          { type: 'enum', values: CREATURE_STATES },
      tier:           { type: 'enum', values: CREATURE_TIERS, description: 'Combat difficulty tier', defaultValue: '3' },
      aggressionLevel: { type: 'enum', values: AGGRESSION_LEVELS, defaultValue: 'neutral' },
      baseHp:         { type: 'integer', description: 'Hit points at tier baseline; very high due to shell armour', defaultValue: 350 },
      baseDamage:     { type: 'integer', description: 'Damage per slime spray at tier baseline', defaultValue: 20 },
    },
    stateMachine: creatureStateMachine(),
    behaviors: {
      detect: {
        description: 'Sense vibration and heat-signature through the ground',
        rules: [
          'Detection range: 6 tiles via ground vibration; 3 tiles via direct contact',
          'Immune to sound-based detection suppression',
        ],
        auth: { roles: ['maintainer'] },
      },
      attack: {
        description: 'Spray superheated slime in a 3-tile cone',
        rules: [
          'Slime applies a heat-burn status: 5 damage per second for 8 seconds',
          'Hit players wearing non-ashite armour take 1.5× damage from burn',
          'Slime coats the ground; affected tiles are impassable without fire resistance for 30 seconds',
        ],
        auth: { roles: ['maintainer'] },
      },
      flee: {
        description: 'Retreat into a lava pool or rock crevice',
        rules: [
          'Flees only if health drops below 10%; very slow movement speed',
          'Cannot be followed into lava pools',
        ],
        auth: { roles: ['maintainer'] },
      },
      die: {
        description: 'Transition to dead state; shell cracks open revealing harvestable drops',
        rules: ['Death emits a death event; shell shards are scattered in a 2-tile radius'],
        auth: { roles: ['maintainer'] },
      },
      drop: {
        description: 'Drop loot on death',
        rules: [
          'Always drops: slug shell shard (2–4), superheated slime vial (1–2)',
          'Chance drop: lava-core organ (15%) — required for master-forge insulation recipes',
        ],
        auth: { roles: ['maintainer'] },
      },
      respawn: {
        description: 'Regenerate from a lava pool spawn point after cooldown',
        rules: ['Respawn cooldown: 25 in-game minutes; spawns submerged in lava and surfaces after 30 seconds'],
        auth: { roles: ['maintainer'] },
      },
      calm: {
        description: 'Resume ashite grazing after threat passes',
        rules: ['Returns to idle 20 seconds after losing target'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── CinderGargoyle ───────────────────────────────────────────────────────
  CinderGargoyle: defineEntity({
    tags: ['creature'],
    description:
      'A winged, stone-skinned predator that nests in volcanic caldera walls. ' +
      'Awakens and hunts during eruption events when ashite formations shift. ' +
      'Its petrified wing fragments are the only known source of heat-stable binding agent ' +
      'for high-tier forge construction.',
    goal: 'Gate high-tier volcanic resources behind a skilled aerial combat challenge',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      state:          { type: 'enum', values: CREATURE_STATES },
      tier:           { type: 'enum', values: CREATURE_TIERS, description: 'Combat difficulty tier', defaultValue: '4' },
      aggressionLevel: { type: 'enum', values: AGGRESSION_LEVELS, defaultValue: 'aggressive' },
      baseHp:         { type: 'integer', description: 'Hit points at tier baseline', defaultValue: 280 },
      baseDamage:     { type: 'integer', description: 'Damage per claw strike at tier baseline', defaultValue: 35 },
    },
    stateMachine: creatureStateMachine(),
    behaviors: {
      detect: {
        description: 'Wake from stone dormancy when eruption event begins or player enters caldera',
        rules: [
          'Dormant during non-eruption periods; spawn weight increases 3× during eruption events',
          'Detects any player within 15 tiles once active',
        ],
        auth: { roles: ['maintainer'] },
      },
      attack: {
        description: 'Dive-claw attack followed by a cinder-breath burst',
        rules: [
          'Claw strike deals baseDamage; knocks target prone for 2 seconds',
          'Cinder breath: 2× baseDamage in a 4-tile cone; ignites wooden structures on contact',
          'Alternates between claw and breath; cannot use breath while airborne',
        ],
        auth: { roles: ['maintainer'] },
      },
      flee: {
        description: 'Retreat to caldera interior when health drops below 20%',
        rules: [
          'Flies directly to the nearest caldera wall crevice',
          'Regenerates 5 HP per second while roosted in caldera; cannot be targeted while in crevice',
        ],
        auth: { roles: ['maintainer'] },
      },
      die: {
        description: 'Transition to dead state; stone body crumbles releasing drops',
        rules: ['Death emits a death event; body crumbles over 5 seconds — loot available after crumble animation'],
        auth: { roles: ['maintainer'] },
      },
      drop: {
        description: 'Drop loot on death',
        rules: [
          'Always drops: cinder gargoyle wing fragment (1–2), petrified binding stone (1)',
          'Chance drop: gargoyle crest (10%) — rare cosmetic component',
        ],
        auth: { roles: ['maintainer'] },
      },
      respawn: {
        description: 'Respawn in caldera dormancy after cooldown',
        rules: [
          'Respawn cooldown: 40 in-game minutes',
          'Spawns dormant; only activates on next eruption or player proximity trigger',
        ],
        auth: { roles: ['maintainer'] },
      },
      calm: {
        description: 'Return to stone dormancy when threat leaves the caldera zone',
        rules: ['Re-enters dormancy 5 in-game minutes after losing target if no eruption is active'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
