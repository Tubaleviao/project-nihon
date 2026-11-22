const { defineEntity } = require('@newel/core')
const work = require('./work')

// Phase 259 — work takes time. Every gathering action (dig, mine, chop) is timed work: a material has a base
// `workSeconds`; the action names the work of the equipment table (Phase 296: Equipment.workTraits) that suits it,
// and the held item's speed at that work is its speed; bare hands (and an item that cannot do the work) work at
// `bareHandsSpeed`. Seconds = workSeconds / speed.
// The host computes the duration from this table, never from a client message.
const BARE_HANDS_SPEED = 0.25 // about 4x the base time, so the first stone tool (Phase 260) is a real step

/** action -> { work, families } : which work (Equipment.workTraits) suits the action, and which material families it works. */
const ACTIONS = {
  dig:  { work: 'dig',  families: ['soil'] },
  mine: { work: 'mine', families: ['stone', 'metal'] },
  chop: { work: 'fell', families: ['wood'] },
}

/** Base seconds at speed 1.0, per material: soil and sand low, host rock higher, ores by tier, woods by tree. */
const WORK_SECONDS = {
  Grass: 0.6, Soil: 0.8, Sand: 0.6, Snow: 0.5,
  Ashite: 2.5, Lumenfite: 3.5,
  Ferrite: 3.0, Veilsteel: 5.0, Aethermite: 7.0, Voidite: 9.0,
  Concrete: 4.0, Steel: 6.0, Leyframe: 6.0,
  Thornwood: 4.0, Duskfiber: 5.0,
}

/**
 * Item speeds come from the equipment work table (Phase 296): an item's speed at an action is its speed at the
 * action's work. The numbers are Phase 259/260/290's: a forged pick and axe at 1.0, the veilsteel pick at 1.5, the
 * stone pick and axe at 0.6 (between bare hands at 0.25 and the forged tools), and the stone shovel at 1.2 since
 * Phase 290 (soil 0.67 s a block), the floor for every later digger (`workTimesProblems` rejects a slower one).
 */
/** Phase 290 — the shovel every other shovel must match or beat. */
const SHOVEL_FLOOR_TOOL = 'StoneShovel'


function workTimesData() {
  return JSON.parse(JSON.stringify({
    bareHandsSpeed: BARE_HANDS_SPEED, actions: ACTIONS, workSeconds: WORK_SECONDS,
  }))
}

function workTimesRefs() {
  const items = require('./items')
  const equipment = require('./equipment')
  const speeds = {}
  for (const [k, e] of Object.entries(items)) {
    const w = e && e.fields && e.fields.works && e.fields.works.defaultValue
    if (w && Object.keys(w).length) speeds[k] = w
  }
  const d = equipment.equipmentData()
  return { materials: Object.keys(work.FAMILIES), families: work.FAMILIES, itemWorks: speeds, works: d.workTraits }
}

/** Problems with the work-time tables, as strings. */
function workTimesProblems(d, refs) {
  const p = []
  if (!(d.bareHandsSpeed > 0 && d.bareHandsSpeed < 1)) p.push('bareHandsSpeed must be in (0, 1)')
  for (const [a, row] of Object.entries(d.actions || {})) {
    const rule = (refs.works || {})[row.work]
    if (!rule) p.push(`actions.${a}.work "${row.work}" is not a work of the equipment table`)
    else if (rule.bareHands !== true) p.push(`actions.${a}.work "${row.work}" cannot be done by bare hands, so an action without the right item would never end`)
  }
  const covered = new Set(Object.values(d.actions || {}).flatMap((r) => r.families || []))
  for (const m of refs.materials) {
    const s = (d.workSeconds || {})[m]
    if (!(typeof s === 'number' && s > 0)) p.push(`workSeconds.${m} is missing: every material needs a work time > 0`)
    if (!covered.has(refs.families[m])) p.push(`${m}: no action works the ${refs.families[m]} family`)
  }
  for (const m of Object.keys(d.workSeconds || {})) if (!refs.materials.includes(m)) p.push(`workSeconds.${m} is not a material`)
  const actionWorks = new Set(Object.values(d.actions || {}).map((r) => r.work))
  for (const [item, works] of Object.entries(refs.itemWorks || {})) {
    for (const [w, v] of Object.entries(works)) {
      if (actionWorks.has(w) && !(v > d.bareHandsSpeed)) p.push(`${item} does ${w} at ${v}: it must beat bare hands (${d.bareHandsSpeed})`)
    }
  }
  // Phase 290 — nothing digs slower than the stone shovel: its speed is the floor of digging.
  const floor = ((refs.itemWorks || {})[SHOVEL_FLOOR_TOOL] || {}).dig
  if (!(typeof floor === 'number')) p.push(`${SHOVEL_FLOOR_TOOL} cannot dig: it is the floor of digging (Phase 290)`)
  else {
    for (const [item, works] of Object.entries(refs.itemWorks || {})) {
      if (item !== SHOVEL_FLOOR_TOOL && typeof works.dig === 'number' && works.dig < floor) {
        p.push(`${item} digs at ${works.dig}, slower than ${SHOVEL_FLOOR_TOOL} (${floor}): a later shovel must dig at least as fast`)
      }
    }
  }
  return p
}

function validateWorkTimes(d, refs) {
  const problems = workTimesProblems(d, refs)
  if (problems.length) throw new Error('Work times are invalid:\n  ' + problems.join('\n  '))
}

const WorkTimes = defineEntity({
  tags: ['world-system'],
  description:
    'How long gathering takes: a base time per material, the work each action wants (the held item\'s speed at it comes ' +
    'from Equipment.workTraits), and the slow factor of bare hands (also the speed of an item that cannot do the work).',
  goal: 'Make better equipment a felt step: timed, held work instead of one-click gathering (Phase 259)',
  fields: {
    id:             { type: 'uuid', primaryKey: true },
    bareHandsSpeed: { type: 'decimal', description: 'Speed multiplier of bare hands and of an item that cannot do the work (1.0 = the baseline item)', defaultValue: BARE_HANDS_SPEED },
    actions:        { type: 'json', description: '{ <dig|mine|chop>: { work, families } }', defaultValue: ACTIONS },
    workSeconds:    { type: 'json', description: '{ <material>: base seconds at speed 1.0 }', defaultValue: WORK_SECONDS },
  },
})

module.exports = { BARE_HANDS_SPEED, SHOVEL_FLOOR_TOOL, ACTIONS, WORK_SECONDS, workTimesData, workTimesRefs, workTimesProblems, validateWorkTimes, WorkTimes }
