const { defineEntity, creatureStateMachine, CREATURE_TIERS, AGGRESSION_LEVELS, CREATURE_STATES } = require('./shared')

module.exports = {

  // ─── ForestBoar ───────────────────────────────────────────────────────────
  ForestBoar: defineEntity({
    tags: ['creature'],
    description:
      'A stout, bristle-furred boar that roots through the forest floor for tubers and fungi. ' +
      'Normally passive, but fiercely territorial when its young are nearby. ' +
      'The most hunted creature in the temperate forest — a reliable early-game meat and hide source.',
    goal: 'Provide new players a safe, rewarding hunt that teaches basic combat loops',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      state:          { type: 'enum', values: CREATURE_STATES },
      tier:           { type: 'enum', values: CREATURE_TIERS, description: 'Combat difficulty tier' },
      aggressionLevel: { type: 'enum', values: AGGRESSION_LEVELS },
      baseHp:         { type: 'integer', description: 'Hit points at tier baseline' },
      baseDamage:     { type: 'integer', description: 'Damage per standard attack at tier baseline' },
    },
    stateMachine: creatureStateMachine(),
    behaviors: {
      detect: {
        description: 'Detect a threat and transition from idle to alert',
        rules: [
          'Detects players within 8 tile radius',
          'Fires attack trigger directly from idle (no alert phase) if player is within 3 tiles of boarlet (juvenile)',
        ],
        auth: { roles: ['maintainer'] },
      },
      attack: {
        description: 'Charge the target with a tusk gore',
        rules: [
          'Gore deals baseDamage; knocks back target 1 tile',
          'Charge requires 2-tile run-up; no knockback at close range',
        ],
        auth: { roles: ['maintainer'] },
      },
      flee: {
        description: 'Retreat when health drops below 25%',
        rules: ['Flees toward dense undergrowth; loses aggro if player breaks line of sight for 10 seconds'],
        auth: { roles: ['maintainer'] },
      },
      die: {
        description: 'Transition to dead state; trigger loot drop and start respawn timer',
        rules: ['Emits a death event consumed by the drop behavior; respawn timer begins immediately'],
        auth: { roles: ['maintainer'] },
      },
      drop: {
        description: 'Drop loot on death',
        rules: [
          'Always drops: raw boar meat (1–3), boar hide (1)',
          'Chance drop: boar tusk (20%)',
        ],
        auth: { roles: ['maintainer'] },
      },
      respawn: {
        description: 'Regenerate at the biome spawn point after a cooldown',
        rules: ['Respawn cooldown: 5 in-game minutes; respawn point is the nearest ForestBoar spawn marker'],
        auth: { roles: ['maintainer'] },
      },
      calm: {
        description: 'Return to idle when threat is no longer detected',
        rules: ['Alert-to-idle: 30 seconds without threat; fleeing-to-idle: reaches safe zone'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── GraywolfPack ─────────────────────────────────────────────────────────
  GraywolfPack: defineEntity({
    tags: ['creature'],
    description:
      'A coordinated hunting pack of gray wolves that roam temperate forest edges and clearings. ' +
      'Individual wolves are manageable; the pack tactics make them deadly to lone travellers. ' +
      'Taming a pup from a defeated pack unlocks the Ranger profession bonus.',
    goal: 'Introduce group AI tactics and the taming mechanic; reward skilled solo hunters over raw power',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      state:          { type: 'enum', values: CREATURE_STATES },
      tier:           { type: 'enum', values: CREATURE_TIERS, description: 'Combat difficulty tier' },
      aggressionLevel: { type: 'enum', values: AGGRESSION_LEVELS },
      baseHp:         { type: 'integer', description: 'Hit points per wolf at tier baseline' },
      baseDamage:     { type: 'integer', description: 'Damage per bite at tier baseline' },
    },
    stateMachine: creatureStateMachine(),
    behaviors: {
      detect: {
        description: 'The lead wolf detects prey; pack transitions to alert simultaneously',
        rules: [
          'Lead wolf detects within 12 tile radius; pack shares the alert state instantly',
          'Pack is aggressive from the start if player is carrying raw meat',
        ],
        auth: { roles: ['maintainer'] },
      },
      attack: {
        description: 'Pack flanking attack — wolves surround the target and attack in sequence',
        rules: [
          'Two wolves attempt to flank; remaining wolves attack the front',
          'Flanking wolf deals 1.5× baseDamage if attack lands from behind',
        ],
        auth: { roles: ['maintainer'] },
      },
      flee: {
        description: 'Pack disbands and flees when lead wolf is killed',
        rules: ['Surviving wolves flee independently; they do not regroup during the same spawn cycle'],
        auth: { roles: ['maintainer'] },
      },
      die: {
        description: 'Transition individual wolf (or full pack) to dead state; trigger loot drop',
        rules: ['Each wolf dies independently; pack is considered dead when all wolves reach the dead state'],
        auth: { roles: ['maintainer'] },
      },
      drop: {
        description: 'Drop loot when all wolves in the pack are dead',
        rules: [
          'Each wolf drops: wolf pelt (1), wolf fang (0–1, 40% chance)',
          'Pack alpha drop: alpha wolf fang (1, 100%)',
        ],
        auth: { roles: ['maintainer'] },
      },
      tame: {
        description: 'Tame a surviving pup after defeating the alpha wolf',
        rules: [
          'Requires Unarmed: Journeyman',
          'Player must approach the pup while unarmed; pup is flagged tameable after alpha death',
          'Taming grants a wolf companion and sets the wolfBondHolder flag; Ranger profession requires this flag in addition to its skill prerequisites',
        ],
        auth: { roles: ['maintainer'] },
      },
      respawn: {
        description: 'Pack reforms at its territory spawn point after cooldown',
        rules: ['Respawn cooldown: 15 in-game minutes; pup does not respawn if tamed'],
        auth: { roles: ['maintainer'] },
      },
      calm: {
        description: 'Return to idle when no prey is detected',
        rules: ['Pack returns to patrol route 60 seconds after losing target'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── SteppeBison ──────────────────────────────────────────────────────────
  SteppeBison: defineEntity({
    tags: ['creature'],
    description:
      'A massive, shaggy bison that grazes temperate grasslands in loose herds. ' +
      'Slow and passive unless provoked, but a stampede is lethal to unarmoured players. ' +
      'The primary large-game target for grassland settlements; bones are a key structural component.',
    goal: 'Provide a high-yield, high-risk hunt that rewards group play and rewarded preparation',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      state:          { type: 'enum', values: CREATURE_STATES },
      tier:           { type: 'enum', values: CREATURE_TIERS, description: 'Combat difficulty tier' },
      aggressionLevel: { type: 'enum', values: AGGRESSION_LEVELS },
      baseHp:         { type: 'integer', description: 'Hit points at tier baseline; high value' },
      baseDamage:     { type: 'integer', description: 'Damage per charge at tier baseline' },
    },
    stateMachine: creatureStateMachine(),
    behaviors: {
      detect: {
        description: 'Sense a threat through ground vibration and scent',
        rules: [
          'Detects vibration (galloping horses, explosions) within 20 tiles',
          'Scent detection within 6 tiles regardless of stealth skill',
        ],
        auth: { roles: ['maintainer'] },
      },
      attack: {
        description: 'Stampede charge in a straight line through the target',
        rules: [
          'Charge deals 3× baseDamage to first target in path; 1× to any behind',
          'Charge cannot be performed on uphill terrain',
        ],
        auth: { roles: ['maintainer'] },
      },
      flee: {
        description: 'Herd stampedes away from threat, dangerous to nearby players',
        rules: [
          'Entire herd flees together; players caught in stampede path take 2× baseDamage per second',
          'Fleeing direction is always away from the original threat source',
        ],
        auth: { roles: ['maintainer'] },
      },
      die: {
        description: 'Transition to dead state; trigger loot drop and start respawn timer',
        rules: ['Emits a death event; surviving herd members do not reset their flee state until cooldown expires'],
        auth: { roles: ['maintainer'] },
      },
      drop: {
        description: 'Drop loot on death',
        rules: [
          'Always drops: bison meat (3–6), bison hide (2), bison bone (1–2)',
          'Chance drop: bison horn (25%)',
        ],
        auth: { roles: ['maintainer'] },
      },
      respawn: {
        description: 'Respawn at the herd centre point after cooldown',
        rules: ['Respawn cooldown: 20 in-game minutes; herd respawns as a group'],
        auth: { roles: ['maintainer'] },
      },
      calm: {
        description: 'Herd settles back to grazing after threat passes',
        rules: ['Returns to idle 2 in-game minutes after losing threat'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RidgeHawk ────────────────────────────────────────────────────────────
  RidgeHawk: defineEntity({
    tags: ['creature'],
    description:
      'A keen-eyed raptor that nests on grassland ridges and hunts small game from altitude. ' +
      'Harmless to armoured players but can knock items from an unarmoured player\'s hands during a dive-bomb. ' +
      'Feathers are a sought-after fletching material for arrow crafting.',
    goal: 'Add environmental detail to the grasslands and give Archery players a reason to hunt without combat risk',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      state:          { type: 'enum', values: CREATURE_STATES },
      tier:           { type: 'enum', values: CREATURE_TIERS, description: 'Combat difficulty tier' },
      aggressionLevel: { type: 'enum', values: AGGRESSION_LEVELS },
      baseHp:         { type: 'integer', description: 'Hit points at tier baseline; low value' },
      baseDamage:     { type: 'integer', description: 'Damage per talon strike at tier baseline' },
    },
    stateMachine: creatureStateMachine(),
    behaviors: {
      detect: {
        description: 'Spot prey or threat from altitude',
        rules: [
          'Visual detection range is 30 tiles while airborne, 8 tiles while perched',
          'Cannot detect Stealth: Journeyman or higher players',
        ],
        auth: { roles: ['maintainer'] },
      },
      attack: {
        description: 'Dive-bomb a target, attempting to knock an item from their hand',
        rules: [
          'Dive-bomb deals 1× baseDamage',
          'Against unarmoured hand slot: 30% chance to knock held item to ground (item not destroyed)',
          'Against armoured players: no item knock; only damage applies',
        ],
        auth: { roles: ['maintainer'] },
      },
      flee: {
        description: 'Fly away when hit',
        rules: ['Immediately flees on taking any damage; re-engages only if nest is within 5 tiles'],
        auth: { roles: ['maintainer'] },
      },
      die: {
        description: 'Transition to dead state; trigger loot drop and start respawn timer',
        rules: ['Bird falls to ground on death; loot available at the landing tile'],
        auth: { roles: ['maintainer'] },
      },
      drop: {
        description: 'Drop loot on death',
        rules: [
          'Always drops: hawk feather (1–3)',
          'Chance drop: hawk talon (35%)',
        ],
        auth: { roles: ['maintainer'] },
      },
      respawn: {
        description: 'Respawn at nest location after cooldown',
        rules: ['Respawn cooldown: 10 in-game minutes'],
        auth: { roles: ['maintainer'] },
      },
      calm: {
        description: 'Return to circling patrol pattern',
        rules: ['Returns to idle 15 seconds after losing target'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
