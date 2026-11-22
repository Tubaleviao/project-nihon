extends RefCounted
## Phase 294 — the creature half of remote motion, split out of `creature_slice.gd` (its line cap). `sl` is the
## owning `CreatureSlice`.
##
## Client: iid -> { track: RemoteMotion, anchor: {chunk, local} } for each live creature the host moves. A state is
## queued on the track as an offset from the anchor (exact however far from the origin, and blind to a rebase);
## every frame `tick` plays it back into `inst["draw"]` ({ pos, speed, yaw }), which the box and the model are
## drawn from. `inst["pos"]` stays the host's latest state for everything else.
##
## Host: `far_hold` keeps back the delta of a creature farther than `farDistanceM` from every player for
## `farSendIntervalMs` (its motion is played back over the longer gap).

const RemoteMotion := preload("res://src/networking/remote_motion.gd")
const RemoteMotionRules := preload("res://src/networking/remote_motion_rules.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")

var sl: Node
var tracks: Dictionary = {}
## The client's clock for motion tracks (ms) when set (the suite drives it), else the engine's.
var clock: Callable = Callable()

func _init(slice: Node) -> void:
	sl = slice

func now_ms() -> float:
	return float(clock.call()) if clock.is_valid() else float(Time.get_ticks_msec())

## Host: the far-creature context for one broadcast: { players: [Vector3], far_m, gap_ms }.
func far_context(player_positions: Callable) -> Dictionary:
	var rules: Dictionary = RemoteMotionRules.rules()["creatures"]
	var players: Array = []
	if player_positions.is_valid():
		var got: Variant = player_positions.call()
		if got is Dictionary:
			players = (got as Dictionary).values()
	return { "players": players, "far_m": float(rules["farDistanceM"]), "gap_ms": float(rules["farSendIntervalMs"]) }

## Host: true when a changed creature at `at` (state unchanged since `prev`, its last broadcast) waits: it is far
## from every player and its last broadcast is less than the far interval old. No players known: never held.
static func far_hold(ctx: Dictionary, prev: Variant, state: String, at: Vector3, now: float) -> bool:
	if prev == null or prev["state"] != state or now - float(prev.get("at", -INF)) >= float(ctx["gap_ms"]):
		return false
	var players: Array = ctx["players"]
	if players.is_empty():
		return false
	for p in players:
		if p is Vector3 and Vector2(at.x - (p as Vector3).x, at.z - (p as Vector3).z).length() <= float(ctx["far_m"]):
			return false
	return true

## Client: queue a host state of `iid` on its motion track (a dead body has none: its fall is the model's, from
## where it stood to the host's landing spot).
func note(iid: String, state: String, pos: Dictionary, now: float) -> void:
	if state == "dead":
		tracks.erase(iid)
		if sl._instances.has(iid):
			var inst: Dictionary = sl._instances[iid]
			inst.erase("draw")
			# The blow's push is measured from the host's last live state, not the drawn body (which trails it by
			# the playback delay): the creature's own travel must not read as a throw.
			if inst["state"] != "dead" and inst.has("pos"):
				inst["death_from"] = (inst["pos"] as Dictionary).duplicate()
		return
	var entry: Dictionary = tracks.get(iid, {})
	if entry.is_empty():
		entry = { "track": RemoteMotion.new(RemoteMotionRules.group("creatures")), "anchor": pos.duplicate() }
		tracks[iid] = entry
	(entry["track"] as RemoteMotion).push(now, WorldPos.offset_between(entry["anchor"], pos))

## Client: play every creature's track back to `now` and draw the box (a model reads `inst["draw"]` in
## `CreatureVisuals`). A track that has settled is drawn once more and then skipped.
func tick(delta: float, now: float = -1.0) -> void:
	if tracks.is_empty():
		return
	if now < 0.0:
		now = now_ms()
	for iid in tracks.keys():
		var inst: Dictionary = sl._instances.get(iid, {})
		if inst.is_empty() or inst["state"] == "dead":
			tracks.erase(iid)
			continue
		var entry: Dictionary = tracks[iid]
		var track: RemoteMotion = entry["track"]
		if bool(entry.get("drawn_settled", false)) and track.at_rest():
			continue
		track.step(now, delta)
		if not track.has_position:
			continue
		var anchor: Dictionary = entry["anchor"]
		var exact := WorldPos.normalized({ "chunk": anchor["chunk"], "local": (anchor["local"] as Vector3) + track.position })
		var draw: Variant = inst.get("draw", null)
		if draw is Dictionary:
			draw["pos"] = exact
			draw["speed"] = track.speed
			draw["yaw"] = track.yaw
		else:
			inst["draw"] = { "pos": exact, "speed": track.speed, "yaw": track.yaw }
		entry["drawn_settled"] = track.at_rest()
		sl._place_box(iid, WorldPos.to_scene(exact, Vector2i.ZERO))

## Client: a fold moved every held creature into another frame (a pole fold also turns directions): drop the
## tracks and drawn positions, so each creature is drawn at its folded state and its next state starts afresh.
func clear() -> void:
	for iid in tracks:
		if sl._instances.has(iid):
			sl._instances[iid].erase("draw")
	tracks.clear()

func track_of(iid: String) -> RemoteMotion:
	return (tracks.get(iid, {}) as Dictionary).get("track", null)
