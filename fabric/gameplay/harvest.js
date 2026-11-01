const { defineEntity } = require('@newel/core')
const attributes = require('./attributes')

// Phase 160 — harvesting. A dead creature leaves a body; its `drops` entries are harvest entries that
// name the tool category that works them and the skill that scales them. Phase 161 reads this at runtime.
//
// Entry: { item, chance, minQty, maxQty, tool, skill }
//   tool    `knife` (pelt, meat, organs), `bonetool` (bone, tusk, horn, fang) or `none` (picked off by hand).
//   skill   the skill whose level scales the entry (every creature uses `Skinning`).
//   Quantity runs from minQty at level 0 to maxQty at the cap along Skinning.yieldCurve; `chance` rises
//   by Skinning.chanceCurve (capped at 1.0).
// Tool: an item with `harvestTool` provides that category at `efficiency` (1.0 = full, below 1.0 = a
//   poor substitute such as an axe as a bone tool). Effective level for yield and quality is
//   floor(level * efficiency).
// Carcass: `carcassMassKg`, `corpseSeconds` and `carryRule` per creature. `carry` bodies fit the carry
//   capacity, `drag` bodies exceed it but fit capacity * dragCapacityFactor, `immovable` bodies cannot move.

const HARVEST_TOOLS = ['knife', 'bonetool', 'none']
const QUALITIES = ['poor', 'common', 'fine', 'prime']
const CARRY_RULES = ['carry', 'drag', 'immovable']
const SKINNING_CAP = 10

const rank = (q) => QUALITIES.indexOf(q)
const levels = (f) => Array.from({ length: SKINNING_CAP + 1 }, (_, l) => f(l))

// Curves indexed by effective Skinning level 0..SKINNING_CAP.
const SKINNING = {
  levelCap: SKINNING_CAP,
  xpToLevel: levels((l) => 40 * l * l),
  yieldCurve: levels((l) => l / SKINNING_CAP),
  chanceCurve: levels((l) => Math.round(l * 0.025 * 1000) / 1000),
  qualityCurve: levels((l) => (l <= 2 ? 'poor' : l <= 5 ? 'common' : l <= 8 ? 'fine' : 'prime')),
}

const RULES = {
  harvestSeconds: 4.0,
  harvestRangeMetres: 3.0,
  carrySlowAboveFraction: 0.5,
  carrySlowSpeedMultiplier: 0.7,
  dragCapacityFactor: 3.0,
  dragSpeedMultiplier: 0.5,
  carryBonusPerSkinningLevelKg: 2.0,
  maxCarcassesPerRegion: 24,
}

// Base carry capacity in kg: the Strength derivation (Phase 177) at base 10. The Skinning bonus adds to it.
const BASE_CARRY_CAPACITY_KG = attributes.derive(attributes.DERIVATION.carryCapacityKg, attributes.BOUNDS.base)

// Fields spread into a creature entity: carcass weight, how long the body lasts, how it can be moved.
function carcassFields({ massKg, corpseSeconds = 300, carryRule }) {
  return {
    carcassMassKg: { type: 'decimal', description: 'Mass in kg of the body a kill leaves; compared with the carrier\'s carry capacity', defaultValue: massKg },
    corpseSeconds: { type: 'integer', description: 'Seconds the body stays in the world before it decays', defaultValue: corpseSeconds },
    carryRule:     { type: 'enum', values: CARRY_RULES, description: '`carry` (fits the carry capacity), `drag` (heavier, slower) or `immovable`', defaultValue: carryRule },
  }
}

const HarvestRules = defineEntity({
  tags: ['harvest'],
  description:
    'Tuning for working and moving a creature body: how long a harvest takes, how close the harvester stands, ' +
    'how carrying and dragging slow the walk, and how many bodies a region keeps.',
  goal: 'Keep harvest and carry numbers in the design bible so balance is a single-source edit',
  fields: {
    id:                           { type: 'uuid', primaryKey: true },
    harvestSeconds:               { type: 'decimal', description: 'Seconds a harvest action runs; moving or taking damage cancels it', defaultValue: RULES.harvestSeconds },
    harvestRangeMetres:           { type: 'decimal', description: 'Distance in metres within which the host accepts a harvest or carry intent', defaultValue: RULES.harvestRangeMetres },
    carrySlowAboveFraction:       { type: 'decimal', description: 'Carrying a body heavier than this fraction of the capacity slows walking', defaultValue: RULES.carrySlowAboveFraction },
    carrySlowSpeedMultiplier:     { type: 'decimal', description: 'Walk speed multiplier while carrying above carrySlowAboveFraction', defaultValue: RULES.carrySlowSpeedMultiplier },
    dragCapacityFactor:           { type: 'decimal', description: 'A `drag` body up to capacity times this factor can be dragged', defaultValue: RULES.dragCapacityFactor },
    dragSpeedMultiplier:          { type: 'decimal', description: 'Walk speed multiplier while dragging a body', defaultValue: RULES.dragSpeedMultiplier },
    carryBonusPerSkinningLevelKg: { type: 'decimal', description: 'Extra carry capacity in kg per Skinning level, on top of the Strength-derived capacity (AttributeSystem.derivation.carryCapacityKg)', defaultValue: RULES.carryBonusPerSkinningLevelKg },
    maxCarcassesPerRegion:        { type: 'integer', description: 'Bodies a region keeps; the oldest decays first', defaultValue: RULES.maxCarcassesPerRegion },
  },
})

