const { defineEntity } = require('@newel/core')

// Phase 184 — the first-steps tutorial as data. Phase 186 shows each step once as a small card and
// completes it from bus events the client already receives; adding or reordering a step is a change
// here, not in code. Read at runtime from GameData.TUTORIALS["Tutorial"].
//
// A step: { id, chapter, inputs, requires, trigger }.
//   id        unique snake_case; the card text is the catalog keys tutorial.<id>.title / .body
//   chapter   one of CHAPTERS (catalog key tutorial.chapter.<chapter>)
//   inputs    INPUT_ACTIONS the card names; the runtime shows the player's own key for each from the
//             `?` controls rows (UiSlice.controls_rows, each row carries its action id)
//   requires  step ids that must be done first; each names an EARLIER step, so the order is a valid
//             topological order and there are no cycles
//   trigger   { kind, ...params }: one of TRIGGER_KINDS, with exactly the params that kind takes
//
// Trigger params name fabric data: `item` an item or material key, `tag` an entity tag
// (item, material, creature) or a tool type (pick, axe), `type` a placeable station type, `window` a
// UI window key, `slot` an equipment slot, `creature` a creature key, `technology` a technology key.

const CHAPTERS = [
  'moving', 'gathering', 'first_stations', 'first_tools', 'shelter', 'first_hunt',
  'staying_alive', 'finding_way', 'growing', 'other_people', 'first_village',
]

// kind -> { required: params it must have, oneOf: exactly one of these params }. No other param is allowed.
const TRIGGER_KINDS = {
  moved_metres:          { required: ['metres'] },
  camera_turned:         {},
  jumped:                {},
  item_gathered:         { required: ['count'], oneOf: ['item', 'tag'] },
  item_crafted:          { oneOf: ['item', 'tag'] },
  station_placed:        { required: ['type'] },
  window_opened:         { required: ['window'] },
  hotbar_bound:          {},
  item_equipped:         { required: ['slot'] },
  creature_killed:       { oneOf: ['creature', 'tag'] },
  carcass_harvested:     {},
  bed_placed:            {},
  shelter_complete:      {},
  respawned:             {},
  waystone_discovered:   {},
  skill_tier_up:         {},
  technology_researched: { required: ['technology'] },
  chat_sent:             {},
  // Phase 198 — the local player's settlement project intent succeeded on the host.
  project_started:       {},
  project_contributed:   {},
}

// The input actions a card can name, in the order of the `?` controls rows (UiSlice.controls_rows).
const INPUT_ACTIONS = [
  'move', 'jump', 'look', 'zoom', 'hotbar_use', 'hotbar_expand', 'drag', 'attack', 'mine', 'place',
  'next_block', 'station', 'tame', 'equipment', 'chest', 'windows', 'controls', 'chat', 'close',
]

// UI windows a step may wait for (UiSlice.WINDOW_KEYS; the suite checks every one exists there).
const WINDOWS = [
  'inventory', 'technology', 'crafting', 'trade', 'market', 'proposals', 'controls', 'character',
  'skills', 'map', 'settlement', 'gestures',
]

const step = (id, chapter, inputs, requires, trigger) => ({ id, chapter, inputs, requires, trigger })

