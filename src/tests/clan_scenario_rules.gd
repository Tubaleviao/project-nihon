extends RefCounted
## Phase 202 — the pure half of the clan loop scenario: the beats the four bots play, the in-game
## clock that excludes admin time skips, the checks read from the host's world record, and the
## `stress/clan.{json,md}` report. No scene and no autoload, so the suite checks it on fixed inputs
## and `tools/stress_report.gd` can render it in a bare SceneTree.

## The bots in the order they join; bot 0 founds the clan, bot 4 never joins it.
const MEMBERS := 4
const BOT_COUNT := 5
## The in-game play time budget in seconds (one hour), admin `/time` skips excluded.
const PLAY_BUDGET_S := 3600.0
## Each beat, in play order. `evidence` names what the host's world record must show once it is done.
const BEATS: Array[Dictionary] = [
	{ "id": "found", "bot": 0, "evidence": "clan_exists" },
	{ "id": "invite_accept", "bot": 0, "evidence": "clan_members_4" },
	{ "id": "work", "bot": -1, "evidence": "skills_differ" },
	{ "id": "see_skills", "bot": -1, "evidence": "clan_view_has_skills" },
	{ "id": "whisper", "bot": 1, "evidence": "whisper_delivered" },
	{ "id": "trade", "bot": 1, "evidence": "trade_completed" },
	{ "id": "build", "bot": -1, "evidence": "clan_structure" },
	{ "id": "chest", "bot": 2, "evidence": "chest_clan_with_item" },
	{ "id": "dismantle", "bot": 3, "evidence": "private_block_removed" },
	{ "id": "outsider", "bot": 4, "evidence": "refusals_recorded" },
]

static func beat_ids() -> Array:
	var ids: Array = []
	for b in BEATS:
		ids.append(str(b["id"]))
	return ids

## Seconds of play: wall seconds the scenario ran minus the in-game seconds an admin `/time` skip
## moved the clock. `skips` is a list of `{ at_s, skipped_s }` the scenario recorded; a skip that is
## negative or longer than the run itself is clamped so a bad record cannot make the clock negative.
static func play_seconds(elapsed_game_s: float, skips: Array) -> float:
	var skipped := 0.0
	for s in skips:
		if s is Dictionary:
			skipped += maxf(0.0, float((s as Dictionary).get("skipped_s", 0.0)))
	return maxf(0.0, elapsed_game_s - skipped)

## The checks the host's world record at the end of the run must pass. `world` is
## `{ clan: { members: [id…], chest_access, chest_items: {item: n} }, skills: { id: {skill: level} },
## trades_completed, structures: [{ owner_kind }], refusals: [key…] }`. Returns `{ name: bool }`.
static func world_checks(world: Dictionary) -> Dictionary:
	var clan: Dictionary = world.get("clan", {}) if world.get("clan", null) is Dictionary else {}
	var members: Array = clan.get("members", []) if clan.get("members", null) is Array else []
	var tops := {}
	var skills: Dictionary = world.get("skills", {}) if world.get("skills", null) is Dictionary else {}
	for id in members:
		var mine: Variant = skills.get(str(id), {})
		if mine is Dictionary and not (mine as Dictionary).is_empty():
			tops[_top_skill(mine)] = true
	var owns := false
	for s in world.get("structures", []):
		if s is Dictionary and str((s as Dictionary).get("owner_kind", "")) == "clan":
			owns = true
	var items: Dictionary = clan.get("chest_items", {}) if clan.get("chest_items", null) is Dictionary else {}
	var moved := false
	for k in items:
		if int(items[k]) > 0:
			moved = true
	var refusals: Array = world.get("refusals", []) if world.get("refusals", null) is Array else []
	return {
		"clan_has_4_members": members.size() == MEMBERS,
		"skills_differ": tops.size() >= 2,
		"one_trade_completed": int(world.get("trades_completed", 0)) >= 1,
		"clan_owns_structure": owns,
		"chest_clan_with_item": str(clan.get("chest_access", "")) == "clan" and moved,
		"outsider_chest_refused": refusals.has("chest_refused"),
		"outsider_build_refused": refusals.has("build_refused"),
	}

static func _top_skill(levels: Dictionary) -> String:
	var best := ""
	var best_level := -1.0
	var names: Array = levels.keys()
	names.sort()   # a tie is decided by name, so the answer does not depend on dictionary order
	for k in names:
		if float(levels[k]) > best_level:
			best_level = float(levels[k])
			best = str(k)
	return best

## The verdict of a whole run: every beat passed, play time under the budget, every world check true.
## Returns `{ pass, failures: [String] }`.
static func verdict(beats: Array, play_s: float, checks: Dictionary) -> Dictionary:
	var failures: Array = []
	var seen := {}
	for b in beats:
		if b is Dictionary:
			seen[str((b as Dictionary).get("id", ""))] = bool((b as Dictionary).get("pass", false))
	for id in beat_ids():
		if not seen.has(id):
			failures.append("beat %s did not run" % id)
		elif not seen[id]:
			failures.append("beat %s failed" % id)
	if play_s >= PLAY_BUDGET_S:
		failures.append("play time %.0f s is not under %.0f s" % [play_s, PLAY_BUDGET_S])
	for k in checks:
		if not bool(checks[k]):
			failures.append("check %s is false" % k)
	return { "pass": failures.is_empty(), "failures": failures }

static func build_report(beats: Array, skips: Array, game_s: float, world: Dictionary) -> Dictionary:
	var play_s := play_seconds(game_s, skips)
	var checks := world_checks(world)
	var v := verdict(beats, play_s, checks)
	return { "scenario": "clan", "beats": beats, "time_skips": skips, "game_s": game_s, "play_s": play_s,
		"checks": checks, "refusals": world.get("refusals", []), "pass": v["pass"], "failures": v["failures"] }

static func report_markdown(report: Dictionary) -> String:
	var out := PackedStringArray()
	out.append("# Clan loop scenario: %s" % ("PASS" if bool(report.get("pass", false)) else "FAIL"))
	out.append("")
	out.append("In-game play time %.0f s of %.0f s (admin time skips excluded: %d)." % [
		float(report.get("play_s", 0.0)), PLAY_BUDGET_S, (report.get("time_skips", []) as Array).size()])
	out.append("")
	out.append("| Beat | Game s | Wall s | Evidence | Verdict |")
	out.append("|---|---|---|---|---|")
	for b in report.get("beats", []):
		var d: Dictionary = b
		out.append("| %s | %.1f | %.1f | %s | %s |" % [str(d.get("id", "")), float(d.get("game_s", 0.0)),
			float(d.get("wall_s", 0.0)), str(d.get("evidence", "")), "pass" if bool(d.get("pass", false)) else "FAIL"])
	out.append("")
	out.append("| World check | Result |")
	out.append("|---|---|")
	var checks: Dictionary = report.get("checks", {})
	var names: Array = checks.keys()
	names.sort()
	for k in names:
		out.append("| %s | %s |" % [str(k), "pass" if bool(checks[k]) else "FAIL"])
	out.append("")
	out.append("Refusals seen: %s" % ", ".join(PackedStringArray(report.get("refusals", []))))
	for f in report.get("failures", []):
		out.append("- FAILURE: %s" % str(f))
	return "\n".join(out) + "\n"
