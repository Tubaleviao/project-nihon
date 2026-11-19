const { defineEntity } = require('@newel/core')

// Phase 273 — titles. A title is a short name shown under a player's name. Every character has the built-in
// `Newcomer`; a profession that becomes `active` unlocks its first title, one that becomes `mastered` its
// second; a skill reaching its master tier unlocks that skill's title. Ids are derived from the source (a
// profession `Blacksmith` gives `Blacksmith` and `MasterBlacksmith`, a skill `Smithing` gives `MasterSmithing`);
// each id needs a `title.<Id>.name` row in locale/content.csv (Phase 267). The host unlocks titles when it
// records the transition and lets a player wear any one it has unlocked, or none; recipe gates keep checking
// professions, never the chosen title.

const BUILTIN = 'Newcomer'

function entitiesTagged(tag, mod) {
  const out = []
  for (const [k, e] of Object.entries(require(mod))) if (e && e.tags && e.tags.includes(tag)) out.push(k)
  return out
}

/** { <TitleId>: { source: { kind: 'builtin' | 'profession' | 'skill', id?, state?: 'active'|'mastered', tier?: 'master' } } } */
function titlesData() {
  const titles = { [BUILTIN]: { source: { kind: 'builtin' } } }
  for (const p of entitiesTagged('profession', './professions')) {
    titles[p] = { source: { kind: 'profession', id: p, state: 'active' } }
    titles[`Master${p}`] = { source: { kind: 'profession', id: p, state: 'mastered' } }
  }
  for (const s of entitiesTagged('skill', './skills')) titles[`Master${s}`] = { source: { kind: 'skill', id: s, tier: 'master' } }
  return JSON.parse(JSON.stringify({ builtin: BUILTIN, titles }))
}

function titlesRefs() {
  return { professions: entitiesTagged('profession', './professions'), skills: entitiesTagged('skill', './skills') }
}

const sourceKey = (s) => [s.kind, s.id || '', s.state || s.tier || ''].join(':')

/** Problems with the title table; `names` (optional) is { <locale>: Set(title ids that have a name) }. */
function titlesProblems(d, refs, names) {
  const p = []
  const seen = new Map()
  if (!(d.builtin in d.titles)) p.push(`builtin title ${d.builtin} is not in the table`)
  for (const [id, t] of Object.entries(d.titles || {})) {
    if (!/^[A-Z][A-Za-z0-9]*$/.test(id)) p.push(`${id}: id must be CamelCase`)
    const s = t.source || {}
    if (s.kind === 'builtin') { if (id !== d.builtin) p.push(`${id}: only ${d.builtin} is built in`) }
    else if (s.kind === 'profession') {
      if (!refs.professions.includes(s.id)) p.push(`${id}: unknown profession ${s.id}`)
      if (!['active', 'mastered'].includes(s.state)) p.push(`${id}: profession state must be active or mastered`)
    } else if (s.kind === 'skill') {
      if (!refs.skills.includes(s.id)) p.push(`${id}: unknown skill ${s.id}`)
      if (s.tier !== 'master') p.push(`${id}: a skill title is for the master tier`)
    } else p.push(`${id}: unknown source kind ${s.kind}`)
    const k = sourceKey(s)
    if (seen.has(k)) p.push(`${id}: same source as ${seen.get(k)}`)
    else seen.set(k, id)
    for (const [loc, set] of Object.entries(names || {})) if (!set.has(id)) p.push(`${id}: no ${loc} name`)
  }
  for (const pr of refs.professions) for (const st of ['active', 'mastered']) {
    if (!seen.has(sourceKey({ kind: 'profession', id: pr, state: st }))) p.push(`${pr}: no title for ${st}`)
  }
  for (const sk of refs.skills) if (!seen.has(sourceKey({ kind: 'skill', id: sk, tier: 'master' }))) p.push(`${sk}: no master title`)
  return p
}

function validateTitles(d, refs) {
  const problems = titlesProblems(d, refs)
  if (problems.length) throw new Error('Titles are invalid:\n  ' + problems.join('\n  '))
}

const Titles = defineEntity({
  tags: ['world-system'],
  description:
    'Titles: names shown under a player. Every character has Newcomer; professions (active, mastered) and skills ' +
    '(master tier) unlock more, and the player wears one or none. Never gates anything.',
  goal: 'Let professions and mastery show on a character as a chosen title (Phase 273)',
  fields: {
    id:      { type: 'uuid', primaryKey: true },
    builtin: { type: 'string', description: 'The title every character has from creation', defaultValue: titlesData().builtin },
    titles:  { type: 'json', description: '{ <TitleId>: { source: { kind, id?, state?, tier? } } }', defaultValue: titlesData().titles },
  },
})

module.exports = { BUILTIN, titlesData, titlesRefs, titlesProblems, validateTitles, Titles }
