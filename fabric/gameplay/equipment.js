const { defineEntity } = require('@newel/core')

// Phase 295 — equipment categories and traits replace tools. Decided by the owner on 2026-11-20: there are no
// tools that cannot be used in combat. Every held item is equipment of a category (knife, sword, axe, hammer,
// pick, shovel…), and what it can do in the world follows from its traits, not from a tool type.
//
// TRAITS          { <Trait>: { damageType, damage, grades? } }. `damage` is the combat damage one unit of strength
//                 adds, of `damageType`. A trait with `grades` (ordered, weakest first) takes a grade on every item
//                 that has it, and each grade sets its own damage (Blunt: light or heavy).
// CATEGORIES      { <category>: { hands, clipFamily, combatMultiplier, defaultTraits } }. `clipFamily` is the attack
//                 chain of Phase 287 (CombatCombos.chains). `defaultTraits` are the traits every item of the category
//                 has at least (with at least that grade), so "every axe fells" holds by construction.
//                 `combatMultiplier` scales the item's trait damage; picks have the lowest of all.
// MATERIAL_TRAITS { <material>: { raise: { <Trait>: +strength }, add: { <Trait>: { strength, grade? } } } }: the
//                 material of an item's working part (head, blade or pin) raises the traits it already has, or adds
//                 one it lacks.
// WORK_TRAITS     { <work>: { ways: [{ category?, traits: { <Trait>: { grade? } }, minStrength?, speed }], bareHands } }.
//                 An item can do a work when it matches one way: of the way's category (if named) and with every
//                 listed trait (at least the listed grade, and at least `minStrength` strong when it is set). Its speed is `way.speed` × the weakest of the listed traits'
//                 strengths (1 when the way lists none); the best way wins. An item that matches no way works as
//                 bare hands where `bareHands` is true (WorkTimes.bareHandsSpeed) and not at all where it is false.
//                 The speeds keep Phase 259/290's work times: the item that did a job before does it at its old speed.
//
// An item's effective traits: its own `traits` ({ <Trait>: { strength, grade? } }), then its material's raise/add.
// Its combat damage per damage type: combatMultiplier × Σ strength × (grade's or trait's) damage.
//
// Until Phase 296 moves the runtime onto these tables, items/index.js derives the old `toolType`, `harvestTool` and
// `efficiency` fields from them (the Phase 295 bridge, `legacyToolFields`), so the game keeps working; no item
// declares them any more.

const DAMAGE_TYPES = ['slashing', 'blunt', 'piercing']

const TRAITS = {
  Sharp:    { damageType: 'slashing', damage: 6 },
  Blunt:    { damageType: 'blunt', grades: { light: { damage: 2 }, heavy: { damage: 5 } } },
  Piercing: { damageType: 'piercing', damage: 5 },
  Broad:    { damageType: 'blunt', damage: 3 }, // a wide flat head that moves loose ground (a shovel's)
}

