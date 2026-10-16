// Phase 137 — which ground covers settle. Sand, Snow and Soil are material entities and carry the
// `granular` field themselves; Grass is one too (turf, not granular). Moss, Ash and Void are covers a
// biome can name that have no entity, so their answer is declared here. `validateGranular` runs when the
// fabric loads, so `npm run validate` fails on a biome whose `surfaceMaterial` declares no `granular`.
const COVER_GRANULAR = { Moss: false, Ash: false, Void: false }

// Returns the problems found; empty when every biome's cover declares `granular` as a boolean and the
// table does not contradict an entity.
function granularProblems(biomes, materials, covers = COVER_GRANULAR) {
  const problems = []
  for (const [name, mat] of Object.entries(materials)) {
    const f = mat.fields && mat.fields.granular
    if (f === undefined) problems.push(`material ${name} declares no \`granular\` field`)
    else if (typeof f.defaultValue !== 'boolean') problems.push(`material ${name}: \`granular\` must be a boolean`)
    if (Object.hasOwn(covers, name)) problems.push(`cover ${name} is declared both as a material and in COVER_GRANULAR`)
  }
  for (const [key, biome] of Object.entries(biomes)) {
    const field = biome.fields && biome.fields.surfaceMaterial
    const cover = field && field.defaultValue
    if (cover === undefined) continue
    const mat = materials[cover]
    const declared = mat ? mat.fields && mat.fields.granular && mat.fields.granular.defaultValue : covers[cover]
    if (typeof declared !== 'boolean') problems.push(`biome ${key}: surfaceMaterial "${cover}" does not declare \`granular\``)
  }
  return problems
}

function validateGranular(biomes, materials, covers = COVER_GRANULAR) {
  const problems = granularProblems(biomes, materials, covers)
  if (problems.length) throw new Error(`Granular materials: ${problems.join('; ')}`)
}

module.exports = { COVER_GRANULAR, granularProblems, validateGranular }