/** Problems with harvest data, as strings.
 *  data: { creatures: { Name: { drops, carcassMassKg, corpseSeconds, carryRule } },
 *          tools: { Item: { harvestTool, efficiency } }, skills: [names], skinning, rules, baseCapacityKg } */
function harvestProblems(data) {
  const problems = []
  const { creatures, tools, skills, skinning: s, rules: r, baseCapacityKg } = data
  const provided = new Set(['none'])
  for (const [item, t] of Object.entries(tools)) {
    if (!HARVEST_TOOLS.includes(t.harvestTool) || t.harvestTool === 'none') problems.push(`${item}.harvestTool must be one of knife, bonetool, got "${t.harvestTool}"`)
    else provided.add(t.harvestTool)
    if (!(typeof t.efficiency === 'number' && t.efficiency > 0 && t.efficiency <= 1)) problems.push(`${item}.efficiency must be in (0, 1], got ${t.efficiency}`)
  }

  // Skinning curves: one entry per level 0..cap, never falling with level.
  const n = s.levelCap + 1
  if (!Number.isInteger(s.levelCap) || s.levelCap < 1) problems.push(`Skinning.levelCap must be an integer >= 1, got ${s.levelCap}`)
  for (const name of ['xpToLevel', 'yieldCurve', 'chanceCurve', 'qualityCurve']) {
    const a = s[name]
    if (!Array.isArray(a) || a.length !== n) { problems.push(`Skinning.${name} must cover every level 0..${s.levelCap} (${n} entries), got ${Array.isArray(a) ? a.length : a}`); continue }
    if (name === 'qualityCurve') {
      a.forEach((q, l) => { if (rank(q) < 0) problems.push(`Skinning.qualityCurve[${l}] is not a quality (${QUALITIES.join(', ')}): "${q}"`) })
      for (let l = 1; l < n; l++) if (rank(a[l]) < rank(a[l - 1])) problems.push(`Skinning.qualityCurve falls at level ${l}`)
    } else {
      for (let l = 1; l < n; l++) {
        if (name === 'xpToLevel' ? !(a[l] > a[l - 1]) : !(a[l] >= a[l - 1])) problems.push(`Skinning.${name} falls at level ${l}`)
      }
    }
  }
  if (Array.isArray(s.yieldCurve) && s.yieldCurve.length === n && (s.yieldCurve[0] !== 0 || s.yieldCurve[s.levelCap] !== 1)) {
    problems.push('Skinning.yieldCurve must run from 0 at level 0 to 1 at the cap')
  }
  if (Array.isArray(s.chanceCurve) && s.chanceCurve.some((c) => !(c >= 0 && c <= 1))) problems.push('Skinning.chanceCurve entries must be in [0, 1]')
  if (Array.isArray(s.xpToLevel) && s.xpToLevel[0] !== 0) problems.push('Skinning.xpToLevel must start at 0 for level 0')
  if (s.maxLevel !== s.levelCap) problems.push(`Skinning.maxLevel (${s.maxLevel}) must equal levelCap (${s.levelCap})`)

  if (!(r.carrySlowAboveFraction > 0 && r.carrySlowAboveFraction <= 1)) problems.push('carrySlowAboveFraction must be in (0, 1]')
  for (const k of ['carrySlowSpeedMultiplier', 'dragSpeedMultiplier']) if (!(r[k] > 0 && r[k] <= 1)) problems.push(`${k} must be in (0, 1]`)
  if (!(r.dragCapacityFactor >= 1)) problems.push('dragCapacityFactor must be >= 1')
  if (!(r.harvestSeconds > 0)) problems.push('harvestSeconds must be > 0')
  if (!(r.harvestRangeMetres > 0)) problems.push('harvestRangeMetres must be > 0')
  if (!(r.carryBonusPerSkinningLevelKg >= 0)) problems.push('carryBonusPerSkinningLevelKg must be >= 0')
  if (!(Number.isInteger(r.maxCarcassesPerRegion) && r.maxCarcassesPerRegion >= 1)) problems.push('maxCarcassesPerRegion must be an integer >= 1')
  if (!(baseCapacityKg > 0)) problems.push('the base carry capacity (AttributeSystem.derivation.carryCapacityKg at base) must be > 0')

  for (const [name, c] of Object.entries(creatures)) {
    if (!(typeof c.carcassMassKg === 'number' && c.carcassMassKg > 0)) problems.push(`${name}: creature needs carcassMassKg > 0, got ${c.carcassMassKg}`)
    if (!(Number.isInteger(c.corpseSeconds) && c.corpseSeconds > 0)) problems.push(`${name}: corpseSeconds must be an integer > 0, got ${c.corpseSeconds}`)
    if (!CARRY_RULES.includes(c.carryRule)) problems.push(`${name}: carryRule must be one of ${CARRY_RULES.join(', ')}, got "${c.carryRule}"`)
    else if (typeof c.carcassMassKg === 'number') {
      if (c.carryRule === 'carry' && c.carcassMassKg > baseCapacityKg) problems.push(`${name}: carryRule carry but ${c.carcassMassKg} kg exceeds the base capacity ${baseCapacityKg} kg`)
      if (c.carryRule === 'drag' && c.carcassMassKg <= baseCapacityKg) problems.push(`${name}: carryRule drag but ${c.carcassMassKg} kg fits the base capacity ${baseCapacityKg} kg (use carry)`)
      if (c.carryRule === 'drag' && c.carcassMassKg > baseCapacityKg * r.dragCapacityFactor) problems.push(`${name}: carryRule drag but ${c.carcassMassKg} kg exceeds ${baseCapacityKg * r.dragCapacityFactor} kg`)
    }
    if (!Array.isArray(c.drops) || c.drops.length === 0) { problems.push(`${name}: creature has no harvest entries`); continue }
    c.drops.forEach((e, i) => {
      const at = `${name}.drops[${i}] (${e.item})`
      if (!HARVEST_TOOLS.includes(e.tool)) problems.push(`${at}: tool must be one of ${HARVEST_TOOLS.join(', ')}, got "${e.tool}"`)
      else if (!provided.has(e.tool)) problems.push(`${at}: no item provides tool "${e.tool}"`)
      if (!skills.includes(e.skill)) problems.push(`${at}: unknown skill "${e.skill}"`)
      else if (e.skill !== 'Skinning') problems.push(`${at}: skill must be Skinning (the only skill with yield, chance and quality curves), got "${e.skill}"`)
      if (!(typeof e.chance === 'number' && e.chance > 0 && e.chance <= 1)) problems.push(`${at}: chance must be in (0, 1]`)
      if (!(Number.isInteger(e.minQty) && Number.isInteger(e.maxQty) && e.minQty >= 0 && e.maxQty >= e.minQty && e.maxQty >= 1)) problems.push(`${at}: needs 0 <= minQty <= maxQty, maxQty >= 1`)
    })
  }
  return problems
}

