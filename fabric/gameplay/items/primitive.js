const { defineEntity, RARITIES, DURABILITY_STATES, itemStateMachine, repairData, itemShape } = require('./shared')

// Phase 260 — stone tools. A newcomer with nothing picks up branches and loose stones and lashes them into
// an axe, a pick, a shovel, a knife and a hammer by hand: no station, no research points, no starting kit.
// They are slower than the forged tools and wear out fast; the forge is the next step, not the first one.
// The hammer is what a builder holds to place blocks (Structure `buildTool`); stations need none.

const TOOL_TYPE_DESC = 'Tool class — the action this tool performs. "pick" mines, "axe" chops, "shovel" digs, "hammer" builds.'

function stoneTool({ archetype, parts, toolType, weight, durability, description, goal, extra = {} }) {
  return defineEntity({
    tags: ['item'],
    description,
    goal,
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg; affects carry capacity', defaultValue: weight },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'common' },
      stackable: { type: 'boolean', description: 'Whether multiple instances stack in inventory', defaultValue: false },
      shape: itemShape({ archetype, parts }),
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades', defaultValue: durability },
      ...(toolType ? { toolType: { type: 'string', description: TOOL_TYPE_DESC, defaultValue: toolType } } : {}),
      ...extra,
      repair: repairData({
        station: '',
        materials: [{ item: 'LooseStone', quantity: 1 }],
        skillGuards: [{ skill: 'Carpentry', tier: 'novice' }],
      }),
    },
    relations: {
      ashite:    { name: 'ashite',    kind: 'hasOne', target: 'Ashite' },
      thornwood: { name: 'thornwood', kind: 'hasOne', target: 'Thornwood' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Reduce durability with each use; a stone head chips quickly',
        rules: ['Each use consumes one durability point'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Knap a fresh edge onto the head with a loose stone, anywhere',
        rules: ['Needs no station', 'Repair costs one loose stone per condition tier restored'],
        auth: { roles: ['maintainer'] },
      },
    },
  })
}

module.exports = {

  // ─── Branch ───────────────────────────────────────────────────────────────
  Branch: defineEntity({
    tags: ['item'],
    description: 'A straight stick picked off the ground or trimmed from a felled tree. The handle of every stone tool.',
    goal: 'A first-hour input that needs no tool: the haft of the stone tools (Phase 260)',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      weight:    { type: 'decimal', description: 'kg per branch', defaultValue: 0.3 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'common' },
      stackable: { type: 'boolean', description: 'True; branches stack', defaultValue: true },
      shape: itemShape({ archetype: 'stick', parts: { body: 'Thornwood' } }),
    },
    relations: {
      thornwood: { name: 'thornwood', kind: 'hasOne', target: 'Thornwood' },
    },
  }),

  // ─── LooseStone ───────────────────────────────────────────────────────────
  LooseStone: defineEntity({
    tags: ['item'],
    description: 'A fist-sized stone picked off the ground or knocked loose from host rock. The head of every stone tool.',
    goal: 'A first-hour input that needs no tool: the head of the stone tools (Phase 260)',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      weight:    { type: 'decimal', description: 'kg per stone', defaultValue: 0.5 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'common' },
      stackable: { type: 'boolean', description: 'True; stones stack', defaultValue: true },
      shape: itemShape({ archetype: 'pebble', parts: { body: 'Ashite' } }),
    },
    relations: {
      ashite: { name: 'ashite', kind: 'hasOne', target: 'Ashite' },
    },
  }),

  // ─── StoneAxe ─────────────────────────────────────────────────────────────
  StoneAxe: stoneTool({
    archetype: 'axe', parts: { head: 'Ashite', handle: 'Thornwood' }, toolType: 'axe', weight: 1.4, durability: 30,
    description: 'A knapped stone lashed into a split branch. Fells a tree, slowly.',
    goal: 'The first axe, made by hand from a branch and a stone (Phase 260)',
  }),

  // ─── StonePick ────────────────────────────────────────────────────────────
  StonePick: stoneTool({
    archetype: 'pick', parts: { head: 'Ashite', handle: 'Thornwood' }, toolType: 'pick', weight: 1.6, durability: 30,
    description: 'A pointed stone bound across a branch. Breaks rock faster than bare hands; ore wears it fast.',
    goal: 'The first pick, made by hand from a branch and two stones (Phase 260)',
  }),

  // ─── StoneShovel ──────────────────────────────────────────────────────────
  StoneShovel: stoneTool({
    archetype: 'shovel', parts: { head: 'Ashite', handle: 'Thornwood' }, toolType: 'shovel', weight: 1.5, durability: 40,
    description: 'A flat stone tied to a long branch. Digs soil, sand and gravel faster than any pick.',
    goal: 'The shovel tool class: the fastest way through soft ground (Phase 260)',
  }),

  // ─── StoneHammer ──────────────────────────────────────────────────────────
  StoneHammer: stoneTool({
    archetype: 'hammer', parts: { head: 'Ashite', handle: 'Thornwood' }, toolType: 'hammer', weight: 1.2, durability: 40,
    description: 'A heavy round stone bound to a short branch. Held to build walls, floors and roofs; benches need none.',
    goal: 'The building tool: a shelter needs a hammer in hand, a bench does not (Phase 260)',
  }),

  // ─── StoneKnife ───────────────────────────────────────────────────────────
  StoneKnife: stoneTool({
    archetype: 'knife', parts: { blade: 'Ashite', grip: 'Thornwood' }, toolType: '', weight: 0.3, durability: 25,
    description: 'A sharp flake of stone in a branch grip. Skins and butchers, poorly.',
    goal: 'A first knife for harvesting a kill before the forge (Phase 260)',
    extra: {
      harvestTool: { type: 'string', description: 'Harvest tool category this item provides (Phase 160): knife or bonetool', defaultValue: 'knife' },
      efficiency:  { type: 'decimal', description: 'How well it works that category, in (0, 1]; below 1.0 is a poor substitute', defaultValue: 0.5 },
    },
  }),
}
