const { defineEntity } = require('@newel/core')
const { STRUCTURAL_CLASSES } = require('../world/materials/structural')
const { LEVEL_CAP } = require('./work')

// Phase 203 — owned structures. A structure is a connected set of placed blocks (and the stations on them),
// assigned when built to its builder (private) or the builder's clan. Phases 205, 206 and 212 read these
// tables from GameData.WORLD_SYSTEMS ("Structure", "StructureDurability", "SelfRespawn").
//
// STRUCTURE
//   `ownership`  `owners` the two kinds; `edit` who may place, reshape or take stations on it, anywhere in
//                the world (`owner` = the builder, `member` = any member of the owning clan). A member's
//                private structure inside their clan's circles (`memberPrivateInTerritory`) may be entered
//                and dismantled, never edited, by any member of that clan. Anyone else may only `damage`
//                it. Where two structures touch each owner keeps their own blocks (`touching`).
//                `buffer` blocks of space around every placed block are kept clear of anyone who may not edit
//                it: no block of theirs lands that close (above, below, beside or diagonally).
//                `abandonedClan` who may edit and dismantle a clan structure whose clan has no members left.
//   `circle`     one per structure: radius = minRadius + footprintFactor × √(footprint m²) + heightFactor ×
//                height m, clamped to [minRadius, maxRadius]. A single block or station gets minRadius.
//                Inside it no creature spawns; inside a clan's circles only that clan's members may start a
//                structure (clan or private).
//   `floorHeight` metres per floor (24 blocks of 0.125 m); `maxFloors` the tallest building.
//   `classes`    structural class -> { maxFloors }: a structure's floors above ground may not exceed the
//                maxFloors of the weakest class among the materials it carries. Ordered as
//                STRUCTURAL_CLASSES; maxFloors rises strictly; wood 2, stone 5, concrete 10, the top class
//                reaches maxFloors.
//   `shapes`     measure -> [{ above, minClass }]: past `above` (blocks for overhangReach and unsupportedSpan,
//                a ratio for heightToFootprint) the weakest carrying class must be at least `minClass`.
//   `existingBuilds` always `kept`: a build that predates these rules never collapses (stable-world rule).
// DURABILITY
//   A block's durability starts at its material's `durability` and falls by fractions of that base:
//   `loss.perDay` per in-game day of age, `loss.weather[state]` per in-game hour of each weather state
//   (Phase 128) on an exposed block, and `loss.perDamage` durability points per point of damage. At 0 the
//   block is destroyed.
//   `methods`    destruction method -> { damage per hit, offlineFactor, classes { <class>: multiplier } }:
//                tools and weapons now. While every owner is offline (for a clan structure: every member)
//                damage is divided by offlineFactor, so destroying it takes that many times longer.
//   `destroyerGets` always `nothing`: a destroyed block drops no material (a destroyed chest still spills
//                its contents, ChestsAndDoors).
//   `repair`     the owner restores durability by spending `share` of the structure's build materials
//                times the fraction of durability restored (rounded up).
//   `dismantle`  the share of a block's material returned: (atNoSkill + (atTopSkill − atNoSkill) × level /
//                topLevel) × durabilityFraction ^ durabilityExponent. 100% at full durability with the top
//                Building level, 50% with none, never rising as durability falls (validated).
// RESPAWN — any player may kill their own character and respawn at their bed or the world spawn, with the
//   normal death rules, at most once per `cooldownSeconds`.
const STRUCTURE = {
  ownership: {
    owners: ['private', 'clan'],
    defaultOwner: 'private',
    edit: { private: 'owner', clan: 'member' },
    memberPrivateInTerritory: { enter: true, dismantle: true, edit: false },
    outsiders: 'damage',
    touching: 'eachKeepsOwn',
    buffer: 1,
    abandonedClan: 'anyone',
  },
  circle: { minRadius: 8, maxRadius: 128, footprintFactor: 1.0, heightFactor: 0.25 },
  floorHeight: 3,
  maxFloors: 163,
  classes: {
    earth:     { maxFloors: 1 },
    wood:      { maxFloors: 2 },
    stone:     { maxFloors: 5 },
    concrete:  { maxFloors: 10 },
    steel:     { maxFloors: 40 },
    composite: { maxFloors: 163 },
  },
  shapes: {
    overhangReach:     [{ above: 8, minClass: 'wood' }, { above: 16, minClass: 'stone' }, { above: 48, minClass: 'steel' }, { above: 128, minClass: 'composite' }],
    unsupportedSpan:   [{ above: 16, minClass: 'wood' }, { above: 32, minClass: 'stone' }, { above: 96, minClass: 'steel' }, { above: 256, minClass: 'composite' }],
    heightToFootprint: [{ above: 3, minClass: 'stone' }, { above: 6, minClass: 'concrete' }, { above: 12, minClass: 'steel' }, { above: 24, minClass: 'composite' }],
  },
  existingBuilds: 'kept',
}

