const { defineEntity } = require('./shared')
const { CHIBI_RANGE } = require('./appearances')

// ─────────────────────────────────────────────────────────────────────────────
// Character creation (Phase 180)
//
// The choices a new player makes before entering the world: a name, a gender,
// a hair style and a hair colour. Phase 181 builds the creation screen and the
// host intent from this data. Read at runtime from
// GameData.CREATIONS["CharacterCreation"].
//
// Gender picks a fixed body preset in appearances.js (body, head, eyes, skin
// colour and the chibi proportions), so the player never picks those parts.
// Attributes are not chosen: every character starts at the Phase 177 base.
//
// Name rule: 3–16 characters after trimming the edges; Unicode letters from a
// single script group plus at most one inner separator (space, hyphen or
// apostrophe). Combining marks (U+0300–U+036F) may follow a letter and do not
// count toward the length. Uniqueness is decided on the name's skeleton, a
// subset of Unicode TR39:
//   1. lower-case,
//   2. fold accents (`accentFold`, built from Unicode NFD) and drop combining marks,
//   3. map each confusable code point to its Latin look-alike (`confusables`),
//   4. replace each `confusableSequences` key (e.g. "rn" → "m"),
//   5. drop separators.
// So "Аlice" with a Cyrillic А is refused as mixed script, and an all-Cyrillic
// "Асе" collides with an existing "Ace". The reserved list is compared on
// skeletons too. Godot strings have no NFD, so the fold tables are data here.
// ─────────────────────────────────────────────────────────────────────────────

const NAME_LIMITS = { minLength: 3, maxLength: 16, maxSeparators: 1 }
const SEPARATORS = [' ', '-', "'"]
const COMBINING = [[0x0300, 0x036f]]

// Script groups as inclusive code point ranges. A name's letters must all come
// from one group. Adding a script is data-only.
const SCRIPTS = {
  latin:    [[0x41, 0x5a], [0x61, 0x7a], [0xc0, 0xd6], [0xd8, 0xf6], [0xf8, 0x24f], [0x1e00, 0x1eff]],
  greek:    [[0x386, 0x386], [0x388, 0x38a], [0x38c, 0x38c], [0x38e, 0x3a1], [0x3a3, 0x3ff], [0x1f00, 0x1fbc]],
  cyrillic: [[0x400, 0x481], [0x48a, 0x52f]],
  // Japanese names mix kana and kanji, so the three count as one group.
  japanese: [[0x3041, 0x3096], [0x30a1, 0x30fa], [0x30fc, 0x30fc], [0x4e00, 0x9fff]],
}

// Step 3: single lower-case code points that look like a Latin letter (TR39 confusables.txt, the
// rows for the scripts above). Applied after lower-casing and accent folding, so "Асе", "асе" and
// "Ace" share one skeleton whatever their case.
const CONFUSABLES = {
  // Cyrillic
  'а': 'a', 'с': 'c', 'е': 'e', 'о': 'o', 'р': 'p', 'х': 'x', 'у': 'y', 'ѕ': 's', 'і': 'i', 'ј': 'j',
  'һ': 'h', 'ԁ': 'd', 'ԛ': 'q', 'ԝ': 'w', 'ӏ': 'l', 'ү': 'y', 'к': 'k', 'м': 'm', 'н': 'h', 'т': 't', 'в': 'b',
  // Greek
  'α': 'a', 'β': 'b', 'ε': 'e', 'ζ': 'z', 'η': 'n', 'ι': 'i', 'κ': 'k', 'μ': 'u', 'ν': 'v', 'ο': 'o',
  'ρ': 'p', 'τ': 't', 'υ': 'u', 'χ': 'x', 'γ': 'y',
}

// Step 4: multi-letter look-alikes, applied to the folded lower-case string.
const CONFUSABLE_SEQUENCES = { rn: 'm', vv: 'w' }

// Letters NFD does not decompose but players read as a base letter plus a mark.
const EXTRA_FOLDS = { 'ß': 'ss', 'ø': 'o', 'đ': 'd', 'ł': 'l', 'æ': 'ae', 'œ': 'oe', 'þ': 'th', 'ð': 'd', 'ħ': 'h', 'ı': 'i' }

