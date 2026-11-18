const { defineEntity } = require('@newel/core')
const { SKILL_TIERS } = require('./skills/shared')

// Phase 271 — the skill wheel. Every skill tier is a node. A node has an `affinity` per profession (weights
// summing to 1; a skill no profession names has none and sits in the centre) and a `depth` from 0 (anyone's) to
// 1 (unique to a profession, advanced) that grows along a skill's tiers. Affinity is derived from the
// professions' `relations` (a skill named by n professions gives each 1/n) unless AFFINITY_OVERRIDES names it.
// `unlock` says what the tier grants: an `ability` when a skill behavior requires that tier, else a `passive`
// bonus (so no tier is empty). The Godot layout (src/ui/skill_wheel_layout.gd) places nodes from this table.

/** skill -> { profession: weight } — replaces the derived affinity (a shared skill sits between its professions). */
const AFFINITY_OVERRIDES = {
  Smithing: { Blacksmith: 0.7, Warrior: 0.3 },
}

/** Depth of a tier: 0 for novice (anyone's) rising to 1 for master (unique, advanced). */
function tierDepth(i) { return i / (SKILL_TIERS.length - 1) }

function skillEntities() {
  const out = {}
  for (const [k, e] of Object.entries(require('./skills'))) if (e && e.tags && e.tags.includes('skill')) out[k] = e
  return out
}

function professionRelations() {
  const out = {}
  for (const [k, e] of Object.entries(require('./professions'))) {
    if (e && e.tags && e.tags.includes('profession')) out[k] = Object.values(e.relations || {}).map((r) => r.target)
  }
  return out
}

/** The tier a behavior requires: "Requires Smithing: Novice" -> 'novice'; null when none. */
function ruleTier(rule) {
  const m = /^Requires [^:]+: (\w+)/.exec(rule)
  const t = m && m[1].toLowerCase()
  return SKILL_TIERS.includes(t) ? t : null
}

function skillWheelData() {
  const skills = skillEntities()
  const profs = professionRelations()
  const nodes = {}
  for (const [skill, e] of Object.entries(skills)) {
    let affinity = AFFINITY_OVERRIDES[skill]
    if (!affinity) {
      const names = Object.keys(profs).filter((p) => profs[p].includes(skill))
      affinity = {}
      for (const p of names) affinity[p] = 1 / names.length
    }
    const abilities = {}
    for (const [b, def] of Object.entries(e.behaviors || {})) {
      for (const r of def.rules || []) { const t = ruleTier(r); if (t && !abilities[t]) abilities[t] = b }
    }
    SKILL_TIERS.forEach((tier, i) => {
      nodes[`${skill}:${tier}`] = {
        skill, tier, depth: tierDepth(i), affinity,
        requires: i > 0 ? [`${skill}:${SKILL_TIERS[i - 1]}`] : [],
        unlock: abilities[tier] ? { kind: 'ability', key: abilities[tier] } : { kind: 'passive', key: `${skill}.${tier}` },
      }
    })
  }
  return JSON.parse(JSON.stringify({ professions: Object.keys(profs), professionSkills: profs, nodes }))
}

function skillWheelRefs() {
  return { professions: Object.keys(professionRelations()), skills: Object.keys(skillEntities()), tiers: SKILL_TIERS }
}

/** Problems with the wheel table, as strings. */
function skillWheelProblems(d, refs) {
  const p = []
  const byTier = {}
  for (const [prof, list] of Object.entries(d.professionSkills || {})) for (const sk of list) if (!refs.skills.includes(sk)) p.push(`${prof}: unknown skill ${sk}`)
  for (const [id, n] of Object.entries(d.nodes || {})) {
    if (!refs.skills.includes(n.skill)) p.push(`${id}: unknown skill ${n.skill}`)
    if (!refs.tiers.includes(n.tier)) p.push(`${id}: unknown tier ${n.tier}`)
    let sum = 0
    for (const [prof, w] of Object.entries(n.affinity || {})) {
      if (!refs.professions.includes(prof)) p.push(`${id}: affinity to unknown profession ${prof}`)
      if (!(w > 0 && w <= 1)) p.push(`${id}: affinity ${prof} must be in (0, 1]`)
      sum += w
    }
    if (Math.abs(sum) > 1e-9 && Math.abs(sum - 1) > 1e-9) p.push(`${id}: affinities sum to ${sum}, not 0 or 1`)
    if (!(n.depth >= 0 && n.depth <= 1)) p.push(`${id}: depth ${n.depth} outside [0, 1]`)
    for (const r of n.requires || []) if (!(r in d.nodes)) p.push(`${id}: requires unknown node ${r}`)
    if (!n.unlock || !['recipe', 'ability', 'passive'].includes(n.unlock.kind) || !n.unlock.key) p.push(`${id}: tier unlocks nothing`)
    ;(byTier[n.skill] = byTier[n.skill] || {})[n.tier] = n.depth
  }
  for (const [skill, tiers] of Object.entries(byTier)) {
    let last = -1
    for (const t of refs.tiers) {
      if (!(t in tiers)) continue
      if (!(tiers[t] > last)) p.push(`${skill}: depth does not grow at tier ${t}`)
      last = tiers[t]
    }
  }
  for (const s of refs.skills) if (!byTier[s]) p.push(`${s}: skill has no wheel nodes`)
  return p
}

function validateSkillWheel(d, refs) {
  const problems = skillWheelProblems(d, refs)
  if (problems.length) throw new Error('Skill wheel is invalid:\n  ' + problems.join('\n  '))
}

const SkillWheel = defineEntity({
  tags: ['world-system'],
  description:
    'The skill wheel: each skill tier is a node with an affinity per profession (which pulls it toward that ' +
    'profession on the rim) and a depth (how far from the centre it sits), plus what the tier unlocks.',
  goal: 'Draw skills as a wheel of professions with shared skills in the centre instead of a grid of tiers (Phase 271)',
  fields: {
    id:          { type: 'uuid', primaryKey: true },
    professions: { type: 'json', description: 'Profession ids, in rim order', defaultValue: skillWheelData().professions },
    professionSkills: { type: 'json', description: '{ <profession>: [skills it is built from] }', defaultValue: skillWheelData().professionSkills },
    nodes:       { type: 'json', description: '{ "<Skill>:<tier>": { skill, tier, depth, affinity, requires, unlock } }', defaultValue: skillWheelData().nodes },
  },
})

module.exports = { AFFINITY_OVERRIDES, skillWheelData, skillWheelRefs, skillWheelProblems, validateSkillWheel, SkillWheel }