const defaults = (e) => Object.fromEntries(Object.entries((e && e.fields) || {}).map(([k, v]) => [k, v.defaultValue]))

/** Builds the harvestProblems input from fabric entities. */
function harvestData({ creatures, items, skills, rules = HarvestRules, skinning = skills.Skinning, attributeSystem = attributes.AttributeSystem }) {
  const tools = {}
  for (const [name, e] of Object.entries(items)) {
    const f = defaults(e)
    if ('harvestTool' in f) tools[name] = { harvestTool: f.harvestTool, efficiency: f.efficiency }
  }
  const cs = {}
  for (const [name, e] of Object.entries(creatures)) {
    const f = defaults(e)
    cs[name] = { drops: f.drops, carcassMassKg: f.carcassMassKg, corpseSeconds: f.corpseSeconds, carryRule: f.carryRule }
  }
  // A missing Strength row leaves the capacity undefined, which harvestProblems reports instead of throwing here.
  const a = defaults(attributeSystem)
  const carryRow = a.derivation && a.derivation.carryCapacityKg
  return {
    creatures: cs, tools, skills: Object.keys(skills), skinning: defaults(skinning), rules: defaults(rules),
    baseCapacityKg: carryRow ? attributes.derive(carryRow, a.base) : undefined,
  }
}

function validateHarvest(data) {
  const problems = harvestProblems(data)
  if (problems.length) throw new Error('Harvest data is invalid:\n  ' + problems.join('\n  '))
}

module.exports = {
  HarvestRules, HARVEST_TOOLS, QUALITIES, CARRY_RULES, SKINNING, RULES, BASE_CARRY_CAPACITY_KG,
  carcassFields, harvestProblems, harvestData, validateHarvest,
}
