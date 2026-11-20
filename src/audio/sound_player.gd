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
##
## Phase 276 — `play_loop(channel, event_id, fade)` keeps one looping event per channel ("music", "ambience") and
## cross-fades when the event changes (`""` fades the channel out); every button in the tree clicks
## (`ui.click`, hooked once here on `SceneTree.node_added`, never per widget); `trace` records what `play` was
## asked to play, so the suite checks the wiring without listening.

const Diag := preload("res://src/core/diag.gd")
const SoundEvents := preload("res://src/audio/sound_events.gd")

## Off on a dedicated server (nobody listens there): `play` returns null without touching a file.
var enabled := true
## Picks the variant and the pitch. The suite seeds it to pin a choice.
var rng := RandomNumberGenerator.new()

var _warned: Dictionary = {}

## Test hook: while `tracing`, each `play` that resolves to an event appends its plan (see `plan`) here, whether or
## not a file then loads. Nothing is recorded while `enabled` is false.
var tracing := false
var trace: Array = []

## A fade's floor: a channel starts and ends here.
const FADE_FLOOR_DB := -60.0
## The event a button press plays (Phase 276). A button with the meta `no_click_sound` stays silent (read at
## press time, so the meta can be set after the button enters the tree).
const CLICK_EVENT := "ui.click"

## Most one-shot players of one event alive at once; a further one is dropped (a swarm of creatures or a burst of
## block changes cannot build hundreds of 3D players).
const MAX_ONE_SHOTS_PER_EVENT := 8
## Most one-shot players alive at once across all events.
const MAX_ONE_SHOTS := 48

var _channels: Dictionary = {}   # channel -> its current looping player
var _fades: Array = []           # [{ player, from, to, seconds, t, free }]


func _ready() -> void:
	# Phase 276 — the one shared hook for button clicks: every BaseButton that enters the tree clicks when pressed.
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	step_fades(delta)


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		hook_button(n as BaseButton)


## Make `button` play `ui.click` when pressed (once; a re-parented button is not hooked twice).
func hook_button(button: BaseButton) -> void:
	var cb := _click.bind(button)
	if not button.pressed.is_connected(cb):
		button.pressed.connect(cb)


func _click(button: BaseButton) -> void:
	if not button.has_meta("no_click_sound"):
		play(CLICK_EVENT)


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
	if tracing:
		trace.append(p)
	if not bool(p["loop"]) and not one_shot_room(event_id):
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
	player.set_meta("sound_one_shot", not bool(p["loop"]))
	add_child(player)
	if not bool(p["loop"]):
		player.connect("finished", player.queue_free)
	player.call("play")
	return player


## Whether another one-shot of `event_id` fits under the polyphony caps.
func one_shot_room(event_id: String) -> bool:
	var same := 0
	var all := 0
	for c in get_children():
		if c.is_queued_for_deletion() or c.get_meta("sound_one_shot", false) != true:
			continue
		all += 1
		if str(c.get_meta("sound_event")) == event_id:
			same += 1
	return same < MAX_ONE_SHOTS_PER_EVENT and all < MAX_ONE_SHOTS


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
		for ch in _channels.keys():
			if _channels[ch] == c:
				_channels.erase(ch)   # no stale entry for play_loop to trip over
		_free_player(c)


## Stop and free every player (channels and fades included).
func stop_all() -> void:
	for c in get_children():
		_free_player(c)
	_channels.clear()
	_fades.clear()


## Phase 276 — keep `event_id` looping on `channel`, fading it in over `fade` seconds and fading out whatever the
## channel played before (a cross-fade). The same event again is a no-op; `""` fades the channel out. Returns the
## channel's player, or null when nothing plays (disabled, unknown event, missing file, or `""`).
func play_loop(channel: String, event_id: String, fade: float = 1.0) -> Node:
	var cur: Node = _channels.get(channel, null)
	if cur != null and not is_instance_valid(cur):
		cur = null
	if cur != null and str(cur.get_meta("sound_event", "")) == event_id:
		return cur
	_channels.erase(channel)
	if cur != null:
		_fade(cur, FADE_FLOOR_DB, fade, true)
	if event_id == "":
		return null
	var p := play(event_id)
	if p == null:
		return null
	var target: float = p.get("volume_db")
	if fade > 0.0:
		p.set("volume_db", FADE_FLOOR_DB)
		_fade(p, target, fade, false)
	_channels[channel] = p
	return p


## The event `channel` is playing ("" when none).
func channel_event(channel: String) -> String:
	var cur: Node = _channels.get(channel, null)
	return str(cur.get_meta("sound_event", "")) if cur != null and is_instance_valid(cur) else ""


## Fade `channel` out (and free it at the end of the fade).
func stop_channel(channel: String, fade: float = 1.0) -> void:
	play_loop(channel, "", fade)


## Players still fading (in or out).
func fading_count() -> int:
	return _fades.size()


## Advance every fade by `delta` seconds (`_process` calls it; the suite calls it directly). A fade-out frees its
## player when done.
func step_fades(delta: float) -> void:
	var keep: Array = []
	for f in _fades:
		var pl: Node = f["player"]
		if not is_instance_valid(pl) or pl.is_queued_for_deletion():
			continue
		f["t"] = float(f["t"]) + delta
		var k := 1.0 if float(f["seconds"]) <= 0.0 else clampf(float(f["t"]) / float(f["seconds"]), 0.0, 1.0)
		pl.set("volume_db", lerpf(float(f["from"]), float(f["to"]), k))
		if k < 1.0:
			keep.append(f)
		elif bool(f["free"]):
			_free_player(pl)
	_fades = keep


func _fade(pl: Node, to_db: float, seconds: float, free_at_end: bool) -> void:
	for f in _fades:
		if f["player"] == pl:
			_fades.erase(f)
			break
	_fades.append({ "player": pl, "from": float(pl.get("volume_db")), "to": to_db, "seconds": maxf(seconds, 0.0),
		"t": 0.0, "free": free_at_end })
	if seconds <= 0.0:
		step_fades(0.0)


func _free_player(c: Node) -> void:
	c.call("stop")
	remove_child(c)
	c.free()


func _warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	Diag.warn(msg)
