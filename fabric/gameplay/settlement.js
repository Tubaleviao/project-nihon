const { defineEntity, recipeData } = require('./recipes/shared')
const { RARITIES, DURABILITY_STATES, itemStateMachine, itemShape } = require('./items/shared')

// Phase 139 — settlements. A player founds a settlement by placing a `Hearth`; members share a
// `Stockpile`. The runtime (Phase 140) reads this table from GameData.WORLD_SYSTEMS["Settlement"].
// Phase 203 — settlements are being replaced by clans (`fabric/gameplay/clan.js`): the claim fields
// (`tiers.claimRadius`, `decayRadiusPerDay`, `minSeparation`) are gone, and Phase 204 migrates every saved
// settlement to a clan with the same name, members and roles (Clan.migration). The hearth fields stay until
// that migration, which returns each hearth to its founder as a `Hearth` item.
//
// `tiers`: settlement tier -> { minMembers, minDays }. A tier is reached when the member count meets
//   minMembers and the age in days meets minDays. Thresholds never shrink with tier. Phase 207 — completed
//   projects no longer count toward a tier (`minProjects` fails): a project changes nothing but itself.
// `roles`: member role -> permissions (`build`, `take`, `invite`, `withdrawLimit` items per day; the
//   founder is never limited, and a role without `take` withdraws nothing).
// `stockpile`: shared container capacity (stacks) by tier.
// `abandonAfterDays`: days with no member activity before `town`/`growing` becomes `abandoned`.
const RULES = {
  hearthStation: 'hearth',
  hearthItem: 'Hearth',
  guildMaxSettlements: 1,
  tiers: {
    founded: { minMembers: 1, minDays: 0 },
    growing: { minMembers: 3, minDays: 3 },
    town:    { minMembers: 8, minDays: 14 },
  },
  roles: {
    founder: { build: true, take: true, invite: true, withdrawLimit: 0 },
    elder:   { build: true, take: true, invite: true, withdrawLimit: 200 },
    member:  { build: true, take: true, invite: false, withdrawLimit: 50 },
    guest:   { build: false, take: false, invite: false, withdrawLimit: 0 },
  },
  stockpile: {
    founded: { capacityStacks: 20 },
    growing: { capacityStacks: 60 },
    town:    { capacityStacks: 160 },
  },
  abandonAfterDays: 30,
}

const TIERS = ['founded', 'growing', 'town']
const KNOWN = ['hearthStation', 'hearthItem', 'guildMaxSettlements', 'tiers', 'roles', 'stockpile', 'abandonAfterDays']
// Phase 203 — the claim is gone: a settlement table that still names one fails.
const CLAIM_FIELDS = ['claimRadius', 'decayRadiusPerDay', 'minSeparation']

const isNum = (v) => typeof v === 'number' && Number.isFinite(v)

