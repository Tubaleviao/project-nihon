const { defineEntity } = require('@newel/core')
const { SKILL_TIERS } = require('./skills/shared')

// Phase 229 — skills capped by the gear. Taken over from parked Phase 227 (its gear-gated-skills part only).
// A master swordsman with a novice sword fights like a novice; a master smith at a novice forge, or with a stone
// hammer, makes only novice goods. Gear is made in the world, so a strong character still climbs the gear ladder.
//
// Every tier is a skill tier (SKILL_TIERS). Three things carry one:
//   - equipment (every item with an equipmentCategory): its `tier` field, which must be its working part's
//     material tier (MATERIAL_TIERS), so a stone sword is never master gear;
//   - crafting stations (the placement item of every station type a recipe names): the item's `tier` field;
//   - combat abilities and recipes: a `requiredTier`, from ABILITIES below and from each recipe's json.
//
// FLOOR           the tier that needs no gear: empty hands and a missing tool count as FLOOR gear, so every
//                 novice ability and novice recipe stays usable with nothing in hand (nothing playable today is
//                 lost). A recipe made by hand (no station) is always FLOOR.
// MATERIAL_TIERS  { <material>: tier } for the working part of a piece of equipment (Equipment.WORKING_PARTS).
// STATION_TOOLS   { <station type>: <equipment category> | null }: the tool a recipe made at that station uses.
//                 null means the station needs no tool (an alchemy bench). The crafter's best tool of that
//                 category, held or in the pack, sets the tool tier.
// ABILITIES       { <combat skill>: { weapons: [category…], abilities: { <behavior>: requiredTier } } }. Every
//                 combat-skill behavior that says "Requires <Skill>: <Tier>" is listed; its requiredTier is that
//                 same tier (an advanced ability needs a weapon of its own tier), and FLOOR for a skill with no
//                 weapons (Unarmed: the body is the weapon). The equipped weapon must be of a listed category.
// REFUSALS        the localized reason keys the host sends when gear is below the tier.
//
// Hammers come in three tiers only (stone novice, ferrite apprentice, veilsteel master). So the journeyman arcane
// forge recipes and the expert void-shielded workshop one need the Veilsteel Hammer, which a smith makes at a master
// forge: an arcanist or void-smith trades for it or learns smithing. That dependency between professions is
// intended for now; journeyman and expert hammers (Aethermite, Voidite) are later content. The climb below checks
// the world as a whole (one character with every skill), not one profession's path.
//
// The host decides: combat from the skill tier and the equipped weapon's tier; crafting from the skill guards, the
// tool tier and the tier of the placed station, read from its own structure record. Skill XP grows with any gear;
// only use is capped.
//
// The validator also proves the ladder can be climbed: starting from bare hands, every recipe becomes craftable
// with tools and stations the ladder itself makes (no recipe is locked behind gear nobody can make), a recipe never
// asks for more gear than its skill guards' highest tier, and never more than its station's tier.

const FLOOR = 'novice'

const MATERIAL_TIERS = {
  Ashite:     'novice',
  Ferrite:    'apprentice',
  Aethermite: 'journeyman',
  Voidite:    'expert',
  Veilsteel:  'master',
}

const STATION_TOOLS = {
  'carpentry bench':        'axe',
  forge:                    'hammer',
  'masonry bench':          'hammer',
  'master forge':           'hammer',
  'arcane forge':           'hammer',
  'void-shielded workshop': 'hammer',
  'alchemy bench':          null,
}

const ABILITIES = {
  Swordsmanship: {
    weapons: ['knife', 'sword', 'greatsword'],
    abilities: { executePowerStrike: 'apprentice', executeCounterSlash: 'journeyman', executeWhirlwindBlade: 'expert' },
  },
  Archery: {
    weapons: ['bow'],
    abilities: { executeSteadyShot: 'apprentice', executeMultiShot: 'journeyman', executePierceShot: 'expert' },
  },
  Shieldcraft: {
    weapons: ['shield'],
    abilities: { executeParry: 'apprentice', executeShieldBash: 'journeyman', activateFortify: 'expert' },
  },
  Unarmed: {
    weapons: [],
    abilities: { executeDisarm: FLOOR, executeGrapple: FLOOR, executeKnockdown: FLOOR },
  },
}

const REFUSALS = {
  weapon:  'combat.refuse.weapon_tier',
  tool:    'craft.refuse.tool_tier',
  station: 'craft.refuse.station_tier',
}

const clone = (v) => JSON.parse(JSON.stringify(v))
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
const dv = (e, f) => (e && e.fields && e.fields[f] ? e.fields[f].defaultValue : undefined)
const rank = (t) => SKILL_TIERS.indexOf(t)

