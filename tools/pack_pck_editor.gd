@tool
extends EditorScript

const SRC_DIR := "res://assets-prod"
const DST_PREFIX := "res://assets/"
const OUT_PCK := "res://assets.pck"

func _run() -> void:
 var files := _collect(SRC_DIR)
 var packer := PCKPacker.new()
 var err := packer.pck_start(ProjectSettings.globalize_path(OUT_PCK))
 if err != OK:
  push_error("pck_start failed: " + str(err))
  return
 for src in files:
  var rel := src.trim_prefix(SRC_DIR).trim_prefix("/")
  packer.add_file(DST_PREFIX + rel, src)
 packer.flush(true)
 print("Wrote ", files.size(), " files to ", OUT_PCK)

func _collect(dir: String) -> Array[String]:
 var out: Array[String] = []
 var d := DirAccess.open(dir)
 if d == null:
  return out
 d.list_dir_begin()
 var n := d.get_next()
 while n != "":
  if n.begins_with("."):
   n = d.get_next()
   continue
  var p := dir.path_join(n)
  if d.current_is_dir():
   out.append_array(_collect(p))
  else:
   out.append(p)
  n = d.get_next()
 d.list_dir_end()
 return out
