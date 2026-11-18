extends "res://src/core/wiring.gd"
## Phase 276 — the first sounds wired into gameplay. Every sound is a fabric event (`fabric/gameplay/sounds.js`)
## played through the `Sound` autoload; this module decides WHEN and WHERE, on the machine that should hear it:
##
## - footsteps (`footstep.<surface>`): the local player, one per `STRIDE_METRES` walked on the ground (not while
##   riding: the body then moves at the mount's speed), at the feet; the surface comes from what is underfoot
##   (`surface_for`: a placed block, else the biome's terrain material, through the fabric's `footsteps` table).
## - the dig (`world.dig`): every `block_changed` "mine" the host applies, at the dug block, so whoever stands
##   near (the digger, a listen host, another client) hears it. The local player's own tool strike
##   (`item.<tool>.hit`) plays on its mine completion, at the aimed point.
## - pickups (`world.pickup`): the local inventory's `item_picked_up`, and a loose stone or branch picked by the
##   local player once the host confirms it (`loose_picked`), so a refused pick is silent.
## - creature attacks (`creature.<Type>.attack`): each swing the host resolves (or a client receives as
##   `combat_hit_synced`), at the creature.
## - ambience (`ambience.<Biome>`) for the biome the local player stands in, cross-faded on a biome change and
##   faded out where the biome has none; the music (`MUSIC_EVENT`) once the player is in the world (a music file
##   that does not load is retried with a growing back-off). Leaving the world (`unwire`, when the root is freed
##   for the main menu) cuts both loops at once.
##
## 3D sounds are placed at scene positions (world + the player's scene offset) and skipped when the listener is
## beyond the event's `maxDistance`. A dedicated server or a headless boot plays nothing (`apply_boot_role`, run
## when a booting root wires this module: the one place that sets `Sound.enabled`), and a server root connects
## nothing. UI clicks and window sounds are hooked at the shared UI points instead (`Sound`'s button hook,
## `UiSlice.open_window` / `close_window`, the pause menu).

const SoundEvents := preload("res://src/audio/sound_events.gd")
const WorkTime := preload("res://src/core/work_time.gd")
const TerrainWeights := preload("res://src/terrain/terrain_weights.gd")
const VoxelRay := preload("res://src/terrain/voxel_ray.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")

## Metres walked per footstep.
const STRIDE_METRES := 1.6
## Below this horizontal speed (m/s) the player is standing, not walking.
const MIN_STEP_SPEED := 0.5
## A run underfoot counts as the ground stood on when its top is at most this far above the feet.
const FEET_SLACK := 0.3
## How often the biome (ambience) and the music are re-checked.
const SURROUND_SECONDS := 1.0
const AMBIENCE_FADE := 2.0
const MUSIC_FADE := 3.0
const MUSIC_EVENT := "music.main_theme"
const CHANNEL_AMBIENCE := "ambience"
const CHANNEL_MUSIC := "music"
const DIG_EVENT := "world.dig"
const PICKUP_EVENT := "world.pickup"
## The first wait (s) after the music fails to load, doubled on each failure up to `MUSIC_RETRY_MAX`.
const MUSIC_RETRY_FIRST := 2.0
const MUSIC_RETRY_MAX := 120.0
## How long (ms) a client's loose pick waits for the host's `loose_picked` before it counts as refused.
const LOOSE_CONFIRM_MS := 5000

var _stride := STRIDE_METRES * 0.5
var _surround_t := SURROUND_SECONDS
var _work_action := "mine"
var _music_wait := 0.0          # seconds before the music is tried again (after a failed load)
var _music_retry := MUSIC_RETRY_FIRST
var _music_attempts := 0        # loads tried (the suite reads it)
var _loose_pending: Dictionary = {}   # loose item id -> ticks (ms) the local player asked for it
var _loose_confirmed := ["", -1]       # [id, process frame] of the last `loose_picked`


