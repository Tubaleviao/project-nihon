const { defineEntity } = require('@newel/core')

// Phase 203 — chests and doors. Each has an access mode its owner sets: `owner` (the owner alone; for a clan
// chest any member), `clan` (any member of the owner's clan) or `everyone`. A locked one can be broken open
// (StructureDurability) or picked (Lockpicking). Phase 208 reads this from GameData.WORLD_SYSTEMS["ChestsAndDoors"]
// and adds the placeable stations.
//
// `accessModes`, `defaultMode`, `setBy` (always `owner`).
// `stations`  station -> { capacityStacks?, spillsOnDestroy? }: a destroyed chest spills its contents for anyone.
// `locks`     a lock's difficulty = `materials[lock material]` × `technologies[the owner's best lock technology]`
//             (`none` when they know none of them). Its durability = the material's durability ×
//             `durabilityFactor` × the same technology multiplier. A pick takes `pickSeconds` × difficulty,
//             shortened by (1 − `skillSpeedup` × Lockpicking level / levelCap); a failed pick breaks the tool
//             with `breakChance` / difficulty… capped at 1, and the owner is told.
const CHESTS_AND_DOORS = {
  accessModes: ['owner', 'clan', 'everyone'],
  defaultMode: 'owner',
  setBy: 'owner',
  stations: {
    chest: { capacityStacks: 20, spillsOnDestroy: true },
    door:  {},
  },
  locks: {
    materials: { Thornwood: 1, Duskfiber: 1.5, Ashite: 2, Ferrite: 3, Aethermite: 4, Veilsteel: 6, Voidite: 8 },
    technologies: { none: 1, TechBasicCarpentry: 1.25, TechBasicSmithing: 1.5, TechMasterForge: 2.5 },
    durabilityFactor: 2,
    pickSeconds: 6,
    skillSpeedup: 0.6,
    breakChance: 0.3,
  },
}

const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
const isNum = (v) => typeof v === 'number' && Number.isFinite(v)

function chestsData() { return JSON.parse(JSON.stringify(CHESTS_AND_DOORS)) }

function chestsRefs() {
  const tagged = (table, tag) => Object.entries(table).filter(([, e]) => e && (e.tags || []).includes(tag)).map(([k]) => k)
  return { materials: tagged(require('../world/materials'), 'material'), technologies: tagged(require('./technology'), 'technology') }
}

/** Problems with the chest and door table, as strings. */
function chestsProblems(d, refs) {
  const p = []
  if (JSON.stringify(d.accessModes) !== JSON.stringify(['owner', 'clan', 'everyone'])) p.push('ChestsAndDoors.accessModes must be ["owner", "clan", "everyone"]')
  if (!(d.accessModes || []).includes(d.defaultMode)) p.push(`ChestsAndDoors.defaultMode "${d.defaultMode}" is not an access mode`)
  if (d.setBy !== 'owner') p.push('ChestsAndDoors.setBy must be "owner": only the owner changes a mode')
  const st = isObj(d.stations) ? d.stations : {}
  for (const k of ['chest', 'door']) if (!isObj(st[k])) p.push(`ChestsAndDoors.stations.${k} is missing`)
  if (st.chest) {
    if (!Number.isInteger(st.chest.capacityStacks) || st.chest.capacityStacks < 1) p.push('ChestsAndDoors.stations.chest.capacityStacks must be an integer >= 1')
    if (st.chest.spillsOnDestroy !== true) p.push('ChestsAndDoors.stations.chest.spillsOnDestroy must be true: a destroyed chest spills its contents to anyone')
  }
  const l = isObj(d.locks) ? d.locks : {}
  const mats = isObj(l.materials) ? l.materials : {}
  if (Object.keys(mats).length === 0) p.push('ChestsAndDoors.locks.materials must name at least one material')
  for (const [k, v] of Object.entries(mats)) {
    if (!refs.materials.includes(k)) p.push(`ChestsAndDoors.locks.materials: "${k}" is not a material`)
    if (!isNum(v) || v < 1) p.push(`ChestsAndDoors.locks.materials.${k} must be >= 1`)
  }
  const techs = isObj(l.technologies) ? l.technologies : {}
  if (techs.none !== 1) p.push('ChestsAndDoors.locks.technologies.none must be 1')
  for (const [k, v] of Object.entries(techs)) {
    if (k !== 'none' && !refs.technologies.includes(k)) p.push(`ChestsAndDoors.locks.technologies: "${k}" is not a technology`)
    if (!isNum(v) || v < 1) p.push(`ChestsAndDoors.locks.technologies.${k} must be >= 1`)
  }
  for (const k of ['durabilityFactor', 'pickSeconds']) if (!isNum(l[k]) || l[k] <= 0) p.push(`ChestsAndDoors.locks.${k} must be > 0`)
  if (!isNum(l.skillSpeedup) || l.skillSpeedup < 0 || l.skillSpeedup >= 1) p.push('ChestsAndDoors.locks.skillSpeedup must be in [0, 1): no lock opens instantly')
  if (!isNum(l.breakChance) || l.breakChance < 0 || l.breakChance > 1) p.push('ChestsAndDoors.locks.breakChance must be in [0, 1]')
  return p
}

function validateChests(d, refs) {
  const problems = chestsProblems(d, refs)
  if (problems.length) throw new Error('Chest and door rules are invalid:\n  ' + problems.join('\n  '))
}

const ChestsAndDoors = defineEntity({
  tags: ['world-system'],
  description:
    'Chests and doors open for their owner only, their clan or everyone, as the owner sets. A locked one can be ' +
    'destroyed or picked; how hard depends on its material and the owner\'s lock technology. A destroyed chest ' +
    'spills its contents for anyone to take.',
  goal: 'Keep a house and its things safe without making them unbreakable (DurabilityAndDestruction, Phase 203)',
  fields: {
    id:    { type: 'uuid', primaryKey: true },
    rules: { type: 'json', description: 'Chest and door table: { accessModes, defaultMode, setBy, stations, locks } (validated at fabric load)', defaultValue: CHESTS_AND_DOORS },
  },
  relations: {
    skill:    { name: 'skill',    kind: 'hasOne', target: 'Lockpicking' },
    decision: { name: 'decision', kind: 'hasOne', target: 'DurabilityAndDestruction' },
  },
  behaviors: {
    open: {
      description: 'Open, take from, put into or pass through',
      rules: ['The host checks the access mode on every open, take, put and pass', 'Only the owner changes the mode'],
      auth: { roles: ['maintainer'] },
    },
    pick: {
      description: 'Pick a lock with a tool',
      rules: ['Success opens it once', 'Failure can break the tool, and the owner is told'],
      auth: { roles: ['maintainer'] },
    },
  },
})

module.exports = { CHESTS_AND_DOORS, chestsData, chestsRefs, chestsProblems, validateChests, ChestsAndDoors }