const CATEGORIES = {
  knife:      { hands: 1, clipFamily: 'one_hand', combatMultiplier: 0.8, defaultTraits: { Sharp: {}, Piercing: {} } },
  sword:      { hands: 1, clipFamily: 'one_hand', combatMultiplier: 1.0, defaultTraits: { Sharp: {}, Piercing: {} } },
  greatsword: { hands: 2, clipFamily: 'two_hand', combatMultiplier: 1.2, defaultTraits: { Sharp: {}, Piercing: {} } },
  axe:        { hands: 1, clipFamily: 'tool',     combatMultiplier: 1.0, defaultTraits: { Sharp: {}, Blunt: { grade: 'heavy' } } },
  hammer:     { hands: 1, clipFamily: 'tool',     combatMultiplier: 0.8, defaultTraits: { Blunt: { grade: 'heavy' } } },
  mace:       { hands: 1, clipFamily: 'one_hand', combatMultiplier: 1.1, defaultTraits: { Blunt: { grade: 'heavy' } } },
  spear:      { hands: 2, clipFamily: 'two_hand', combatMultiplier: 1.0, defaultTraits: { Piercing: {} } },
  pick:       { hands: 1, clipFamily: 'tool',     combatMultiplier: 0.5, defaultTraits: { Piercing: {}, Blunt: { grade: 'light' } } },
  shovel:     { hands: 1, clipFamily: 'tool',     combatMultiplier: 0.6, defaultTraits: { Broad: {}, Blunt: { grade: 'light' } } },
  saw:        { hands: 1, clipFamily: 'one_hand', combatMultiplier: 0.7, defaultTraits: { Sharp: {} } },
  lockpick:   { hands: 1, clipFamily: 'one_hand', combatMultiplier: 0.8, defaultTraits: { Piercing: {} } },
  // A bow has no melee chain of its own yet; struck with, it swings one-handed (ranged fire is its own system).
  bow:        { hands: 2, clipFamily: 'one_hand', combatMultiplier: 0.6, defaultTraits: { Piercing: {} } },
  // Held in the off hand; struck with, a shield bashes.
  shield:     { hands: 1, clipFamily: 'one_hand', combatMultiplier: 0.8, defaultTraits: { Blunt: { grade: 'heavy' } } },
}

const MATERIAL_TRAITS = {
  Veilsteel: { raise: { Sharp: 0.5, Piercing: 0.5, Blunt: 0.5 }, add: {} },
}

const WORK_TRAITS = {
  fell:     { bareHands: true,  ways: [{ traits: { Sharp: {}, Blunt: { grade: 'heavy' } }, speed: 1.0 }] },
  mine:     { bareHands: true,  ways: [{ traits: { Piercing: {}, Blunt: {} }, speed: 1.0 }] },
  dig:      { bareHands: true,  ways: [{ traits: { Broad: {} }, speed: 1.0 }] },
  build:    { bareHands: false, ways: [{ category: 'hammer', traits: {}, speed: 1.0 }] },
  pickLock: { bareHands: false, ways: [{ category: 'lockpick', traits: {}, speed: 1.0 }] },
  dissect:  { bareHands: false, ways: [{ category: 'knife', traits: { Sharp: {} }, speed: 1.0 }] },
  cutBone:  { bareHands: false, ways: [
    { category: 'saw', traits: { Sharp: {} }, speed: 1.0 },
    // A forged axe is a poor bone saw; a stone one (strength 0.6) is not one at all, as before this phase.
    { traits: { Sharp: {}, Blunt: { grade: 'heavy' } }, minStrength: 1.0, speed: 0.5 },
  ] },
}

// What each former tool did before this phase, and how fast (WorkTimes.toolSpeeds and the harvest `efficiency`
// of Phase 290). The validator proves each still does it at least as fast: no regression in what a player can do.
const FORMER_JOBS = {
  StoneAxe:      { fell: 0.6 },
  CarpenterAxe:  { fell: 1.0, cutBone: 0.5 },
  StonePick:     { mine: 0.6 },
  FerritePick:   { mine: 1.0 },
  VeilsteelPick: { mine: 1.5 },
  StoneShovel:   { dig: 1.2 },
  StoneHammer:   { build: 1.0 },
  Lockpick:      { pickLock: 1.0 },
  StoneKnife:    { dissect: 0.5 },
  SkinningKnife: { dissect: 1.0 },
  BoneSaw:       { cutBone: 1.0 },
}

// Phase 295 bridge: the runtime (until Phase 296) reads one `toolType` per item and a `harvestTool` with an
// `efficiency`. Each work below maps to the old name; build reads Structure.buildTool, pickLock
// ChestsAndDoors.locks.toolType, the others WorkTimes.actions.
const LEGACY_TOOL_TYPE = { fell: 'axe', mine: 'pick', dig: 'shovel', build: 'hammer', pickLock: 'lockpick' }
const LEGACY_HARVEST_TOOL = { dissect: 'knife', cutBone: 'bonetool' }

// The part of a shape whose material sets the item's tier and raises its traits.
const WORKING_PARTS = ['head', 'blade', 'pin', 'tip', 'limb', 'face']

