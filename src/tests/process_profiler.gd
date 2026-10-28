extends RefCounted
## Phase 183 — the playtest bot's per-node `_process` profiler (`--playtest-profile`).
##
## Godot does not time a node's `_process` for a script. The profiler takes over the scene tree's script
## `_process` callbacks instead: it switches processing off on every node that has one and calls them
## itself, in the engine's order (process priority, then tree order), each inside a `TickProbe` phase
## named after its script. `TickProbe` times phases exclusively, so the existing nested phases
## (`chunks`, `creature_ai`, `snapshots`…) come out of their caller's time and every frame's phases add
## up to the work measured.
##
## Diagnostic only: a node that switches its own processing off while taken over keeps being called, and
## built-in nodes' internal processing is not timed, so a profiled run is never the gated run.
##
## Public API:
##   requested(args) -> bool          — static, is the profiler asked for
##   take_over(root, skip) -> void    — rescan the tree and take every new script `_process` over
##   run_frame(delta) -> void         — call every taken node's `_process`, timed
##   label_of(node) -> String         — static, the phase a node's callback is timed under
##   summarize(frames, worst) -> Dictionary  — static, per phase: mean ms, and mean over the `worst` frames

const TickProbe := preload("res://src/core/tick_probe.gd")

const ARG := "--playtest-profile"
const RESCAN_FRAMES := 30   ## nodes added since the last scan (remote avatars, windows) are taken over this often

var _nodes: Array = []   ## of [node, label], in the engine's order
var _taken: Dictionary = {}   ## instance id -> true
var _since_scan := RESCAN_FRAMES

static func requested(args: Array) -> bool:
	return ARG in args

## The phase a node's `_process` is timed under: its script's file name (`voxel_slice`), so the
## instances of one script (creatures, avatars) add up.
static func label_of(node: Node) -> String:
	var script: Script = node.get_script()
	if script == null or script.resource_path == "":
		return "node:" + node.get_class()
	return "node:" + script.resource_path.get_file().get_basename()

static func _has_script_process(node: Node) -> bool:
	var script: Script = node.get_script()
	while script != null:
		for m in script.get_script_method_list():
			if str(m["name"]) == "_process":
				return true
		script = script.get_base_script()
	return false

## Take over every processing script node under `root` not yet taken, except `skip` (the bot and its
## frame-end node, whose callbacks bracket the frame). Runs every `RESCAN_FRAMES` frames.
func take_over(root: Node, skip: Array) -> void:
	_since_scan += 1
	if _since_scan < RESCAN_FRAMES:
		return
	_since_scan = 0
	var all: Array = []
	var stack: Array = [root]
	var order := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		order += 1
		if not (n in skip):
			if _taken.has(n.get_instance_id()):
				all.append([n, n.process_priority, order])
			elif n.is_processing() and _has_script_process(n):
				n.set_process(false)
				_taken[n.get_instance_id()] = true
				all.append([n, n.process_priority, order])
		var kids := n.get_children()
		kids.reverse()
		stack.append_array(kids)
	all.sort_custom(func(a, b): return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]))
	_nodes = []
	for e in all:
		_nodes.append([e[0], label_of(e[0])])

func run_frame(delta: float) -> void:
	for e in _nodes:
		var n: Variant = e[0]
		if not is_instance_valid(n) or not (n as Node).is_inside_tree() or not (n as Node).can_process():
			continue
		if (n as Node).is_processing():
			(n as Node).set_process(false)   # it switched itself back on: it ran this frame already
		TickProbe.begin(str(e[1]))
		(n as Node).call("_process", delta)
		TickProbe.end()

## `frames` is one `TickProbe.take_times()` table (µs) per recorded frame. Per phase: the mean ms over
## every frame, and over the `worst` share of frames by total time (the frames that make the p95).
static func summarize(frames: Array, worst: float = 0.05) -> Dictionary:
	var totals: Array = []
	for i in frames.size():
		var sum := 0
		for v in (frames[i] as Dictionary).values():
			sum += int(v)
		totals.append([sum, i])
	totals.sort_custom(func(a, b): return a[0] > b[0])
	var n_worst := maxi(1, int(ceil(float(frames.size()) * worst))) if not frames.is_empty() else 0
	var worst_idx := {}
	for k in n_worst:
		worst_idx[totals[k][1]] = true
	var mean: Dictionary = {}
	var worst_mean: Dictionary = {}
	for i in frames.size():
		for phase in frames[i]:
			var ms := float(frames[i][phase]) / 1000.0
			mean[phase] = float(mean.get(phase, 0.0)) + ms
			if worst_idx.has(i):
				worst_mean[phase] = float(worst_mean.get(phase, 0.0)) + ms
	var out: Dictionary = {}
	for phase in mean:
		out[phase] = {
			"mean": float(mean[phase]) / float(frames.size()),
			"worst_mean": float(worst_mean.get(phase, 0.0)) / float(n_worst),
		}
	return out
