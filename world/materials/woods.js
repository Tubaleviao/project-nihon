const { defineEntity } = require('@newel/core')

// NOTE: state keys in each factory must be kept in sync with the consumer entity's `state` enum values — the normalizer does not reconcile them.

// Lumber state machine: raw log → planed plank → treated (terminal).
function lumberStateMachine() {
  return {
    field: 'state',
    initial: 'raw',
    states: {
      raw:     'Freshly felled log; can be worked at a sawmill or hand-split',
      planed:  'Smooth plank or beam; ready for construction and basic crafting',
      treated: { description: 'Sealed and cured with resin or alchemy; weatherproof and fire-resistant', terminal: true },
    },
    transitions: [
      { from: 'raw',    to: 'planed',  trigger: 'plane' },
      { from: 'planed', to: 'treated', trigger: 'treat' },
    ],
  }
}

// Fibre state machine: raw bark → processed thread → treated (terminal).
function fibreStateMachine() {
  return {
    field: 'state',
    initial: 'raw',
    states: {
      raw:       'Freshly stripped bark bundle; must be shredded before use',
      processed: 'Weavable thread bundle; ready for textile crafting and rope-making',
      treated:   { description: 'Infused with moon-oil alchemical reagent; bioluminescence permanently locked in — only reachable via luminous thread (isLuminous = true at process time)', terminal: true },
    },
    transitions: [
      { from: 'raw',       to: 'processed', trigger: 'process' },
      { from: 'processed', to: 'treated',   trigger: 'treat' },
    ],
  }
}

module.exports = {

  // ─── Thornwood ────────────────────────────────────────────────────────────
  Thornwood: defineEntity({
    role: 'material',
    description:
      'Dense, dark-veined wood from the Thornwood tree that grows in lowland forests. ' +
      'Characterised by natural spike-like growths on its branches; commonly used for ' +
      'weapon hafts, siege equipment, and defensive palisades.',
    goal: 'Primary structural wood for early military and defensive constructions',
    fields: {
      id:           { type: 'uuid', primaryKey: true },
      state:        { type: 'enum', values: ['raw', 'planed', 'treated'] },
      density:      { type: 'decimal', description: 'g/cm³; heavier than most woods' },
      hardness:     { type: 'decimal', description: 'Janka hardness equivalent 0–1' },
      conductivity: { type: 'decimal', description: 'Thermal conductivity 0–1; low for wood' },
      magicAffinity: { type: 'decimal', description: 'Capacity to hold enchantment 0–1; very low — dense wood resists magical binding' },
    },
    stateMachine: lumberStateMachine(),
    behaviors: {
      plane: {
        description: 'Mill raw thornwood logs into planks at a player-built sawmill',
        rules: [
          'Three raw logs yield five planks',
          'Thornwood dulls blades faster than common lumber; tools degrade at 1.5× rate',
        ],
        auth: { roles: ['maintainer'] },
      },
      treat: {
        description: 'Apply pine-tar resin or alchemical sealant to planed thornwood, permanently sealing it',
        rules: [
          'Treated thornwood gains fire-resistance tier 1',
          'Treatment is a one-time permanent process; the treated state is final — for structures requiring seasonal maintenance, use untreated planks and track durability externally',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Duskfiber ────────────────────────────────────────────────────────────
  Duskfiber: defineEntity({
    role: 'material',
    description:
      'Fibrous bark harvested from the Duskwood trees that grow only in twilight biomes ' +
      'where day and night cycle at unusual speeds. The fibers shimmer with faint ' +
      'bioluminescence and are prized for light armour weaves and magical rope.',
    goal: 'Flexible mid-tier material bridging woodworking and textile crafting with a magical flavour',
    fields: {
      id:           { type: 'uuid', primaryKey: true },
      state:        { type: 'enum', values: ['raw', 'processed', 'treated'] },
      density:      { type: 'decimal', description: 'g/cm³; extremely low — used as fibre not lumber' },
      hardness:     { type: 'decimal', description: 'Janka equivalent 0–1; low but flexible' },
      conductivity: { type: 'decimal', description: 'Thermal conductivity 0–1' },
      magicAffinity: { type: 'decimal', description: 'Capacity to hold enchantment 0–1; moderate — bioluminescent nature enhances magical bonding' },
      isLuminous:   { type: 'boolean', description: 'Stamped true at process time when processed during twilight hours, false otherwise; must be read as stored state at treat time — not re-derived from current time-of-day; determines whether moon-oil treatment is valid' },
    },
    stateMachine: fibreStateMachine(),
    behaviors: {
      process: {
        description: 'Shred bark strips into weavable duskfiber thread at a processing bench',
        rules: [
          'Requires Woodworking: Apprentice or Textile: Apprentice — either suffices',
          'Processing in daylight hours yields standard thread; twilight hours yield luminous thread',
        ],
        auth: { roles: ['maintainer'] },
      },
      treat: {
        description: 'Infuse processed duskfiber with moon-oil to lock in bioluminescence',
        rules: [
          'Moon-oil is a rare alchemical reagent — one vial treats ten bundles',
          'Treatment requires isLuminous = true; the crafting system must reject the treat trigger on non-luminous thread — this guard is not encoded in the state machine and must be enforced at the application layer',
          'Treated luminous thread retains glow permanently; untreated luminous thread fades after two in-game days',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
