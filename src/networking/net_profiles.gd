extends RefCounted
## Phase 135/150 — the named link profiles, with no dependency on the rest of the game so
## `tools/profile_scale.gd` (and through it `tools/net_harness.sh`) can read them in a bare SceneTree.
## Latency/jitter are ms added by each process to its outbound packets, loss a percentage.

const TABLE := {
	"loopback": { "latency_ms": 0.0, "jitter_ms": 0.0, "loss_rate": 0.0, "bandwidth_kbps": 0.0 },
	"lan": { "latency_ms": 2.0, "jitter_ms": 1.0, "loss_rate": 0.0, "bandwidth_kbps": 0.0 },
	"wan_br": { "latency_ms": 60.0, "jitter_ms": 15.0, "loss_rate": 1.0, "bandwidth_kbps": 0.0 },
	"wan_bad": { "latency_ms": 200.0, "jitter_ms": 60.0, "loss_rate": 5.0, "bandwidth_kbps": 256.0 },
}

## The profile's round-trip time in ms (worst case with jitter), 0 for an unknown name.
static func rtt_ms(name: String) -> float:
	if not TABLE.has(name):
		return 0.0
	var p: Dictionary = TABLE[name]
	return 2.0 * (float(p["latency_ms"]) + float(p["jitter_ms"]))

## How much longer than loopback a wait under this profile should be: one plus the round trip over 250 ms.
static func time_scale(name: String) -> float:
	return 1.0 + rtt_ms(name) / 250.0