const STEPS = [
  // Moving
  step('move', 'moving', ['move'], [], { kind: 'moved_metres', metres: 10 }),
  step('jump', 'moving', ['jump'], ['move'], { kind: 'jumped' }),
  step('look', 'moving', ['look', 'zoom'], ['move'], { kind: 'camera_turned' }),
  step('controls', 'moving', ['controls'], ['look'], { kind: 'window_opened', window: 'controls' }),
  // Gathering (bare hands mine; the starting axe chops)
  step('mine', 'gathering', ['mine'], ['move'], { kind: 'item_gathered', tag: 'material', count: 1 }),
  step('chop', 'gathering', ['attack'], ['mine'], { kind: 'item_gathered', item: 'Thornwood', count: 4 }),
  step('inventory', 'gathering', [], ['mine'], { kind: 'window_opened', window: 'inventory' }),
  step('hotbar', 'gathering', ['drag', 'hotbar_expand', 'hotbar_use'], ['inventory'], { kind: 'hotbar_bound' }),
  // First stations: research, a carpentry bench and its first recipe
  step('technology', 'first_stations', [], ['chop'], { kind: 'window_opened', window: 'technology' }),
  step('research_carpentry', 'first_stations', [], ['technology'], { kind: 'technology_researched', technology: 'TechBasicCarpentry' }),
  step('place_bench', 'first_stations', ['station'], ['chop'], { kind: 'station_placed', type: 'carpentry bench' }),
  step('crafting', 'first_stations', [], ['chop'], { kind: 'window_opened', window: 'crafting' }),
  step('craft_planks', 'first_stations', [], ['place_bench', 'research_carpentry', 'crafting'], { kind: 'item_crafted', item: 'ThornwoodPlank' }),
  // First tools: a forge, smithing and a pick that mines faster
  step('place_forge', 'first_tools', ['station'], ['craft_planks'], { kind: 'station_placed', type: 'forge' }),
  step('research_smithing', 'first_tools', [], ['place_forge'], { kind: 'technology_researched', technology: 'TechBasicSmithing' }),
  step('craft_tool', 'first_tools', [], ['research_smithing'], { kind: 'item_crafted', tag: 'pick' }),
  step('use_tool', 'first_tools', ['mine'], ['craft_tool'], { kind: 'item_gathered', tag: 'material', count: 5 }),
  // Shelter: a bed, placed, then walled and roofed
  step('craft_bed', 'shelter', [], ['craft_planks'], { kind: 'item_crafted', item: 'Bed' }),
  step('place_bed', 'shelter', ['station'], ['craft_bed'], { kind: 'bed_placed' }),
  step('build_shelter', 'shelter', ['next_block', 'place'], ['place_bed'], { kind: 'shelter_complete' }),
  // First hunt
  step('equip_weapon', 'first_hunt', ['equipment'], ['research_smithing'], { kind: 'item_equipped', slot: 'MainHand' }),
  step('kill', 'first_hunt', ['attack'], ['equip_weapon'], { kind: 'creature_killed', tag: 'creature' }),
  step('harvest', 'first_hunt', [], ['kill'], { kind: 'carcass_harvested' }),
  // Staying alive
  step('respawn', 'staying_alive', [], ['place_bed'], { kind: 'respawned' }),
  // Finding your way
  step('map', 'finding_way', [], ['move'], { kind: 'window_opened', window: 'map' }),
  step('waystone', 'finding_way', [], ['map'], { kind: 'waystone_discovered' }),
  // Growing
  step('skills', 'growing', [], ['chop'], { kind: 'window_opened', window: 'skills' }),
  step('tier_up', 'growing', [], ['skills'], { kind: 'skill_tier_up' }),
  step('character', 'growing', [], ['skills'], { kind: 'window_opened', window: 'character' }),
  // Other people
  step('chat', 'other_people', ['chat'], ['controls'], { kind: 'chat_sent' }),
  step('trade', 'other_people', [], ['chat'], { kind: 'window_opened', window: 'trade' }),
  step('settlement', 'other_people', [], ['build_shelter'], { kind: 'window_opened', window: 'settlement' }),
  // Your first village (Phase 198): found, start a project, bring it something. Like every chapter it can be
  // dismissed; a player who never founds a village is never held by it.
  step('found_village', 'first_village', ['station'], ['settlement'], { kind: 'station_placed', type: 'hearth' }),
  step('start_project', 'first_village', [], ['found_village'], { kind: 'project_started' }),
  step('contribute_project', 'first_village', [], ['start_project'], { kind: 'project_contributed' }),
]

const titleKey = (id) => `tutorial.${id}.title`
const bodyKey = (id) => `tutorial.${id}.body`
const chapterKey = (chapter) => `tutorial.chapter.${chapter}`

/** Every catalog key the tutorial needs. */
function catalogKeys(data) {
  return [
    ...data.chapters.map(chapterKey),
    ...data.steps.flatMap((s) => [titleKey(s.id), bodyKey(s.id)]),
  ]
}

function tutorialData() {
  return {
    chapters: [...CHAPTERS],
    steps: JSON.parse(JSON.stringify(STEPS)),
    triggerKinds: JSON.parse(JSON.stringify(TRIGGER_KINDS)),
    inputActions: [...INPUT_ACTIONS],
    windows: [...WINDOWS],
  }
}

