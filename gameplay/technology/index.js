const { defineEntity } = require('@newel/core')

const TECH_STATES = ['locked', 'researching', 'unlocked']

function technologyStateMachine() {
  return {
    field: 'status',
    initial: 'locked',
    states: {
      locked:      'Prerequisites not yet met; technology is not visible in the research interface',
      researching: 'Player or guild has committed resources; research progresses over time',
      unlocked:    { description: 'Research complete; all associated recipes and abilities are available', terminal: true },
    },
    transitions: [
      { from: 'locked',      to: 'researching', trigger: 'beginResearch' },
      { from: 'researching', to: 'unlocked',    trigger: 'completeResearch' },
    ],
  }
}

module.exports = {

  // ─── TechBasicSmithing ────────────────────────────────────────────────────
  TechBasicSmithing: defineEntity({
    tags: ['technology'],
    description:
      'Foundational metalworking knowledge. Unlocks the forge structure, ferrite smelting, ' +
      'and all Smithing: Novice recipes. Every civilization needs this first.',
    goal: 'Root node of the smithing tree; accessible to all players from the opening hours',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: TECH_STATES },
      researchCost: { type: 'integer', description: 'Research points required to complete' },
      tier:   { type: 'integer', description: 'Technology tree tier (1 = root)' },
    },
    relations: {
      unlocksRecipeFerriteIngot:     { name: 'unlocksRecipeFerriteIngot',     kind: 'hasOne', target: 'RecipeFerriteIngot' },
      unlocksRecipeFerriteShortSword: { name: 'unlocksRecipeFerriteShortSword', kind: 'hasOne', target: 'RecipeFerriteShortSword' },
      unlocksRecipeFerritePick:      { name: 'unlocksRecipeFerritePick',      kind: 'hasOne', target: 'RecipeFerritePick' },
    },
    stateMachine: technologyStateMachine(),
    behaviors: {
      beginResearch: {
        description: 'Commit resources to researching basic smithing',
        rules: [
          'No prerequisites required',
          'Research requires a campfire or forge in the player\'s settlement',
        ],
        auth: { roles: ['maintainer'] },
      },
      completeResearch: {
        description: 'Finish research and unlock all basic smithing recipes',
        rules: ['Research cost fully paid; all related recipes become craftable'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── TechMasterForge ──────────────────────────────────────────────────────
  TechMasterForge: defineEntity({
    tags: ['technology'],
    description:
      'Advanced forge construction and temperature-control techniques. ' +
      'Unlocks the master forge structure and veilsteel recipes. ' +
      'Requires basic smithing and a supply of ashite blocks.',
    goal: 'Mid-tier smithing unlock; drives cross-biome supply chains (volcanic ashite to temperate smiths)',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: TECH_STATES },
      researchCost: { type: 'integer', description: 'Research points required to complete' },
      tier:   { type: 'integer', description: 'Technology tree tier' },
    },
    relations: {
      requiresTechBasicSmithing:        { name: 'requiresTechBasicSmithing',        kind: 'hasOne', target: 'TechBasicSmithing' },
      unlocksRecipeVeilsteelIngot:      { name: 'unlocksRecipeVeilsteelIngot',      kind: 'hasOne', target: 'RecipeVeilsteelIngot' },
      unlocksRecipeVeilsteelLongsword:  { name: 'unlocksRecipeVeilsteelLongsword',  kind: 'hasOne', target: 'RecipeVeilsteelLongsword' },
      unlocksRecipeVeilsteelChestplate: { name: 'unlocksRecipeVeilsteelChestplate', kind: 'hasOne', target: 'RecipeVeilsteelChestplate' },
    },
    stateMachine: technologyStateMachine(),
    behaviors: {
      beginResearch: {
        description: 'Commit resources to master forge research',
        rules: [
          'Requires TechBasicSmithing: unlocked',
          'Requires Smithing: Journeyman',
          'Requires at least ten ashite blocks in settlement storage',
        ],
        auth: { roles: ['maintainer'] },
      },
      completeResearch: {
        description: 'Finish research; master forge blueprint and veilsteel recipes become available',
        rules: ['Research cost fully paid'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── TechBasicCarpentry ───────────────────────────────────────────────────
  TechBasicCarpentry: defineEntity({
    tags: ['technology'],
    description:
      'Foundation woodworking knowledge. Unlocks the carpentry bench, plank milling, ' +
      'and basic wood-component recipes.',
    goal: 'Root node of the carpentry tree; parallel to basic smithing for wood-primary builds',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: TECH_STATES },
      researchCost: { type: 'integer', description: 'Research points required to complete' },
      tier:   { type: 'integer', description: 'Technology tree tier (1 = root)' },
    },
    relations: {
      unlocksRecipeThornwoodPlank: { name: 'unlocksRecipeThornwoodPlank', kind: 'hasOne', target: 'RecipeThornwoodPlank' },
      unlocksRecipeCarpenterAxe:   { name: 'unlocksRecipeCarpenterAxe',   kind: 'hasOne', target: 'RecipeCarpenterAxe' },
    },
    stateMachine: technologyStateMachine(),
    behaviors: {
      beginResearch: {
        description: 'Commit resources to basic carpentry research',
        rules: ['No prerequisites; requires a stockpile of thornwood logs'],
        auth: { roles: ['maintainer'] },
      },
      completeResearch: {
        description: 'Finish research and unlock carpentry bench blueprint and wood recipes',
        rules: ['Research cost fully paid'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── TechTextileWeaving ───────────────────────────────────────────────────
  TechTextileWeaving: defineEntity({
    tags: ['technology'],
    description:
      'Fiber processing and loom construction techniques. ' +
      'Unlocks duskfiber weaving and the cloak recipe. Depends on basic carpentry for the loom frame.',
    goal: 'Textile branch of carpentry tree; enables light-armour and stealth-build gear',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: TECH_STATES },
      researchCost: { type: 'integer', description: 'Research points required to complete' },
      tier:   { type: 'integer', description: 'Technology tree tier' },
    },
    relations: {
      requiresTechBasicCarpentry:  { name: 'requiresTechBasicCarpentry',  kind: 'hasOne', target: 'TechBasicCarpentry' },
      unlocksRecipeDuskfiberCloak: { name: 'unlocksRecipeDuskfiberCloak', kind: 'hasOne', target: 'RecipeDuskfiberCloak' },
      unlocksRecipeAshiteBlock:    { name: 'unlocksRecipeAshiteBlock',    kind: 'hasOne', target: 'RecipeAshiteBlock' },
    },
    stateMachine: technologyStateMachine(),
    behaviors: {
      beginResearch: {
        description: 'Commit resources to textile weaving research',
        rules: [
          'Requires TechBasicCarpentry: unlocked',
          'Requires a duskfiber supply (Twilight Grove access)',
        ],
        auth: { roles: ['maintainer'] },
      },
      completeResearch: {
        description: 'Finish research; loom blueprint and duskfiber recipes become available',
        rules: ['Research cost fully paid'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── TechArcaneForging ────────────────────────────────────────────────────
  TechArcaneForging: defineEntity({
    tags: ['technology'],
    description:
      'Magical metallurgy principles. Unlocks the arcane forge structure and all arcane crafting recipes ' +
      'including aethermite shard imbuing and the aethermite bow.',
    goal: 'Bridge technology linking the smithing and magic trees; requires both paths to unlock',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: TECH_STATES },
      researchCost: { type: 'integer', description: 'Research points required to complete' },
      tier:   { type: 'integer', description: 'Technology tree tier' },
    },
    relations: {
      requiresTechBasicSmithing:            { name: 'requiresTechBasicSmithing',            kind: 'hasOne', target: 'TechBasicSmithing' },
      requiresTechAlchemy:                  { name: 'requiresTechAlchemy',                  kind: 'hasOne', target: 'TechAlchemy' },
      unlocksRecipeEnchantedAethermiteShard: { name: 'unlocksRecipeEnchantedAethermiteShard', kind: 'hasOne', target: 'RecipeEnchantedAethermiteShard' },
      unlocksRecipeAethermiteBow:           { name: 'unlocksRecipeAethermiteBow',           kind: 'hasOne', target: 'RecipeAethermiteBow' },
      unlocksRecipeLumenfiteOrb:            { name: 'unlocksRecipeLumenfiteOrb',            kind: 'hasOne', target: 'RecipeLumenfiteOrb' },
    },
    stateMachine: technologyStateMachine(),
    behaviors: {
      beginResearch: {
        description: 'Commit resources to arcane forging research',
        rules: [
          'Requires TechBasicSmithing: unlocked',
          'Requires TechAlchemy: unlocked',
          'Requires Arcane Forging: Apprentice',
        ],
        auth: { roles: ['maintainer'] },
      },
      completeResearch: {
        description: 'Finish research; arcane forge blueprint and arcane recipes become available',
        rules: ['Research cost fully paid'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── TechAlchemy ──────────────────────────────────────────────────────────
  TechAlchemy: defineEntity({
    tags: ['technology'],
    description:
      'Basic alchemical knowledge. Unlocks the alchemy bench and foundational potion recipes ' +
      'including health and stamina potions.',
    goal: 'Root node of the alchemy tree; independent of smithing, can be researched in parallel',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: TECH_STATES },
      researchCost: { type: 'integer', description: 'Research points required to complete' },
      tier:   { type: 'integer', description: 'Technology tree tier (1 = root)' },
    },
    relations: {
      unlocksRecipeHealthPotion:  { name: 'unlocksRecipeHealthPotion',  kind: 'hasOne', target: 'RecipeHealthPotion' },
      unlocksRecipeStaminaPotion: { name: 'unlocksRecipeStaminaPotion', kind: 'hasOne', target: 'RecipeStaminaPotion' },
    },
    stateMachine: technologyStateMachine(),
    behaviors: {
      beginResearch: {
        description: 'Commit resources to alchemy research',
        rules: [
          'No smithing prerequisite; requires an aethermite ore sample to begin',
        ],
        auth: { roles: ['maintainer'] },
      },
      completeResearch: {
        description: 'Finish research; alchemy bench blueprint and basic potion recipes unlock',
        rules: ['Research cost fully paid'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── TechVoidMastery ──────────────────────────────────────────────────────
  TechVoidMastery: defineEntity({
    tags: ['technology'],
    description:
      'Esoteric void-smithing and void-brewing techniques. ' +
      'Unlocks void-resist potion brewing and the void rune tablet recipe. ' +
      'Cannot be discovered through normal research — it is reverse-engineered from surviving void exposure.',
    goal: 'Endgame technology node; forces players to risk void-biome exploration before this branch opens',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: TECH_STATES },
      researchCost: { type: 'integer', description: 'Research points required to complete' },
      tier:   { type: 'integer', description: 'Technology tree tier (highest)' },
    },
    relations: {
      requiresTechArcaneForging:       { name: 'requiresTechArcaneForging',       kind: 'hasOne', target: 'TechArcaneForging' },
      requiresTechAlchemy:             { name: 'requiresTechAlchemy',             kind: 'hasOne', target: 'TechAlchemy' },
      unlocksRecipeVoidResistPotion:   { name: 'unlocksRecipeVoidResistPotion',   kind: 'hasOne', target: 'RecipeVoidResistPotion' },
      unlocksRecipeVoidRuneTablet:     { name: 'unlocksRecipeVoidRuneTablet',     kind: 'hasOne', target: 'RecipeVoidRuneTablet' },
    },
    stateMachine: technologyStateMachine(),
    behaviors: {
      beginResearch: {
        description: 'Begin reverse-engineering void techniques after direct void exposure',
        rules: [
          'Requires TechArcaneForging: unlocked',
          'Requires TechAlchemy: unlocked',
          'Player must hold voidBurstSurvivor flag',
          'Cannot be initiated from a research interface — begins automatically on first successful Voidite.refine',
        ],
        auth: { roles: ['maintainer'] },
      },
      completeResearch: {
        description: 'Finish void mastery research; void-tier recipes become available',
        rules: [
          'Research cost fully paid',
          'The VoidTouched profession is required to use the unlocked recipes',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
