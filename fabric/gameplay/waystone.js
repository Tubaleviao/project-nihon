const { defineEntity } = require('@newel/core')

// Phase 125 — waystones. A player attunes to a waystone by standing at it, and may travel between two
// stones they are attuned to. The runtime reads this table from GameData.WORLD_SYSTEMS["WaystoneTravel"].
//
// `attuneRadius`: metres within which a player may attune to, or depart from, a stone.
// `cooldownSeconds`: wall-clock seconds between two travels by one player.
// `costItem` / `costPerThousandKm`: item paid per 1,000 km travelled (rounded up, at least 1).
// `placementItem`: the item one placement of a stone consumes (placement-cost policy for stations: a
// station type consumes an item only when the fabric names one here; forges and benches stay free).
const TRAVEL = {
  stationType: 'waystone',
  attuneRadius: 4,
  cooldownSeconds: 30,
  costItem: 'AethermiteShard',
  costPerThousandKm: 1,
  placementItem: 'Waystone',
}

const MAX_RADIUS = 64
const MAX_COOLDOWN = 86400
const MAX_COST = 1000

/** Problems with a travel rule table, as strings. `itemKeys` (optional) lists valid item keys. */
function travelProblems(rules, itemKeys) {
  const problems = []
  const known = ['stationType', 'attuneRadius', 'cooldownSeconds', 'costItem', 'costPerThousandKm', 'placementItem']
  if (typeof rules.stationType !== 'string' || rules.stationType === '') problems.push('WaystoneTravel.stationType must be a non-empty string')
  if (typeof rules.attuneRadius !== 'number' || !(rules.attuneRadius > 0) || rules.attuneRadius > MAX_RADIUS) problems.push(`WaystoneTravel.attuneRadius must be in (0, ${MAX_RADIUS}], got ${rules.attuneRadius}`)
  if (!Number.isInteger(rules.cooldownSeconds) || rules.cooldownSeconds < 0 || rules.cooldownSeconds > MAX_COOLDOWN) problems.push(`WaystoneTravel.cooldownSeconds must be an integer in 0..${MAX_COOLDOWN}, got ${rules.cooldownSeconds}`)
  if (!Number.isInteger(rules.costPerThousandKm) || rules.costPerThousandKm < 0 || rules.costPerThousandKm > MAX_COST) problems.push(`WaystoneTravel.costPerThousandKm must be an integer in 0..${MAX_COST}, got ${rules.costPerThousandKm}`)
  if (typeof rules.costItem !== 'string' || rules.costItem === '') problems.push('WaystoneTravel.costItem must be a non-empty string')
  else if (itemKeys && !itemKeys.includes(rules.costItem)) problems.push(`WaystoneTravel.costItem "${rules.costItem}" is not a defined item`)
  if (typeof rules.placementItem !== 'string') problems.push('WaystoneTravel.placementItem must be a string ("" for a free placement)')
  else if (rules.placementItem !== '' && itemKeys && !itemKeys.includes(rules.placementItem)) problems.push(`WaystoneTravel.placementItem "${rules.placementItem}" is not a defined item`)
  for (const key of Object.keys(rules)) if (!known.includes(key)) problems.push(`WaystoneTravel has unknown field "${key}"`)
  return problems
}

function validateTravel(rules, itemKeys) {
  const problems = travelProblems(rules, itemKeys)
  if (problems.length) throw new Error('Waystone travel rule is invalid:\n  ' + problems.join('\n  '))
}

const WaystoneTravel = defineEntity({
  tags: ['world-system'],
  description:
    'Fast travel between waystones: a player attunes to a stone by standing at it, then travels between ' +
    'two attuned stones for a cost in items per 1,000 km, once per cooldown.',
  goal: 'Make a planet that takes about 90 days to walk around navigable without removing the journey',
  fields: {
    id: { type: 'uuid', primaryKey: true },
    rules: {
      type: 'json',
      description: 'Travel rule: { stationType, attuneRadius (m), cooldownSeconds, costItem, costPerThousandKm, placementItem } (validated at fabric load)',
      defaultValue: TRAVEL,
    },
  },
  behaviors: {
    attune: {
      description: 'Record that the player knows this waystone, by standing within the attune radius',
      rules: ['Host-validated; attunement is stored on the player record'],
      auth: { roles: ['maintainer'] },
    },
    travel: {
      description: 'Teleport between two attuned waystones, paying the item cost',
      rules: [
        'The player is within the attune radius of the departure stone and attuned to both',
        'Both stones still exist and the cooldown has elapsed',
        'The cost is paid from the inventory; a refusal tells the owner why',
      ],
      auth: { roles: ['maintainer'] },
    },
  },
})

module.exports = { TRAVEL, WaystoneTravel, travelProblems, validateTravel }
