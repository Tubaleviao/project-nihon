extends SceneTree
## Prints `PROFILE_SCALE <x>`: the harness time scale of the link profile named after `--`.
## Read by tools/net_harness.sh so its timeouts follow the profile table.

const NetProfiles := preload("res://src/networking/net_profiles.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var name := str(args[0]) if args.size() > 0 else ""
	print("PROFILE_SCALE %s" % str(NetProfiles.time_scale(name)))
	quit(0 if NetProfiles.TABLE.has(name) else 1)
