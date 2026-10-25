const { defineEntity } = require('@newel/core')
const { SKILL_CATEGORIES } = require('./skills/shared')

// Phase 177 — character attributes. Six attributes feed systems that already exist; there are no
// classes and no levels. A character starts from creation (Phase 180) and grows slowly from skill use
// (Phase 178 applies it on the host). Read at runtime from GameData.ATTRIBUTES["AttributeSystem"].
//
// Bounds: every attribute starts at `base`; creation keeps each value in creationMin..creationMax; growth
//   never lifts one above hardCap.
//
// Derivation: one row per derived stat, fed by one attribute:
//   d = value - base
//   stat = clamp(statBase + (d < 0 ? perPointBelow : perPoint) * d, min, max)
//   `perPointBelow` defaults to `perPoint`; 0 means a low attribute never takes the stat below today's
//   number (a chance that is 0 today cannot go negative). At base 10 every stat equals today's constant,
//   so a character saved before attributes existed plays the same.
//   kind: `amount` (an absolute number in `unit`), `factor` (multiplies today's number, 1 = unchanged),
//   `chance` (added probability, 0..1) or `bonus` (added to a level or a grade step).
//
// Growth: XP granted in a skill category feeds the weighted attributes. An attribute that has grown `g`
//   points needs xpPerPoint * (1 + costStep * g) weighted XP for its next point (diminishing returns),
//   and the points grown across all six attributes stop at totalPointsCap. Growth comes from use, never
//   from spending points.

const ATTRIBUTES = ['strength', 'vitality', 'resistance', 'agility', 'intelligence', 'perception']
const STAT_KINDS = ['amount', 'factor', 'chance', 'bonus']

const BOUNDS = { base: 10, creationMin: 5, creationMax: 18, hardCap: 30 }

// Today's constants the derivation reproduces at base 10 (checked by tools/check_attributes.js and the suite).
const TODAY = {
  carryCapacityKg: 40.0,     // harvest.js base carry capacity (Phase 160)
  maxHp: 100.0,              // PlayerRules.MAX_HP
  hpRegenPerSecond: 0.25,    // GestureRules.BASE_HP_REGEN_PER_S
  detectionRadiusMetres: 32, // new in Phase 178: the minimap draws no creatures or deposits today
}

const stat = (attribute, kind, statBase, perPoint, min, max, extra = {}) => ({
  attribute, kind, base: statBase, perPoint, perPointBelow: perPoint, min, max, ...extra,
})

const DERIVATION = {
  // Strength
  carryCapacityKg:         stat('strength', 'amount', TODAY.carryCapacityKg, 2.0, 25, 85, { unit: 'kg' }),
  meleeDamageFactor:       stat('strength', 'factor', 1.0, 0.02, 0.85, 1.45),
  knockbackDealtFactor:    stat('strength', 'factor', 1.0, 0.02, 0.85, 1.45),
  gatherSpeedFactor:       stat('strength', 'factor', 1.0, 0.015, 0.9, 1.35),
  // Vitality
  maxHp:                   stat('vitality', 'amount', TODAY.maxHp, 5.0, 70, 210, { unit: 'hp' }),
  hpRegenPerSecond:        stat('vitality', 'amount', TODAY.hpRegenPerSecond, 0.0125, 0.18, 0.55, { unit: 'hp/s' }),
  restRegenFactor:         stat('vitality', 'factor', 1.0, 0.02, 0.85, 1.45),
  // Resistance
  damageReduction:         stat('resistance', 'chance', 0.0, 0.01, -0.06, 0.22),
  statusChanceFactor:      stat('resistance', 'factor', 1.0, -0.015, 0.65, 1.1),
  statusDurationFactor:    stat('resistance', 'factor', 1.0, -0.015, 0.65, 1.1),
  staggerResistChance:     stat('resistance', 'chance', 0.0, 0.01, 0.0, 0.22, { perPointBelow: 0 }),
  // Agility
  moveSpeedFactor:         stat('agility', 'factor', 1.0, 0.005, 0.97, 1.12),
  attackIntervalFactor:    stat('agility', 'factor', 1.0, -0.01, 0.78, 1.06),
  dodgeChance:             stat('agility', 'chance', 0.0, 0.005, 0.0, 0.12, { perPointBelow: 0 }),
  // Intelligence
  researchGainFactor:      stat('intelligence', 'factor', 1.0, 0.025, 0.85, 1.55),
  craftQualityChance:      stat('intelligence', 'chance', 0.0, 0.01, 0.0, 0.22, { perPointBelow: 0 }),
  magicXpFactor:           stat('intelligence', 'factor', 1.0, 0.02, 0.85, 1.45),
  // Perception
  gatherYieldFactor:       stat('perception', 'factor', 1.0, 0.015, 0.9, 1.35),
  harvestQualityBonus:     stat('perception', 'bonus', 0.0, 0.1, -0.6, 2.2),
  detectionRadiusMetres:   stat('perception', 'amount', TODAY.detectionRadiusMetres, 1.6, 24, 68, { unit: 'm' }),
}