/** Problems with a settlement rule table, as strings. `itemKeys` (optional) lists valid item keys. */
function settlementProblems(rules, itemKeys) {
  const problems = []
  if (typeof rules.hearthStation !== 'string' || rules.hearthStation === '') problems.push('Settlement.hearthStation must be a non-empty string')
  if (typeof rules.hearthItem !== 'string' || rules.hearthItem === '') problems.push('Settlement.hearthItem must be a non-empty string')
  else if (itemKeys && !itemKeys.includes(rules.hearthItem)) problems.push(`Settlement.hearthItem "${rules.hearthItem}" is not a defined item`)
  if (!Number.isInteger(rules.guildMaxSettlements) || rules.guildMaxSettlements < 1) problems.push('Settlement.guildMaxSettlements must be an integer >= 1')
  if (!isNum(rules.abandonAfterDays) || rules.abandonAfterDays <= 0) problems.push('Settlement.abandonAfterDays must be a positive number')

  const tiers = rules.tiers || {}
  let prev = null
  for (const name of TIERS) {
    const t = tiers[name]
    if (!t) { problems.push(`Settlement.tiers.${name} is missing`); prev = null; continue }
    for (const f of CLAIM_FIELDS) if (f in t) problems.push(`Settlement.tiers.${name}.${f}: settlements have no claim (Phase 203)`)
    if (!Number.isInteger(t.minMembers) || t.minMembers < 1) problems.push(`Settlement.tiers.${name}.minMembers must be an integer >= 1`)
    if (!isNum(t.minDays) || t.minDays < 0) problems.push(`Settlement.tiers.${name}.minDays must be >= 0`)
    if ('minProjects' in t) problems.push(`Settlement.tiers.${name}.minProjects: completed projects count toward no tier (Phase 207)`)
    if (prev) {
      if (t.minMembers < prev.minMembers) problems.push(`Settlement.tiers.${name}.minMembers ${t.minMembers} is below the previous tier's ${prev.minMembers} (thresholds out of order)`)
      if (t.minDays < prev.minDays) problems.push(`Settlement.tiers.${name}.minDays ${t.minDays} is below the previous tier's ${prev.minDays} (thresholds out of order)`)
    }
    prev = t
  }
  for (const name of Object.keys(tiers)) if (!TIERS.includes(name)) problems.push(`Settlement.tiers has unknown tier "${name}"`)

  const stock = rules.stockpile || {}
  let prevCap = 0
  for (const name of TIERS) {
    const s = stock[name]
    if (!s || !Number.isInteger(s.capacityStacks) || s.capacityStacks <= 0) { problems.push(`Settlement.stockpile.${name}.capacityStacks must be a positive integer`); continue }
    if (s.capacityStacks < prevCap) problems.push(`Settlement.stockpile.${name}.capacityStacks ${s.capacityStacks} shrinks below the previous tier's ${prevCap}`)
    prevCap = s.capacityStacks
  }

  const roles = rules.roles || {}
  if (!roles.founder) problems.push('Settlement.roles.founder is missing')
  for (const [name, r] of Object.entries(roles)) {
    for (const k of ['build', 'take', 'invite']) if (typeof r[k] !== 'boolean') problems.push(`Settlement.roles.${name}.${k} must be a boolean`)
    if (!Number.isInteger(r.withdrawLimit) || r.withdrawLimit < 0) problems.push(`Settlement.roles.${name}.withdrawLimit must be an integer >= 0`)
  }

  for (const key of Object.keys(rules)) {
    if (CLAIM_FIELDS.includes(key)) problems.push(`Settlement.${key}: settlements have no claim (Phase 203)`)
    else if (!KNOWN.includes(key)) problems.push(`Settlement has unknown field "${key}"`)
  }
  return problems
}

function validateSettlement(rules, itemKeys) {
  const problems = settlementProblems(rules, itemKeys)
  if (problems.length) throw new Error('Settlement rule is invalid:\n  ' + problems.join('\n  '))
}

// ─── Phase 197 — the settlement loop: projects and specialties ──────────────────────────────────────
// Two rule tables, one world system each, read from GameData.WORLD_SYSTEMS ("SettlementProjects",
// "SettlementSpecialties"). Phase 203 removed raids and upkeep (raids are deferred, upkeep is dropped),
// project labour and project effects: a project is complete once its materials are in, and nothing a
// member does is progress for the village beyond the project itself (WorkSkills). A table that still
// names a removed field fails.
//
// PROJECTS — structures a village builds together.
//   `projects`: key -> {
//     minTier    the lowest settlement tier that may start it
//     materials  [{ item, quantity }] existing item keys, taken from the stockpile or a member as given
//     places     { block, blocks, layout, stations } what is placed when it completes: `blocks` of
//                `block` (an item or material key) in the `layout` shape, plus `stations`
//   }
// SPECIALTIES — what each member is good at. A specialty's score is the sum of weight × skill tier rank
//   (novice 0 .. master 4) over `skills` plus weight × attribute points above the base over `attributes`.
//   A member's specialty is their best score at or above `floor` (ties go to the earlier row); a member
//   below the floor has none.
const LAYOUTS = ['ring', 'tower', 'hall', 'shed']
const REMOVED_PROJECT_FIELDS = ['labour', 'effects', 'steps', 'work']
const REMOVED_TABLE_FIELDS = { projects: ['workSecondsPerUnit'], specialties: ['bonusLabour'] }

