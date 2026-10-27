const { defineEntity } = require('./shared')

// ─────────────────────────────────────────────────────────────────────────────
// Character creation (Phase 180)
//
// A player picks a name, a gender (a fixed chibi body preset: appearances.js), a hair style of that gender and a hair
// colour from a curated list. Attributes are not chosen: every character starts at the Phase 177 base values. The
// runtime screen (Phase 181) is generated from this data. Read at runtime from GameData.CREATIONS["CharacterCreation"].
//
// Art direction: cute, chunky chibi figures: a big head (about a third of the height), large expressive eyes, short
// limbs, big hands and boots, bold chunky hair. Our own designs, never copies of any other game's styles.
// ─────────────────────────────────────────────────────────────────────────────

// Name rules, applied by the host (Phase 181). Unique per server after case folding, accent folding and a Unicode TR39
// confusables skeleton, so "Аlice" with a Cyrillic А collides with "Alice".
const NAME_RULES = {
  minLength: 3,
  maxLength: 16,
  scriptsMixAllowed: false,        // letters come from a single script (no Latin mixed with Cyrillic or Greek)
  separators: [' ', '-', "'"],     // at most one, inside the name (never first, last or doubled)
  maxSeparators: 1,
  uniqueBy: ['caseFold', 'accentFold', 'confusablesSkeleton'],
  reserved: ['admin', 'administrator', 'moderator', 'mod', 'server', 'system', 'console', 'root', 'npc', 'gm', 'staff', 'nihon'],
}

const GENDERS = ['masculine', 'feminine']
// Gender -> the appearance entity that carries its body, head, eyes, skin and chibi proportions.
const PRESETS = { masculine: 'CreationMasculine', feminine: 'CreationFeminine' }

const HAIR_PER_GENDER = 6
const hairStyles = (g) => Array.from({ length: HAIR_PER_GENDER }, (_, i) => `hair_chibi_${g[0]}_${String(i + 1).padStart(2, '0')}`)
const HAIR = Object.fromEntries(GENDERS.map((g) => [g, hairStyles(g)]))

// Palette indices of the hair/fur region (32–63), chosen to read apart on a dark backdrop.
const HAIR_COLORS = [33, 36, 40, 44, 48, 52, 56, 60]

const DEFAULT_CREATION = { gender: 'feminine', hair: 'hair_chibi_f_01', hairColor: 40 }
// A starting kit per server rule: a plain novice outfit, no class kits (the sandbox has none).
const STARTING_KIT = { outfit: 'NoviceTunic', items: [] }

// The chibi proportion preset both genders use: the head about a third of the height, short limbs.
const CHIBI_PROPORTIONS = { height: 0.85, bodyMass: 1.1, shoulderWidth: 1.0, armLength: 0.7, legLength: 0.65, headScale: 1.8 }
// head height / total height must fall within this range for a chibi figure.
const CHIBI_HEAD_RATIO = [0.28, 0.4]

const creationData = () => ({
  nameRules: NAME_RULES, genders: GENDERS, presets: PRESETS, hair: HAIR, hairColors: HAIR_COLORS,
  defaultCreation: DEFAULT_CREATION, startingKit: STARTING_KIT, chibi: CHIBI_PROPORTIONS, chibiHeadRatio: CHIBI_HEAD_RATIO,
})

