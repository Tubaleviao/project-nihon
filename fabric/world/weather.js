const { defineEntity } = require('@newel/core')

// Phase 128 — the weather table. The runtime (src/world/weather_slice.gd) reads it from
// GameData.WORLD_SYSTEMS["WeatherSystem"].rules and rolls a state per weather cell and `hoursPerRoll`
// in-game hours from the world seed, so every host and client computes the same weather.
//
// WeatherState fields (one entry per state in `states`):
//   moveSpeedFactor / visibilityFactor: multipliers in 0..1 on outdoor walking speed / view distance.
//   minTemperature / maxTemperature: °C of the cell's seasonal temperature the state needs (inclusive).
//   minRainfall: mm per in-game year of the biome the state needs.
//   weight: relative chance among the states the cell allows (>= 0).
//   biomes: when non-empty, only these biomes can roll the state.
//   exceptBiomes: biomes that never roll the state.
// `climate` gives a biome's annual { temperature, rainfall } where the biome authors none (its
// avgTemperature / avgRainfall are 0), so a temperate forest does not read as a freezing desert.
const RULES = {
  cellSizeChunks: 64,
  hoursPerRoll: 6,
  overrideMaxHours: 48,
  states: {
    clear:            { moveSpeedFactor: 1.0, visibilityFactor: 1.0, minTemperature: -100, maxTemperature: 100, minRainfall: 0,   weight: 6, biomes: [], exceptBiomes: [] },
    rain:             { moveSpeedFactor: 0.95, visibilityFactor: 0.8, minTemperature: 0,   maxTemperature: 100, minRainfall: 200, weight: 3, biomes: [], exceptBiomes: ['VoidRift'] },
    storm:            { moveSpeedFactor: 0.7, visibilityFactor: 0.6, minTemperature: 5,   maxTemperature: 100, minRainfall: 400, weight: 1, biomes: [], exceptBiomes: ['VoidRift'] },
    blizzard:         { moveSpeedFactor: 0.6, visibilityFactor: 0.4, minTemperature: -100, maxTemperature: 0,  minRainfall: 100, weight: 2, biomes: [], exceptBiomes: ['VoidRift'] },
    fog:              { moveSpeedFactor: 1.0, visibilityFactor: 0.5, minTemperature: -10, maxTemperature: 25,  minRainfall: 300, weight: 1.5, biomes: [], exceptBiomes: ['VoidRift'] },
    ash_fall:         { moveSpeedFactor: 0.9, visibilityFactor: 0.5, minTemperature: -100, maxTemperature: 100, minRainfall: 0,  weight: 3, biomes: ['VolcanicBadlands'], exceptBiomes: [] },
    electrical_storm: { moveSpeedFactor: 0.8, visibilityFactor: 0.7, minTemperature: -100, maxTemperature: 100, minRainfall: 0,  weight: 3, biomes: ['TwilightGrove'], exceptBiomes: [] },
    void_storm:       { moveSpeedFactor: 0.9, visibilityFactor: 0.6, minTemperature: -100, maxTemperature: 100, minRainfall: 0,  weight: 4, biomes: ['VoidRift'], exceptBiomes: [] },
  },
  climate: {
    TemperateForest:    { temperature: 10, rainfall: 900 },
    TemperateGrassland: { temperature: 12, rainfall: 600 },
    TwilightGrove:      { temperature: 10, rainfall: 700 },
    VolcanicBadlands:   { temperature: 30, rainfall: 100 },
    VoidRift:           { temperature: 10, rainfall: 0 },
  },
}

const STATE_FIELDS = ['moveSpeedFactor', 'visibilityFactor', 'minTemperature', 'maxTemperature', 'minRainfall', 'weight', 'biomes', 'exceptBiomes']
const RULE_FIELDS = ['cellSizeChunks', 'hoursPerRoll', 'overrideMaxHours', 'states', 'climate']
const MAX_CELL_CHUNKS = 4096
const MAX_HOURS = 24 * 365

