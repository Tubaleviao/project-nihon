extends RefCounted
## Phase 162 — the pure half of the crowd stress run: the bots' walk patterns, the budgets, and the
## report builder that turns the recorders' JSON into `stress/report.{json,md}`.
##
## No scene, no autoloads, no engine state: `tools/stress_report.gd` runs it in a bare SceneTree, the
## bot process walks its bots with it, and the suite checks it on fixed inputs. Mirrored constants
## (walk speed, send interval) are pinned to their sources by the suite.

## The walk patterns `--stress-pattern` accepts, in the order `tools/stress.sh` runs them.
const PATTERNS: Array[String] = ["cluster", "spread", "cross", "pole", "churn"]
## The crowd sizes of the ladder, smallest first.
const LADDER: Array[int] = [16, 32, 64, 128, 200]

## The budgets a run must meet for its size to count as supported.
const BUDGETS := {
	"host_tick_p95_ms": 16.0,
	"down_kbps_per_peer": 64.0,
	"watch_frame_p95_ms": 33.0,
	"relay_lag_ms": 250.0,
}
## The ladder stops climbing once a run's host tick p95 passes this (a size that slow tells nothing new).
const LADDER_STOP_TICK_P95_MS := 50.0
## A frame (host or watcher) longer than this is a hard failure.
const HARD_FRAME_MS := 2000.0
## Phase 163 — the largest passing size of each series in the committed baseline
## (`docs/perf/crowd-baseline.md`, the Phase 162 run). A run whose series falls below it fails the
## stress job: the crowd the host supports may only grow.
const BASELINE_LARGEST := {
	"lan/cluster": 16,
	"lan/cross": 16,
	"lan/spread": 16,
	"lan/pole": 32,
	"lan/churn": 0,
}

## Mirrors `PlayerSlice.SPEED` (m/s on foot) and the client's report interval
## (`PlayerSlice.SYNC_INTERVAL` physics ticks at 60 Hz), so a bot walks and reports like a player.
const WALK_SPEED := 4.5
const SEND_INTERVAL := 0.5
## Mirrors `RelayBatch.NEAR_RADIUS`: only relays of subjects this close to the watcher count toward the
## relay lag. Farther ones are thinned on purpose (one per `FAR_GAP_MS`, a held change sent once due),
## so their arrival trails the send by design, not by load.
const RELAY_NEAR_M := 24.0

## `cluster` / `churn`: bots wander between random points inside this disc around the anchor (m).
const CLUSTER_RADIUS := 30.0
## `cross`: each bot paces a line this long (m) through the anchor, so it crosses AOI cells (96 m) and
## chunk borders (32 m) every lap.
const CROSS_SPAN := 200.0
## `pole`: bots start this many chunks short of the fold row and walk north across it.
const POLE_START_CHUNKS := 2
## `pole`: bots spread over this width (m) across the meridian.
const POLE_WIDTH := 40.0
## `churn`: seconds online and offline, each drawn per cycle from [min, max].
const CHURN_ONLINE := Vector2(4.0, 9.0)
const CHURN_OFFLINE := Vector2(1.5, 4.0)

## The tick phases the host probe reports (`TickProbe` names), and the label the report gives each.
const PHASE_LABELS := {
	"net_in": "networking poll (inbound packets)",
	"aoi_relay": "AOI relays and equipment pairs",
	"snapshots": "join and AOI re-scope snapshots",
	"peer_windows": "peer streaming windows (periodic re-centre)",
	"window_moves": "peer window moves on joins and AOI crossings",
	"creature_ai": "creature AI",
	"creature_sync": "creature syncs",
	"chunks": "chunk records and region streaming",
	"save": "save",
}

static func is_pattern(name: String) -> bool:
	return PATTERNS.has(name)

# ---------------------------------------------------------------------------
# Walk patterns
# ---------------------------------------------------------------------------

## A generator seeded by `(seed, bot, k)`: the same triple always draws the same numbers.
static func _rng(seed: int, bot: int, k: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed, bot, k])
	return r

