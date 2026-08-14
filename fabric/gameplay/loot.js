const { defineEntity } = require('@newel/core')

const LOOT_STATES = ['sealed', 'available', 'claimed', 'expired']

function lootStateMachine() {
  return {
    field: 'state',
    initial: 'sealed',
    states: {
      sealed:    'Loot has not yet been rolled; no items are visible',
      available: 'Loot roll has completed; items are present in the world and can be picked up',
      claimed:   { description: 'All items have been picked up; the container is empty', terminal: false },
      expired:   { description: 'Despawn timer elapsed with unclaimed items; items are removed from the world', terminal: true },
    },
    transitions: [
      { from: 'sealed',    to: 'available', trigger: 'roll' },
      { from: 'available', to: 'claimed',   trigger: 'collect' },
      { from: 'available', to: 'expired',   trigger: 'expire' },
      { from: 'claimed',   to: 'expired',   trigger: 'expire' },
    ],
  }
}

module.exports = {

  // ─── LootTable ─────────────────────────────────────────────────────────────
  LootTable: defineEntity({
    tags: ['loot'],
    description:
      'Defines the rules that govern what items drop when a creature dies. ' +
      'Each entry specifies an item, a quantity range, and a drop chance. ' +
      'The LootTable is shared across all instances of a creature species; ' +
      'individual rolls are performed per kill by the loot system.',
    goal: 'Centralise drop rules in the design bible so balance changes are a single-source edit rather than scattered constants',
    fields: {
      id:            { type: 'uuid', primaryKey: true },
      state:         { type: 'enum', values: LOOT_STATES },
      creatureId:    { type: 'string', description: 'Entity key of the creature this table belongs to' },
      despawnSeconds: { type: 'integer', description: 'Seconds before unclaimed loot is removed from the world', defaultValue: 120 },
    },
    stateMachine: lootStateMachine(),
    behaviors: {
      roll: {
        description: 'Perform the loot roll for all entries in the table and place results in the world',
        rules: [
          'Guaranteed entries (chance = 1.0) always produce their item',
          'Chance entries are rolled independently; multiple chance drops can occur in one kill',
          'Quantity is chosen uniformly at random within [minQty, maxQty]',
          'Rolled items are placed at the creature\'s death position as world pickups',
          'Emits a loot_dropped event with the full drop list',
        ],
        auth: { roles: ['maintainer'] },
      },
      collect: {
        description: 'A player picks up one or more items from the available loot',
        rules: [
          'Collection transfers the item to the player\'s inventory via Inventory.pickup',
          'When the last item is collected the state transitions to claimed',
        ],
        auth: { roles: ['maintainer'] },
      },
      expire: {
        description: 'Despawn timer elapses; all remaining items are removed',
        rules: [
          'Timer starts when state enters available',
          'Expiry emits a loot_expired event so clients can hide the pickup indicator',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── DeathSignal ───────────────────────────────────────────────────────────
  DeathSignal: defineEntity({
    tags: ['system'],
    description:
      'System that propagates entity-death events across all subsystems. ' +
      'When any creature or player entity transitions to the dead state, ' +
      'DeathSignal broadcasts an authoritative death event that the loot, ' +
      'combat, UI, and persistence systems subscribe to. ' +
      'This decouples the death source from its downstream effects.',
    goal: 'Ensure every death — creature or player — triggers consistent downstream reactions through a single broadcast channel',
    fields: {
      id: { type: 'uuid', primaryKey: true },
    },
    behaviors: {
      broadcast: {
        description: 'Emit a death event when any entity reaches the dead state',
        rules: [
          'Payload includes: entity_id, entity_type (creature | player), world_position, killer_id (nullable)',
          'Subscribed systems: LootTable.roll, CombatSystem (XP calculation), PersistenceSlice (world-state update), UI (death overlay)',
          'Broadcast is idempotent — duplicate broadcasts for the same entity in the same death cycle are suppressed',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