const DURABILITY = {
  loss: {
    perDay: 0.002,
    weather: { clear: 0, fog: 0.0001, rain: 0.0005, storm: 0.001, blizzard: 0.001, ash_fall: 0.0008, electrical_storm: 0.0012, void_storm: 0.002 },
    perDamage: 1,
  },
  methods: {
    hand:   { damage: 1,  offlineFactor: 20, classes: { earth: 1, wood: 0.25, stone: 0.05, concrete: 0.02, steel: 0.01, composite: 0.01 } },
    pick:   { damage: 10, offlineFactor: 20, classes: { earth: 1, wood: 0.5, stone: 1, concrete: 0.75, steel: 0.4, composite: 0.25 } },
    axe:    { damage: 10, offlineFactor: 20, classes: { earth: 0.5, wood: 1, stone: 0.2, concrete: 0.1, steel: 0.05, composite: 0.05 } },
    weapon: { damage: 6,  offlineFactor: 20, classes: { earth: 0.5, wood: 0.5, stone: 0.2, concrete: 0.1, steel: 0.1, composite: 0.05 } },
  },
  destroyerGets: 'nothing',
  repair: { share: 0.5 },
  dismantle: { atNoSkill: 0.5, atTopSkill: 1.0, topLevel: LEVEL_CAP, durabilityExponent: 1.5, skill: 'Building' },
}

const RESPAWN = {
  command: 'respawn',
  menuButton: true,
  cooldownSeconds: 60,
  destinations: ['bed', 'worldSpawn'],
  deathRules: 'normal',
}

const MEASURES = ['overhangReach', 'unsupportedSpan', 'heightToFootprint']
const FIXED_FLOORS = { wood: 2, stone: 5, concrete: 10 }
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
const isNum = (v) => typeof v === 'number' && Number.isFinite(v)

/** The share of a block's material dismantling returns, from the durability fraction 0..1 and a Building level. */
function dismantleShare(d, durabilityFraction, level) {
  const skill = Math.min(1, Math.max(0, level / d.topLevel))
  const frac = Math.min(1, Math.max(0, durabilityFraction))
  return (d.atNoSkill + (d.atTopSkill - d.atNoSkill) * skill) * Math.pow(frac, d.durabilityExponent)
}

/** A structure's circle radius in metres from its footprint (m²) and height (m). */
function circleRadius(c, footprintM2, heightM) {
  const r = c.minRadius + c.footprintFactor * Math.sqrt(Math.max(0, footprintM2)) + c.heightFactor * Math.max(0, heightM)
  return Math.min(c.maxRadius, Math.max(c.minRadius, r))
}

function structureData() {
  return JSON.parse(JSON.stringify({ structure: STRUCTURE, durability: DURABILITY, respawn: RESPAWN }))
}

function structureRefs() {
  const materials = require('../world/materials')
  const weather = require('../world/weather')
  const world = require('../world/world')
  const skills = require('./skills')
  const tagged = (table, tag) => Object.entries(table).filter(([, e]) => e && (e.tags || []).includes(tag))
  const RARITY_ORDER = materials.Ferrite.fields.rarity.values
  const wf = world.WorldSystem.fields
  return {
    classes: [...STRUCTURAL_CLASSES],
    rarityOrder: RARITY_ORDER,
    materials: Object.fromEntries(tagged(materials, 'material').map(([k, e]) => [k, {
      rarity: e.fields.rarity && e.fields.rarity.defaultValue,
      durability: e.fields.durability && e.fields.durability.defaultValue,
      structuralClass: e.fields.structuralClass && e.fields.structuralClass.defaultValue,
    }])),
    weatherStates: Object.keys(weather.RULES.states),
    skills: tagged(skills, 'skill').map(([k]) => k),
    maxHeight: wf.maxHeight.defaultValue,
    buildCeiling: wf.buildCeiling && wf.buildCeiling.defaultValue,
  }
}