/** True when `state` may roll in `biome` at seasonal `temperature` (°C) and annual `rainfall` (mm). */
function stateAllows(state, biome, temperature, rainfall) {
  if (state.biomes.length > 0 && !state.biomes.includes(biome)) return false
  if (state.exceptBiomes.includes(biome)) return false
  return temperature >= state.minTemperature && temperature <= state.maxTemperature && rainfall >= state.minRainfall
}

/**
 * Problems with a weather rule table, as strings. `biomes` (optional) maps biome key to
 * { avgTemperature, avgRainfall, seasonSwing } and enables the "every biome reaches a state" check.
 */
function weatherProblems(rules, biomes) {
  const problems = []
  const isNum = (v) => typeof v === 'number' && Number.isFinite(v)
  for (const key of Object.keys(rules)) if (!RULE_FIELDS.includes(key)) problems.push(`WeatherSystem has unknown field "${key}"`)
  if (!Number.isInteger(rules.cellSizeChunks) || rules.cellSizeChunks < 1 || rules.cellSizeChunks > MAX_CELL_CHUNKS) problems.push(`WeatherSystem.cellSizeChunks must be an integer in 1..${MAX_CELL_CHUNKS}, got ${rules.cellSizeChunks}`)
  if (!Number.isInteger(rules.hoursPerRoll) || rules.hoursPerRoll < 1 || rules.hoursPerRoll > MAX_HOURS) problems.push(`WeatherSystem.hoursPerRoll must be an integer in 1..${MAX_HOURS}, got ${rules.hoursPerRoll}`)
  if (!Number.isInteger(rules.overrideMaxHours) || rules.overrideMaxHours < 1 || rules.overrideMaxHours > MAX_HOURS) problems.push(`WeatherSystem.overrideMaxHours must be an integer in 1..${MAX_HOURS}, got ${rules.overrideMaxHours}`)
  const states = rules.states || {}
  const ids = Object.keys(states)
  if (!ids.includes('clear')) problems.push('WeatherSystem.states must define "clear"')
  for (const id of ids) {
    const st = states[id]
    if (!/^[a-z][a-z_]*$/.test(id)) problems.push(`weather state "${id}" must be lower snake_case`)
    for (const key of Object.keys(st)) if (!STATE_FIELDS.includes(key)) problems.push(`weather state "${id}" has unknown field "${key}"`)
    for (const f of ['moveSpeedFactor', 'visibilityFactor']) {
      if (!isNum(st[f]) || st[f] < 0 || st[f] > 1) problems.push(`weather state "${id}".${f} must be in 0..1, got ${st[f]}`)
    }
    if (!isNum(st.weight) || st.weight < 0) problems.push(`weather state "${id}".weight must be >= 0, got ${st.weight}`)
    for (const f of ['minTemperature', 'maxTemperature', 'minRainfall']) {
      if (!isNum(st[f])) problems.push(`weather state "${id}".${f} must be a number, got ${st[f]}`)
    }
    if (isNum(st.minTemperature) && isNum(st.maxTemperature) && st.minTemperature > st.maxTemperature) problems.push(`weather state "${id}" has minTemperature above maxTemperature`)
    for (const f of ['biomes', 'exceptBiomes']) {
      if (!Array.isArray(st[f])) { problems.push(`weather state "${id}".${f} must be an array`); continue }
      if (biomes) for (const b of st[f]) if (!(b in biomes)) problems.push(`weather state "${id}".${f} names unknown biome "${b}"`)
    }
  }
  if (biomes) {
    for (const b of Object.keys(rules.climate || {})) if (!(b in biomes)) problems.push(`WeatherSystem.climate names unknown biome "${b}"`)
    if (!problems.length) {
      for (const [key, biome] of Object.entries(biomes)) {
        const c = (rules.climate || {})[key] || { temperature: biome.avgTemperature, rainfall: biome.avgRainfall }
        const swing = biome.seasonSwing || 0
        const reachable = [c.temperature - swing, c.temperature, c.temperature + swing].some((t) =>
          ids.some((id) => states[id].weight > 0 && stateAllows(states[id], key, t, c.rainfall)))
        if (!reachable) problems.push(`biome "${key}" reaches no weather state (temperature ${c.temperature}±${swing}, rainfall ${c.rainfall})`)
      }
    }
  }
  return problems
}