// Weights per skill category sum to 1. Every category in SKILL_CATEGORIES has a row.
const GROWTH = {
  xpPerPoint: 600,
  costStep: 0.25,
  totalPointsCap: 40,
  categories: {
    combat:      { strength: 0.5, agility: 0.5 },
    crafting:    { strength: 0.5, intelligence: 0.5 },
    exploration: { perception: 0.5, agility: 0.5 },
    survival:    { vitality: 0.5, perception: 0.5 },
    magic:       { intelligence: 0.5, resistance: 0.5 },
    social:      { perception: 1.0 },
  },
}

// Limits that keep a 20-point gap noticeable but never a one-shot.
const LIMITS = {
  factorRange: [0.5, 2.0],      // a factor stat never halves or doubles today's number
  chanceRange: [-0.25, 0.5],    // a chance stat stays well short of certain
  amountRange: [0.5, 2.5],      // an amount stat stays within this multiple of today's number
  minNoticeable: 0.05,          // hardCap vs base must move a stat by at least 5% of its scale
}

const nameKey = (id) => `attr.${id}.name`
const descKey = (id) => `attr.${id}.desc`
const statKey = (id) => `stat.${id}`

/** A derived stat's value for one attribute value (`row` from DERIVATION). */
function derive(row, value, bounds = BOUNDS) {
  const d = value - bounds.base
  const raw = row.base + (d < 0 ? row.perPointBelow : row.perPoint) * d
  return Math.min(row.max, Math.max(row.min, raw))
}

/** Every derived stat for a full attribute set ({ strength: 10, … }). */
function deriveAll(attrs, table = DERIVATION, bounds = BOUNDS) {
  const out = {}
  for (const [id, row] of Object.entries(table)) out[id] = derive(row, attrs[row.attribute], bounds)
  return out
}

const uniform = (v) => Object.fromEntries(ATTRIBUTES.map((a) => [a, v]))

