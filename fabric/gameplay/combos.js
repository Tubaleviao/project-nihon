const { defineEntity } = require('@newel/core')

// Phase 287 — fighting that reads. Repeated attacks inside a window cycle through a weapon class's clip variants;
// each step names its clip, the damage multiplier it deals and the `impact` time (a 0..1 share of the clip's
// length, mirroring the asset's impact marker) at which the host resolves the hit. A missing variant on a rig
// falls back to the class's first clip. A hit past `staggerShare` of the target's max health staggers it, a lighter
// one plays `hit`; `knockback` is the metres a struck target is pushed away from the attacker.
// The host reads this table, never a client message.

/** Every attack clip a rig may play: the rig contract (placeholders on the public player_rig first). */
const ATTACK_CLIPS = [
  'attack', 'attack_unarmed', 'attack_unarmed_2', 'attack_1h', 'attack_1h_2', 'attack_1h_3',
  'attack_2h', 'attack_2h_2', 'attack_tool',
]

const CHAINS = {
  unarmed:  { clips: ['attack_unarmed', 'attack_unarmed_2'], windowSeconds: 1.2, damageMultipliers: [1.0, 1.15], impact: [0.4, 0.45] },
  one_hand: { clips: ['attack_1h', 'attack_1h_2', 'attack_1h_3'], windowSeconds: 1.2, damageMultipliers: [1.0, 1.1, 1.3], impact: [0.5, 0.45, 0.55] },
  two_hand: { clips: ['attack_2h', 'attack_2h_2'], windowSeconds: 1.5, damageMultipliers: [1.0, 1.25], impact: [0.55, 0.6] },
  tool:     { clips: ['attack_tool'], windowSeconds: 1.0, damageMultipliers: [1.0], impact: [0.5] },
}


const STAGGER_SHARE = 0.25
const KNOCKBACK_LIGHT = 0.3
const KNOCKBACK_HEAVY = 0.8

function combosData() {
  return JSON.parse(JSON.stringify({
    attackClips: ATTACK_CLIPS, chains: CHAINS, staggerShare: STAGGER_SHARE,
    knockbackLight: KNOCKBACK_LIGHT, knockbackHeavy: KNOCKBACK_HEAVY,
  }))
}

/** Problems with the combo table, as strings. */
function combosProblems(d) {
  const p = []
  const contract = new Set(d.attackClips || [])
  if (!(d.staggerShare > 0 && d.staggerShare < 1)) p.push('staggerShare must be in (0, 1)')
  for (const k of ['knockbackLight', 'knockbackHeavy']) if (!(d[k] >= 0)) p.push(`${k} must be a distance >= 0`)
  if (d.knockbackHeavy < d.knockbackLight) p.push('knockbackHeavy must be at least knockbackLight')
  for (const [name, c] of Object.entries(d.chains || {})) {
    const n = (c.clips || []).length
    if (n < 1) p.push(`chains.${name}: needs at least one clip`)
    for (const clip of c.clips || []) if (!contract.has(clip)) p.push(`chains.${name}: clip "${clip}" is outside the rig contract`)
    if (!(c.windowSeconds > 0)) p.push(`chains.${name}.windowSeconds must be > 0`)
    if ((c.damageMultipliers || []).length !== n || !c.damageMultipliers.every((m) => m > 0)) p.push(`chains.${name}.damageMultipliers needs a multiplier > 0 per clip`)
    if ((c.impact || []).length !== n || !c.impact.every((t) => typeof t === 'number' && t >= 0 && t <= 1)) p.push(`chains.${name}.impact needs a time in 0..1 per clip`)
  }
  for (const need of ['unarmed', 'one_hand', 'two_hand', 'tool']) if (!(d.chains || {})[need]) p.push(`chains.${need} is missing`)
  return p
}

function validateCombos(d) {
  const problems = combosProblems(d)
  if (problems.length) throw new Error('Combos are invalid:\n  ' + problems.join('\n  '))
}

const CombatCombos = defineEntity({
  tags: ['world-system'],
  description:
    'Attack combos and hit timing: per weapon class the clip order, the window that keeps a chain going, the damage ' +
    'multiplier and impact time of each step, the stagger share and the knock-back of a struck target.',
  goal: 'Make fighting read: variation, a hit that lands when the blow does, and a target that reacts (Phase 287)',
  fields: {
    id:             { type: 'uuid', primaryKey: true },
    attackClips:    { type: 'json', description: 'The attack clips a rig may play (the rig contract)', defaultValue: ATTACK_CLIPS },
    chains:         { type: 'json', description: '{ <unarmed|one_hand|two_hand|tool>: { clips, windowSeconds, damageMultipliers, impact } }', defaultValue: CHAINS },
    staggerShare:   { type: 'decimal', description: 'A hit of at least this share of the target\'s max health staggers it; a lighter one plays hit', defaultValue: STAGGER_SHARE },
    knockbackLight: { type: 'decimal', description: 'Metres a target is pushed away by a light hit', defaultValue: KNOCKBACK_LIGHT },
    knockbackHeavy: { type: 'decimal', description: 'Metres a target is pushed away by a staggering hit', defaultValue: KNOCKBACK_HEAVY },
  },
})

module.exports = { ATTACK_CLIPS, CHAINS, combosData, combosProblems, validateCombos, CombatCombos }