function validateWeather(rules, biomes) {
  const problems = weatherProblems(rules, biomes)
  if (problems.length) throw new Error('Weather rule table is invalid:\n  ' + problems.join('\n  '))
}

/** The biome fields the validator needs, read off the biome entities. */
function biomeClimates(biomeEntities) {
  const out = {}
  for (const [key, e] of Object.entries(biomeEntities)) {
    const f = (e.fields || {})
    const dv = (n, d) => (f[n] && f[n].defaultValue !== undefined ? f[n].defaultValue : d)
    out[key] = { avgTemperature: dv('avgTemperature', 0), avgRainfall: dv('avgRainfall', 0), seasonSwing: dv('seasonSwing', 0) }
  }
  return out
}

const WeatherSystem = defineEntity({
    tags: ['world-system'],
    description:
      'Simulates weather across biomes as an emergent world system. ' +
      'Weather is not authored — it emerges from biome parameters, seasonal cycles, ' +
      'and player-built infrastructure (logging, irrigation, chimneys). ' +
      'Effects are gameplay-significant: rain douses fires, storms disable airships, ' +
      'blizzards slow movement and starve uninsulated settlements.',
    goal: 'Make weather a real logistical variable that drives construction, trade, and seasonal planning',
    fields: {
      id: { type: 'uuid', primaryKey: true },
      rules: {
        type: 'json',
        description: 'Weather table (Phase 128): { cellSizeChunks, hoursPerRoll, overrideMaxHours, states: { <id>: WeatherState }, climate } (validated at fabric load)',
        defaultValue: RULES,
      },
    },
    behaviors: {
      evaluateWeather: {
        description: 'Calculate the current weather state for a biome tile each in-game hour',
        rules: [
          'Base weather probability is derived from biome avgTemperature and avgRainfall — void rift tiles are excluded from this global calculation; see rule 6',
          'Player deforestation in temperate biomes increases drought probability by 5% per 100 felled tiles',
          'Player-built irrigation canals reduce drought probability by 3% per 50 canal segments',
          'Volcanic biomes always have ash-fall risk on eruption days regardless of other factors',
          'Twilight groves cycle through calm/fog/electrical-storm patterns tied to their day-night speed',
          'Void rifts generate local weather anomalies (void-storms) independent of global weather simulation',
        ],
        auth: { roles: ['maintainer'] },
      },
      applyWeatherEffects: {
        description: 'Apply the current weather state to gameplay mechanics in the affected tile',
        rules: [
          'Rain: open fire structures extinguished; wood rot rate doubled; crop growth +20%',
          'Storm: airship travel disabled in affected tiles; player movement speed –30% outdoors',
          'Blizzard: player heat-loss rate tripled; uninsulated structures lose integrity at 1% per hour',
          'Ash-fall: visibility –50%; all outdoor forges temporarily disabled',
          'Fog: trade route visibility markers hidden; ambush risk elevated for caravans',
          'Electrical-storm: player and creature movement speed –20%; metal armour wearers struck periodically for minor lightning damage',
          'Void-storm: void corruption accumulates 3× faster; all ley-line structures overcharge',
        ],
        auth: { roles: ['maintainer'] },
      },
      overrideWeather: {
        description: 'Allow maintainers to manually trigger a weather event for testing or world events',
        rules: [
          'Overrides must specify duration in in-game hours',
          'Override is logged and visible in the world-event feed',
          'Override cannot contradict biome physics permanently — effects revert after duration',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  })

module.exports = { RULES, WeatherSystem, weatherProblems, validateWeather, biomeClimates, stateAllows }
