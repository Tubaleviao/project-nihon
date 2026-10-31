const { defineEntity } = require('@newel/core')
const { RARITIES } = require('./items/shared')
const creation = require('./characters/creation')
const settlement = require('./settlement')

// Phase 203 — clans. A player founds a clan by choosing its name and invites other players. A clan has any
// number of members and a player belongs to at most one. Every member sees every other member's skills, so
// they can find the clan's best sewer and message them. A clan has no hearth: its settlements and cities are
// simply where its buildings stand (Structure). Phase 204 reads CLAN from GameData.WORLD_SYSTEMS["Clan"],
// Phase 210 reads TIERS from GameData.WORLD_SYSTEMS["ClanTiers"].
//
// CLAN
//   `name`        a player-chosen name: length and separators, checked with the character-name rules
//                 (CharacterCreation.name: scripts, confusable skeletons, reserved words) and unique by
//                 skeleton among clans. `reserved` adds clan-only words to the character list.
//   `maxClansPerPlayer` always 1. `maxMembers` 0 = no limit.
//   `roles`       role -> { invite, kick, setRole, dismantleClanStructures }. The founder holds every
//                 permission and cannot be kicked; `founderRole` names it.
//   `invites`     { ttlDays, maxPendingPerClan }: an invite lapses after ttlDays.
//   `roster`      who sees a member's skills: always `members` (the clan's own peers, never an outsider).
//   `messages`    private messages: { maxLength, perMinute } per sender, relayed only to the recipient.
//   `hasHearth`   always false.
//   `migration`   how a saved settlement becomes a clan: same name, members and roles; the hearth goes back
//                 to its founder as an item; the stockpile becomes a clan chest with the same contents.
// TIERS — a clan's score is the sum over every block of every structure it owns, wherever it stands, of the
//   block material's `durability` / `durabilityUnit` × `rarityWeight[material.rarity]`. A tier is reached at
//   its `minScore` and lost below it. A tier gives nothing yet (`gives` is empty; clan skills come later).
const CLAN = {
  name: { minLength: 3, maxLength: 24, maxSeparators: 3, rules: 'CharacterCreation.name', uniqueBy: 'skeleton', reserved: ['clan', 'cla', 'guild', 'guilda'] },
  maxClansPerPlayer: 1,
  maxMembers: 0,
  founderRole: 'founder',
  roles: {
    founder: { invite: true, kick: true, setRole: true, dismantleClanStructures: true },
    elder:   { invite: true, kick: true, setRole: false, dismantleClanStructures: true },
    member:  { invite: false, kick: false, setRole: false, dismantleClanStructures: true },
    guest:   { invite: false, kick: false, setRole: false, dismantleClanStructures: false },
  },
  invites: { ttlDays: 7, maxPendingPerClan: 32 },
  roster: { skillsVisibleTo: 'members', sortBy: 'skill' },
  messages: { maxLength: 280, perMinute: 10 },
  hasHearth: false,
  migration: { from: 'Settlement', name: 'same', members: 'same', roles: 'same', hearth: 'returnToFounder', stockpile: 'clanChest' },
}

const TIERS = {
  durabilityUnit: 100,
  rarityWeight: { common: 1, uncommon: 2, rare: 4, epic: 8, legendary: 16 },
  tiers: [
    { tier: 'band',    minScore: 0 },
    { tier: 'clan',    minScore: 400 },
    { tier: 'house',   minScore: 4000 },
    { tier: 'dynasty', minScore: 40000 },
  ],
  gives: [],
}

const PERMISSIONS = ['invite', 'kick', 'setRole', 'dismantleClanStructures']
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
const isNum = (v) => typeof v === 'number' && Number.isFinite(v)

function clanData() {
  return JSON.parse(JSON.stringify({ clan: CLAN, tiers: TIERS }))
}

function clanRefs() {
  return {
    characterName: creation.NAME_LIMITS,
    settlementRoles: Object.keys(settlement.RULES.roles),
    rarities: [...RARITIES],
  }
}

