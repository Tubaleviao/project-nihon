const { defineEntity } = require('./shared')

// ─────────────────────────────────────────────────────────────────────────────
// Palette (characters.md §19)
//
// One shared 256-entry palette. Each color index is one byte (network encoding,
// shader sampler, and per-character persistence cost). Colors are authored as
// hex strings so artists can copy them straight from a color picker; the
// runtime slice converts hex → Color.
//
// The 256 entries are grouped into 32-entry regions (skin, hair, primary,
// secondary, accent, metal, emission, misc) and built by interpolating anchor
// colors within each region. Region index layout:
//   0-31    skin
//   32-63   hair / fur
//   64-95   primary cloth / armor
//   96-127  secondary cloth / armor
//   128-159 accent / trim
//   160-191 metals
//   192-223 emission / glow
//   224-255 eyes / misc
// ─────────────────────────────────────────────────────────────────────────────

const PALETTE_SIZE = 256
const REGION_SIZE = 32

// Named region layout (characters.md §19). The 256 entries are grouped into
// eight 32-entry regions in this order; region bounds are derived from this
// list (index * REGION_SIZE .. (index + 1) * REGION_SIZE - 1) so runtime code
// and the generated GameData agree on the metals (160–191) and emission
// (192–223) regions without hardcoding the numbers.
const REGION_NAMES = ['skin', 'hair', 'primary', 'secondary', 'accent', 'metals', 'emission', 'eyes']
const REGIONS = REGION_NAMES.map((name, i) => ({
  name,
  start: i * REGION_SIZE,
  end: (i + 1) * REGION_SIZE - 1,
}))

// Anchor colors per 32-entry region, as [r, g, b] (0-255).
const PALETTE_REGIONS = [
  [[255, 235, 214], [219, 168, 133], [133, 82, 51]],
  [[13, 10, 13], [92, 59, 33], [158, 117, 56], [219, 219, 219]],
  [[41, 77, 133], [71, 115, 82], [158, 46, 46], [235, 199, 77]],
  [[230, 230, 230], [184, 184, 189], [77, 77, 87], [31, 26, 26]],
  [[230, 158, 41], [204, 71, 56], [61, 133, 158], [107, 71, 158]],
  [[77, 77, 82], [140, 128, 112], [184, 153, 107], [230, 224, 204]],
  [[41, 153, 235], [51, 235, 133], [235, 71, 71], [158, 77, 235]],
  [[20, 89, 179], [51, 166, 115], [140, 89, 51], [179, 179, 179]],
]

function lerp(a, b, t) {
  return a + (b - a) * t
}

function lerpRgb(a, b, t) {
  return [
    Math.round(lerp(a[0], b[0], t)),
    Math.round(lerp(a[1], b[1], t)),
    Math.round(lerp(a[2], b[2], t)),
  ]
}

function expandAnchors(anchors, count) {
  const out = []
  if (anchors.length === 1) {
    for (let i = 0; i < count; i++) out.push(anchors[0])
    return out
  }
  const segments = anchors.length - 1
  for (let i = 0; i < count; i++) {
    const t = (i / (count - 1)) * segments
    const seg = Math.min(Math.floor(t), segments - 1)
    const local = t - seg
    out.push(lerpRgb(anchors[seg], anchors[seg + 1], local))
  }
  return out
}

function toHex([r, g, b]) {
  const hex = (n) => n.toString(16).padStart(2, '0')
  return `#${hex(r)}${hex(g)}${hex(b)}`
}

function buildDefaultPalette() {
  const entries = []
  for (const anchors of PALETTE_REGIONS) {
    for (const rgb of expandAnchors(anchors, 32)) {
      entries.push(toHex(rgb))
    }
  }
  return entries
}

module.exports = {

  DefaultPalette: defineEntity({
    tags: ['palette'],
    description:
      'The single shared 256-entry palette for the character system. ' +
      'Characters store color indices; the shader samples this palette texture. ' +
      'One byte per index keeps network and persistence cost flat (§19).',
    goal: 'Define the controlled color space that preserves the pixel-art art direction',
    fields: {
      entries: {
        type: 'json',
        description: `256 hex color strings, region-grouped (§19)`,
        defaultValue: buildDefaultPalette(),
      },
      regions: {
        type: 'json',
        description: 'Named 32-entry region bounds for the 256-entry palette (§19)',
        defaultValue: REGIONS,
      },
    },
  }),

}

module.exports.PALETTE_SIZE = PALETTE_SIZE
module.exports.REGION_SIZE = REGION_SIZE
module.exports.REGIONS = REGIONS
module.exports.METALS_REGION = REGIONS[5]
module.exports.EMISSION_REGION = REGIONS[6]
