const { defineEntity } = require('@newel/core')

// Player-economy and social-governance systems (Phase 24). These entities are
// the fabric source of truth for the balance numbers the trade, market, and
// governance slices consume at runtime. Keeping the numbers here (not as
// GDScript constants) preserves the fabric-first rule: a balance change is a
// single-source edit that regenerates GameData rather than a hand-edited
// constant buried in a slice.

module.exports = {

  // ─── TradeSystem ───────────────────────────────────────────────────────────
  TradeSystem: defineEntity({
    tags: ['world-system'],
    description:
      'Defines the rules governing player-to-player trade. A trade is a two-party ' +
      'session: each side proposes what they give and want, either may counter-offer, ' +
      'and the exchange commits only when both accept. A broker fee is withheld from ' +
      'the goods a player receives, scaled by their commercial skill tier.',
    goal: 'Ground the EconomyIsPlayerDriven principle in concrete trade mechanics whose balance numbers live in the design bible',
    fields: {
      id: { type: 'uuid', primaryKey: true },
      feeSkill: {
        type: 'string',
        description: 'Social skill whose tier sets the broker fee on player trades. Trade (commercial acumen) — not Diplomacy, which the fabric scopes to NPC factions only.',
        defaultValue: 'Trade',
      },
      brokerFee: {
        type: 'json',
        description: 'Skill tier → fraction of received goods withheld as a broker fee. Higher tier lowers the fee; a master trades tax-free.',
        defaultValue: {
          novice: 0.10,
          apprentice: 0.08,
          journeyman: 0.05,
          expert: 0.02,
          master: 0.0,
        },
      },
    },
    behaviors: {
      resolveExchange: {
        description: 'Commit a trade whose two parties have both accepted',
        rules: [
          'The exchange transfers each party\u2019s give into the counterparty\u2019s inventory',
          'The receiving player\u2019s goods are reduced by the broker fee for their feeSkill tier',
          'A trade with insufficient goods on either side fails without partial transfer',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── MarketSystem ──────────────────────────────────────────────────────────
  MarketSystem: defineEntity({
    tags: ['world-system'],
    description:
      'Defines the rules of the persistent player-run market. Players list items at a ' +
      'price; others browse and buy; listings expire after a configurable duration. ' +
      'Listing deadlines are wall-clock timestamps so a saved listing keeps its real ' +
      'deadline across sessions.',
    goal: 'Make the market a real, persistent economic venue whose expiry window is a single-source balance value',
    fields: {
      id: { type: 'uuid', primaryKey: true },
      defaultExpirySeconds: {
        type: 'integer',
        description: 'Default listing lifetime in seconds before it expires and is removed',
        defaultValue: 3600,
      },
    },
    behaviors: {
      expireListings: {
        description: 'Remove listings whose wall-clock deadline has passed',
        rules: [
          'Deadlines are Unix-epoch wall-clock timestamps, not process uptime',
          'A listing past its deadline is not browsable and cannot be purchased',
          'Expiry emits a market_listing_expired event for each removed listing',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── GovernanceSystem ──────────────────────────────────────────────────────
  GovernanceSystem: defineEntity({
    tags: ['world-system'],
    description:
      'Defines the rules of in-game community governance. Players submit proposals, ' +
      'others vote, and a proposal ratifies only once a quorum of distinct voters has ' +
      'cast ballots within a voting window and a threshold fraction favour the change. ' +
      'The proposal author cannot vote on their own proposal.',
    goal: 'Ground the CommunityOwnsTheFuture principle in anti-gaming governance mechanics (quorum, window, no self-vote)',
    fields: {
      id: { type: 'uuid', primaryKey: true },
      ratification: {
        type: 'json',
        description: 'Ratification parameters: threshold (fraction of cast votes that must favour), quorum (minimum distinct voters), windowSeconds (voting window before the proposal closes).',
        defaultValue: {
          threshold: 0.6,
          quorum: 3,
          windowSeconds: 86400,
        },
      },
      guildMinTier: {
        type: 'string',
        description: 'Minimum Leadership tier required to form a guild',
        defaultValue: 'apprentice',
      },
    },
    behaviors: {
      ratify: {
        description: 'Ratify a proposal that has met quorum, threshold, and window',
        rules: [
          'The proposal author may not vote on their own proposal',
          'Ratification requires at least quorum distinct voters',
          'Votes after the voting window closes are rejected',
          'A ratified proposal is recorded in the runtime decisions log',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