// Every held item is equipment (it has a category); every worn piece is armour (it has protection numbers).
const HELD_SLOTS = ['MainHand', 'OffHand']
const HELD_ARCHETYPES = ['pick', 'axe', 'sword', 'longsword', 'knife', 'saw', 'bow', 'shield', 'lockpick', 'shovel', 'hammer']
const WORN_SLOTS = ['Head', 'Chest', 'Cape', 'Legs', 'Feet', 'Hands']

const clone = (v) => JSON.parse(JSON.stringify(v))
const round = (x) => Math.round(x * 1000) / 1000

function gradeIndex(trait, grade, traits = TRAITS) {
  const t = traits[trait]
  if (!t || !t.grades) return 0
  return Object.keys(t.grades).indexOf(grade)
}

/** The material of an item's working part, from its shape ({ archetype, parts }). */
function workingMaterial(shape) {
  const parts = (shape && shape.parts) || {}
  for (const p of WORKING_PARTS) if (parts[p]) return parts[p]
  return ''
}

/** An item's effective traits: its own, then its material's raise and add. { <Trait>: { strength, grade? } } */
function effectiveTraits(spec, d = equipmentData()) {
  const out = clone(spec.traits || {})
  const m = d.materialTraits[spec.material || ''] || {}
  for (const [t, by] of Object.entries(m.raise || {})) if (out[t]) out[t].strength = round(out[t].strength + by)
  for (const [t, add] of Object.entries(m.add || {})) if (!out[t]) out[t] = clone(add)
  return out
}

function wayMatches(way, spec, traits, d) {
  if (way.category && way.category !== spec.category) return false
  for (const [t, need] of Object.entries(way.traits || {})) {
    const have = traits[t]
    if (!have || !(have.strength > 0)) return false
    if (need.grade && gradeIndex(t, have.grade, d.traits) < gradeIndex(t, need.grade, d.traits)) return false
    if (way.minStrength !== undefined && have.strength < way.minStrength) return false
  }
  return true
}

/** The speed `spec` does `work` at, or 0 when it matches no way. spec: { category, traits, material } */
function workSpeed(spec, work, d = equipmentData()) {
  const rule = d.workTraits[work]
  if (!rule) return 0
  const traits = effectiveTraits(spec, d)
  let best = 0
  for (const way of rule.ways || []) {
    if (!wayMatches(way, spec, traits, d)) continue
    const names = Object.keys(way.traits || {})
    const weakest = names.length ? Math.min(...names.map((t) => traits[t].strength)) : 1
    best = Math.max(best, round(way.speed * weakest))
  }
  return best
}

/** { <work>: speed } for every work the item can do. */
function worksOf(spec, d = equipmentData()) {
  const out = {}
  for (const w of Object.keys(d.workTraits)) {
    const s = workSpeed(spec, w, d)
    if (s > 0) out[w] = s
  }
  return out
}

/** Combat damage per damage type: combatMultiplier × Σ strength × damage. */
function combatDamage(spec, d = equipmentData()) {
  const cat = d.categories[spec.category]
  const out = {}
  if (!cat) return out
  for (const [t, v] of Object.entries(effectiveTraits(spec, d))) {
    const def = d.traits[t]
    if (!def) continue
    const per = def.grades ? ((def.grades[v.grade] || {}).damage || 0) : def.damage
    out[def.damageType] = round((out[def.damageType] || 0) + cat.combatMultiplier * v.strength * per)
  }
  return out
}

const totalDamage = (dmg) => round(Object.values(dmg).reduce((a, b) => a + b, 0))

/** Phase 295 bridge: the old fields the runtime still reads, derived from the work table. */
function legacyToolFields(spec, d = equipmentData()) {
  const works = worksOf(spec, d)
  const out = {}
  const types = Object.keys(LEGACY_TOOL_TYPE).filter((w) => works[w])
  if (types.length) out.toolType = LEGACY_TOOL_TYPE[types[0]]
  for (const w of Object.keys(LEGACY_HARVEST_TOOL)) {
    if (works[w]) { out.harvestTool = LEGACY_HARVEST_TOOL[w]; out.efficiency = Math.min(1, works[w]); break }
  }
  return out
}

