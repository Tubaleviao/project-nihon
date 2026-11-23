const { defineEntity } = require('@newel/core')

// Phase 226 — several characters per player. Until now a player id was one character: the registry, the creation
// record, inventory, skills, attributes, research, clan membership and owned structures all keyed on it. This
// splits the PLAYER (the account: who connects) from the CHARACTER (who walks the world). A player keeps a short
// list of characters on each server; each new one starts from scratch and copies nothing from its siblings.
//
// OWNERSHIP      { <field>: 'character' | 'player' }: who owns each piece of per-player state. Everything that is
//                progress in the world (body, name, pack, gear, skills, attributes, research, books, clan, owned
//                structures, spawn bed…) is the character's; only who the person is (friend code, settings, the
//                admin flag, which character they played last) is the player's.
// RECORD_KEYS    { <key of today's per-player save record>: <OWNERSHIP field> }: where each key of the record the
//                runtime writes today (PlayerRegistry) goes once characters exist. The runtime PR moves every key
//                whose field is the character's into the character's record.
// LIMIT          characters one player may keep on one server. The host refuses a new character over it.
// ON_DELETE      what happens to the structures a deleted character owned: 'clan' gives each to the character's
//                clan (when it is in one; a structure of a clanless character becomes ownerless), 'ownerless'
//                leaves every one ownerless, to decay as abandoned structures do.
// NAMES          names are unique per server across ALL characters of all players (the creation `name_taken`
//                rule): two characters of one player cannot share a name either.
// DELETE_CONFIRM the player types the character's name to delete it; the host compares it (never the client).
// MIGRATION      a save from before Phase 226 has one record per player id: it becomes that player's first
//                character, with every character field unchanged, and the player's fields move to the player.
// REFUSALS       the locale keys the host refuses with; the client renders them in the reader's locale.
//
// The host decides everything: it sends a player's character list (name, body, last played) after the player
// chooses a world or joins a server, and the client never decides which characters exist.

const OWNERS = ['character', 'player']

const OWNERSHIP = {
  // The character: everything that is progress in this world.
  body:            'character',   // gender, hair, hair colour (the creation record) and the appearance
  name:            'character',
  hp:              'character',
  position:        'character',
  statusEffects:   'character',
  attributes:      'character',
  attributeGrowth: 'character',
  inventory:       'character',
  equipment:       'character',
  skills:          'character',
  skillXp:         'character',
  skillFocus:      'character',
  professions:     'character',
  titles:          'character',
  cooldowns:       'character',
  craftCounter:    'character',
  research:        'character',   // technology: discovered again by each character
  booksLearned:    'character',
  tamingFlags:     'character',
  companions:      'character',
  waystones:       'character',
  clanMembership:  'character',
  ownedStructures: 'character',
  spawnBed:        'character',
  // The player: who the person is, the same for every character.
  friendCode:      'player',
  settings:        'player',
  admin:           'player',
  lastCharacter:   'player',
}

// Fields that must be the character's: putting any on the player would let a second character inherit progress.
const CHARACTER_FIELDS = [
  'body', 'name', 'inventory', 'equipment', 'skills', 'skillXp', 'attributes', 'research', 'booksLearned',
  'clanMembership', 'ownedStructures', 'spawnBed',
]
// Fields that must be the player's: they say who connects, not what a character did.
const PLAYER_FIELDS = ['friendCode', 'settings', 'admin']

const RECORD_KEYS = {
  position:          'position',
  hp:                'hp',
  respawn_deadline:  'hp',
  status_effects:    'statusEffects',
  appearance:        'body',
  creation:          'body',
  technology:        'research',
  flags:             'tamingFlags',
  waystones:         'waystones',
  companions:        'companions',
  professions:       'professions',
  titles:            'titles',
  craft_counter:     'craftCounter',
  skills:            'skills',
  skill_xp:          'skillXp',
  skill_focus:       'skillFocus',
  attributes:        'attributes',
  attribute_growth:  'attributeGrowth',
  cooldowns:         'cooldowns',
  equipment:         'equipment',
  spawn:             'spawnBed',
  bed:               'spawnBed',
  inventory:         'inventory',
  inventory_durability: 'inventory',
}

const LIMIT = 4
const LIMIT_RANGE = [1, 16]
const ON_DELETE_CHOICES = ['clan', 'ownerless']
const ON_DELETE = 'clan'
const NAMES = 'server'
const DELETE_CONFIRM = 'name'
const MIGRATION = 'firstCharacter'