## Where bot `bot` stands `t` seconds into a run of `pattern`, as an XZ offset (m) from its anchor.
## For `pole` the anchor is the pole start (see `pole_anchor_chunk_y`) and +Y runs north. Pure and
## deterministic: two runs with the same seed walk the same paths.
static func bot_offset(pattern: String, seed: int, bot: int, t: float) -> Vector2:
	match pattern:
		"cluster", "churn":
			return _wander(seed, bot, t)
		"spread":
			# Golden-angle headings: any number of bots fan out evenly, each on its own ray.
			var angle := float(bot) * 2.399963 + float(posmod(seed, 360)) * PI / 180.0
			var start := _wander(seed, bot, 0.0)
			return start + Vector2(cos(angle), sin(angle)) * WALK_SPEED * t
		"cross":
			var r := _rng(seed, bot, -1)
			var lane := r.randf_range(-CLUSTER_RADIUS, CLUSTER_RADIUS)
			var d := _triangle(t * WALK_SPEED + r.randf() * 2.0 * CROSS_SPAN, CROSS_SPAN) - CROSS_SPAN * 0.5
			return Vector2(d, lane) if bot % 2 == 0 else Vector2(lane, d)
		"pole":
			var r := _rng(seed, bot, -2)
			return Vector2(r.randf_range(-POLE_WIDTH, POLE_WIDTH) * 0.5, r.randf_range(0.0, 8.0) + WALK_SPEED * t)
	return Vector2.ZERO

## A triangle wave over [0, span]: `s` metres walked, pacing back and forth.
static func _triangle(s: float, span: float) -> float:
	var m := fposmod(s, 2.0 * span)
	return m if m <= span else 2.0 * span - m

## Random-waypoint walk inside the cluster disc: waypoint `k` is drawn from `(seed, bot, k)`, and the
## bot walks the legs at walking speed.
static func _wander(seed: int, bot: int, t: float) -> Vector2:
	var at := _disc_point(seed, bot, 0)
	var left := maxf(t, 0.0) * WALK_SPEED
	var k := 1
	while k < 100000:
		var next := _disc_point(seed, bot, k)
		var leg := at.distance_to(next)
		if leg >= left:
			return at + (next - at) * (left / maxf(leg, 0.0001))
		left -= leg
		at = next
		k += 1
	return at

static func _disc_point(seed: int, bot: int, k: int) -> Vector2:
	var r := _rng(seed, bot, k)
	var a := r.randf() * TAU
	return Vector2(cos(a), sin(a)) * CLUSTER_RADIUS * sqrt(r.randf())

## `churn`: is bot `bot` connected `t` seconds in? Every bot starts online after a short stagger,
## then alternates online and offline spells drawn per cycle. Other patterns are always online.
static func online_at(pattern: String, seed: int, bot: int, t: float) -> bool:
	if pattern != "churn":
		return true
	var clock := _rng(seed, bot, -3).randf_range(0.0, 2.0)
	if t < clock:
		return false
	var cycle := 0
	while cycle < 100000:
		var r := _rng(seed, bot, 1000 + cycle)
		var on := r.randf_range(CHURN_ONLINE.x, CHURN_ONLINE.y)
		var off := r.randf_range(CHURN_OFFLINE.x, CHURN_OFFLINE.y)
		if t < clock + on:
			return true
		if t < clock + on + off:
			return false
		clock += on + off
		cycle += 1
	return false

# ---------------------------------------------------------------------------
# Statistics
# ---------------------------------------------------------------------------

