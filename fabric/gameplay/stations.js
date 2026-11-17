const { defineEntity } = require('@newel/core')

// Phase 268 — every placeable station type is made, carried and placed from the hotbar. One placement consumes
// the type's `placementItem` (an item tagged `station`), and its owner can pick the placed station up again to
// get the item back. The rule ChestsAndDoors applied to chests and doors (Phase 208) now covers every type.
//
// `first`       the station a newcomer makes first: its item's recipe needs no station and takes only
//               `handInputs` (what the newcomer grounds lay on the ground: StoneTools.inputs).
// `handInputs`  the items the first station is made from.
// `pickUp`      a placed station's owner picks it up within `reachMetres` and gets its item back. A chest keeps
//               ChestsAndDoors' `spillsOnDestroy`: picking one up spills what it holds.
// `stations`    station type -> { placementItem }. It lists every placeable type (a recipe's or a repair's
//               station, the waystone, the hearth, the bed, the chest and the door) and agrees with the
//               waystone, bed, hearth and chest rows that name their own item.
//
// The chain: starting from the hand-made first station, every other station's item is crafted at a station
// already reachable, from inputs that are raw or crafted at a reachable station. A station recipe that needs no
// station (the bed, the chest, the door) must take at least one crafted input, so only the first is made from
// raw goods by hand.
const STATIONS = {
  first: 'carpentry bench',
  handInputs: ['Branch', 'LooseStone'],
  pickUp: { reachMetres: 4, ownerOnly: true },
  stations: {
    'carpentry bench':        { placementItem: 'CarpentryBench' },
    forge:                    { placementItem: 'Forge' },
    'masonry bench':          { placementItem: 'MasonryBench' },
    'alchemy bench':          { placementItem: 'AlchemyBench' },
    'master forge':           { placementItem: 'MasterForge' },
    'arcane forge':           { placementItem: 'ArcaneForge' },
    'void-shielded workshop': { placementItem: 'VoidShieldedWorkshop' },
    waystone:                 { placementItem: 'Waystone' },
    hearth:                   { placementItem: 'Hearth' },
    bed:                      { placementItem: 'Bed' },
    chest:                    { placementItem: 'Chest' },
    door:                     { placementItem: 'Door' },
  },
}

const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
const def = (e, field) => (e && e.fields && e.fields[field] ? e.fields[field].defaultValue : undefined)

function stationsData() { return JSON.parse(JSON.stringify(STATIONS)) }

/** The fabric's items, recipes and placeable station types, in the plain shape the validator reads. */
function stationsRefs() {
  const items = require('./items')
  const settlement = require('./settlement')
  const recipes = require('./recipes')
  const allItems = { ...items, Hearth: settlement.Hearth }
  const recipeRows = {}
  for (const [k, e] of Object.entries({ ...recipes, RecipeHearth: settlement.RecipeHearth })) {
    const r = def(e, 'recipe')
    if (r) recipeRows[k] = r
  }
  const tagged = Object.entries(allItems).filter(([, e]) => e && (e.tags || []).includes('station')).map(([k]) => k)
  const own = {   // the types whose own rule names their item
    [require('./waystone').TRAVEL.stationType]: require('./waystone').TRAVEL.placementItem,
    [settlement.RULES.hearthStation]: settlement.RULES.hearthItem,
    [require('./bed').RULES.stationType]: require('./bed').RULES.placementItem,
  }
  for (const [t, s] of Object.entries(require('./chests').CHESTS_AND_DOORS.stations)) own[t] = s.placementItem
  const types = new Set(require('./tutorial').tutorialRefs().stationTypes)
  for (const t of Object.keys(own)) types.add(t)
  return {
    stationItems: tagged,
    goods: [...Object.keys(allItems), ...Object.keys(require('../world/materials'))],
    recipes: recipeRows,
    stationTypes: [...types].sort(),
    ownItems: own,
    handInputs: require('./stone_tools').stoneToolsData().inputs,
  }
}