const PROJECTS = {
  projects: {
    palisade: {
      minTier: 'founded',
      materials: [{ item: 'ThornwoodPlank', quantity: 40 }, { item: 'FerriteIngot', quantity: 4 }],
      places: { block: 'ThornwoodPlank', blocks: 48, layout: 'ring', stations: [] },
    },
    storehouse: {
      minTier: 'founded',
      materials: [{ item: 'ThornwoodPlank', quantity: 30 }, { item: 'AshiteBlock', quantity: 12 }],
      places: { block: 'AshiteBlock', blocks: 24, layout: 'shed', stations: [] },
    },
    workshop: {
      minTier: 'founded',
      materials: [{ item: 'ThornwoodPlank', quantity: 20 }, { item: 'FerriteIngot', quantity: 10 }, { item: 'AshiteBlock', quantity: 10 }],
      places: { block: 'AshiteBlock', blocks: 32, layout: 'hall', stations: ['carpentry bench', 'forge'] },
    },
    watchtower: {
      minTier: 'growing',
      materials: [{ item: 'ThornwoodPlank', quantity: 24 }, { item: 'AshiteBlock', quantity: 16 }, { item: 'FerriteIngot', quantity: 6 }],
      places: { block: 'AshiteBlock', blocks: 40, layout: 'tower', stations: [] },
    },
  },
}

const SPECIALTIES = {
  floor: 2,
  specialties: {
    woodworker: { skills: { Carpentry: 1 }, attributes: { strength: 0.25 } },
    smith:      { skills: { Smithing: 1, ArcaneForging: 0.5 }, attributes: { strength: 0.25 } },
    hunter:     { skills: { Archery: 0.5, Swordsmanship: 0.5, Skinning: 0.5, Tracking: 0.5 }, attributes: { agility: 0.25 } },
    builder:    { skills: { Carpentry: 0.5, Leadership: 0.5 }, attributes: { vitality: 0.25, strength: 0.25 } },
    forager:    { skills: { Tracking: 0.5, Navigation: 0.5, Alchemy: 0.5 }, attributes: { perception: 0.25 } },
  },
}

const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)

/** The loop tables plus the tier table they refer to, as plain data. */
function settlementLoopData() {
  return JSON.parse(JSON.stringify({ tiers: RULES.tiers, projects: PROJECTS, specialties: SPECIALTIES }))
}

/** What the loop tables may name, read from the fabric modules (required lazily: they require this file). */
function settlementLoopRefs() {
  const items = require('./items')
  const skills = require('./skills')
  const attributes = require('./attributes')
  const materials = require('../world/materials')
  const biomes = require('../world/biomes')
  const creatures = require('../world/creatures')
  const tutorial = require('./tutorial')
  const tagged = (table, tag) => Object.entries(table).filter(([, e]) => e && (e.tags || []).includes(tag)).map(([k]) => k)
  const creatureBiome = {}
  for (const k of tagged(creatures, 'creature')) creatureBiome[k] = creatures[k].fields.biome.defaultValue
  return {
    items: [...tagged(items, 'item'), 'Hearth'],
    materials: tagged(materials, 'material'),
    skills: tagged(skills, 'skill'),
    attributes: [...attributes.ATTRIBUTES],
    biomes: Object.keys(biomes),
    creatureBiome,
    stationTypes: tutorial.tutorialRefs().stationTypes,
  }
}

function costProblems(at, list, items) {
  const p = []
  if (!Array.isArray(list) || list.length === 0) return [`${at} must list at least one { item, quantity }`]
  for (const [i, m] of list.entries()) {
    if (!isObj(m) || !items.includes(m.item)) p.push(`${at}[${i}]: item "${m && m.item}" is not a defined item`)
    if (!isObj(m) || !Number.isInteger(m.quantity) || m.quantity < 1) p.push(`${at}[${i}]: quantity must be an integer >= 1`)
  }
  return p
}

