const { defineFabric } = require('@newel/core')

const principles   = require('./constitution/principles')
const decisions    = require('./constitution/decisions')
const monetization = require('./constitution/monetization')

module.exports = defineFabric({
  meta: {
    name:        'project-nihon',
    version:     '0.1.0',
    description: 'Open-source sandbox MMORPG where players build a civilization. ' +
                 'The world is persistent, expands over time, and evolves through player interaction. ' +
                 'This fabric encodes the game\'s design bible — materials, skills, items, creatures, ' +
                 'and world systems — as a single source of truth.',
  },
  entities: {
    // Constitution — Principles
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

    // Constitution — Decisions
    GodotEngine:               decisions.GodotEngine,
    OnePersistentWorld:        decisions.OnePersistentWorld,
    OfflinePlayerNpcs:         decisions.OfflinePlayerNpcs,
    NoTeleportation:           decisions.NoTeleportation,
    MagicBalancedWithMartial:  decisions.MagicBalancedWithMartial,
    DestructibleBuildings:     decisions.DestructibleBuildings,
    KnowledgeByExperimentation: decisions.KnowledgeByExperimentation,
    FictionalMaterials:        decisions.FictionalMaterials,

    // Constitution — Monetization
    MonetizationRules: monetization.MonetizationRules,
  },
})
