extends RefCounted
## AnimationTree wiring for a real rig (ROADMAP Phase 45).
##
## `node_for_state` is the single, pure enum -> tree-node table; the suite
## asserts it covers every `Locomotion.State` so a new state cannot silently
## animate as idle. `build_tree` turns it into an AnimationNodeStateMachine
## whose IDLE/WALK/RUN share one BlendSpace1D driven by
## `Locomotion.get_blend_weight()`. Exercised in game only (no frames in the suite).

const Locomotion := preload("res://src/character/locomotion.gd")

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


## Build the tree. Clips are looked up by lowercase state name ("idle", "walk",
## "run", "fall", ...) in the player's library; a missing clip leaves that node
## without an animation (warns once) rather than failing.
static func build_tree(player: AnimationPlayer) -> AnimationTree:
	var tree := AnimationTree.new()
	var sm := AnimationNodeStateMachine.new()
	var space := AnimationNodeBlendSpace1D.new()
	for pair in [["idle", 0.0], ["walk", 0.5], ["run", 1.0]]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = pair[0]
		space.add_blend_point(clip, pair[1])
	space.min_space = 0.0
	space.max_space = 1.0
	sm.add_node(NODE_LOCOMOTION, space)
	var added := {NODE_LOCOMOTION: true}
	for s in Locomotion.State.values():
		var n := node_for_state(s)
		if n == "" or added.has(n):
			continue
		var clip := AnimationNodeAnimation.new()
		clip.animation = n.to_lower()
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
	tree.anim_player = tree.get_path_to(player) if tree.is_inside_tree() else NodePath()
	return tree


## Push a locomotion update into the tree: travel to the state's node and set
## the blend position.
static func drive(tree: AnimationTree, loco) -> void:
	var playback = tree.get(PLAYBACK_PARAM)
	if playback != null:
		playback.travel(node_for_state(loco.get_state()))
	tree.set(BLEND_PARAM, loco.get_blend_weight())
