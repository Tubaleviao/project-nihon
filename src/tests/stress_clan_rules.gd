extends RefCounted
## Phase 202 — the pure half of the `clan` stress scenario: the beats the four bots play, how in-game
## play time is counted (admin `/time` skips excluded), the verdict read from the host's world record,
## and the `stress/clan.{json,md}` report. No scene and no engine state, so `tools/stress_report.gd` runs
## it in a bare SceneTree and the suite checks it on fixed inputs.

## The beats in play order. Every beat must be in the report and pass.
const BEATS: Array[String] = [
	"join", "found", "invite", "accept", "work", "whisper", "trade", "build",
	"chest_clan", "chest_move", "dismantle_private", "outsider_chest", "outsider_build",
]
## Four members play the loop; the fifth bot is the outsider.
const MEMBERS := 4
const OUTSIDERS := 1
## In-game play time must stay under this (seconds), not counting admin time skips.
const PLAY_BUDGET_S := 3600.0
## Beats that must carry the host's refusal key.
const REFUSAL_BEATS: Array[String] = ["outsider_chest", "outsider_build"]
## The refusal keys that prove each outsider beat was refused for not being in the clan (#571): a chest locked
## to them, a block on a structure that is not theirs or inside the clan's circle. Any other key fails the beat.
const REFUSAL_KEYS := {
	"outsider_chest": ["locked"],
	"outsider_build": ["structure.refused.not_owner", "structure.refused.foreign_circle"],
}
## The only admin command the scenario may send.
const ALLOWED_ADMIN := "/time"

## One beat row. `game_s` is the in-game seconds the beat took, `skipped_s` the part of it an admin
## `/time` skip covered, `evidence` the host-side fact that proves it, `refusal` a refusal key (outsider beats).
static func beat(id: String, game_s: float, wall_s: float, skipped_s: float, evidence: String, ok: bool, refusal: String = "") -> Dictionary:
	return {
		"id": id, "game_s": game_s, "wall_s": wall_s, "skipped_s": skipped_s,
		"evidence": evidence, "ok": ok, "refusal": refusal,
	}

## In-game play time: every beat's game seconds minus what an admin skip covered.
static func play_time_s(beats: Array) -> float:
	var total := 0.0
	for b: Variant in beats:
		if b is Dictionary:
			total += maxf(0.0, float(b.get("game_s", 0.0)) - float(b.get("skipped_s", 0.0)))
	return total

## Number of distinct highest-skill ids across the members' skill tables (`{player: {skill: level}}`).
## A member with an empty table has no highest skill and is not counted. Ties go to the lexically first skill.
static func distinct_top_skills(skills_by_member: Dictionary) -> int:
	var tops := {}
	for pid: Variant in skills_by_member.keys():
		var table: Variant = skills_by_member[pid]
		if not (table is Dictionary) or (table as Dictionary).is_empty():
			continue
		var best := ""
		var best_level := -INF
		var names: Array = (table as Dictionary).keys()
		names.sort()
		for s: Variant in names:
			var lvl := float(table[s])
			if lvl > best_level:
				best_level = lvl
				best = str(s)
		tops[best] = true
	return tops.size()

## The failures of a clan report, empty when the scenario passed. `report` has `beats` (Array of `beat`),
## `admin` (Array of admin commands sent) and `world` (the host's record at the end).
static func failures(report: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var beats: Array = report.get("beats", [])
	var by_id := {}
	for b: Variant in beats:
		if b is Dictionary:
			by_id[str((b as Dictionary).get("id", ""))] = b
	for id in BEATS:
		if not by_id.has(id):
			out.append("beat %s missing" % id)
		elif not bool((by_id[id] as Dictionary).get("ok", false)):
			out.append("beat %s failed: %s" % [id, str((by_id[id] as Dictionary).get("evidence", ""))])
	for id in REFUSAL_BEATS:
		var key := str((by_id[id] as Dictionary).get("refusal", "")) if by_id.has(id) else ""
		if by_id.has(id) and key == "":
			out.append("beat %s has no refusal key" % id)
		elif by_id.has(id) and not (REFUSAL_KEYS.get(id, []) as Array).has(key):
			out.append("beat %s was refused with %s, not a membership refusal" % [id, key])
	var play := play_time_s(beats)
	if play >= PLAY_BUDGET_S:
		out.append("play time %.0f s is not under %.0f s" % [play, PLAY_BUDGET_S])
	for cmd: Variant in report.get("admin", []):
		if not str(cmd).begins_with(ALLOWED_ADMIN):
			out.append("admin command %s is not allowed" % str(cmd))
	var world: Dictionary = report.get("world", {})
	if int(world.get("members", 0)) != MEMBERS:
		out.append("clan has %d members, want %d" % [int(world.get("members", 0)), MEMBERS])
	var skills: Variant = world.get("skills", {})
	if not (skills is Dictionary) or distinct_top_skills(skills) < 2:
		out.append("fewer than two distinct highest skills")
	if int(world.get("trades", 0)) < 1:
		out.append("no completed trade")
	if int(world.get("structures", 0)) < 1:
		out.append("clan owns no structure")
	if str(world.get("chest_access", "")) != "clan":
		out.append("chest access is '%s', want clan" % str(world.get("chest_access", "")))
	if int(world.get("chest_items", 0)) < 1:
		out.append("moved item is not in the clan chest")
	return out

## The report the scenario writes: beats, admin log, world record, and the verdict.
static func build_report(beats: Array, admin: Array, world: Dictionary) -> Dictionary:
	var report := { "beats": beats, "admin": admin, "world": world }
	var fails := failures(report)
	report["play_time_s"] = play_time_s(beats)
	report["failures"] = fails
	report["passed"] = fails.is_empty()
	return report

static func markdown(report: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("# Clan loop stress scenario")
	lines.append("")
	lines.append("Verdict: **%s**. In-game play time %.0f s of %.0f s (admin skips excluded)." % [
		"PASS" if bool(report.get("passed", false)) else "FAIL", float(report.get("play_time_s", 0.0)), PLAY_BUDGET_S])
	lines.append("")
	lines.append("| Beat | In-game s | Wall s | Evidence | Refusal | Verdict |")
	lines.append("|---|---|---|---|---|---|")
	for b: Variant in report.get("beats", []):
		var d: Dictionary = b
		lines.append("| %s | %.1f | %.1f | %s | %s | %s |" % [
			str(d.get("id", "")), float(d.get("game_s", 0.0)), float(d.get("wall_s", 0.0)),
			str(d.get("evidence", "")).replace("|", "/"), str(d.get("refusal", "")), "ok" if bool(d.get("ok", false)) else "FAIL"])
	var fails: Array = report.get("failures", [])
	if not fails.is_empty():
		lines.append("")
		lines.append("## Failures")
		for f: Variant in fails:
			lines.append("- %s" % str(f))
	return "\n".join(lines) + "\n"
