const { defineEntity } = require('@newel/core')
const work = require('./work')

// Phase 259 — work takes time. Every gathering action (dig, mine, chop) is timed work: a material has a base
// `workSeconds`; the action names the tool class that suits it; a tool has a `workSpeed` per class it serves;
// bare hands (and a tool of the wrong class) work at `bareHandsSpeed`. Seconds = workSeconds / speed.
// The host computes the duration from this table, never from a client message.
const BARE_HANDS_SPEED = 0.25 // about 4x the base time, so the first stone tool (Phase 260) is a real step

/** action -> { toolClass, families } : which tool class suits the action, and which material families it works. */
const ACTIONS = {
  dig:  { toolClass: 'shovel', families: ['soil'] },
  mine: { toolClass: 'pick',   families: ['stone', 'metal'] },
  chop: { toolClass: 'axe',    families: ['wood'] },
}

/** Base seconds at speed 1.0, per material: soil and sand low, host rock higher, ores by tier, woods by tree. */
const WORK_SECONDS = {
  Grass: 0.6, Soil: 0.8, Sand: 0.6, Snow: 0.5,
  Ashite: 2.5, Lumenfite: 3.5,
  Ferrite: 3.0, Veilsteel: 5.0, Aethermite: 7.0, Voidite: 9.0,
  Concrete: 4.0, Steel: 6.0, Leyframe: 6.0,
  Thornwood: 4.0, Duskfiber: 5.0,
}

/** tool item -> { <class>: speed }. Speed 1.0 is the base time. Only tools that work a class appear. */
const TOOL_SPEEDS = {
  FerritePick:   { pick: 1.0 },
  VeilsteelPick: { pick: 1.5 },
  CarpenterAxe:  { axe: 1.0 },
}

const WORK_CLASSES = ['pick', 'axe', 'shovel']

function workTimesData() {
  return JSON.parse(JSON.stringify({
    bareHandsSpeed: BARE_HANDS_SPEED, actions: ACTIONS, workSeconds: WORK_SECONDS, toolSpeeds: TOOL_SPEEDS,
  }))
}

function workTimesRefs() {
  const items = require('./items')
  const tools = {}
  for (const [k, e] of Object.entries(items)) {
    const t = e && e.fields && e.fields.toolType && e.fields.toolType.defaultValue
    if (t) tools[k] = t
  }
  return { materials: Object.keys(work.FAMILIES), families: work.FAMILIES, toolTypes: tools }
}

/** Problems with the work-time tables, as strings. */
function workTimesProblems(d, refs) {
  const p = []
  if (!(d.bareHandsSpeed > 0 && d.bareHandsSpeed < 1)) p.push('bareHandsSpeed must be in (0, 1)')
  const classes = new Set()
  for (const [a, row] of Object.entries(d.actions || {})) {
    if (!WORK_CLASSES.includes(row.toolClass)) p.push(`actions.${a}.toolClass "${row.toolClass}" is not a tool class`)
    else classes.add(row.toolClass)
  }
  const covered = new Set(Object.values(d.actions || {}).flatMap((r) => r.families || []))
  for (const m of refs.materials) {
    const s = (d.workSeconds || {})[m]
    if (!(typeof s === 'number' && s > 0)) p.push(`workSeconds.${m} is missing: every material needs a work time > 0`)
    if (!covered.has(refs.families[m])) p.push(`${m}: no action works the ${refs.families[m]} family`)
  }
  for (const m of Object.keys(d.workSeconds || {})) if (!refs.materials.includes(m)) p.push(`workSeconds.${m} is not a material`)
  for (const [item, cls] of Object.entries(refs.toolTypes)) {
    if (!WORK_CLASSES.includes(cls)) continue
    const sp = (d.toolSpeeds || {})[item]
    if (!sp || !(sp[cls] > 0)) p.push(`${item}: tool of class ${cls} has no workSpeed for it`)
  }
  for (const [item, row] of Object.entries(d.toolSpeeds || {})) {
    if (!(item in refs.toolTypes)) p.push(`toolSpeeds.${item} is not a tool item`)
    for (const [cls, v] of Object.entries(row)) {
      if (!WORK_CLASSES.includes(cls)) p.push(`toolSpeeds.${item}.${cls} is not a tool class`)
      else if (!(v > d.bareHandsSpeed)) p.push(`toolSpeeds.${item}.${cls} (${v}) must beat bare hands (${d.bareHandsSpeed})`)
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
    'How long gathering takes: a base time per material, the tool class each action wants, a speed per tool ' +
    'and class, and the slow factor of bare hands (also the speed of a tool of the wrong class).',
  goal: 'Make a better tool a felt step: timed, held work instead of one-click gathering (Phase 259)',
  fields: {
    id:             { type: 'uuid', primaryKey: true },
    bareHandsSpeed: { type: 'decimal', description: 'Speed multiplier of bare hands and of a wrong-class tool (1.0 = a right tool at base speed)', defaultValue: BARE_HANDS_SPEED },
    actions:        { type: 'json', description: '{ <dig|mine|chop>: { toolClass, families } }', defaultValue: ACTIONS },
    workSeconds:    { type: 'json', description: '{ <material>: base seconds at speed 1.0 }', defaultValue: WORK_SECONDS },
    toolSpeeds:     { type: 'json', description: '{ <tool item>: { <class>: speed } }', defaultValue: TOOL_SPEEDS },
  },
})

module.exports = { BARE_HANDS_SPEED, ACTIONS, WORK_SECONDS, TOOL_SPEEDS, workTimesData, workTimesRefs, workTimesProblems, validateWorkTimes, WorkTimes }