/** Problems with the settlement loop tables, as strings. */
function settlementLoopProblems(data, refs) {
  const p = []
  const tierNames = Object.keys(data.tiers || {})
  const specialtyNames = Object.keys((data.specialties || {}).specialties || {})

  // Projects
  const pr = data.projects || {}
  for (const [table, fields] of Object.entries(REMOVED_TABLE_FIELDS)) {
    for (const f of fields) if (f in (data[table] || {})) p.push(`Settlement${table[0].toUpperCase()}${table.slice(1)}.${f}: projects have no labour (Phase 203)`)
  }
  for (const k of ['raids', 'upkeep']) if (k in data) p.push(`Settlement loop has "${k}": raids and upkeep were removed (Phase 203)`)
  if (!isObj(pr.projects) || Object.keys(pr.projects).length === 0) p.push('SettlementProjects.projects must name at least one project')
  for (const [key, proj] of Object.entries(pr.projects || {})) {
    const at = `SettlementProjects.${key}`
    if (!tierNames.includes(proj.minTier)) p.push(`${at}.minTier "${proj.minTier}" is not a settlement tier`)
    p.push(...costProblems(`${at}.materials`, proj.materials, refs.items))
    for (const f of REMOVED_PROJECT_FIELDS) if (f in proj) p.push(`${at}.${f}: a project is complete once its materials are in (Phase 203)`)
    const pl = proj.places
    if (!isObj(pl)) { p.push(`${at}.places must be an object`); continue }
    if (![...refs.items, ...refs.materials].includes(pl.block)) p.push(`${at}.places.block "${pl.block}" is not an item or material`)
    if (!Number.isInteger(pl.blocks) || pl.blocks < 1) p.push(`${at}.places.blocks must be an integer >= 1`)
    if (!LAYOUTS.includes(pl.layout)) p.push(`${at}.places.layout must be one of ${LAYOUTS.join(', ')}`)
    if (!Array.isArray(pl.stations)) p.push(`${at}.places.stations must be a list`)
    else for (const st of pl.stations) if (!refs.stationTypes.includes(st)) p.push(`${at}.places.stations: "${st}" is not a placeable station type`)
  }

  // Specialties
  const sp = data.specialties || {}
  if (!isNum(sp.floor) || sp.floor <= 0) p.push('SettlementSpecialties.floor must be > 0')
  if (specialtyNames.length === 0) p.push('SettlementSpecialties.specialties must name at least one specialty')
  for (const [key, s] of Object.entries(sp.specialties || {})) {
    const at = `SettlementSpecialties.${key}`
    const sk = isObj(s.skills) ? s.skills : {}
    const at2 = isObj(s.attributes) ? s.attributes : {}
    if (Object.keys(sk).length + Object.keys(at2).length === 0) p.push(`${at} must score at least one skill or attribute`)
    for (const [id, w] of Object.entries(sk)) {
      if (!refs.skills.includes(id)) p.push(`${at}: unknown skill "${id}"`)
      if (!isNum(w) || w <= 0) p.push(`${at}.skills.${id} weight must be > 0`)
    }
    for (const [id, w] of Object.entries(at2)) {
      if (!refs.attributes.includes(id)) p.push(`${at}: unknown attribute "${id}"`)
      if (!isNum(w) || w <= 0) p.push(`${at}.attributes.${id} weight must be > 0`)
    }
  }
  return p
}

function validateSettlementLoop(data, refs) {
  const problems = settlementLoopProblems(data, refs)
  if (problems.length) throw new Error('Settlement loop data is invalid:\n  ' + problems.join('\n  '))
}

