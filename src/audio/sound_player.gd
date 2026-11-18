extends Node
## Phase 275 — `Sound` (autoload): gameplay plays sound EVENTS by id, never paths.
##
##     Sound.play("ui.click")                          # 2D, on the event's bus
##     Sound.play("footstep.grass", body.global_position)   # 3D at a world position (a 2D event ignores it)
##     Sound.stop("ambience.TemperateForest")          # loops play until stopped
##
## The event row (`SoundEvents`, from the fabric) picks the variant file, the bus, the base volume, the pitch
## jitter and the range; `AssetOverlay.load_sound` decodes the `.ogg.raw` bytes (production override first).
## An unknown event or a key with no playable file warns once and plays nothing: `play` returns null.
## A one-shot frees its player when it finishes; a looping event (ambience, music) plays until `stop`.
## Volumes are the buses' (`GameSettings`, `default_bus_layout.tres`), never per call site.

const Diag := preload("res://src/core/diag.gd")
const SoundEvents := preload("res://src/audio/sound_events.gd")

## Off on a dedicated server (nobody listens there): `play` returns null without touching a file.
var enabled := true
## Picks the variant and the pitch. The suite seeds it to pin a choice.
var rng := RandomNumberGenerator.new()

var _warned: Dictionary = {}


## What `play(event_id, at)` would do, without doing it: `{ event, key, bus, spatial ("2d"|"3d"),
## volume_db, pitch_scale, loop, max_distance, position }`, or {} for an unknown id. `spatial` is "3d" only
## for a 3D event given a Vector3. Advances `rng` (one variant pick when there are several, one pitch pick
## when the jitter is above 0).
func plan(event_id: String, at: Variant = null) -> Dictionary:
	var ev := SoundEvents.event(event_id)
	var keys := SoundEvents.files(event_id)
	if ev.is_empty() or keys.is_empty():
		return {}
	var key: String = str(keys[0] if keys.size() == 1 else keys[rng.randi_range(0, keys.size() - 1)])
	var jitter := float(ev.get("pitchJitter", 0.0))
	var spatial := "3d" if str(ev.get("spatial", "2d")) == "3d" and at is Vector3 else "2d"
	return {
		"event": event_id,
		"key": key,
		"bus": str(ev.get("bus", "Master")),
		"spatial": spatial,
		"volume_db": float(ev.get("volumeDb", 0.0)),
		"pitch_scale": 1.0 + (rng.randf_range(-jitter, jitter) if jitter > 0.0 else 0.0),
		"loop": bool(ev.get("loop", false)),
		"max_distance": float(ev.get("maxDistance", 0.0)),
		"position": at if spatial == "3d" else Vector3.ZERO,
	}


## Play `event_id` (at world position `at` when the event is 3D). Returns the player node (an
## AudioStreamPlayer or AudioStreamPlayer3D, child of this node), or null when nothing plays.
func play(event_id: String, at: Variant = null) -> Node:
	if not enabled:
		return null
	var p := plan(event_id, at)
	if p.is_empty():
		_warn_once(event_id, "[Sound] unknown sound event %s; it stays silent" % event_id)
		return null
	var stream := AssetOverlay.load_sound(str(p["key"]))
	if stream == null:
		return null   # AssetOverlay warned once for the key
	if stream is AudioStreamOggVorbis and (stream as AudioStreamOggVorbis).loop != bool(p["loop"]):
		# The cached stream is shared by key; the player gets its own copy rather than flipping `loop` under
		# another player. (Today each key belongs to one event, so the copy never happens.)
		stream = stream.duplicate() as AudioStream
		(stream as AudioStreamOggVorbis).loop = bool(p["loop"])
	var player: Node
	if p["spatial"] == "3d":
		var p3 := AudioStreamPlayer3D.new()
		p3.max_distance = float(p["max_distance"])
		p3.position = p["position"]   # this node is not a Node3D, so the position is global
		p3.stream = stream
		p3.bus = p["bus"]
		p3.volume_db = float(p["volume_db"])
		p3.pitch_scale = float(p["pitch_scale"])
		player = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = stream
		p2.bus = p["bus"]
		p2.volume_db = float(p["volume_db"])
		p2.pitch_scale = float(p["pitch_scale"])
		player = p2
	player.set_meta("sound_event", event_id)
	add_child(player)
	if not bool(p["loop"]):
		player.connect("finished", player.queue_free)
	player.call("play")
	return player


## The players of `event_id` still alive (playing or not yet freed).
func playing(event_id: String) -> Array:
	var out: Array = []
	for c in get_children():
		if not c.is_queued_for_deletion() and str(c.get_meta("sound_event", "")) == event_id:
			out.append(c)
	return out


## Stop and free every player of `event_id`.
func stop(event_id: String) -> void:
	for c in playing(event_id):
		_free_player(c)


## Stop and free every player.
func stop_all() -> void:
	for c in get_children():
		_free_player(c)


func _free_player(c: Node) -> void:
	c.call("stop")
	remove_child(c)
	c.free()


func _warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	Diag.warn(msg)
