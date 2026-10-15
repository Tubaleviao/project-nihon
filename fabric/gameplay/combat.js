const { defineEntity } = require('@newel/core')

// Phase 129 — the status-effect table. The runtime (src/battle/status_effects.gd) reads it from
// GameData.WORLD_SYSTEMS["CombatSystem"].statusEffects; a creature's `onHitEffects` ([{ effect, chance }])
// names the rows a landed hit rolls.
//
// StatusEffect fields:
//   durationSeconds: how long the effect lasts (0 = instant, e.g. knockback's displacement).
//   damagePerSecond: damage dealt each second while the effect lasts.
//   immobilize: the body cannot move or act while the effect lasts.
//   damageTakenFactor: multiplier on every hit the body takes while the effect lasts (1 = none).
//   displaceTiles: whole tiles the body is pushed along the attack direction when it is applied.
//   stacks: false = reapplying refreshes the timer; true = reapplying adds a second instance.
//   extinguishedBy: weather states under which the effect ends.
const STATUS_EFFECTS = {
  heat_burn:  { durationSeconds: 8, damagePerSecond: 5, immobilize: false, damageTakenFactor: 1,   displaceTiles: 0, stacks: false, extinguishedBy: ['rain', 'storm'] },
  paralysis:  { durationSeconds: 3, damagePerSecond: 0, immobilize: true,  damageTakenFactor: 1,   displaceTiles: 0, stacks: false, extinguishedBy: [] },
  knockback:  { durationSeconds: 0, damagePerSecond: 0, immobilize: false, damageTakenFactor: 1,   displaceTiles: 1, stacks: false, extinguishedBy: [] },
  knockdown:  { durationSeconds: 2, damagePerSecond: 0, immobilize: false, damageTakenFactor: 1.5, displaceTiles: 0, stacks: false, extinguishedBy: [] },
  stagger:    { durationSeconds: 1, damagePerSecond: 0, immobilize: true,  damageTakenFactor: 1,   displaceTiles: 0, stacks: false, extinguishedBy: [] },
}

const EFFECT_FIELDS = ['durationSeconds', 'damagePerSecond', 'immobilize', 'damageTakenFactor', 'displaceTiles', 'stacks', 'extinguishedBy']
const MAX_DISPLACE_TILES = 8
const MAX_DURATION_SECONDS = 600

/** Problems with a status-effect table, as strings. `weatherStates` (optional) is the list of weather state ids. */
function statusEffectProblems(table, weatherStates) {
  const problems = []
  const isNum = (v) => typeof v === 'number' && Number.isFinite(v)
  const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
  if (!isObj(table)) return ['CombatSystem.statusEffects must be an object']
  for (const [id, e] of Object.entries(table)) {
    if (!/^[a-z][a-z_]*$/.test(id)) problems.push(`status effect "${id}" must be lower snake_case`)
    if (!isObj(e)) { problems.push(`status effect "${id}" must be an object`); continue }
    for (const key of Object.keys(e)) if (!EFFECT_FIELDS.includes(key)) problems.push(`status effect "${id}" has unknown field "${key}"`)
    if (!isNum(e.durationSeconds) || e.durationSeconds < 0 || e.durationSeconds > MAX_DURATION_SECONDS) problems.push(`status effect "${id}".durationSeconds must be in 0..${MAX_DURATION_SECONDS}, got ${e.durationSeconds}`)
    if (!isNum(e.damagePerSecond) || e.damagePerSecond < 0) problems.push(`status effect "${id}".damagePerSecond must be >= 0, got ${e.damagePerSecond}`)
    if (isNum(e.damagePerSecond) && e.damagePerSecond > 0 && !(e.durationSeconds > 0)) problems.push(`status effect "${id}" deals damage per second but has no duration`)
    if (!isNum(e.damageTakenFactor) || e.damageTakenFactor < 0) problems.push(`status effect "${id}".damageTakenFactor must be >= 0, got ${e.damageTakenFactor}`)
    if (!Number.isInteger(e.displaceTiles) || e.displaceTiles < 0 || e.displaceTiles > MAX_DISPLACE_TILES) problems.push(`status effect "${id}".displaceTiles must be an integer in 0..${MAX_DISPLACE_TILES}, got ${e.displaceTiles}`)
    if (typeof e.immobilize !== 'boolean') problems.push(`status effect "${id}".immobilize must be a boolean`)
    if (typeof e.stacks !== 'boolean') problems.push(`status effect "${id}".stacks must be a boolean`)
    if (e.immobilize === true && e.stacks !== false) problems.push(`status effect "${id}" immobilizes, so it must have stacks: false`)
    if (!Array.isArray(e.extinguishedBy)) problems.push(`status effect "${id}".extinguishedBy must be an array`)
    else if (weatherStates) for (const w of e.extinguishedBy) if (!weatherStates.includes(w)) problems.push(`status effect "${id}".extinguishedBy names unknown weather state "${w}"`)
  }
  return problems
}