## The `p`-th percentile (0–100) of `values`, linearly interpolated between the closest ranks (0 for
## an empty list).
static func percentile(values: Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var rank := clampf(p, 0.0, 100.0) / 100.0 * float(sorted.size() - 1)
	var lo := floori(rank)
	var hi := mini(lo + 1, sorted.size() - 1)
	return lerpf(float(sorted[lo]), float(sorted[hi]), rank - float(lo))

static func _max(values: Array) -> float:
	var m := 0.0
	for v in values:
		m = maxf(m, float(v))
	return m

static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var s := 0.0
	for v in values:
		s += float(v)
	return s / float(values.size())

## Each phase's share of the summed phase time (0–1), from `{ phase: µs }`.
static func phase_shares(phase_us: Dictionary) -> Dictionary:
	var total := 0.0
	for k in phase_us:
		total += float(phase_us[k])
	var out := {}
	for k in phase_us:
		out[k] = float(phase_us[k]) / total if total > 0.0 else 0.0
	return out

## kbit/s each peer received from the host: `out_peer` (peer -> [bytes, packets]) over the seconds
## each peer was connected (`peer_seconds`, peer -> s). Peers connected under a second are skipped.
static func peer_kbps(out_peer: Dictionary, peer_seconds: Dictionary) -> Dictionary:
	var out := {}
	for peer in out_peer:
		var secs := float(peer_seconds.get(peer, 0.0))
		if secs < 1.0:
			continue
		out[peer] = float((out_peer[peer] as Array)[0]) * 8.0 / 1000.0 / secs
	return out

## The least-squares slope of `points` ([[x, y], ...]); 0 with fewer than two distinct x.
static func slope(points: Array) -> float:
	return fit_line(points).x

## The least-squares line through `points` as Vector2(slope, intercept). With fewer than two distinct
## x the slope is 0 and the intercept is the mean y.
static func fit_line(points: Array) -> Vector2:
	var n := float(points.size())
	if n < 1.0:
		return Vector2.ZERO
	var sx := 0.0
	var sy := 0.0
	for pt in points:
		sx += float(pt[0])
		sy += float(pt[1])
	var mx := sx / n
	var my := sy / n
	var num := 0.0
	var den := 0.0
	for pt in points:
		num += (float(pt[0]) - mx) * (float(pt[1]) - my)
		den += (float(pt[0]) - mx) * (float(pt[0]) - mx)
	var k := num / den if den > 0.0 else 0.0
	return Vector2(k, my - k * mx)

# ---------------------------------------------------------------------------
# One run: host + watcher + bots -> a metrics row
# ---------------------------------------------------------------------------

## Join the bots' sends with the watcher's arrivals: each relay the watcher saw is matched to the
## send it carried (`"<peer>|<key>"` -> unix ms), and its lag is arrival minus send (ms). An arrival
## whose 4th field (the watcher's distance to the subject) is past `RELAY_NEAR_M` is skipped.
static func relay_lags(sends: Dictionary, seen: Array) -> Array:
	var out: Array = []
	for row in seen:
		if (row as Array).size() > 3 and float(row[3]) > RELAY_NEAR_M:
			continue
		var key := "%d|%s" % [int(row[0]), str(row[1])]
		if sends.has(key):
			out.append(maxf(0.0, float(row[2]) - float(sends[key])))
	return out

## The metrics row of one run from the three recorders' JSON (any may be empty when its process
## crashed; the row then names the failure).
static func run_row(host: Dictionary, watch: Dictionary, bots: Dictionary) -> Dictionary:
	var tick: Array = host.get("tick_ms", [])
	var frames := maxi(tick.size(), 1)
	var phase_us: Dictionary = host.get("phase_us", {})
	var phase_ms := {}
	for k in phase_us:
		phase_ms[k] = float(phase_us[k]) / 1000.0 / float(frames)
	var kbps := peer_kbps(host.get("out_peer", {}), host.get("peer_seconds", {}))
	var watch_frames: Array = watch.get("frame_ms", [])
	var lags := relay_lags(bots.get("sends", {}), watch.get("relay_seen", []))
	var row := {
		"pattern": str(host.get("pattern", bots.get("pattern", ""))),
		"profile": str(host.get("profile", "")),
		"size": int(bots.get("n", host.get("size", 0))),
		"host_tick_p50_ms": percentile(tick, 50.0),
		"host_tick_p95_ms": percentile(tick, 95.0),
		"host_tick_p99_ms": percentile(tick, 99.0),
		"host_tick_max_ms": _max(tick),
		"host_frames": tick.size(),
		"phase_ms_per_tick": phase_ms,
		"phase_shares": phase_shares(phase_us),
		"down_kbps_per_peer": percentile(kbps.values(), 95.0),
		"down_kbps_mean": _mean(kbps.values()),
		"up_bytes": _bytes_total(host.get("in_peer", {})),
		"down_bytes": _bytes_total(host.get("out_peer", {})),
		"packets_down_per_peer_s": _packets_rate(host.get("out_peer", {}), host.get("peer_seconds", {})),
		"bytes_by_type": _type_bytes(host.get("out_type", {})),
		"kbps_by_type": type_kbps(host.get("out_type", {}), host.get("peer_seconds", {})),
		"peers_max": int(host.get("peers_max", 0)),
		"aoi_cell_peers_max": int(host.get("aoi_cell_peers_max", 0)),
		"rtt_ms_p95": float(host.get("rtt_ms_p95", 0.0)),
		"enet_loss_p95": float(host.get("enet_loss_p95", 0.0)),
		"enet_throttle_min": float(host.get("enet_throttle_min", 0.0)),
		"chunks_in_flight_max": int(host.get("chunks_in_flight_max", 0)),
		"chunks_waiting_max": int(host.get("chunks_waiting_max", 0)),
		"region_reads": int(host.get("region_reads", 0)),
		"memory_mb_max": float(host.get("memory_mb_max", 0.0)),
		"nodes_max": int(host.get("nodes_max", 0)),
		"watch_frame_p95_ms": percentile(watch_frames, 95.0),
		"watch_frame_max_ms": _max(watch_frames),
		"watch_avatars_max": int(watch.get("avatars_max", 0)),
		"watch_bytes_in": int(watch.get("bytes_in", 0)),
		"watch_relay_apply_us": float(watch.get("relay_apply_us", 0.0)) / maxf(1.0, float(watch.get("relays", 0))),
		"relay_lag_ms": percentile(lags, 95.0),
		"relay_lag_samples": lags.size(),
		"bots_joined": int(bots.get("joined", 0)),
		"window_s": float(host.get("window_s", 0.0)),
	}
	row["budgets_met"] = budgets_met(row)
	row["hard_failures"] = hard_failures(host, watch, bots)
	return row

static func _bytes_total(table: Dictionary) -> int:
	var total := 0
	for k in table:
		total += int((table[k] as Array)[0])
	return total

static func _packets_rate(out_peer: Dictionary, peer_seconds: Dictionary) -> float:
	var rates: Array = []
	for peer in out_peer:
		var secs := float(peer_seconds.get(peer, 0.0))
		if secs >= 1.0:
			rates.append(float((out_peer[peer] as Array)[1]) / secs)
	return _mean(rates)

## kbit/s per connected peer that each message type costs: its bytes over every peer's connected
## seconds added up (`out_type`: type -> [bytes, packets]).
static func type_kbps(out_type: Dictionary, peer_seconds: Dictionary) -> Dictionary:
	var peer_s := 0.0
	for p in peer_seconds:
		peer_s += float(peer_seconds[p])
	var out := {}
	for t in out_type:
		out[t] = float((out_type[t] as Array)[0]) * 8.0 / 1000.0 / peer_s if peer_s > 0.0 else 0.0
	return out

static func _type_bytes(out_type: Dictionary) -> Dictionary:
	var out := {}
	for k in out_type:
		out[k] = int((out_type[k] as Array)[0])
	return out

## Which budgets a row meets: `{ budget: bool }` for every entry of BUDGETS. A relay lag with no
## samples (no watcher, or a crowd out of its sight) is not a failure: there was nothing to lag.
static func budgets_met(row: Dictionary) -> Dictionary:
	return {
		"host_tick_p95_ms": float(row.get("host_tick_p95_ms", INF)) <= float(BUDGETS["host_tick_p95_ms"]),
		"down_kbps_per_peer": float(row.get("down_kbps_per_peer", INF)) <= float(BUDGETS["down_kbps_per_peer"]),
		"watch_frame_p95_ms": float(row.get("watch_frame_p95_ms", INF)) <= float(BUDGETS["watch_frame_p95_ms"]),
		"relay_lag_ms": float(row.get("relay_lag_ms", INF)) <= float(BUDGETS["relay_lag_ms"]),
	}

static func meets_all(row: Dictionary) -> bool:
	var met: Dictionary = row.get("budgets_met", budgets_met(row))
	for k in BUDGETS:
		if not bool(met.get(k, false)):
			return false
	return true

## The hard failures of one run (an empty list is a pass): a missing recorder (its process crashed),
## a host or watcher frame over HARD_FRAME_MS, a bot the host dropped without being asked, and a peer
## record the host still holds after every peer left.
static func hard_failures(host: Dictionary, watch: Dictionary, bots: Dictionary) -> Array:
	var out: Array = []
	if host.is_empty():
		out.append("host: no report (crashed or never finished)")
	if watch.is_empty():
		out.append("watcher: no report (crashed or never finished)")
	if bots.is_empty():
		out.append("bots: no report (crashed or never finished)")
	if float(host.get("frame_gap_max_ms", 0.0)) > HARD_FRAME_MS:
		out.append("host: a frame took %.0f ms" % float(host["frame_gap_max_ms"]))
	if float(watch.get("frame_gap_max_ms", 0.0)) > HARD_FRAME_MS:
		out.append("watcher: a frame took %.0f ms" % float(watch["frame_gap_max_ms"]))
	if int(bots.get("dropped_unexpected", 0)) > 0:
		out.append("bots: %d dropped by the host without a reason" % int(bots["dropped_unexpected"]))
	if int(bots.get("join_failures", 0)) > 0:
		out.append("bots: %d never completed the handshake" % int(bots["join_failures"]))
	var orphans: Dictionary = host.get("orphans", {})
	for k in orphans:
		if int(orphans[k]) > 0:
			out.append("host: %d orphaned %s after every peer left" % [int(orphans[k]), k])
	return out

# ---------------------------------------------------------------------------
# The report: every run -> per series the largest passing size, and the hot spots
# ---------------------------------------------------------------------------

## The largest size in `rows` (one series) that met every budget without a hard failure; 0 when none did.
static func largest_passing(rows: Array) -> int:
	var best := 0
	for row in rows:
		if meets_all(row) and (row.get("hard_failures", []) as Array).is_empty():
			best = maxi(best, int(row.get("size", 0)))
	return best

## Rank the hot spots. Every candidate is projected to `at_size` bots from its measured curve (a
## least-squares line of cost against crowd size; the worst series decides) and scored by the share of
## its budget that projection takes: a tick phase's ms per tick over the tick budget, a message type's
## kbit/s per peer over the bandwidth budget. Highest share first, so a cost that grows with the crowd
## outranks a larger one that stays flat.
##
## `phase_curves`: phase -> Array of series, each an Array of [size, ms_per_tick].
## `message_curves`: message type -> Array of series, each an Array of [size, kbps_per_peer].
static func rank_hot_spots(phase_curves: Dictionary, message_curves: Dictionary, at_size: int) -> Array:
	var out: Array = []
	for phase in phase_curves:
		var p := _project(phase_curves[phase], at_size)
		out.append({
			"kind": "phase", "name": str(phase), "label": str(PHASE_LABELS.get(phase, phase)),
			"growth_per_bot": p.x, "projected": p.y, "unit": "ms/tick",
			"budget_share": p.y / float(BUDGETS["host_tick_p95_ms"]),
		})
	for t in message_curves:
		var m := _project(message_curves[t], at_size)
		out.append({
			"kind": "message", "name": str(t), "label": "%s messages" % str(t),
			"growth_per_bot": m.x, "projected": m.y, "unit": "kbit/s per peer",
			"budget_share": m.y / float(BUDGETS["down_kbps_per_peer"]),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["budget_share"]), float(b["budget_share"])):
			return float(a["budget_share"]) > float(b["budget_share"])
		return str(a["name"]) < str(b["name"]))
	return out