// Problems with a tutorial table. `refs` holds what triggers must point at:
//   { items: [ids], tags: { <tag>: [ids] }, stationTypes: [..], slots: [..], creatures: [ids],
//     technologies: [ids], catalog?: { <locale>: Set(keys) } }
// The closed sets (trigger kinds, input actions, windows) are the module's own unless `data` replaces them.
function tutorialProblems(data, refs) {
  const p = []
  const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
  if (!isObj(data) || !Array.isArray(data.steps) || !Array.isArray(data.chapters)) return ['tutorial must have chapters and steps lists']
  const kinds = data.triggerKinds || TRIGGER_KINDS
  const actions = data.inputActions || INPUT_ACTIONS
  const windows = data.windows || WINDOWS
  if (!data.steps.length) p.push('tutorial has no steps')
  if (new Set(data.chapters).size !== data.chapters.length) p.push('chapters must be unique')

  const seen = new Map()   // id -> index
  const chapterUsed = new Set()
  data.steps.forEach((s, i) => {
    const at = `step ${i} (${s && s.id})`
    if (!isObj(s)) { p.push(`step ${i} must be an object`); return }
    if (typeof s.id !== 'string' || !/^[a-z][a-z0-9_]*$/.test(s.id)) p.push(`${at}: id must be snake_case`)
    else if (seen.has(s.id)) p.push(`${at}: duplicate id "${s.id}"`)
    if (!data.chapters.includes(s.chapter)) p.push(`${at}: unknown chapter "${s.chapter}"`)
    else chapterUsed.add(s.chapter)
    for (const a of s.inputs || []) if (!actions.includes(a)) p.push(`${at}: unknown input action "${a}"`)
    if (!Array.isArray(s.inputs)) p.push(`${at}: inputs must be a list`)
    if (!Array.isArray(s.requires)) p.push(`${at}: requires must be a list`)
    for (const r of s.requires || []) {
      if (r === s.id) p.push(`${at}: requires itself`)
      else if (!seen.has(r)) p.push(`${at}: requires "${r}", which is not an earlier step`)
    }
    p.push(...triggerProblems(at, s.trigger, kinds, windows, refs))
    if (typeof s.id === 'string' && !seen.has(s.id)) seen.set(s.id, i)
  })
  for (const c of data.chapters) if (!chapterUsed.has(c)) p.push(`chapter "${c}" has no step`)
  // Steps of one chapter sit together, so the per-chapter progress reads in fabric order.
  const order = data.steps.map((s) => s && s.chapter)
  for (let i = 1; i < order.length; i++) {
    if (order[i] !== order[i - 1] && order.slice(0, i - 1).includes(order[i])) p.push(`chapter "${order[i]}" is split (step ${i})`)
  }

  if (refs.catalog) {
    for (const [loc, keys] of Object.entries(refs.catalog)) {
      for (const k of catalogKeys(data)) if (!keys.has(k)) p.push(`catalog ${loc} has no key ${k}`)
    }
  }
  return p
}

function triggerProblems(at, t, kinds, windows, refs) {
  const p = []
  if (!t || typeof t !== 'object') return [`${at}: trigger must be an object`]
  const spec = kinds[t.kind]
  if (!spec) return [`${at}: unknown trigger kind "${t.kind}"`]
  const required = spec.required || []
  const oneOf = spec.oneOf || []
  for (const k of required) if (!(k in t)) p.push(`${at}: ${t.kind} needs "${k}"`)
  const given = oneOf.filter((k) => k in t)
  if (oneOf.length && given.length !== 1) p.push(`${at}: ${t.kind} needs exactly one of ${oneOf.join(', ')}`)
  for (const k of Object.keys(t)) if (k !== 'kind' && !required.includes(k) && !oneOf.includes(k)) p.push(`${at}: ${t.kind} takes no "${k}"`)

  const posInt = (v) => Number.isInteger(v) && v >= 1
  if ('count' in t && !posInt(t.count)) p.push(`${at}: count must be an integer >= 1, got ${t.count}`)
  if ('metres' in t && !(typeof t.metres === 'number' && t.metres > 0)) p.push(`${at}: metres must be > 0, got ${t.metres}`)
  if ('item' in t && !refs.items.includes(t.item)) p.push(`${at}: item "${t.item}" does not exist`)
  if ('tag' in t && !((refs.tags[t.tag] || []).length)) p.push(`${at}: tag "${t.tag}" names nothing`)
  if ('type' in t && !refs.stationTypes.includes(t.type)) p.push(`${at}: station type "${t.type}" is not placeable`)
  if ('window' in t && !windows.includes(t.window)) p.push(`${at}: window "${t.window}" does not exist`)
  if ('slot' in t && !refs.slots.includes(t.slot)) p.push(`${at}: equipment slot "${t.slot}" does not exist`)
  if ('creature' in t && !refs.creatures.includes(t.creature)) p.push(`${at}: creature "${t.creature}" does not exist`)
  if ('technology' in t && !refs.technologies.includes(t.technology)) p.push(`${at}: technology "${t.technology}" does not exist`)
  return p
}

