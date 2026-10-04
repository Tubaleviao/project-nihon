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
const BLEND_PARAM := "parameters/Locomotion/blend_position"
const PLAYBACK_PARAM := "parameters/playback"


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
	sm.add_node(NODE_LOCOMOTION, space)
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
				sm.add_transition(a, b, AnimationNodeStateMachineTransition.new())
	# Auto-enter the locomotion space so the machine runs before the first travel().
	var entry := AnimationNodeStateMachineTransition.new()
	entry.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("Start", NODE_LOCOMOTION, entry)
	tree.tree_root = sm
	return tree


## Push a locomotion update into the tree: travel to the state's node and set
## the blend position.
static func drive(tree: AnimationTree, loco) -> void:
	var playback = tree.get(PLAYBACK_PARAM)
	if playback != null:
		playback.travel(node_for_state(loco.get_state()))
	tree.set(BLEND_PARAM, loco.get_blend_weight())
