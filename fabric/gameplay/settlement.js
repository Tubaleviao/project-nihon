const { defineEntity, recipeData } = require('./recipes/shared')
const { RARITIES, DURABILITY_STATES, itemStateMachine, itemShape } = require('./items/shared')

// Phase 139 — settlements. A player founds a settlement by placing a `Hearth`; the hearth claims land
// around it, members share a `Stockpile`, and the claim grows with the settlement's tier. The runtime
// (Phase 140) reads this table from GameData.WORLD_SYSTEMS["Settlement"].
//
// `tiers`: settlement tier -> { claimRadius (m), minMembers, minDays }. A tier is reached when the
//   member count and the age in days both meet its thresholds; radius and thresholds never shrink
//   with tier.
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
    growing: { claimRadius: 48, minMembers: 3, minDays: 3 },
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
    if (prev) {
      if (t.claimRadius < prev.claimRadius) problems.push(`Settlement.tiers.${name}.claimRadius ${t.claimRadius} shrinks below the previous tier's ${prev.claimRadius}`)
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

module.exports = {
  RULES,
  settlementProblems,
  validateSettlement,

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
      'It grows from founded to growing to town as members and days accumulate, and is abandoned when no member ' +
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
    },
    stateMachine: {
      field: 'status',
      initial: 'founded',
      states: {
        founded:   'The hearth is placed and the claim is at its smallest radius',
        growing:   'Enough members and days: the claim and stockpile have grown',
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
          'Both minMembers and minDays of the next tier must be met',
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
