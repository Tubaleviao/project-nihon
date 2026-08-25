extends SceneTree
## Pack the private production-asset submodule into a Godot `.pck` override.
##
## Invoked headless:
##   godot --headless --path . --script res://tools/pack_pck.gd
##
## The submodule `assets-prod/` mirrors the public `assets/` tree, so every file
## is packed at its canonical `res://assets/<rel>` path and the resulting
## `assets.pck` overlays the committed placeholders at startup (see
## src/core/asset_overlay.gd).

const SRC_DIR := "res://assets-prod"
const DST_PREFIX := "res://assets/"
const OUT_PCK := "res://assets.pck"


func _init() -> void:
	var files := _collect(SRC_DIR)
	if files.is_empty():
		printerr("[pack_pck] no production assets under %s — run `git submodule update --init assets-prod`" % SRC_DIR)
		quit(1)
		return

	var packer := PCKPacker.new()
	var err := packer.pck_start(ProjectSettings.globalize_path(OUT_PCK))
	if err != OK:
		printerr("[pack_pck] pck_start failed: %s" % error_string(err))
		quit(1)
		return

	for src in files:
		var rel := src.trim_prefix(SRC_DIR).trim_prefix("/")
		var target := DST_PREFIX + rel
		var add_err := packer.add_file(target, src)
		if add_err != OK:
			printerr("[pack_pck] add_file(%s) failed: %s" % [target, error_string(add_err)])

	print("[pack_pck] wrote %d files to %s" % [files.size(), OUT_PCK])
	packer.flush(true)
	quit(0)


func _collect(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var path := dir.path_join(name)
		if d.current_is_dir():
			out.append_array(_collect(path))
		else:
			out.append(path)
		name = d.get_next()
	d.list_dir_end()
	return out
