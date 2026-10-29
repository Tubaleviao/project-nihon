const { defineEntity } = require('@newel/core')

// Phase 184 — the bed and the shelter rule. A player crafts a Bed (items/furniture.js, RecipeBed) and
// places it through the station path as station type `bed`; Phase 185 makes the placed bed that
// player's spawn point. The runtime reads this table from GameData.WORLD_SYSTEMS["BedSpawn"].
//
// `stationType` / `placementItem`: the station type a bed places as, and the item one placement
//   consumes (the placement-cost policy WaystoneTravel.placementItem set in Phase 130).
// `perPlayer`: beds one player may own at a time (Phase 185 drops the older one back as an item).
// `notices`: catalog keys the host sends the owner (keys, never prose).
// `shelter`: one pure rule (src/world/shelter_rule.gd), read by the host (Phase 185) and by the
//   tutorial's `shelter_complete` trigger (Phase 186). A bed at height y is sheltered when
//   - a solid run in the bed's own tile starts above y and at most `roofWithinMetres` above it, and
//   - at least `minClosedSides` of the 4 sides (±x, ±z) are closed: walking out from the bed's tile on
//     that side, some tile within `sideReachMetres` is solid at height y + `wallCheckMetres` (a wall
//     at chest height, so a one-step lip does not count, but a hillside does).
const RULES = {
  stationType: 'bed',
  placementItem: 'Bed',
  perPlayer: 1,
  notices: { placed: 'bed.placed', lost: 'bed.lost' },
  shelter: { roofWithinMetres: 3.0, sideReachMetres: 2.0, minClosedSides: 3, wallCheckMetres: 1.0 },
}

const SIDES = 4
const MAX_REACH = 8   // metres; a wider shelter is a hall, not a bed's room

/** Problems with the bed rule, as strings. `itemKeys` lists valid item keys. */
function bedProblems(rules, itemKeys) {
  const p = []
  const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
  if (!isObj(rules)) return ['BedSpawn.rules must be an object']
  const known = ['stationType', 'placementItem', 'perPlayer', 'notices', 'shelter']
  for (const k of Object.keys(rules)) if (!known.includes(k)) p.push(`BedSpawn has unknown field "${k}"`)
  if (typeof rules.stationType !== 'string' || !/^[a-z][a-z ]*$/.test(rules.stationType)) p.push('BedSpawn.stationType must be a lower-case station type')
  if (typeof rules.placementItem !== 'string' || !itemKeys.includes(rules.placementItem)) p.push(`BedSpawn.placementItem "${rules.placementItem}" is not a defined item`)
  if (!(Number.isInteger(rules.perPlayer) && rules.perPlayer >= 1)) p.push(`BedSpawn.perPlayer must be an integer >= 1, got ${rules.perPlayer}`)
  if (!isObj(rules.notices)) p.push('BedSpawn.notices must be an object')
  else for (const [k, v] of Object.entries(rules.notices)) if (typeof v !== 'string' || !/^bed\.[a-z_]+$/.test(v)) p.push(`BedSpawn.notices.${k} must be a bed.* catalog key, got "${v}"`)
  const s = rules.shelter
  if (!isObj(s)) return [...p, 'BedSpawn.shelter must be an object']
  const num = (v) => typeof v === 'number' && Number.isFinite(v)
  if (!(num(s.roofWithinMetres) && s.roofWithinMetres > 0 && s.roofWithinMetres <= MAX_REACH)) p.push(`shelter.roofWithinMetres must be in (0, ${MAX_REACH}], got ${s.roofWithinMetres}`)
  if (!(num(s.sideReachMetres) && s.sideReachMetres > 0 && s.sideReachMetres <= MAX_REACH)) p.push(`shelter.sideReachMetres must be in (0, ${MAX_REACH}], got ${s.sideReachMetres}`)
  if (!(Number.isInteger(s.minClosedSides) && s.minClosedSides >= 1 && s.minClosedSides <= SIDES)) p.push(`shelter.minClosedSides must be an integer in 1..${SIDES}, got ${s.minClosedSides}`)
  if (!(num(s.wallCheckMetres) && s.wallCheckMetres > 0)) p.push(`shelter.wallCheckMetres must be > 0, got ${s.wallCheckMetres}`)
  else if (num(s.roofWithinMetres) && !(s.wallCheckMetres < s.roofWithinMetres)) p.push(`shelter.wallCheckMetres ${s.wallCheckMetres} must be below roofWithinMetres ${s.roofWithinMetres} (the wall is checked under the roof)`)
  for (const k of Object.keys(s)) if (!['roofWithinMetres', 'sideReachMetres', 'minClosedSides', 'wallCheckMetres'].includes(k)) p.push(`BedSpawn.shelter has unknown field "${k}"`)
  return p
}

function validateBed(rules, itemKeys) {
  const problems = bedProblems(rules, itemKeys)
  if (problems.length) throw new Error('Bed rule is invalid:\n  ' + problems.join('\n  '))
}

const BedSpawn = defineEntity({
  tags: ['world-system'],
  description:
    'A bed a player places becomes where they come back after death. One bed per player; the bed must be ' +
    'placed like a station, and a shelter rule says when the space around it is a roofed room.',
  goal: 'Give a new player a home in their first hour and a reason to build a shelter',
  fields: {
    id: { type: 'uuid', primaryKey: true },
    rules: {
      type: 'json',
      description: 'Bed rule: { stationType, placementItem, perPlayer, notices: { placed, lost }, ' +
        'shelter: { roofWithinMetres, sideReachMetres, minClosedSides, wallCheckMetres } } (validated at fabric load)',
      defaultValue: RULES,
    },
  },
  behaviors: {
    place: {
      description: 'Place a bed as a station; it becomes the owner\'s spawn point',
      rules: [
        'Placing consumes one Bed item',
        'A player owns at most perPlayer beds; a new one replaces the oldest',
      ],
      auth: { roles: ['maintainer'] },
    },
    shelter: {
      description: 'Decide whether a bed is sheltered',
      rules: [
        'A solid run starts above the bed and no more than roofWithinMetres above it',
        'At least minClosedSides of the four sides have solid material at wall height within sideReachMetres',
      ],
      auth: { roles: ['maintainer'] },
    },
  },
})

module.exports = { RULES, BedSpawn, bedProblems, validateBed }
