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
const ONE_SHOT_CLIPS := ["land", "attack", "death", "hit", "sit", "lie_down", "wave"]

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
	loco_tree.connect_node("output", 0, SCALE_NODE)
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


## Push a locomotion update into the tree: travel to the state's node (once per change), set the
## blend position and the time scale.
static func drive(tree: AnimationTree, loco) -> void:
	travel_once(tree, tree.get(PLAYBACK_PARAM), node_for_state(loco.get_state()))
	apply_motion(tree, loco.get_speed(), loco.get_blend_weight())
