// Phase 43 — where a material occurs in the ground, as ENTITY FIELDS rather than a
// GDScript table. The runtime ore field (src/terrain/ore_field.gd) reads these off the
// generated material resources, so the band a vein is gated by cannot disagree with the
// fabric: it IS the fabric value.
//
//   depthBand — the half-open band [min, max) of depth, in world units BELOW the tile's
//               natural surface, inside which a vein of this material may sit. A band with
//               max <= min is EMPTY: the material is never a ground vein (woods grow as
//               trees, alloys are smelted).
//   leyGated  — true when a vein of this material only forms near a ley line.
//
// Authored from the prose each material already carries; the `why` string is that prose's
// claim, restated next to the number it justifies.
function depositFields({ min, max, leyGated = false, why }) {
  return {
    depthBand: {
      type: 'json',
      description: `Depth band [min, max) in world units below the natural surface where a vein may form; empty when max <= min. ${why}`,
      defaultValue: { min, max },
    },
    leyGated: {
      type: 'boolean',
      description: 'True when a vein of this material forms only near a ley line',
      defaultValue: leyGated,
    },
  }
}

module.exports = { depositFields }
