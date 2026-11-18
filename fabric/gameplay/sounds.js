const { defineEntity } = require('@newel/core')

// Phase 275 — the sound event table. Gameplay code plays an EVENT by id (`Sound.play("ui.click")`), never a path:
// the event names the asset key, the bus, whether it is positional, how many variants it has, its base volume and
// its pitch jitter. The files of an event follow from its key (see `soundFiles`), so a contributor adds a sound by
// adding a row here, regenerating, and running `python3 tools/gen_placeholder_audio.py` for its placeholder.
//
// Key layout (public `assets/` and private `assets-prod/` mirror it; every file ends in `.ogg.raw`):
//   sounds/ui/<event>                         one file, `<key>.ogg.raw`, bus UI, never positional
//   sounds/sfx/items/<ItemId>/<event>         `<key>_01.ogg.raw` .. `_NN` (variants), bus Effects
//   sounds/sfx/creatures/<Entity>/<event>     same
//   sounds/sfx/player/footsteps/<surface>     same
//   sounds/sfx/world/<thing>                  same
//   sounds/ambience/<Biome>                   one looping file, bus Ambience, never positional
//   sounds/music/<track>                      one looping file, bus Music, never positional

/** The audio buses under Master, in `default_bus_layout.tres` order. */
const BUSES = ['Music', 'Effects', 'Ambience', 'UI']

const MAX_VARIANTS = 8

/**
 * event id -> row. `volumeDb` is the base volume, `pitchJitter` the largest pitch-scale change either way
 * (0.08 = 0.92..1.08), `maxDistance` (3d only) the metres past which a positional sound is silent.
 * Phase 275 shipped a starter set, one per folder kind, so the loader, the player and the placeholder generator
 * are tested end to end; Phase 276 wires them into gameplay and adds the rest of the first set: the window
 * open/close sounds, footsteps on stone and sand, the dig, and the pickup. Who plays what is in
 * `src/audio/audio_wiring.gd` (and the button and window hooks in `sound_player.gd` / `ui_slice.gd`).
 */
const EVENTS = {
  'ui.click':                   { key: 'sounds/ui/click', bus: 'UI', spatial: '2d', variants: 1, volumeDb: -6, pitchJitter: 0, loop: false },
  'ui.window_open':             { key: 'sounds/ui/window_open', bus: 'UI', spatial: '2d', variants: 1, volumeDb: -8, pitchJitter: 0, loop: false },
  'ui.window_close':            { key: 'sounds/ui/window_close', bus: 'UI', spatial: '2d', variants: 1, volumeDb: -8, pitchJitter: 0, loop: false },
  'footstep.grass':             { key: 'sounds/sfx/player/footsteps/grass', bus: 'Effects', spatial: '3d', variants: 3, volumeDb: -8, pitchJitter: 0.08, loop: false, maxDistance: 20 },
  'footstep.stone':             { key: 'sounds/sfx/player/footsteps/stone', bus: 'Effects', spatial: '3d', variants: 3, volumeDb: -8, pitchJitter: 0.08, loop: false, maxDistance: 20 },
  'footstep.sand':              { key: 'sounds/sfx/player/footsteps/sand', bus: 'Effects', spatial: '3d', variants: 3, volumeDb: -9, pitchJitter: 0.08, loop: false, maxDistance: 20 },
  'world.dig':                  { key: 'sounds/sfx/world/dig', bus: 'Effects', spatial: '3d', variants: 3, volumeDb: -5, pitchJitter: 0.06, loop: false, maxDistance: 30 },
  'world.pickup':               { key: 'sounds/sfx/world/pickup', bus: 'Effects', spatial: '2d', variants: 2, volumeDb: -6, pitchJitter: 0.04, loop: false },
  'item.StonePick.hit':         { key: 'sounds/sfx/items/StonePick/hit', bus: 'Effects', spatial: '3d', variants: 2, volumeDb: -4, pitchJitter: 0.05, loop: false, maxDistance: 30 },
  'creature.GraywolfPack.attack': { key: 'sounds/sfx/creatures/GraywolfPack/attack', bus: 'Effects', spatial: '3d', variants: 2, volumeDb: -2, pitchJitter: 0.06, loop: false, maxDistance: 40 },
  'ambience.TemperateForest':   { key: 'sounds/ambience/TemperateForest', bus: 'Ambience', spatial: '2d', variants: 1, volumeDb: -10, pitchJitter: 0, loop: true },
  'music.main_theme':           { key: 'sounds/music/main_theme', bus: 'Music', spatial: '2d', variants: 1, volumeDb: -6, pitchJitter: 0, loop: true },
}

