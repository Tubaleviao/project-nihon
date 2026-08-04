const { defineEntity } = require('@newel/core')

const PROFESSION_STATUSES = ['locked', 'active', 'mastered']

const PROFESSION_STATE_MACHINE = {
  field: 'status',
  initial: 'locked',
  states: {
    locked:   'Prerequisite skill tiers not yet met',
    active:   'Profession is available to the player; provides passive and active bonuses',
    mastered: { description: 'All constituent skills are at master tier; highest-tier profession bonuses active', terminal: true },
  },
  transitions: [
    { from: 'locked',  to: 'active',   trigger: 'unlock' },
    { from: 'active',  to: 'mastered', trigger: 'master' },
  ],
}

const professions = {

  // ─── Blacksmith ───────────────────────────────────────────────────────────
  Blacksmith: defineEntity({
    tags: ['profession'],
    description:
      'Dedicated metalworker who has combined standard smithing with arcane forging techniques. ' +
      'Produces higher-quality weapons and armour, and can process magical materials unavailable to ' +
      'casual crafters.',
    goal: 'Represent the mid-tier crafting profession that bridges mundane and magical metalwork',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: PROFESSION_STATUSES },
    },
    relations: {
      smithing:     { name: 'smithing',     kind: 'hasOne', target: 'Smithing' },
      arcaneForging: { name: 'arcaneForging', kind: 'hasOne', target: 'ArcaneForging' },
    },
    stateMachine: PROFESSION_STATE_MACHINE,
    behaviors: {
      unlock: {
        description: 'Become available when prerequisite crafting skill tiers are reached',
        rules: [
          'Requires Smithing: Journeyman',
          'Requires Arcane Forging: Apprentice',
        ],
        auth: { roles: ['maintainer'] },
      },
      master: {
        description: 'Achieve full mastery when all constituent skills reach master tier',
        rules: ['Smithing and Arcane Forging must both be at master tier'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Arcanist ─────────────────────────────────────────────────────────────
  Arcanist: defineEntity({
    tags: ['profession'],
    description:
      'A practitioner who has married elemental control with enchanting craft, producing the most ' +
      'potent magical items and wielding area-control spells in combat.',
    goal: 'Represent the primary magic-focused profession with both offensive and item-craft capability',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: PROFESSION_STATUSES },
    },
    relations: {
      elementalMagic: { name: 'elementalMagic', kind: 'hasOne', target: 'ElementalMagic' },
      enchanting:     { name: 'enchanting',     kind: 'hasOne', target: 'Enchanting' },
    },
    stateMachine: PROFESSION_STATE_MACHINE,
    behaviors: {
      unlock: {
        description: 'Become available when prerequisite magic skill tiers are reached',
        rules: [
          'Requires Elemental Magic: Journeyman',
          'Requires Enchanting: Journeyman',
        ],
        auth: { roles: ['maintainer'] },
      },
      master: {
        description: 'Achieve full mastery when all constituent skills reach master tier',
        rules: ['Elemental Magic and Enchanting must both be at master tier'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Ranger ───────────────────────────────────────────────────────────────
  Ranger: defineEntity({
    tags: ['profession'],
    description:
      'A wilderness specialist who combines ranged combat with reading the environment. ' +
      'Provides the most effective hunting output and can guide expeditions through unmapped terrain.',
    goal: 'Represent the hunting and wilderness-travel profession; bridge combat and exploration',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: PROFESSION_STATUSES },
    },
    relations: {
      archery:    { name: 'archery',    kind: 'hasOne', target: 'Archery' },
      tracking:   { name: 'tracking',   kind: 'hasOne', target: 'Tracking' },
      navigation: { name: 'navigation', kind: 'hasOne', target: 'Navigation' },
      unarmed:    { name: 'unarmed',    kind: 'hasOne', target: 'Unarmed' },
    },
    stateMachine: PROFESSION_STATE_MACHINE,
    behaviors: {
      unlock: {
        description: 'Become available when prerequisite exploration and combat skill tiers are reached',
        rules: [
          'Requires Archery: Journeyman',
          'Requires Tracking: Apprentice',
          'Requires Navigation: Apprentice',
          'Player must hold wolfBondHolder flag — requires taming a GraywolfPack pup, which in turn requires Unarmed: Journeyman',
        ],
        auth: { roles: ['maintainer'] },
      },
      master: {
        description: 'Achieve full mastery when all constituent skills reach master tier',
        rules: ['Archery, Tracking, and Navigation must all be at master tier'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Warrior ──────────────────────────────────────────────────────────────
  Warrior: defineEntity({
    tags: ['profession'],
    description:
      'A frontline combatant who has mastered both offensive bladework and defensive shieldcraft. ' +
      'The archetypal tank-damage melee role; core to siege and creature-hunting groups.',
    goal: 'Represent the dedicated melee combat profession; pair with Arcanist for balanced group composition',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: PROFESSION_STATUSES },
    },
    relations: {
      swordsmanship: { name: 'swordsmanship', kind: 'hasOne', target: 'Swordsmanship' },
      shieldcraft:   { name: 'shieldcraft',   kind: 'hasOne', target: 'Shieldcraft' },
    },
    stateMachine: PROFESSION_STATE_MACHINE,
    behaviors: {
      unlock: {
        description: 'Become available when prerequisite combat skill tiers are reached',
        rules: [
          'Requires Swordsmanship: Journeyman',
          'Requires Shieldcraft: Apprentice',
        ],
        auth: { roles: ['maintainer'] },
      },
      master: {
        description: 'Achieve full mastery when all constituent skills reach master tier',
        rules: ['Swordsmanship and Shieldcraft must both be at master tier'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Alchemist ────────────────────────────────────────────────────────────
  Alchemist: defineEntity({
    tags: ['profession'],
    description:
      'A reagent crafter who supplements alchemy knowledge with arcane forging to produce the most ' +
      'potent catalysts and consumables. Primary supplier of enchanting inputs for Arcanists.',
    goal: 'Create an economic niche for potion and catalyst production; link crafting and magic economies',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: PROFESSION_STATUSES },
    },
    relations: {
      alchemy:      { name: 'alchemy',      kind: 'hasOne', target: 'Alchemy' },
      arcaneForging: { name: 'arcaneForging', kind: 'hasOne', target: 'ArcaneForging' },
    },
    stateMachine: PROFESSION_STATE_MACHINE,
    behaviors: {
      unlock: {
        description: 'Become available when prerequisite crafting skill tiers are reached',
        rules: [
          'Requires Alchemy: Journeyman',
          'Requires Arcane Forging: Apprentice',
        ],
        auth: { roles: ['maintainer'] },
      },
      master: {
        description: 'Achieve full mastery when all constituent skills reach master tier',
        rules: ['Alchemy and Arcane Forging must both be at master tier'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Merchant ─────────────────────────────────────────────────────────────
  Merchant: defineEntity({
    tags: ['profession'],
    description:
      'A commercial specialist who leverages trade acumen, diplomatic connections, and speechcraft ' +
      'to dominate NPC and player-to-NPC markets. Can operate offline via NPC consignment.',
    goal: 'Make commerce a viable primary profession; enable the player-driven economy to function at scale',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: PROFESSION_STATUSES },
    },
    relations: {
      trade:       { name: 'trade',       kind: 'hasOne', target: 'Trade' },
      diplomacy:   { name: 'diplomacy',   kind: 'hasOne', target: 'Diplomacy' },
      speechcraft: { name: 'speechcraft', kind: 'hasOne', target: 'Speechcraft' },
    },
    stateMachine: PROFESSION_STATE_MACHINE,
    behaviors: {
      unlock: {
        description: 'Become available when prerequisite social skill tiers are reached',
        rules: [
          'Requires Trade: Journeyman',
          'Requires Diplomacy: Apprentice',
          'Requires Speechcraft: Apprentice',
        ],
        auth: { roles: ['maintainer'] },
      },
      master: {
        description: 'Achieve full mastery when all constituent skills reach master tier',
        rules: ['Trade, Diplomacy, and Speechcraft must all be at master tier'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Pathfinder ───────────────────────────────────────────────────────────
  Pathfinder: defineEntity({
    tags: ['profession'],
    description:
      'An expert scout and guide who can navigate any terrain invisibly, chart it accurately, ' +
      'and lead groups at full speed. Essential for opening new territories.',
    goal: 'Reward deep exploration investment; create a profession that opens the world for other players',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: PROFESSION_STATUSES },
    },
    relations: {
      navigation:   { name: 'navigation',   kind: 'hasOne', target: 'Navigation' },
      cartography:  { name: 'cartography',  kind: 'hasOne', target: 'Cartography' },
      stealth:      { name: 'stealth',      kind: 'hasOne', target: 'Stealth' },
    },
    stateMachine: PROFESSION_STATE_MACHINE,
    behaviors: {
      unlock: {
        description: 'Become available when prerequisite exploration skill tiers are reached',
        rules: [
          'Requires Navigation: Journeyman',
          'Requires Cartography: Journeyman',
          'Requires Stealth: Apprentice',
        ],
        auth: { roles: ['maintainer'] },
      },
      master: {
        description: 'Achieve full mastery when all constituent skills reach master tier',
        rules: ['Navigation, Cartography, and Stealth must all be at master tier'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── VoidTouched ──────────────────────────────────────────────────────────
  VoidTouched: defineEntity({
    tags: ['profession'],
    description:
      'A rare hybrid who has survived void exposure and mastered both its magic and its smithing. ' +
      'Produces the most powerful items in the game and wields the only magic that bypasses veilsteel. ' +
      'Cannot be chosen — it is unlocked only through in-world experimentation.',
    goal: 'Represent the highest-tier dual-path profession; reward players who explored dangerously',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: PROFESSION_STATUSES },
    },
    relations: {
      voidMagic:    { name: 'voidMagic',    kind: 'hasOne', target: 'VoidMagic' },
      voidSmithing: { name: 'voidSmithing', kind: 'hasOne', target: 'VoidSmithing' },
    },
    stateMachine: PROFESSION_STATE_MACHINE,
    behaviors: {
      unlock: {
        description: 'Become available when both void-path skill tiers are reached',
        rules: [
          'Requires Void Magic: Expert',
          'Requires Void Smithing: Expert',
          'Player must hold voidBurstSurvivor flag — cannot be unlocked without surviving a void burst',
        ],
        auth: { roles: ['maintainer'] },
      },
      master: {
        description: 'Achieve full mastery when all constituent skills reach master tier',
        rules: ['Void Magic and Void Smithing must both be at master tier'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}

module.exports = professions
