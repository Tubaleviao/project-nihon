extends RefCounted
## Shared skill-tier ordering — single source of truth for tier rank lookups
## across the crafting, trade, and governance slices (previously copy-pasted
## three times). Mirrors the fabric skill state machine
## (fabric/gameplay/skills/shared.js SKILL_TIERS): novice → apprentice →
## journeyman → expert → master.

const TIER_ORDER: Array = ["novice", "apprentice", "journeyman", "expert", "master"]

## Rank of a tier name (0 = novice). Returns -1 for an unknown tier.
static func rank(tier: String) -> int:
	return TIER_ORDER.find(tier)
