const { defineEntity } = require('@newel/core')
const { SKINNING } = require('./harvest')

// Phase 203 — skills grow from work. Every kind of work a player does grows that player's own skill for it
// (sewing makes you a better sewer); nothing a member does is progress for a clan. Phase 207 reads this
// table from GameData.WORLD_SYSTEMS["WorkSkills"] and calls player_registry.grant_skill_xp per action.
//
// `craft`:  recipe domain -> { skill, xp }   one row per crafting domain a recipe can name; `tailoring` is
//           the sewing domain (its recipes arrive with Phase 207).
// `gather`: what is gathered -> { skill, xp } one row per material family (a mined or chopped block of
//           that family) plus `plant` (foraged) and `carcass` (a skinned body, Phase 160's Skinning XP).
// `build`, `dismantle`, `repair`, `lockpick`: { skill, xp } per placed block, per dismantled block, per
//           repair and per picked lock.
// A row is exactly { skill, xp }: a row that names a clan, a target or anything else fails, so no work
// can be credited to anyone but the worker.
//
// SKILL_CURVES — the XP curve of each skill this phase adds, like Skinning's (Phase 160): `xpToLevel`
// is the cumulative XP to reach each level 0..levelCap.
const LEVEL_CAP = 10
const levels = (f) => Array.from({ length: LEVEL_CAP + 1 }, (_, l) => f(l))

const SKILL_CURVES = {
  Building:    { levelCap: LEVEL_CAP, xpToLevel: levels((l) => 50 * l * l) },
  Tailoring:   { levelCap: LEVEL_CAP, xpToLevel: levels((l) => 40 * l * l) },
  Lockpicking: { levelCap: LEVEL_CAP, xpToLevel: levels((l) => 60 * l * l) },
}

const WORK = {
  craft: {
    smithing:  { skill: 'Smithing', xp: 8 },
    carpentry: { skill: 'Carpentry', xp: 8 },
    alchemy:   { skill: 'Alchemy', xp: 8 },
    arcane:    { skill: 'ArcaneForging', xp: 10 },
    tailoring: { skill: 'Tailoring', xp: 8 },
  },
  gather: {
    metal:   { skill: 'Smithing', xp: 2 },
    stone:   { skill: 'Building', xp: 2 },
    wood:    { skill: 'Carpentry', xp: 2 },
    soil:    { skill: 'Building', xp: 1 },
    plant:   { skill: 'Alchemy', xp: 2 },
    carcass: { skill: 'Skinning', xp: SKINNING.xpPerHarvest },
  },
  build:     { skill: 'Building', xp: 1 },
  dismantle: { skill: 'Building', xp: 2 },
  repair:    { skill: 'Building', xp: 3 },
  lockpick:  { skill: 'Lockpicking', xp: 15 },
}

const SINGLE_KINDS = ['build', 'dismantle', 'repair', 'lockpick']
const FAMILY_FILES = { metal: 'metals', stone: 'stones', wood: 'woods', soil: 'soils' }

/** Phase 207 — every material's gather family, { <material>: 'metal' | 'stone' | 'wood' | 'soil' }, from the
 *  file that defines it, so the runtime picks WorkSkills.gather[family] for a mined or chopped block. */
function materialFamilies() {
  const out = {}
  for (const [fam, file] of Object.entries(FAMILY_FILES)) {
    for (const m of Object.keys(require(`../world/materials/${file}`))) out[m] = fam
  }
  return out
}
const FAMILIES = materialFamilies()
const ROW_FIELDS = ['skill', 'xp']
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)

/** The work and curve tables as plain data. */
function workData() {
  return JSON.parse(JSON.stringify({ work: WORK, curves: SKILL_CURVES }))
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
  return {
    skills: tagged(require('./skills'), 'skill'),
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
  for (const [k, row] of Object.entries(gather)) p.push(...rowProblems(`WorkSkills.gather.${k}`, row, refs.skills))
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
  for (const s of ['Building', 'Tailoring', 'Lockpicking']) if (!(s in (data.curves || {}))) p.push(`WorkSkills.curves.${s} is missing`)
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
    families: { type: 'json', description: 'Phase 207 — each material\'s gather family { <material>: metal | stone | wood | soil }, derived from the material files', defaultValue: FAMILIES },
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

module.exports = { LEVEL_CAP, SKILL_CURVES, WORK, FAMILIES, materialFamilies, workData, workRefs, workProblems, validateWork, WorkSkills }
