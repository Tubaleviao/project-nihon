const { defineFabric } = require('@newel/core')
const { safeMerge } = require('./shared')

const principles   = require('./constitution/principles')
const decisions    = require('./constitution/decisions')
const monetization = require('./constitution/monetization')
const materials    = require('./world/materials')
const biomes       = require('./world/biomes')
const weather      = require('./world/weather')
const world        = require('./world/world')
const creatures    = require('./world/creatures')
const skills       = require('./gameplay/skills')
const professions  = require('./gameplay/professions')
const items        = require('./gameplay/items')
const recipes      = require('./gameplay/recipes')
const technology   = require('./gameplay/technology')
const waystone     = require('./gameplay/waystone')
const settlement   = require('./gameplay/settlement')
const combat       = require('./gameplay/combat')
const economy      = require('./gameplay/economy')
const player       = require('./gameplay/player')
const loot         = require('./gameplay/loot')
const gestures     = require('./gameplay/gestures')
const harvest      = require('./gameplay/harvest')
const attributes   = require('./gameplay/attributes')
const persistence  = require('./gameplay/persistence')
const skeletons    = require('./gameplay/characters/skeletons')
const palettes     = require('./gameplay/characters/palettes')
const appearances  = require('./gameplay/characters/appearances')
const creation     = require('./gameplay/characters/creation')
const bed          = require('./gameplay/bed')
const tutorial     = require('./gameplay/tutorial')
const work         = require('./gameplay/work')
const clan         = require('./gameplay/clan')
const structure    = require('./gameplay/structure')
const chests       = require('./gameplay/chests')
const writing      = require('./gameplay/writing')

// Phase 125 — the travel cost must name a real item; throwing fails `npm run validate`.
waystone.validateTravel(waystone.TRAVEL, Object.keys(items))

// Phase 128 — the weather table must be well formed and every biome must reach a state.
weather.validateWeather(weather.RULES, weather.biomeClimates(biomes))

// Phase 139 — the settlement rule table must be well formed (thresholds in order); Phase 203: it names no claim.
settlement.validateSettlement(settlement.RULES, [...Object.keys(items), 'Hearth'])
// Phase 197 — projects and specialties must name real items, skills, attributes and placeable stations;
// Phase 203: no project labour or effects, no raids or upkeep.
settlement.validateSettlementLoop(settlement.settlementLoopData(), settlement.settlementLoopRefs())

// Phase 203 — research is per player: no technology names a settlement research site or stockpile.
technology.validateSettlementRefs()

// Phase 203 — clans, owned structures, durability, respawning, chests and doors, writing and work skills.
clan.validateClan(clan.clanData(), clan.clanRefs())
structure.validateStructure(structure.structureData(), structure.structureRefs())
chests.validateChests(chests.chestsData(), chests.chestsRefs())
writing.validateWriting(writing.writingData(), writing.writingRefs())
work.validateWork(work.workData(), work.workRefs())

// Phase 129 — the status-effect table must be well formed and every creature's `onHitEffects` must name a defined effect.
combat.validateCombat(combat.STATUS_EFFECTS, combat.creatureOnHit(creatures), Object.keys(weather.RULES.states))

// Phase 136 — every creature's ground-movement fields must be in range; throwing fails `npm run validate`.
require('./world/creatures/shared').validatePathFields(creatures)
require('./world/creatures/shared').validateSkeletonFields(creatures)
// Phase 192 — every creature declares a body footprint and squash in range.
require('./world/creatures/shared').validateBodyFields(creatures)

// Phase 137 — every biome's `surfaceMaterial` must declare whether it is `granular` (settles when undermined).
require('./world/materials/granular').validateGranular(require('./world/biomes'), materials)

// Phase 158 — the gesture table must be well formed (known kinds, unique chat commands, restRegen >= 1).
gestures.validateGestures(gestures.gestureTable())

// Phase 160 — every harvest entry must name a tool category some item provides and a real skill, every creature needs a
// carcass mass, and the Skinning yield and quality tables must cover every level and never fall.
harvest.validateHarvest(harvest.harvestData({ creatures, items, skills }))

// Phase 177 — the attribute bounds, derivation and growth tables must be well formed, base 10 must reproduce today's
// constants, and every skill category needs a growth row.
attributes.validateAttributes(attributes.attributeData())

// Phase 180 — character creation: every gender preset, hair style and colour must point at real data, each gender
// needs a hair style, the chibi presets keep their head ratio and the default creation must be valid.
creation.validateCreation(creation.creationData(), creation.creationRefs())

