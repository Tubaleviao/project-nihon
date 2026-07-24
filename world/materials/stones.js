const { defineEntity } = require('@newel/core')

// Stone transitions: raw → dressed (cut to shape) → inscribed (rune-carved, terminal)
function stoneStateMachine() {
  return {
    field: 'state',
    initial: 'raw',
    states: {
      raw:       'Rough quarried block; heavy but structurally sound',
      dressed:   'Cut and smoothed for construction or decorative use',
      inscribed: { description: 'Rune-carved by a mason-arcanist; permanently enchanted', terminal: true },
    },
    transitions: [
      { from: 'raw',     to: 'dressed',   trigger: 'dress' },
      { from: 'dressed', to: 'inscribed', trigger: 'inscribe' },
    ],
  }
}

module.exports = {

  // ─── Ashite ───────────────────────────────────────────────────────────────
  Ashite: defineEntity({
    role: 'material',
    description:
      'Pale grey volcanic rock formed from compressed volcanic ash. ' +
      'Lightweight for its volume and naturally insulating; the standard building stone ' +
      'for heated workshops and cold-climate settlements.',
    goal: 'Versatile, abundant early-game building stone with a thermal advantage',
    fields: {
      id:           { type: 'uuid', primaryKey: true },
      state:        { type: 'enum', values: ['raw', 'dressed', 'inscribed'] },
      density:      { type: 'decimal', description: 'g/cm³; notably light for a stone' },
      hardness:     { type: 'decimal', description: 'Mohs equivalent 0–10' },
      conductivity: { type: 'decimal', description: 'Thermal conductivity 0–1; low, good insulator' },
      magicAffinity: { type: 'decimal', description: 'Weak affinity; holds basic ward runes' },
    },
    stateMachine: stoneStateMachine(),
    behaviors: {
      dress: {
        description: 'Cut and face raw ashite blocks at a player-built masonry bench',
        rules: [
          'Three raw blocks yield two dressed blocks (waste fraction removed during cutting)',
          'Ashite dust produced during dressing is an alchemical component',
        ],
        auth: { roles: ['maintainer'] },
      },
      inscribe: {
        description: 'Carve runic patterns into dressed ashite to embed a permanent effect',
        rules: [
          'Ashite accepts heat-ward and cold-ward runes only',
          'Inscribed blocks must be placed in a structure before activation — free-standing runes are inert',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Lumenfite ────────────────────────────────────────────────────────────
  Lumenfite: defineEntity({
    role: 'material',
    description:
      'Translucent crystalline mineral that absorbs ambient light during the day and ' +
      'releases it slowly at night. Found in shallow cave systems and cliff faces. ' +
      'Valued for lighting infrastructure without open flames.',
    goal: 'Provide a reliable, player-craftable light source that drives infrastructure investment',
    fields: {
      id:           { type: 'uuid', primaryKey: true },
      state:        { type: 'enum', values: ['raw', 'dressed', 'inscribed'] },
      density:      { type: 'decimal', description: 'g/cm³; moderate' },
      hardness:     { type: 'decimal', description: 'Mohs equivalent; brittle, shatters under impact' },
      conductivity: { type: 'decimal', description: '0–1; conducts light energy, not heat' },
      magicAffinity: { type: 'decimal', description: 'High affinity for light-type enchantments' },
    },
    stateMachine: stoneStateMachine(),
    behaviors: {
      dress: {
        description: 'Facet raw lumenfite shards to maximise light refraction at a jeweller bench',
        rules: [
          'Requires Masonry: Apprentice or Jewellery: Apprentice',
          'Poorly cut shards emit dim scattered light; precision cutting increases brightness radius',
        ],
        auth: { roles: ['maintainer'] },
      },
      inscribe: {
        description: 'Engrave a flux rune to increase charge capacity or alter emission colour',
        rules: [
          'Colour runes change emission spectrum but do not increase brightness',
          "Flux runes must be aligned with the crystal's natural axis or the shard shatters",
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
