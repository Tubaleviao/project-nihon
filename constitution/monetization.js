const { defineEntity } = require('@newel/core')

module.exports = {
  MonetizationRules: defineEntity({
    tags: ['system'],
    description: 'Monetization policy for Project Nihon: fair, transparent, and never pay-to-win. Revenue funds official server infrastructure and ongoing open-source development.',
    goal: 'Sustain the project financially without compromising gameplay fairness or community trust',
    behaviors: {
      approvePurchaseType: {
        description: 'Approve a new in-game or external purchase type against monetization rules',
        rules: [
          'Purchase must not grant gameplay power, XP acceleration, inventory advantages, or exclusive gear',
          'Cosmetic-only items (skins, emotes, housing decorations, pets) are permitted',
          'One-time Steam purchase is the primary entry point — no free-to-play paywall',
          'Optional monthly subscription grants access to official server infrastructure only, not gameplay advantages',
          'Community servers must remain available without subscription',
          'Expansion DLCs must contain only new regions and art assets with no exclusive power unlocks',
          'Supporter packs may include badges, forum credits, Discord roles, and early test access only',
        ],
        auth: { roles: ['maintainer'] },
      },
      rejectPurchaseType: {
        description: 'Reject a proposed purchase type that violates monetization rules',
        rules: [
          'Any purchase that sells power, XP boosts, inventory upgrades, or premium gear must be rejected',
          'Rejection reason must be documented and linked to the violated rule',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),
}
