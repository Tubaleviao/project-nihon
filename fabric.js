const { defineFabric } = require('@newel/core')
const { safeMerge } = require('./shared')

const principles   = require('./constitution/principles')
const decisions    = require('./constitution/decisions')
const monetization = require('./constitution/monetization')
const materials    = require('./world/materials')
const biomes       = require('./world/biomes')
const weather      = require('./world/weather')
const creatures    = require('./world/creatures')
const skills       = require('./gameplay/skills')
const professions  = require('./gameplay/professions')
const items        = require('./gameplay/items')
const recipes      = require('./gameplay/recipes')
const technology   = require('./gameplay/technology')
const combat       = require('./gameplay/combat')

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
      MagicBalancedWithMartial:  decisions.MagicBalancedWithMartial,
      DestructibleBuildings:     decisions.DestructibleBuildings,
      KnowledgeByExperimentation: decisions.KnowledgeByExperimentation,
      FictionalMaterials:        decisions.FictionalMaterials,
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
    },
    // World — Biomes + Systems
    {
      TemperateForest:    biomes.TemperateForest,
      TemperateGrassland: biomes.TemperateGrassland,
      VolcanicBadlands:   biomes.VolcanicBadlands,
      TwilightGrove:      biomes.TwilightGrove,
      VoidRift:           biomes.VoidRift,
      WeatherSystem:      weather.WeatherSystem,
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
      FerriteShortSword:        items.FerriteShortSword,
      VeilsteelLongsword:       items.VeilsteelLongsword,
      AethermiteBow:            items.AethermiteBow,
      VoiditeEdge:              items.VoiditeEdge,
      FerriteHelmet:            items.FerriteHelmet,
      VeilsteelChestplate:      items.VeilsteelChestplate,
      DuskfiberCloak:           items.DuskfiberCloak,
      FieldRations:             items.FieldRations,
      AlchemyPotion:            items.AlchemyPotion,
      FerriteIngot:             items.FerriteIngot,
      VeilsteelIngot:           items.VeilsteelIngot,
      ThornwoodPlank:           items.ThornwoodPlank,
      AethermiteDust:           items.AethermiteDust,
      AethermiteShard:          items.AethermiteShard,
      AshiteBlock:              items.AshiteBlock,
      EnchantedAethermiteShard: items.EnchantedAethermiteShard,
      VoidRuneTablet:           items.VoidRuneTablet,
      LumenfiteOrb:             items.LumenfiteOrb,
    },
    // Gameplay — Recipes
    {
      RecipeFerriteIngot:              recipes.RecipeFerriteIngot,
      RecipeVeilsteelIngot:            recipes.RecipeVeilsteelIngot,
      RecipeFerriteShortSword:         recipes.RecipeFerriteShortSword,
      RecipeFerritePick:               recipes.RecipeFerritePick,
      RecipeVeilsteelLongsword:        recipes.RecipeVeilsteelLongsword,
      RecipeVeilsteelChestplate:       recipes.RecipeVeilsteelChestplate,
      RecipeHealthPotion:              recipes.RecipeHealthPotion,
      RecipeStaminaPotion:             recipes.RecipeStaminaPotion,
      RecipeVoidResistPotion:          recipes.RecipeVoidResistPotion,
      RecipeEnchantedAethermiteShard:  recipes.RecipeEnchantedAethermiteShard,
      RecipeAethermiteBow:             recipes.RecipeAethermiteBow,
      RecipeLumenfiteOrb:              recipes.RecipeLumenfiteOrb,
      RecipeVoidRuneTablet:            recipes.RecipeVoidRuneTablet,
      RecipeThornwoodPlank:            recipes.RecipeThornwoodPlank,
      RecipeCarpenterAxe:              recipes.RecipeCarpenterAxe,
      RecipeDuskfiberCloak:            recipes.RecipeDuskfiberCloak,
      RecipeAshiteBlock:               recipes.RecipeAshiteBlock,
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
  ),
})
