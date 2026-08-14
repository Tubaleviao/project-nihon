const { defineEntity } = require('@newel/core')

const PLAYER_STATES = ['alive', 'dead', 'respawning']
const INVENTORY_STATES = ['open', 'closed', 'full']

function playerStateMachine() {
  return {
    field: 'state',
    initial: 'alive',
    states: {
      alive:      'Player is in the world; can move, fight, and interact',
      dead:       { description: 'Player has been killed; inventory is locked; respawn timer running', terminal: false },
      respawning: 'Player is transitioning back to alive at their bind point',
    },
    transitions: [
      { from: 'alive',      to: 'dead',       trigger: 'die' },
      { from: 'dead',       to: 'respawning',  trigger: 'respawn' },
      { from: 'respawning', to: 'alive',       trigger: 'spawn' },
    ],
  }
}

function inventoryStateMachine() {
  return {
    field: 'state',
    initial: 'closed',
    states: {
      open:   'Inventory UI is visible; player can manage, equip, or drop items',
      closed: 'Inventory UI is hidden; passive weight and slot checks still apply',
      full:   'All slots and weight capacity are at maximum; pickups are rejected',
    },
    transitions: [
      { from: 'closed', to: 'open',   trigger: 'open' },
      { from: 'open',   to: 'closed', trigger: 'close' },
      { from: 'open',   to: 'full',   trigger: 'fill' },
      { from: 'closed', to: 'full',   trigger: 'fill' },
      { from: 'full',   to: 'open',   trigger: 'open' },
      { from: 'full',   to: 'closed', trigger: 'close' },
    ],
  }
}

module.exports = {

  // ─── PlayerCharacter ───────────────────────────────────────────────────────
  PlayerCharacter: defineEntity({
    tags: ['player'],
    description:
      'The player-controlled character in the world. ' +
      'Stats are derived from equipped items, active skills, and status effects. ' +
      'A player\'s character persists across sessions; death resets only transient state.',
    goal: 'Model the minimum runtime data the server needs to authorise actions and the client needs to render the character',
    fields: {
      id:           { type: 'uuid', primaryKey: true },
      state:        { type: 'enum', values: PLAYER_STATES },
      name:         { type: 'string', description: 'Display name chosen at character creation' },
      baseHp:       { type: 'integer', description: 'Maximum HP at current level/gear baseline', defaultValue: 100 },
      currentHp:    { type: 'integer', description: 'Current hit points; 0 triggers the die transition', defaultValue: 100 },
      baseSpeed:    { type: 'decimal', description: 'Movement speed in tiles per second', defaultValue: 4.5 },
      positionX:    { type: 'decimal', description: 'World X coordinate (server-authoritative)', defaultValue: 0.0 },
      positionY:    { type: 'decimal', description: 'World Y coordinate (elevation)', defaultValue: 0.0 },
      positionZ:    { type: 'decimal', description: 'World Z coordinate (server-authoritative)', defaultValue: 0.0 },
    },
    stateMachine: playerStateMachine(),
    behaviors: {
      move: {
        description: 'Move the character through the world',
        rules: [
          'Server validates the destination tile against the heightmap collision mesh',
          'Speed is reduced to 60% in water, 80% on rough terrain (volcanic, void)',
          'Movement input is rejected while the character is in the dead state',
        ],
        auth: { roles: ['maintainer'] },
      },
      attack: {
        description: 'Initiate a combat action against a target entity',
        rules: [
          'Attack request is forwarded to CombatSystem.calculateHit',
          'Cooldown is determined by the equipped weapon\'s attack speed field',
          'Attacks from the dead state are silently dropped by the server',
        ],
        auth: { roles: ['maintainer'] },
      },
      die: {
        description: 'Transition to dead state on HP reaching 0',
        rules: [
          'Emits a player_died event consumed by the UI, loot, and persistence systems',
          'Inventory is locked; equipment remains visible to other players at the death location',
          'Respawn timer begins immediately (default 10 seconds)',
        ],
        auth: { roles: ['maintainer'] },
      },
      respawn: {
        description: 'Begin respawning at the player\'s bound respawn point',
        rules: [
          'HP is restored to baseHp on completing the respawn transition',
          'Player appears at their last-used bind point or the world spawn if none is set',
        ],
        auth: { roles: ['maintainer'] },
      },
      spawn: {
        description: 'Complete respawn; character becomes interactive again',
        rules: ['Grants 5-second invulnerability window; movement is unrestricted immediately'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Inventory ─────────────────────────────────────────────────────────────
  Inventory: defineEntity({
    tags: ['player'],
    description:
      'The container of items carried by a single player. ' +
      'Weight and slot limits enforce the survival economy; exceeding either blocks pickups. ' +
      'Inventory contents are persisted server-side and restored on login.',
    goal: 'Define the rules governing what a player can carry, how items stack, and when the full state is reached',
    fields: {
      id:          { type: 'uuid', primaryKey: true },
      state:       { type: 'enum', values: INVENTORY_STATES },
      maxSlots:    { type: 'integer', description: 'Maximum number of distinct item stacks', defaultValue: 30 },
      maxWeightKg: { type: 'decimal', description: 'Maximum total carry weight in kilograms', defaultValue: 50.0 },
      usedSlots:   { type: 'integer', description: 'Current number of occupied stacks', defaultValue: 0 },
      currentWeightKg: { type: 'decimal', description: 'Sum of (item.weight × quantity) for all stacks', defaultValue: 0.0 },
    },
    stateMachine: inventoryStateMachine(),
    behaviors: {
      pickup: {
        description: 'Add a world-dropped item to the inventory',
        rules: [
          'Rejected if state is full',
          'Stackable items merge into an existing stack if one exists; otherwise a new slot is consumed',
          'Weight is recalculated on every pickup; if the result would exceed maxWeightKg, the pickup is rejected',
          'Emits an item_picked_up event with the item id and quantity',
        ],
        auth: { roles: ['maintainer'] },
      },
      drop: {
        description: 'Remove an item from the inventory and place it in the world at the player\'s position',
        rules: [
          'Dropping a full stack frees the slot',
          'Partial stack drop reduces quantity; slot is freed only when quantity reaches 0',
          'Equipment currently worn cannot be dropped without first being unequipped',
        ],
        auth: { roles: ['maintainer'] },
      },
      open: {
        description: 'Open the inventory UI',
        rules: ['Blocked during combat animations; otherwise always permitted'],
        auth: { roles: ['maintainer'] },
      },
      close: {
        description: 'Close the inventory UI',
        rules: ['Always permitted'],
        auth: { roles: ['maintainer'] },
      },
      fill: {
        description: 'Transition to full state when slots or weight ceiling is reached',
        rules: ['Triggered automatically after every successful pickup that saturates either limit'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}

module.exports.PLAYER_STATES   = PLAYER_STATES
module.exports.INVENTORY_STATES = INVENTORY_STATES