const loopEntity = (description, goal, rulesDescription, rules, behaviors) => defineEntity({
  tags: ['world-system'],
  description,
  goal,
  fields: {
    id: { type: 'uuid', primaryKey: true },
    rules: { type: 'json', description: rulesDescription + ' (validated at fabric load)', defaultValue: rules },
  },
  relations: {
    settlement: { name: 'settlement', kind: 'hasOne', target: 'Settlement' },
  },
  behaviors,
})

const SettlementProjects = loopEntity(
  'Structures a village builds together: a palisade, a storehouse, a workshop, a watchtower. Each needs ' +
  'materials, which members bring; it is complete once its materials are in, with no labour stage (Phase 203). ' +
  'A finished project is placed as blocks and stations, and changes nothing else: it counts toward no tier ' +
  '(Phase 207).',
  'Give a new village something to build together in its first hour (CivilizationIsPlayerMade, Phase 197)',
  'Project table: { projects: { <key>: { minTier, materials, places } } }',
  PROJECTS,
  {
    start: {
      description: 'A member with build permission starts a project at a site',
      rules: ['The settlement must have reached the project\'s minTier'],
      auth: { roles: ['maintainer'] },
    },
    contribute: {
      description: 'A member adds materials to an unfinished project',
      rules: ['Materials are moved, never duplicated: what is contributed leaves the giver'],
      auth: { roles: ['maintainer'] },
    },
    complete: {
      description: 'The contribution that brings in the last material completes the project and places it',
      rules: ['Places places.blocks of places.block in the layout, plus places.stations', 'Counts toward no tier and credits no clan'],
      auth: { roles: ['maintainer'] },
    },
  },
)

const SettlementSpecialties = loopEntity(
  'What each member of a village is good at: woodworker, smith, hunter, builder or forager. A specialty is scored ' +
  'from the member\'s skill tiers and attributes; a member\'s specialty is their best score at or above the floor. ' +
  'A specialty is a consequence of how someone plays, never a class picked up front, and it gives no labour bonus (Phase 203).',
  'Make each member of a small village matter for something (EverythingHasTradeoffs, Phase 197)',
  'Specialty table: { floor, specialties: { <key>: { skills: { <skill>: weight }, attributes: { <attribute>: weight } } } }',
  SPECIALTIES,
  {
    score: {
      description: 'Score every specialty for a member and take the best one at or above the floor',
      rules: [
        'Skill score: weight × tier rank (novice 0 .. master 4); attribute score: weight × points above the base',
        'Ties go to the earlier specialty in the table; below the floor a member has no specialty',
      ],
      auth: { roles: ['maintainer'] },
    },
  },
)

