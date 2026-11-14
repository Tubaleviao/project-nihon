const { defineEntity } = require('@newel/core')

// Phase 260 — stone tools: a newcomer makes an axe, a pick, a shovel, a knife and a hammer on the spot from
// branches and loose stones. Only they need no bench: every other tool is crafted and repaired at a station. This table names the tools, their inputs, and where the inputs come from in the world
// so they never run out where there is rock and wood: a felled tree drops branches beside its wood, and
// mining natural host rock knocks a loose stone loose at `looseStoneChance` (decided by the mined span's
// position, so the host and a replay agree).

const TOOLS = ['StoneAxe', 'StonePick', 'StoneShovel', 'StoneKnife', 'StoneHammer']
const INPUTS = ['Branch', 'LooseStone']

const YIELDS = {
  fellBranches: 2,        // branches a felled tree drops into the feller's pack beside its wood
  looseStoneChance: 0.25, // chance a mined span of natural host rock also yields one loose stone
}

function stoneToolsData() {
  return JSON.parse(JSON.stringify({ tools: TOOLS, inputs: INPUTS, yields: YIELDS }))
}

/** The fabric's recipes and technologies, in the plain shape the validator reads. */
function stoneToolsRefs() {
  const items = require('./items')
  const recipes = require('./recipes')
  const technology = require('./technology')
  const recipeRows = {}
  for (const [k, e] of Object.entries(recipes)) {
    const r = e && e.fields && e.fields.recipe && e.fields.recipe.defaultValue
    if (r) recipeRows[k] = r
  }
  const techRows = {}
  for (const [k, e] of Object.entries(technology)) {
    const t = e && e.fields && e.fields.tech && e.fields.tech.defaultValue
    if (t) techRows[k] = { ...t, researchCost: e.fields.researchCost.defaultValue }
  }
  // Every tool (an item with a tool class or a harvest tool) and its repair station, for the bench rule.
  const toolItems = {}
  for (const [k, e] of Object.entries(items)) {
    const f = (e && e.fields) || {}
    if (!f.toolType && !f.harvestTool) continue
    toolItems[k] = { repairStation: f.repair ? f.repair.defaultValue.station : null }
  }
  const structure = require('./structure').Structure
  const toolTypes = {}
  for (const [k, e] of Object.entries(items)) {
    const t = e && e.fields && e.fields.toolType && e.fields.toolType.defaultValue
    if (t) toolTypes[k] = t
  }
  return { items: Object.keys(items), recipes: recipeRows, technologies: techRows, tools: toolItems, toolTypes,
    buildTool: structure.fields.buildTool.defaultValue }
}

/** Problems with the stone-tool table against the fabric, as strings. */
function stoneToolsProblems(d, refs) {
  const p = []
  for (const i of d.inputs || []) if (!refs.items.includes(i)) p.push(`input ${i} is not an item`)
  const y = d.yields || {}
  if (!(Number.isInteger(y.fellBranches) && y.fellBranches >= 1)) p.push('yields.fellBranches must be an integer >= 1')
  if (!(typeof y.looseStoneChance === 'number' && y.looseStoneChance > 0 && y.looseStoneChance <= 1)) p.push('yields.looseStoneChance must be in (0, 1]')
  for (const tool of d.tools || []) {
    if (!refs.items.includes(tool)) { p.push(`${tool} is not an item`); continue }
    const found = Object.entries(refs.recipes).filter(([, r]) => (r.outputs || []).some((o) => o.item === tool))
    if (!found.length) { p.push(`${tool}: no recipe makes it`); continue }
    for (const [rk, r] of found) {
      if (r.station) p.push(`${rk}: a stone tool needs no station, got "${r.station}"`)
      for (const inp of r.inputs || []) if (!(d.inputs || []).includes(inp.item)) p.push(`${rk}: input ${inp.item} is not a branch or a loose stone`)
      for (const g of r.skillGuards || []) if (g.tier !== 'novice') p.push(`${rk}: skill guard ${g.skill} must be novice, got ${g.tier}`)
      const techs = Object.entries(refs.technologies).filter(([, t]) => (t.unlocks || []).includes(rk))
      if (!techs.length) p.push(`${rk}: no technology unlocks it`)
      for (const [tk, t] of techs) {
        if (t.researchCost !== 0) p.push(`${tk}: the technology of a stone tool costs no research points, got ${t.researchCost}`)
        if ((t.requires || []).length) p.push(`${tk}: the technology of a stone tool has no prerequisite`)
        if ((t.researchMaterials || []).length) p.push(`${tk}: the technology of a stone tool takes no materials`)
        if (t.discovery !== true) p.push(`${tk}: the technology of a stone tool is a discovery (found by holding its inputs)`)
      }
    }
  }
  // Only stone tools skip the bench: every other tool is crafted and repaired at a station.
  for (const [tool, row] of Object.entries(refs.tools || {})) {
    if ((d.tools || []).includes(tool)) continue
    for (const [rk, r] of Object.entries(refs.recipes)) {
      if ((r.outputs || []).some((o) => o.item === tool) && !r.station) p.push(`${rk}: ${tool} is not a stone tool, so it is crafted at a station`)
    }
    if (row.repairStation === '') p.push(`${tool}: not a stone tool, so it is repaired at a station`)
  }
  // The build tool is one a newcomer can make: some stone tool has its class.
  if (!refs.buildTool) p.push('Structure.buildTool is missing')
  else if (!(d.tools || []).some((t) => refs.toolTypes[t] === refs.buildTool)) p.push(`no stone tool is a ${refs.buildTool}, the class a builder holds`)
  return p
}

function validateStoneTools(d, refs) {
  const problems = stoneToolsProblems(d, refs)
  if (problems.length) throw new Error('Stone tools are invalid:\n  ' + problems.join('\n  '))
}

const StoneTools = defineEntity({
  tags: ['world-system'],
  description:
    'The stone tools a newcomer makes by hand (the only tools made or repaired without a bench), the two inputs they take, and where those inputs come from: ' +
    'branches from a felled tree, loose stones knocked from host rock.',
  goal: 'A first tool with nothing in the pack: no station, no research, inputs that never run out (Phase 260)',
  fields: {
    id:     { type: 'uuid', primaryKey: true },
    tools:  { type: 'json', description: 'Item keys of the stone tools', defaultValue: TOOLS },
    inputs: { type: 'json', description: 'The only items a stone tool recipe takes', defaultValue: INPUTS },
    yields: { type: 'json', description: '{ fellBranches, looseStoneChance }', defaultValue: YIELDS },
  },
})

module.exports = { TOOLS, INPUTS, YIELDS, stoneToolsData, stoneToolsRefs, stoneToolsProblems, validateStoneTools, StoneTools }
