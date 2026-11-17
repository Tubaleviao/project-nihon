const { defineEntity } = require('@newel/core')

// Phase 203 — skills grow from work. Every kind of work a player does grows that player's own skill for it
// (sewing makes you a better sewer); nothing a member does is progress for a clan. Phase 207 reads this
// table from GameData.WORLD_SYSTEMS["WorkSkills"] and calls player_registry.grant_skill_xp per action.
//
// `craft`:  recipe domain -> { skill, xp }   one row per crafting domain a recipe can name; `tailoring` is
//           the sewing domain (its recipes arrive with Phase 207).
// `gather`: what is gathered -> { skill, xp } one row per material family (a mined or chopped unit of
//           that family) plus `plant` (foraged) and `carcass` (a skinned body: the only Skinning XP source).
//           Phase 274 — every gather row names a skill of the `gathering` category, by the tool the work
//           wants: pick (stone, metal) and shovel (soil) grow Mining, the axe (wood) Woodcutting, plants
//           Foraging and carcasses Skinning. Crafting skills grow only from `craft` rows, Building only from
//           placing, dismantling and repairing.
// `build`, `dismantle`, `repair`, `lockpick`: { skill, xp } per placed block, per dismantled block, per
//           repair and per picked lock.
// A row is exactly { skill, xp }: a row that names a clan, a target or anything else fails, so no work
// can be credited to anyone but the worker.
//
// SKILL_CURVES — the XP curve of each skill this phase adds, like Skinning's (Phase 160): `xpToLevel`
// is the cumulative XP to reach each level 0..levelCap.
//
// TIER_XP — Phase 207 review: the cumulative XP in a skill at which its tier (novice … master) is reached.
// The host raises a worker's tier when a grant crosses a threshold and never lowers one, so the recipe
// skill guards and the specialty tiers follow the work. One table for every skill.
const LEVEL_CAP = 10
const levels = (f) => Array.from({ length: LEVEL_CAP + 1 }, (_, l) => f(l))

// Phase 274 — gathering no longer feeds Building, so its curve is gentler (50 l² before) and a placed block
// grants 2 XP (1 before); the crafting rows grant 12 XP (8 before) for the ore, wood and plants that no longer
// count, so Building, Smithing, Carpentry and Alchemy still reach their tiers in play. The gathering skills
// get curves of their own.
const SKILL_CURVES = {
  Building:    { levelCap: LEVEL_CAP, xpToLevel: levels((l) => 35 * l * l) },
  Mining:      { levelCap: LEVEL_CAP, xpToLevel: levels((l) => 40 * l * l) },
  Woodcutting: { levelCap: LEVEL_CAP, xpToLevel: levels((l) => 40 * l * l) },
  Foraging:    { levelCap: LEVEL_CAP, xpToLevel: levels((l) => 30 * l * l) },
  Tailoring:   { levelCap: LEVEL_CAP, xpToLevel: levels((l) => 40 * l * l) },
  Lockpicking: { levelCap: LEVEL_CAP, xpToLevel: levels((l) => 60 * l * l) },
}

const TIER_XP = { novice: 0, apprentice: 100, journeyman: 400, expert: 1200, master: 3000 }

// Phase 274 — what each tier of a gathering skill gives (Phase 271 shows a node per tier). `work` names the
// actions it applies to (WorkTimes actions dig / mine / chop, or `forage`); `effect` is `speed` (a factor on
// the work speed, on top of the held tool's: seconds = workSeconds / (toolSpeed * factor)) or `yield` (a
// factor on the units a gather gives). Novice is 1 (no bonus) and every later tier gives more.
// Skinning's tiers live in its own harvest curves (harvest.js), so it has no row here.
const TIER_BONUSES = {
  Mining:      { work: ['mine', 'dig'], effect: 'speed', byTier: { novice: 1, apprentice: 1.1, journeyman: 1.2, expert: 1.35, master: 1.5 } },
  Woodcutting: { work: ['chop'],        effect: 'speed', byTier: { novice: 1, apprentice: 1.1, journeyman: 1.2, expert: 1.35, master: 1.5 } },
  Foraging:    { work: ['forage'],      effect: 'yield', byTier: { novice: 1, apprentice: 1.15, journeyman: 1.3, expert: 1.5, master: 1.75 } },
}
const TIER_BONUS_SKILLS = ['Mining', 'Woodcutting', 'Foraging']
const BONUS_EFFECTS = ['speed', 'yield']
const BONUS_WORK = ['dig', 'mine', 'chop', 'forage']
// The category every gather row's skill belongs to.
const GATHERING = 'gathering'

