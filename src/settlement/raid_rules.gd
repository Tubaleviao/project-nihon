extends RefCounted
## Settlement raid rules (Phase 200, designed in Phase 197) — the pure half: whether a raid may start, which
## pack comes, what a lost raid costs and how defence effects scale that. The settlement slice owns the state
## and the scheduler calls these with plain data. Rules come from the fabric's `SettlementRaids` world system
## (`GameData.WORLD_SYSTEMS["SettlementRaids"].rules`).

const TIER_ORDER := ["founded", "growing", "town"]
const MINUTE_SEC := 60.0
const HOUR_SEC := 3600.0

## Refusal keys, each with catalog text `settlement.raid.refused.<key>`.
const REASONS := ["no_member_online", "too_young", "not_worth_raiding", "cooldown", "raid_active", "no_pack"]

static func table() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("SettlementRaids", null)
	var r: Variant = res.get("rules") if res != null else null
	if r is Dictionary and (r as Dictionary).get("packs", null) is Dictionary:
		return r
	return { "minAgeMinutes": 30, "minTier": "growing", "minStockpileStacks": 10, "cooldownHours": 6, "warningSeconds": 120,
		"durationSeconds": 600, "offlineProtection": true, "defenceCap": 0.75,
		"stakes": { "stockpileShareMax": 0.2, "projectDamageMax": 0.25 }, "packs": {} }

## "" when a raid may start, else the first reason. `info`: { age_sec, tier, stock_stacks, since_last_sec (a
## huge number when none), active (bool), online_in_claim (members online inside the claim), biome }.
static func start_blocker(info: Dictionary, tbl: Dictionary = {}) -> String:
	var t: Dictionary = tbl if not tbl.is_empty() else table()
	if bool(info.get("active", false)):
		return "raid_active"
	if bool(t.get("offlineProtection", true)) and int(info.get("online_in_claim", 0)) < 1:
		return "no_member_online"
	if float(info.get("age_sec", 0.0)) < float(t["minAgeMinutes"]) * MINUTE_SEC:
		return "too_young"
	var tier_ok := TIER_ORDER.find(str(info.get("tier", "founded"))) >= TIER_ORDER.find(str(t["minTier"]))
	if not tier_ok and int(info.get("stock_stacks", 0)) < int(t["minStockpileStacks"]):
		return "not_worth_raiding"
	if float(info.get("since_last_sec", 1.0e12)) < float(t["cooldownHours"]) * HOUR_SEC:
		return "cooldown"
	if not (t["packs"] as Dictionary).has(str(info.get("biome", ""))):
		return "no_pack"
	return ""

## The pack for `biome` as [{ creature, count }], counts drawn between each row's min and max from `roll`
## (a deterministic 0..1 value per row, e.g. a hash of the world seed, settlement and raid count).
static func pack_for(biome: String, rolls: Array, tbl: Dictionary = {}) -> Array:
	var t: Dictionary = tbl if not tbl.is_empty() else table()
	var out: Array = []
	var rows: Array = (t["packs"] as Dictionary).get(biome, [])
	for i in rows.size():
		var lo := int(rows[i]["min"])
		var hi := int(rows[i]["max"])
		var r := clampf(float(rolls[i]) if i < rolls.size() else 0.0, 0.0, 0.999999)
		out.append({ "creature": str(rows[i]["creature"]), "count": lo + int(floor(r * float(hi - lo + 1))) })
	return out

## The share (0..defenceCap) by which standing defence effects scale both losses down.
static func defence_share(defence: float, tbl: Dictionary = {}) -> float:
	var t: Dictionary = tbl if not tbl.is_empty() else table()
	return clampf(defence, 0.0, float(t["defenceCap"]))

## What a lost raid takes: { stock {item: n}, project_damage (share of contributed labour lost, 0..) } for a
## stockpile `stock`. A defended raid takes nothing. Stock loss rounds down per item.
static func losses(defended: bool, stock: Dictionary, defence: float, tbl: Dictionary = {}) -> Dictionary:
	if defended:
		return { "stock": {}, "project_damage": 0.0 }
	var t: Dictionary = tbl if not tbl.is_empty() else table()
	var keep := 1.0 - defence_share(defence, t)
	var share := float(t["stakes"]["stockpileShareMax"]) * keep
	var taken := {}
	for item: String in stock:
		var n := int(floor(float(int(stock[item])) * share))
		if n > 0:
			taken[item] = n
	return { "stock": taken, "project_damage": float(t["stakes"]["projectDamageMax"]) * keep }