function gearTiersData() {
  return clone({
    tiers: SKILL_TIERS, floor: FLOOR, materialTiers: MATERIAL_TIERS, stationTools: STATION_TOOLS,
    abilities: ABILITIES, refusals: REFUSALS,
  })
}

/** The tier a behavior rule requires: "Requires Swordsmanship: Expert" -> 'expert'; null when none. */
function ruleTier(rule, skill) {
  const m = /^Requires ([^:]+): (\w+)$/.exec(rule)
  if (!m || m[1] !== skill) return null
  const t = m[2].toLowerCase()
  return SKILL_TIERS.includes(t) ? t : null
}

/** The fabric's equipment, stations, recipes and combat skills, in the plain shape the validator reads. */
function gearTiersRefs() {
  const equipment = require('./equipment')
  const items = require('./items')
  const settlement = require('./settlement')
  const specs = equipment.itemSpecs(items)
  const out = { equipment: {}, stationItems: {}, placement: {}, recipes: {}, combatSkills: {}, categories: Object.keys(equipment.CATEGORIES), materials: Object.keys(require('../world/materials')) }
  for (const [k, s] of Object.entries(specs)) {
    if (s.category !== undefined) out.equipment[k] = { category: s.category, material: s.material, tier: dv(items[k], 'tier') }
  }
  for (const [k, e] of Object.entries(items)) {
    if ((e.tags || []).includes('station')) out.stationItems[k] = { tier: dv(e, 'tier'), declared: Object.hasOwn(e.fields || {}, 'tier') }
  }
  for (const [t, row] of Object.entries(require('./stations').STATIONS.stations)) out.placement[t] = row.placementItem
  // Recipes live in ./recipes and settlement (the hearth); tools/check_gear_tiers.js proves this set is every
  // recipe-tagged entity in the fabric, so a recipe added elsewhere cannot skip these checks.
  for (const [k, e] of Object.entries({ ...require('./recipes'), ...settlement })) {
    if (!e || !(e.tags || []).includes('recipe')) continue
    const r = dv(e, 'recipe')
    if (r) out.recipes[k] = clone(r)
  }
  for (const [k, e] of Object.entries(require('./skills'))) {
    if (!e || !(e.tags || []).includes('skill') || dv(e, 'category') !== 'combat') continue
    const behaviors = {}
    for (const [b, def] of Object.entries(e.behaviors || {})) {
      if (b === 'advanceTier') continue
      // Every other behavior of a combat skill is an ability; null when no rule names its tier.
      behaviors[b] = (def.rules || []).map((r) => ruleTier(r, k)).find((x) => x) || null
    }
    out.combatSkills[k] = behaviors
  }
  return out
}

/** { <station type>: tier } for every station type some recipe names, read off its placement item. */
function stationTiers(refs) {
  const out = {}
  for (const r of Object.values(refs.recipes)) {
    const st = r.station || ''
    if (!st || st in out) continue
    const item = refs.placement[st]
    out[st] = item && refs.stationItems[item] ? refs.stationItems[item].tier : undefined
  }
  return out
}

/** The recipes craftable when climbing from bare hands, and the gear the climb reaches. */
function climb(d, refs) {
  const stTiers = stationTiers(refs)
  const tools = {}       // category -> best tier rank reached
  const stations = new Set()
  const craftable = new Set()
  const toolOk = (r) => {
    if (r.requiredTier === d.floor) return true
    const cat = d.stationTools[r.station || '']
    if (cat === null) return true
    // An unknown station (cat undefined) is rejected before the climb runs; kept so climb() is safe on its own.
    return cat !== undefined && (tools[cat] ?? -1) >= rank(r.requiredTier)
  }
  let changed = true
  while (changed) {
    changed = false
    for (const [k, r] of Object.entries(refs.recipes)) {
      if (craftable.has(k)) continue
      const st = r.station || ''
      if (st && !stations.has(st)) continue
      // Also rejected before the climb; kept so climb() is safe on its own (it is exported).
      if (st && !(rank(stTiers[st]) >= rank(r.requiredTier))) continue
      if (!toolOk(r)) continue
      craftable.add(k); changed = true
      for (const o of r.outputs || []) {
        const eq = refs.equipment[o.item]
        if (eq && rank(eq.tier) >= 0) tools[eq.category] = Math.max(tools[eq.category] ?? -1, rank(eq.tier))
        for (const [t, item] of Object.entries(refs.placement)) if (item === o.item) stations.add(t)
      }
    }
  }
  return { craftable, tools, stations }
}

/** Combat abilities no equipment of the skill's weapons reaches yet: { "<Skill>.<ability>": tier }. Content gaps,
 *  not errors: the ability is refused until a weapon of its tier exists. */
