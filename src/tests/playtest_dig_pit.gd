extends RefCounted
## Phase 300 — the playtest bot's `mine` step digs a pit with a stone shovel: a brush dig moves a shovelful, so a
## pit 1 m deep and 1.5 m across takes a handful of holds, not hundreds. The first hold is the step's own (it
## shoots the work bar); `run` makes the rest, re-aiming at the pit's edges until it is wide enough and at its
## bottom until it is deep enough, and reports what the runs hold.

const StoneTools := preload("res://src/world/stone_tools.gd")
const MAX_HOLDS := 6
const MIN_DEPTH := 1.0
const MIN_WIDTH := 1.5
const STEP := 0.5   # a tile
## Where the next hold aims, as tile offsets from the pit's centre (a hold at the centre digs deeper).
const EDGES := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]

## Metres the centre column is below the original surface `y0`.
static func depth(voxel: Node, c: Vector2, y0: float) -> float:
	return y0 - float(voxel.get_voxel_height_at(c))

## The widest run of dug tiles along either axis through the centre, in metres (a tile counts when its top is at
## least a step under the original surface).
static func width(voxel: Node, c: Vector2, y0: float) -> float:
	var best := 0.0
	for axis in [Vector2(1, 0), Vector2(0, 1)]:
		var n := 0
		for dir in [1.0, -1.0]:
			for k in range(0 if dir > 0.0 else 1, 8):
				if y0 - float(voxel.get_voxel_height_at(c + axis * dir * STEP * float(k))) < 0.125 - 1.0e-4:
					break
				n += 1
		best = maxf(best, float(n) * STEP)
	return best

## Holds 2.. of the pit (`holds` already made). Returns `{ holds, depth, width, ok }`.
static func run(bot: Node, c: Vector2, y0: float, holds: int) -> Dictionary:
	var voxel: Node = bot._root._voxel
	var edge := 0
	while holds < MAX_HOLDS and (depth(voxel, c, y0) < MIN_DEPTH or width(voxel, c, y0) < MIN_WIDTH):
		var at := c
		if width(voxel, c, y0) < MIN_WIDTH:
			at = c + EDGES[edge % EDGES.size()] * STEP
			edge += 1
		var spot := Vector3(at.x, float(voxel.get_voxel_height_at(at)) - 0.1, at.y)
		var n: int = bot._mined.size()
		await bot._hold_work("block", "", spot)
		GameBus.block_mine_requested.emit(spot, Vector3.UP, "", {})
		await bot._until(func(): return bot._mined.size() > n, 4.0)
		await bot.get_tree().process_frame
		holds += 1
	var d := depth(voxel, c, y0)
	var w := width(voxel, c, y0)
	return { "holds": holds, "depth": d, "width": w, "ok": d >= MIN_DEPTH and w >= MIN_WIDTH and holds <= MAX_HOLDS }

## The pit moves a few hundred units of ground and the shovel was lent: take back everything the pack gained since
## `before`, so the later steps (gather, craft, place) start from the pack they always had, under its carry limit.
static func hand_back(inventory: Node, before: Dictionary) -> void:
	var extra: Dictionary = {}
	var now: Dictionary = inventory.get_contents()
	for item in now:
		var n: int = int(now[item]) - int(before.get(item, 0))
		if n > 0:
			extra[item] = n
	if not extra.is_empty():
		inventory.consume_items(extra)

## What the tutorial's bare-hands work left in the pack (ore, soil, spare loose items, the used stone tools; the
## knife stays for the harvest), as a `consume_items` map. Dropped on a failed dig too: a brush dig fills the pack
## with soil, and a pack at its weight cap makes `add_item` refuse the later steps' waystones and blocks.
static func leftovers(inventory: Node) -> Dictionary:
	var out := {}
	for item in ["Ferrite", "Soil", StoneTools.BRANCH, StoneTools.LOOSE_STONE, "StoneAxe", "StonePick", "StoneShovel"]:
		if inventory.get_item_count(item) > 0:
			out[item] = inventory.get_item_count(item)
	return out

## Runs `mine` (a mine intent) with the brush off: one slab of one column, as `net_harness`'s `slab_mine` does. The
## tower step levels its footprint column by column, and a round brush would cut the neighbours too.
static func slab(voxel: Node, mine: Callable) -> void:
	var was: bool = voxel._edit.brush_enabled
	voxel._edit.brush_enabled = false
	mine.call()
	voxel._edit.brush_enabled = was
