const { defineEntity } = require('@newel/core')

module.exports = {
  PlayersAreTheContent: defineEntity({
    description: 'Players are the content — there are no scripted quests; the world is shaped entirely by player action, economy, and politics.',
    behaviors: {
      enforce: {
        description: 'Gate design decisions that would replace player-driven content with scripted story',
        rules: [
          'No scripted quest lines that substitute for player agency',
          'World events must emerge from player interaction or world systems, not authored cutscenes',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  FreedomComesFirst: defineEntity({
    description: 'Freedom comes first — players choose who to be, what to build, and how to play without imposed class or story restrictions.',
    behaviors: {
      enforce: {
        description: 'Reject design choices that lock players into predetermined roles',
        rules: [
          'No hard class system; skill-based progression only',
          'Players may respec or combine skills freely',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  TheWorldIsPersistent: defineEntity({
    description: 'The world is persistent — changes made by players endure; nothing resets without deliberate world-event mechanics.',
    behaviors: {
      enforce: {
        description: 'Ensure all world state is durable across sessions',
        rules: [
          'Player constructions, resource depletion, and political state must persist between sessions',
          'Server downtime must not roll back player progress',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  SystemsOverScripts: defineEntity({
    description: 'Systems over scripts — dynamic simulation rules produce emergent outcomes rather than authored event sequences.',
    behaviors: {
      enforce: {
        description: 'Prefer rule-based simulation over hand-authored content',
        rules: [
          'Buildings are destroyed by physics/fire/siege systems, not arbitrary designer flags',
          'NPC behavior is driven by AI goals and world state, not scripted dialogue trees',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  KnowledgeIsProgression: defineEntity({
    description: 'Knowledge is progression — players advance by discovering how the world works, not by grinding XP bars.',
    behaviors: {
      enforce: {
        description: 'Design progression gated on discovery and experimentation',
        rules: [
          'Crafting recipes are discovered through experimentation, not purchased from vendors',
          'No automatic XP rewards for routine repetition without new discovery',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  CivilizationIsPlayerMade: defineEntity({
    description: 'Civilization is player-made — towns, governments, economies, and infrastructure are built and maintained by players.',
    behaviors: {
      enforce: {
        description: 'Prevent designer-placed permanent cities and scripted economies',
        rules: [
          'No permanent NPC cities that players cannot destroy or absorb',
          'Markets, roads, and governance structures must be player-initiated',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  BelievableNotRealistic: defineEntity({
    description: 'Believable, not realistic — the world has internal consistency and lore logic rather than real-world physics fidelity.',
    behaviors: {
      enforce: {
        description: 'Balance simulation depth against gameplay accessibility',
        rules: [
          'Fictional materials follow consistent in-world rules, not real metallurgy',
          'Magic and martial systems must be internally balanced; realism is secondary to fairness',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  EverythingHasTradeoffs: defineEntity({
    description: 'Everything has trade-offs — no dominant strategy; every choice sacrifices something.',
    behaviors: {
      enforce: {
        description: 'Identify and correct dominant strategies in system design',
        rules: [
          'Every material, skill, and technology has a meaningful weakness',
          'Fast travel alternatives (mounts, trains, airships) must require infrastructure investment',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  CommunityOwnsTheFuture: defineEntity({
    description: 'Community owns the future — the game is open-source and its direction is shaped by contributor consensus.',
    behaviors: {
      enforce: {
        description: 'Preserve community governance over design decisions',
        rules: [
          'Major design decisions must be proposed publicly and ratified by the community',
          'No proprietary forks that restrict contribution',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  NoPayToWin: defineEntity({
    description: 'No pay-to-win — monetary transactions never grant gameplay advantages over non-paying players.',
    behaviors: {
      enforce: {
        description: 'Block any monetization mechanism that affects gameplay balance',
        rules: [
          'Cosmetics only in the shop; no power, XP boosts, inventory upgrades, or exclusive gear',
          'Optional subscription grants access to official server infrastructure, not gameplay advantages',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),
}