const REFUSALS = {
  limit:        'characters.refuse.limit',
  nameTaken:    'creation.refuse.name_taken',
  confirm:      'characters.refuse.confirm',
  unknown:      'characters.refuse.unknown',
  rateLimited:  'characters.refuse.rate_limited',
}

function characterRosterData() {
  return {
    owners: OWNERS.slice(),
    ownership: { ...OWNERSHIP },
    characterFields: CHARACTER_FIELDS.slice(),
    playerFields: PLAYER_FIELDS.slice(),
    recordKeys: { ...RECORD_KEYS },
    limit: LIMIT,
    limitRange: LIMIT_RANGE.slice(),
    onDelete: ON_DELETE,
    names: NAMES,
    deleteConfirm: DELETE_CONFIRM,
    migration: MIGRATION,
    refusals: { ...REFUSALS },
  }
}

const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)

function characterRosterProblems(d) {
  const p = []
  if (!isObj(d.ownership)) return ['ownership must be { field: owner }']
  for (const [f, owner] of Object.entries(d.ownership)) {
    if (!OWNERS.includes(owner)) p.push(`ownership.${f}: "${owner}" is not one of ${OWNERS.join(', ')}`)
  }
  for (const f of CHARACTER_FIELDS) {
    if (!Object.hasOwn(d.ownership, f)) p.push(`ownership has no ${f}: it must be the character's`)
    else if (d.ownership[f] !== 'character') p.push(`${f} is on the ${d.ownership[f]}, not the character: a new character would inherit it`)
  }
  for (const f of PLAYER_FIELDS) {
    if (!Object.hasOwn(d.ownership, f)) p.push(`ownership has no ${f}: it must be the player's`)
    else if (d.ownership[f] !== 'player') p.push(`${f} is on the ${d.ownership[f]}, not the player`)
  }
  if (!isObj(d.recordKeys)) p.push('recordKeys must be { record key: ownership field }')
  else {
    for (const [k, f] of Object.entries(d.recordKeys)) {
      if (!Object.hasOwn(d.ownership, f)) p.push(`recordKeys.${k}: "${f}" is not an ownership field`)
    }
    for (const k of Object.keys(RECORD_KEYS)) {
      if (!Object.hasOwn(d.recordKeys, k)) p.push(`recordKeys has no ${k}: every key of the save record needs an owner`)
    }
  }
  if (!Number.isInteger(d.limit) || d.limit < LIMIT_RANGE[0] || d.limit > LIMIT_RANGE[1]) {
    p.push(`limit must be an integer from ${LIMIT_RANGE[0]} to ${LIMIT_RANGE[1]}, got ${d.limit}`)
  }
  if (!ON_DELETE_CHOICES.includes(d.onDelete)) p.push(`onDelete must be one of ${ON_DELETE_CHOICES.join(', ')}, got ${d.onDelete}`)
  if (d.names !== 'server') p.push(`names must be unique per server ("server"), got ${d.names}`)
  if (d.deleteConfirm !== 'name') p.push(`deleteConfirm must be "name" (the player types the character's name), got ${d.deleteConfirm}`)
  if (d.migration !== 'firstCharacter') p.push(`migration must be "firstCharacter", got ${d.migration}`)
  if (!isObj(d.refusals)) p.push('refusals must be { reason: locale key }')
  else {
    for (const k of Object.keys(REFUSALS)) {
      if (typeof d.refusals[k] !== 'string' || !/^[a-z_]+\.[a-z_.]+$/.test(d.refusals[k])) p.push(`refusals.${k} must be a locale key`)
    }
  }
  return p
}

function validateCharacterRoster(d) {
  const problems = characterRosterProblems(d)
  if (problems.length) throw new Error('CharacterRoster is invalid:\n  ' + problems.join('\n  '))
}

const fieldsOf = (owner) => Object.keys(OWNERSHIP).filter((f) => OWNERSHIP[f] === owner)

