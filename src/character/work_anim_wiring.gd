extends "res://src/core/wiring.gd"
## Phase 281 — work you can see. Plays the fabric `WorkClips` clip on the body of whoever is working: a hold loops
## its clip (one strike per cycle, at the clip's impact marker), a single action (a placed block) plays once. The
## host emits `work_anim_changed` for every body and sends it to peers in range; a client plays its own work at
## once from its own hold and everyone else's from the host's packet.

const WorkAnim := preload("res://src/character/work_anim.gd")

## peer -> { kind, clip, length, t, struck, loop }
var _active: Dictionary = {}
## peer -> the clip last played (the playtest bot and the suite read it).
var last_clip: Dictionary = {}
## peer -> the last few clips played, oldest first (the harness reads it: a slow link can land "build" before a
## poll sees "chop").
var clip_history: Dictionary = {}
## peer -> the loop last announced on the host (a stop is only broadcast for a body that has one running; a
## single action ends on its own, so it leaves "" here).
var _announced: Dictionary = {}
## Strikes fired so far, by peer.
var strikes: Dictionary = {}

func _connect_all() -> void:
	connect_bus(GameBus.work_start_requested, _on_start_requested)
	connect_bus(GameBus.work_started, _on_own_work_started)
	connect_bus(GameBus.work_cancel_requested, _on_own_cancel)
	connect_bus(GameBus.tree_chop_requested, _on_completion_tree)
	connect_bus(GameBus.block_mine_requested, _on_completion_block)
	connect_bus(GameBus.block_place_requested, _on_place)
	connect_bus(GameBus.station_placed_by_me, _on_station_placed_by_me)
	connect_bus(GameBus.work_anim_changed, _on_anim_changed)
	connect_bus(GameBus.harvest_started, _on_harvest_started)
	connect_bus(GameBus.harvest_resolved, _on_harvest_resolved)
	connect_bus(GameBus.peer_disconnected, _on_peer_disconnected)

## A peer that left takes its per-peer state with it (peer ids are not reused, so the maps would only grow).
func _on_peer_disconnected(peer: int) -> void:
	for m: Dictionary in [_active, last_clip, clip_history, _announced, strikes, _since_sent]:
		m.erase(peer)

## A carcass harvest (host only) is a hold of its own: it plays `dissect` on the harvester until it resolves.
func _on_harvest_started(player_id: String, _carcass_id: String, _seconds: float) -> void:
	_announce_player(player_id, "dissect")

func _on_harvest_resolved(player_id: String, _carcass_id: String, _reason: String, _items: Array) -> void:
	_announce_player(player_id, "")

func _announce_player(player_id: String, kind: String) -> void:
	if root._is_client:
		return
	var peer := 1
	if player_id != "" and player_id != "player" and player_id != root._registry.local_player_id:
		peer = root._registry.get_peer_id(player_id)
		if peer <= 0:
			return
	# A refused or cancelled harvest also resolves: only a running dissect is stopped by it.
	if kind == "" and _announced.get(peer, "") != "dissect":
		return
	_announce(peer, kind)

func _local_peer() -> int:
	return root.multiplayer.get_unique_id() if root._is_client and root.is_inside_tree() else 1

func _character_of(peer: int) -> String:
	if peer == _local_peer():
		return str(root._character.get_player_character())
	return str(root._combat_wiring._character_for_key("p:%d" % peer))

## The local player asked to work on a target: remember it, the body turns to face it when the work starts.
var _face_target: Variant = null

func _on_start_requested(kind: String, tree_id: String, position: Vector3, _normal: Vector3, _exact: Dictionary, player_id: String) -> void:
	if player_id != "" and player_id != "player":
		return
	_face_target = null
	if kind == "tree" and root._tree != null and root._tree._trees.has(tree_id):
		_face_target = root._tree._trees[tree_id]["position"]
	elif kind == "block":
		_face_target = position

## The local player's hold was answered: its work kind is the action (dig / mine / chop).
func _on_own_work_started(_key: String, _duration: float, action: String, _material: String) -> void:
	_announce(_local_peer(), action)

func _on_own_cancel(player_id: String) -> void:
	if player_id == "":
		_announce(_local_peer(), "")

## A completed hold ends the loop; a chained next target restarts it with its own `work_started`.
func _on_completion_tree(_tree_id: String, player_id: String) -> void:
	if player_id == "":
		_announce(_local_peer(), "")

func _on_completion_block(_pos: Vector3, _normal: Vector3, player_id: String, _exact: Dictionary) -> void:
	if player_id == "":
		_announce(_local_peer(), "")

func _on_place(_pos: Vector3, _normal: Vector3, player_id: String, _material: String, _exact: Dictionary) -> void:
	if root._is_client:
		if player_id == "" or player_id == "player":
			_play(_local_peer(), "build")
		return
	var peer := 1
	if player_id != "" and player_id != "player" and player_id != root._registry.local_player_id:
		peer = root._registry.get_peer_id(player_id)
		if peer <= 0:
			return
	_announce(peer, "build")

## Placing a station from the hotbar is building too (the local player's).
func _on_station_placed_by_me(_station_id: String, _type: String) -> void:
	_announce(_local_peer(), "build")

## A client plays its own work directly; the host emits for everyone, which animates its copy and tells the peers.
func _announce(peer: int, kind: String) -> void:
	if root._is_client:
		_play(peer, kind)
	else:
		GameBus.work_anim_changed.emit(peer, kind)

