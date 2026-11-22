extends RefCounted
## Phase 294 — the fabric's `RemoteMotion` table (`GameData.WORLD_SYSTEMS["RemoteMotion"].rules`): send rates,
## playback buffer, extrapolation cap, teleport distance, turn rate and the walk/run speed thresholds. A field the
## fabric does not carry (or carries with the wrong type) keeps its default here, so a stripped GameData still runs.

const DEFAULT_RULES := {
	"players":   { "sendIntervalMs": 100.0, "bufferMs": 150.0, "extrapolateMaxMs": 100.0 },
	"creatures": { "sendIntervalMs": 100.0, "bufferMs": 150.0, "extrapolateMaxMs": 100.0, "farSendIntervalMs": 400.0, "farDistanceM": 96.0 },
	"teleportDistanceM": 30.0,
	"turnRateRadPerSec": 10.0,
	"walkSpeed": 0.2,
	"runSpeed": 3.0,
}

static var _cache: Dictionary = {}
static var _source: Resource = null

## The whole table, defaults filled in. Cached per GameData resource.
static func rules() -> Dictionary:
	var src: Resource = GameData.WORLD_SYSTEMS.get("RemoteMotion", null)
	if src == _source and not _cache.is_empty():
		return _cache
	var out: Dictionary = DEFAULT_RULES.duplicate(true)
	var fab: Variant = src.get("rules") if src != null else null
	if fab is Dictionary:
		for k: String in out:
			var v: Variant = (fab as Dictionary).get(k, null)
			if out[k] is Dictionary and v is Dictionary:
				for f: String in out[k]:
					var fv: Variant = (v as Dictionary).get(f, null)
					if fv is float or fv is int:
						out[k][f] = float(fv)
			elif not out[k] is Dictionary and (v is float or v is int):
				out[k] = float(v)
	_source = src
	_cache = out
	return out

## One group's numbers (`players` or `creatures`) plus the shared ones, as the `RemoteMotion` track takes them.
static func group(name: String) -> Dictionary:
	var r := rules()
	var g: Dictionary = (r.get(name, r["players"]) as Dictionary).duplicate()
	g["teleportDistanceM"] = r["teleportDistanceM"]
	g["turnRateRadPerSec"] = r["turnRateRadPerSec"]
	return g

static func walk_speed() -> float:
	return float(rules()["walkSpeed"])

static func run_speed() -> float:
	return float(rules()["runSpeed"])

## Seconds between two movement reports of the local player.
static func player_send_interval_s() -> float:
	return float(rules()["players"]["sendIntervalMs"]) / 1000.0

## Seconds between two creature delta broadcasts from the host.
static func creature_send_interval_s() -> float:
	return float(rules()["creatures"]["sendIntervalMs"]) / 1000.0
