const { defineEntity } = require('@newel/core')

// Shared state machine for every material: raw → refined → enchanted (terminal)
// NOTE: state keys must be kept in sync with each consumer entity's `state` enum values — the normalizer does not reconcile them.
function materialStateMachine() {
  return {
    field: 'state',
    initial: 'raw',
    states: {
      raw:       'Ore or unprocessed form; must be smelted or worked before use',
      refined:   'Processed ingot or sheet; ready for crafting',
      enchanted: { description: 'Imbued with magical energy at an arcane forge', terminal: true },
    },
    transitions: [
      { from: 'raw',     to: 'refined',   trigger: 'refine' },
      { from: 'refined', to: 'enchanted', trigger: 'enchant' },
    ],
  }
}

module.exports = {

  // ─── Ferrite ──────────────────────────────────────────────────────────────
  Ferrite: defineEntity({
    tags: ['material'],
    description:
      'Common dark-grey metal found in surface veins across temperate biomes, volcanic lava-tube edges, ' +
      'and stabilised sections of void rifts. ' +
      'Abundant but brittle when thin; the backbone of early-game tooling.',
    goal: 'Serve as the entry-level metallic material, readily available to new players',
    fields: {
      id:           { type: 'uuid', primaryKey: true },
      state:        { type: 'enum', values: ['raw', 'refined', 'enchanted'] },
      density:      { type: 'decimal', description: 'g/cm³; governs item weight', defaultValue: 7.2 },
      hardness:     { type: 'decimal', description: 'Mohs-equivalent scale 1–10', defaultValue: 4.5 },
      conductivity: { type: 'decimal', description: 'Thermal conductivity rating 0–1', defaultValue: 0.4 },
      magicAffinity: { type: 'decimal', description: 'Capacity to hold enchantment 0–1', defaultValue: 0.1 },
    },
    stateMachine: materialStateMachine(),
    behaviors: {
      refine: {
        description: 'Smelt raw ferrite ore into refined ingots at a forge',
        rules: [
          'Requires a functional forge structure',
          'Two raw ferrite ore yield one refined ingot',
        ],
        auth: { roles: ['maintainer'] },
      },
      enchant: {
        description: 'Imbue a refined ingot at an arcane forge to unlock enchanted state',
        rules: [
          'Ferrite holds weak enchantments only; magical capacity capped at 0.3',
          'Enchanting consumes one enchanted aethermite shard as a catalyst; Aethermite.consume is invoked on the spent shard — the shard transitions to consumed state and is removed from inventory entirely',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Veilsteel ────────────────────────────────────────────────────────────
  Veilsteel: defineEntity({
    tags: ['material'],
    description:
      'Blue-black alloy smelted from ferrite ingots and aethermite shards under high heat. ' +
      'Extremely hard but non-conductive; absorbs magical interference, making it ideal for anti-magic armor.',
    goal: 'Provide a mid-tier martial metal that counters magic-heavy builds',
    fields: {
      id:           { type: 'uuid', primaryKey: true },
      state:        { type: 'enum', values: ['unalloyed', 'refined', 'enchanted'] },
      density:      { type: 'decimal', description: 'g/cm³; governs item weight', defaultValue: 8.1 },
      hardness:     { type: 'decimal', description: 'Mohs-equivalent scale 1–10', defaultValue: 7.8 },
      conductivity: { type: 'decimal', description: 'Thermal conductivity rating 0–1', defaultValue: 0.05 },
      magicAffinity: { type: 'decimal', description: 'Capacity to hold enchantment 0–1; deliberately low — anti-magic is an intrinsic structural trait, not a held enchantment', defaultValue: 0.05 },
    },
    stateMachine: {
      field: 'state',
      initial: 'unalloyed',
      states: {
        unalloyed: 'Raw component inputs assembled and ready for alloying — no veilsteel ore exists in the world',
        refined:   'Alloyed ingot; ready for smithing into armour or weapons',
        enchanted: { description: 'Void-attuned via voidite-catalyst binding; magical resistance is structural, not additive', terminal: true },
      },
      transitions: [
        { from: 'unalloyed', to: 'refined',   trigger: 'refine' },
        { from: 'refined',   to: 'enchanted', trigger: 'enchant' },
      ],
    },
    behaviors: {
      refine: {
        description: 'Alloy ferrite ingots and aethermite shards in a master forge',
        rules: [
          'Requires Smithing: Journeyman',
          'Three ferrite ingots and one refined aethermite shard (form = shard; aethermite dust is not accepted) yield one veilsteel ingot — the shard is an alloying input consumed as a crafting ingredient, not a catalyst; Aethermite.consume is not invoked',
          'Process collapses if forge temperature falls below threshold mid-smelt',
        ],
        auth: { roles: ['maintainer'] },
      },
      enchant: {
        description: 'Veilsteel resists conventional enchanting; only void-aligned spells bind',
        rules: [
          'Only Voidite-catalyst enchantments succeed on veilsteel',
          'magicAffinity is capped at 0.15 even after enchanting',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Aethermite ───────────────────────────────────────────────────────────
  Aethermite: defineEntity({
    tags: ['material'],
    description:
      'Pale silver ore that hums faintly in the presence of active magic. ' +
      'Found deep underground near ley lines and in meteor craters. ' +
      'The primary catalyst for enchanting and arcane crafting.',
    goal: 'Act as the universal enchanting catalyst and magical progression gate',
    fields: {
      id:           { type: 'uuid', primaryKey: true },
      state:        { type: 'enum', values: ['raw', 'refined', 'enchanted', 'consumed'] },
      form:         { type: 'enum', values: ['dust', 'shard'], description: 'Output form from refining: dust (from grinding) or shard (from smelting); set at refine time; recipes specify which form is accepted — Veilsteel.refine requires shard' },
      density:      { type: 'decimal', description: 'g/cm³; governs item weight', defaultValue: 4.3 },
      hardness:     { type: 'decimal', description: 'Mohs-equivalent scale 1–10', defaultValue: 5.0 },
      conductivity: { type: 'decimal', description: 'Thermal conductivity rating 0–1', defaultValue: 0.6 },
      magicAffinity: { type: 'decimal', description: 'Capacity to hold enchantment 0–1', defaultValue: 0.8 },
    },
    stateMachine: {
      field: 'state',
      initial: 'raw',
      states: {
        raw:      'Ore or unprocessed form; must be worked at an arcane forge',
        refined:  'Processed form; either dust (ground) or shard (smelted) — see form field',
        enchanted: 'Imbued with magical energy; emits faint glow; ready for use as a crafting catalyst',
        consumed: { description: 'Spent as a crafting catalyst and removed from inventory; no further transitions', terminal: true },
      },
      transitions: [
        { from: 'raw',       to: 'refined',   trigger: 'refine' },
        { from: 'refined',   to: 'enchanted', trigger: 'enchant' },
        { from: 'enchanted', to: 'consumed',  trigger: 'consume' },
      ],
    },
    behaviors: {
      refine: {
        description: 'Grind raw ore into aethermite dust or smelt into shards at an arcane forge; the desired output form must be specified',
        rules: [
          'Requires Arcane Forging: Apprentice',
          'Raw ore must be worked at a player-built arcane forge — standard forges shatter it',
          'Grinding produces dust (form = dust); smelting produces shards (form = shard); form is stamped on the item at refine time and cannot be changed afterward',
        ],
        auth: { roles: ['maintainer'] },
      },
      enchant: {
        description: 'Aethermite becomes a living enchantment vessel in its enchanted state',
        rules: [
          'magicAffinity reaches 1.0; the material emits a faint glow',
          'Enchanted shards are consumed as single-use crafting components via Aethermite.consume',
        ],
        auth: { roles: ['maintainer'] },
      },
      consume: {
        description: 'Destroy an enchanted aethermite shard when it is spent as a crafting catalyst; transitions state to consumed',
        rules: [
          'Consumption is triggered by the crafting system when the shard is used — the item is removed from inventory entirely',
          'No partial consumption: the full shard is spent per catalyst use',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Voidite ──────────────────────────────────────────────────────────────
  Voidite: defineEntity({
    tags: ['material'],
    description:
      'Jet-black crystalline ore found only in void-touched biomes and deep rifts. ' +
      'Extremely rare, highly conductive of void-type magic; dangerously unstable in raw form.',
    goal: 'Serve as the rarest, most powerful — and most dangerous — late-game magical material',
    fields: {
      id:           { type: 'uuid', primaryKey: true },
      state:        { type: 'enum', values: ['raw', 'refined', 'enchanted'] },
      density:      { type: 'decimal', description: 'g/cm³; governs item weight', defaultValue: 9.5 },
      hardness:     { type: 'decimal', description: 'Mohs-equivalent scale 1–10', defaultValue: 8.5 },
      conductivity: { type: 'decimal', description: 'Thermal conductivity rating 0–1', defaultValue: 0.9 },
      magicAffinity: { type: 'decimal', description: 'Capacity to hold enchantment 0–1', defaultValue: 0.95 },
    },
    stateMachine: materialStateMachine(),
    behaviors: {
      refine: {
        description: 'Stabilise raw voidite through void-tuned smelting in a specially shielded forge',
        rules: [
          'Requires Void Smithing: Expert — an esoteric skill unlocked only via experimentation',
          'Raw voidite emits void pulses that corrupt nearby items; shielded forge room mandatory',
          'One raw crystal yields one refined shard; failures may cause a void burst event — surviving such a burst grants the voidBurstSurvivor flag regardless of tile location (same flag as VoidRift.applyHazards; either source is sufficient)',
        ],
        auth: { roles: ['maintainer'] },
      },
      enchant: {
        description: 'Void-attune a refined shard to its maximum magical capacity',
        rules: [
          'Only players who have survived a void burst (voidBurstSurvivor flag, granted by surviving any void burst — via VoidRift.applyHazards or Voidite.refine failure) may learn to enchant voidite',
          'Enchanted voidite cannot be stored in standard item bags without void-lining',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