/** Problems with the clan and clan tier tables, as strings. */
function clanProblems(data, refs) {
  const p = []
  const c = data.clan || {}
  const n = isObj(c.name) ? c.name : {}
  if (!Number.isInteger(n.minLength) || n.minLength < 1) p.push('Clan.name.minLength must be an integer >= 1')
  if (!Number.isInteger(n.maxLength) || n.maxLength < n.minLength) p.push('Clan.name.maxLength must be an integer >= minLength')
  if (Number.isInteger(n.minLength) && n.minLength < refs.characterName.minLength) p.push(`Clan.name.minLength ${n.minLength} is below the character-name minimum ${refs.characterName.minLength}`)
  if (n.rules !== 'CharacterCreation.name') p.push('Clan.name.rules must be "CharacterCreation.name": clan names are checked as character names are')
  if (n.uniqueBy !== 'skeleton') p.push('Clan.name.uniqueBy must be "skeleton": two clans never share a name, even through look-alike letters')
  if (c.maxClansPerPlayer !== 1) p.push('Clan.maxClansPerPlayer must be 1: a player belongs to at most one clan')
  if (c.maxMembers !== 0) p.push('Clan.maxMembers must be 0: a clan has any number of members')
  if (c.hasHearth !== false) p.push('Clan.hasHearth must be false: a clan is where its buildings stand')
  const roles = isObj(c.roles) ? c.roles : {}
  const founder = roles[c.founderRole]
  if (!founder) p.push(`Clan.founderRole "${c.founderRole}" is not a role`)
  else for (const k of PERMISSIONS) if (founder[k] !== true) p.push(`Clan.roles.${c.founderRole}.${k} must be true: the founder holds every permission`)
  for (const [name, r] of Object.entries(roles)) for (const k of PERMISSIONS) if (typeof r[k] !== 'boolean') p.push(`Clan.roles.${name}.${k} must be a boolean`)
  const inv = isObj(c.invites) ? c.invites : {}
  if (!isNum(inv.ttlDays) || inv.ttlDays <= 0) p.push('Clan.invites.ttlDays must be > 0')
  if (!Number.isInteger(inv.maxPendingPerClan) || inv.maxPendingPerClan < 1) p.push('Clan.invites.maxPendingPerClan must be an integer >= 1')
  if (!isObj(c.roster) || c.roster.skillsVisibleTo !== 'members') p.push('Clan.roster.skillsVisibleTo must be "members": an outsider never sees a member\'s skills')
  const m = isObj(c.messages) ? c.messages : {}
  if (!Number.isInteger(m.maxLength) || m.maxLength < 1) p.push('Clan.messages.maxLength must be an integer >= 1')
  if (!Number.isInteger(m.perMinute) || m.perMinute < 1) p.push('Clan.messages.perMinute must be an integer >= 1: private messages are rate-limited')
  const mig = isObj(c.migration) ? c.migration : {}
  for (const k of ['name', 'members', 'roles']) if (mig[k] !== 'same') p.push(`Clan.migration.${k} must be "same": a migrated settlement keeps its ${k}`)
  if (mig.hearth !== 'returnToFounder') p.push('Clan.migration.hearth must be "returnToFounder"')
  if (mig.stockpile !== 'clanChest') p.push('Clan.migration.stockpile must be "clanChest"')
  for (const r of refs.settlementRoles) if (!(r in roles)) p.push(`Clan.roles.${r} is missing: a migrated settlement keeps its ${r} role`)

  const t = data.tiers || {}
  if (!isNum(t.durabilityUnit) || t.durabilityUnit <= 0) p.push('ClanTiers.durabilityUnit must be > 0')
  const w = isObj(t.rarityWeight) ? t.rarityWeight : {}
  let prevW = 0
  for (const r of refs.rarities) {
    if (!isNum(w[r]) || w[r] <= prevW) p.push(`ClanTiers.rarityWeight.${r} must be a number above the previous rarity's ${prevW}: a rarer material always weighs more`)
    else prevW = w[r]
  }
  const tiers = Array.isArray(t.tiers) ? t.tiers : []
  if (tiers.length < 2) p.push('ClanTiers.tiers must list at least two tiers')
  if (tiers[0] && tiers[0].minScore !== 0) p.push('ClanTiers.tiers[0].minScore must be 0: every clan has a tier')
  for (let i = 1; i < tiers.length; i++) {
    if (!isNum(tiers[i].minScore) || tiers[i].minScore <= tiers[i - 1].minScore) p.push(`ClanTiers.tiers[${i}].minScore must rise above ${tiers[i - 1].minScore}`)
  }
  if (new Set(tiers.map((x) => x.tier)).size !== tiers.length) p.push('ClanTiers.tiers names must be unique')
  if (!Array.isArray(t.gives) || t.gives.length !== 0) p.push('ClanTiers.gives must be empty: a tier gives nothing yet')
  return p
}

