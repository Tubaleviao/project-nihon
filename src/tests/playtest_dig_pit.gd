extends RefCounted
## Phase 300 — the playtest `mine` step's pit: a stone shovel digs 1 m deep and 1.5 m wide in at most PIT_HOLDS holds.
## Split out of `playtest_bot.gd` for its line cap; `bot` is the running bot (hold_work, frames) and `root` the game root.

const PIT_HOLDS := 6

## Holds work and completes one dig per hold around `centre` (xz) until the ground at the centre is 1 m under where
## it started and the ground 0.75 m to each side is at least half a metre under. `{ ok, note }`.
static func dig(bot: Node, root: Node, centre: Vector3) -> Dictionary:
	if int(root._inventory.get_item_count("StoneShovel")) < 1:
		root._inventory.add_item("StoneShovel", 1)
	var voxel: Node = root._voxel
	var c := Vector2(centre.x, centre.z)
	var start: float = voxel.get_voxel_height_at(c)
	var offsets := [Vector2.ZERO, Vector2(0.75, 0.0), Vector2(-0.75, 0.0), Vector2(0.0, 0.75), Vector2(0.0, -0.75), Vector2.ZERO]
	var sides := [Vector2(0.75, 0.0), Vector2(-0.75, 0.0), Vector2(0.0, 0.75), Vector2(0.0, -0.75)]
	for i in PIT_HOLDS:
		var q: Vector2 = c + offsets[i]
		var spot := Vector3(q.x, voxel.get_voxel_height_at(q) - 0.05, q.y)
		if await bot._hold_work("block", "", spot) < 0.0:
			return { "ok": false, "note": "the host never answered hold %d" % i }
		GameBus.block_mine_requested.emit(spot, Vector3.UP, "", {})
		await bot.get_tree().process_frame
		var wide := true
		for d in sides:
			wide = wide and start - voxel.get_voxel_height_at(c + d) >= 0.5
		if start - voxel.get_voxel_height_at(c) >= 1.0 and wide:
			return { "ok": true, "note": "%d holds" % (i + 1) }
	return { "ok": false, "note": "%d holds left the centre %.2f m down" % [PIT_HOLDS, start - voxel.get_voxel_height_at(c)] }
