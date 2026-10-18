const { defineEntity } = require('@newel/core')

const CREATURE_TIERS = ['1', '2', '3', '4', '5']
const AGGRESSION_LEVELS = ['passive', 'neutral', 'aggressive', 'territorial']
const CREATURE_STATES = ['idle', 'alert', 'aggressive', 'fleeing', 'dead', 'respawning']
const BIOME_KEYS = ['TemperateForest', 'TemperateGrassland', 'VolcanicBadlands', 'TwilightGrove', 'VoidRift', 'Ocean', 'Beach', 'Desert', 'Tundra', 'Alpine', 'Taiga', 'Savanna']
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

// Structured harvest table (Phase 160), formerly the drop table. The `drop` behavior above carries the
// prose design bible; this json field is the single source of truth for what a body yields. Each entry:
// { item, chance (0-1), minQty, maxQty, tool, skill } -- the raw item key (a creature material, not a
// fabric entity), the base chance, the quantity range, the tool category that works it (`knife`,
// `bonetool` or `none` for things picked straight off the body) and the skill that scales it
// (`Skinning`). Quantity rises from minQty at level 0 to maxQty at the cap and chance rises with level;
// see gameplay/harvest.js. Each entry is rolled independently per harvest.
function dropsData(drops) {
  return {
    type: 'json',
    description:
      'Structured harvest table: raw item key, base chance (0-1), quantity range [minQty, maxQty], the tool category that works it (knife, bonetool, none) and the scaling skill. Each entry is rolled independently per harvest.',
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

// Ground movement (Phase 136), consumed by CreaturePath (src/creature/creature_path.gd). Spread into
// a creature's `fields`; override a value by listing the field after the spread.
//   maxStepMetres    tallest ledge the creature climbs in one tile step (> 0)
//   canSwim          the creature may path through water tiles (ground below sea level)
//   pathRadiusTiles  search radius of one path query, in tiles (1..PATH_RADIUS_MAX)
//   movement         how the creature occupies the world (Phase 149): ground (snapped to the surface),
//                    flying (kept hoverMetres above it) or swimming
//   hoverMetres      height above the surface a flyer holds (>= 0; 0 for the other kinds)
const PATH_RADIUS_MAX = 64
const MOVEMENT_KINDS = ['ground', 'flying', 'swimming']
function pathFields({ maxStepMetres = 0.75, canSwim = false, pathRadiusTiles = 24, movement = 'ground', hoverMetres = 0 } = {}) {
  return {
    maxStepMetres:   { type: 'decimal', description: 'Tallest ledge in metres the creature climbs in one tile step; a taller step is routed around', defaultValue: maxStepMetres },
    canSwim:         { type: 'boolean', description: 'Whether the creature paths through water tiles (ground below sea level)', defaultValue: canSwim },
    pathRadiusTiles: { type: 'integer', description: 'Search radius in tiles of one path query', defaultValue: pathRadiusTiles },
    movement:        { type: 'enum', values: MOVEMENT_KINDS, description: 'ground snaps to the surface, flying holds hoverMetres above it, swimming stays in water', defaultValue: movement },
    hoverMetres:     { type: 'decimal', description: 'Height in metres above the surface a flying creature holds', defaultValue: hoverMetres },
  }
}

// Throws (failing `npm run validate`) when a creature's ground-movement fields are out of range.
function validatePathFields(creatures) {
  for (const [name, entity] of Object.entries(creatures)) {
    const f = (entity && entity.fields) || {}
    if (!f.maxStepMetres) continue
    const step = f.maxStepMetres.defaultValue
    const radius = f.pathRadiusTiles.defaultValue
    if (!(typeof step === 'number' && step > 0)) throw new Error(`${name}: maxStepMetres must be > 0 (got ${step})`)
    if (!Number.isInteger(radius) || radius < 1 || radius > PATH_RADIUS_MAX) {
      throw new Error(`${name}: pathRadiusTiles must be an integer in 1..${PATH_RADIUS_MAX} (got ${radius})`)
    }
    const kind = f.movement.defaultValue
    if (!MOVEMENT_KINDS.includes(kind)) throw new Error(`${name}: movement must be one of ${MOVEMENT_KINDS.join(', ')} (got ${kind})`)
    const hover = f.hoverMetres.defaultValue
    if (!(typeof hover === 'number' && hover >= 0)) throw new Error(`${name}: hoverMetres must be >= 0 (got ${hover})`)
    if (kind === 'flying' && !(hover > 0)) throw new Error(`${name}: a flying creature needs hoverMetres > 0`)
    if (typeof f.canSwim.defaultValue !== 'boolean') throw new Error(`${name}: canSwim must be a boolean`)
  }
}

// Skeleton family a creature's model is rigged on (Phase 143), consumed by CreatureVisuals. Spread into
// a creature's `fields`. Each value names a SkeletonDefinition entity in gameplay/characters/skeletons.js.
const CREATURE_SKELETONS = ['QuadrupedSkeleton', 'BirdSkeleton', 'SerpentSkeleton', 'HumanoidSkeleton']
function skeletonField(family) {
  return { type: 'string', description: 'Skeleton family the creature model is rigged on (a SkeletonDefinition entity)', defaultValue: family }
}

// Throws (failing `npm run validate`) when a creature lacks a skeleton or names an unknown one.
function validateSkeletonFields(creatures, skeletons = CREATURE_SKELETONS) {
  for (const [name, entity] of Object.entries(creatures)) {
    const f = (entity && entity.fields) || {}
    const v = f.skeleton && f.skeleton.defaultValue
    if (!v) throw new Error(`${name}: creature must name a skeleton`)
    if (!skeletons.includes(v)) throw new Error(`${name}: unknown skeleton '${v}' (expected one of ${skeletons.join(', ')})`)
  }
}

module.exports = { skeletonField, validateSkeletonFields, CREATURE_SKELETONS, pathFields, validatePathFields, PATH_RADIUS_MAX, MOVEMENT_KINDS, defineEntity, creatureStateMachine, creatureStateValues, CREATURE_TIERS, AGGRESSION_LEVELS, CREATURE_STATES, BIOME_KEYS, GROUP_BEHAVIORS, dropsData, tameData }
