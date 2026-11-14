extends RefCounted
## Phase 260 — stone tools: where their inputs come from, read from the fabric's `StoneTools` world system
## (`GameData.WORLD_SYSTEMS["StoneTools"]`). A felled tree drops `fellBranches` branches beside its wood; a
## mined span of natural host rock also yields a loose stone at `looseStoneChance`, decided by the span's
## position so the host's answer never depends on who asks or how often.

const BRANCH := "Branch"
const LOOSE_STONE := "LooseStone"

static func _yields() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("StoneTools", null)
	var v: Variant = res.get("yields") if res != null else null
	return v if v is Dictionary else {}

## The stone tool item keys (empty when the table is absent).
static func tools() -> Array:
	var res: Resource = GameData.WORLD_SYSTEMS.get("StoneTools", null)
	var v: Variant = res.get("tools") if res != null else null
	return v if v is Array else []

## Branches a felled tree drops (0 when the table is absent).
static func fell_branches() -> int:
	return maxi(0, int(_yields().get("fellBranches", 0)))

static func loose_stone_chance() -> float:
	return clampf(float(_yields().get("looseStoneChance", 0.0)), 0.0, 1.0)

## Whether mining the natural span at `tile` whose bottom is `bottom` also knocks a loose stone loose. Pure:
## the same span always answers the same, so mining it again after a reload gives nothing new.
static func loose_stone_at(tile: Vector2i, bottom: float) -> bool:
	var chance := loose_stone_chance()
	if chance <= 0.0:
		return false
	var h := hash([tile.x, tile.y, roundi(bottom * 1000.0), "loose_stone"])
	return float(posmod(h, 10000)) / 10000.0 < chance