/** Problems with the structure, durability and respawn tables (and the materials they read), as strings. */
function structureProblems(data, refs) {
  const p = []
  const s = data.structure || {}
  const own = isObj(s.ownership) ? s.ownership : {}
  if (JSON.stringify(own.owners) !== JSON.stringify(['private', 'clan'])) p.push('Structure.ownership.owners must be ["private", "clan"]')
  if (!(own.owners || []).includes(own.defaultOwner)) p.push(`Structure.ownership.defaultOwner "${own.defaultOwner}" is not an owner kind`)
  const edit = isObj(own.edit) ? own.edit : {}
  if (edit.private !== 'owner' || edit.clan !== 'member') p.push('Structure.ownership.edit must be { private: "owner", clan: "member" }: only the owner edits a structure')
  const mp = isObj(own.memberPrivateInTerritory) ? own.memberPrivateInTerritory : {}
  if (mp.enter !== true || mp.dismantle !== true || mp.edit !== false) p.push('Structure.ownership.memberPrivateInTerritory must let clan members enter and dismantle, never edit')
  if (own.outsiders !== 'damage') p.push('Structure.ownership.outsiders must be "damage": anyone else may only damage a structure')
  if (own.touching !== 'eachKeepsOwn') p.push('Structure.ownership.touching must be "eachKeepsOwn"')
  if (!Number.isInteger(own.buffer) || own.buffer < 1 || own.buffer > 4) p.push('Structure.ownership.buffer must be an integer from 1 to 4 blocks: a stranger may not build against a structure')
  if (own.abandonedClan !== 'anyone') p.push('Structure.ownership.abandonedClan must be "anyone": a clan with no members left owns nothing')

  const c = isObj(s.circle) ? s.circle : {}
  if (!isNum(c.minRadius) || c.minRadius <= 0) p.push('Structure.circle.minRadius must be > 0')
  if (!isNum(c.maxRadius) || c.maxRadius <= c.minRadius) p.push('Structure.circle.maxRadius must exceed minRadius')
  if (!isNum(c.footprintFactor) || c.footprintFactor < 0 || !isNum(c.heightFactor) || c.heightFactor < 0) p.push('Structure.circle factors must be >= 0')
  else if (c.footprintFactor + c.heightFactor <= 0) p.push('Structure.circle needs a positive factor: a larger structure has a larger circle')

  if (!isNum(s.floorHeight) || s.floorHeight <= 0) p.push('Structure.floorHeight must be > 0')
  else if (!Number.isInteger(s.floorHeight / 0.125)) p.push(`Structure.floorHeight ${s.floorHeight} m is not a whole number of 0.125 m blocks`)
  if (!Number.isInteger(s.maxFloors) || s.maxFloors < 1) p.push('Structure.maxFloors must be an integer >= 1')
  const cls = isObj(s.classes) ? s.classes : {}
  const order = refs.classes
  if (JSON.stringify(Object.keys(cls)) !== JSON.stringify(order)) p.push(`Structure.classes must list exactly ${order.join(', ')}, weakest first`)
  let prev = 0
  for (const name of order) {
    const f = cls[name] && cls[name].maxFloors
    if (!Number.isInteger(f) || f <= prev) p.push(`Structure.classes.${name}.maxFloors must be an integer above ${prev}`)
    else prev = f
  }
  for (const [name, f] of Object.entries(FIXED_FLOORS)) if (cls[name] && cls[name].maxFloors !== f) p.push(`Structure.classes.${name}.maxFloors must be ${f} (owner, 2026-10-31)`)
  const top = cls[order[order.length - 1]]
  if (!top || top.maxFloors !== s.maxFloors) p.push(`Structure.classes.${order[order.length - 1]}.maxFloors must equal maxFloors ${s.maxFloors}`)

  const shapes = isObj(s.shapes) ? s.shapes : {}
  for (const m of MEASURES) {
    const rows = shapes[m]
    if (!Array.isArray(rows) || rows.length === 0) { p.push(`Structure.shapes.${m} must list at least one threshold`); continue }
    for (let i = 0; i < rows.length; i++) {
      const r = rows[i]
      if (!order.includes(r.minClass)) { p.push(`Structure.shapes.${m}[${i}].minClass "${r.minClass}" is not a structural class`); continue }
      if (!isNum(r.above) || r.above <= 0) p.push(`Structure.shapes.${m}[${i}].above must be > 0`)
      if (i > 0 && !(r.above > rows[i - 1].above)) p.push(`Structure.shapes.${m}[${i}].above must rise above ${rows[i - 1].above}`)
      if (i > 0 && order.indexOf(r.minClass) <= order.indexOf(rows[i - 1].minClass)) p.push(`Structure.shapes.${m}[${i}].minClass must be stronger than ${rows[i - 1].minClass}: a more unusual shape needs a rarer material`)
    }
  }
  for (const m of Object.keys(shapes)) if (!MEASURES.includes(m)) p.push(`Structure.shapes has unknown measure "${m}"`)
  if (s.existingBuilds !== 'kept') p.push('Structure.existingBuilds must be "kept": a build that predates the rules never collapses')

  // Materials: every one has a rarity, a durability and a class; a rarer material never has less durability.
  const mats = Object.entries(refs.materials)
  for (const [k, m] of mats) {
    if (!refs.rarityOrder.includes(m.rarity)) p.push(`${k}.rarity "${m.rarity}" is not a rarity`)
    if (!Number.isInteger(m.durability) || m.durability < 1) p.push(`${k}.durability must be an integer >= 1`)
    if (!order.includes(m.structuralClass)) p.push(`${k}.structuralClass "${m.structuralClass}" is not a structural class`)
  }
  for (const [a, ma] of mats) for (const [b, mb] of mats) {
    if (refs.rarityOrder.indexOf(ma.rarity) > refs.rarityOrder.indexOf(mb.rarity) && ma.durability < mb.durability) {
      p.push(`${a} (${ma.rarity}) has durability ${ma.durability}, below ${b} (${mb.rarity}) at ${mb.durability}: a rarer material never has less`)
    }
  }

  // Heights: the build ceiling clears the highest peak plus the tallest structure.
  if (isNum(s.floorHeight) && Number.isInteger(s.maxFloors)) {
    const need = refs.maxHeight + s.maxFloors * s.floorHeight
    if (!isNum(refs.buildCeiling) || refs.buildCeiling < need) p.push(`WorldSystem.buildCeiling ${refs.buildCeiling} must be at least maxHeight ${refs.maxHeight} + ${s.maxFloors} floors × ${s.floorHeight} m = ${need}`)
  }

  // Durability
  const d = data.durability || {}
  const loss = isObj(d.loss) ? d.loss : {}
  if (!isNum(loss.perDay) || loss.perDay <= 0 || loss.perDay >= 1) p.push('StructureDurability.loss.perDay must be in (0, 1)')
  if (!isNum(loss.perDamage) || loss.perDamage <= 0) p.push('StructureDurability.loss.perDamage must be > 0')
  const wl = isObj(loss.weather) ? loss.weather : {}
  for (const st of refs.weatherStates) if (!isNum(wl[st]) || wl[st] < 0 || wl[st] >= 1) p.push(`StructureDurability.loss.weather.${st} must be in [0, 1)`)
  for (const st of Object.keys(wl)) if (!refs.weatherStates.includes(st)) p.push(`StructureDurability.loss.weather: unknown weather state "${st}"`)
  const methods = isObj(d.methods) ? d.methods : {}
  if (Object.keys(methods).length === 0) p.push('StructureDurability.methods must name at least one destruction method')
  for (const [k, m] of Object.entries(methods)) {
    const at = `StructureDurability.methods.${k}`
    if (!isNum(m.damage) || m.damage <= 0) p.push(`${at}.damage must be > 0`)
    if (!isNum(m.offlineFactor) || m.offlineFactor < 10) p.push(`${at}.offlineFactor must be >= 10: destroying a structure while its owners are offline is very difficult`)
    const mc = isObj(m.classes) ? m.classes : {}
    for (const name of order) if (!isNum(mc[name]) || mc[name] <= 0 || mc[name] > 1) p.push(`${at}.classes.${name} must be in (0, 1]`)
  }
  if (d.destroyerGets !== 'nothing') p.push('StructureDurability.destroyerGets must be "nothing"')
  const rep = isObj(d.repair) ? d.repair : {}
  if (!isNum(rep.share) || rep.share <= 0 || rep.share > 1) p.push('StructureDurability.repair.share must be in (0, 1]: a repair costs part of the build materials')
  const dm = isObj(d.dismantle) ? d.dismantle : null
  if (!dm || !isNum(dm.atNoSkill) || !isNum(dm.atTopSkill) || !Number.isInteger(dm.topLevel) || dm.topLevel < 1 || !isNum(dm.durabilityExponent)) {
    p.push('StructureDurability.dismantle needs atNoSkill, atTopSkill, an integer topLevel >= 1 and durabilityExponent')
  } else {
    if (!refs.skills.includes(dm.skill)) p.push(`StructureDurability.dismantle.skill "${dm.skill}" is not a skill`)
    const near = (a, b) => Math.abs(a - b) < 1e-9
    if (!near(dismantleShare(dm, 1, 0), 0.5)) p.push(`StructureDurability.dismantle returns ${dismantleShare(dm, 1, 0)} at full durability with no skill, not 0.5`)
    if (!near(dismantleShare(dm, 1, dm.topLevel), 1)) p.push(`StructureDurability.dismantle returns ${dismantleShare(dm, 1, dm.topLevel)} at full durability with the top skill, not 1`)
    let rises = false
    for (let level = 0; level <= dm.topLevel; level++) {
      let last = Infinity
      for (let i = 100; i >= 0; i--) {
        const v = dismantleShare(dm, i / 100, level)
        if (v > last + 1e-12 || v < 0 || v > 1) rises = true
        last = v
      }
    }
    if (rises) p.push('StructureDurability.dismantle must stay in [0, 1] and never rise as durability falls')
  }

  // Respawn
  const r = data.respawn || {}
  if (typeof r.command !== 'string' || !/^[a-z]+$/.test(r.command)) p.push('SelfRespawn.command must be a lower-case word')
  if (r.menuButton !== true) p.push('SelfRespawn.menuButton must be true')
  if (!isNum(r.cooldownSeconds) || r.cooldownSeconds <= 0) p.push('SelfRespawn.cooldownSeconds must be > 0: respawning at will is rate-limited')
  if (!Array.isArray(r.destinations) || r.destinations.length === 0 || r.destinations.some((x) => !['bed', 'worldSpawn'].includes(x))) p.push('SelfRespawn.destinations must list "bed" and/or "worldSpawn"')
  if (r.deathRules !== 'normal') p.push('SelfRespawn.deathRules must be "normal": a self-kill is a death like any other')
  return p
}