module.exports = {
  RULES,
  settlementProblems,
  validateSettlement,
  LAYOUTS,
  PROJECTS,
  SPECIALTIES,
  settlementLoopData,
  settlementLoopRefs,
  settlementLoopProblems,
  validateSettlementLoop,
  SettlementProjects,
  SettlementSpecialties,

  // ─── Hearth ───────────────────────────────────────────────────────────────
  Hearth: defineEntity({
    tags: ['item', 'station'],
    description:
      'A stone-ringed fire pit that founds a settlement when placed. Phase 203 removed its claim and its research ' +
      'site; Phase 204 returns each placed hearth to its founder as this item when settlements become clans.',
    goal: 'The item and station that turns a camp into a shared settlement (Phase 139)',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg per hearth', defaultValue: 20.0 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'uncommon' },
      stackable: { type: 'boolean', description: 'False; one hearth per slot', defaultValue: false },
      shape: itemShape({ archetype: 'hearth', parts: { base: 'Ferrite', fuel: 'Thornwood' } }),
      durability: { type: 'integer', description: 'Structural integrity', defaultValue: 500 },
    },
    relations: {
      plank: { name: 'plank', kind: 'hasOne', target: 'ThornwoodPlank' },
      ingot: { name: 'ingot', kind: 'hasOne', target: 'FerriteIngot' },
      settlement: { name: 'settlement', kind: 'hasOne', target: 'Settlement' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'A hearth does not weather while carried',
        rules: ['Normal inventory storage never degrades a hearth'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Re-lay a worn hearth at a carpentry bench',
        rules: ['Requires a carpentry bench; no additional materials consumed'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeHearth ─────────────────────────────────────────────────────────
  RecipeHearth: defineEntity({
    tags: ['recipe'],
    description: 'Lay a hearth from six thornwood planks and four ferrite ingots at a carpentry bench.',
    goal: 'Make founding a settlement something a player prepares for (Phase 139)',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'carpentry',
        station: 'carpentry bench',
        inputs: [{ item: 'ThornwoodPlank', quantity: 6 }, { item: 'FerriteIngot', quantity: 4 }],
        outputs: [{ item: 'Hearth', quantity: 1 }],
        skillGuards: [{ skill: 'Carpentry', tier: 'apprentice' }],
      }),
    },
    relations: {
      inputPlank: { name: 'inputPlank', kind: 'hasOne', target: 'ThornwoodPlank' },
      inputIngot: { name: 'inputIngot', kind: 'hasOne', target: 'FerriteIngot' },
      output:     { name: 'output',     kind: 'hasOne', target: 'Hearth' },
    },
    behaviors: {
      craft: {
        description: 'Lay and fit a hearth at a carpentry bench',
        rules: [
          'Requires Carpentry: Apprentice',
          'Requires a carpentry bench structure',
          'Six planks and four ferrite ingots yield one hearth',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Stockpile ────────────────────────────────────────────────────────────
  Stockpile: defineEntity({
    tags: ['container'],
    description:
      'The container a settlement\'s members fill and draw from together. Its capacity in stacks grows with the ' +
      'settlement tier, and each role has a daily withdraw limit. Phase 204 turns it into a clan chest with the ' +
      'same contents (Clan.migration); research no longer draws from it (Phase 203).',
    goal: 'Give a settlement a shared store so cooperation is worth more than trading (Phase 139)',
    fields: {
      id: { type: 'uuid', primaryKey: true },
      capacityStacks: { type: 'integer', description: 'Stacks the stockpile holds at the current tier (Settlement rules.stockpile)', defaultValue: RULES.stockpile.founded.capacityStacks },
      usedStacks: { type: 'integer', description: 'Stacks currently held', defaultValue: 0 },
    },
    relations: {
      settlement: { name: 'settlement', kind: 'hasOne', target: 'Settlement' },
      governance: { name: 'governance', kind: 'hasOne', target: 'GovernanceSystem' },
    },
    behaviors: {
      deposit: {
        description: 'A member with build or take permission adds items to the stockpile',
        rules: [
          'Only members of the owning settlement may deposit',
          'A deposit beyond capacityStacks is refused whole, with no partial transfer',
          'Item totals are preserved: what is deposited is what is held',
        ],
        auth: { roles: ['maintainer'] },
      },
      withdraw: {
        description: 'A member takes items from the stockpile',
        rules: [
          'The role must have take permission',
          'A withdraw beyond the role\'s daily withdrawLimit is refused',
          'Guests never withdraw; the founder is not limited',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Settlement ───────────────────────────────────────────────────────────
  Settlement: defineEntity({
    tags: ['world-system'],
    description:
      'A player-founded village: a Hearth, members with roles and a shared Stockpile. It grows from founded to ' +
      'growing to town as members and days accumulate (growing also by completed projects), members build projects ' +
      'together, and it is abandoned when no member is active. Phase 203 replaced its claim with owned structures ' +
      'and clans: a settlement claims no land, and Phase 204 migrates each one to a Clan with the same name, ' +
      'members and roles (Clan.migration). Rule changes are made through GovernanceSystem proposals.',
    goal: 'Give players a shared place to build a civilization together (CivilizationIsPlayerMade)',
    fields: {
      id: { type: 'uuid', primaryKey: true },
      name: { type: 'string', description: 'Display name chosen by the founder' },
      founder: { type: 'string', description: 'Player id of the founder; always a member with the founder role' },
      members: { type: 'json', description: 'Player id -> role (founder, elder, member, guest)', defaultValue: {} },
      guild: { type: 'string', description: 'Guild that holds this settlement, empty if none; a guild holds at most guildMaxSettlements', defaultValue: '' },
      createdAt: { type: 'datetime', description: 'Wall-clock time the hearth was placed' },
      lastActiveAt: { type: 'datetime', description: 'Wall-clock time any member was last active' },
      rules: {
        type: 'json',
        description: 'Settlement rule table: { hearthStation, hearthItem, guildMaxSettlements, tiers, roles, stockpile, abandonAfterDays } (validated at fabric load)',
        defaultValue: RULES,
      },
      status: {
        type: 'enum',
        values: ['founded', 'growing', 'town', 'abandoned'],
        description: 'Lifecycle tier of the settlement',
      },
    },
    relations: {
      hearth:     { name: 'hearth',     kind: 'hasOne', target: 'Hearth' },
      stockpile:  { name: 'stockpile',  kind: 'hasOne', target: 'Stockpile' },
      governance: { name: 'governance', kind: 'hasOne', target: 'GovernanceSystem' },
      recipe:     { name: 'recipe',     kind: 'hasOne', target: 'RecipeHearth' },
      projects:    { name: 'projects',    kind: 'hasOne', target: 'SettlementProjects' },
      specialties: { name: 'specialties', kind: 'hasOne', target: 'SettlementSpecialties' },
      clan:        { name: 'clan',        kind: 'hasOne', target: 'Clan' },
      decision:    { name: 'decision',    kind: 'hasOne', target: 'ClansAndOwnedStructures' },
    },
    stateMachine: {
      field: 'status',
      initial: 'founded',
      states: {
        founded:   'The hearth is placed and the stockpile is at its smallest',
        growing:   'Enough members and days, or enough members and completed projects: the stockpile has grown',
        town:      'The top tier: the largest stockpile',
        abandoned: 'No member active for abandonAfterDays',
      },
      transitions: [
        { from: 'founded', to: 'growing',   trigger: 'grow' },
        { from: 'growing', to: 'town',      trigger: 'grow' },
        { from: ['founded', 'growing', 'town'], to: 'abandoned', trigger: 'abandon' },
        { from: 'abandoned', to: 'founded', trigger: 'reclaim' },
      ],
    },
    behaviors: {
      found: {
        description: 'Place a Hearth to found a settlement',
        rules: [
          'Consumes one Hearth item (RecipeHearth)',
          'The placer becomes the founder and the first member',
        ],
        auth: { roles: ['maintainer'] },
      },
      grow: {
        description: 'Raise the tier when member count and age meet the next tier thresholds',
        rules: [
          'minMembers and minDays of the next tier must be met; completed projects do not count (Phase 207)',
          'Stockpile capacity rises to the new tier\'s value and never shrinks',
        ],
        auth: { roles: ['maintainer'] },
      },
      abandon: {
        description: 'Mark a settlement with no member activity for abandonAfterDays as abandoned',
        rules: ['The Stockpile contents are kept for members who return'],
        auth: { roles: ['maintainer'] },
      },
      reclaim: {
        description: 'A member returns to an abandoned settlement',
        rules: ['The settlement returns to founded and grows with the tiers again'],
        auth: { roles: ['maintainer'] },
      },
      changeRules: {
        description: 'Change a settlement rule through a governance proposal',
        rules: [
          'A rule change is a GovernanceSystem proposal; it applies only once ratified',
          'Roles and withdraw limits are changed this way, never by the founder alone',
        ],
        auth: { roles: ['maintainer'] },
      },
      migrate: {
        description: 'Become a clan (Phase 204)',
        rules: [
          'The clan keeps the settlement\'s name, members and roles (Clan.migration)',
          'The hearth is removed and returned to the founder as a Hearth item',
          'The stockpile becomes a clan chest with the same contents',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),
}