/** Problems with the creation data, as strings. `appearances` is the appearance entity table, `hairRegion` the palette's hair range. */
function creationProblems(data, appearances, hairRegion = [32, 63]) {
  const problems = []
  const n = data.nameRules
  if (!(Number.isInteger(n.minLength) && Number.isInteger(n.maxLength) && n.minLength >= 3 && n.minLength <= n.maxLength && n.maxLength <= 16)) {
    problems.push(`name length must satisfy 3 <= min <= max <= 16, got ${n.minLength}..${n.maxLength}`)
  }
  if (!Array.isArray(n.reserved) || n.reserved.length === 0) problems.push('the reserved-name list must not be empty')
  if (new Set(n.uniqueBy).size !== 3) problems.push('name uniqueness needs caseFold, accentFold and confusablesSkeleton')
  if (!Array.isArray(data.genders) || data.genders.length < 1) problems.push('there must be at least one gender')
  for (const g of data.genders) {
    const preset = data.presets[g]
    const app = appearances[preset]
    if (!preset || !app) { problems.push(`gender ${g} names no appearance preset ("${preset}")`); continue }
    const f = app.fields || {}
    const props = f.proportions && f.proportions.defaultValue
    if (!props) problems.push(`preset ${preset} has no proportions`)
    else if (props.headScale < 1.5) problems.push(`preset ${preset} is not chibi: headScale ${props.headScale} < 1.5`)
    const hair = data.hair[g]
    if (!Array.isArray(hair) || hair.length < 1) problems.push(`gender ${g} has no hair style`)
    else if (new Set(hair).size !== hair.length) problems.push(`gender ${g} lists a hair style twice`)
  }
  const all = Object.values(data.hair).flat()
  if (new Set(all).size !== all.length) problems.push('a hair style belongs to more than one gender')
  if (!Array.isArray(data.hairColors) || data.hairColors.length < 1) problems.push('there must be at least one hair colour')
  for (const c of data.hairColors || []) {
    if (!Number.isInteger(c) || c < hairRegion[0] || c > hairRegion[1]) problems.push(`hair colour ${c} is outside the hair palette region ${hairRegion[0]}–${hairRegion[1]}`)
  }
  const d = data.defaultCreation
  if (!data.genders.includes(d.gender)) problems.push(`the default gender ${d.gender} is not a gender`)
  else if (!(data.hair[d.gender] || []).includes(d.hair)) problems.push(`the default hair ${d.hair} is not a ${d.gender} style`)
  if (!data.hairColors.includes(d.hairColor)) problems.push(`the default hair colour ${d.hairColor} is not in the list`)
  if (!data.startingKit || typeof data.startingKit.outfit !== 'string' || data.startingKit.outfit === '') problems.push('the starting kit names no outfit')
  return problems
}

function validateCreation(data, appearances) {
  const problems = creationProblems(data, appearances)
  if (problems.length) throw new Error(`Character creation data is invalid:\n  - ${problems.join('\n  - ')}`)
}

const CharacterCreation = defineEntity({
  tags: ['creation'],
  description:
    'What a player chooses when creating a character: a name (rules and uniqueness), a gender (a fixed chibi body ' +
    'preset), a hair style of that gender and a hair colour. Attributes are not chosen; every character starts at base. ' +
    'Cute, chunky chibi figures: a big head, short limbs, bold hair. Our own designs.',
  goal: 'Let a player become a recognisable character in one short screen, generated from data, without a pay or class gate',
  fields: {
    nameRules:       { type: 'json', description: 'Name length, scripts, separators, uniqueness folding and reserved names', defaultValue: NAME_RULES },
    genders:         { type: 'json', description: 'The gender options, in display order', defaultValue: GENDERS },
    presets:         { type: 'json', description: 'Gender -> the appearance entity (body, head, eyes, skin, chibi proportions)', defaultValue: PRESETS },
    hair:            { type: 'json', description: 'Gender -> hair style ids (each has a UI icon and a mesh at the same key)', defaultValue: HAIR },
    hairColors:      { type: 'json', description: 'The curated hair colour list (palette indices in the hair region)', defaultValue: HAIR_COLORS },
    defaultCreation: { type: 'json', description: 'The creation a skipped screen uses', defaultValue: DEFAULT_CREATION },
    startingKit:     { type: 'json', description: 'The starting outfit and items per server rule: a plain novice outfit, no class kits', defaultValue: STARTING_KIT },
    chibiHeadRatio:  { type: 'json', description: 'Allowed head height / total height of a chibi rig', defaultValue: CHIBI_HEAD_RATIO },
  },
})

module.exports = {
  CharacterCreation, creationData, creationProblems, validateCreation,
  NAME_RULES, GENDERS, PRESETS, HAIR, HAIR_COLORS, DEFAULT_CREATION, STARTING_KIT, CHIBI_PROPORTIONS, CHIBI_HEAD_RATIO,
}