function validateStructure(data, refs) {
  const problems = structureProblems(data, refs)
  if (problems.length) throw new Error('Structure rules are invalid:\n  ' + problems.join('\n  '))
}

const Structure = defineEntity({
  tags: ['world-system'],
  description:
    'A connected set of placed blocks and the stations on them, owned by its builder or the builder\'s clan. ' +
    'Only its owner edits it, wherever it stands; anyone else may only damage it. Around it a circle, larger for ' +
    'a larger structure, where no creature spawns and, for a clan structure, where only that clan\'s members may ' +
    'build. Its floors are limited by the weakest material it carries (wood 2, stone 5, concrete 10, up to 163), ' +
    'and an unusual shape needs a stronger class. There is no claim area.',
  goal: 'Make what a player builds theirs, as tall as its materials allow (ClansAndOwnedStructures, EarthScaleHeights, Phase 203)',
  fields: {
    id:          { type: 'uuid', primaryKey: true },
    owner:       { type: 'string', description: 'The owning player id (private) or clan id (clan)' },
    ownerKind:   { type: 'enum', values: ['private', 'clan'], defaultValue: 'private', description: 'Chosen by the builder when placing' },
    floorHeight: { type: 'decimal', description: 'Metres per floor: 24 blocks of 0.125 m', defaultValue: STRUCTURE.floorHeight },
    maxFloors:   { type: 'integer', description: 'Floors of the tallest structure (the top structural class)', defaultValue: STRUCTURE.maxFloors },
    rules:       { type: 'json', description: 'Structure table: { ownership, circle, floorHeight, maxFloors, classes, shapes, existingBuilds } (validated at fabric load)', defaultValue: STRUCTURE },
  },
  relations: {
    durability: { name: 'durability', kind: 'hasOne', target: 'StructureDurability' },
    clan:       { name: 'clan',       kind: 'hasOne', target: 'Clan' },
    decision:   { name: 'decision',   kind: 'hasOne', target: 'ClansAndOwnedStructures' },
  },
  behaviors: {
    build: {
      description: 'Place a block or station, joining or starting a structure',
      rules: [
        'The builder picks private or clan for a new structure',
        'Only the owner may add to an existing structure',
        'Inside a clan\'s circle only that clan\'s members may start a structure',
        'The weakest class carrying the block must allow its floor and the structure\'s shape',
      ],
      auth: { roles: ['maintainer'] },
    },
    enter: {
      description: 'A member of the clan passes into another member\'s private structure inside the clan\'s circles',
      rules: ['Entering and dismantling are allowed, editing is not'],
      auth: { roles: ['maintainer'] },
    },
  },
})