/** Problems with the attribute data, as strings. data: { attributes, bounds, derivation, growth, categories, today } */
function attributeProblems(data) {
  const problems = []
  const { attributes, bounds: b, derivation, growth: g, categories, today } = data
  const isNum = (v) => typeof v === 'number' && Number.isFinite(v)
  const close = (x, y) => Math.abs(x - y) < 1e-9

  // Shape first: the checks below index into every table, so a missing one is reported, not thrown.
  const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
  if (!Array.isArray(attributes) || attributes.length === 0) problems.push('attributes must be a non-empty list')
  if (!isObj(b)) problems.push('bounds must be an object')
  if (!isObj(derivation)) problems.push('derivation must be an object')
  else for (const [id, r] of Object.entries(derivation)) if (!isObj(r)) problems.push(`derived stat ${id} must be an object`)
  if (!isObj(g) || !isObj(g.categories)) problems.push('growth must be an object with a categories object')
  else for (const [c, w] of Object.entries(g.categories)) if (!isObj(w)) problems.push(`growth row ${c} must be an object`)
  if (!Array.isArray(categories)) problems.push('categories must be a list')
  if (!isObj(today)) problems.push('today must be an object')
  if (problems.length) return problems

  if (new Set(attributes).size !== attributes.length) problems.push('attributes must be unique')
  for (const a of attributes) if (!/^[a-z]+$/.test(a)) problems.push(`attribute "${a}" must be lower case letters`)

  for (const k of ['base', 'creationMin', 'creationMax', 'hardCap']) if (!Number.isInteger(b[k])) problems.push(`bounds.${k} must be an integer, got ${b[k]}`)
  if (!(b.creationMin >= 1 && b.creationMin <= b.base && b.base <= b.creationMax && b.creationMax <= b.hardCap)) {
    problems.push(`bounds must satisfy 1 <= creationMin <= base <= creationMax <= hardCap, got ${b.creationMin}, ${b.base}, ${b.creationMax}, ${b.hardCap}`)
  }

  const fed = new Set()
  for (const [id, r] of Object.entries(derivation)) {
    const at = `derived stat ${id}`
    if (!/^[a-z][A-Za-z]*$/.test(id)) problems.push(`${at} must be lowerCamelCase`)
    if (!attributes.includes(r.attribute)) { problems.push(`${at} names unknown attribute "${r.attribute}"`); continue }
    fed.add(r.attribute)
    if (!STAT_KINDS.includes(r.kind)) problems.push(`${at}.kind must be one of ${STAT_KINDS.join(', ')}, got "${r.kind}"`)
    for (const k of ['base', 'perPoint', 'perPointBelow', 'min', 'max']) if (!isNum(r[k])) problems.push(`${at}.${k} must be a number, got ${r[k]}`)
    if (!(r.min < r.max)) problems.push(`${at} needs min < max, got ${r.min}..${r.max}`)
    if (r.perPoint === 0) problems.push(`${at}.perPoint must not be 0 (the attribute would feed nothing)`)
    if (r.perPointBelow !== 0 && Math.sign(r.perPointBelow) !== Math.sign(r.perPoint)) problems.push(`${at}.perPointBelow must be 0 or share perPoint's sign`)
    if (r.kind === 'factor' && r.base !== 1) problems.push(`${at} is a factor, so its base must be 1 (today's number unchanged), got ${r.base}`)
    if ((r.kind === 'chance' || r.kind === 'bonus') && r.base !== 0) problems.push(`${at} is a ${r.kind}, so its base must be 0 (no change from today), got ${r.base}`)
    if (r.kind === 'amount' && (!isNum(today[id]) || !close(r.base, today[id]))) problems.push(`${at} is an amount, so its base must equal today's constant ${today[id]}, got ${r.base}`)

    // The base sits inside the clamp, and the extremes stay inside it unclamped (the clamp is a guard, not a rule).
    const raw = (v) => r.base + ((v - b.base) < 0 ? r.perPointBelow : r.perPoint) * (v - b.base)
    if (!(r.base >= r.min && r.base <= r.max)) problems.push(`${at}: base ${r.base} is outside its clamp ${r.min}..${r.max}`)
    for (const [label, v] of [['the creation minimum', b.creationMin], ['the hard cap', b.hardCap]]) {
      const x = raw(v)
      if (!(x >= r.min - 1e-9 && x <= r.max + 1e-9)) problems.push(`${at}: ${label} (${v}) gives ${round(x)}, outside its clamp ${r.min}..${r.max}`)
    }
    // Never a one-shot: the clamp itself stays within sane multiples of today's number.
    const [lo, hi] = r.kind === 'factor' ? LIMITS.factorRange
      : r.kind === 'chance' ? LIMITS.chanceRange
        : r.kind === 'amount' ? LIMITS.amountRange.map((m) => m * r.base) : [-Infinity, Infinity]
    if (r.min < lo - 1e-9 || r.max > hi + 1e-9) problems.push(`${at}: clamp ${r.min}..${r.max} leaves ${round(lo)}..${round(hi)} (a ${r.kind} that large is a one-shot)`)
    // Noticeable: the hard cap moves the stat by at least minNoticeable of its scale.
    const scale = r.kind === 'amount' ? r.base : 1
    if (Math.abs(derive(r, b.hardCap, b) - r.base) < LIMITS.minNoticeable * scale - 1e-9) problems.push(`${at}: the hard cap moves it by less than ${LIMITS.minNoticeable * 100}% (not noticeable)`)
  }
  for (const a of attributes) if (!fed.has(a)) problems.push(`attribute ${a} feeds no derived stat`)

  // Base 10 in every attribute reproduces today's constants.
  const atBase = {}
  for (const [id, r] of Object.entries(derivation)) if (attributes.includes(r.attribute)) atBase[id] = derive(r, b.base, b)
  for (const [id, v] of Object.entries(today)) {
    if (!(id in derivation)) problems.push(`today's constant ${id} has no derived stat`)
    else if (!close(atBase[id], v)) problems.push(`at base ${b.base}, ${id} is ${atBase[id]}, not today's ${v}`)
  }

  if (!(Number.isInteger(g.xpPerPoint) && g.xpPerPoint > 0)) problems.push(`growth.xpPerPoint must be an integer > 0, got ${g.xpPerPoint}`)
  if (!(isNum(g.costStep) && g.costStep > 0)) problems.push(`growth.costStep must be > 0 (diminishing returns), got ${g.costStep}`)
  if (!(Number.isInteger(g.totalPointsCap) && g.totalPointsCap > 0)) problems.push(`growth.totalPointsCap must be an integer > 0, got ${g.totalPointsCap}`)
  else if (g.totalPointsCap > attributes.length * (b.hardCap - b.base)) problems.push(`growth.totalPointsCap ${g.totalPointsCap} exceeds what the hard cap allows (${attributes.length * (b.hardCap - b.base)})`)
  for (const c of categories) if (!(c in g.categories)) problems.push(`skill category ${c} has no growth row`)
  for (const [c, weights] of Object.entries(g.categories)) {
    if (!categories.includes(c)) { problems.push(`growth row ${c} is not a skill category`); continue }
    let sum = 0
    for (const [a, w] of Object.entries(weights)) {
      if (!attributes.includes(a)) problems.push(`growth row ${c} names unknown attribute "${a}"`)
      if (!(isNum(w) && w > 0 && w <= 1)) problems.push(`growth row ${c}.${a} weight must be in (0, 1], got ${w}`)
      sum += isNum(w) ? w : 0
    }
    if (!close(sum, 1)) problems.push(`growth row ${c} weights sum to ${round(sum)}, not 1`)
  }
  return problems
}

