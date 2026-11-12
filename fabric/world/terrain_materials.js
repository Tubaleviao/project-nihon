const fs = require('fs')
const path = require('path')
const { defineEntity } = require('@newel/core')

// Phase 242 — terrain materials: the textures natural ground is drawn with. Not to be confused with
// the block materials in ./materials (Grass, Sand, Snow… are things a player mines and carries); a
// terrain material is only how the ground looks. Each one owns a layer of the terrain shader's
// texture arrays and says where it shows:
//
// - `biomes`: the biomes whose flat ground it covers. Every biome resolves to at least one.
// - `slopeMin`: degrees from flat above which ground turns to it (rock on cliffs), whatever the biome.
// - `aboveSnowLine`: it covers ground above the biome's `snowLine` (metres above sea level).
// - `nearWater`: metres from a lake, river or sea edge within which it covers wet ground.
//
// The per-vertex weights are a pure function of these (src/terrain/terrain_weights.gd). Textures are
// CC0 (credited in assets/README.md), so they are public and are also the placeholder for later
// production art: `<textureKey>_{albedo,normal,roughness}.jpg.raw` under assets/.

const MAPS = ['albedo', 'normal', 'roughness']
const ASSETS = path.join(__dirname, '..', '..', 'assets')
// The mesh carries every layer's weight per vertex in two RGBA8 arrays (CUSTOM0 = layers 0-3, CUSTOM1 =
// layers 4-7), so weights interpolate correctly across a triangle whose corners use different
// materials; that caps the table at eight layers. A vertex still blends at most four of them.
const MAX_LAYERS = 8
// Metres along one chunk edge (TerrainSlice.CHUNK_METERS: 64 tiles x 0.5 m). The shader maps textures
// from scene positions, and an origin rebase shifts the scene by whole chunks, so a texture tile that
// does not fit a chunk a whole number of times would jump at every rebase: `scale` must divide it.
const CHUNK_METRES = 32

function terrainMaterial({ description, goal, layer, textureKey, scale, biomes = [], slopeMin = -1,
  aboveSnowLine = false, nearWater = -1 }) {
  return defineEntity({
    tags: ['terrain_material'],
    description,
    goal,
    fields: {
      id:            { type: 'uuid', primaryKey: true },
      layer:         { type: 'integer', description: 'Index of this material in the terrain shader\'s texture arrays and its weight channel in CUSTOM0/CUSTOM1 (Phase 242)', defaultValue: layer },
      textureKey:    { type: 'string', description: 'Asset key prefix; the maps are <key>_albedo/_normal/_roughness.jpg.raw under assets/ (Phase 242)', defaultValue: textureKey },
      scale:         { type: 'decimal', description: 'Metres of ground one texture tile covers (Phase 242)', defaultValue: scale },
      biomes:        { type: 'json', description: 'Biomes whose flat ground this material covers (Phase 242)', defaultValue: biomes },
      slopeMin:      { type: 'decimal', description: 'Degrees from flat above which ground is this material whatever the biome; -1 = never (Phase 242)', defaultValue: slopeMin },
      aboveSnowLine: { type: 'boolean', description: 'Whether this material covers ground above the biome\'s snowLine (Phase 242)', defaultValue: aboveSnowLine },
      nearWater:     { type: 'decimal', description: 'Metres from open water within which this material covers wet ground; -1 = never (Phase 242)', defaultValue: nearWater },
    },
  })
}

const TERRAIN_MATERIALS = {
  TerrainGrass: terrainMaterial({
    description: 'Short green turf: the ground of the temperate belt, the taiga and the savanna.',
    goal: 'The most common ground a player walks on',
    layer: 0, textureKey: 'textures/terrain/grass', scale: 4,
    biomes: ['TemperateForest', 'TemperateGrassland', 'Taiga', 'Savanna'],
  }),
  TerrainDirt: terrainMaterial({
    description: 'Dry brown soil and ash: the volcanic badlands.',
    goal: 'Bare earth where nothing grows',
    layer: 1, textureKey: 'textures/terrain/dirt', scale: 4,
    biomes: ['VolcanicBadlands'],
  }),
  TerrainMoss: terrainMaterial({
    description: 'Mossy forest floor under the twilight canopy.',
    goal: 'Give the twilight grove its own ground',
    layer: 2, textureKey: 'textures/terrain/moss', scale: 4,
    biomes: ['TwilightGrove'],
  }),
  TerrainRock: terrainMaterial({
    description: 'Bare grey rock: cliffs and steep slopes everywhere, and the floor of the void rift.',
    goal: 'Read steep ground as stone, not as stretched grass',
    layer: 3, textureKey: 'textures/terrain/rock', scale: 6.4,
    biomes: ['VoidRift'], slopeMin: 40,
  }),
  TerrainSand: terrainMaterial({
    description: 'Pale sand: beaches, deserts and the sea floor.',
    goal: 'Make shores and deserts readable from a distance',
    layer: 4, textureKey: 'textures/terrain/sand', scale: 4,
    biomes: ['Ocean', 'Beach', 'Desert'],
  }),
  TerrainSnow: terrainMaterial({
    description: 'Packed snow: the tundra, the alpine peaks and any ground above its biome\'s snow line.',
    goal: 'Mark cold and high ground',
    layer: 5, textureKey: 'textures/terrain/snow', scale: 6.4,
    biomes: ['Tundra', 'Alpine'], aboveSnowLine: true,
  }),
  TerrainMud: terrainMaterial({
    description: 'Wet dark mud along lake shores and river banks.',
    goal: 'Show where the ground meets fresh water',
    layer: 6, textureKey: 'textures/terrain/mud', scale: 3.2,
    nearWater: 3,
  }),
}