## Vector2(growth per bot, projected cost at `at_size`) of the worst of `curves` (Arrays of [x, y]).
static func _project(curves: Array, at_size: int) -> Vector2:
	var best := Vector2(0.0, -1.0)
	for series in curves:
		if (series as Array).is_empty():
			continue
		var line := fit_line(series)
		var projected := maxf(0.0, line.y + line.x * float(at_size))
		if projected > best.y:
			best = Vector2(line.x, projected)
	return Vector2(best.x, maxf(best.y, 0.0))

## The whole report from every run's row: series keyed "<profile>/<pattern>", each with its rows by
## size, the largest passing size and where the ladder stopped, plus the ranked hot spots and every
## hard failure.
static func build_report(rows: Array, meta: Dictionary = {}) -> Dictionary:
	var series := {}
	for row in rows:
		var key := "%s/%s" % [str(row.get("profile", "")), str(row.get("pattern", ""))]
		if not series.has(key):
			series[key] = []
		series[key].append(row)
	var phase_curves := {}
	var message_curves := {}
	var out_series := {}
	var failures: Array = []
	for key in series:
		var list: Array = series[key]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["size"]) < int(b["size"]))
		var stopped := 0
		for row in list:
			for f in row.get("hard_failures", []):
				failures.append("%s @%d: %s" % [key, int(row["size"]), str(f)])
			if stopped == 0 and float(row.get("host_tick_p95_ms", 0.0)) > LADDER_STOP_TICK_P95_MS:
				stopped = int(row["size"])
		for phase in PHASE_LABELS:
			var curve: Array = []
			for row in list:
				if int(row.get("host_frames", 0)) == 0:
					continue   # the host's report is missing: no point, not a zero
				curve.append([int(row["size"]), float((row.get("phase_ms_per_tick", {}) as Dictionary).get(phase, 0.0))])
			if not phase_curves.has(phase):
				phase_curves[phase] = []
			phase_curves[phase].append(curve)
		var types := {}
		for row in list:
			for t in row.get("kbps_by_type", {}):
				types[t] = true
		for t in types:
			var mcurve: Array = []
			for row in list:
				if int(row.get("host_frames", 0)) == 0:
					continue
				mcurve.append([int(row["size"]), float((row.get("kbps_by_type", {}) as Dictionary).get(t, 0.0))])
			if not message_curves.has(t):
				message_curves[t] = []
			message_curves[t].append(mcurve)
		out_series[key] = {
			"largest_passing": largest_passing(list),
			"ladder_stopped_at": stopped,
			"runs": list,
		}
	var top_size: int = LADDER[LADDER.size() - 1]
	return {
		"phase": 162,
		"meta": meta,
		"budgets": BUDGETS,
		"series": out_series,
		"hot_spots": rank_hot_spots(phase_curves, message_curves, top_size),
		"hard_failures": failures,
		"regressions": baseline_regressions(out_series, int(meta.get("max", top_size))),
	}