function equipmentData() {
  return clone({
    damageTypes: DAMAGE_TYPES, traits: TRAITS, categories: CATEGORIES, materialTraits: MATERIAL_TRAITS,
    workTraits: WORK_TRAITS, formerJobs: FORMER_JOBS,
  })
}

/** Equipment specs off authored item entities: { <item>: { category, traits, material, declared } }. */
function itemSpecs(items) {
  const out = {}
  const dv = (e, f) => e && e.fields && e.fields[f] ? e.fields[f].defaultValue : undefined
  for (const [k, e] of Object.entries(items)) {
    const f = (e && e.fields) || {}
    out[k] = {
      category: dv(e, 'equipmentCategory'),
      traits: dv(e, 'traits'),
      material: workingMaterial(dv(e, 'shape')),
      protection: dv(e, 'protection'),
      slot: dv(e, 'equipmentSlot'),
      archetype: (dv(e, 'shape') || {}).archetype,
      declared: ['toolType', 'harvestTool', 'efficiency'].filter((n) => n in f),
    }
  }
  return out
}

function equipmentRefs() {
  return {
    items: itemSpecs(require('./items/authored')),
    materials: Object.keys(require('../world/materials')),
    clipFamilies: Object.keys(require('./combos').CHAINS),
  }
}

/** Problems with the equipment tables and the items' categories and traits, as strings. */
function equipmentProblems(d, refs) {
  const p = []
  const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
  const traitOk = (where, t, v, needStrength) => {
    const def = d.traits[t]
    if (!def) { p.push(`${where}: trait "${t}" is not in the trait table`); return }
    if (!isObj(v)) { p.push(`${where}.${t} must be an object`); return }
    if (needStrength && !(typeof v.strength === 'number' && v.strength > 0)) p.push(`${where}.${t}.strength must be > 0, got ${v.strength}`)
    if (def.grades) {
      if (needStrength && !(v.grade in def.grades)) p.push(`${where}.${t} needs a grade (${Object.keys(def.grades).join(', ')}), got "${v.grade}"`)
      else if (v.grade !== undefined && !(v.grade in def.grades)) p.push(`${where}.${t}: unknown grade "${v.grade}"`)
    } else if (v.grade !== undefined) p.push(`${where}.${t} has no grades, got "${v.grade}"`)
  }

  // Traits.
  if (!Object.keys(d.traits).length) p.push('the trait table is empty')
  for (const [t, def] of Object.entries(d.traits)) {
    if (!/^[A-Z][A-Za-z]*$/.test(t)) p.push(`trait "${t}" must be PascalCase`)
    if (!d.damageTypes.includes(def.damageType)) p.push(`trait ${t}: damage type "${def.damageType}" is not one of ${d.damageTypes.join(', ')}`)
    if (def.grades) {
      const gs = Object.values(def.grades)
      if (!gs.length) p.push(`trait ${t}: grades is empty`)
      gs.forEach((g, i) => {
        if (!(g.damage >= 0)) p.push(`trait ${t}: every grade needs a damage >= 0`)
        if (i > 0 && g.damage < gs[i - 1].damage) p.push(`trait ${t}: grades must be ordered weakest first`)
      })
    } else if (!(def.damage >= 0)) p.push(`trait ${t}: damage must be >= 0, got ${def.damage}`)
  }
  for (const dt of d.damageTypes) {
    if (!Object.values(d.traits).some((def) => def.damageType === dt)) p.push(`damage type ${dt}: no trait deals it`)
  }

  // Categories.
  for (const [c, cat] of Object.entries(d.categories)) {
    if (!/^[a-z][a-z_]*$/.test(c)) p.push(`category "${c}" must be lower snake_case`)
    if (![1, 2].includes(cat.hands)) p.push(`category ${c}: hands must be 1 or 2, got ${cat.hands}`)
    if (!refs.clipFamilies.includes(cat.clipFamily)) p.push(`category ${c}: clip family "${cat.clipFamily}" is not a CombatCombos chain`)
    if (!(cat.combatMultiplier > 0)) p.push(`category ${c}: combatMultiplier must be > 0`)
    if (!isObj(cat.defaultTraits) || !Object.keys(cat.defaultTraits).length) p.push(`category ${c}: needs at least one default trait`)
    else for (const [t, v] of Object.entries(cat.defaultTraits)) traitOk(`category ${c}.defaultTraits`, t, v, false)
  }
  // Picks are the weakest weapons: the lowest combat multiplier of every category, strictly.
  if (!d.categories.pick) p.push('category pick is missing')
  else {
    for (const [c, cat] of Object.entries(d.categories)) {
      if (c !== 'pick' && !(cat.combatMultiplier > d.categories.pick.combatMultiplier)) {
        p.push(`category ${c}: combatMultiplier ${cat.combatMultiplier} must be above the pick's (${d.categories.pick.combatMultiplier}): picks are the weakest weapons`)
      }
    }
  }

  // Materials.
  for (const [m, row] of Object.entries(d.materialTraits)) {
    if (!refs.materials.includes(m)) p.push(`materialTraits.${m} is not a material`)
    for (const [t, by] of Object.entries(row.raise || {})) {
      if (!d.traits[t]) p.push(`materialTraits.${m}.raise: trait "${t}" is not in the trait table`)
      if (!(by > 0)) p.push(`materialTraits.${m}.raise.${t} must be > 0`)
    }
    for (const [t, v] of Object.entries(row.add || {})) traitOk(`materialTraits.${m}.add`, t, v, true)
  }

  // Work rules.
  for (const [w, rule] of Object.entries(d.workTraits)) {
    if (typeof rule.bareHands !== 'boolean') p.push(`work ${w}: bareHands must be true or false`)
    if (!Array.isArray(rule.ways) || !rule.ways.length) { p.push(`work ${w}: needs at least one way`); continue }
    rule.ways.forEach((way, i) => {
      const where = `work ${w}.ways[${i}]`
      if (way.category !== undefined && !d.categories[way.category]) p.push(`${where}: category "${way.category}" is not in the category table`)
      if (!isObj(way.traits)) p.push(`${where}.traits must be an object`)
      else for (const [t, v] of Object.entries(way.traits)) traitOk(`${where}.traits`, t, v, false)
      if (way.category === undefined && !Object.keys(way.traits || {}).length) p.push(`${where}: names neither a category nor a trait, so anything would do it`)
      if (!(way.speed > 0)) p.push(`${where}.speed must be > 0`)
      if (way.minStrength !== undefined && !(way.minStrength > 0 && Object.keys(way.traits || {}).length)) p.push(`${where}.minStrength must be > 0 and needs listed traits`)
    })
  }

  // Items.
  const specs = refs.items
  for (const [k, s] of Object.entries(specs)) {
    for (const f of s.declared) p.push(`${k} declares ${f}: there are no tool types any more (Phase 295); give it an equipmentCategory and traits`)
    if (s.category === undefined && s.traits === undefined) continue
    const cat = d.categories[s.category]
    if (!cat) { p.push(`${k}: equipmentCategory "${s.category}" is not in the category table`); continue }
    if (!isObj(s.traits) || !Object.keys(s.traits).length) { p.push(`${k}: equipment needs its traits`); continue }
    for (const [t, v] of Object.entries(s.traits)) traitOk(`${k}.traits`, t, v, true)
    for (const [t, need] of Object.entries(cat.defaultTraits)) {
      const have = s.traits[t]
      if (!have) p.push(`${k}: every ${s.category} has ${t}, and it lacks it`)
      else if (need.grade && gradeIndex(t, have.grade, d.traits) < gradeIndex(t, need.grade, d.traits)) p.push(`${k}: every ${s.category} has ${t} (${need.grade}), it has ${have.grade}`)
    }
  }

  // Every held item is equipment, every worn piece has protection numbers.
  for (const [k, s] of Object.entries(specs)) {
    if ((HELD_SLOTS.includes(s.slot) || HELD_ARCHETYPES.includes(s.archetype)) && s.category === undefined) p.push(`${k} is held (${s.slot || s.archetype}), so it is equipment: give it an equipmentCategory and traits`)
    if (WORN_SLOTS.includes(s.slot) && s.protection === undefined) p.push(`${k} is worn (${s.slot}), so it needs protection numbers per damage type`)
  }

  // Armour: what each piece takes off each damage type, a number per type (Phase 295; was prose).
  for (const [k, s] of Object.entries(specs)) {
    if (s.protection === undefined) continue
    if (!isObj(s.protection)) { p.push(`${k}.protection must be an object`); continue }
    for (const dt of d.damageTypes) {
      const v = s.protection[dt]
      if (!(typeof v === 'number' && v >= 0 && v < 1)) p.push(`${k}.protection.${dt} must be a share in [0, 1), got ${v}`)
    }
    for (const dt of Object.keys(s.protection)) if (!d.damageTypes.includes(dt)) p.push(`${k}.protection.${dt} is not a damage type`)
  }

  // No regression: every former tool still does its former job, at least as fast.
  for (const [k, jobs] of Object.entries(d.formerJobs)) {
    const s = specs[k]
    if (!s || !s.category) { p.push(`${k}: a former tool must be equipment with a category`); continue }
    for (const [w, speed] of Object.entries(jobs)) {
      if (!d.workTraits[w]) { p.push(`formerJobs.${k}.${w} is not a work`); continue }
      const now = workSpeed(s, w, d)
      if (!(now > 0)) p.push(`${k} can no longer ${w}: a former tool must keep its job`)
      else if (now < speed) p.push(`${k} does ${w} at ${now}, slower than before (${speed})`)
      // What the runtime reads until Phase 296 (the bridge) must say the same.
      const legacy = legacyToolFields(s, d)
      if (LEGACY_TOOL_TYPE[w] && legacy.toolType !== LEGACY_TOOL_TYPE[w]) p.push(`${k}: the bridge gives toolType "${legacy.toolType}", the runtime needs "${LEGACY_TOOL_TYPE[w]}" for ${w}`)
      if (LEGACY_HARVEST_TOOL[w] && (legacy.harvestTool !== LEGACY_HARVEST_TOOL[w] || !(legacy.efficiency >= Math.min(1, speed)))) p.push(`${k}: the bridge gives harvestTool "${legacy.harvestTool}" at ${legacy.efficiency}, the runtime needs "${LEGACY_HARVEST_TOOL[w]}" at ${speed} for ${w}`)
    }
  }
  // Picks deal the least: a pick's damage is below every other item's with the same working material.
  for (const [k, s] of Object.entries(specs)) {
    if (s.category !== 'pick' || !d.categories.pick) continue
    const mine = totalDamage(combatDamage(s, d))
    const peers = Object.entries(specs).filter(([o, so]) => o !== k && so.category && so.category !== 'pick' && so.material === s.material && d.categories[so.category])
    if (!peers.length) p.push(`${k}: no other equipment of its material (${s.material || 'none'}) to prove a pick deals the least`)
    for (const [o, so] of Object.entries(specs)) {
      if (o === k || !so.category || so.category === 'pick' || so.material !== s.material || !d.categories[so.category]) continue
      const theirs = totalDamage(combatDamage(so, d))
      if (!(theirs > mine)) p.push(`${k} (${mine}) must deal less than ${o} (${theirs}): picks are the weakest weapons`)
    }
  }
  // Phase 295 bridge: the runtime reads one toolType per item until Phase 296.
  for (const [k, s] of Object.entries(specs)) {
    if (!s.category || !d.categories[s.category]) continue
    const works = worksOf(s, d)
    const legacy = Object.keys(LEGACY_TOOL_TYPE).filter((w) => works[w])
    if (legacy.length > 1) p.push(`${k} can ${legacy.join(' and ')}: the runtime reads one tool class per item until Phase 296`)
    const harvest = Object.keys(LEGACY_HARVEST_TOOL).filter((w) => works[w])
    if (harvest.length > 1) p.push(`${k} can ${harvest.join(' and ')}: the runtime reads one harvest tool per item until Phase 296`)
  }
  return p
}

