const { defineEntity, recipeData } = require('./recipes/shared')
const { RARITIES, DURABILITY_STATES, itemStateMachine, itemShape } = require('./items/shared')

// Phase 139 — settlements. A player founds a settlement by placing a `Hearth`; the hearth claims land
// around it, members share a `Stockpile`, and the claim grows with the settlement's tier. The runtime
// (Phase 140) reads this table from GameData.WORLD_SYSTEMS["Settlement"].
//
// `tiers`: settlement tier -> { claimRadius (m), minMembers, minDays, minProjects? }. A tier is reached
//   when the member count meets minMembers and either the age in days meets minDays or (Phase 197, when
//   the tier has minProjects) that many settlement projects are complete. Radius and thresholds never
//   shrink with tier.
// `roles`: member role -> permissions inside the claim (`build`, `take`, `invite`, `withdrawLimit` items
//   per day; the founder is never limited, and a role without `take` withdraws nothing).
// `stockpile`: shared container capacity (stacks) by tier.
// `abandonAfterDays`: days with no member activity before `town`/`growing` becomes `abandoned`.
// `decayRadiusPerDay`: metres a claim shrinks per day once abandoned; at 0 radius the land is free.
// `minSeparation`: metres between two hearths, always more than the sum of both claim radii at the
//   top tier so claims never cover another settlement's land.
const RULES = {
  hearthStation: 'hearth',
  hearthItem: 'Hearth',
  guildMaxSettlements: 1,
  tiers: {
    founded: { claimRadius: 24, minMembers: 1, minDays: 0 },
    growing: { claimRadius: 48, minMembers: 3, minDays: 3, minProjects: 2 },
    town:    { claimRadius: 96, minMembers: 8, minDays: 14 },
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
  decayRadiusPerDay: 2,
  minSeparation: 200,
}

const TIERS = ['founded', 'growing', 'town']
const KNOWN = ['hearthStation', 'hearthItem', 'guildMaxSettlements', 'tiers', 'roles', 'stockpile', 'abandonAfterDays', 'decayRadiusPerDay', 'minSeparation']

const isNum = (v) => typeof v === 'number' && Number.isFinite(v)

/** Problems with a settlement rule table, as strings. `itemKeys` (optional) lists valid item keys. */
function settlementProblems(rules, itemKeys) {
  const problems = []
  if (typeof rules.hearthStation !== 'string' || rules.hearthStation === '') problems.push('Settlement.hearthStation must be a non-empty string')
  if (typeof rules.hearthItem !== 'string' || rules.hearthItem === '') problems.push('Settlement.hearthItem must be a non-empty string')
  else if (itemKeys && !itemKeys.includes(rules.hearthItem)) problems.push(`Settlement.hearthItem "${rules.hearthItem}" is not a defined item`)
  if (!Number.isInteger(rules.guildMaxSettlements) || rules.guildMaxSettlements < 1) problems.push('Settlement.guildMaxSettlements must be an integer >= 1')
  if (!isNum(rules.abandonAfterDays) || rules.abandonAfterDays <= 0) problems.push('Settlement.abandonAfterDays must be a positive number')
  if (!isNum(rules.decayRadiusPerDay) || rules.decayRadiusPerDay <= 0) problems.push('Settlement.decayRadiusPerDay must be a positive number')

  const tiers = rules.tiers || {}
  let prev = null
  for (const name of TIERS) {
    const t = tiers[name]
    if (!t) { problems.push(`Settlement.tiers.${name} is missing`); prev = null; continue }
    if (!isNum(t.claimRadius) || t.claimRadius <= 0) problems.push(`Settlement.tiers.${name}.claimRadius must be > 0, got ${t.claimRadius}`)
    if (!Number.isInteger(t.minMembers) || t.minMembers < 1) problems.push(`Settlement.tiers.${name}.minMembers must be an integer >= 1`)
    if (!isNum(t.minDays) || t.minDays < 0) problems.push(`Settlement.tiers.${name}.minDays must be >= 0`)
    if ('minProjects' in t && (!Number.isInteger(t.minProjects) || t.minProjects < 1)) problems.push(`Settlement.tiers.${name}.minProjects must be an integer >= 1 when present`)
    if (prev) {
      if (t.claimRadius < prev.claimRadius) problems.push(`Settlement.tiers.${name}.claimRadius ${t.claimRadius} shrinks below the previous tier's ${prev.claimRadius}`)
      if (t.minMembers < prev.minMembers) problems.push(`Settlement.tiers.${name}.minMembers ${t.minMembers} is below the previous tier's ${prev.minMembers} (thresholds out of order)`)
      if (t.minDays < prev.minDays) problems.push(`Settlement.tiers.${name}.minDays ${t.minDays} is below the previous tier's ${prev.minDays} (thresholds out of order)`)
    }
    prev = t
  }
  for (const name of Object.keys(tiers)) if (!TIERS.includes(name)) problems.push(`Settlement.tiers has unknown tier "${name}"`)
  if (tiers.town && 'minProjects' in tiers.town) problems.push('Settlement.tiers.town keeps its day threshold and takes no minProjects')

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

  const top = tiers.town
  if (!isNum(rules.minSeparation)) problems.push('Settlement.minSeparation must be a number')
  else if (top && isNum(top.claimRadius) && rules.minSeparation <= 2 * top.claimRadius) problems.push(`Settlement.minSeparation ${rules.minSeparation} must exceed twice the top claim radius ${2 * top.claimRadius}, so claims never overlap`)
  for (const key of Object.keys(rules)) if (!KNOWN.includes(key)) problems.push(`Settlement has unknown field "${key}"`)
  return problems
}

function validateSettlement(rules, itemKeys) {
  const problems = settlementProblems(rules, itemKeys)
  if (problems.length) throw new Error('Settlement rule is invalid:\n  ' + problems.join('\n  '))
}

// ─── Phase 197 — the settlement loop: projects, specialties, raids and upkeep ───────────────────────
// Four rule tables, one world system each, read by Phases 198–201 from GameData.WORLD_SYSTEMS
// ("SettlementProjects", "SettlementSpecialties", "SettlementRaids", "SettlementUpkeep").
//
// PROJECTS — structures a village builds together inside its claim.
//   `workSecondsPerUnit`: seconds of contributing at the site that one work unit takes.
//   `projects`: key -> {
//     minTier    the lowest settlement tier that may start it
//     materials  [{ item, quantity }] existing item keys, taken from the stockpile or a member as given
//     labour     [{ step, specialty, work }] ordered steps; `work` in work units, and a member whose
//                specialty matches the step's adds SPECIALTIES.bonusLabour more per unit
//     effects    [{ kind, value }] from EFFECT_KINDS, active while the project stands and upkeep is paid
//     places     { block, blocks, layout, stations } what is placed in the claim when it completes:
//                `blocks` of `block` (an item or material key) in the `layout` shape, plus `stations`
//   }
// SPECIALTIES — what each member is good at. A specialty's score is the sum of weight × skill tier rank
//   (novice 0 .. master 4) over `skills` plus weight × attribute points above the base over `attributes`.
//   A member's specialty is their best score at or above `floor` (ties go to the earlier row); a member
//   below the floor has none.
// RAIDS — creature attacks on a village (never settlement against settlement).
//   A raid can start when the settlement is at least `minAgeMinutes` old, has reached `minTier` or holds
//   at least `minStockpileStacks`, the last raid ended `cooldownHours` ago, and (`offlineProtection`) a
//   member is online inside the claim. `warningSeconds` pass between the warning and the first creature.
//   `packs`: biome -> [{ creature, min, max }] existing creatures of that biome; a biome with no row is
//   never raided. If the raid is not repelled within `durationSeconds`, the village loses at most
//   `stakes.stockpileShareMax` of its stockpile and each unfinished project at most
//   `stakes.projectDamageMax` of its contributed labour; raidDefence effects scale both losses down by
//   up to `defenceCap`.
// UPKEEP — a cost per tier taken from the stockpile every `periodHours`. Unpaid upkeep suspends project
//   effects until it is paid; it never shrinks the claim (`shrinksClaim` false), which follows only the
//   activity-based abandonment rule. upkeepRelief effects reduce each quantity (rounded down).
const EFFECT_KINDS = ['stockpileCapacity', 'raidDefence', 'craftSpeed', 'upkeepRelief']
const LAYOUTS = ['ring', 'tower', 'hall', 'shed']

const PROJECTS = {
  workSecondsPerUnit: 2,
  projects: {
    palisade: {
      minTier: 'founded',
      materials: [{ item: 'ThornwoodPlank', quantity: 40 }, { item: 'FerriteIngot', quantity: 4 }],
      labour: [
        { step: 'posts', specialty: 'woodworker', work: 60 },
        { step: 'raise', specialty: 'builder', work: 90 },
      ],
      effects: [{ kind: 'raidDefence', value: 0.3 }],
      places: { block: 'ThornwoodPlank', blocks: 48, layout: 'ring', stations: [] },
    },
    storehouse: {
      minTier: 'founded',
      materials: [{ item: 'ThornwoodPlank', quantity: 30 }, { item: 'AshiteBlock', quantity: 12 }],
      labour: [
        { step: 'foundation', specialty: 'builder', work: 60 },
        { step: 'shelving', specialty: 'woodworker', work: 60 },
        { step: 'provisions', specialty: 'forager', work: 30 },
      ],
      effects: [{ kind: 'stockpileCapacity', value: 20 }, { kind: 'upkeepRelief', value: 0.25 }],
      places: { block: 'AshiteBlock', blocks: 24, layout: 'shed', stations: [] },
    },
    workshop: {
      minTier: 'founded',
      materials: [{ item: 'ThornwoodPlank', quantity: 20 }, { item: 'FerriteIngot', quantity: 10 }, { item: 'AshiteBlock', quantity: 10 }],
      labour: [
        { step: 'walls', specialty: 'builder', work: 60 },
        { step: 'benches', specialty: 'woodworker', work: 45 },
        { step: 'anvil', specialty: 'smith', work: 45 },
      ],
      effects: [{ kind: 'craftSpeed', value: 0.2 }],
      places: { block: 'AshiteBlock', blocks: 32, layout: 'hall', stations: ['carpentry bench', 'forge'] },
    },
    watchtower: {
      minTier: 'growing',
      materials: [{ item: 'ThornwoodPlank', quantity: 24 }, { item: 'AshiteBlock', quantity: 16 }, { item: 'FerriteIngot', quantity: 6 }],
      labour: [
        { step: 'base', specialty: 'builder', work: 90 },
        { step: 'lookout', specialty: 'woodworker', work: 60 },
        { step: 'signal', specialty: 'hunter', work: 30 },
      ],
      effects: [{ kind: 'raidDefence', value: 0.2 }],
      places: { block: 'AshiteBlock', blocks: 40, layout: 'tower', stations: [] },
    },
  },
}

const SPECIALTIES = {
  floor: 2,
  bonusLabour: 0.5,
  specialties: {
    woodworker: { skills: { Carpentry: 1 }, attributes: { strength: 0.25 } },
    smith:      { skills: { Smithing: 1, ArcaneForging: 0.5 }, attributes: { strength: 0.25 } },
    hunter:     { skills: { Archery: 0.5, Swordsmanship: 0.5, Skinning: 0.5, Tracking: 0.5 }, attributes: { agility: 0.25 } },
    builder:    { skills: { Carpentry: 0.5, Leadership: 0.5 }, attributes: { vitality: 0.25, strength: 0.25 } },
    forager:    { skills: { Tracking: 0.5, Navigation: 0.5, Alchemy: 0.5 }, attributes: { perception: 0.25 } },
  },
}

const RAIDS = {
  minAgeMinutes: 30,
  minTier: 'growing',
  minStockpileStacks: 10,
  cooldownHours: 6,
  warningSeconds: 120,
  durationSeconds: 600,
  offlineProtection: true,
  defenceCap: 0.75,
  stakes: { stockpileShareMax: 0.2, projectDamageMax: 0.25 },
  packs: {
    TemperateForest:    [{ creature: 'GraywolfPack', min: 3, max: 5 }, { creature: 'ForestBoar', min: 1, max: 2 }],
    TemperateGrassland: [{ creature: 'SteppeBison', min: 2, max: 3 }, { creature: 'RidgeHawk', min: 2, max: 4 }],
    VolcanicBadlands:   [{ creature: 'CinderGargoyle', min: 2, max: 3 }, { creature: 'LavaSlug', min: 2, max: 4 }],
    TwilightGrove:      [{ creature: 'VeilStalker', min: 2, max: 3 }, { creature: 'GlimmerFox', min: 2, max: 4 }],
    VoidRift:           [{ creature: 'VoidSerpent', min: 2, max: 4 }],
  },
}

const UPKEEP = {
  periodHours: 24,
  shrinksClaim: false,
  costs: {
    founded: [{ item: 'ThornwoodPlank', quantity: 2 }],
    growing: [{ item: 'ThornwoodPlank', quantity: 6 }, { item: 'FerriteIngot', quantity: 1 }],
    town:    [{ item: 'ThornwoodPlank', quantity: 12 }, { item: 'FerriteIngot', quantity: 3 }, { item: 'AshiteBlock', quantity: 4 }],
  },
}

const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)