## Phase 163 — the series of `series` whose largest passing size is below `BASELINE_LARGEST`. A series the
## run did not include, or a baseline size above the run's ladder ceiling `max_size`, is not judged.
static func baseline_regressions(series: Dictionary, max_size: int = 200) -> Array:
	var out: Array = []
	for key in BASELINE_LARGEST:
		var want := int(BASELINE_LARGEST[key])
		if not series.has(key) or want > max_size:
			continue
		var got := int((series[key] as Dictionary).get("largest_passing", 0))
		if got < want:
			out.append("%s: largest passing size %d is below the baseline's %d" % [key, got, want])
	return out

## A run worth one more try before it counts: it missed a budget with no hard failure, at a size its
## series' baseline says must pass. A shared CI runner's slow seconds land on one 20 s run and miss it
## (tick p95 at 16 bots has ranged 3–18 ms on the same code); a real regression misses the rerun too.
static func needs_retry(row: Dictionary, series_key: String) -> bool:
	if meets_all(row) or not (row.get("hard_failures", []) as Array).is_empty():
		return false
	return int(row.get("size", 0)) <= int(BASELINE_LARGEST.get(series_key, 0))

## `report.md`: one table per series, then the hot spots and the hard failures.
static func report_markdown(report: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("# Crowd stress report (Phase 162)")
	lines.append("")
	var meta: Dictionary = report.get("meta", {})
	if not meta.is_empty():
		lines.append("Run: %s" % ", ".join(PackedStringArray(meta.keys().map(func(k): return "%s=%s" % [k, str(meta[k])]))))
		lines.append("")
	var b: Dictionary = report.get("budgets", BUDGETS)
	lines.append("Budgets: host tick p95 ≤ %s ms, ≤ %s kbit/s down per peer, watcher frame p95 ≤ %s ms, relay lag ≤ %s ms." % [
		b["host_tick_p95_ms"], b["down_kbps_per_peer"], b["watch_frame_p95_ms"], b["relay_lag_ms"]])
	lines.append("")
	lines.append("## Largest passing size")
	lines.append("")
	lines.append("| Series | Largest passing size | Ladder stopped at |")
	lines.append("|---|---|---|")
	var series: Dictionary = report.get("series", {})
	var keys := series.keys()
	keys.sort()
	for key in keys:
		var s: Dictionary = series[key]
		lines.append("| %s | %d | %s |" % [key, int(s["largest_passing"]), str(s["ladder_stopped_at"]) if int(s["ladder_stopped_at"]) > 0 else "—"])
	lines.append("")
	lines.append("## Hot spots")
	lines.append("")
	lines.append("| Rank | Hot spot | Budget share at %d bots | Detail |" % LADDER[LADDER.size() - 1])
	lines.append("|---|---|---|---|")
	var rank := 1
	for h in report.get("hot_spots", []):
		var detail := "%+.4f %s per bot, %.2f %s projected" % [float(h["growth_per_bot"]), str(h["unit"]),
				float(h["projected"]), str(h["unit"])]
		lines.append("| %d | %s | %.0f%% | %s |" % [rank, str(h["label"]), float(h["budget_share"]) * 100.0, detail])
		rank += 1
	lines.append("")
	for key in keys:
		lines.append("## %s" % key)
		lines.append("")
		lines.append("| Bots | Tick p50/p95/p99/max ms | Down kbit/s/peer p95 | Watcher frame p95 ms | Relay lag p95 ms | Avatars seen | Peers per AOI cell | Budgets |")
		lines.append("|---|---|---|---|---|---|---|---|")
		for row in series[key]["runs"]:
			lines.append("| %d | %.2f / %.2f / %.2f / %.1f | %.1f | %.2f | %.0f (%d) | %d | %d | %s |" % [
				int(row["size"]), float(row["host_tick_p50_ms"]), float(row["host_tick_p95_ms"]), float(row["host_tick_p99_ms"]),
				float(row["host_tick_max_ms"]), float(row["down_kbps_per_peer"]), float(row["watch_frame_p95_ms"]),
				float(row["relay_lag_ms"]), int(row["relay_lag_samples"]), int(row["watch_avatars_max"]),
				int(row["aoi_cell_peers_max"]), "pass" if meets_all(row) else "miss"])
		lines.append("")
	lines.append("## Baseline")
	lines.append("")
	var regressions: Array = report.get("regressions", [])
	if regressions.is_empty():
		lines.append("No series fell below the baseline's largest passing size.")
	for r in regressions:
		lines.append("- %s" % str(r))
	lines.append("")
	lines.append("## Hard failures")
	lines.append("")
	var failures: Array = report.get("hard_failures", [])
	if failures.is_empty():
		lines.append("None.")
	for f in failures:
		lines.append("- %s" % str(f))
	lines.append("")
	return "\n".join(lines)