## Whether this boot plays sound: never on a dedicated server or a headless boot (nobody listens there).
static func sound_allowed(is_server: bool, headless: bool) -> bool:
	return not is_server and not headless


## Set `Sound.enabled` for the boot role.
static func apply_boot_role(is_server: bool, headless: bool) -> void:
	Sound.enabled = sound_allowed(is_server, headless)


## A booting root (in the tree; `GameRoot._build_and_boot` wires every module before any role boot runs) sets
## `Sound` for its role first. A suite fixture root is not in the tree and leaves `Sound` alone.
func _connect_all() -> void:
	if root.is_inside_tree():
		apply_boot_role(root._is_server, DisplayServer.get_name() == "headless")
	if root._is_server:
		return   # a dedicated server hears nothing
	connect_bus(GameBus.block_changed, _on_block_changed)
	connect_bus(GameBus.block_mine_requested, _on_mine_requested)
	connect_bus(GameBus.work_started, _on_work_started)
	connect_bus(GameBus.item_picked_up, _on_item_picked_up)
	connect_bus(GameBus.loose_pick_requested, _on_loose_pick_requested)
	connect_bus(GameBus.loose_picked, _on_loose_picked)
	connect_bus(GameBus.combat_hit_resolved, _on_combat_hit_resolved)
	connect_bus(GameBus.combat_hit_synced, _on_combat_hit_synced)


func unwire() -> void:
	if connection_count() > 0:
		Sound.stop_channel(CHANNEL_AMBIENCE, 0.0)
		Sound.stop_channel(CHANNEL_MUSIC, 0.0)
	super.unwire()


func tick(delta: float) -> void:
	if root._is_server or root._player == null:
		return
	var p = root._player
	if p.is_world_input_frozen() or not p.is_alive():
		return   # the loading screen, or dead: no steps and no change of surroundings
	var v: Vector3 = p.get_velocity()
	# A rider's own body moves at the mount's speed and stays on the floor: no human steps then (the stride resets).
	var due := step_due(_stride, Vector2(v.x, v.z).length(), delta, p.is_grounded() and not local_mounted())
	_stride = float(due[0])
	if bool(due[1]):
		play_footstep()
	_surround_t += delta
	if _surround_t >= SURROUND_SECONDS:
		_surround_t = 0.0
		refresh_surroundings(SURROUND_SECONDS)


# ---------------------------------------------------------------------------
# Pure rules
# ---------------------------------------------------------------------------

## The stride after `delta` seconds at horizontal `speed` (m/s): `[stride, step]`, `step` true when a footstep
## falls in this frame. Off the ground or standing, the stride resets to half a stride, so the first step of a
## walk comes soon.
static func step_due(stride: float, speed: float, delta: float, grounded: bool) -> Array:
	if not grounded or speed < MIN_STEP_SPEED:
		return [STRIDE_METRES * 0.5, false]
	var s := stride + speed * maxf(delta, 0.0)
	if s >= STRIDE_METRES:
		return [fmod(s, STRIDE_METRES), true]
	return [s, false]


## The footstep surface for a placed block `block_material` ("" = natural ground) in `biome`: the fabric's
## `footsteps.block` for a block, else the surface of the terrain material the biome's ground is drawn with.
## "" when the table names none.
static func surface_for(block_material: String, biome: String) -> String:
	var fs := SoundEvents.footsteps()
	if block_material != "":
		return str(fs.get("block", ""))
	var t := TerrainWeights.table()
	var layer := TerrainWeights.biome_layer(t, biome)
	for row in t["layers"]:
		if int(row["layer"]) == layer:
			return str((fs.get("terrain", {}) as Dictionary).get(str(row["name"]), ""))
	return ""


## The event a footstep on `surface` plays ("" when there is none).
static func footstep_event(surface: String) -> String:
	var id := "footstep." + surface
	return id if surface != "" and SoundEvents.has_event(id) else ""