function abilityGaps(d = gearTiersData(), refs = gearTiersRefs()) {
  const out = {}
  for (const [skill, row] of Object.entries(d.abilities)) {
    for (const [a, t] of Object.entries(row.abilities || {})) {
      if (t === d.floor) continue
      const ok = Object.values(refs.equipment).some((e) => row.weapons.includes(e.category) && rank(e.tier) >= rank(t))
      if (!ok) out[`${skill}.${a}`] = t
    }
  }
  return out
}

/** Problems with the gear tier tables, the items' and stations' tiers and the recipes' required tiers. */
function gearTiersProblems(d, refs) {
  const p = []
  const tierOk = (where, t) => {
    if (!d.tiers.includes(t)) { p.push(`${where}: tier "${t}" is not a skill tier (${d.tiers.join(', ')})`); return false }
    return true
  }
  if (JSON.stringify(d.tiers) !== JSON.stringify(SKILL_TIERS)) p.push('tiers must be the skill tiers, in order')
  tierOk('floor', d.floor)

  // Materials.
  for (const [m, t] of Object.entries(d.materialTiers)) {
    if (!refs.materials.includes(m)) p.push(`materialTiers.${m} is not a material`)
    tierOk(`materialTiers.${m}`, t)
  }

  // Equipment: every piece carries a tier, the tier of its working part's material.
  for (const [k, e] of Object.entries(refs.equipment)) {
    if (e.tier === undefined) { p.push(`${k} is equipment (${e.category}) with no tier`); continue }
    if (!tierOk(k, e.tier)) continue
    const mt = d.materialTiers[e.material]
    if (mt === undefined) p.push(`${k}: its working material "${e.material || 'none'}" has no gear tier (materialTiers)`)
    else if (mt !== e.tier) p.push(`${k} is ${e.tier} but its ${e.material} working part is ${mt}`)
  }

  // Stations: every station type a recipe names has a placement item with a tier, and a tool rule.
  const stTiers = stationTiers(refs)
  for (const [st, t] of Object.entries(stTiers)) {
    const item = refs.placement[st]
    if (!item) { p.push(`station "${st}" has no placement item`); continue }
    if (t === undefined) p.push(`${item} is the ${st} crafting station with no tier`)
    else tierOk(item, t)
    if (!Object.hasOwn(d.stationTools, st)) p.push(`stationTools["${st}"] is missing: say which tool its recipes use (or null)`)
  }
  const crafting = new Set(Object.keys(stTiers).map((st) => refs.placement[st]))
  for (const [k, row] of Object.entries(refs.stationItems)) {
    if (!crafting.has(k) && row.declared) p.push(`${k} carries a tier, but no recipe is made at its station: only crafting stations have one`)
  }
  for (const [st, cat] of Object.entries(d.stationTools)) {
    if (!Object.hasOwn(stTiers, st)) p.push(`stationTools["${st}"]: no recipe is made at it`)
    if (cat !== null && !refs.categories.includes(cat)) p.push(`stationTools["${st}"]: "${cat}" is not an equipment category`)
  }

  // Recipes.
  for (const [k, r] of Object.entries(refs.recipes)) {
    if (r.requiredTier === undefined) { p.push(`${k} has no requiredTier`); continue }
    if (!tierOk(`${k}.requiredTier`, r.requiredTier)) continue
    const st = r.station || ''
    if (!st && r.requiredTier !== d.floor) p.push(`${k} is made by hand (no station or tool to check), so its requiredTier must be ${d.floor}, got ${r.requiredTier}`)
    const guards = (r.skillGuards || []).map((g) => rank(g.tier)).filter((x) => x >= 0)
    const top = guards.length ? Math.max(...guards) : rank(d.floor)
    if (rank(r.requiredTier) > top) p.push(`${k} asks for ${r.requiredTier} gear, above its highest skill guard (${d.tiers[top]})`)
    if (st && d.tiers.includes(stTiers[st]) && rank(r.requiredTier) > rank(stTiers[st])) p.push(`${k} asks for ${r.requiredTier} gear at a ${st}, which is only ${stTiers[st]}`)
  }

  // The ladder can be climbed from bare hands.
  if (!p.length) {
    const { craftable } = climb(d, refs)
    for (const k of Object.keys(refs.recipes)) {
      if (!craftable.has(k)) {
        const r = refs.recipes[k]
        p.push(`${k} can never be crafted: no climb from bare hands reaches a ${d.stationTools[r.station] || 'station'} of ${r.requiredTier} tier at a ${r.station}`)
      }
    }
  }

  // Combat abilities.
  for (const [skill, row] of Object.entries(d.abilities)) {
    if (!Object.hasOwn(refs.combatSkills, skill)) { p.push(`abilities.${skill} is not a combat skill`); continue }
    if (!isObj(row) || !Array.isArray(row.weapons) || !isObj(row.abilities)) { p.push(`abilities.${skill} needs weapons [] and abilities {}`); continue }
    for (const w of row.weapons) if (!refs.categories.includes(w)) p.push(`abilities.${skill}.weapons: "${w}" is not an equipment category`)
    for (const [a, t] of Object.entries(row.abilities)) {
      if (!Object.hasOwn(refs.combatSkills[skill], a)) { p.push(`abilities.${skill}.${a} is not an ability of ${skill}`); continue }
      if (!tierOk(`abilities.${skill}.${a}`, t)) continue
      if (row.weapons.length && refs.combatSkills[skill][a] === null) { p.push(`${skill}.${a}: no rule "Requires ${skill}: <Tier>" names the tier it needs`); continue }
      const want = row.weapons.length ? refs.combatSkills[skill][a] : d.floor
      if (t !== want) p.push(`abilities.${skill}.${a} must need ${want} gear (${row.weapons.length ? 'the tier its skill rule names' : 'no weapon: the floor'}), got ${t}`)
    }
  }
  for (const [skill, behaviors] of Object.entries(refs.combatSkills)) {
    for (const a of Object.keys(behaviors)) {
      if (!d.abilities[skill] || !isObj(d.abilities[skill].abilities) || !Object.hasOwn(d.abilities[skill].abilities, a)) p.push(`${skill}.${a} is a combat ability with no requiredTier (abilities.${skill})`)
    }
  }

  // Refusal keys.
  for (const k of ['weapon', 'tool', 'station']) {
    if (typeof d.refusals[k] !== 'string' || !/^[a-z_]+\.[a-z_.]+$/.test(d.refusals[k])) p.push(`refusals.${k} must be a locale key`)
  }
  return p
}

