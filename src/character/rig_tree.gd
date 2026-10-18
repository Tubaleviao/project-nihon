extends RefCounted
## AnimationTree wiring for a real rig (ROADMAP Phase 45).
##
## `node_for_state` is the single, pure enum -> tree-node table; the suite
## asserts it covers every `Locomotion.State` so a new state cannot silently
## animate as idle. `build_tree` turns it into an AnimationNodeStateMachine
## whose IDLE/WALK/RUN share one BlendSpace1D driven by
## `Locomotion.get_blend_weight()`. Exercised in game only (no frames in the suite).

const Locomotion := preload("res://src/character/locomotion.gd")
const Diag := preload("res://src/core/diag.gd")
const GameDataReader := preload("res://src/core/game_data_reader.gd")

## Tree node name per state. IDLE/WALK/RUN all live in the "Locomotion" blend
## space; the rest are single clips named after the state.
const NODE_LOCOMOTION := "Locomotion"
const BLEND_PARAM := "parameters/Locomotion/Space/blend_position"
const PLAYBACK_PARAM := "parameters/playback"
## The locomotion node is a blend tree: the idle/walk/run blend space, then a time scale.
const BLEND_NODE := "Space"
const SCALE_NODE := "Scale"
const SCALE_PARAM := "parameters/Locomotion/Scale/scale"

## Clips that loop, and clips that play once and hold their last key. The runtime glTF import
## leaves every clip at LOOP_NONE, so `prepare_library` applies this table; a new clip must be
## listed in one of the two (the suite asserts the table covers every clip a rig ships).
const LOOPING_CLIPS := ["idle", "walk", "run", "fall"]
const ONE_SHOT_CLIPS := ["land", "attack", "attack_unarmed", "attack_1h", "attack_tool", "death", "hit",
	"stagger", "death_back", "death_forward", "death_side", "idle_look", "idle_stretch", "sit", "lie_down", "wave"]

## The swing a body plays by what its main hand holds; a rig missing one plays `attack`.
const ATTACK_DEFAULT := "attack"
const ATTACK_UNARMED := "attack_unarmed"
const ATTACK_ONE_HAND := "attack_1h"
const ATTACK_TOOL := "attack_tool"

## OneShot nodes inside the locomotion blend tree: the flinch (additive) and the idle variant
## (replaces the pose; aborted once the body moves).
const HIT_NODE := "Hit"
const HIT_CLIP_NODE := "HitClip"
const IDLE_NODE := "IdleVariant"
const IDLE_CLIP_NODE := "IdleVariantClip"
const HIT_REQUEST_PARAM := "parameters/Locomotion/Hit/request"
const IDLE_REQUEST_PARAM := "parameters/Locomotion/IdleVariant/request"

## Stride length (metres of ground per cycle) and cycle length (seconds) of the walk and run
## clips. `clip_ground_speed` is the speed the clip covers at time scale 1; the locomotion node
## plays at `ground_speed / clip_ground_speed` so feet do not slide. A creature model overrides
## either by metadata on its AnimationPlayer (`walk_stride_m`, `run_stride_m`).
const WALK_STRIDE_M := 1.4
const RUN_STRIDE_M := 3.0
const WALK_CYCLE_S := 1.0
const RUN_CYCLE_S := 0.6
## Time scale bounds, so a stray speed never freezes or blurs the legs.
const MIN_TIME_SCALE := 0.25
const MAX_TIME_SCALE := 3.0

## Cross-fade seconds of a state machine transition.
const XFADE_LOCOMOTION := 0.12
const XFADE_ATTACK := 0.05
const XFADE_DEATH := 0.08
const XFADE_FROM_LAND := 0.1


## The attack clip for a main-hand item (`""` for empty hands): unarmed, a tool (anything the fabric
## gives a `toolType`) or a one-handed weapon. `items` is the item table (`GameData.ITEMS`).
static func attack_clip_for(item_key: String, items: Dictionary) -> String:
	if item_key == "":
		return ATTACK_UNARMED
	var res: Resource = items.get(item_key, null)
	if res != null and GameDataReader.str_field(res, "toolType", "") != "":
		return ATTACK_TOOL
	return ATTACK_ONE_HAND