const StructureDurability = defineEntity({
  tags: ['world-system'],
  description:
    'How a placed block wears and comes apart. Its durability starts at its material\'s and falls with weather, ' +
    'age and damage; at zero it is destroyed. Destruction methods damage some classes more than others, and do ' +
    'so offlineFactor times more slowly while every owner is offline. A destroyer gets nothing. The owner repairs ' +
    'with part of the build materials, and dismantling returns a share that rises with Building skill and falls ' +
    'with durability.',
  goal: 'Let anyone break a building, but only with effort (DurabilityAndDestruction, Phase 203)',
  fields: {
    id:    { type: 'uuid', primaryKey: true },
    rules: { type: 'json', description: 'Durability table: { loss: { perDay, weather, perDamage }, methods, destroyerGets, repair: { share }, dismantle } (validated at fabric load)', defaultValue: DURABILITY },
  },
  relations: {
    structure: { name: 'structure', kind: 'hasOne', target: 'Structure' },
    skill:     { name: 'skill',     kind: 'hasOne', target: 'Building' },
    decision:  { name: 'decision',  kind: 'hasOne', target: 'DurabilityAndDestruction' },
  },
  behaviors: {
    wear: {
      description: 'Lower a block\'s durability by age and weather',
      rules: ['Computed from timestamps when a block is read or ticked, never by touching every block every frame'],
      auth: { roles: ['maintainer'] },
    },
    destroy: {
      description: 'A non-owner damages a block with a method',
      rules: ['Damage = method damage × class multiplier, divided by offlineFactor while every owner is offline', 'The destroyer gets nothing'],
      auth: { roles: ['maintainer'] },
    },
    repair: {
      description: 'The owner restores durability',
      rules: ['Costs repair.share of the build materials times the fraction restored, rounded up'],
      auth: { roles: ['maintainer'] },
    },
    dismantle: {
      description: 'The owner (or a clan member, for a member\'s private house in clan territory) takes a block apart',
      rules: ['Returns the dismantle share of its material, by durability and Building level'],
      auth: { roles: ['maintainer'] },
    },
  },
})

const SelfRespawn = defineEntity({
  tags: ['world-system'],
  description:
    'Any player may kill their own character to respawn at their bed or the world spawn, with the normal death ' +
    'rules, from a command or a menu button, so no one can be trapped inside another\'s structure.',
  goal: 'A way out of any wall (DurabilityAndDestruction, Phase 203)',
  fields: {
    id:    { type: 'uuid', primaryKey: true },
    rules: { type: 'json', description: 'Respawn table: { command, menuButton, cooldownSeconds, destinations, deathRules } (validated at fabric load)', defaultValue: RESPAWN },
  },
  relations: {
    decision: { name: 'decision', kind: 'hasOne', target: 'DurabilityAndDestruction' },
  },
  behaviors: {
    respawn: {
      description: 'Kill your own character and respawn',
      rules: ['At most once per cooldownSeconds', 'The normal death rules apply'],
      auth: { roles: ['maintainer'] },
    },
  },
})

module.exports = {
  STRUCTURE, DURABILITY, RESPAWN, MEASURES, dismantleShare, circleRadius,
  structureData, structureRefs, structureProblems, validateStructure,
  Structure, StructureDurability, SelfRespawn,
}