const def = (e, field) => e && e.fields && e.fields[field] ? e.fields[field].defaultValue : undefined

// What the shipped tutorial must point at, read from the fabric modules.
function tutorialRefs() {
  const items = require('./items')
  const recipes = require('./recipes')
  const settlement = require('./settlement')
  const waystone = require('./waystone')
  const bed = require('./bed')
  const technology = require('./technology')
  const materials = require('../world/materials')
  const creatures = require('../world/creatures')
  const allItems = { ...items, Hearth: settlement.Hearth }
  const keysTagged = (table, tag) => Object.entries(table).filter(([, e]) => e && (e.tags || []).includes(tag)).map(([k]) => k)
  const itemKeys = keysTagged(allItems, 'item')
  const tags = {
    item: itemKeys,
    material: keysTagged(materials, 'material'),
    creature: keysTagged(creatures, 'creature'),
  }
  for (const k of itemKeys) {
    const tool = def(allItems[k], 'toolType')
    if (typeof tool === 'string' && tool) (tags[tool] = tags[tool] || []).push(k)
  }
  // Placeable station types, as StationSlice.placeable_station_types derives them.
  const stationTypes = new Set()
  for (const r of Object.values({ ...recipes, RecipeHearth: settlement.RecipeHearth })) {
    const st = (def(r, 'recipe') || {}).station
    if (st) stationTypes.add(st)
  }
  for (const k of itemKeys) {
    const st = (def(allItems[k], 'repair') || {}).station
    if (st) stationTypes.add(st)
  }
  stationTypes.add(waystone.TRAVEL.stationType)
  stationTypes.add(settlement.RULES.hearthStation)
  stationTypes.add(bed.RULES.stationType)
  const slots = new Set()
  for (const k of itemKeys) {
    const slot = def(allItems[k], 'equipmentSlot')
    if (typeof slot === 'string' && slot) slots.add(slot)
  }
  return {
    items: [...itemKeys, ...tags.material],
    tags,
    stationTypes: [...stationTypes],
    slots: [...slots],
    creatures: tags.creature,
    technologies: keysTagged(technology, 'technology'),
  }
}

function validateTutorial(data, refs) {
  const problems = tutorialProblems(data, refs)
  if (problems.length) throw new Error('Tutorial data is invalid:\n  ' + problems.join('\n  '))
}

const Tutorial = defineEntity({
  tags: ['tutorial'],
  description:
    'The first-steps tutorial: an ordered list of small steps that teach a new player to move, gather, ' +
    'build the first stations and tools, make a shelter with a bed, hunt, stay alive, find their way, ' +
    'grow and meet other people. Each step names the keys it teaches and the event that completes it.',
  goal: 'One guided path for the first hour, so the tutorial is the one place that teaches',
  fields: {
    id: { type: 'uuid', primaryKey: true },
    chapters: { type: 'json', description: 'Chapter ids in order; label tutorial.chapter.<id>', defaultValue: CHAPTERS },
    steps: {
      type: 'json',
      description: 'Ordered steps: [{ id, chapter, inputs, requires, trigger: { kind, ...params } }]; text tutorial.<id>.title / .body',
      defaultValue: STEPS,
    },
    triggerKinds: { type: 'json', description: 'The closed set of completion events: { <kind>: { required?, oneOf? } }', defaultValue: TRIGGER_KINDS },
    inputActions: { type: 'json', description: 'Input action ids a step can name, in `?` controls-row order', defaultValue: INPUT_ACTIONS },
    windows: { type: 'json', description: 'UI window keys a window_opened trigger can name', defaultValue: WINDOWS },
  },
  behaviors: {
    progress: {
      description: 'Show the next step and complete it from a client event',
      rules: [
        'A step is eligible when every step it requires is done and it is neither done nor dismissed',
        'A done or dismissed step never comes back; the whole tutorial can be turned off',
        'The tutorial is client-side only and changes no game state',
      ],
      auth: { roles: ['maintainer'] },
    },
  },
})

module.exports = {
  Tutorial, CHAPTERS, TRIGGER_KINDS, INPUT_ACTIONS, WINDOWS, STEPS,
  titleKey, bodyKey, chapterKey, catalogKeys, tutorialData, tutorialProblems, tutorialRefs, validateTutorial,
}