/** Problems with the station placement table, as strings. */
function stationsProblems(d, refs) {
  const p = []
  const st = isObj(d.stations) ? d.stations : {}
  for (const t of refs.stationTypes) if (!isObj(st[t])) p.push(`StationPlacement.stations["${t}"] is missing: a placeable station type with no placement item`)
  const byItem = {}
  for (const [t, row] of Object.entries(st)) {
    if (!refs.stationTypes.includes(t)) p.push(`StationPlacement.stations["${t}"] is no placeable station type`)
    if (!isObj(row)) continue
    const item = row.placementItem
    if (!refs.stationItems.includes(item)) { p.push(`StationPlacement.stations["${t}"].placementItem "${item}" is not an item tagged station`); continue }
    if (byItem[item]) p.push(`StationPlacement.stations["${t}"].placementItem "${item}" places two station types`)
    byItem[item] = t
    if (t in refs.ownItems && refs.ownItems[t] !== item) p.push(`StationPlacement.stations["${t}"].placementItem "${item}" disagrees with its own rule ("${refs.ownItems[t]}")`)
  }
  const makers = (item) => Object.entries(refs.recipes).filter(([, r]) => (r.outputs || []).some((o) => o.item === item))
  for (const [item, t] of Object.entries(byItem)) if (makers(item).length === 0) p.push(`StationPlacement.stations["${t}"]: no recipe makes its placement item "${item}"`)
  // The first station: hand-made from the newcomer grounds' goods.
  const hand = Array.isArray(d.handInputs) ? d.handInputs : []
  if (JSON.stringify([...hand].sort()) !== JSON.stringify([...(refs.handInputs || [])].sort())) p.push(`StationPlacement.handInputs must be what the newcomer grounds lay out: ${(refs.handInputs || []).join(', ')}`)
  for (const i of hand) if (!refs.goods.includes(i)) p.push(`StationPlacement.handInputs: "${i}" is not an item`)
  if (!isObj(st[d.first])) p.push(`StationPlacement.first "${d.first}" is not a station in the table`)
  else {
    const firstItem = st[d.first].placementItem
    const handMade = makers(firstItem).some(([, r]) => !r.station && (r.inputs || []).every((i) => hand.includes(i.item)))
    if (!handMade) p.push(`StationPlacement.first "${d.first}": no recipe makes "${firstItem}" by hand from ${hand.join(', ')}`)
  }
  // The chain from the first station: a good is obtainable when no recipe makes it (raw), or a recipe makes it at a
  // reachable station (or by hand) from obtainable inputs; a station is reachable when its item is obtainable.
  const outputs = new Set(Object.values(refs.recipes).flatMap((r) => (r.outputs || []).map((o) => o.item)))
  const have = new Set(refs.goods.filter((g) => !outputs.has(g)))
  const reach = new Set()
  for (let changed = true; changed;) {
    changed = false
    for (const r of Object.values(refs.recipes)) {
      if (r.station && !reach.has(r.station)) continue
      if (!(r.inputs || []).every((i) => have.has(i.item))) continue
      for (const o of r.outputs || []) if (!have.has(o.item)) { have.add(o.item); changed = true }
    }
    for (const [t, row] of Object.entries(st)) if (isObj(row) && have.has(row.placementItem) && !reach.has(t)) { reach.add(t); changed = true }
  }
  for (const t of Object.keys(st)) if (refs.stationTypes.includes(t) && !reach.has(t)) p.push(`StationPlacement.stations["${t}"] cannot be reached from the ${d.first}: its item needs a station or a good no earlier station gives`)
  // Only the first station is made by hand from raw goods alone.
  for (const [item, t] of Object.entries(byItem)) {
    if (t === d.first) continue
    for (const [rk, r] of makers(item)) {
      if (!r.station && (r.inputs || []).every((i) => !outputs.has(i.item))) p.push(`${rk}: a station other than the ${d.first} is built at an earlier station or from crafted goods, not by hand from raw goods`)
    }
  }
  const pu = isObj(d.pickUp) ? d.pickUp : {}
  if (!(typeof pu.reachMetres === 'number' && pu.reachMetres > 0 && pu.reachMetres <= 8)) p.push('StationPlacement.pickUp.reachMetres must be in (0, 8]')
  if (pu.ownerOnly !== true) p.push('StationPlacement.pickUp.ownerOnly must be true: only a station\'s owner picks it up')
  return p
}

function validateStations(d, refs) {
  const problems = stationsProblems(d, refs)
  if (problems.length) throw new Error('Station placement rules are invalid:\n  ' + problems.join('\n  '))
}

const StationPlacement = defineEntity({
  tags: ['world-system'],
  description:
    'Every station is an item: crafted (the first by hand, the rest at an earlier station), carried in the pack, ' +
    'placed from the hotbar and picked up again by its owner.',
  goal: 'No free stations and no shortcut keys: a station is made before it is placed (Phase 268)',
  fields: {
    id:    { type: 'uuid', primaryKey: true },
    rules: { type: 'json', description: 'Station placement table: { first, handInputs, pickUp, stations } (validated at fabric load)', defaultValue: STATIONS },
  },
  behaviors: {
    place: {
      description: 'Place the station item in the selected hotbar slot at the aimed spot',
      rules: ['The host consumes one placement item and refuses without it', 'The rotation travels with the request'],
      auth: { roles: ['maintainer'] },
    },
    pickUp: {
      description: 'Pick a placed station up again',
      rules: ['Only its owner, within reach', 'The item goes back to the owner\'s pack', 'A chest spills what it holds'],
      auth: { roles: ['maintainer'] },
    },
  },
})

module.exports = { STATIONS, stationsData, stationsRefs, stationsProblems, validateStations, StationPlacement }