// Phase 184 — the bed rule must name a real placement item and a sane shelter rule; every tutorial step needs a unique
// id, earlier `requires`, a known trigger kind with exactly its params, and params that name real fabric data.
bed.validateBed(bed.RULES, Object.keys(items))
tutorial.validateTutorial(tutorial.tutorialData(), tutorial.tutorialRefs())

// Phase 151 — every entity tagged `item` needs a shape: a known archetype, and a real material for each of its parts.
{
  const { validateShapes } = require('./gameplay/items/shape')
  validateShapes({ ...items, Hearth: settlement.Hearth }, Object.keys(materials))
}

module.exports = defineFabric({
  meta: {
    name:        'project-nihon',
    version:     '0.2.0',
    description: 'Open-source sandbox MMORPG where players build a civilization. ' +
                 'The world is persistent, expands over time, and evolves through player interaction. ' +
                 'This fabric encodes the game\'s design bible — materials, skills, items, creatures, ' +
                 'and world systems — as a single source of truth.',
  },
  entities: safeMerge('fabric',
    // Constitution — Principles
    {
      PlayersAreTheContent:    principles.PlayersAreTheContent,
      FreedomComesFirst:       principles.FreedomComesFirst,
      TheWorldIsPersistent:    principles.TheWorldIsPersistent,
      SystemsOverScripts:      principles.SystemsOverScripts,
      KnowledgeIsProgression:  principles.KnowledgeIsProgression,
      CivilizationIsPlayerMade: principles.CivilizationIsPlayerMade,
      BelievableNotRealistic:  principles.BelievableNotRealistic,
      EverythingHasTradeoffs:  principles.EverythingHasTradeoffs,
      CommunityOwnsTheFuture:  principles.CommunityOwnsTheFuture,
      NoPayToWin:              principles.NoPayToWin,
    },
    // Constitution — Decisions + Monetization
    {
      GodotEngine:               decisions.GodotEngine,
      OnePersistentWorld:        decisions.OnePersistentWorld,
      OfflinePlayerNpcs:         decisions.OfflinePlayerNpcs,
      NoTeleportation:           decisions.NoTeleportation,
      WaystonesAmendNoTeleportation: decisions.WaystonesAmendNoTeleportation,
      SettlementClaimAndDecay:   decisions.SettlementClaimAndDecay,
      SettlementRaidsAndUpkeep:  decisions.SettlementRaidsAndUpkeep,
      ClansAndOwnedStructures:   decisions.ClansAndOwnedStructures,
      DurabilityAndDestruction:  decisions.DurabilityAndDestruction,
      ResearchSharedByWriting:   decisions.ResearchSharedByWriting,
      SkillsGrowFromWork:        decisions.SkillsGrowFromWork,
      EarthScaleHeights:         decisions.EarthScaleHeights,
      MagicBalancedWithMartial:  decisions.MagicBalancedWithMartial,
      DestructibleBuildings:     decisions.DestructibleBuildings,
      KnowledgeByExperimentation: decisions.KnowledgeByExperimentation,
      FictionalMaterials:        decisions.FictionalMaterials,
      PlayerIdentityModel:       decisions.PlayerIdentityModel,
      MonetizationRules:         monetization.MonetizationRules,
    },
    // World — Materials
    {
      Ferrite:    materials.Ferrite,
      Veilsteel:  materials.Veilsteel,
      Aethermite: materials.Aethermite,
      Voidite:    materials.Voidite,
      Thornwood:  materials.Thornwood,
      Duskfiber:  materials.Duskfiber,
      Ashite:     materials.Ashite,
      Lumenfite:  materials.Lumenfite,
      Grass:      materials.Grass,
      Soil:       materials.Soil,
      Sand:       materials.Sand,
      Snow:       materials.Snow,
    },
    // World — Biomes + Systems
    {
      TemperateForest:    biomes.TemperateForest,
      TemperateGrassland: biomes.TemperateGrassland,
      VolcanicBadlands:   biomes.VolcanicBadlands,
      TwilightGrove:      biomes.TwilightGrove,
      VoidRift:           biomes.VoidRift,
      Ocean:              biomes.Ocean,
      Beach:              biomes.Beach,
      Desert:             biomes.Desert,
      Tundra:             biomes.Tundra,
      Alpine:             biomes.Alpine,
      Taiga:              biomes.Taiga,
      Savanna:            biomes.Savanna,
      WeatherSystem:      weather.WeatherSystem,
      WorldSystem:        world.WorldSystem,
    },
    // Gameplay — Skills
    {
      Swordsmanship:   skills.Swordsmanship,
      Archery:         skills.Archery,
      Shieldcraft:     skills.Shieldcraft,
      Unarmed:         skills.Unarmed,
      Smithing:        skills.Smithing,
      Carpentry:       skills.Carpentry,
      Alchemy:         skills.Alchemy,
      ArcaneForging:   skills.ArcaneForging,
      VoidSmithing:    skills.VoidSmithing,
      ElementalMagic:  skills.ElementalMagic,
      VoidMagic:       skills.VoidMagic,
      RestorationMagic: skills.RestorationMagic,
      Enchanting:      skills.Enchanting,
      Cartography:     skills.Cartography,
      Tracking:        skills.Tracking,
      Stealth:         skills.Stealth,
      Navigation:      skills.Navigation,
      Diplomacy:       skills.Diplomacy,
      Trade:           skills.Trade,
      Speechcraft:     skills.Speechcraft,
      Leadership:      skills.Leadership,
      Skinning:        skills.Skinning,
      Building:        skills.Building,
      Tailoring:       skills.Tailoring,
      Lockpicking:     skills.Lockpicking,
    },
    // Gameplay — Professions
    {
      Blacksmith:  professions.Blacksmith,
      Arcanist:    professions.Arcanist,
      Ranger:      professions.Ranger,
      Warrior:     professions.Warrior,
      Alchemist:   professions.Alchemist,
      Merchant:    professions.Merchant,
      Pathfinder:  professions.Pathfinder,
      VoidTouched: professions.VoidTouched,
    },
    // Gameplay — Items
    {
      FerritePick:              items.FerritePick,
      VeilsteelPick:            items.VeilsteelPick,
      CarpenterAxe:             items.CarpenterAxe,
      SkinningKnife:            items.SkinningKnife,
      BoneSaw:                  items.BoneSaw,
      Lockpick:                 items.Lockpick,
      FerriteShortSword:        items.FerriteShortSword,
      VeilsteelLongsword:       items.VeilsteelLongsword,
      AethermiteBow:            items.AethermiteBow,
      VoiditeEdge:              items.VoiditeEdge,
      FerriteHelmet:            items.FerriteHelmet,
      VeilsteelChestplate:      items.VeilsteelChestplate,
      DuskfiberCloak:           items.DuskfiberCloak,
      NoviceTunic:              items.NoviceTunic,
      FerriteShield:            items.FerriteShield,
      FieldRations:             items.FieldRations,
      AlchemyPotion:            items.AlchemyPotion,
      FerriteIngot:             items.FerriteIngot,
      VeilsteelIngot:           items.VeilsteelIngot,
      ThornwoodPlank:           items.ThornwoodPlank,
      Waystone:                 items.Waystone,
      AethermiteDust:           items.AethermiteDust,
      AethermiteShard:          items.AethermiteShard,
      RefinedVoiditeShard:      items.RefinedVoiditeShard,
      AshiteBlock:              items.AshiteBlock,
      EnchantedAethermiteShard: items.EnchantedAethermiteShard,
      VoidRuneTablet:           items.VoidRuneTablet,
      LumenfiteOrb:             items.LumenfiteOrb,
      Bed:                      items.Bed,
      Chest:                    items.Chest,
      Door:                     items.Door,
    },
    // Gameplay — Gestures
    gestures.GESTURES,
    // Gameplay — Recipes
    {
      RecipeFerriteIngot:              recipes.RecipeFerriteIngot,
      RecipeVeilsteelIngot:            recipes.RecipeVeilsteelIngot,
      RecipeFerriteShortSword:         recipes.RecipeFerriteShortSword,
      RecipeFerritePick:               recipes.RecipeFerritePick,
      RecipeSkinningKnife:             recipes.RecipeSkinningKnife,
      RecipeBoneSaw:                   recipes.RecipeBoneSaw,
      RecipeLockpick:                  recipes.RecipeLockpick,
      RecipeVeilsteelLongsword:        recipes.RecipeVeilsteelLongsword,
      RecipeVeilsteelChestplate:       recipes.RecipeVeilsteelChestplate,
      RecipeHealthPotion:              recipes.RecipeHealthPotion,
      RecipeStaminaPotion:             recipes.RecipeStaminaPotion,
      RecipeVoidResistPotion:          recipes.RecipeVoidResistPotion,
      RecipeEnchantedAethermiteShard:  recipes.RecipeEnchantedAethermiteShard,
      RecipeAethermiteBow:             recipes.RecipeAethermiteBow,
      RecipeLumenfiteOrb:              recipes.RecipeLumenfiteOrb,
      RecipeVoidRuneTablet:            recipes.RecipeVoidRuneTablet,
      RecipeRefinedVoiditeShard:       recipes.RecipeRefinedVoiditeShard,
      RecipeThornwoodPlank:            recipes.RecipeThornwoodPlank,
      RecipeWaystone:                  recipes.RecipeWaystone,
      RecipeCarpenterAxe:              recipes.RecipeCarpenterAxe,
      RecipeDuskfiberCloak:            recipes.RecipeDuskfiberCloak,
      RecipeNoviceTunic:               recipes.RecipeNoviceTunic,
      RecipeAshiteBlock:               recipes.RecipeAshiteBlock,
      RecipeBed:                       recipes.RecipeBed,
      RecipeChest:                     recipes.RecipeChest,
      RecipeDoor:                      recipes.RecipeDoor,
    },
    // Gameplay — Technology
    {
      TechBasicSmithing:  technology.TechBasicSmithing,
      TechMasterForge:    technology.TechMasterForge,
      TechBasicCarpentry: technology.TechBasicCarpentry,
      TechTextileWeaving: technology.TechTextileWeaving,
      TechArcaneForging:  technology.TechArcaneForging,
      TechAlchemy:        technology.TechAlchemy,
      TechVoidMastery:    technology.TechVoidMastery,
      ResearchPointRule:  technology.ResearchPointRule,
      WaystoneTravel:     waystone.WaystoneTravel,
      BedSpawn:           bed.BedSpawn,
    },
    // Gameplay — Settlements (Phase 139)
    {
      Settlement:   settlement.Settlement,
      Hearth:       settlement.Hearth,
      RecipeHearth: settlement.RecipeHearth,
      Stockpile:    settlement.Stockpile,
      // Phase 197 — the settlement loop
      SettlementProjects:    settlement.SettlementProjects,
      SettlementSpecialties: settlement.SettlementSpecialties,
    },
    // Gameplay — Clans, owned structures, chests and doors, writing and work skills (Phase 203)
    {
      Clan:                clan.Clan,
      ClanTiers:           clan.ClanTiers,
      Structure:           structure.Structure,
      StructureDurability: structure.StructureDurability,
      SelfRespawn:         structure.SelfRespawn,
      ChestsAndDoors:      chests.ChestsAndDoors,
      Book:                writing.Book,
      Blueprint:           writing.Blueprint,
      WorkSkills:          work.WorkSkills,
    },
    // World — Creatures
    {
      ForestBoar:     creatures.ForestBoar,
      GraywolfPack:   creatures.GraywolfPack,
      SteppeBison:    creatures.SteppeBison,
      RidgeHawk:      creatures.RidgeHawk,
      LavaSlug:       creatures.LavaSlug,
      CinderGargoyle: creatures.CinderGargoyle,
      GlimmerFox:     creatures.GlimmerFox,
      VeilStalker:    creatures.VeilStalker,
      VoidSerpent:    creatures.VoidSerpent,
      RiftWarden:     creatures.RiftWarden,
    },
    // Gameplay — Combat system
    { CombatSystem: combat.CombatSystem },
    // Gameplay — Server persistence + save lifecycle (Phase 33)
    { PersistenceSystem: persistence.PersistenceSystem },
    // Gameplay — Player economy + governance systems (Phase 24)
    {
      TradeSystem:      economy.TradeSystem,
      MarketSystem:     economy.MarketSystem,
      GovernanceSystem: economy.GovernanceSystem,
    },
    // Gameplay — Player + Inventory
    {
      AttributeSystem: attributes.AttributeSystem,
      PlayerCharacter: player.PlayerCharacter,
      Inventory:       player.Inventory,
    },
    // Gameplay — Loot + Death signals
    {
      LootTable:   loot.LootTable,
      DeathSignal: loot.DeathSignal,
      HarvestRules: harvest.HarvestRules,
    },
    // Gameplay — Character system (skeletons, palette, appearance recipes)
    {
      HumanoidSkeleton: skeletons.HumanoidSkeleton,
      QuadrupedSkeleton: skeletons.QuadrupedSkeleton,
      BirdSkeleton:      skeletons.BirdSkeleton,
      SerpentSkeleton:   skeletons.SerpentSkeleton,
      DefaultPalette:    palettes.DefaultPalette,
      NoviceMasculine:   appearances.NoviceMasculine,
      NoviceFeminine:    appearances.NoviceFeminine,
      TravellerHuman:    appearances.TravellerHuman,
      BoarRider:         appearances.BoarRider,
      CharacterCreation: creation.CharacterCreation,
    },
    // Gameplay — First-steps tutorial (Phase 184)
    { Tutorial: tutorial.Tutorial },
  ),
})
