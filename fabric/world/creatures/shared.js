const { defineEntity } = require('@newel/core')

const CREATURE_TIERS = ['1', '2', '3', '4', '5']
const AGGRESSION_LEVELS = ['passive', 'neutral', 'aggressive', 'territorial']
const CREATURE_STATES = ['idle', 'alert', 'aggressive', 'fleeing', 'dead', 'respawning']
const BIOME_KEYS = ['TemperateForest', 'TemperateGrassland', 'VolcanicBadlands', 'TwilightGrove', 'VoidRift']
// How group members coordinate (pack/herd behaviour, Phase 30). `none` = solitary
// (no cross-creature coordination); `pack` = predators that share alert/aggressive
// (a coordinated attack); `herd` = prey that stampede together (share flee).
const GROUP_BEHAVIORS = ['none', 'pack', 'herd']

// Returns the CREATURE_STATES subset appropriate for a creature's canFlee/skipAlert settings.
function creatureStateValues({ canFlee = true, skipAlert = false } = {}) {
  return CREATURE_STATES.filter(s => {
    if (s === 'fleeing' && !canFlee) return false
    if (s === 'alert'   && skipAlert) return false
    return true
  })
}

// canFlee: set to false for creatures whose design forbids the fleeing state (e.g. RiftWarden).
// skipAlert: set to true for creatures that fire attack directly from idle on detection, bypassing alert (e.g. RiftWarden).
// conditionalAlertSkip: set to true when a creature has BOTH the normal idle→alert path AND a conditional
//   idle→aggressive direct path (e.g. ForestBoar near boarlet, GraywolfPack when player carries raw meat).
function creatureStateMachine({ canFlee = true, skipAlert = false, conditionalAlertSkip = false } = {}) {
  const fleeTransitions = canFlee
    ? [
        ...(!skipAlert ? [{ from: 'alert', to: 'fleeing', trigger: 'flee' }] : []),
        { from: 'aggressive', to: 'fleeing', trigger: 'flee' },
        { from: 'fleeing',    to: 'dead',    trigger: 'die' },
        { from: 'fleeing',    to: 'idle',    trigger: 'calm' },
        { from: 'fleeing',    to: 'aggressive', trigger: 'attack' },
      ]
    : []

  const alertTransitions = skipAlert
    ? []
    : [
        { from: 'idle',  to: 'alert',      trigger: 'detect' },
        ...(conditionalAlertSkip ? [{ from: 'idle', to: 'aggressive', trigger: 'detect' }] : []),
        { from: 'alert', to: 'aggressive', trigger: 'attack' },
        { from: 'alert', to: 'idle',       trigger: 'calm' },
      ]

  return {
    field: 'state',
    initial: 'idle',
    states: {
      idle:       'Creature is at rest; not pursuing any target',
      ...(skipAlert ? {} : { alert: 'Creature has detected a threat; preparing to fight or flee' }),
      aggressive: 'Creature is actively attacking a target',
      ...(canFlee ? { fleeing: 'Creature is retreating from danger; cannot attack' } : {}),
      dead:       'Creature has been killed; drops are available',
      respawning: 'Creature is regenerating at its spawn point; not yet interactable',
    },
    transitions: [
      ...(skipAlert ? [{ from: 'idle', to: 'aggressive', trigger: 'detect' }] : []),
      ...alertTransitions,
      { from: 'aggressive', to: 'dead',       trigger: 'die' },
      { from: 'aggressive', to: 'idle',       trigger: 'calm' },
      ...fleeTransitions,
      { from: 'dead',       to: 'respawning', trigger: 'respawn' },
      { from: 'respawning', to: 'idle',       trigger: 'calm' },
    ],
  }
}

// Structured drop table consumed by LootSlice (src/loot/loot_slice.gd). The
// `drop` behavior above carries the prose design bible; this json field is the
// single source of truth for in-game loot rolls — item key (raw creature drop,
// not a fabric entity), drop chance (0–1), and quantity range [minQty, maxQty].
// Each entry is rolled independently on death.
function dropsData(drops) {
  return {
    type: 'json',
    description:
      'Structured drop table: raw drop item key, drop chance (0–1), and quantity range [minQty, maxQty]. Rolled independently per kill by the loot system.',
    defaultValue: drops,
  }
}

// Structured taming spec consumed by TamingSlice (src/creature/taming_slice.gd).
// The `tame` behavior on the entity carries the prose design bible; this json
// field is the single source of truth for in-game taming resolution.
//
//   result              'companion' — the creature becomes the tamer's companion;
//                       'yield'     — the creature stays alive and sheds items.
//   requiresUnarmed     the tamer must have nothing equipped in the main hand.
//   requiresSkill       { skill, tier } — the tamer's own skill progression.
//   requiresAnyItem     [{ item, quantity }] — ANY ONE entry satisfies the offer
//                       and is consumed (the fabric rules name alternatives:
//                       "offer field rations or raw meat while unarmed").
//   requiresDefeated    a same-species instance in the world is already dead —
//                       the pack's alpha-down gate ("tame a surviving pup after
//                       defeating the alpha wolf").
//   grantsFlag          a durable player flag set on success ("" = none).
//   yields              [{ item, quantity }] given to the tamer on success.
//   cooldownSeconds     wall-clock seconds before this SAME instance can be
//                       tamed again (0 = no cooldown).
//   suppressRespawn     a tamed instance of this creature does not respawn.
function tameData(tame) {
  return {
    type: 'json',
    description:
      'Structured taming spec: result kind (companion / yield), bare-hands and skill requirements, the offered item consumed, the defeated-alpha gate, the granted player flag, shed items, cooldown (seconds) and whether a tamed instance respawns.',
    defaultValue: tame,
  }
}


// Phase 44 — how a creature populates the world, as ENTITY FIELDS the runtime spawn
// roll (src/creature/creature_slice.gd) reads off the generated creature resources.
//
//   spawnCount   — PACK size: the instances placed TOGETHER around one spawn point when
//                  a chunk's roll admits this creature. It used to read "per game world"
//                  while the runtime spawned that many per chunk of the biome; it is now
//                  neither — one chunk rolls at most one pack, and a pack of 3 means three
//                  arriving together in one place, which is what the Phase 30 pack/herd AI
//                  consumes.
//   spawnChance  — 0..1, the per-chunk chance that a chunk of this creature's biome holds
//                  a pack at all (before the density noise). Authored from the biome
//                  prose's "spawn weight".
//   spawnDensity — 0..1, the amplitude of a seeded 2D density noise that scales the chance
//                  across the world: 0 = an even sprinkle, higher = packs cluster in some
//                  regions and thin out to nothing in others.
//
// The `why` string is the prose claim the numbers come from.
function spawnFields({ packSize, chance, density, why }) {
  return {
    spawnCount: {
      type: 'integer',
      description: `Pack size: instances placed together at one spawn point when a chunk rolls a spawn (not a per-chunk or per-world count). ${why}`,
      defaultValue: packSize,
    },
    spawnChance: {
      type: 'decimal',
      description: 'Per-chunk chance (0–1) that a chunk of this biome holds a pack, before the density noise',
      defaultValue: chance,
    },
    spawnDensity: {
      type: 'decimal',
      description: 'Amplitude (0–1) of the seeded density noise that clusters packs in some regions and thins them in others',
      defaultValue: density,
    },
  }
}

module.exports = { spawnFields, defineEntity, creatureStateMachine, creatureStateValues, CREATURE_TIERS, AGGRESSION_LEVELS, CREATURE_STATES, BIOME_KEYS, GROUP_BEHAVIORS, dropsData, tameData }