/**
 * Problems with the `onHitEffects` of every creature. `creatures` maps a creature key to its list
 * ([{ effect, chance }]); `table` is the status-effect table.
 */
function onHitProblems(creatures, table) {
  const problems = []
  for (const [key, list] of Object.entries(creatures)) {
    if (!Array.isArray(list)) { problems.push(`${key}.onHitEffects must be an array`); continue }
    for (const entry of list) {
      if (entry === null || typeof entry !== 'object') { problems.push(`${key}.onHitEffects has a non-object entry`); continue }
      if (!Object.prototype.hasOwnProperty.call(table, entry.effect)) problems.push(`${key}.onHitEffects names undefined effect "${entry.effect}"`)
      if (typeof entry.chance !== 'number' || !(entry.chance >= 0 && entry.chance <= 1)) problems.push(`${key}.onHitEffects "${entry.effect}" chance must be in 0..1, got ${entry.chance}`)
    }
  }
  return problems
}

/** The `onHitEffects` defaults off the creature entities (those that declare the field). */
function creatureOnHit(creatureEntities) {
  const out = {}
  for (const [key, e] of Object.entries(creatureEntities)) {
    const f = (e.fields || {}).onHitEffects
    if (f) out[key] = f.defaultValue === undefined ? [] : f.defaultValue
  }
  return out
}

function validateCombat(table, creatures, weatherStates) {
  const problems = statusEffectProblems(table, weatherStates).concat(onHitProblems(creatures, table))
  if (problems.length) throw new Error('Combat status-effect table is invalid:\n  ' + problems.join('\n  '))
}