const round = (x) => Math.round(x * 1e6) / 1e6

function attributeData({ categories = SKILL_CATEGORIES } = {}) {
  return { attributes: [...ATTRIBUTES], bounds: { ...BOUNDS }, derivation: JSON.parse(JSON.stringify(DERIVATION)), growth: JSON.parse(JSON.stringify(GROWTH)), categories: [...categories], today: { ...TODAY } }
}

function validateAttributes(data) {
  const problems = attributeProblems(data)
  if (problems.length) throw new Error('Attribute data is invalid:\n  ' + problems.join('\n  '))
}

const AttributeSystem = defineEntity({
  tags: ['attribute'],
  description:
    'The six character attributes (Strength, Vitality, Resistance, Agility, Intelligence, Perception), ' +
    'what each one feeds, and how skill use grows them. No classes and no levels: a character starts from ' +
    'creation and grows slowly from use. At base 10 in every attribute each derived stat equals the number ' +
    'the game used before attributes existed.',
  goal: 'Give each character a body that differs from another\'s through data that feeds existing systems, in keeping with KnowledgeIsProgression and NoPayToWin',
  fields: {
    id:          { type: 'uuid', primaryKey: true },
    attributes:  { type: 'json', description: 'Attribute ids in display order; names and descriptions are catalog keys attr.<id>.name / attr.<id>.desc', defaultValue: ATTRIBUTES },
    base:        { type: 'integer', description: 'Starting value of every attribute; a save from before Phase 178 loads at this value', defaultValue: BOUNDS.base },
    creationMin: { type: 'integer', description: 'Lowest value character creation allows', defaultValue: BOUNDS.creationMin },
    creationMax: { type: 'integer', description: 'Highest value character creation allows', defaultValue: BOUNDS.creationMax },
    hardCap:     { type: 'integer', description: 'No attribute grows above this value', defaultValue: BOUNDS.hardCap },
    derivation:  {
      type: 'json',
      description: 'Derived stats: { <stat>: { attribute, kind, base, perPoint, perPointBelow, min, max, unit? } }; ' +
        'stat = clamp(base + slope * (value - attribute base), min, max), slope = perPointBelow under the base, perPoint at or above it',
      defaultValue: DERIVATION,
    },
    growth: {
      type: 'json',
      description: 'Growth from skill XP: { xpPerPoint, costStep, totalPointsCap, categories: { <skill category>: { <attribute>: weight } } }; ' +
        'the next point of an attribute that has grown g points costs xpPerPoint * (1 + costStep * g) weighted XP',
      defaultValue: GROWTH,
    },
  },
  behaviors: {
    derive: {
      description: 'Compute a character\'s derived stats from its attributes',
      rules: [
        'Each derived stat is fed by exactly one attribute through the derivation table; nothing else is hard-coded',
        'At base 10 in every attribute each derived stat equals today\'s constant (carry 40 kg, max HP 100, HP regeneration 0.25/s, every factor 1, every chance 0)',
        'The clamp keeps a 20-point gap noticeable but never a one-shot',
      ],
      auth: { roles: ['maintainer'] },
    },
    grow: {
      description: 'Grow attributes from skill XP on the host',
      rules: [
        'XP granted in a skill category is split over that category\'s weighted attributes',
        'Each point grown makes the next point of that attribute cost more (diminishing returns)',
        'Growth stops at the hard cap per attribute and at totalPointsCap across all six',
        'Attributes never grow from spending points; the client sends no attribute values',
      ],
      auth: { roles: ['maintainer'] },
    },
  },
})

module.exports = {
  AttributeSystem, ATTRIBUTES, STAT_KINDS, BOUNDS, TODAY, DERIVATION, GROWTH, LIMITS,
  nameKey, descKey, statKey, derive, deriveAll, uniform, attributeProblems, attributeData, validateAttributes,
}