function validateClan(data, refs) {
  const problems = clanProblems(data, refs)
  if (problems.length) throw new Error('Clan rules are invalid:\n  ' + problems.join('\n  '))
}

const Clan = defineEntity({
  tags: ['world-system'],
  description:
    'A group of players under a name one of them chose. A player belongs to at most one clan; a clan has any ' +
    'number of members, roles that may invite, kick and set roles, and no hearth: its settlements are simply ' +
    'where its buildings stand. Every member sees every other member\'s skills and can message any of them ' +
    'privately, so the clan\'s best sewer is one click away. A saved settlement becomes a clan with the same ' +
    'name, members and roles.',
  goal: 'Let players organise without a land claim (ClansAndOwnedStructures, Phase 203)',
  fields: {
    id:      { type: 'uuid', primaryKey: true },
    name:    { type: 'string', description: 'The name the founder chose; unique by skeleton among clans' },
    founder: { type: 'string', description: 'Player id of the founder' },
    members: { type: 'json', description: 'Player id -> role', defaultValue: {} },
    invites: { type: 'json', description: 'Invited player id -> time of the invite; lapses after invites.ttlDays', defaultValue: {} },
    rules:   { type: 'json', description: 'Clan rule table: { name, maxClansPerPlayer, maxMembers, founderRole, roles, invites, roster, messages, hasHearth, migration } (validated at fabric load)', defaultValue: CLAN },
  },
  relations: {
    tiers:      { name: 'tiers',      kind: 'hasOne', target: 'ClanTiers' },
    settlement: { name: 'settlement', kind: 'hasOne', target: 'Settlement' },
    decision:   { name: 'decision',   kind: 'hasOne', target: 'ClansAndOwnedStructures' },
  },
  behaviors: {
    found: {
      description: 'A player who is in no clan founds one with a name',
      rules: ['The name passes the character-name rules and no clan has the same skeleton', 'The founder is the first member'],
      auth: { roles: ['maintainer'] },
    },
    invite: {
      description: 'A member whose role may invite asks another player to join',
      rules: ['The invite lapses after invites.ttlDays', 'A player already in a clan cannot accept'],
      auth: { roles: ['maintainer'] },
    },
    leave: {
      description: 'A member leaves, or is kicked by a role that may kick',
      rules: ['The founder cannot be kicked', 'A member who leaves stops receiving the others\' skills'],
      auth: { roles: ['maintainer'] },
    },
    message: {
      description: 'Send a private message to one player',
      rules: ['The host relays it only to the recipient', 'At most messages.perMinute per sender, messages.maxLength characters'],
      auth: { roles: ['maintainer'] },
    },
  },
})

const ClanTiers = defineEntity({
  tags: ['world-system'],
  description:
    'A clan\'s tier, from every building it owns wherever it stands, weighed by how durable and how rare each ' +
    'block\'s material is. It rises as the clan builds and falls when its buildings are dismantled or ' +
    'destroyed. A tier gives nothing yet.',
  goal: 'Make a clan\'s standing the sum of what it has built (SkillsGrowFromWork, Phase 203)',
  fields: {
    id:    { type: 'uuid', primaryKey: true },
    rules: { type: 'json', description: 'Tier table: { durabilityUnit, rarityWeight: { <rarity>: weight }, tiers: [{ tier, minScore }], gives } (validated at fabric load)', defaultValue: TIERS },
  },
  relations: {
    clan:     { name: 'clan',     kind: 'hasOne', target: 'Clan' },
    decision: { name: 'decision', kind: 'hasOne', target: 'SkillsGrowFromWork' },
  },
  behaviors: {
    score: {
      description: 'Sum, over every block of every structure the clan owns, durability / durabilityUnit × rarityWeight',
      rules: ['Computed by the host from its structure index, never from a client message', 'The tier is the highest whose minScore the score meets'],
      auth: { roles: ['maintainer'] },
    },
  },
})

module.exports = { CLAN, TIERS, clanData, clanRefs, clanProblems, validateClan, Clan, ClanTiers }