const WORK = {
  craft: {
    smithing:  { skill: 'Smithing', xp: 12 },
    carpentry: { skill: 'Carpentry', xp: 12 },
    alchemy:   { skill: 'Alchemy', xp: 12 },
    arcane:    { skill: 'ArcaneForging', xp: 10 },
    tailoring: { skill: 'Tailoring', xp: 8 },
  },
  gather: {
    metal:   { skill: 'Mining', xp: 2 },
    stone:   { skill: 'Mining', xp: 2 },
    wood:    { skill: 'Woodcutting', xp: 2 },
    soil:    { skill: 'Mining', xp: 1 },
    plant:   { skill: 'Foraging', xp: 2 },
    carcass: { skill: 'Skinning', xp: 10 },
  },
  build:     { skill: 'Building', xp: 2 },
  dismantle: { skill: 'Building', xp: 2 },
  repair:    { skill: 'Building', xp: 3 },
  lockpick:  { skill: 'Lockpicking', xp: 15 },
}

const SINGLE_KINDS = ['build', 'dismantle', 'repair', 'lockpick']
const FAMILY_FILES = { metal: 'metals', stone: 'stones', wood: 'woods', soil: 'soils' }
// Phase 212 — the made materials (materials/built.js) are gathered as what they are made of.
const BUILT_FAMILIES = { Concrete: 'stone', Steel: 'metal', Leyframe: 'metal' }

/** Phase 207 — every material's gather family, { <material>: 'metal' | 'stone' | 'wood' | 'soil' }, from the
 *  file that defines it, so the runtime picks WorkSkills.gather[family] for a mined or chopped block. */
function materialFamilies() {
  const out = {}
  for (const [fam, file] of Object.entries(FAMILY_FILES)) {
    for (const m of Object.keys(require(`../world/materials/${file}`))) out[m] = fam
  }
  for (const m of Object.keys(require('../world/materials/built'))) {
    if (!BUILT_FAMILIES[m]) throw new Error(`WorkSkills: made material ${m} has no gather family (BUILT_FAMILIES)`)
    out[m] = BUILT_FAMILIES[m]
  }
  return out
}
const FAMILIES = materialFamilies()
const ROW_FIELDS = ['skill', 'xp']
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)

/** The work and curve tables as plain data. */
function workData() {
  return JSON.parse(JSON.stringify({ work: WORK, curves: SKILL_CURVES, tiers: TIER_XP, bonuses: TIER_BONUSES }))
}

/** What the work table must cover and may name (required lazily: skills require this file). */
function workRefs() {
  const tagged = (table, tag) => Object.entries(table).filter(([, e]) => e && (e.tags || []).includes(tag)).map(([k]) => k)
  const recipes = require('./recipes')
  const settlement = require('./settlement')
  const domains = new Set()
  for (const r of [...Object.values(recipes), settlement.RecipeHearth]) {
    const f = r && r.fields || {}
    if (f.recipe && f.recipe.defaultValue && f.recipe.defaultValue.domain) domains.add(f.recipe.defaultValue.domain)
    for (const v of (f.domain && f.domain.values) || []) domains.add(v)
  }
  const skillTable = require('./skills')
  const { SKILL_CATEGORIES } = require('./skills/shared')
  const categories = {}
  for (const k of tagged(skillTable, 'skill')) {
    const f = skillTable[k].fields && skillTable[k].fields.category
    categories[k] = f ? f.defaultValue : undefined
  }
  return {
    skills: tagged(skillTable, 'skill'),
    categories,
    skillCategories: [...SKILL_CATEGORIES],
    domains: [...domains],
    families: Object.fromEntries(Object.entries(FAMILY_FILES).map(([fam, file]) => [fam, Object.keys(require(`../world/materials/${file}`))])),
  }
}

function rowProblems(at, row, skills) {
  if (!isObj(row)) return [`${at} must be { skill, xp }`]
  const p = []
  for (const k of Object.keys(row)) if (!ROW_FIELDS.includes(k)) p.push(`${at}.${k}: work grows only the worker's own skill, never a clan or anyone else`)
  if (!skills.includes(row.skill)) p.push(`${at}.skill "${row.skill}" is not a skill`)
  if (!Number.isInteger(row.xp) || row.xp < 1) p.push(`${at}.xp must be an integer >= 1`)
  return p
}