/** The four loop tables plus the tier table they refer to, as plain data. */
function settlementLoopData() {
  return JSON.parse(JSON.stringify({ tiers: RULES.tiers, projects: PROJECTS, specialties: SPECIALTIES, raids: RAIDS, upkeep: UPKEEP }))
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
  if (!isNum(pr.workSecondsPerUnit) || pr.workSecondsPerUnit <= 0) p.push('SettlementProjects.workSecondsPerUnit must be > 0')
  if (!isObj(pr.projects) || Object.keys(pr.projects).length === 0) p.push('SettlementProjects.projects must name at least one project')
  for (const [key, proj] of Object.entries(pr.projects || {})) {
    const at = `SettlementProjects.${key}`
    if (!tierNames.includes(proj.minTier)) p.push(`${at}.minTier "${proj.minTier}" is not a settlement tier`)
    p.push(...costProblems(`${at}.materials`, proj.materials, refs.items))
    if (!Array.isArray(proj.labour) || proj.labour.length === 0) p.push(`${at}.labour must list at least one step`)
    for (const [i, s] of (proj.labour || []).entries()) {
      if (typeof s.step !== 'string' || s.step === '') p.push(`${at}.labour[${i}].step must be a non-empty string`)
      if (!specialtyNames.includes(s.specialty)) p.push(`${at}.labour[${i}].specialty "${s.specialty}" is not a specialty`)
      if (!Number.isInteger(s.work) || s.work < 1) p.push(`${at}.labour[${i}].work must be an integer >= 1`)
    }
    if (!Array.isArray(proj.effects) || proj.effects.length === 0) p.push(`${at}.effects must list at least one effect`)
    for (const [i, e] of (proj.effects || []).entries()) {
      if (!EFFECT_KINDS.includes(e.kind)) { p.push(`${at}.effects[${i}].kind "${e.kind}" must be one of ${EFFECT_KINDS.join(', ')}`); continue }
      if (e.kind === 'stockpileCapacity' ? !(Number.isInteger(e.value) && e.value >= 1) : !(isNum(e.value) && e.value > 0 && e.value <= 1)) {
        p.push(`${at}.effects[${i}].value ${e.value} is out of range for ${e.kind} (stacks >= 1, other kinds in (0, 1])`)
      }
    }
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
  if (!isNum(sp.bonusLabour) || sp.bonusLabour <= 0 || sp.bonusLabour > 1) p.push('SettlementSpecialties.bonusLabour must be in (0, 1]')
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
  const used = new Set(Object.values(pr.projects || {}).flatMap((x) => (x.labour || []).map((s) => s.specialty)))
  for (const name of specialtyNames) if (!used.has(name)) p.push(`SettlementSpecialties.${name} matches no project step, so it never gives bonus labour`)

  // Raids
  const r = data.raids || {}
  if (r.offlineProtection !== true) p.push('SettlementRaids.offlineProtection must be true: no raid starts unless a member is online inside the claim')
  if (!isNum(r.warningSeconds) || r.warningSeconds <= 0) p.push('SettlementRaids.warningSeconds must be > 0: every raid is warned')
  if (!isNum(r.minAgeMinutes) || r.minAgeMinutes < 0) p.push('SettlementRaids.minAgeMinutes must be >= 0')
  if (!tierNames.includes(r.minTier)) p.push(`SettlementRaids.minTier "${r.minTier}" is not a settlement tier`)
  if (!Number.isInteger(r.minStockpileStacks) || r.minStockpileStacks < 1) p.push('SettlementRaids.minStockpileStacks must be an integer >= 1')
  if (!isNum(r.cooldownHours) || r.cooldownHours <= 0) p.push('SettlementRaids.cooldownHours must be > 0')
  if (!isNum(r.durationSeconds) || r.durationSeconds <= 0) p.push('SettlementRaids.durationSeconds must be > 0')
  if (!isNum(r.defenceCap) || r.defenceCap < 0 || r.defenceCap >= 1) p.push('SettlementRaids.defenceCap must be in [0, 1): a raid always has something at stake')
  const st = isObj(r.stakes) ? r.stakes : {}
  for (const k of ['stockpileShareMax', 'projectDamageMax']) {
    if (!isNum(st[k]) || st[k] < 0 || st[k] > 1) p.push(`SettlementRaids.stakes.${k} must be a share in [0, 1], got ${st[k]}`)
  }
  if (!isObj(r.packs) || Object.keys(r.packs).length === 0) p.push('SettlementRaids.packs must name at least one biome')
  for (const [biome, rows] of Object.entries(r.packs || {})) {
    const at = `SettlementRaids.packs.${biome}`
    if (!refs.biomes.includes(biome)) p.push(`${at}: unknown biome "${biome}"`)
    if (!Array.isArray(rows) || rows.length === 0) { p.push(`${at} must list at least one creature`); continue }
    for (const [i, row] of rows.entries()) {
      if (!(row.creature in refs.creatureBiome)) p.push(`${at}[${i}]: unknown creature "${row.creature}"`)
      else if (refs.creatureBiome[row.creature] !== biome) p.push(`${at}[${i}]: ${row.creature} lives in ${refs.creatureBiome[row.creature]}, not ${biome}`)
      if (!Number.isInteger(row.min) || !Number.isInteger(row.max) || row.min < 1 || row.max < row.min) p.push(`${at}[${i}] needs integers 1 <= min <= max`)
    }
  }

  // Upkeep
  const u = data.upkeep || {}
  if (!isNum(u.periodHours) || u.periodHours <= 0) p.push('SettlementUpkeep.periodHours must be > 0')
  if (u.shrinksClaim !== false) p.push('SettlementUpkeep.shrinksClaim must be false: unpaid upkeep suspends project effects, never the claim')
  const costs = isObj(u.costs) ? u.costs : {}
  let prev = null
  for (const name of tierNames) {
    if (!(name in costs)) { p.push(`SettlementUpkeep.costs.${name} is missing`); prev = null; continue }
    p.push(...costProblems(`SettlementUpkeep.costs.${name}`, costs[name], refs.items))
    if (prev && Array.isArray(costs[name])) {
      for (const m of prev.list) {
        const q = (costs[name].find((x) => x.item === m.item) || { quantity: 0 }).quantity
        if (q < m.quantity) p.push(`SettlementUpkeep.costs.${name}: ${m.item} ${q} falls below ${prev.name}'s ${m.quantity} (upkeep never falls as the tier rises)`)
      }
    }
    prev = Array.isArray(costs[name]) ? { name, list: costs[name] } : null
  }
  for (const name of Object.keys(costs)) if (!tierNames.includes(name)) p.push(`SettlementUpkeep.costs has unknown tier "${name}"`)
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
  'Structures a village builds together inside its claim: a palisade, a storehouse, a workshop, a watchtower. ' +
  'Each needs materials and labour in ordered steps; members contribute both, and a member whose specialty ' +
  'matches a step works faster on it. A finished project is placed as blocks and stations in the claim, and its ' +
  'effects (stockpile capacity, raid defence, crafting speed inside the claim, upkeep relief) hold while upkeep is paid. ' +
  'Completed projects also grow a village: the growing tier is reached by minMembers and minProjects as well as by days.',
  'Give a new village something to build together in its first hour (CivilizationIsPlayerMade, Phase 197)',
  'Project table: { workSecondsPerUnit, projects: { <key>: { minTier, materials, labour, effects, places } } }',
  PROJECTS,
  {
    start: {
      description: 'A member with build permission starts a project at a site inside the claim',
      rules: ['The settlement must have reached the project\'s minTier', 'The site must lie inside the claim'],
      auth: { roles: ['maintainer'] },
    },
    contribute: {
      description: 'A member adds materials or labour to an unfinished project',
      rules: [
        'Materials are moved, never duplicated: what is contributed leaves the giver',
        'One work unit takes workSecondsPerUnit seconds at the site; a matching specialty adds bonusLabour per unit',
        'Steps are worked in order',
      ],
      auth: { roles: ['maintainer'] },
    },
    complete: {
      description: 'All materials and labour are in: the structure is placed and its effects start',
      rules: ['Places places.blocks of places.block in the layout, plus places.stations', 'Counts toward the tier\'s minProjects'],
      auth: { roles: ['maintainer'] },
    },
  },
)

const SettlementSpecialties = loopEntity(
  'What each member of a village is good at: woodworker, smith, hunter, builder or forager. A specialty is scored ' +
  'from the member\'s skill tiers and attributes; a member\'s specialty is their best score at or above the floor, ' +
  'and it adds bonus labour on project steps that ask for it. A specialty is a consequence of how someone plays, never a class picked up front.',
  'Make each member of a small village matter for something (EverythingHasTradeoffs, Phase 197)',
  'Specialty table: { floor, bonusLabour, specialties: { <key>: { skills: { <skill>: weight }, attributes: { <attribute>: weight } } } }',
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

const SettlementRaids = loopEntity(
  'Creature packs from the village\'s own biome attack a settlement that is worth raiding. Every raid is warned, ' +
  'never starts while no member is online inside the claim, and has a capped loss: a share of the stockpile and ' +
  'damage to unfinished projects, both reduced by raid-defence projects. Raids come from creatures only; ' +
  'settlement-against-settlement conflict is deferred.',
  'Give a village something to defend together without punishing it for being offline (SettlementRaidsAndUpkeep, Phase 197)',
  'Raid table: { minAgeMinutes, minTier, minStockpileStacks, cooldownHours, warningSeconds, durationSeconds, offlineProtection, defenceCap, stakes, packs }',
  RAIDS,
  {
    warn: {
      description: 'Announce a raid to every member warningSeconds before the first creature arrives',
      rules: [
        'The settlement is at least minAgeMinutes old and has reached minTier or holds minStockpileStacks',
        'cooldownHours have passed since the last raid ended',
        'A member is online inside the claim (offlineProtection)',
      ],
      auth: { roles: ['maintainer'] },
    },
    resolve: {
      description: 'End the raid: repelled when every raider is dead, otherwise lost after durationSeconds',
      rules: [
        'A lost raid takes at most stakes.stockpileShareMax of the stockpile and stakes.projectDamageMax of each unfinished project\'s labour',
        'Raid-defence effects scale both losses down by at most defenceCap',
      ],
      auth: { roles: ['maintainer'] },
    },
  },
)

const SettlementUpkeep = loopEntity(
  'What a village pays to keep going: a cost per tier taken from the stockpile every period. Unpaid upkeep ' +
  'suspends project effects until it is paid; it never shrinks the claim, which still follows only the ' +
  'activity-based abandonment rule. Upkeep never falls as the tier rises.',
  'Give a growing village a reason to keep gathering and trading (EverythingHasTradeoffs, Phase 197)',
  'Upkeep table: { periodHours, shrinksClaim, costs: { <tier>: [{ item, quantity }] } }',
  UPKEEP,
  {
    pay: {
      description: 'Take the tier\'s upkeep from the stockpile once per periodHours',
      rules: [
        'upkeepRelief effects reduce each quantity, rounded down',
        'If the stockpile cannot pay in full nothing is taken and project effects are suspended until it can',
        'Unpaid upkeep never shrinks the claim',
      ],
      auth: { roles: ['maintainer'] },
    },
  },
)

module.exports = {
  RULES,
  settlementProblems,
  validateSettlement,
  EFFECT_KINDS,
  LAYOUTS,
  PROJECTS,
  SPECIALTIES,
  RAIDS,
  UPKEEP,
  settlementLoopData,
  settlementLoopRefs,
  settlementLoopProblems,
  validateSettlementLoop,
  SettlementProjects,
  SettlementSpecialties,
  SettlementRaids,
  SettlementUpkeep,

  // ─── Hearth ───────────────────────────────────────────────────────────────
  Hearth: defineEntity({
    tags: ['item', 'station'],
    description:
      'A stone-ringed fire pit that founds a settlement when placed on free land. It is the settlement\'s ' +
      'research and crafting anchor: technology research that needs a "player\'s settlement" is done at a Hearth.',
    goal: 'The item and station that turns a camp into a claimed, shared settlement (Phase 139)',
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
      'settlement tier, and each role has a daily withdraw limit. Technology research that needs "settlement ' +
      'storage" draws its materials from here.',
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
          'The role must have take permission inside the claim',
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
      'A player-founded place: a Hearth, a claimed circle of land, members with roles and a shared Stockpile. ' +
      'It grows from founded to growing to town as members and days accumulate (growing also by completed projects), ' +
      'members build projects together, defend against creature raids and pay upkeep, and it is abandoned when no member ' +
      'is active; an abandoned claim decays until the land is free again. A claim never covers another ' +
      'settlement\'s land. Rule changes are made through GovernanceSystem proposals.',
    goal: 'Give players a shared place to build a civilization together (CivilizationIsPlayerMade)',
    fields: {
      id: { type: 'uuid', primaryKey: true },
      name: { type: 'string', description: 'Display name chosen by the founder' },
      founder: { type: 'string', description: 'Player id of the founder; always a member with the founder role' },
      members: { type: 'json', description: 'Player id -> role (founder, elder, member, guest)', defaultValue: {} },
      guild: { type: 'string', description: 'Guild that holds this settlement, empty if none; a guild holds at most guildMaxSettlements', defaultValue: '' },
      createdAt: { type: 'datetime', description: 'Wall-clock time the hearth was placed' },
      lastActiveAt: { type: 'datetime', description: 'Wall-clock time any member was last active inside the claim' },
      rules: {
        type: 'json',
        description: 'Settlement rule table: { hearthStation, hearthItem, guildMaxSettlements, tiers, roles, stockpile, abandonAfterDays, decayRadiusPerDay, minSeparation } (validated at fabric load)',
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
      raids:       { name: 'raids',       kind: 'hasOne', target: 'SettlementRaids' },
      upkeep:      { name: 'upkeep',      kind: 'hasOne', target: 'SettlementUpkeep' },
      decision:    { name: 'decision',    kind: 'hasOne', target: 'SettlementRaidsAndUpkeep' },
    },
    stateMachine: {
      field: 'status',
      initial: 'founded',
      states: {
        founded:   'The hearth is placed and the claim is at its smallest radius',
        growing:   'Enough members and days, or enough members and completed projects: the claim and stockpile have grown',
        town:      'The top tier: the largest claim and stockpile',
        abandoned: 'No member active for abandonAfterDays: the claim decays until the land is free',
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
        description: 'Place a Hearth on free land to found a settlement',
        rules: [
          'Consumes one Hearth item (RecipeHearth)',
          'The claim must not overlap another settlement\'s claim: hearths are at least minSeparation apart',
          'The placer becomes the founder and the first member',
        ],
        auth: { roles: ['maintainer'] },
      },
      grow: {
        description: 'Raise the tier when member count and age meet the next tier thresholds',
        rules: [
          'minMembers of the next tier must be met, and either its minDays or (when it has one) its minProjects completed settlement projects',
          'The claim radius and Stockpile capacity rise to the new tier\'s values and never shrink',
        ],
        auth: { roles: ['maintainer'] },
      },
      abandon: {
        description: 'Mark a settlement with no member activity for abandonAfterDays as abandoned',
        rules: [
          'The claim shrinks by decayRadiusPerDay each day until its land is free',
          'The Stockpile contents are kept for members who return',
        ],
        auth: { roles: ['maintainer'] },
      },
      reclaim: {
        description: 'A member returns to an abandoned settlement whose claim has not fully decayed',
        rules: ['The settlement returns to founded and the claim regrows with the tiers'],
        auth: { roles: ['maintainer'] },
      },
      changeRules: {
        description: 'Change a settlement rule through a governance proposal',
        rules: [
          'A rule change is a GovernanceSystem proposal; it applies only once ratified',
          'Claim radius, roles and withdraw limits are changed this way, never by the founder alone',
        ],
        auth: { roles: ['maintainer'] },
      },
      build: {
        description: 'Build or break inside the claim',
        rules: [
          'Only roles with build permission may build inside the claim',
          'Outsiders may not build or take inside a claim',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),
}
