extends RefCounted
## Structure limits (Phase 212) — what a structure's materials can hold up: pure reads of the fabric's
## `Structure.classes` and `Structure.shapes` (Phase 203) over numbers the structure index keeps per block.
##
## Every indexed block carries three numbers, set once when it is placed and never recomputed from the rest of
## the structure (a 163-floor tower is not rescanned on a placement):
##   base   the bottom (mm) of the ground its load comes down to: its own bottom when it stands on ground (or on a
##          block outside the index), else the base of the block that carries it
##   reach  blocks sideways from the nearest block standing on ground or on a column that does: 0 on a column,
##          its support's + 1 for a block hung out sideways, its support's for one hung under a ceiling
##   carry  the weakest structural class (an index into `Rules.CLASSES`) among the block and everything carrying it
## A block's floor is `(bottom − base) / floorHeight + 1`; it may not exceed `classes[carry].maxFloors`, and past a
## shape threshold its carry must be at least that threshold's `minClass`. `StructureSlice.plan_place` derives the
## numbers from the index and the host's own world, never from a client message. A build that predates the rules
## is kept (`existingBuilds`): a block loaded without the numbers counts as standing on ground.

const Rules := preload("res://src/structure/structure_rules.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")

## The refusal reasons a limit gives (`StructureSlice.REASONS`, key `structure.refused.<reason>`).
const TOO_MANY_FLOORS := "too_many_floors"
const OVERHANG := "overhang_too_far"
const SPAN := "span_too_long"
const SLENDER := "too_slender"

## The class index of `material` (0, earth, for an unknown one).
static func rank_of(material: String) -> int:
	return maxi(0, Rules.CLASSES.find(Rules.class_of(material)))

## The most floors a structure carried by class index `rank` may have.
static func max_floors(rank: int) -> int:
	var classes: Dictionary = Rules.structure().get("classes", {})
	var name: String = Rules.CLASSES[clampi(rank, 0, Rules.CLASSES.size() - 1)]
	return int((classes.get(name, {}) as Dictionary).get("maxFloors", 1))

## Millimetres per floor (`Structure.floorHeight`, 3 m).
static func floor_mm() -> int:
	return maxi(1, roundi(float(Rules.structure().get("floorHeight", 3.0)) * 1000.0))

## The floor (1 = the ground floor) of a block whose bottom is `mm` over a base at `base_mm`. A block below its
## base (a basement) is on floor 0 or lower, which no class limits.
static func floor_of(mm: int, base_mm: int) -> int:
	return floori(float(mm - base_mm) / float(floor_mm())) + 1

## The weakest class index `measure` allows at `value`: the strongest `minClass` among the thresholds `value` is
## past, or 0 when it is past none.
static func min_rank(measure: String, value: float) -> int:
	var need := 0
	for row: Variant in (Rules.structure().get("shapes", {}) as Dictionary).get(measure, []):
		if row is Dictionary and value > float(row.get("above", INF)):
			need = maxi(need, Rules.CLASSES.find(str(row.get("minClass", ""))))
	return need

## The largest value of `measure` any class allows (its last threshold): a walk measuring it may stop past this.
static func last_threshold(measure: String) -> float:
	var top := 0.0
	for row: Variant in (Rules.structure().get("shapes", {}) as Dictionary).get(measure, []):
		if row is Dictionary:
			top = maxf(top, float(row.get("above", 0.0)))
	return top

## Height over the width of a square of the structure's footprint: `height_m` / √(`columns` × tile²).
static func slenderness(height_m: float, columns: int) -> float:
	var side := sqrt(float(maxi(1, columns))) * VoxelConsts.TILE_SIZE
	return height_m / side

## "" when a block carried by class index `carry` may stand on floor `floor` with sideways `reach` in an
## unsupported run of `span` blocks, its structure `slender` (height over footprint width; 0 when the block does
## not raise a structure taller than one floor), else the reason it may not.
static func refusal(carry: int, floor: int, reach: int, span: int, slender: float) -> String:
	if floor > max_floors(carry):
		return TOO_MANY_FLOORS
	if carry < min_rank("overhangReach", float(reach)):
		return OVERHANG
	if carry < min_rank("unsupportedSpan", float(span)):
		return SPAN
	if carry < min_rank("heightToFootprint", slender):
		return SLENDER
	return ""