/** Problems with the work and curve tables, as strings. */
function workProblems(data, refs) {
  const p = []
  const w = data.work || {}
  const craft = isObj(w.craft) ? w.craft : {}
  for (const d of [...refs.domains, 'tailoring']) if (!(d in craft)) p.push(`WorkSkills.craft.${d} is missing: every crafting domain grows a skill`)
  for (const [d, row] of Object.entries(craft)) p.push(...rowProblems(`WorkSkills.craft.${d}`, row, refs.skills))
  const gather = isObj(w.gather) ? w.gather : {}
  for (const [fam, mats] of Object.entries(refs.families)) {
    if (!(fam in gather)) p.push(`WorkSkills.gather.${fam} is missing: gathering ${mats.join(', ')} must grow a skill`)
  }
  for (const k of ['plant', 'carcass']) if (!(k in gather)) p.push(`WorkSkills.gather.${k} is missing`)
  for (const [k, row] of Object.entries(gather)) {
    p.push(...rowProblems(`WorkSkills.gather.${k}`, row, refs.skills))
    if (isObj(row) && refs.skills.includes(row.skill) && refs.categories[row.skill] !== GATHERING) {
      p.push(`WorkSkills.gather.${k}.skill "${row.skill}" is a ${refs.categories[row.skill]} skill: gathering grows only ${GATHERING} skills`)
    }
  }
  // Phase 274 — every skill sits in a category of SKILL_CATEGORIES (skill resources load it as an index).
  for (const [skill, cat] of Object.entries(refs.categories || {})) {
    if (!(refs.skillCategories || []).includes(cat)) p.push(`skill ${skill}: category "${cat}" is not in SKILL_CATEGORIES`)
  }
  for (const k of SINGLE_KINDS) {
    if (!(k in w)) p.push(`WorkSkills.${k} is missing: every kind of work grows a skill`)
    else p.push(...rowProblems(`WorkSkills.${k}`, w[k], refs.skills))
  }
  for (const k of Object.keys(w)) if (!['craft', 'gather', ...SINGLE_KINDS].includes(k)) p.push(`WorkSkills has unknown kind of work "${k}"`)

  for (const [skill, c] of Object.entries(data.curves || {})) {
    const at = `WorkSkills.curves.${skill}`
    if (!refs.skills.includes(skill)) p.push(`${at}: "${skill}" is not a skill`)
    if (!Number.isInteger(c.levelCap) || c.levelCap < 1) { p.push(`${at}.levelCap must be an integer >= 1`); continue }
    if (!Array.isArray(c.xpToLevel) || c.xpToLevel.length !== c.levelCap + 1) { p.push(`${at}.xpToLevel needs one entry per level 0..${c.levelCap}`); continue }
    if (c.xpToLevel[0] !== 0) p.push(`${at}.xpToLevel must start at 0 for level 0`)
    for (let l = 1; l < c.xpToLevel.length; l++) if (!(c.xpToLevel[l] > c.xpToLevel[l - 1])) p.push(`${at}.xpToLevel does not rise at level ${l}`)
  }
  for (const s of ['Building', 'Tailoring', 'Lockpicking', ...TIER_BONUS_SKILLS]) if (!(s in (data.curves || {}))) p.push(`WorkSkills.curves.${s} is missing`)

  const tiers = isObj(data.tiers) ? data.tiers : {}
  const { SKILL_TIERS } = require('./skills/shared')
  for (const k of Object.keys(tiers)) if (!SKILL_TIERS.includes(k)) p.push(`WorkSkills.tiers.${k} is not a tier`)
  SKILL_TIERS.forEach((t, i) => {
    if (!Number.isInteger(tiers[t]) || tiers[t] < 0) p.push(`WorkSkills.tiers.${t} must be an integer >= 0`)
    else if (i === 0 && tiers[t] !== 0) p.push(`WorkSkills.tiers.${t} must be 0: every skill starts there`)
    else if (i > 0 && !(tiers[t] > tiers[SKILL_TIERS[i - 1]])) p.push(`WorkSkills.tiers.${t} does not rise above ${SKILL_TIERS[i - 1]}`)
  })

  // Phase 274 — each tier of Mining, Woodcutting and Foraging gives something.
  const bonuses = isObj(data.bonuses) ? data.bonuses : {}
  for (const s of TIER_BONUS_SKILLS) if (!(s in bonuses)) p.push(`WorkSkills.bonuses.${s} is missing: each tier of a gathering skill gives a bonus`)
  const claimed = {}
  for (const [skill, b] of Object.entries(bonuses)) {
    const at = `WorkSkills.bonuses.${skill}`
    if (!refs.skills.includes(skill)) { p.push(`${at}: "${skill}" is not a skill`); continue }
    if (refs.categories[skill] !== GATHERING) p.push(`${at}: ${skill} is not a ${GATHERING} skill`)
    if (!isObj(b)) { p.push(`${at} must be { work, effect, byTier }`); continue }
    if (!BONUS_EFFECTS.includes(b.effect)) p.push(`${at}.effect "${b.effect}" is not one of ${BONUS_EFFECTS.join(', ')}`)
    if (!Array.isArray(b.work) || b.work.length === 0) p.push(`${at}.work must name the work it applies to`)
    for (const w of Array.isArray(b.work) ? b.work : []) {
      if (!BONUS_WORK.includes(w)) p.push(`${at}.work "${w}" is not one of ${BONUS_WORK.join(', ')}`)
      else if (claimed[`${b.effect}:${w}`]) p.push(`${at}.work "${w}" already has a ${b.effect} bonus from ${claimed[`${b.effect}:${w}`]}`)
      else claimed[`${b.effect}:${w}`] = skill
    }
    const by = isObj(b.byTier) ? b.byTier : {}
    for (const k of Object.keys(by)) if (!SKILL_TIERS.includes(k)) p.push(`${at}.byTier.${k} is not a tier`)
    SKILL_TIERS.forEach((t, i) => {
      const v = by[t]
      if (typeof v !== 'number' || !Number.isFinite(v)) p.push(`${at}.byTier.${t} must be a number`)
      else if (i === 0 && v !== 1) p.push(`${at}.byTier.novice must be 1: a novice works at the tool's speed and yield`)
      else if (i > 0 && !(v > by[SKILL_TIERS[i - 1]])) p.push(`${at}.byTier.${t} does not rise above ${SKILL_TIERS[i - 1]}: every tier gives something`)
    })
  }
  return p
}

