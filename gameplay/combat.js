const { defineEntity } = require('@newel/core')

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
    },
    behaviors: {
      calculateHit: {
        description: 'Determine whether an attack lands and compute base damage',
        rules: [
          'Base hit chance = attacker accuracy stat minus defender evasion stat; minimum 5%, maximum 95%',
          'Swordsmanship: Apprentice or higher adds +10% accuracy for melee attacks',
          'Archery: Apprentice or higher adds +10% accuracy for ranged attacks; reduced by wind speed above 20 km/h',
          'Unarmed attacks against an armoured target deal only 50% of computed damage',
          'Shieldcraft: Journeyman allows the defender to halve the incoming damage once per 5 seconds via executeParry',
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
          'Burn (from LavaSlug slime spray): 5 damage per second for 8 seconds; extinguished by rain or water source',
          'Paralysis (from VeilStalker venom): 3-second immobilisation; 20% chance per hit; does not stack',
          'Void corruption (from VoidSerpent, RiftWarden, or void rift biome): accumulates as an integer; see VoidRift.applyHazards for overflow rules',
          'Knockback (from ForestBoar gore, SteppeBison charge, RiftWarden slam): displaces target by 1–2 tiles; cannot exceed map boundary',
          'Knockdown (from Unarmed.executeKnockdown): prone state; target takes 1.5× damage from all sources until they stand',
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
