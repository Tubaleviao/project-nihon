const { defineEntity, creatureStateMachine, CREATURE_TIERS, AGGRESSION_LEVELS, CREATURE_STATES, BIOME_KEYS } = require('./shared')

module.exports = {

  // ─── GlimmerFox ───────────────────────────────────────────────────────────
  GlimmerFox: defineEntity({
    tags: ['creature'],
    description:
      'A sleek, luminescent fox native to the Twilight Grove whose fur shifts in hue with the accelerated ' +
      'day-night cycle. Inherently curious and non-aggressive; actively approaches players carrying food. ' +
      'Its shed fur is harvested as a raw alchemical reagent that intensifies potion luminosity.',
    goal: 'Reward exploration and peaceful interaction; provide an alchemy reagent that does not require killing',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      state:          { type: 'enum', values: CREATURE_STATES },
      tier:           { type: 'enum', values: CREATURE_TIERS, description: 'Combat difficulty tier', defaultValue: '1' },
      aggressionLevel: { type: 'enum', values: AGGRESSION_LEVELS, defaultValue: 'passive' },
      baseHp:         { type: 'integer', description: 'Hit points at tier baseline; low', defaultValue: 20 },
      baseDamage:     { type: 'integer', description: 'Damage per nip at tier baseline; minimal', defaultValue: 2 },
      alertRadius:    { type: 'decimal', description: 'Distance in metres at which creature enters alert state', defaultValue: 8.0 },
      attackRadius:   { type: 'decimal', description: 'Distance in metres at which creature begins attacking', defaultValue: 3.0 },
      fleeThreshold:  { type: 'decimal', description: 'HP fraction (0–1) below which creature flees; flees on weapon detect', defaultValue: 1.0 },
      respawnSeconds: { type: 'integer', description: 'Seconds before a dead creature respawns', defaultValue: 480 },
      spawnCount:     { type: 'integer', description: 'Number of instances spawned per game world', defaultValue: 2 },
      biome:          { type: 'enum', values: BIOME_KEYS, description: 'Biome this creature belongs to', defaultValue: 'TwilightGrove' },
    },
    stateMachine: creatureStateMachine(),
    behaviors: {
      detect: {
        description: 'Sense light changes and player presence; approach if food is detected',
        rules: [
          'Approaches players within 8 tiles who carry food items',
          'Flees from players carrying drawn weapons',
          'Reacts to sudden day-night cycle shifts by briefly freezing, then resuming patrol',
        ],
        auth: { roles: ['maintainer'] },
      },
      attack: {
        description: 'Nip defensively when cornered',
        rules: [
          'Only attacks when cornered (no escape path available)',
          'Nip deals 1× baseDamage; immediately flees after attacking',
        ],
        auth: { roles: ['maintainer'] },
      },
      flee: {
        description: 'Dart into the undergrowth when threatened',
        rules: [
          'On detecting a drawn weapon within 6 tiles: transitions idle → alert → fleeing immediately (skips aggressive)',
          'Extremely fast; outruns players without Tracking: Journeyman',
        ],
        auth: { roles: ['maintainer'] },
      },
      die: {
        description: 'Transition to dead state; trigger loot drop and start respawn timer',
        rules: ['Death emits a death event; loot appears at the fox\'s location'],
        auth: { roles: ['maintainer'] },
      },
      drop: {
        description: 'Drop loot on death (or shed fur via tame interaction)',
        rules: [
          'On death: glimmer fox pelt (1), trace luminescent reagent (1)',
          'Via tame (feeding): sheds glimmer fur tuft (1) without dying; 10-minute cooldown per fox',
        ],
        auth: { roles: ['maintainer'] },
      },
      tame: {
        description: 'Feed the fox to harvest shed fur without harming it',
        rules: [
          'Requires Alchemy: Apprentice to recognise the reagent value',
          'Player must offer field rations or raw meat while unarmed',
          'Fox remains alive; cooldown applies before it can be fed again',
        ],
        auth: { roles: ['maintainer'] },
      },
      respawn: {
        description: 'Respawn at a grove spawn point after cooldown',
        rules: ['Respawn cooldown: 8 in-game minutes; ignores respawn if tamed instance is still alive in the tile'],
        auth: { roles: ['maintainer'] },
      },
      calm: {
        description: 'Return to patrol pattern after threat passes',
        rules: ['Returns to idle 10 seconds after threat leaves detection range'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── VeilStalker ──────────────────────────────────────────────────────────
  VeilStalker: defineEntity({
    tags: ['creature'],
    description:
      'A lithe, shadowy predator that phases in and out of visibility in sync with the Twilight Grove\'s ' +
      'erratic light cycle. Hunts in silence, telegraphing its attack only by a brief luminescent pulse. ' +
      'Highly prized by alchemists — its venom is the base for the most potent paralytic compounds.',
    goal: 'Challenge experienced players with a visibility-mechanic fight and reward knowledge-based preparation',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      state:          { type: 'enum', values: CREATURE_STATES },
      tier:           { type: 'enum', values: CREATURE_TIERS, description: 'Combat difficulty tier', defaultValue: '3' },
      aggressionLevel: { type: 'enum', values: AGGRESSION_LEVELS, defaultValue: 'aggressive' },
      baseHp:         { type: 'integer', description: 'Hit points at tier baseline', defaultValue: 150 },
      baseDamage:     { type: 'integer', description: 'Damage per strike at tier baseline', defaultValue: 28 },
      alertRadius:    { type: 'decimal', description: 'Distance in metres at which creature enters alert state', defaultValue: 15.0 },
      attackRadius:   { type: 'decimal', description: 'Distance in metres at which creature begins attacking', defaultValue: 3.0 },
      fleeThreshold:  { type: 'decimal', description: 'HP fraction (0–1) below which creature flees', defaultValue: 0.30 },
      respawnSeconds: { type: 'integer', description: 'Seconds before a dead creature respawns', defaultValue: 1080 },
      spawnCount:     { type: 'integer', description: 'Number of instances spawned per game world', defaultValue: 1 },
      biome:          { type: 'enum', values: BIOME_KEYS, description: 'Biome this creature belongs to', defaultValue: 'TwilightGrove' },
    },
    stateMachine: creatureStateMachine(),
    behaviors: {
      detect: {
        description: 'Stalk players from invisibility before ambushing',
        rules: [
          'Invisible while idle and alert; visibility phase lasts 1 second before each attack',
          'Detects players within 15 tiles; follows silently before initiating attack',
          'Tracking: Expert can reveal a VeilStalker\'s approximate location via disturbed undergrowth',
        ],
        auth: { roles: ['maintainer'] },
      },
      attack: {
        description: 'Ambush strike with paralytic venom injection',
        rules: [
          'Deals baseDamage; injects venom on hit — venom causes paralysis (3 seconds, 20% chance)',
          'Paralysis prevents movement and action; does not stack',
          'Must become visible for 1 second before striking; players can react during this window',
        ],
        auth: { roles: ['maintainer'] },
      },
      flee: {
        description: 'Phase into invisibility and disengage when health drops below 30%',
        rules: [
          'Instantly becomes invisible on fleeing',
          'Breaks combat and repositions to 15+ tiles away before becoming trackable again',
        ],
        auth: { roles: ['maintainer'] },
      },
      die: {
        description: 'Transition to dead state; briefly becomes visible as phase coherence fails',
        rules: ['Death emits a death event; body becomes visible and lootable for 30 seconds before fading'],
        auth: { roles: ['maintainer'] },
      },
      drop: {
        description: 'Drop loot on death',
        rules: [
          'Always drops: veilstalker venom sac (1), shadow-phase membrane (1)',
          'Chance drop: crystallised phase-shard (20%) — rare magical component',
        ],
        auth: { roles: ['maintainer'] },
      },
      respawn: {
        description: 'Respawn at a twilight grove hollow after cooldown',
        rules: ['Respawn cooldown: 18 in-game minutes; spawns invisible'],
        auth: { roles: ['maintainer'] },
      },
      calm: {
        description: 'Phase back to invisible patrol after losing target',
        rules: ['Disengages and becomes invisible 20 seconds after losing target'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