function validateWork(data, refs) {
  const problems = workProblems(data, refs)
  if (problems.length) throw new Error('Work skill table is invalid:\n  ' + problems.join('\n  '))
}

const WorkSkills = defineEntity({
  tags: ['world-system'],
  description:
    'Which skill each kind of work grows, and by how much: crafting in each domain, gathering each family of ' +
    'material, plants and carcasses, building, dismantling, repairing and picking locks. The XP goes to the ' +
    'worker alone; nothing a member does is progress for a clan.',
  goal: 'Make a specialty the result of how someone plays (SkillsGrowFromWork, Phase 203)',
  fields: {
    id:     { type: 'uuid', primaryKey: true },
    rules:  { type: 'json', description: 'Work table: { craft: { <domain>: { skill, xp } }, gather: { <family>: { skill, xp } }, build, dismantle, repair, lockpick } (validated at fabric load)', defaultValue: WORK },
    curves: { type: 'json', description: 'XP curves of the skills added in Phase 203: { <skill>: { levelCap, xpToLevel } }', defaultValue: SKILL_CURVES },
    tiers:  { type: 'json', description: 'Phase 207 review — cumulative XP in a skill at which each tier is reached: { novice: 0, apprentice, journeyman, expert, master }', defaultValue: TIER_XP },
    families: { type: 'json', description: 'Phase 207 — each material\'s gather family { <material>: metal | stone | wood | soil }, derived from the material files', defaultValue: FAMILIES },
    bonuses:  { type: 'json', description: 'Phase 274 — what each tier of a gathering skill gives: { <skill>: { work: [dig|mine|chop|forage], effect: speed | yield, byTier: { <tier>: factor } } }', defaultValue: TIER_BONUSES },
  },
  relations: {
    decision: { name: 'decision', kind: 'hasOne', target: 'SkillsGrowFromWork' },
  },
  behaviors: {
    grant: {
      description: 'Grant the mapped skill XP to the player who did the work',
      rules: [
        'The host decides the kind of work and the XP from this table, never from a client message',
        'Only the worker gains: no clan, project or other player is credited',
      ],
      auth: { roles: ['maintainer'] },
    },
  },
})

module.exports = { LEVEL_CAP, SKILL_CURVES, TIER_XP, TIER_BONUSES, GATHERING, WORK, FAMILIES, materialFamilies, workData, workRefs, workProblems, validateWork, WorkSkills }
