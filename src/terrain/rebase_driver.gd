extends RefCounted
## Phase 63 — the client-side origin rebase driver.
##
## Float32 scene positions lose the 0.125 m step far from the scene origin, so once the player drifts
## `WorldPos.REBASE_DISTANCE` away the client moves the ORIGIN, not the world: the terrain roots, the
## trees, creatures, stations and the player body all shift by the same offset in one call, so no
## frame sees a mix of frames. World records (`{chunk, local}`) are untouched; only scene positions move.

const WorldPos := preload("res://src/terrain/world_pos.gd")
const Diag := preload("res://src/core/diag.gd")

## Nodes with a `shift_scene(Vector3)`: the voxel slice, tree, creature and station slices, the player.
var targets: Array = []
## The chunk the scene origin currently sits at.
var origin_chunk: Vector2i = Vector2i.ZERO
var rebase_count: int = 0
## Targets that had no `shift_scene` when a rebase reached them: a node left behind would sit a
## whole offset away from everything that moved, so each is counted and reported once.
var unshiftable_skipped: int = 0
var _reported_unshiftable: Dictionary = {}   # instance id -> true

func _init(shiftables: Array = []) -> void:
	targets = shiftables

## Rebase when the player's scene position drifted past the threshold. Returns true when it did.
## `player_scene_pos` is the body's scene position; `player_chunk` the chunk it stands in.
func tick(player_scene_pos: Vector3, player_chunk: Vector2i) -> bool:
	if not WorldPos.needs_rebase(player_scene_pos):
		return false
	rebase_to(player_chunk)
	return true

## Move the scene origin to `new_origin`, shifting every target by the same offset.
func rebase_to(new_origin: Vector2i) -> Vector3:
	var shift := WorldPos.rebase_shift(origin_chunk, new_origin)
	if shift == Vector3.ZERO:
		return shift
	for t in targets:
		if t == null:
			continue
		if t.has_method("shift_scene_to_origin"):   # the player: keeps the integer origin, not a rounded shift
			t.shift_scene_to_origin(shift, new_origin)
		elif t.has_method("shift_scene"):
			t.shift_scene(shift)
		else:
			_report_unshiftable(t)
	origin_chunk = new_origin
	rebase_count += 1
	return shift

func _report_unshiftable(t: Object) -> void:
	unshiftable_skipped += 1
	var id := t.get_instance_id()
	if _reported_unshiftable.has(id):
		return
	_reported_unshiftable[id] = true
	Diag.error("RebaseDriver: %s has no shift_scene(); it was left behind by the rebase" % str(t))