function validateGearTiers(d, refs) {
  const problems = gearTiersProblems(d, refs)
  if (problems.length) throw new Error('GearTiers is invalid:\n  ' + problems.join('\n  '))
}

function itemTiers(refs = gearTiersRefs()) {
  const out = {}
  for (const [k, e] of Object.entries(refs.equipment)) out[k] = e.tier
  return out
}

function gapsProse() {
  const gaps = Object.entries(abilityGaps())
  return gaps.length ? ' No weapon reaches these abilities yet: ' + gaps.map(([a, t]) => `${a} (${t})`).join(', ') + '.' : ''
}

const GearTiers = defineEntity({
  tags: ['world-system'],
  description:
    'Skills capped by the gear (Phase 229): a combat ability needs an equipped weapon of its tier, and a recipe needs ' +
    'a tool and a crafting station of its tier. Empty hands and a missing tool count as novice gear, so novice ' +
    'abilities and recipes need nothing. Skill XP grows with any gear; only use is capped.' + gapsProse(),
  goal: 'A character that knows more than its gear allows still has to make the gear in this world first',
  fields: {
    id:            { type: 'uuid', primaryKey: true },
    tiers:         { type: 'json', description: 'The gear tiers: the skill tiers, lowest first', defaultValue: SKILL_TIERS },
    floor:         { type: 'string', description: 'The tier that needs no gear: empty hands and a missing tool count as it', defaultValue: FLOOR },
    materialTiers: { type: 'json', description: '{ <material>: tier } of an equipment piece\'s working part; its `tier` field must match', defaultValue: MATERIAL_TIERS },
    stationTools:  { type: 'json', description: '{ <station type>: <equipment category> | null }: the tool recipes made there use (null: none)', defaultValue: STATION_TOOLS },
    abilities:     { type: 'json', description: '{ <combat skill>: { weapons: [category], abilities: { <behavior>: requiredTier } } }', defaultValue: ABILITIES },
    refusals:      { type: 'json', description: 'Locale keys the host refuses with: { weapon, tool, station }', defaultValue: REFUSALS },
    stationTiers:  { type: 'json', description: 'Derived: { <station type>: tier } from each crafting station\'s placement item', defaultValue: stationTiers(gearTiersRefs()) },
    itemTiers:     { type: 'json', description: 'Derived: { <item>: tier } for every piece of equipment', defaultValue: itemTiers() },
    abilityGaps:   { type: 'json', description: 'Derived: { "<Skill>.<ability>": tier } that no weapon reaches yet (refused until one exists)', defaultValue: abilityGaps() },
  },
})

module.exports = {
  FLOOR, MATERIAL_TIERS, STATION_TOOLS, ABILITIES, REFUSALS,
  gearTiersData, gearTiersRefs, gearTiersProblems, validateGearTiers, stationTiers, climb, abilityGaps, itemTiers, ruleTier, GearTiers,
}