// Step 2: every lower-case letter of the latin, greek and cyrillic groups whose NFD is a base
// letter plus marks, mapped to that base. Built from the JS engine's Unicode tables.
function buildAccentFold() {
  const out = {}
  for (const script of ['latin', 'greek', 'cyrillic']) {
    for (const [lo, hi] of SCRIPTS[script]) {
      for (let cp = lo; cp <= hi; cp++) {
        const ch = String.fromCodePoint(cp)
        if (ch !== ch.toLowerCase()) continue
        const base = ch.normalize('NFD').replace(/[̀-ͯ]/g, '')
        if (base !== ch && base.length > 0 && [...base].length === 1) out[ch] = base
      }
    }
  }
  return { ...out, ...EXTRA_FOLDS }
}

// Compared on skeletons. Covers staff-looking names in both shipped locales.
const RESERVED = [
  'admin', 'administrator', 'administrador', 'moderator', 'moderador', 'mod', 'gm', 'gamemaster',
  'staff', 'support', 'suporte', 'server', 'servidor', 'system', 'sistema', 'host', 'nihon',
  'projectnihon', 'player', 'jogador', 'guest', 'convidado', 'anonymous', 'anonimo', 'everyone',
  'null', 'undefined',
]

// Hair: each style has a gender and a silhouette `shape` the placeholder mesh (gen_placeholder_glb.py)
// and the picker icon (gen_ui_icons.py) are drawn from. Keys: models/characters/hair/<id>.glb.raw and
// icons/hair/<id>.png.raw. Names are not shown: the picker grid shows icons.
const HAIR_SHAPES = ['crop', 'spiky', 'swept', 'mop', 'topknot', 'mohawk', 'bob', 'long', 'twintails', 'ponytail', 'bun', 'braid']
const HAIR_STYLES = {
  hair_m_crop:      { gender: 'masculine', shape: 'crop' },
  hair_m_spiky:     { gender: 'masculine', shape: 'spiky' },
  hair_m_swept:     { gender: 'masculine', shape: 'swept' },
  hair_m_mop:       { gender: 'masculine', shape: 'mop' },
  hair_m_topknot:   { gender: 'masculine', shape: 'topknot' },
  hair_m_mohawk:    { gender: 'masculine', shape: 'mohawk' },
  hair_f_bob:       { gender: 'feminine', shape: 'bob' },
  hair_f_long:      { gender: 'feminine', shape: 'long' },
  hair_f_twintails: { gender: 'feminine', shape: 'twintails' },
  hair_f_ponytail:  { gender: 'feminine', shape: 'ponytail' },
  hair_f_bun:       { gender: 'feminine', shape: 'bun' },
  hair_f_braid:     { gender: 'feminine', shape: 'braid' },
}

// Curated hair colours: palette indices (DefaultPalette). Eight natural tones from the hair region
// (32–63), then four bold ones from the accent and secondary regions for the chibi look.
const HAIR_COLORS = [33, 37, 41, 45, 49, 53, 58, 62, 129, 133, 138, 151]

// Gender -> the appearance preset (appearances.js) that fixes body, head, eyes, skin and proportions.
// The display name is a catalog key: creation.gender.<id>.
const GENDERS = {
  masculine: { appearance: 'NoviceMasculine' },
  feminine:  { appearance: 'NoviceFeminine' },
}

const DEFAULT_CREATION = { gender: 'masculine', hair: 'hair_m_crop', hairColor: 41 }

// Items given once at creation. Server rules may replace the list; the sandbox has no class kits.
const STARTING_KIT = [{ item: 'NoviceTunic', quantity: 1, equip: true }]

// Refusal keys the host sends; the client renders them through I18n.t (locale/ui.csv).
const REFUSALS = [
  'name_length', 'name_chars', 'name_script', 'name_separator', 'name_reserved', 'name_taken',
  'gender', 'hair', 'hair_gender', 'hair_color',
]
const refusalKey = (reason) => `creation.refuse.${reason}`
const genderKey = (gender) => `creation.gender.${gender}`

function creationData() {
  return {
    name: { ...NAME_LIMITS, separators: [...SEPARATORS], combining: COMBINING, scripts: SCRIPTS, reserved: [...RESERVED],
      confusables: { ...CONFUSABLES }, confusableSequences: { ...CONFUSABLE_SEQUENCES }, accentFold: buildAccentFold() },
    genders: JSON.parse(JSON.stringify(GENDERS)),
    hairStyles: JSON.parse(JSON.stringify(HAIR_STYLES)),
    hairColors: [...HAIR_COLORS],
    defaultCreation: { ...DEFAULT_CREATION },
    startingKit: JSON.parse(JSON.stringify(STARTING_KIT)),
    proportionPreset: 'chibi',
    headRatio: { ...CHIBI_RANGE },
    refusals: [...REFUSALS],
  }
}

