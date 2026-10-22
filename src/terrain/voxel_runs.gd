extends RefCounted

const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const STEP_HEIGHT := VoxelConsts.STEP_HEIGHT
const BEDROCK_DEPTH := VoxelConsts.BEDROCK_DEPTH
const MAX_HEIGHT := VoxelConsts.MAX_HEIGHT

# ---------------------------------------------------------------------------
# Run algebra — the column model (Phase 41)
# ---------------------------------------------------------------------------

## Replay a tile's typed run edits over its natural runs. Pure (no node state), so
## the column model is testable on its own — and it is the ONLY place edits turn
## into geometry, shared by the mesher, the collision soup, the footing sampler and
## the save manifest.
static func apply_run_ops(runs: Array, ops: Array) -> Array:
	var out: Array = []
	for run in runs:
		out.append({ "bottom": float(run["bottom"]), "top": float(run["top"]), "material": str(run.get("material", "")) })
	for op in ops:
		if not (op is Dictionary):
			continue
		var o: Dictionary = op
		var bottom := float(o.get("bottom", 0.0))
		var top := float(o.get("top", 0.0))
		if top <= bottom:
			continue
		var kind := str(o.get("op", ""))
		if kind == "add":
			out = add_span(out, bottom, top, str(o.get("material", "")))
		elif kind == "remove":
			out = remove_span(out, bottom, top)
		# An unknown kind is IGNORED, never treated as a remove: the two kinds are
		# not symmetric (one fills, one carves), and defaulting to the carving one
		# is how a corrupt edit list silently eats terrain (see `_normalise_ops`).
	return out

## Add a solid span, merging it with runs of the SAME material it touches or
## overlaps. Material is part of a run's identity: a placed block stays its own run
## above the natural ground, so the natural base keeps the biome's colour instead
## of being repainted by whatever the player stacked on it.
static func add_span(runs: Array, bottom: float, top: float, material: String) -> Array:
	var out: Array = []
	for run in runs:
		out.append({ "bottom": float(run["bottom"]), "top": float(run["top"]), "material": str(run.get("material", "")) })
	out.append({ "bottom": bottom, "top": top, "material": material })
	# A total order (bottom, then top, then material): `sort_custom` is not stable, so a tie on
	# `bottom` alone left the run order, and the merge below, up to the sort's whim (Phase 168).
	out.sort_custom(func(a, b):
		if float(a["bottom"]) != float(b["bottom"]):
			return float(a["bottom"]) < float(b["bottom"])
		if float(a["top"]) != float(b["top"]):
			return float(a["top"]) < float(b["top"])
		return str(a["material"]) < str(b["material"]))
	var merged: Array = []
	for run in out:
		if merged.is_empty():
			merged.append(run)
			continue
		var prev: Dictionary = merged[-1]
		var touches := float(run["bottom"]) <= float(prev["top"]) + 0.000001
		if touches and str(prev["material"]) == str(run["material"]):
			prev["top"] = maxf(float(prev["top"]), float(run["top"]))
		else:
			merged.append(run)
	return merged

## Carve a solid span OUT of the runs — the mining edit. Trims a run that
## partially overlaps, drops one fully covered, and SPLITS one the span sits
## strictly inside. That split is what a tunnel IS: a floor run and a roof run,
## and mining either of them leaves the other alone.
static func remove_span(runs: Array, bottom: float, top: float) -> Array:
	var out: Array = []
	for run in runs:
		var rbottom := float(run["bottom"])
		var rtop := float(run["top"])
		var material := str(run.get("material", ""))
		if top <= rbottom or bottom >= rtop:
			out.append({ "bottom": rbottom, "top": rtop, "material": material })
			continue
		if rbottom < bottom:
			out.append({ "bottom": rbottom, "top": bottom, "material": material })
		if rtop > top:
			out.append({ "bottom": top, "top": rtop, "material": material })
	return out