function validateEquipment(d, refs) {
  const problems = equipmentProblems(d, refs)
  if (problems.length) throw new Error('Equipment is invalid:\n  ' + problems.join('\n  '))
}

/** The categories with what an item of the category can do at least (from its default traits at strength 1). */
function categorySummary(d = equipmentData()) {
  const out = {}
  for (const [c, cat] of Object.entries(d.categories)) {
    const traits = {}
    for (const [t, v] of Object.entries(cat.defaultTraits)) traits[t] = { strength: 1, ...v }
    const spec = { category: c, traits, material: '' }
    out[c] = { hands: cat.hands, traits: Object.keys(traits), canDo: Object.keys(worksOf(spec, d)), combatMultiplier: cat.combatMultiplier }
  }
  return out
}

/** Prose for the generated docs: each category with its traits and what it can do. */
function categoryProse(d = equipmentData()) {
  const rows = Object.entries(categorySummary(d)).map(([c, r]) => {
    const traits = r.traits.map((t) => {
      const g = d.categories[c].defaultTraits[t].grade
      return g ? `${t} (${g})` : t
    }).join(' + ')
    return `${c} (${r.hands}-handed, ${traits}, combat x${r.combatMultiplier}): ${r.canDo.length ? r.canDo.join(', ') : 'combat only'}`
  })
  return 'Categories: ' + rows.join('; ') + '.'
}