static func node_for_state(state: int) -> String:
	match state:
		Locomotion.State.IDLE, Locomotion.State.WALK, Locomotion.State.RUN:
			return NODE_LOCOMOTION
		Locomotion.State.FALL: return "Fall"
		Locomotion.State.LAND: return "Land"
		Locomotion.State.ATTACK: return "Attack"
		Locomotion.State.DEATH: return "Death"
	return ""


## Clip names already reported missing, so a rig that lacks one warns once per name
## for the whole run instead of on every character built from it.
static var _warned_missing: Dictionary = {}


## The clip a tree node should play: `clip` when the player has it, else "idle" (when
## the player has that), else `clip` unchanged. A missing clip warns once.
static func _resolve_clip(player: AnimationPlayer, clip: String) -> String:
	if player.has_animation(clip):
		return clip
	if not _warned_missing.has(clip):
		_warned_missing[clip] = true
		Diag.warn("[RigTree] rig has no '%s' clip; falling back to idle" % clip)
	return "idle" if player.has_animation("idle") else clip


## Set the loop mode of every clip in the player's libraries from the table above. The one place
## that does so, for the player rig and every creature model. Clips the table does not name are
## left as imported.
static func prepare_library(player: AnimationPlayer) -> void:
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		for clip_name in lib.get_animation_list():
			var anim := lib.get_animation(clip_name)
			if clip_name in LOOPING_CLIPS:
				anim.loop_mode = Animation.LOOP_LINEAR
			elif clip_name in ONE_SHOT_CLIPS:
				anim.loop_mode = Animation.LOOP_NONE


## Length in seconds of every attack clip of `player`, by name.
static func swing_lengths(player: AnimationPlayer) -> Dictionary:
	var out := {}
	for clip_name in player.get_animation_list():
		if str(clip_name).begins_with("attack"):
			out[str(clip_name)] = player.get_animation(clip_name).length
	return out


## Metres of ground per second of clip time for the walk and run clips of `player`'s rig.
static func clip_ground_speeds(player: AnimationPlayer) -> Vector2:
	var walk_m := float(player.get_meta("walk_stride_m", WALK_STRIDE_M))
	var run_m := float(player.get_meta("run_stride_m", RUN_STRIDE_M))
	return Vector2(walk_m / WALK_CYCLE_S, run_m / RUN_CYCLE_S)


## Time scale for the locomotion node: `speed` (m/s on the ground) over the ground speed the
## clip pair covers at scale 1 at blend position `blend` (walk clip at 0.5, run at 1.0).
## 1.0 while standing (the idle clip is not a stride).
static func time_scale(speed: float, blend: float, clip_speeds: Vector2) -> float:
	if speed < Locomotion.WALK_SPEED:
		return 1.0
	var covered := clip_speeds.x
	if blend > 0.5:
		covered = lerpf(clip_speeds.x, clip_speeds.y, clampf((blend - 0.5) * 2.0, 0.0, 1.0))
	return clampf(speed / covered, MIN_TIME_SCALE, MAX_TIME_SCALE)


## Cross-fade seconds for the transition from tree node `from` to `to`.
static func xfade_for(from: String, to: String) -> float:
	if to == "Attack":
		return XFADE_ATTACK
	if to == "Death":
		return XFADE_DEATH
	if from == "Land":
		return XFADE_FROM_LAND
	return XFADE_LOCOMOTION


