const { defineEntity } = require('@newel/core')

// Phase 158 — gestures. One entity per gesture, read at runtime from GameData.GESTURES by Phase 159.
//
// `clip`: rig clip name the gesture plays (every placeholder player rig must carry it).
// `kind`: `pose` is held until cancelled, `oneShot` plays once and ends.
// `cancelOnMove` / `cancelOnDamage`: a movement intent / taking damage ends the gesture.
// `requiresGround`: the player must stand on the ground (not swim or fall) to start it.
// `restRegen`: multiplier on HP/stamina regeneration while held; 1.0 for none, never below.
// `chatCommand`: slash command that starts it; unique across gestures.
// `nameKey`: translation key for the gesture's name (locale/ui.csv).
const KINDS = ['pose', 'oneShot']
const FIELDS = ['clip', 'kind', 'cancelOnMove', 'cancelOnDamage', 'requiresGround', 'restRegen', 'chatCommand', 'nameKey']

function gesture(description, f) {
  return defineEntity({
    tags: ['gesture'],
    description,
    goal: 'Let players look alive together: sit, lie down and signal each other',
    fields: {
      clip:           { type: 'string',  description: 'Rig clip name', defaultValue: f.clip },
      kind:           { type: 'enum', values: KINDS, description: '`pose` (held until cancelled) or `oneShot`', defaultValue: f.kind },
      cancelOnMove:   { type: 'boolean', description: 'A movement intent ends the gesture', defaultValue: f.cancelOnMove },
      cancelOnDamage: { type: 'boolean', description: 'Taking damage ends the gesture', defaultValue: f.cancelOnDamage },
      requiresGround: { type: 'boolean', description: 'The player must stand on the ground to start it', defaultValue: f.requiresGround },
      restRegen:      { type: 'decimal',  description: 'HP/stamina regeneration multiplier while held (1.0 = none, never below)', defaultValue: f.restRegen },
      chatCommand:    { type: 'string',  description: 'Slash command that starts the gesture', defaultValue: f.chatCommand },
      nameKey:        { type: 'string',  description: 'Translation key for the gesture name', defaultValue: f.nameKey },
    },
  })
}

const oneShot = (clip, cmd, extra = {}) => ({
  clip, kind: 'oneShot', cancelOnMove: false, cancelOnDamage: false, requiresGround: false,
  restRegen: 1.0, chatCommand: cmd, nameKey: `gesture.${clip}`, ...extra,
})
const pose = (clip, cmd, extra = {}) => ({
  clip, kind: 'pose', cancelOnMove: true, cancelOnDamage: false, requiresGround: true,
  restRegen: 1.0, chatCommand: cmd, nameKey: `gesture.${clip}`, ...extra,
})

const Sit       = gesture('Sit on a seat-height surface or the ground edge; a small rest bonus.', pose('sit', '/sit', { restRegen: 1.5 }))
const SitGround = gesture('Sit cross-legged on the ground; a small rest bonus.', pose('sit_ground', '/sitground', { restRegen: 1.5 }))
const LieDown   = gesture('Lie down flat; the best rest bonus, and any hit gets you up.', pose('lie_down', '/lie', { restRegen: 2.0, cancelOnDamage: true }))
const Wave      = gesture('Wave a hand in greeting.', oneShot('wave', '/wave'))
const Point     = gesture('Point ahead.', oneShot('point', '/point'))
const Bow       = gesture('Bow politely.', oneShot('bow', '/bow', { requiresGround: true }))
const Cheer     = gesture('Raise both arms and cheer.', oneShot('cheer', '/cheer'))
const Shrug     = gesture('Shrug.', oneShot('shrug', '/shrug'))
const Clap      = gesture('Clap hands.', oneShot('clap', '/clap'))
const Kneel     = gesture('Kneel on one knee.', pose('kneel', '/kneel', { restRegen: 1.0 }))

const GESTURES = { Sit, SitGround, LieDown, Wave, Point, Bow, Cheer, Shrug, Clap, Kneel }

/** Problems with a gesture table ({ key: fieldDefaults }), as strings. */
function gestureProblems(table) {
  const problems = []
  const cmds = new Map()
  for (const [key, f] of Object.entries(table)) {
    for (const name of FIELDS) if (!(name in f)) problems.push(`Gesture ${key} is missing "${name}"`)
    for (const name of Object.keys(f)) if (!FIELDS.includes(name)) problems.push(`Gesture ${key} has unknown field "${name}"`)
    if (typeof f.clip !== 'string' || f.clip === '') problems.push(`Gesture ${key}.clip must be a non-empty string`)
    if (!KINDS.includes(f.kind)) problems.push(`Gesture ${key}.kind must be one of ${KINDS.join(', ')}, got "${f.kind}"`)
    for (const b of ['cancelOnMove', 'cancelOnDamage', 'requiresGround']) {
      if (typeof f[b] !== 'boolean') problems.push(`Gesture ${key}.${b} must be a boolean`)
    }
    if (typeof f.restRegen !== 'number' || !(f.restRegen >= 1.0)) problems.push(`Gesture ${key}.restRegen must be >= 1.0, got ${f.restRegen}`)
    if (typeof f.chatCommand !== 'string' || !/^\/[a-z]+$/.test(f.chatCommand)) {
      problems.push(`Gesture ${key}.chatCommand must look like "/word", got "${f.chatCommand}"`)
    } else if (cmds.has(f.chatCommand)) {
      problems.push(`Gestures ${cmds.get(f.chatCommand)} and ${key} share chatCommand ${f.chatCommand}`)
    } else cmds.set(f.chatCommand, key)
    if (typeof f.nameKey !== 'string' || f.nameKey === '') problems.push(`Gesture ${key}.nameKey must be a non-empty string`)
  }
  return problems
}

/** Field defaults of every shipped gesture, keyed by entity name. */
function gestureTable(entities = GESTURES) {
  const out = {}
  for (const [key, e] of Object.entries(entities)) {
    const row = {}
    for (const [name, def] of Object.entries(e.fields || {})) row[name] = def.defaultValue
    out[key] = row
  }
  return out
}

function validateGestures(table) {
  const problems = gestureProblems(table)
  if (problems.length) throw new Error('Gesture table is invalid:\n  ' + problems.join('\n  '))
}

module.exports = { ...GESTURES, GESTURES, gestureProblems, gestureTable, validateGestures }
