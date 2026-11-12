extends Node
## Phase 243 — a chunk changing level cross-fades instead of swapping in one frame.
##
## The old surface (a `ChunkSurface`) is handed over here when its chunk is rebuilt at another level (the
## window's coarse-to-full upgrade, an LOD ring moving) and the new one fades in over `FADE_SEC` while the
## old fades out, dithered through the terrain shader's `lod_fade` instance uniform; the two dither
## patterns are complementary at the same progress, so the ground is never see-through. The old surface
## is freed at the end. Only the high terrain shader declares the uniform, so `enabled()` is false on the
## low path (the Compatibility renderer by default) and the swap stays instant there.

const TerrainMaterial := preload("res://src/terrain/terrain_material.gd")

const FADE_SEC := 0.4

## Each entry: `{ "old": Array of surfaces, "new": Array of surfaces, "t": progress 0..1 }`.
var _fades: Array = []

## True when level changes cross-fade: the high terrain shader is in use.
static func enabled() -> bool:
	return TerrainMaterial.quality() == TerrainMaterial.QUALITY_HIGH

## Fade `new_surfaces` in and `old_surfaces` out; the old ones are reparented under this node (so the
## caller may free their chunk's root) and freed when the fade ends. Surfaces without `set_fade` are
## shown at once and old ones freed at once.
func cross_fade(old_surfaces: Array, new_surfaces: Array) -> void:
	var olds: Array = []
	for o in old_surfaces:
		var node := o as Node
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("set_fade"):
			node.queue_free()
			continue
		var at: Transform3D = (node as Node3D).global_transform if node is Node3D and node.is_inside_tree() else Transform3D()
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		add_child(node)
		if node is Node3D and node.is_inside_tree():
			(node as Node3D).global_transform = at
		olds.append(node)
	var news: Array = []
	for n in new_surfaces:
		if n != null and is_instance_valid(n) and (n as Node).has_method("set_fade"):
			news.append(n)
	if olds.is_empty() and news.is_empty():
		return
	var entry := { "old": olds, "new": news, "t": 0.0 }
	_apply(entry)
	_fades.append(entry)

## Fades in flight (a test reads it).
func active() -> int:
	return _fades.size()

## Advance every fade by `delta` seconds.
func step(delta: float) -> void:
	var keep: Array = []
	for entry in _fades:
		entry["t"] = minf(float(entry["t"]) + delta / FADE_SEC, 1.0)
		_apply(entry)
		if float(entry["t"]) >= 1.0:
			_finish(entry)
		else:
			keep.append(entry)
	_fades = keep

## End every fade now (a rebase or a fold moves the scene under them).
func finish_all() -> void:
	for entry in _fades:
		entry["t"] = 1.0
		_apply(entry)
		_finish(entry)
	_fades.clear()

## Shift the old surfaces this node holds by `shift` (a client rebase).
func shift_scene(shift: Vector3) -> void:
	for entry in _fades:
		for o in entry["old"]:
			if is_instance_valid(o) and o is Node3D:
				(o as Node3D).position += shift

func _process(delta: float) -> void:
	if not _fades.is_empty():
		step(delta)

func _apply(entry: Dictionary) -> void:
	var t := float(entry["t"])
	for n in entry["new"]:
		if is_instance_valid(n):
			n.set_fade(t)
	for o in entry["old"]:
		if is_instance_valid(o):
			o.set_fade(2.0 + t)

func _finish(entry: Dictionary) -> void:
	for n in entry["new"]:
		if is_instance_valid(n):
			n.set_fade(1.0)
	for o in entry["old"]:
		if is_instance_valid(o):
			o.queue_free()