// Problems with a creation table. `refs` holds what the data must point at:
//   appearances: { <id>: { proportions, hair? } }, items: [ids], paletteSize, shapes: [HAIR_SHAPES]
function creationProblems(data, refs) {
  const p = []
  const n = data.name || {}
  if (!(Number.isInteger(n.minLength) && Number.isInteger(n.maxLength) && n.minLength >= 1 && n.minLength <= n.maxLength))
    p.push(`name: length bounds ${n.minLength}..${n.maxLength} are not 1 <= min <= max`)
  if (!Array.isArray(n.separators) || n.separators.some((s) => [...s].length !== 1)) p.push('name: every separator must be one character')
  const ranges = Object.values(n.scripts || {}).flat()
  if (!ranges.length) p.push('name: no script group')
  for (const [lo, hi] of ranges) if (!(lo <= hi)) p.push(`name: script range ${lo}..${hi} is reversed`)
  const inScript = (cp) => ranges.some(([lo, hi]) => cp >= lo && cp <= hi)
  for (const [from, to] of Object.entries(n.confusables || {})) {
    if ([...from].length !== 1 || from !== from.toLowerCase()) p.push(`name: confusable "${from}" is not one lower-case code point`)
    if (!/^[A-Za-z]+$/.test(to)) p.push(`name: confusable "${from}" maps to "${to}", not Latin letters`)
  }
  for (const [from, to] of Object.entries(n.accentFold || {})) {
    if (!inScript(from.codePointAt(0))) p.push(`name: accent fold "${from}" is outside every script group`)
    if (!to) p.push(`name: accent fold "${from}" maps to nothing`)
  }
  for (const r of n.reserved || []) if (!/^[a-z]+$/.test(r)) p.push(`name: reserved "${r}" must be a lower-case Latin skeleton`)

  const genders = Object.keys(data.genders || {})
  if (genders.length < 2) p.push('genders: need at least two')
  for (const [g, row] of Object.entries(data.genders || {})) {
    const app = refs.appearances[row.appearance]
    if (!app) { p.push(`gender ${g}: appearance ${row.appearance} does not exist`); continue }
    const ratio = headRatio(app.proportions, refs.coefficients)
    if (!(ratio >= data.headRatio.min && ratio <= data.headRatio.max))
      p.push(`gender ${g}: head-to-height ratio ${ratio.toFixed(3)} is outside ${data.headRatio.min}..${data.headRatio.max}`)
    if (!Object.values(data.hairStyles || {}).some((h) => h.gender === g)) p.push(`gender ${g}: no hair style`)
  }
  for (const [id, h] of Object.entries(data.hairStyles || {})) {
    if (!genders.includes(h.gender)) p.push(`hair ${id}: unknown gender ${h.gender}`)
    if (!refs.shapes.includes(h.shape)) p.push(`hair ${id}: unknown shape ${h.shape}`)
  }
  const colors = data.hairColors || []
  if (!colors.length) p.push('hairColors: empty')
  if (new Set(colors).size !== colors.length) p.push('hairColors: duplicate index')
  for (const c of colors) if (!(Number.isInteger(c) && c >= 0 && c < refs.paletteSize)) p.push(`hairColors: ${c} is not a palette index`)

  const d = data.defaultCreation || {}
  const reason = creationRefusal(data, d)
  if (reason) p.push(`defaultCreation: refused (${reason})`)
  for (const k of data.startingKit || []) {
    if (!refs.items.includes(k.item)) p.push(`startingKit: ${k.item} is not an item`)
    if (!(Number.isInteger(k.quantity) && k.quantity >= 1)) p.push(`startingKit: ${k.item} quantity ${k.quantity}`)
  }
  return p
}

// The refusal reason for a creation's gender, hair and colour (the name is checked separately), or ''.
function creationRefusal(data, c) {
  if (!(c.gender in (data.genders || {}))) return 'gender'
  const h = (data.hairStyles || {})[c.hair]
  if (!h) return 'hair'
  if (h.gender !== c.gender) return 'hair_gender'
  if (!(data.hairColors || []).includes(c.hairColor)) return 'hair_color'
  return ''
}

// Head height over total height from the placeholder landmarks (skeleton_rig.gd compute_landmarks).
function headRatio(props, c) {
  const height = props.height ?? 1, leg = props.legLength ?? 1, head = props.headScale ?? 1
  const hip = c.hipHeightFactor * leg * height
  const top = hip + c.torsoHeightFactor * height + c.neckHeightFactor * height + c.headSizeFactor * head
  return (c.headSizeFactor * head) / top
}