## The ambience of `biome` ("" when it has none).
static func ambience_for(biome: String) -> String:
	var id := "ambience." + biome
	return id if biome != "" and SoundEvents.has_event(id) else ""


## The material of the run the feet stand on (`runs` bottom → top, each `{bottom, top, material}`): the highest
## run whose top is no more than `FEET_SLACK` above `feet_y`. "" for natural ground or no run.
static func material_underfoot(runs: Array, feet_y: float) -> String:
	var out := ""
	for r in runs:
		if r is Dictionary and float(r.get("top", 0.0)) <= feet_y + FEET_SLACK:
			out = str(r.get("material", ""))
	return out


# ---------------------------------------------------------------------------
# Playing
# ---------------------------------------------------------------------------

## Whether this machine's player rides a mount.
func local_mounted() -> bool:
	var mw = root._mount_wiring
	return mw != null and mw.slice != null and mw.slice.is_local_mounted()


## The local player's scene offset (world + offset = scene); zero with no player.
func _offset() -> Vector3:
	return root._player.scene_offset() if root._player != null else Vector3.ZERO


## The scene position of an exact `{chunk, local}` world position.
func _scene_of_pos(pos: Dictionary) -> Vector3:
	var off := _offset()
	var origin := Vector2i(roundi(-off.x / WorldPos.CHUNK_METERS), roundi(-off.z / WorldPos.CHUNK_METERS))
	return WorldPos.to_scene(pos, origin)


## Play a 3D `event_id` at the scene position `at`, unless the local listener is beyond the event's range.
func play_at(event_id: String, at: Vector3) -> Node:
	if root._player != null:
		var reach := float(SoundEvents.event(event_id).get("maxDistance", 0.0))
		if reach > 0.0 and root._player.get_scene_position().distance_to(at) > reach:
			return null
	return Sound.play(event_id, at)


## One footstep of the local player, on the surface underfoot.
func play_footstep() -> Node:
	var p = root._player
	var scene: Vector3 = p.get_scene_position()
	var off: Vector3 = p.scene_offset()
	var block := ""
	if root._voxel != null and root._voxel.has_method("get_runs_at_tile"):
		block = material_underfoot(root._voxel.get_runs_at_tile(VoxelRay.tile_of(scene, off)), scene.y - off.y)
	var biome := ""
	if root._terrain != null:
		biome = str(root._terrain.get_biome_at_chunk(p.get_world_pos()["chunk"]))
	var ev := footstep_event(surface_for(block, biome))
	return Sound.play(ev, scene) if ev != "" else null


## Re-read the biome underfoot for the ambience, and keep the music going. `elapsed` (s) is the time since the
## last refresh, counted against the music's retry back-off.
func refresh_surroundings(elapsed: float = SURROUND_SECONDS) -> void:
	if root._terrain != null and root._player != null:
		var biome := str(root._terrain.get_biome_at_chunk(root._player.get_world_pos()["chunk"]))
		var amb := ambience_for(biome)
		if amb != Sound.channel_event(CHANNEL_AMBIENCE):
			Sound.play_loop(CHANNEL_AMBIENCE, amb, AMBIENCE_FADE)
	if Sound.channel_event(CHANNEL_MUSIC) == "" and Sound.enabled:
		_music_wait -= elapsed
		if _music_wait <= 0.0:
			_start_music()


## Start the music, unless none of its files loads (a bad pack): then wait, twice as long after each failure. The
## files are checked first, so a failed try neither picks a variant (`Sound.rng`) nor builds a player.
func _start_music() -> void:
	_music_attempts += 1
	var playable := false
	for k in SoundEvents.files(MUSIC_EVENT):
		playable = playable or AssetOverlay.load_sound(str(k)) != null
	if playable and Sound.play_loop(CHANNEL_MUSIC, MUSIC_EVENT, MUSIC_FADE) != null:
		_music_retry = MUSIC_RETRY_FIRST
		_music_wait = 0.0
		return
	_music_wait = _music_retry
	_music_retry = minf(_music_retry * 2.0, MUSIC_RETRY_MAX)