## Build the tree. Clips are looked up by lowercase state name ("idle", "walk",
## "run", "fall", ...) in the player's library; one the rig lacks plays "idle" instead
## (and warns once) rather than leaving the engine to log "Animation not found" every
## frame. The caller sets `anim_player` once the tree is inside the scene.
static func build_tree(player: AnimationPlayer) -> AnimationTree:
	var tree := AnimationTree.new()
	var sm := AnimationNodeStateMachine.new()
	var space := AnimationNodeBlendSpace1D.new()
	for pair in [["idle", 0.0], ["walk", 0.5], ["run", 1.0]]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = _resolve_clip(player, pair[0])
		space.add_blend_point(clip, pair[1], -1, StringName(pair[0]))
	space.min_space = 0.0
	space.max_space = 1.0
	var loco_tree := AnimationNodeBlendTree.new()
	var scale_node := AnimationNodeTimeScale.new()
	loco_tree.add_node(BLEND_NODE, space)
	loco_tree.add_node(SCALE_NODE, scale_node)
	loco_tree.connect_node(SCALE_NODE, 0, BLEND_NODE)
	var tail := SCALE_NODE
	# The idle variant replaces the pose; the flinch adds to it, so it comes last. A rig without the
	# clip simply has no node (a flinch or a variant is skipped, not faked with another clip).
	for spec in [[IDLE_NODE, IDLE_CLIP_NODE, "idle_look", false], [HIT_NODE, HIT_CLIP_NODE, "hit", true]]:
		if not player.has_animation(spec[2]):
			continue
		var shot := AnimationNodeOneShot.new()
		shot.fadein_time = 0.05
		shot.fadeout_time = 0.1
		if spec[3]:
			shot.mix_mode = AnimationNodeOneShot.MIX_MODE_ADD
		var shot_clip := AnimationNodeAnimation.new()
		shot_clip.animation = spec[2]
		loco_tree.add_node(spec[0], shot)
		loco_tree.add_node(spec[1], shot_clip)
		loco_tree.connect_node(spec[0], 0, tail)
		loco_tree.connect_node(spec[0], 1, spec[1])
		tail = spec[0]
	loco_tree.connect_node("output", 0, tail)
	sm.add_node(NODE_LOCOMOTION, loco_tree)
	var added := {NODE_LOCOMOTION: true}
	for s in Locomotion.State.values():
		var n := node_for_state(s)
		if n == "" or added.has(n):
			continue
		var clip := AnimationNodeAnimation.new()
		clip.animation = _resolve_clip(player, n.to_lower())
		sm.add_node(n, clip)
		added[n] = true
	for a in added:
		for b in added:
			if a != b:
				var tr := AnimationNodeStateMachineTransition.new()
				tr.xfade_time = xfade_for(a, b)
				sm.add_transition(a, b, tr)
	# Auto-enter the locomotion space so the machine runs before the first travel().
	var entry := AnimationNodeStateMachineTransition.new()
	entry.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("Start", NODE_LOCOMOTION, entry)
	tree.tree_root = sm
	tree.set_meta("clip_speeds", clip_ground_speeds(player))
	var clips := {}
	for clip_name in player.get_animation_list():
		clips[str(clip_name)] = true
	tree.set_meta("clips", clips)
	tree.set_meta("loco_tree", loco_tree)
	tree.set_meta("attack_node", sm.get_node("Attack"))
	tree.set_meta("death_node", sm.get_node("Death"))
	return tree


## Travel to `node` unless the tree is already heading there: `drive` runs per frame per avatar, and
## re-issuing the same travel hides real transition bugs. `playback` is the tree's state machine
## playback (anything with `travel(node)` in tests).
static func travel_once(tree: Object, playback: Object, node: String) -> bool:
	if playback == null or tree.get_meta("travel_node", "") == node:
		return false
	tree.set_meta("travel_node", node)
	playback.travel(node)
	return true


## Set the locomotion blend position and the stride-matched time scale for a ground `speed`.
static func apply_motion(tree: AnimationTree, speed: float, blend: float) -> void:
	tree.set(BLEND_PARAM, blend)
	var speeds: Vector2 = tree.get_meta("clip_speeds", Vector2(WALK_STRIDE_M / WALK_CYCLE_S, RUN_STRIDE_M / RUN_CYCLE_S))
	tree.set(SCALE_PARAM, time_scale(speed, blend, speeds))


## Point the Attack node at `clip` (a variant), falling back to `attack` when the rig lacks it (warns
## once per name, like every missing clip). Returns the clip it settled on.
static func set_attack_clip(tree: Object, clip: String) -> String:
	var clips: Dictionary = tree.get_meta("clips", {})
	var chosen := clip
	if not clips.has(chosen):
		if not _warned_missing.has(chosen):
			_warned_missing[chosen] = true
			Diag.warn("[RigTree] rig has no '%s' clip; falling back to attack" % chosen)
		chosen = ATTACK_DEFAULT
	var node: AnimationNodeAnimation = tree.get_meta("attack_node", null)
	if node != null and clips.has(chosen):
		node.animation = chosen
	tree.set_meta("attack_clip", chosen)
	return chosen


