const { defineEntity } = require('@newel/core')

// Phase 281 — work you can see. Which rig clip each kind of work plays, and whether it loops (a hold: one strike per
// work tick) or plays once (a single action). A rig without the clip falls back to `attack_tool`.
// `impact` is the fraction of the clip at which the strike lands (the fallback `attack_tool` uses the same 0.4); the
// tick's chips, sound and progress step happen at that moment.

/** Clips the player rig contract carries for work (assets A41 replaces the placeholders under the same names). */
const RIG_CLIPS = ['chop', 'mine', 'dig', 'build', 'dissect', 'attack_tool']
const MODES = ['loop', 'once']
const FALLBACK_CLIP = 'attack_tool'
const IMPACT = 0.4

/** work kind -> { clip, mode, impact }. Holds: chop, mine, dig, dissect. Singles (WorkSkills SINGLE_KINDS): build,
 * dismantle, repair all play `build` once until art splits them; lockpick has no work motion yet. */
const WORK_CLIPS = {
  chop:      { clip: 'chop',    mode: 'loop', impact: IMPACT },
  mine:      { clip: 'mine',    mode: 'loop', impact: IMPACT },
  dig:       { clip: 'dig',     mode: 'loop', impact: IMPACT },
  dissect:   { clip: 'dissect', mode: 'loop', impact: IMPACT },
  build:     { clip: 'build',   mode: 'once', impact: IMPACT },
  dismantle: { clip: 'build',   mode: 'once', impact: IMPACT },
  repair:    { clip: 'build',   mode: 'once', impact: IMPACT },
}
const REQUIRED_KINDS = ['chop', 'mine', 'dig', 'dissect', 'build', 'dismantle', 'repair']

function workClipsData() {
  return { fallbackClip: FALLBACK_CLIP, rigClips: RIG_CLIPS.slice(), clips: JSON.parse(JSON.stringify(WORK_CLIPS)) }
}

function workClipsProblems(d) {
  const p = []
  const rig = d.rigClips || []
  if (!rig.includes(d.fallbackClip)) p.push(`fallbackClip "${d.fallbackClip}" is not on the rig contract`)
  for (const kind of REQUIRED_KINDS) {
    if (!d.clips || !d.clips[kind]) p.push(`work kind "${kind}" has no clip`)
  }
  for (const [kind, row] of Object.entries(d.clips || {})) {
    if (!REQUIRED_KINDS.includes(kind)) p.push(`clips.${kind}: unknown work kind`)
    if (!rig.includes(row.clip)) p.push(`clips.${kind}: clip "${row.clip}" is not on the rig contract (${rig.join(', ')})`)
    if (!MODES.includes(row.mode)) p.push(`clips.${kind}: mode "${row.mode}" must be one of ${MODES.join(', ')}`)
    if (typeof row.impact !== 'number' || !(row.impact > 0 && row.impact < 1)) p.push(`clips.${kind}: impact must be a fraction in (0, 1)`)
  }
  return p
}

function validateWorkClips(d) {
  const problems = workClipsProblems(d)
  if (problems.length) throw new Error('Work clips are invalid:\n  ' + problems.join('\n  '))
}

const WorkClips = defineEntity({
  tags: ['world-system'],
  description: 'Which rig clip each kind of work plays (loop for a hold, once for a single action), and the fraction of the clip at which the strike lands.',
  goal: 'Make work visible: every kind of work has its own motion, and other players see it (Phase 281)',
  fields: {
    id:           { type: 'uuid', primaryKey: true },
    fallbackClip: { type: 'string', description: 'Clip a rig without the work clip plays', defaultValue: FALLBACK_CLIP },
    rigClips:     { type: 'json', description: 'Clip names the player rig contract carries for work', defaultValue: RIG_CLIPS },
    clips:        { type: 'json', description: '{ <work kind>: { clip, mode: loop|once, impact } }', defaultValue: WORK_CLIPS },
  },
})

module.exports = { RIG_CLIPS, WORK_CLIPS, REQUIRED_KINDS, workClipsData, workClipsProblems, validateWorkClips, WorkClips }
