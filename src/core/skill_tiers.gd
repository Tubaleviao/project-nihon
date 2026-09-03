extends RefCounted
## Shared skill-tier ordering — single source of truth for tier rank lookups
## across the crafting, trade, and governance slices (previously copy-pasted
## three times). Mirrors the fabric skill state machine
## (fabric/gameplay/skills/shared.js SKILL_TIERS): novice → apprentice →
## journeyman → expert → master.

const TIER_ORDER: Array = ["novice", "apprentice", "journeyman", "expert", "master"]

## Whether `tier` is a known tier name.
static func is_valid_tier(tier: String) -> bool:
	return TIER_ORDER.has(tier)

## Rank of a tier name (0 = novice). Unknown tiers fail closed: they return a
## rank one past `master`, so a guard that requires an unknown tier can never be
## satisfied (the required rank is higher than any real tier).
static func rank(tier: String) -> int:
	var idx := TIER_ORDER.find(tier)
	if idx == -1:
		return TIER_ORDER.size()
	return idx