const CharacterRoster = defineEntity({
  tags: ['world-system'],
  description:
    'Several characters per player (Phase 226). The player is the account that connects; a character is who walks ' +
    'the world. A player keeps up to ' + LIMIT + ' characters on a server, picked from a list after choosing a world ' +
    'or joining a server. A new character starts from scratch: no items, base attributes, no skills, research, ' +
    'books or clan, and nothing from the player\'s other characters. Names are unique on the server across every ' +
    'character. Deleting a character asks for its name typed out; its structures go to its clan, or become ' +
    'ownerless when it had none. The character owns: ' + fieldsOf('character').join(', ') + '. The player owns: ' +
    fieldsOf('player').join(', ') + '.',
  goal: 'A player can start over as someone new without losing the character they already have',
  fields: {
    id:              { type: 'uuid', primaryKey: true },
    ownership:       { type: 'json', description: '{ <field>: "character" | "player" }: who owns each piece of per-player state', defaultValue: OWNERSHIP },
    characterFields: { type: 'json', description: 'Fields that must be the character\'s (a new character would otherwise inherit them)', defaultValue: CHARACTER_FIELDS },
    playerFields:    { type: 'json', description: 'Fields that must be the player\'s', defaultValue: PLAYER_FIELDS },
    recordKeys:      { type: 'json', description: '{ <key of the pre-Phase-226 player save record>: <ownership field> }: where each key moves', defaultValue: RECORD_KEYS },
    limit:           { type: 'integer', description: 'Characters one player may keep on one server; the host refuses one over it', defaultValue: LIMIT },
    onDelete:        { type: 'string', description: 'A deleted character\'s structures: "clan" (to its clan, ownerless without one) or "ownerless"', defaultValue: ON_DELETE },
    names:           { type: 'string', description: 'Name uniqueness scope: "server", across every character of every player', defaultValue: NAMES },
    deleteConfirm:   { type: 'string', description: 'What the player types to delete a character: "name", its name, checked by the host', defaultValue: DELETE_CONFIRM },
    migration:       { type: 'string', description: 'A pre-Phase-226 save: "firstCharacter", each player\'s one record becomes their first character, unchanged', defaultValue: MIGRATION },
    refusals:        { type: 'json', description: 'Locale keys the host refuses with: { limit, nameTaken, confirm, unknown, rateLimited }', defaultValue: REFUSALS },
  },
  behaviors: {
    listCharacters: {
      description: 'Send a player the list of their characters on this server',
      rules: [
        'The host sends the list after the player chooses a local world or joins a server: name, body, last played',
        'The client never decides which characters exist; it shows what the host sent',
      ],
      auth: { roles: ['maintainer'] },
    },
    createCharacter: {
      description: 'Create a new character for a player through the creation screen',
      rules: [
        'Refused over the character limit (refusals.limit)',
        'Refused when any character on the server has the name or one that looks like it (refusals.nameTaken)',
        'The new character has an empty pack, base attributes, no skills, research, books, clan or structures',
        'Nothing is copied from the player\'s other characters',
      ],
      auth: { roles: ['maintainer'] },
    },
    playCharacter: {
      description: 'Enter the world as one of the player\'s characters',
      rules: [
        'Only a character of the connecting player can be entered (refusals.unknown)',
        'The player\'s lastCharacter becomes that character',
      ],
      auth: { roles: ['maintainer'] },
    },
    deleteCharacter: {
      description: 'Delete one of the player\'s characters',
      rules: [
        'The player types the character\'s name; the host compares it and refuses a mismatch (refusals.confirm)',
        'Its structures go to its clan, or become ownerless when it has none (onDelete)',
        'Its name is free again for any new character on the server',
      ],
      auth: { roles: ['maintainer'] },
    },
    migrateSave: {
      description: 'Load a save written before Phase 226',
      rules: [
        'Each player record becomes that player\'s first character, every character field unchanged',
        'The player fields move to the player; the first character is the player\'s lastCharacter',
      ],
      auth: { roles: ['maintainer'] },
    },
  },
})

// The account a person connects as (Phase 226): the same on every character it plays.
const Player = defineEntity({
  tags: ['player'],
  description:
    'The account that connects to a server. It owns who the person is (friend code, settings, the admin flag, the ' +
    'character played last) and a list of characters (CharacterRoster); all progress in the world is the ' +
    'character\'s (PlayerCharacter).',
  goal: 'Separate who connects from who walks the world, so one person can keep several characters',
  fields: {
    id:            { type: 'uuid', primaryKey: true },
    friendCode:    { type: 'string', description: 'The code a friend types to join this player\'s world' },
    settings:      { type: 'json', description: 'Client settings (sound, graphics, language, tutorial); kept on this player\'s machine' },
    admin:         { type: 'boolean', description: 'Whether the host lets this player use admin commands', defaultValue: false },
    lastCharacter: { type: 'string', description: 'Id of the character this player entered last, offered first in the list' },
  },
})

module.exports = {
  OWNERS, OWNERSHIP, CHARACTER_FIELDS, PLAYER_FIELDS, RECORD_KEYS, LIMIT, LIMIT_RANGE, ON_DELETE_CHOICES, ON_DELETE,
  REFUSALS, characterRosterData, characterRosterProblems, validateCharacterRoster, CharacterRoster, Player,
}
