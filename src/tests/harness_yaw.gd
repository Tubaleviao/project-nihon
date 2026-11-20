extends RefCounted
## Phase 282 — the fall direction a harness side was told for each felled tree (`GameBus.tree_chopped`).

var yaws: Dictionary = {}

func _init() -> void:
	GameBus.tree_chopped.connect(on_chopped)

func on_chopped(id: String, _wood: String, _state: String, _respawn_at: float, yaw: float) -> void:
	yaws[id] = yaw

func has(id: String) -> bool:
	return yaws.has(id)

## Milliradians as a detail token ("yaw1571"); "noyaw" when none came or the event carried no fall.
func token(id: String) -> String:
	var y: float = float(yaws.get(id, 1000.0))
	return "noyaw" if absf(y) > TAU * 2.0 else "yaw%d" % int(round(y * 1000.0))
