extends Node
## Phase 298 — a public host's heartbeat: every `RegistryWire.HEARTBEAT_S` seconds (the first at once) it tells each
## registry its game port, status port, world name, region, protocol and player counts, over TCP so its source
## address cannot be spoofed, and over each address family a registry resolves to. A child of the networking slice
## while a `--public` dedicated server or a listen host with "Show in server list" ticked is hosting.

const RegistryClient := preload("res://src/networking/registry_client.gd")
const RegistryWire := preload("res://src/networking/registry_wire.gd")

var registries: Array = []
## () -> Dictionary: {game_port, status_port, world_name, region, protocol, players, max_players}
var info: Callable = Callable()
var interval_ms: int = RegistryWire.HEARTBEAT_S * 1000
var sent: int = 0
var accepted: int = 0
var _client := RegistryClient.new()
var _next_ms: int = 0

func _process(_delta: float) -> void:
	poll()

func _exit_tree() -> void:
	_client.cancel()

func poll(now_ms: int = Time.get_ticks_msec()) -> void:
	if now_ms >= _next_ms and not _client.busy() and info.is_valid():
		_next_ms = now_ms + interval_ms
		sent += _client.send_heartbeats(registries, info.call(), now_ms)
	for r in _client.poll(now_ms):
		var msg: Dictionary = r["message"]
		if bool(r["ok"]) and str(msg.get("type", "")) == "heartbeat_ok":
			accepted += 1
			print("[Registry] heartbeat to %s (%s): %s" % [r["registry"], r["ip"], "listed" if bool(msg.get("listed", false)) else "checking"])
		else:
			var why := str(msg.get("code", r["error"]))
			print("[Registry] heartbeat to %s (%s) failed: %s" % [r["registry"], r["ip"], why])