## The host applied a dig (any player's, or a worn structure block): heard at the block by whoever is near.
func _on_block_changed(action: String, position: Vector3, _normal: Vector3, _material: String) -> void:
	if action == "mine":
		play_at(DIG_EVENT, position + _offset())


## Phase 259's work answer names the action (dig / mine / chop): the tool the completion strikes with.
func _on_work_started(_key: String, _duration: float, action: String, _material: String) -> void:
	if action == "dig" or action == "mine":
		_work_action = action


## The local player's mine completes: its tool strikes (`item.<tool>.hit`, when the tool has one).
func _on_mine_requested(position: Vector3, _normal: Vector3, player_id: String, exact: Dictionary) -> void:
	if player_id != "" and player_id != "player":
		return   # a remote actor's request, re-run on the host: its own client plays the strike
	var tool := WorkTime.held_tool(root._inventory, _work_action)
	var ev := "item.%s.hit" % tool
	if tool == "" or not SoundEvents.has_event(ev):
		return
	var at := _scene_of_pos(exact) if exact.has("chunk") and exact.has("local") else position + _offset()
	play_at(ev, at)


func _on_item_picked_up(_item_id: String, _quantity: int) -> void:
	Sound.play(PICKUP_EVENT)


## The local player asks for a loose stone or branch. The pickup plays once the host confirms it with `loose_picked`
## (reach, taken, a full bag can refuse it). On a host the pick resolves inside this same emit, and the slice's
## handler runs first, so the confirmation may already be here; a client waits up to `LOOSE_CONFIRM_MS`.
func _on_loose_pick_requested(id: String, player_id: String) -> void:
	if player_id != "":
		return   # a remote actor's pick, re-run on the host: its own client plays the sound
	if _loose_confirmed[0] == id and int(_loose_confirmed[1]) == Engine.get_process_frames():
		_loose_confirmed = ["", -1]
		Sound.play(PICKUP_EVENT)
		return
	if root._is_client:
		var now := Time.get_ticks_msec()
		for k in _loose_pending.keys():
			if now - int(_loose_pending[k]) > LOOSE_CONFIRM_MS:
				_loose_pending.erase(k)
		_loose_pending[id] = now


## The host took a loose item off the ground: the local player's own pick sounds now.
func _on_loose_picked(id: String, _regrow_at: float) -> void:
	if _loose_pending.has(id):
		var asked := int(_loose_pending[id])
		_loose_pending.erase(id)
		if Time.get_ticks_msec() - asked <= LOOSE_CONFIRM_MS:
			Sound.play(PICKUP_EVENT)
		return
	_loose_confirmed = [id, Engine.get_process_frames()]


## Host: a swing resolved here (a client hears the host's copy, `_on_combat_hit_synced`).
func _on_combat_hit_resolved(attacker_id: String, _defender_id: String, _outcome: String, _damage: float) -> void:
	if not root._is_client:
		creature_attack(attacker_id)


## Client: the host's swing, keyed "c:<instance id>" for a creature.
func _on_combat_hit_synced(attacker_key: String, _defender_key: String, _outcome: String) -> void:
	if root._is_client and attacker_key.begins_with("c:"):
		creature_attack(attacker_key.substr(2))


## A creature instance swung: its type's attack, at the creature. Nothing for a player or an unknown instance.
func creature_attack(instance_id: String) -> Node:
	if root._creature == null:
		return null
	var type := str(root._creature.get_instance_creature_id(instance_id))
	var ev := "creature.%s.attack" % type
	if type == "" or not SoundEvents.has_event(ev):
		return null
	var pos: Dictionary = root._creature.get_instance_pos(instance_id)
	if pos.is_empty():
		return null
	return play_at(ev, _scene_of_pos(pos))
