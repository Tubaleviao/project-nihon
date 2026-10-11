// Phase 112 — which biomes may not lie side by side, and what lies between them instead.
//
// The table is authored once, here, and every biome entity takes its two fields from it
// (`adjacencyFields`). `validateAdjacency` runs when the fabric loads, so `npm run validate` fails on
// an unknown key, an asymmetric pair, or a forbidden pair with no usable transition.
//
// `forbiddenNeighbours`: biome keys that must not touch this biome across a chunk edge (4-neighbour).
// `transition`: the biome that lies between this one and a forbidden neighbour. Phase 113 reads it.

const ADJACENCY = {
  // Cold biomes against hot or arid ones.
  Tundra:           { forbiddenNeighbours: ['Desert', 'VolcanicBadlands'], transition: 'Taiga' },
  Desert:           { forbiddenNeighbours: ['Tundra'], transition: 'Savanna' },
  VolcanicBadlands: { forbiddenNeighbours: ['Tundra'], transition: 'Alpine' },
  // No rule.
  Taiga: { forbiddenNeighbours: [], transition: '' },
  Savanna: { forbiddenNeighbours: [], transition: '' },
  TemperateForest: { forbiddenNeighbours: [], transition: '' },
  TemperateGrassland: { forbiddenNeighbours: [], transition: '' },
  TwilightGrove: { forbiddenNeighbours: [], transition: '' },
  VoidRift: { forbiddenNeighbours: [], transition: '' },
  Ocean: { forbiddenNeighbours: [], transition: '' },
  Beach: { forbiddenNeighbours: [], transition: '' },
  Alpine: { forbiddenNeighbours: [], transition: '' },
}

/** Problems with an adjacency table (`{ key: { forbiddenNeighbours, transition } }`), as strings. */
function adjacencyProblems(table, knownKeys) {
  const known = new Set(knownKeys)
  const problems = []
  for (const [key, row] of Object.entries(table)) {
    if (!known.has(key)) problems.push(`adjacency: row for unknown biome "${key}"`)
    const forbidden = row.forbiddenNeighbours || []
    for (const other of forbidden) {
      if (!known.has(other)) { problems.push(`adjacency: ${key}.forbiddenNeighbours names unknown biome "${other}"`); continue }
      if (other === key) problems.push(`adjacency: ${key} forbids itself`)
      else if (!(table[other]?.forbiddenNeighbours || []).includes(key)) {
        problems.push(`adjacency: ${key} forbids ${other} but ${other} does not forbid ${key} (asymmetric pair)`)
      }
    }
    if (forbidden.length === 0) continue
    const t = row.transition
    if (!t) problems.push(`adjacency: ${key} has forbidden neighbours but no transition`)
    else if (!known.has(t)) problems.push(`adjacency: ${key}.transition names unknown biome "${t}"`)
    else if (t === key || forbidden.includes(t)) problems.push(`adjacency: ${key}.transition "${t}" is the biome itself or one of its forbidden neighbours`)
    else for (const other of forbidden) {
      if ((table[t]?.forbiddenNeighbours || []).includes(other)) {
        problems.push(`adjacency: ${key}.transition "${t}" is itself forbidden next to ${other}`)
      }
    }
  }
  for (const key of known) if (!table[key]) problems.push(`adjacency: biome "${key}" has no row`)
  return problems
}

function validateAdjacency(table, knownKeys) {
  const problems = adjacencyProblems(table, knownKeys)
  if (problems.length) throw new Error('Biome adjacency table is invalid:\n  ' + problems.join('\n  '))
}

/** The two entity fields for biome `key`. */
function adjacencyFields(key) {
  const row = ADJACENCY[key]
  if (!row) throw new Error(`adjacency: no row for biome "${key}"`)
  return {
    forbiddenNeighbours: { type: 'json', description: 'Biome keys that must not lie across a chunk edge from this biome; symmetric, validated at fabric load (Phase 112)', defaultValue: row.forbiddenNeighbours },
    transition: { type: 'string', description: 'The biome that lies between this one and a forbidden neighbour; empty when nothing is forbidden (Phase 112)', defaultValue: row.transition },
  }
}

module.exports = { ADJACENCY, adjacencyProblems, validateAdjacency, adjacencyFields }