## The run whose TOP is the plane `y` (within half a step), or {} when no run tops
## there. Phase 41 — a top-face hit names the run it LANDED on, not the column's
## topmost one: a tunnel FLOOR keeps an exposed top face with the roof above it, so
## "the topmost run" answers with the roof and carves (or stacks on) the wrong span
## from a click on the floor. Falls back to the caller's reading when the y is not
## on any run boundary (the boot demo passes the spawn plain's height, not the
## target tile's), which is what keeps a misaligned y behaving as it did before.
## Pure, so the resolution rule is testable on its own.
static func runs_topping_at(runs: Array, y: float) -> Dictionary:
	var best: Dictionary = {}
	for run in runs:
		if absf(float(run["top"]) - y) > STEP_HEIGHT * 0.5:
			continue
		if best.is_empty() or float(run["top"]) > float(best["top"]):
			best = run
	return best

## True when any run covers the ordinate `y` (half-open [bottom, top]). The rule
## the mesher asks before emitting a top or an underside face.
static func runs_cover_y(runs: Array, y: float) -> bool:
	for run in runs:
		if float(run["bottom"]) - 0.000001 <= y and y < float(run["top"]) - 0.000001:
			return true
	return false

## The parts of `run` that `others` do NOT fill, as [{ "bottom", "top" }]. Used to
## build a wall face per neighbour from solidity difference, so a wall is emitted
## exactly where this column has material the neighbour has not.
static func subtract_runs(run: Dictionary, others: Array) -> Array:
	var segments: Array = [{ "bottom": float(run["bottom"]), "top": float(run["top"]) }]
	for other in others:
		var ob := float(other["bottom"])
		var ot := float(other["top"])
		var next: Array = []
		for seg in segments:
			if ot <= float(seg["bottom"]) or ob >= float(seg["top"]):
				next.append(seg)
				continue
			if float(seg["bottom"]) < ob:
				next.append({ "bottom": float(seg["bottom"]), "top": ob })
			if float(seg["top"]) > ot:
				next.append({ "bottom": ot, "top": float(seg["top"]) })
		segments = next
	return segments

## The typed run edits a pre-Phase-41 scalar height edit migrates to. An old edit
## was an absolute quantised column TOP and the column it described is the single
## run from BEDROCK_DEPTH up to that height — exactly what this pair of edits
## resolves to against the tile's own natural run. `materials` is the legacy
## per-tile stack of placed blocks: the natural run ends that many steps BELOW the
## edited top, and each placed block becomes its own `add` span above it. Pure, so
## the migration rule is testable on its own.
##
## The stack survives every case, including the re-rolled-seed one: an edit whose
## top reaches further than `placed` steps above the CURRENT base top means the
## ground itself moved under the save (a version-1 world re-rolls once), not that
## the stack vanished — so the natural span is re-added up to the stack's own base
## and the materials still sit on top of it, still theirs. Collapsing that case
## into one anonymous span (the pre-review behaviour) repaints a re-rolled world's
## player work as natural ground, which is the one thing this migration exists to
## refuse to do.
static func legacy_edit_ops(legacy_height: float, base_top: float, materials: Array = []) -> Array:
	var placed := materials.size()
	var natural_top := legacy_height - float(placed) * STEP_HEIGHT
	# Nothing can sit above the edited top, so a legacy height with nothing
	# stacked on it is one plain span (up to it, or down to it when the edit
	# carved): the common shape, and the one that has to stay a single op.
	if placed == 0:
		if legacy_height >= base_top:
			return [{ "op": "add", "bottom": base_top, "top": legacy_height, "material": "" }]
		return [{ "op": "remove", "bottom": legacy_height, "top": base_top }]
	var ops: Array = []
	if natural_top > base_top:
		ops.append({ "op": "add", "bottom": base_top, "top": natural_top, "material": "" })
	elif natural_top < base_top:
		ops.append({ "op": "remove", "bottom": natural_top, "top": base_top })
	for k in range(placed):
		ops.append({
			"op":       "add",
			"bottom":   natural_top + float(k) * STEP_HEIGHT,
			"top":      natural_top + float(k + 1) * STEP_HEIGHT,
			"material": str(materials[k]),
		})
	return ops