/**
 * Phase 276 — what a footstep sounds like underfoot: natural ground by its terrain material
 * (`fabric/world/terrain_materials.js`, the material the biome's flat ground is drawn with) and any placed block,
 * each naming a surface whose `footstep.<surface>` event is in EVENTS. Every terrain material has a surface.
 */
const FOOTSTEPS = {
  terrain: {
    TerrainGrass: 'grass', TerrainMoss: 'grass', TerrainDirt: 'grass', TerrainMud: 'grass',
    TerrainRock: 'stone',
    TerrainSand: 'sand', TerrainSnow: 'sand',
  },
  block: 'stone',
}

const NAME = '[A-Za-z0-9_]+'
/** folder pattern -> what an event under it must be. `ref` names the fabric list the first segment must be in. */
const FOLDERS = [
  { kind: 'ui',       re: new RegExp(`^sounds/ui/${NAME}$`),                       bus: 'UI',       spatial: ['2d'],       loop: false, variants: false },
  { kind: 'items',    re: new RegExp(`^sounds/sfx/items/(${NAME})/${NAME}$`),      bus: 'Effects',  spatial: ['2d', '3d'], loop: false, variants: true, ref: 'items' },
  { kind: 'creatures', re: new RegExp(`^sounds/sfx/creatures/(${NAME})/${NAME}$`), bus: 'Effects',  spatial: ['2d', '3d'], loop: false, variants: true, ref: 'creatures' },
  { kind: 'footsteps', re: new RegExp(`^sounds/sfx/player/footsteps/${NAME}$`),   bus: 'Effects',  spatial: ['2d', '3d'], loop: false, variants: true },
  { kind: 'world',    re: new RegExp(`^sounds/sfx/world/${NAME}$`),                bus: 'Effects',  spatial: ['2d', '3d'], loop: false, variants: true },
  { kind: 'ambience', re: new RegExp(`^sounds/ambience/(${NAME})$`),               bus: 'Ambience', spatial: ['2d'],       loop: true,  variants: false, ref: 'biomes' },
  { kind: 'music',    re: new RegExp(`^sounds/music/${NAME}$`),                    bus: 'Music',    spatial: ['2d'],       loop: true,  variants: false },
]

function folderOf(key) {
  return FOLDERS.find((f) => f.re.test(key)) || null
}

/** The asset keys of one event row: `<key>.ogg.raw` for ui/ambience/music, `<key>_01.ogg.raw`.. for sfx. */
function soundFiles(row) {
  const f = folderOf(row.key)
  if (!f || !f.variants) return [`${row.key}.ogg.raw`]
  const out = []
  for (let i = 1; i <= row.variants; i++) out.push(`${row.key}_${String(i).padStart(2, '0')}.ogg.raw`)
  return out
}

function soundsData() {
  return JSON.parse(JSON.stringify({ buses: BUSES, events: EVENTS, footsteps: FOOTSTEPS }))
}

function soundsRefs() {
  return {
    items: Object.keys(require('./items')),
    creatures: Object.keys(require('../world/creatures')),
    biomes: Object.keys(require('../world/biomes')),
    terrain: Object.keys(require('../world/terrain_materials').TERRAIN_MATERIALS),
  }
}