func _on_anim_changed(peer: int, kind: String) -> void:
	if root._is_client and peer == _local_peer():
		# Holds are played at once from the local hold; a dissect has no local hold, so the host's packet plays it.
		var own_dissect: bool = kind == "dissect" or (kind == "" and str(_active.get(peer, {}).get("kind", "")) == "dissect")
		if not own_dissect:
			return
	if not root._is_client:
		if kind == "" and _announced.get(peer, "") == "":
			return   # nothing running on that body: no stop to play or broadcast
		_announced[peer] = kind if WorkAnim.is_loop(kind) else ""
		_since_sent[peer] = 0.0
	_play(peer, kind)
	_send(peer, kind)

## Host: tell the peers in range of `peer`'s body that its work clip is `kind` ("" = stopped).
func _send(peer: int, kind: String) -> void:
	if not root._is_client and root._networking != null and root._networking.is_host():
		var at: Variant = _position_of(peer)
		if at != null:
			root._networking._m2.send_work_anim(peer, kind, at)

func _position_of(peer: int) -> Variant:
	if peer == 1:
		return root._player.get_position() if root._player != null else null
	if root._networking.has_last_known_state(peer):
		return root._networking.get_last_known_state(peer)
	return null

func _remember(peer: int, clip: String) -> void:
	var h: Array = clip_history.get(peer, [])
	h.append(clip)
	if h.size() > 8:
		h.pop_front()
	clip_history[peer] = h

## Start (`kind` != "") or stop (`""`) the work clip on `peer`'s body.
func _play(peer: int, kind: String) -> void:
	var iid := _character_of(peer)
	# #714: the same loop announced again (the host's refresh of a long hold) keeps the running clip and only
	# pushes the remote expiry back; restarting would pop the clip to its first frame.
	if kind != "" and WorkAnim.is_loop(kind) and str(_active.get(peer, {}).get("kind", "")) == kind \
			and str(_active[peer].get("iid", "")) == iid:
		_active[peer]["age"] = 0.0
		return
	if kind == "":
		_active.erase(peer)
		if peer == _local_peer():
			_face_target = null
		if iid != "":
			root._character.stop_work(iid)
		return
	if not WorkAnim.has_kind(kind):
		return
	if iid == "":
		last_clip[peer] = WorkAnim.clip_of(kind)
		_remember(peer, str(last_clip[peer]))   # no body drawn here (headless harness): the clip it would play
		return
	var clip: String = root._character.trigger_work(iid, kind)
	last_clip[peer] = clip
	_remember(peer, clip)
	if peer == _local_peer() and _face_target != null and kind != "build":
		root._character.face_toward(iid, _face_target)
		_face_target = null   # one start request turns the body once
	var length := float(root._character.work_clip_length(iid, clip))
	if length <= 0.0:
		length = 0.5
	_active[peer] = { "kind": kind, "length": length, "t": 0.0, "struck": false, "loop": WorkAnim.is_loop(kind), "iid": iid }

## A remote body whose stop packet never arrives (it left range or disconnected) stops after this many seconds.
const REMOTE_LOOP_MAX_SECONDS := 30.0
## #714 — host: a loop still running is announced again this often, so a viewer's copy of a hold longer than
## REMOTE_LOOP_MAX_SECONDS keeps playing (and a viewer that came into range picks it up).
const LOOP_REFRESH_SECONDS := 10.0
## Host: peer -> seconds since its running loop was last sent.
var _since_sent: Dictionary = {}

## Host: re-send every running loop that has not been sent for LOOP_REFRESH_SECONDS.
func _refresh_loops(delta: float) -> void:
	if root._is_client:
		return
	for peer in _announced.keys():
		var kind := str(_announced[peer])
		if kind == "":
			_since_sent.erase(peer)
			continue
		if not _hold_alive(peer, kind):
			# The host's work session is gone without a stop reaching here (death, abandoned hold): end the clip
			# for everyone instead of refreshing it forever.
			_announced[peer] = ""
			_since_sent.erase(peer)
			_play(peer, "")
			_send(peer, "")
			continue
		if _active.has(peer):
			_active[peer]["age"] = 0.0   # the host knows the hold still runs: its own copy does not expire
		var t := float(_since_sent.get(peer, 0.0)) + delta
		if t >= LOOP_REFRESH_SECONDS:
			t = 0.0
			_send(peer, kind)
		_since_sent[peer] = t

## Host: does a running `kind` loop of `peer` still have a live work session? A tree/block hold lives in the
## WorkHost session; other loops (a dissect) and a host without an enforcing WorkHost have no session to check.
func _hold_alive(peer: int, kind: String) -> bool:
	if kind == "dissect" or peer == 1 or root._networking == null or not root._networking.has_meta("work_host"):
		return true
	var host: Variant = root._networking.get_meta("work_host")
	if host == null or not bool(host.enforce):
		return true
	return bool(host.sessions.has_session(str(root._networking.get_player_id(peer))))

func tick(delta: float) -> void:
	_refresh_loops(delta)
	for peer in _active.keys():
		var a: Dictionary = _active[peer]
		a["t"] += delta
		a["age"] = float(a.get("age", 0.0)) + delta
		if peer != _local_peer() and a["age"] > REMOTE_LOOP_MAX_SECONDS:
			_play(peer, "")
			continue
		if not a["struck"] and a["t"] >= WorkAnim.impact_time(a["kind"], a["length"]):
			a["struck"] = true
			strikes[peer] = int(strikes.get(peer, 0)) + 1
			GameBus.work_strike.emit(peer, a["kind"])
		if a["t"] >= a["length"]:
			if a["loop"]:
				a["t"] = 0.0
				a["struck"] = false
				root._character.trigger_work(a["iid"], a["kind"])
			else:
				_active.erase(peer)

func is_working(peer: int) -> bool:
	return _active.has(peer)