module.exports = {


  CombatSystem: defineEntity({
    tags: ['world-system'],
    description:
      'Defines the rules governing all combat interactions — player vs creature, player vs player, ' +
      'and structure damage. Combat is simulation-driven: outcomes emerge from stats, skills, ' +
      'equipment, and biome conditions rather than authored scripts. ' +
      'Magic and martial paths are balanced by design — neither dominates at every range and context.',
    goal: 'Enforce the MagicBalancedWithMartial and DestructibleBuildings constitution decisions through combat system rules',
    fields: {
      id: { type: 'uuid', primaryKey: true },
      statusEffects: {
        type: 'json',
        description: 'Status-effect table (Phase 129): { <id>: { durationSeconds, damagePerSecond, immobilize, damageTakenFactor, displaceTiles, stacks, extinguishedBy } } (validated at fabric load)',
        defaultValue: STATUS_EFFECTS,
      },
    },
    behaviors: {
      calculateHit: {
        description: 'Determine whether an attack lands and compute base damage',
        rules: [
          'Base hit chance = attacker accuracy stat minus defender evasion stat; minimum 5%, maximum 95%',
          'Swordsmanship: Apprentice or higher adds +10% accuracy for melee attacks',
          'Archery: Apprentice or higher adds +10% accuracy for ranged attacks; reduced by wind speed above 20 km/h',
          'Unarmed attacks against an armoured target deal only 50% of computed damage',
          'Shieldcraft: Apprentice allows the defender to halve the incoming damage once per 5 seconds via executeParry',
        ],
        auth: { roles: ['maintainer'] },
      },
      calculateCritical: {
        description: 'Determine whether a hit is a critical strike and apply the critical multiplier',
        rules: [
          'Base critical strike chance: 5% for all attackers',
          'Swordsmanship: Expert raises melee critical chance by 10%',
          'Archery: Expert raises ranged critical chance by 10% when target is stationary',
          'Critical strikes deal 2× computed damage',
          'Critical strikes from behind deal 2.5× computed damage (position bonus)',
          'Void-phase creatures (VoidSerpent during phase window) cannot receive critical strikes from non-magical attacks',
        ],
        auth: { roles: ['maintainer'] },
      },
      applyStatusEffects: {
        description: 'Apply and tick status effects resulting from attacks or environmental sources',
        rules: [
          'heat-burn (from LavaSlug slime spray): 5 damage per second for 8 seconds; extinguished by rain or water source',
          'Paralysis (from VeilStalker venom): 3-second immobilisation; 20% chance per hit; does not stack',
          'Void corruption (from VoidSerpent, RiftWarden, or void rift biome): accumulates as an integer; see VoidRift.applyHazards for overflow rules',
          'Knockback (from ForestBoar gore): displaces target by 1 tile; cannot exceed map boundary',
          'Knockdown (from Unarmed.executeKnockdown, RiftWarden ground slam): prone state; target takes 1.5× damage from all sources until they stand',
          'Stagger (from Swordsmanship.executePowerStrike, Shieldcraft.executeShieldBash): interrupts current action; 1-second recovery',
          'Status effects are visible in the player HUD and accessible via the game API',
        ],
        auth: { roles: ['maintainer'] },
      },
      resolveMagicInteractions: {
        description: 'Resolve interactions between magical attacks and targets',
        rules: [
          'Elemental Magic attacks deal full damage to all creature tiers',
          'Void Magic attacks bypass creature phase resistance (including VoidSerpent phase window)',
          'VoidTouched players bypass VoidSerpent phase resistance entirely — all attack types deal full damage regardless of phase state',
          'Restoration Magic heals the caster or a targeted ally; cannot be cast in combat without Restoration Magic: Journeyman',
          'Enchanting-buffed weapons count as magical for the purpose of bypassing physical damage reduction',
          'Magic spells consume mana proportional to tier; mana regenerates at 1 point per second out of combat',
          'Magic and martial balance: a Master Swordsmanship player and a Master Elemental Magic player should achieve similar sustained damage output in a 30-second engagement against a tier-3 creature; tuning this ratio is a designer invariant',
        ],
        auth: { roles: ['maintainer'] },
      },
      applyStructureDamage: {
        description: 'Compute and apply damage to player-built structures caught in combat',
        rules: [
          'Explosive attacks (CinderGargoyle cinder breath, void pulses) deal structure damage proportional to base damage',
          'Structures made of ashite blocks receive 50% fire damage reduction',
          'Structures made of thornwood planks are flammable; catch fire on cinder breath contact',
          'Veilsteel-reinforced structures receive 30% all-damage reduction',
          'Structures at 0 HP collapse; wreckage tiles are not cleared automatically',
          'Player-built structure destruction fulfils the DestructibleBuildings constitution decision — all structures are damageable by sufficient force',
        ],
        auth: { roles: ['maintainer'] },
      },
      evaluatePvP: {
        description: 'Apply additional rules governing player-vs-player combat',
        rules: [
          'PvP is unrestricted in VoidRift and VolcanicBadlands biomes',
          'PvP in temperate and twilight biomes requires mutual flagging or active war declaration between guilds',
          'Killing an unflagged player in a non-PvP zone applies the murderer debuff: +50% guard aggression for 24 in-game hours',
          'Loot on player death: equipped item durability decreases by one tier; no inventory drop unless both players are flagged',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}

Object.assign(module.exports, { STATUS_EFFECTS, statusEffectProblems, onHitProblems, creatureOnHit, validateCombat })