/** Problems with the sound tables, as strings. */
function soundsProblems(d, refs) {
  const p = []
  if (JSON.stringify(d.buses) !== JSON.stringify(BUSES)) p.push(`buses must be ${BUSES.join(', ')} (default_bus_layout.tres)`)
  const keys = new Map()
  for (const [id, row] of Object.entries(d.events || {})) {
    if (!/^[a-z]+(\.[A-Za-z0-9_]+)+$/.test(id)) p.push(`event "${id}": id must be <category>.<name>[.<name>] (lowercase category)`)
    const f = folderOf(String(row.key || ''))
    if (!f) { p.push(`event ${id}: key "${row.key}" is not in the sound key layout`); continue }
    if (keys.has(row.key)) p.push(`event ${id}: key ${row.key} is already used by ${keys.get(row.key)}`)
    keys.set(row.key, id)
    if (f.ref) {
      const name = f.re.exec(row.key)[1]
      if (!refs[f.ref].includes(name)) p.push(`event ${id}: ${name} is not one of the fabric's ${f.ref}`)
    }
    if (row.bus !== f.bus) p.push(`event ${id}: a ${f.kind} sound plays on bus ${f.bus}, not ${row.bus}`)
    if (!f.spatial.includes(row.spatial)) p.push(`event ${id}: a ${f.kind} sound is ${f.spatial.join(' or ')}, not ${row.spatial}`)
    if (row.loop !== f.loop) p.push(`event ${id}: a ${f.kind} sound must have loop ${f.loop}`)
    if (!Number.isInteger(row.variants) || row.variants < 1 || row.variants > MAX_VARIANTS) p.push(`event ${id}: variants must be 1..${MAX_VARIANTS}`)
    else if (!f.variants && row.variants !== 1) p.push(`event ${id}: a ${f.kind} sound has exactly 1 variant`)
    if (!(typeof row.volumeDb === 'number' && row.volumeDb >= -40 && row.volumeDb <= 6)) p.push(`event ${id}: volumeDb must be in [-40, 6]`)
    if (!(typeof row.pitchJitter === 'number' && row.pitchJitter >= 0 && row.pitchJitter <= 0.5)) p.push(`event ${id}: pitchJitter must be in [0, 0.5]`)
    if (row.spatial === '3d' && !(typeof row.maxDistance === 'number' && row.maxDistance > 0)) p.push(`event ${id}: a 3d sound needs maxDistance > 0`)
    if (row.spatial !== '3d' && 'maxDistance' in row) p.push(`event ${id}: maxDistance is for 3d sounds only`)
  }
  p.push(...footstepProblems(d, refs))
  return p
}

/** Phase 276 — every terrain material has a surface, every named material exists, and every surface has its event. */
function footstepProblems(d, refs) {
  const p = []
  const fs = d.footsteps || {}
  const terrain = fs.terrain || {}
  const surface = (where, s) => {
    const ev = (d.events || {})[`footstep.${s}`]
    if (typeof s !== 'string' || !ev) p.push(`footsteps ${where}: surface "${s}" has no footstep.${s} event`)
    else if (ev.key !== `sounds/sfx/player/footsteps/${s}`) p.push(`footsteps ${where}: footstep.${s} must use the key sounds/sfx/player/footsteps/${s}`)
  }
  for (const m of refs.terrain) if (!(m in terrain)) p.push(`footsteps: terrain material ${m} has no surface`)
  for (const [m, s] of Object.entries(terrain)) {
    if (!refs.terrain.includes(m)) p.push(`footsteps: ${m} is not one of the fabric's terrain materials`)
    surface(m, s)
  }
  surface('block', fs.block)
  return p
}

function validateSounds(d, refs) {
  const problems = soundsProblems(d, refs)
  if (problems.length) throw new Error('Sound events are invalid:\n  ' + problems.join('\n  '))
}

/** event id -> its asset keys, generated beside the table so the runtime and the placeholder tool share the rule. */
function eventFiles(events) {
  const out = {}
  for (const [id, row] of Object.entries(events)) out[id] = soundFiles(row)
  return out
}

const SoundEvents = defineEntity({
  tags: ['world-system'],
  description:
    'The sound event table: gameplay plays an event id, which names the asset key, the audio bus, whether it is ' +
    'positional, how many variants it picks from, its base volume and its pitch jitter. Files live under ' +
    '`assets/sounds/` as `.ogg.raw`, with a generated placeholder for every key.',
  goal: 'Sounds are data: a new sound is a row and a file, never a path in gameplay code (Phase 275)',
  fields: {
    id:     { type: 'uuid', primaryKey: true },
    buses:  { type: 'json', description: 'The audio buses under Master, in layout order', defaultValue: BUSES },
    events: { type: 'json', description: '{ <event id>: { key, bus, spatial: 2d|3d, variants, volumeDb, pitchJitter, loop, maxDistance? } }', defaultValue: EVENTS },
    files:  { type: 'json', description: '{ <event id>: [asset keys] } — `<key>.ogg.raw`, or `<key>_01.ogg.raw`.. for sfx variants', defaultValue: eventFiles(EVENTS) },
    footsteps: { type: 'json', description: '{ terrain: { <terrain material>: <surface> }, block: <surface> } — the footstep.<surface> event underfoot (Phase 276)', defaultValue: FOOTSTEPS },
  },
})

module.exports = { BUSES, EVENTS, FOOTSTEPS, FOLDERS, MAX_VARIANTS, soundFiles, eventFiles, soundsData, soundsRefs, soundsProblems, footstepProblems, validateSounds, SoundEvents }