// Returns the problems found; empty when every biome resolves to a material, layers are 0..n-1 with
// no gap or repeat, every named biome exists and every map file is in assets/.
function terrainMaterialProblems(materials, biomes, assetsDir = ASSETS) {
  const problems = []
  const biomeNames = new Set(Object.keys(biomes))
  const covered = new Set()
  const layers = new Map()
  const value = (m, f) => m.fields && m.fields[f] && m.fields[f].defaultValue
  for (const [name, m] of Object.entries(materials)) {
    const layer = value(m, 'layer')
    if (!Number.isInteger(layer) || layer < 0 || layer >= MAX_LAYERS) problems.push(`terrain material ${name}: layer ${layer} is outside 0..${MAX_LAYERS - 1}`)
    else if (layers.has(layer)) problems.push(`terrain material ${name}: layer ${layer} is also ${layers.get(layer)}'s`)
    else layers.set(layer, name)
    const scale = value(m, 'scale')
    if (!(typeof scale === 'number' && scale > 0)) problems.push(`terrain material ${name}: scale must be a positive number of metres`)
    else if (Math.abs(CHUNK_METRES / scale - Math.round(CHUNK_METRES / scale)) > 1e-9) problems.push(`terrain material ${name}: scale ${scale} must fit a ${CHUNK_METRES} m chunk a whole number of times (the texture would jump at an origin rebase)`)
    const list = value(m, 'biomes')
    if (!Array.isArray(list)) problems.push(`terrain material ${name}: biomes must be a list`)
    else for (const b of list) {
      if (!biomeNames.has(b)) problems.push(`terrain material ${name}: names unknown biome "${b}"`)
      covered.add(b)
    }
    const slope = value(m, 'slopeMin')
    if (!(slope === -1 || (typeof slope === 'number' && slope > 0 && slope < 90))) problems.push(`terrain material ${name}: slopeMin must be -1 or in (0, 90) degrees`)
    const wet = value(m, 'nearWater')
    if (!(wet === -1 || (typeof wet === 'number' && wet > 0))) problems.push(`terrain material ${name}: nearWater must be -1 or a positive distance`)
    const key = value(m, 'textureKey')
    if (typeof key !== 'string' || !key) problems.push(`terrain material ${name}: no textureKey`)
    else for (const map of MAPS) {
      const file = `${key}_${map}.jpg.raw`
      if (!fs.existsSync(path.join(assetsDir, file))) problems.push(`terrain material ${name}: texture ${file} has no file in assets/`)
    }
  }
  const n = layers.size
  for (let i = 0; i < n; i++) if (!layers.has(i)) problems.push(`terrain material layers skip ${i}: layers must be 0..${n - 1}`)
  for (const b of biomeNames) {
    if (!covered.has(b)) problems.push(`biome ${b} resolves to no terrain material`)
    const line = value(biomes[b], 'snowLine')
    if (typeof line !== 'number') problems.push(`biome ${b} declares no numeric snowLine`)
  }
  if (!Object.values(materials).some((m) => value(m, 'aboveSnowLine') === true)) problems.push('no terrain material covers ground above the snow line')
  return problems
}

function validateTerrainMaterials(materials, biomes, assetsDir = ASSETS) {
  const problems = terrainMaterialProblems(materials, biomes, assetsDir)
  if (problems.length) throw new Error(`Terrain materials: ${problems.join('; ')}`)
}

module.exports = { TERRAIN_MATERIALS, MAPS, CHUNK_METRES, terrainMaterialProblems, validateTerrainMaterials }