## Phase 157 — point the Death node at the variant `clip`, falling back to `death` when the rig lacks it.
## Returns the clip it settled on.
static func set_death_clip(tree: Object, clip: String) -> String:
	var clips: Dictionary = tree.get_meta("clips", {})
	var chosen := clip if clips.has(clip) else "death"
	var node: AnimationNodeAnimation = tree.get_meta("death_node", null)
	if node != null and clips.has(chosen):
		node.animation = chosen
	tree.set_meta("death_clip", chosen)
	return chosen


## Fire a OneShot (`param` is its request parameter) after pointing its clip node at `clip`.
## `count_key` is the meta counter the suite reads; no frames elapse there, so it counts what was fired.
static func _fire_shot(tree: Object, node_name: String, clip_node: String, param: String, clip: String, count_key: String) -> bool:
	var loco_tree: AnimationNodeBlendTree = tree.get_meta("loco_tree", null)
	if loco_tree == null or not loco_tree.has_node(node_name):
		return false
	var clips: Dictionary = tree.get_meta("clips", {})
	if clips.has(clip):
		(loco_tree.get_node(clip_node) as AnimationNodeAnimation).animation = clip
	tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	tree.set_meta(count_key, int(tree.get_meta(count_key, 0)) + 1)
	return true


static func fire_hit(tree: Object, clip: String = "hit") -> bool:
	if not tree.get_meta("clips", {}).has(clip):
		clip = "hit"
	return _fire_shot(tree, HIT_NODE, HIT_CLIP_NODE, HIT_REQUEST_PARAM, clip, "hit_shots")


static func fire_idle_variant(tree: Object, clip: String) -> bool:
	return _fire_shot(tree, IDLE_NODE, IDLE_CLIP_NODE, IDLE_REQUEST_PARAM, clip, "idle_shots")


## Cut an idle variant short (the body started moving).
static func abort_idle_variant(tree: Object) -> void:
	var loco_tree: AnimationNodeBlendTree = tree.get_meta("loco_tree", null)
	if loco_tree != null and loco_tree.has_node(IDLE_NODE):
		tree.set(IDLE_REQUEST_PARAM, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)


## Run the one-shots a locomotion object asked for since the last call: a new swing restarts the Attack
## clip (a second hit in the same state would otherwise leave it playing), a new hit fires the flinch, a
## new idle variant fires once and is cut when the body leaves idle.
static func drive_shots(tree: Object, playback: Object, loco) -> void:
	var swing: int = loco.swing_serial
	if swing != int(tree.get_meta("swing_serial", 0)):
		tree.set_meta("swing_serial", swing)
		if loco.get_state() == Locomotion.State.ATTACK:
			set_attack_clip(tree, loco.attack_clip)
			if playback != null and tree.get_meta("travel_node", "") == "Attack":
				playback.start("Attack")
				tree.set_meta("swing_restarts", int(tree.get_meta("swing_restarts", 0)) + 1)
	var hit: int = loco.hit_serial
	if hit != int(tree.get_meta("hit_serial", 0)):
		tree.set_meta("hit_serial", hit)
		fire_hit(tree, loco.hit_clip)
	var idle: int = loco.idle_serial
	if idle != int(tree.get_meta("idle_serial", 0)):
		tree.set_meta("idle_serial", idle)
		fire_idle_variant(tree, loco.idle_clip)
	elif loco.get_state() != Locomotion.State.IDLE and tree.get_meta("idle_shots", 0) > 0:
		abort_idle_variant(tree)


## Push a locomotion update into the tree: travel to the state's node (once per change), set the
## blend position and the time scale.
static func drive(tree: AnimationTree, loco) -> void:
	var playback: Object = tree.get(PLAYBACK_PARAM)
	drive_shots(tree, playback, loco)
	if loco.get_state() == Locomotion.State.DEATH and tree.get_meta("travel_node", "") != "Death":
		set_death_clip(tree, loco.death_clip)
	travel_once(tree, playback, node_for_state(loco.get_state()))
	apply_motion(tree, loco.get_speed(), loco.get_blend_weight())