const defaults = (e) => Object.fromEntries(Object.entries((e && e.fields) || {}).map(([k, v]) => [k, v.defaultValue]))

// What the shipped creation table must point at, read from the fabric modules.
function creationRefs() {
  const appearances = require('./appearances')
  const skeletons = require('./skeletons')
  const { PALETTE_SIZE } = require('./palettes')
  const items = require('../items')
  return {
    appearances: Object.fromEntries(Object.entries(appearances).filter(([, e]) => e && e.fields).map(([id, e]) => [id, defaults(e)])),
    coefficients: defaults(skeletons.HumanoidSkeleton).bodyShapeCoefficients,
    items: Object.entries(items).filter(([, e]) => e && (e.tags || []).includes('item')).map(([id]) => id),
    paletteSize: PALETTE_SIZE,
    shapes: [...HAIR_SHAPES],
  }
}

function validateCreation(data, refs) {
  const problems = creationProblems(data, refs)
  if (problems.length) throw new Error('Character creation data is invalid:\n  ' + problems.join('\n  '))
}

const CharacterCreation = defineEntity({
  tags: ['creation'],
  description:
    'The choices a new player makes before entering the world: a name, a gender, a hair style and a hair ' +
    'colour. Gender picks a fixed chibi body preset; attributes are not chosen (every character starts at ' +
    'the AttributeSystem base). The host validates every field and refuses with a keyed reason.',
  goal: 'Let each player be someone recognisable from the first minute, with a name nobody else can impersonate',
  fields: {
    id: { type: 'uuid', primaryKey: true },
    name: {
      type: 'json',
      description: 'Name rule: { minLength, maxLength, maxSeparators, separators, combining, scripts: { <group>: [[lo, hi]] }, ' +
        'reserved, confusables, confusableSequences, accentFold }; uniqueness is per server on the TR39-style skeleton',
      defaultValue: creationData().name,
    },
    genders: { type: 'json', description: '{ <gender>: { appearance } }; the appearance preset fixes body, head, eyes, skin and proportions. Label: creation.gender.<id>', defaultValue: GENDERS },
    hairStyles: { type: 'json', description: '{ <hair id>: { gender, shape } }; mesh models/characters/hair/<id>.glb.raw, icon icons/hair/<id>.png.raw', defaultValue: HAIR_STYLES },
    hairColors: { type: 'json', description: 'Curated hair colours as DefaultPalette indices', defaultValue: HAIR_COLORS },
    defaultCreation: { type: 'json', description: 'The creation a player who skips the screen gets: { gender, hair, hairColor }', defaultValue: DEFAULT_CREATION },
    startingKit: { type: 'json', description: 'Items given once at creation: [{ item, quantity, equip }]; a server rule may replace it', defaultValue: STARTING_KIT },
    proportionPreset: { type: 'string', description: 'Body proportion preset both gender presets use', defaultValue: 'chibi' },
    headRatio: { type: 'json', description: 'Allowed head-to-height ratio of a created rig: { min, max }', defaultValue: CHIBI_RANGE },
    refusals: { type: 'json', description: 'Refusal reasons; the catalog key is creation.refuse.<reason>', defaultValue: REFUSALS },
  },
  behaviors: {
    create: {
      description: 'Create a character on the host from a name, gender, hair style and hair colour',
      rules: [
        'The name is 3–16 letters from one script group with at most one inner space, hyphen or apostrophe',
        'The name is unique per server on its skeleton (case, accents and confusable look-alikes folded) and is not reserved',
        'The hair style belongs to the chosen gender and the colour is in the curated list',
        'Attributes start at the AttributeSystem base; the client sends no attribute values',
        'A refusal carries a keyed reason the client renders in its own locale',
      ],
      auth: { roles: ['maintainer'] },
    },
  },
})

module.exports = {
  CharacterCreation, NAME_LIMITS, SEPARATORS, SCRIPTS, CONFUSABLES, CONFUSABLE_SEQUENCES, RESERVED,
  HAIR_SHAPES, HAIR_STYLES, HAIR_COLORS, GENDERS, DEFAULT_CREATION, STARTING_KIT, REFUSALS,
  refusalKey, genderKey, creationData, creationRefs, creationProblems, creationRefusal, headRatio, validateCreation, buildAccentFold,
}