const Equipment = defineEntity({
  tags: ['world-system'],
  description:
    'Equipment categories and traits (Phase 295): every held item is equipment of a category, and what it can do in ' +
    'the world (fell, mine, dig, build, pick a lock, dissect, cut bone) follows from its traits by the work table. ' +
    'There are no tools that cannot be used in combat; picks are the weakest weapons. ' + categoryProse(),
  goal: 'One rule for what a held item can do, in work and in combat, instead of a tool type per item',
  fields: {
    id:             { type: 'uuid', primaryKey: true },
    damageTypes:    { type: 'json', description: 'The combat damage types a trait deals', defaultValue: DAMAGE_TYPES },
    traits:         { type: 'json', description: '{ <Trait>: { damageType, damage } | { damageType, grades: { <grade>: { damage } } } }, grades weakest first', defaultValue: TRAITS },
    categories:     { type: 'json', description: '{ <category>: { hands, clipFamily, combatMultiplier, defaultTraits } }', defaultValue: CATEGORIES },
    materialTraits: { type: 'json', description: '{ <material>: { raise: { <Trait>: +strength }, add: { <Trait>: { strength, grade? } } } } for the working part', defaultValue: MATERIAL_TRAITS },
    workTraits:     { type: 'json', description: '{ <work>: { bareHands, ways: [{ category?, traits: { <Trait>: { grade? } }, speed }] } }', defaultValue: WORK_TRAITS },
    categorySummary: { type: 'json', description: 'Derived: per category its hands, traits, what it can do and its combat multiplier', defaultValue: categorySummary() },
  },
})

module.exports = {
  DAMAGE_TYPES, TRAITS, CATEGORIES, MATERIAL_TRAITS, WORK_TRAITS, FORMER_JOBS, LEGACY_TOOL_TYPE, LEGACY_HARVEST_TOOL,
  equipmentData, equipmentRefs, equipmentProblems, validateEquipment, itemSpecs, workingMaterial,
  effectiveTraits, workSpeed, worksOf, combatDamage, totalDamage, legacyToolFields, categorySummary, categoryProse, HELD_SLOTS, HELD_ARCHETYPES, WORN_SLOTS, Equipment,
}
