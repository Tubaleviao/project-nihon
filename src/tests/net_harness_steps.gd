## Net harness steps for the late phases (208 onwards), split out of `net_harness.gd` for its line cap. Each
## takes the running harness `h` and uses its role, root, waits and report exactly as a step there does.
extends RefCounted

const WorldPos := preload("res://src/terrain/world_pos.gd")
const TitleRules := preload("res://src/character/title_rules.gd")
const PlayerSlice := preload("res://src/player/player_slice.gd")
const RemoteMotionRules := preload("res://src/networking/remote_motion_rules.gd")

## Phase 208 — the host stands a chest of its own clan (the client is not in it) at the client's feet, holding five
## Thornwood. The client uses it and asks to take one: both are refused, the chest still holds five, the
## client's pack gains nothing and it was never sent a view of the chest.
const CHEST_ITEM := "Thornwood"
func chest_take_refused(h: Node) -> void:
	await h._await_settle(1.0 * h._time_scale)
	if h._role == "host":
		var seen: Array = []
		var on_resolved := func(pid: String, action: String, ok: bool, _reason: String) -> void: seen.append([pid, action, ok])
		GameBus.chest_resolved.connect(on_resolved)
		var peer: int = h._peer_id()
		var bound: String = h._live_bound_id()
		var pack_before: int = h._root._registry.get_inventory(bound).get_item_count(CHEST_ITEM)
		var got_pos: bool = await h._await_until(func(): return not h._root._networking.get_last_known_exact(peer).is_empty(), h._step_timeout())
		var at: Variant = h._root._chest_wiring.player_pos(bound) if got_pos else null
		# A clan with members: a memberless clan's chest is abandoned and open to anyone (`ChestSlice._abandoned`).
		var local: String = h._root._registry.local_player_id
		if h._root._clans.clan_of(local) == "":
			h._root._clans.found(local, "Chestkeepers")
		var clan: String = h._root._clans.clan_of(local)
		var id := ""
		if at is Vector3 and clan != "" and h._root._clans.clan_of(bound) != clan:
			h._root._chest_wiring._migrating = true   # a station the host stands up itself, given straight to the clan
			id = h._root._station.place_station("chest", h._root._station.snap_to_grid(at))
			h._root._chest_wiring._migrating = false
			h._root._chests.register_clan_chest(id, "chest", h._root._station.snap_to_grid(at), clan, { CHEST_ITEM: 5 })
		var took: bool = await h._await_until(func():
			return seen.any(func(e: Array) -> bool: return str(e[0]) == bound and str(e[1]) == "take"), h._step_timeout() * 2.0)
		await h._await_settle(0.5)
		var refused: bool = took and not seen.any(func(e: Array) -> bool: return str(e[0]) == bound and bool(e[2]))
		var unchanged: bool = id != "" and h._root._chests.items_of(id) == { CHEST_ITEM: 5 }
		var pack_same: bool = h._root._registry.get_inventory(bound).get_item_count(CHEST_ITEM) == pack_before
		GameBus.chest_resolved.disconnect(on_resolved)
		if id != "":
			h._root._station.remove_station(id)
		var ok: bool = refused and unchanged and pack_same
		h._report("chest_take_refused", h.verdict(ok, true), "take-refused-chest-unchanged" if ok else "placed%d-took%d-refused%d-unchanged%d-pack%d" % [int(id != ""), int(took), int(refused), int(unchanged), int(pack_same)])
		return
	var before: int = h._root._inventory.get_item_count(CHEST_ITEM)
	await h._await_settle(2.0 * h._time_scale)
	GameBus.chest_intent.emit("use", {}, "")
	await h._await_settle(0.6)
	GameBus.chest_intent.emit("take", { "item": CHEST_ITEM, "qty": 1 }, "")
	await h._await_settle(2.5 * h._time_scale)
	var pack_same: bool = h._root._inventory.get_item_count(CHEST_ITEM) == before
	var no_view: bool = h._root._chest_wiring.view().is_empty()
	var ok: bool = pack_same and no_view
	h._report("chest_take_refused", h.verdict(ok, true), "take-refused-chest-unchanged" if ok else "pack%d-view%d" % [int(pack_same), int(no_view)])

## Phase 221 — the Character window's create button follows the host's record. Before `create_character` the client
## skips: the host records "skipped" and the client's sheet offers the button. After it, the host records a character
## and the client's sheet hides it. A listen host's own sheet is judged the same way; a dedicated one has none.
const CreationRules := preload("res://src/character/creation_rules.gd")
func _button_matches(h: Node, state: Dictionary) -> bool:
	var ui: Node = h._root._ui
	if ui == null:
		return false
	ui.refresh_character()
	var want: bool = not CreationRules.is_created(state)
	var button_ok: bool = ui._sheet_create_button == null or ui._sheet_create_button.visible == want
	return ui._creation_known and ui.creation_button_shown() == want and button_ok

func _ui_state(h: Node) -> String:
	var ui: Node = h._root._ui
	if ui == null:
		return "no_ui"
	return "known%d-shown%d-button%s-ui_%s-own_%s" % [int(ui._creation_known), int(ui.creation_button_shown()),
		"none" if ui._sheet_create_button == null else str(int(ui._sheet_create_button.visible)),
		str(ui._creation_state.get("state", "")), str(h._root._creation_wiring.own_state().get("state", ""))]

func creation_skip_button(h: Node) -> void:
	const DETAIL := "skipped-button-offered"
	if h._role == "host":
		var bound: String = h._live_bound_id()
		var skipped: bool = await h._await_until(func():
			return str(h._root._registry.creation_of(bound).get("state", "")) == CreationRules.STATE_SKIPPED, h._step_timeout())
		# A dedicated host has no sheet of its own: only its record of the client is judged there.
		var own_ok: bool = h._root._is_server or await h._await_until(func(): return _button_matches(h, h._root._creation_wiring.own_state()), h._step_timeout())
		var ok: bool = skipped and own_ok
		h._report("creation_skip_button", h.verdict(ok, true), DETAIL if ok else "skipped%d-own%d-%s" % [int(skipped), int(own_ok), _ui_state(h)])
		return
	h._creations_seen.clear()
	GameBus.character_creation_intent.emit("skip", {}, "")
	var answered: bool = await h._await_until(func(): return not h._creations_seen.is_empty(), h._step_timeout())
	var skipped: bool = answered and str(h._creations_seen[0][1]) == ""
	var state: Dictionary = h._root._creation_wiring.own_state()
	var button_ok: bool = str(state.get("state", "")) == CreationRules.STATE_SKIPPED and _button_matches(h, state)
	await h._await_settle(1.0)   # past the host's per-player creation rate limit, before `create_character`
	var ok: bool = skipped and button_ok
	h._report("creation_skip_button", h.verdict(ok, true), DETAIL if ok else "skipped%d-button%d-%s" % [int(skipped), int(button_ok), str(h._creations_seen)])

func creation_button_synced(h: Node) -> void:
	const DETAIL := "created-button-hidden"
	var created := func() -> bool:
		var state: Dictionary = h._root._creation_wiring.own_state()
		return CreationRules.is_created(state) and (h._root._is_server or _button_matches(h, state))
	var ok: bool = await h._await_until(created, h._step_timeout())
	if h._role == "host":
		var peer_created: bool = CreationRules.is_created(h._root._registry.creation_of(h._live_bound_id()))
		h._report("creation_button_synced", h.verdict(ok and peer_created, true), DETAIL if ok and peer_created else "own%d-peer%d-%s" % [int(ok), int(peer_created), _ui_state(h)])
		return
	h._report("creation_button_synced", h.verdict(ok, true), DETAIL if ok else "button_shown-%s" % str(h._root._creation_wiring.own_state().get("state", "")))

## Phase 209 — the host hands the client's player a book about a technology neither of them knows. The client
## reads it: the client's player learns it (host record and client mirror), and the host's own player does not.
const BOOK_ITEM := "BookTechBasicSmithing"
const BOOK_TECH := "TechBasicSmithing"
func book_teaches_client(h: Node) -> void:
	await h._await_settle(1.0 * h._time_scale)
	if h._role == "host":
		var bound: String = h._live_bound_id()
		var local: String = h._root._registry.local_player_id
		var host_before: bool = h._root._technology.is_unlocked(BOOK_TECH, local)
		var fresh: bool = bound != "" and not h._root._technology.is_unlocked(BOOK_TECH, bound)
		if fresh:
			h._root._registry.get_inventory(bound).add_item(BOOK_ITEM, 1)
			h._root._chest_wiring._push_inventory(bound)
		var learnt: bool = fresh and await h._await_until(func(): return h._root._technology.is_unlocked(BOOK_TECH, bound), h._step_timeout() * 2.0)
		var kept: bool = bound != "" and h._root._registry.get_inventory(bound).get_item_count(BOOK_ITEM) == 1
		var host_same: bool = h._root._technology.is_unlocked(BOOK_TECH, local) == host_before and not host_before
		var ok: bool = learnt and kept and host_same
		h._report("book_teaches_client", h.verdict(ok, true), "client-learnt-host-unchanged" if ok else "fresh%d-learnt%d-kept%d-host%d" % [int(fresh), int(learnt), int(kept), int(host_same)])
		return
	var got: bool = await h._await_until(func(): return h._root._inventory.get_item_count(BOOK_ITEM) >= 1, h._step_timeout() * 2.0)
	if got:
		GameBus.writing_intent.emit("read", BOOK_ITEM, "")
	var learnt: bool = got and await h._await_until(func(): return h._root._technology.is_unlocked(BOOK_TECH), h._step_timeout() * 2.0)
	var kept: bool = h._root._inventory.get_item_count(BOOK_ITEM) >= 1
	var ok: bool = learnt and kept
	h._report("book_teaches_client", h.verdict(ok, true), "client-learnt-host-unchanged" if ok else "got%d-learnt%d-kept%d" % [int(got), int(learnt), int(kept)])

## Phase 216 — the host gives the client's player a tamed wolf beside them. The client asks to mount: the host
## records the rider, the client is told and sees the broadcast; the client asks to get off and the host records it.
## The wolf is a fixed instance id both sides know, so the client can name it; the host keeps it beside the client.
const MOUNT_CREATURE := "GraywolfPack"
const MOUNT_CHUNK := Vector2i(0, 0)
const MOUNT_INDEX := 99
func mount_dismount(h: Node) -> void:
	var iid: String = h._root._creature._instance_id(MOUNT_CHUNK, MOUNT_CREATURE, MOUNT_INDEX)
	await h._await_settle(1.0 * h._time_scale)
	if h._role == "host":
		var peer: int = h._peer_id()
		var bound: String = h._live_bound_id()
		var made: String = h._root._creature._spawn(MOUNT_CREATURE, MOUNT_CHUNK, MOUNT_INDEX)
		var tamed: bool = made == iid and bound != "" and h._root._creature.mark_tamed(iid, bound)
		var slice: Node = h._root._mount_wiring.slice
		var mounted := false
		var deadline := Time.get_ticks_msec() + int(h._step_timeout() * 2.0 * 1000.0)
		while tamed and not mounted and Time.get_ticks_msec() < deadline:
			var at: Variant = h._root._networking.get_last_known_state(peer) if h._root._networking.has_last_known_state(peer) else null
			if at is Vector3:
				h._root._creature.set_instance_position(iid, at)   # keep the wolf at its tamer's feet
			mounted = slice.mounted_instance(bound) == iid
			await h._await_settle(0.2)
		var off: bool = mounted and await h._await_until(func(): return not slice.is_mounted(bound), h._step_timeout() * 2.0)
		var ok: bool = tamed and mounted and off
		h._report("mount_dismount", h.verdict(ok, true), "mounted-then-dismounted" if ok else "tamed%d-mounted%d-off%d" % [int(tamed), int(mounted), int(off)])
		return
	var told := { "mount": false, "off": false, "seen": false, "last": "" }
	var on_resolved := func(_pid: String, action: String, ok: bool, reason: String) -> void:
		told["last"] = reason
		if ok:
			told["mount" if action == "mount" else "off"] = true
	var on_changed := func(_player: String, instance: String) -> void:
		if instance == iid:
			told["seen"] = true
	GameBus.mount_resolved.connect(on_resolved)
	GameBus.mount_changed.connect(on_changed)
	var deadline := Time.get_ticks_msec() + int(h._step_timeout() * 2.0 * 1000.0)
	while not told["mount"] and Time.get_ticks_msec() < deadline:
		GameBus.mount_intent.emit(iid, "")   # refused until the host has stood the wolf beside us: try again
		await h._await_settle(1.0)
	var seen: bool = told["mount"] and await h._await_until(func(): return told["seen"], h._step_timeout())
	deadline = Time.get_ticks_msec() + int(h._step_timeout() * 2.0 * 1000.0)
	while told["mount"] and not told["off"] and Time.get_ticks_msec() < deadline:
		GameBus.dismount_intent.emit("")
		await h._await_settle(1.0)
	GameBus.mount_resolved.disconnect(on_resolved)
	GameBus.mount_changed.disconnect(on_changed)
	var ok: bool = told["mount"] and seen and told["off"]
	h._report("mount_dismount", h.verdict(ok, true), "mounted-then-dismounted" if ok else "mount%d-seen%d-off%d-last-%s" % [int(told["mount"]), int(seen), int(told["off"]), str(told["last"]).replace(" ", "_")])

## Phase 195 — host half of `creature_far_delta`: how many of `points` went out to `peer` as exactly one packet naming
## `iid`, counted below the AOI path. A packet is sent at once (a spy on the raw sender) or, under a link emulator
## (`wan_bad`), queued in `_pending` and sent by `_drain_emulator` later, so both are counted.
func far_delta_sent(h: Node, peer_id: int, iid: String, points: Array) -> int:
	var net = h._root._networking
	var peer := int(peer_id)
	var transport = net._ensure_transport()
	var real_send: Callable = transport._send_raw
	var counting := [false, 0]
	transport._send_raw = func(to: int, bytes: PackedByteArray) -> void:
		if counting[0] and to == peer and bytes.get_string_from_utf8().contains(iid):
			counting[1] += 1
		real_send.call(to, bytes)
	var sent := 0
	for p in points:
		var queued_before := _queued_for(net, peer, iid)
		counting[0] = true
		counting[1] = 0
		net._peer_spatial.update(peer, WorldPos.to_scene(p, Vector2i.ZERO))
		GameBus.creature_state_changed.emit(iid, "ForestBoar", "idle", p)
		net._peer_spatial.update(peer, net.get_aoi_center(peer))
		counting[0] = false
		if int(counting[1]) + _queued_for(net, peer, iid) - queued_before == 1:
			sent += 1
		await h._await_settle(0.5)
	transport._send_raw = real_send
	return sent

func _queued_for(net: Object, peer: int, needle: String) -> int:
	var n := 0
	for e: Dictionary in net._pending:
		if int(e.get("peer_id", -1)) == peer and str(e.get("payload", "")).contains(needle):
			n += 1
	return n

## Phase 297 — LAN discovery finds the harness host: the client sends the status query the Join screen sends, aimed at
## the loopback address it joined (`ServerProbe.discover` with that one target), and must get the host's answer with
## its game port and this build's protocol. The host must have answered it on its status port.
const ServerProbe := preload("res://src/networking/server_probe.gd")
const ServerStatus := preload("res://src/networking/server_status.gd")
const NetAddress := preload("res://src/networking/net_address.gd")
## Phase 297 — join the host the driver named (`--client <addr>`: a host, `host:port`, `[v6]:port` or bare IPv6).
static func join_host(h: Node) -> Error:
	var a := NetAddress.parse(str(h._root._host_address))
	if not bool(a["ok"]):
		return ERR_INVALID_PARAMETER
	return h._root._networking.join(str(a["host"]), int(a["port"]))

func lan_discovery(h: Node) -> void:
	if h._role == "host":
		var answered: bool = await h._await_until(func() -> bool:
			var st: Node = h._root._networking._m3.status_server
			return st != null and int(st.answered) > 0, h._step_timeout() * 2.0)
		h._report("lan_discovery", h.verdict(answered, true), "status-answered" if answered else "no_query_answered")
		return
	var a := NetAddress.parse(str(h._root._host_address))
	var probe := ServerProbe.new()
	var found := {}
	if bool(a["ok"]) and probe.open() == OK:
		var status_port := ServerStatus.default_status_port(int(a["port"]))
		var sent := { "at": -100000 }
		await h._await_until(func() -> bool:
			var now := Time.get_ticks_msec()
			if now - int(sent["at"]) >= 1000:
				sent["at"] = now
				probe.discover(status_port, "lan", [str(a["host"])], now)
			for ans in probe.poll(now):
				var st: Dictionary = ans["status"]
				if int(st["game_port"]) == int(a["port"]) and int(st["protocol"]) == ServerStatus.PROTOCOL_VERSION:
					found["ip"] = str(ans["ip"])   # a lambda's locals are copies: mutate, do not reassign
			return not found.is_empty(), h._step_timeout() * 2.0)
	probe.close()
	h._report("lan_discovery", h.verdict(not found.is_empty(), true),
		"status-answered" if not found.is_empty() else "no_answer_from_%s" % str(a.get("host", "?")))

## Phase 223 — the main menu's join path connects; since Phase 224 (#599) through a real main menu. The harness
## client drops its connection and boots a third process with no role (`--menu-join <host>`): the main menu opens,
## the Join form's choice (`MainMenu.join_choice`) goes through `MenuWiring.start` and `GameRoot._build_and_boot`,
## the world snapshot arrives and that process reports its position, then exits 0. The host sees a new peer
## connect, bind an identity and report (so it does not quit under a client whose snapshot is still crossing).
const MenuWiring := preload("res://src/menu/menu_wiring.gd")
func menu_join(h: Node) -> void:
	await h._await_settle(1.0 * h._time_scale)
	if h._role == "host":
		var fresh: Array = []
		var on_connected := func(id: int) -> void: fresh.append(id)
		h._root.multiplayer.peer_connected.connect(on_connected)
		var bound: bool = await h._await_until(func():
			return fresh.any(func(p: int) -> bool:
				return str(h._root._networking.get_player_id(p)) != "" and h._root._networking.has_last_known_state(p)), h._step_timeout() * 3.0)
		h._root.multiplayer.peer_connected.disconnect(on_connected)
		await h._await_link_drained()
		await h._await_settle(2.0 * h._time_scale)
		h._report("menu_join", h.verdict(bound, true), "joined-from-menu" if bound else "connected%d-bound0" % fresh.size())
		return
	# Phase 224 (#599) — the joining side is a THIRD process booted with no role at all: it opens the real main
	# menu and joins through `MenuWiring.start` (`--menu-join`, see menu_wiring.gd). This process steps aside
	# first, so the host's fresh peer is that one.
	h._root._networking.disconnect_all()
	await h._await_settle(h.RECONNECT_WAIT_SECS * h._time_scale)
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--",
		MenuWiring.MENU_JOIN_ARG, h._root._host_address])
	var pid := OS.create_process(OS.get_executable_path(), args)
	var exited: bool = pid > 0 and await h._await_until(func(): return not OS.is_process_running(pid),
		h._step_timeout() * 3.0 + MenuWiring.MENU_JOIN_SETTLE)
	var code := OS.get_process_exit_code(pid) if exited else -1
	if pid > 0 and not exited:
		OS.kill(pid)
	h._report("menu_join", h.verdict(exited and code == 0, true),
		"joined-from-menu" if exited and code == 0 else "spawned%d-exit%d" % [int(pid > 0), code])

## Phase 261 — a client picks up a loose item and the host (and so every peer) sees it gone. Both sides name the same
## item (placement is a pure function of the seed and the tile); the client (which stands near the rendezvous, within the host's edit reach of it) asks to pick it up.
## The host must see it taken, the client must hold it, and an immediate second pick of it is refused.
func loose_pick_synced(h: Node) -> void:
	var loose: Node = h._root._loose
	var from := Vector2(h.RENDEZVOUS.x, h.RENDEZVOUS.z)
	var items: Array = loose.items_near(from, 40.0)
	if items.is_empty():
		h._report("loose_pick_synced", "fail", "no_item")
		return
	# The nearest one (both peers compute the same items, so they agree on it).
	var it: Dictionary = items[0]
	for c in items:
		if (c["xz"] as Vector2).distance_to(from) < (it["xz"] as Vector2).distance_to(from):
			it = c
	var id: String = str(it["id"])
	if h._role == "host":
		var taken: bool = await h._await_until(func(): return loose.is_taken(id), h._step_timeout() * 3.0)
		h._report("loose_pick_synced", h.verdict(taken, true), id if taken else "never_taken")
		return
	# The host checks a remote pick against the fabric's pick reach from the peer's reported position, and this
	# client reports RENDEZVOUS unless told otherwise: it walks its body from RENDEZVOUS to the item under the
	# host's speed cap (1 m per 0.3 s) and reports where the body really is on each leg.
	var target: Vector2 = it["xz"]
	var start := from
	var legs := maxi(1, ceili(start.distance_to(target)))
	h._report_actual = true
	for i in range(0, legs + 1):
		var p := start.lerp(target, float(i) / float(legs))
		var ground: float = float(loose.height_fn.call(p)) if loose.height_fn.is_valid() else float(h.RENDEZVOUS.y)
		h._root._player.place_at_world_pos(WorldPos.from_world(p.x, ground + 1.0, p.y))
		h._report_position()
		await h._await_settle(0.3)
	h._report_position()
	await h._await_settle(1.0 * h._time_scale)
	var before: int = h._root._inventory.get_item_count(str(it["kind"]))
	GameBus.loose_pick_requested.emit(id, "")
	var gone: bool = await h._await_until(func(): return loose.is_taken(id) and h._root._inventory.get_item_count(str(it["kind"])) > before, h._step_timeout() * 3.0)
	# Walk back to RENDEZVOUS the same way, so the reports that follow are not a jump the speed cap pulls back.
	for i in range(legs, -1, -1):
		var p := start.lerp(target, float(i) / float(legs))
		var ground: float = float(loose.height_fn.call(p)) if loose.height_fn.is_valid() else float(h.RENDEZVOUS.y)
		h._root._player.place_at_world_pos(WorldPos.from_world(p.x, ground + 1.0, p.y))
		h._report_position()
		await h._await_settle(0.3)
	h._report_actual = false
	h._report_position()
	h._report("loose_pick_synced", h.verdict(gone, true), id if gone else "never_taken")

## Phase 268 — a station is crafted, selected in the hotbar and placed over the socket. The host grants the client
## what the carpentry bench is made of; the client crafts it, selects it in the hotbar and clicks: the request
## reaches the host, which places the bench (owned by the client, the item consumed) and the client's own station
## list gains it. Then the client asks again with no bench left: the host refuses and stands nothing up.
func station_from_hotbar(h: Node) -> void:
	await h._await_settle(1.0 * h._time_scale)
	if h._role == "host":
		var bound: String = h._live_bound_id()
		var pack: Node = h._root._registry.get_inventory(bound) if bound != "" else null
		if pack == null:
			h._report("station_from_hotbar", "fail", "no_owner")
			return
		var seen: Array = []
		var on_resolved := func(pid: String, action: String, ok: bool, reason: String) -> void: seen.append([pid, action, ok, reason])
		GameBus.station_resolved.connect(on_resolved)
		pack.add_item("Branch", 4)
		pack.add_item("LooseStone", 2)
		h._root._technology.note_obtained(bound, "Branch")
		h._root._technology.note_obtained(bound, "LooseStone")
		GameBus.inventory_synced.emit(bound, pack.get_contents(), pack.get_durability_data())
		var owned := func() -> bool:
			return h._root._station.get_all_stations().any(func(st: Dictionary) -> bool: return str(st.get("owner", "")) == bound)
		var placed: bool = await h._await_until(owned, h._step_timeout() * 2.0)
		var refused: bool = await h._await_until(func() -> bool:
			return seen.any(func(e: Array) -> bool: return str(e[0]) == bound and str(e[1]) == "place" and not bool(e[2]) and str(e[3]) == "no_item"), h._step_timeout() * 2.0)
		var count_ok: bool = h._root._station.get_all_stations().filter(func(st: Dictionary) -> bool: return str(st.get("owner", "")) == bound).size() == 1
		var consumed: bool = int(pack.get_item_count("CarpentryBench")) == 0
		GameBus.station_resolved.disconnect(on_resolved)
		for st: Dictionary in h._root._station.get_all_stations():
			if str(st.get("owner", "")) == bound:
				h._root._station.remove_station(str(st["id"]))
		var ok: bool = placed and refused and count_ok and consumed
		h._report("station_from_hotbar", h.verdict(ok, true), "placed-from-hotbar-refused-without-item" if ok
			else "placed%d-refused%d-one%d-consumed%d" % [int(placed), int(refused), int(count_ok), int(consumed)])
		return
	var inv: Node = h._root._inventory
	if not await h._await_until(func() -> bool: return inv.get_item_count("Branch") >= 4 and inv.get_item_count("LooseStone") >= 2, h._step_timeout()):
		h._report("station_from_hotbar", "fail", "no_inputs")
		return
	var tries := 0
	while inv.get_item_count("CarpentryBench") < 1 and tries < 5:
		GameBus.craft_requested.emit("RecipeCarpentryBench")
		tries += 1
		await h._await_until(func() -> bool: return inv.get_item_count("CarpentryBench") >= 1, 2.0)
	if inv.get_item_count("CarpentryBench") < 1:
		h._report("station_from_hotbar", "fail", "craft_failed")
		return
	var before: int = h._root._station.get_all_stations().size()
	GameBus.hotbar_station_selected.emit("CarpentryBench")
	var player: Node = h._root._player
	var body: Vector3 = player.get_position()
	var sent: bool = player._station_placer.request(inv, body + Vector3(2.0, -0.9, 0.0), body)
	var seen_here: bool = await h._await_until(func() -> bool: return h._root._station.get_all_stations().size() > before, h._step_timeout() * 2.0)
	var gone: bool = await h._await_until(func() -> bool: return inv.get_item_count("CarpentryBench") == 0, h._step_timeout())
	# Again with no bench in the pack: the placer is no longer armed, so ask the host directly as a modified
	# client would; the host must refuse it.
	GameBus.station_intent.emit("place", { "item": "CarpentryBench", "ox": -2.0, "oy": -0.9, "oz": 0.0, "rot": 0 }, "")
	await h._await_settle(1.5 * h._time_scale)
	var one_more: bool = h._root._station.get_all_stations().size() <= before + 1
	GameBus.hotbar_station_selected.emit("")
	var ok: bool = sent and seen_here and gone and one_more
	h._report("station_from_hotbar", h.verdict(ok, true), "placed-from-hotbar-refused-without-item" if ok
		else "sent%d-seen%d-consumed%d-one%d" % [int(sent), int(seen_here), int(gone), int(one_more)])

## Phase 269 — crafting at the station. The host gives the client's player four Thornwood and the carpentry
## technology, waits for the client to report where its body really stands, and stands a carpentry bench 1.5 m
## from it. The client uses the bench (the interact input's own rule), its window lists the planks, and Craft
## makes three planks. The host then moves the bench 40 m away: the client's window closes, and the same request
## sent anyway is refused by the host (`station_required`), the client's pack unchanged.
## The step tests crafting, not combat: the regenerated world spawns creatures round RENDEZVOUS, and a boar's hits
## knock the client's body about half a metre each (a host teleport) until it dies and respawns at RENDEZVOUS, on the
## waystone `waystone_travel` left there, which the interact rule then prefers to the bench. So for the whole step the
## host keeps creatures off the client the way the playtest bot and the clan probe do (`STATION_CLEAR_M`).
const STATION_RECIPE := "RecipeThornwoodPlank"
const STATION_TYPE := "carpentry bench"
const STATION_TECH := "TechBasicCarpentry"
const STATION_CLEAR_M := 40.0
const CraftCatalog := preload("res://src/crafting/craft_catalog.gd")
func station_craft(h: Node) -> void:
	await h._await_settle(1.0 * h._time_scale)
	const DETAIL := "crafted-at-station-refused-away"
	if h._role == "host":
		var bound: String = h._live_bound_id()
		var pack: Node = h._root._registry.get_inventory(bound) if bound != "" else null
		if pack == null:
			h._report("station_craft", "fail", "no_owner")
			return
		var keep_clear := func() -> void: _clear_creatures_near(h, bound)
		keep_clear.call()
		h.get_tree().process_frame.connect(keep_clear)
		var seen: Array = []
		var on_craft := func(r: Dictionary) -> void:
			if str(r.get("player_id", "")) == bound and str(r.get("recipe_id", "")) == STATION_RECIPE:
				seen.append([bool(r.get("success", false)), str(r.get("reason", ""))])
		GameBus.craft_resolved.connect(on_craft)
		pack.add_item("Thornwood", 4)
		h._root._technology.learn("technology", STATION_TECH, bound)
		h._root._chest_wiring._push_inventory(bound)
		var came: bool = await h._await_client_ready("station_craft", bound)
		await h._await_settle(1.0 * h._time_scale)
		var at: Variant = h._root._chest_wiring.player_pos(bound)
		var near := ""
		if came and at is Vector3:
			# A bench left by an earlier step (the hotbar one lands late on a slow runner) nearer the body would win the pick.
			for st: Dictionary in h._root._station.get_all_stations():
				var sp: Variant = st.get("position", null)
				if sp is Vector3 and (sp as Vector3).distance_to(at as Vector3) <= CraftCatalog.INTERACT_REACH + 1.0:
					h._root._station.remove_station(str(st["id"]))
			near = h._root._station.place_station(STATION_TYPE, (at as Vector3) + Vector3(1.5, 0.0, 0.0))
		# The bench must be what the interact input picks where the body stands (no nearer chest, bed or waystone).
		var picked: bool = near != "" and CraftCatalog.interact_station(h._root._station.get_all_stations(), at as Vector3) == near
		var crafted: bool = near != "" and await h._await_until(func() -> bool:
			return seen.any(func(e: Array) -> bool: return bool(e[0])), h._step_timeout() * 3.0)
		var far := ""
		if near != "":
			h._root._station.remove_station(near)
			far = h._root._station.place_station(STATION_TYPE, (at as Vector3) + Vector3(40.0, 0.0, 0.0))
		var refused: bool = crafted and await h._await_until(func() -> bool:
			return seen.any(func(e: Array) -> bool: return not bool(e[0]) and str(e[1]) == "station_required:" + STATION_TYPE), h._step_timeout() * 3.0)
		var planks: int = int(pack.get_item_count("ThornwoodPlank"))
		var wood: int = int(pack.get_item_count("Thornwood"))
		GameBus.craft_resolved.disconnect(on_craft)
		h.get_tree().process_frame.disconnect(keep_clear)
		if far != "":
			h._root._station.remove_station(far)
		var ok: bool = picked and crafted and refused and planks == 3 and wood == 2
		h._report("station_craft", h.verdict(ok, true), DETAIL if ok
			else "came%d-placed%d-picked%d-crafted%d-refused%d-planks%d-wood%d" % [int(came), int(near != ""), int(picked), int(crafted), int(refused), planks, wood])
		return
	var inv: Node = h._root._inventory
	var ui: Node = h._root._ui
	var player: Node = h._root._player
	if not await h._await_until(func() -> bool: return inv.get_item_count("Thornwood") >= 4 and h._root._technology.is_unlocked(STATION_TECH), h._step_timeout() * 2.0):
		h._report("station_craft", "fail", "no_inputs")
		return
	# Report where the body really is, so the host stands the bench beside it and judges the craft from there.
	h._report_actual = true
	h._report_position()
	await h._await_settle(2.0 * h._time_scale)
	var announced := {}
	var found: bool = await h._await_until(func() -> bool:
		h._announce_ready("station_craft", announced)
		return player.interact_station() != "", h._step_timeout() * 4.0)
	var sid: String = player.interact_station() if found else ""
	if sid != "":
		GameBus.station_window_requested.emit(sid)   # what the interact input sends at a crafting station
	var opened: bool = sid != "" and ui.is_window_open("station")
	var card: Dictionary = {}
	if opened:
		for c: Dictionary in ui.station_window.cards():
			if str(c["id"]) == STATION_RECIPE:
				card = c
	var sent := 0
	if not card.is_empty():
		ui.station_window.select(STATION_RECIPE)
		sent = ui.station_window.craft_selected()
	var made: bool = sent == 1 and await h._await_until(func() -> bool: return inv.get_item_count("ThornwoodPlank") >= 3, h._step_timeout() * 3.0)
	# The host moves the bench away: this window closes, and a bench is listed far from the body.
	var closed: bool = made and await h._await_until(func() -> bool:
		var benches: Array = h._root._station.get_all_stations().filter(func(st: Dictionary) -> bool: return str(st.get("type", "")) == STATION_TYPE)
		return not ui.is_window_open("station") and not benches.is_empty() and player.interact_station() == "", h._step_timeout() * 3.0)
	if closed:
		GameBus.craft_requested.emit(STATION_RECIPE)   # asked anyway, as a modified client would
		await h._await_settle(2.0 * h._time_scale)
	var kept: bool = inv.get_item_count("ThornwoodPlank") == 3 and inv.get_item_count("Thornwood") == 2
	h._report_actual = false
	h._report_position()
	var ok: bool = opened and not card.is_empty() and made and closed and kept
	h._report("station_craft", h.verdict(ok, true), DETAIL if ok
		else "found%d-opened%d-listed%d-sent%d-made%d-closed%d-kept%d" % [int(found), int(opened), int(not card.is_empty()), sent, int(made), int(closed), int(kept)])

## Host: despawn every creature within `STATION_CLEAR_M` (on the x/z plane) of where the host judges `player_id`.
static func _clear_creatures_near(h: Node, player_id: String) -> void:
	var at: Variant = h._root._chest_wiring.player_pos(player_id)
	if not at is Vector3:
		return
	for inst: Dictionary in h._root._creature.get_all_instances():
		var c: Vector3 = inst["position"]
		if Vector2(c.x - (at as Vector3).x, c.z - (at as Vector3).z).length() <= STATION_CLEAR_M:
			h._root._creature.despawn_instance(str(inst["instance_id"]))
## Phase 263 — a client's predicted edit. The client digs a block beside its body: the dig is predicted (its voxel
## data changes at once, its chunk remeshed ahead of streaming) and the host confirms it; with the native mesher on
## a delayed link (lan, wan_br) the edited mesh is on screen BEFORE the confirmation arrives. Then it digs one out of
## the host's reach: the host refuses it and the client's column is rolled back to exactly what it was. The host
## sees one dig applied and one refused. The client prints its timings (network round trip, edit to visible).
const NativeBuilderScript := preload("res://src/terrain/native_builder.gd")
const NetProfilesScript := preload("res://src/networking/net_profiles.gd")
const PREDICT_OFFSET_M := 1.5
const PREDICT_FAR_M := 70.0   # past NetworkingSlice.MAX_EDIT_REACH (60 m), inside the client's loaded window
func predicted_edit(h: Node) -> void:
	await h._await_settle(1.0 * h._time_scale)
	var net: Node = h._root._networking
	if h._role == "host":
		var mines := [0]
		var on_changed := func(action: String, _p: Vector3, _n: Vector3, _m: String) -> void:
			if action == "mine":
				mines[0] += 1
		GameBus.block_changed.connect(on_changed)
		var refused0: int = int(net._m2.edit_refusals_sent)
		var seen: bool = await h._await_until(func() -> bool: return mines[0] >= 1 and int(net._m2.edit_refusals_sent) > refused0, h._step_timeout() * 3.0)
		await h._await_settle(1.0 * h._time_scale)
		GameBus.block_changed.disconnect(on_changed)
		var ok: bool = seen and mines[0] == 1 and int(net._m2.edit_refusals_sent) == refused0 + 1
		h._report("predicted_edit", h.verdict(ok, true), "predicted-confirmed-refused-rolled-back" if ok
			else "mines%d-refusals%d" % [mines[0], int(net._m2.edit_refusals_sent) - refused0])
		return
	var voxel: Node = h._root._voxel
	var pred: RefCounted = voxel._predict
	var remesh: RefCounted = h._root._chunk_manager._m1.remesh
	var acks: Array = []
	var on_ack := func(seq: int, accepted: bool, _span: Dictionary) -> void: acks.append([seq, accepted, Time.get_ticks_usec()])
	var rolled: Array = []
	var on_rolled := func(_action: String, reason: String) -> void: rolled.append(reason)
	GameBus.block_edit_acked.connect(on_ack)
	GameBus.block_edit_rolled_back.connect(on_rolled)
	var body: Vector3 = h._root._player.get_position()
	# The kept dig.
	var xz := Vector2(body.x + PREDICT_OFFSET_M, body.z)
	var top: float = voxel.get_voxel_height_at(xz)
	# The player's work on it built the dug chunk ahead (PR #648 review), as `work_start_requested` does.
	voxel._edit.prebuild_edit("mine", Vector3(xz.x, top - 0.05, xz.y), Vector3.UP, "")
	await h._await_settle(0.5 * h._time_scale)
	var n0: int = remesh.samples.size()
	var t0 := Time.get_ticks_usec()
	GameBus.block_mine_requested.emit(Vector3(xz.x, top - 0.05, xz.y), Vector3.UP, "", {})
	var seq: int = int(pred._next_seq)
	var predicted: bool = pred.is_pending(seq) and voxel.get_voxel_height_at(xz) < top
	var confirmed: bool = await h._await_until(func() -> bool: return acks.any(func(a: Array) -> bool: return a[0] == seq and a[1]), h._step_timeout() * 2.0)
	var ack_usec: int = 0
	for a: Array in acks:
		if a[0] == seq:
			ack_usec = int(a[2])
	var own: Array = remesh.samples.slice(n0).filter(func(s: Dictionary) -> bool: return bool(s["primary"]))
	var visible_usec: int = int(own[0]["at_usec"]) if not own.is_empty() else 0
	var visible_first: bool = visible_usec > 0 and ack_usec > 0 and visible_usec <= ack_usec
	# On loopback the answer can beat any build; without the native mesher the build waits for a worker.
	var profile := str(net.net_profile)
	var must_lead: bool = NativeBuilderScript.is_native() and NetProfilesScript.rtt_ms(profile) > 0.0
	var kept: bool = confirmed and not pred.is_pending(seq) and voxel.get_voxel_height_at(xz) < top
	print("[Harness] predicted_edit profile=%s network %.1f ms, visible %.1f ms after the completion (%s frames, %s), %s the confirmation" % [
		profile if profile != "" else "loopback", float(ack_usec - t0) / 1000.0, float(visible_usec - t0) / 1000.0 if visible_usec > 0 else -1.0,
		str(own[0]["frames"]) if not own.is_empty() else "-",
		("main thread, prebuilt" if bool(own[0].get("prebuilt", false)) else "main thread") if not own.is_empty() and bool(own[0]["sync"]) else "worker",
		"before" if visible_first else "after"])
	# The refused dig: out of the host's reach.
	var far := Vector2(body.x + PREDICT_FAR_M, body.z)
	var tile: Vector2i = voxel._resolve_edit_tile("mine", Vector3(far.x, 0.0, far.y), Vector3.UP)["tile"]
	var before := var_to_bytes([voxel._edits.get(voxel._tile_key(tile), null), voxel.get_runs_at_tile(tile)])
	var far_top: float = voxel.get_voxel_height_at(far)
	GameBus.block_mine_requested.emit(Vector3(far.x, far_top - 0.05, far.y), Vector3.UP, "", {})
	var seq2: int = int(pred._next_seq)
	var predicted2: bool = seq2 > seq and pred.is_pending(seq2) and voxel.get_voxel_height_at(far) < far_top
	var back: bool = await h._await_until(func() -> bool: return rolled.has("refused"), h._step_timeout() * 2.0)
	var restored: bool = var_to_bytes([voxel._edits.get(voxel._tile_key(tile), null), voxel.get_runs_at_tile(tile)]) == before
	GameBus.block_edit_acked.disconnect(on_ack)
	GameBus.block_edit_rolled_back.disconnect(on_rolled)
	await h._await_settle(1.0 * h._time_scale)
	var ok: bool = predicted and kept and (visible_first or not must_lead) and predicted2 and back and restored and pred.pending_count() == 0
	h._report("predicted_edit", h.verdict(ok, true), "predicted-confirmed-refused-rolled-back" if ok
		else "predicted%d-kept%d-lead%d-predicted2_%d-back%d-restored%d" % [int(predicted), int(kept), int(visible_first or not must_lead),
			int(predicted2), int(back), int(restored)])

## Phase 273 — titles over the socket. The host unlocks and wears a title on its own player, and the client's
## view of that player's nameplate shows it (in the client's locale); the host unlocks one for the client, which
## chooses it (accepted) and then asks for a locked one (refused, the choice unchanged).
func title_choice(h: Node) -> void:
	const DETAIL := "nameplate-title-chosen-locked-refused"
	var host_id: int = h._root._networking.HOST_PEER_ID
	if h._role == "host":
		var peers: PackedInt32Array = h._root.multiplayer.get_peers()
		var pid: String = h._root._networking.get_player_id(peers[0]) if peers.size() > 0 else ""
		if pid == "":
			h._report("title_choice", "fail", "no_connected_peer")
			return
		var me: String = h._root._registry.local_player_id
		h._root._title_wiring.unlock(me, "MasterMining")
		var wore: bool = h._root._title_wiring.choose("", "MasterMining") == ""
		h._root._title_wiring.unlock(pid, "MasterSmithing")
		# The client draws this player only while the host relays its body, so keep reporting it while the client works.
		var chose := false
		for i in 60:
			var here: Vector3 = h._root._player.get_position()
			GameBus.player_state_sync_requested.emit({ "position": here, "world_pos": WorldPos.from_world(here.x, here.y, here.z),
				"hp": float(PlayerSlice.MAX_HP), "max_hp": float(PlayerSlice.MAX_HP) })
			await h._await_settle(0.25)
			chose = chose or TitleRules.chosen_of(h._root._title_wiring.titles_of(pid)) == "MasterSmithing"
			if i >= 40 and chose:
				break   # past the client's locked request
		var held: bool = TitleRules.chosen_of(h._root._title_wiring.titles_of(pid)) == "MasterSmithing" \
			and not (h._root._title_wiring.titles_of(pid)["unlocked"] as Dictionary).has("MasterArchery")
		var ok := wore and chose and held
		h._report("title_choice", h.verdict(ok, true), DETAIL if ok else ("host_not_worn" if not wore else ("not_chosen" if not chose else "locked_changed_it")))
		return
	var want: String = TitleRules.nameplate(h.HOST_NAME, "MasterMining")
	var have: bool = await h._await_until(func(): return (h._root._title_wiring.own_record()["unlocked"] as Dictionary).has("MasterSmithing"), h._step_timeout())
	GameBus.title_choose_intent.emit("MasterSmithing", "")
	var chosen: bool = have and await h._await_until(func(): return TitleRules.chosen_of(h._root._title_wiring.own_record()) == "MasterSmithing", h._step_timeout())
	h._root._title_wiring.last_refusal = ""
	GameBus.title_choose_intent.emit("MasterArchery", "")
	var refused: bool = await h._await_until(func(): return h._root._title_wiring.last_refusal == "title_locked", h._step_timeout())
	var kept: bool = TitleRules.chosen_of(h._root._title_wiring.own_record()) == "MasterSmithing"
	var seen: bool = await h._await_until(func(): return h._root._character.get_nameplate(h._root._character.get_peer_character(host_id)) == want, h._step_timeout() * 2.0)
	var ok := seen and have and chosen and refused and kept
	h._report("title_choice", h.verdict(ok, true), DETAIL if ok else ("nameplate_not_seen-%s" % h._root._character.get_nameplate(h._root._character.get_peer_character(host_id)).replace("\n", "/").replace(" ", "_") if not seen \
		else ("not_unlocked" if not have else ("not_chosen" if not chosen else ("locked_not_refused" if not refused else "choice_changed")))))

## Phase 281 — the host's own body works, and the client's copy of it plays `chop`, then `build` after the host
## places a block: the host sends a `work_anim` packet to peers in range and the client plays the table's clip.
func work_anim_synced(h: Node) -> void:
	if h._role == "host":
		await h._await_settle(1.0)
		GameBus.work_anim_changed.emit(1, "chop")
		await h._await_settle(1.5)
		GameBus.work_anim_changed.emit(1, "")
		GameBus.block_place_requested.emit(Vector3.ZERO, Vector3.UP, "", "Soil", {})
		await h._await_settle(1.5)
		h._report("work_anim_synced", h.verdict(true, true), "synced")
		return
	var w = h._root._work_anim_wiring
	var chopped: bool = await h._await_until(func(): return "chop" in w.clip_history.get(1, []), h._step_timeout())
	var built: bool = await h._await_until(func(): return w.clip_history.get(1, []).slice(maxi(w.clip_history.get(1, []).rfind("chop"), 0)).has("build"), h._step_timeout())
	h._report("work_anim_synced", h.verdict(chopped and built, true), "synced" if chopped and built else ("no_chop" if not chopped else "no_build"))

## A client's own swing reaches the host. The host stands a probe creature beside the peer's reported body; the
## client swings with the player's real input path (`PlayerSlice._try_attack`), which on a client forwards an
## `attack_intent`. The host must resolve a round with the peer's player id as the attacker, and the client must
## see that swing come back as the synced hit. Before the fix, a client resolved its swings on its own copy of
## the creature and the host never heard of them.
const ATTACK_PROBE_ID := "creature_harness_attack_probe"
## The client's position report interval while it swings (the host's bucket refills 40 packets a second).
const REPORT_INTERVAL_MS := 200
func client_attack_lands(h: Node) -> void:
	if h._role == "host":
		var peer: int = h._peer_id()
		var pid: String = h._root._networking.get_player_id(peer)
		if pid == "" or not await h._await_until(func(): return h._root._networking.has_last_known_state(peer), h._step_timeout()):
			h._report("client_attack_lands", "fail", "no_peer_position")
			return
		# Steps have no barrier: a probe laid before the client sets its fold log aside reaches it replayed into
		# the folded frame, metres off, and a pinned probe sends no later delta to correct it.
		if not await h._await_client_ready("client_attack", pid):
			h._report("client_attack_lands", "fail", "client_never_ready")
			return
		var rounds := { "n": 0 }
		var on_hit := func(attacker: String, _defender: String, _outcome: String, _dmg: float) -> void:
			if attacker == pid:
				rounds["n"] = int(rounds["n"]) + 1
		GameBus.combat_hit_resolved.connect(on_hit)
		# What arrived, for a failure's detail: the swings the peer forwarded and the last target it named.
		var intents := { "n": 0, "last": "none" }
		var on_intent := func(iid: String, who: String) -> void:
			if who == pid:
				intents["n"] = int(intents["n"]) + 1
				intents["last"] = "probe" if iid == ATTACK_PROBE_ID else "other"
		GameBus.attack_intent.connect(on_intent)
		# Keep the probe pinned beside wherever the peer reports itself until a swing lands.
		var landed := false
		var deadline: int = Time.get_ticks_msec() + int(h._step_timeout() * 3.0 * 1000.0)
		while Time.get_ticks_msec() < deadline and not landed:
			# Exact `{chunk, local}`: earlier steps leave the peer far from the origin, where metres are float32-coarse.
			var at: Dictionary = h._root._peer_wiring.peer_exact_pos(peer)
			at = { "chunk": at["chunk"], "local": (at["local"] as Vector3) + Vector3(0.75, 0.0, 0.0) }
			if not h._root._creature._instances.has(ATTACK_PROBE_ID):
				h._root._creature.apply_creature_state(ATTACK_PROBE_ID, "ForestBoar", "idle", WorldPos.to_scene(at, Vector2i.ZERO))
			# Re-pinned every frame, not once per lap: the host's AI reacts to a player this close (a flee runs
			# 4.5 m/s), so a probe pinned twice a second spent most of the lap out of the client's 3 m reach.
			var lap_end: int = Time.get_ticks_msec() + 500
			while Time.get_ticks_msec() < lap_end and int(rounds["n"]) == 0:
				h._root._creature.set_instance_pos(ATTACK_PROBE_ID, at)
				await h.get_tree().process_frame
			landed = int(rounds["n"]) > 0
		GameBus.combat_hit_resolved.disconnect(on_hit)
		GameBus.attack_intent.disconnect(on_intent)
		# The peer's kill notice (its tutorial's only word of a kill): sent the way the host's `creature_died`
		# handler sends it, without killing the probe, so no carcass or loot outlives the step.
		var told: int = h._root._combat_wiring.on_creature_died(ATTACK_PROBE_ID, Vector3.ZERO, pid, Vector3.ZERO) if landed else 0
		# Let the client see the synced swing and the notice before the probe goes.
		await h._await_settle(2.0 * h._time_scale)
		h._root._creature.despawn_instance(ATTACK_PROBE_ID)
		h._report("client_attack_lands", h.verdict(landed and told == peer, true),
			"host_resolved" if landed and told == peer else ("swing_never_reached_host-intents%d-%s" % [int(intents["n"]),
			intents["last"]] if not landed else "kill_not_sent"))
		return
	var own_key := "p:%d" % h._root.multiplayer.get_unique_id()
	var seen := { "hit": false }
	var on_synced := func(attacker_key: String, _defender_key: String, outcome: String) -> void:
		if attacker_key == own_key and outcome != "swing":   # Phase 287: "swing" is the click's announcement; the hit lands later
			seen["hit"] = true
	GameBus.combat_hit_synced.connect(on_synced)
	var on_tut := func(kind: String, params: Dictionary) -> void:
		if kind == "creature_killed" and str(params.get("creature", "")) == "ForestBoar":
			seen["killed"] = true
	GameBus.tutorial_event.connect(on_tut)
	# The fold step left this client in a folded frame that would replay onto the host's creature positions (see
	# `_step_creature_far_delta`): set it aside for the probe and put it back.
	var folds: Array = h._root._creature._fold_log
	h._root._creature._fold_log = []
	h._report_actual = true
	var swung := { "n": 0 }
	var announced := {}
	var got: bool = await h._await_until(func() -> bool:
		if bool(seen["hit"]):
			return true
		h._announce_ready("client_attack", announced)   # the host lays the probe only after this
		# Paced like the other steps' reports: one per poll frame outruns the host's client packet bucket on a
		# slow link (retransmits bunch packets up), and the host then drops this peer's reports and swings alike.
		if Time.get_ticks_msec() - int(swung.get("reported", 0)) >= REPORT_INTERVAL_MS:
			swung["reported"] = Time.get_ticks_msec()
			h._report_position()
		if Time.get_ticks_msec() - int(swung.get("at", 0)) >= 400 and h._root._player._alive:
			swung["at"] = Time.get_ticks_msec()
			swung["n"] = int(swung["n"]) + 1
			var target: String = h._root._creature.nearest_creature(h._root._player.get_world_pos(), PlayerSlice.ATTACK_RANGE)
			swung["target"] = "probe" if target == ATTACK_PROBE_ID else ("none" if target == "" else "other")
			h._root._player._try_attack()
		return false, h._step_timeout() * 3.0)
	GameBus.combat_hit_synced.disconnect(on_synced)
	h._root._creature._fold_log = folds
	h._report_actual = false
	h._report_position()
	# The host's kill notice follows the landed swing; it reaches the tutorial as a species kill.
	var killed := false
	if got:
		killed = await h._await_until(func() -> bool: return bool(seen.get("killed", false)), h._step_timeout())
	GameBus.tutorial_event.disconnect(on_tut)
	h._report("client_attack_lands", h.verdict(got and killed, true), "host_resolved" if got and killed else (
		"no_synced_swing-after-%d-target_%s-probe%d-carrying%d" % [int(swung["n"]), str(swung.get("target", "none")),
		int(h._root._creature._instances.has(ATTACK_PROBE_ID)), int(h._root._player.carrying)] if not got else "kill_notice_missing"))

## Ground loot across the wire. The host lays a pickup beside the peer; the client must see it, take it through
## the player's pickup request (the host checks reach and the bag, the pickup leaves both sides and the client's
## bag gains it), then drop one through the UI's drop request: the host takes it off the peer's bag and lays it
## at the peer's feet, and the client sees that pickup too. Before this, pickups lived only on the host.
const LOOT_ITEM := "Duskfiber"   # no other step moves it
func client_loot_synced(h: Node) -> void:
	var loot: Node = h._root._loot
	if h._role == "host":
		var peer: int = h._peer_id()
		var pid: String = h._root._networking.get_player_id(peer)
		if pid == "" or not await h._await_until(func(): return h._root._networking.has_last_known_state(peer), h._step_timeout()):
			h._report("client_loot_synced", "fail", "no_peer_position")
			return
		var bag: Node = h._root._registry.get_inventory(pid)
		var before: int = bag.get_item_count(LOOT_ITEM)
		var laid: String = loot.spawn_pickup(LOOT_ITEM, 2, h._root._networking.get_last_known_state(peer) + Vector3(2.0, 0.0, 0.0))
		var taken: bool = await h._await_until(func(): return loot.get_pickup(laid).is_empty() and bag.get_item_count(LOOT_ITEM) == before + 2, h._step_timeout() * 3.0)
		var dropped: bool = taken and await h._await_until(func():
			if bag.get_item_count(LOOT_ITEM) != before + 1:
				return false
			for id in loot.ids():
				if str(loot.get_pickup(str(id))["item_id"]) == LOOT_ITEM:
					return true
			return false, h._step_timeout() * 3.0)
		# Let the client see the dropped pickup before the step moves on.
		await h._await_settle(2.0 * h._time_scale)
		for id in loot.ids():
			loot.consume_pickup(str(id))
		h._report("client_loot_synced", h.verdict(taken and dropped, true), "taken-and-dropped" if taken and dropped else ("not_taken" if not taken else "not_dropped"))
		return
	var inv: Node = h._root._inventory
	var seen := { "id": "" }
	var got: bool = await h._await_until(func() -> bool:
		for id in loot.ids():
			if str(loot.get_pickup(str(id))["item_id"]) == LOOT_ITEM:
				seen["id"] = str(id)
				return true
		return false, h._step_timeout() * 3.0)
	if not got:
		h._report("client_loot_synced", "fail", "pickup_never_seen")
		return
	var before: int = inv.get_item_count(LOOT_ITEM)
	GameBus.pickup_requested.emit(str(seen["id"]))
	var taken: bool = await h._await_until(func(): return inv.get_item_count(LOOT_ITEM) == before + 2 and loot.get_pickup(str(seen["id"])).is_empty(), h._step_timeout() * 3.0)
	if not taken:
		h._report("client_loot_synced", "fail", "not_taken-bag%d-view%s" % [inv.get_item_count(LOOT_ITEM) - before, str(not loot.get_pickup(str(seen["id"])).is_empty())])
		return
	GameBus.item_drop_requested.emit(LOOT_ITEM, 1, Vector3.ZERO)
	var dropped: bool = await h._await_until(func() -> bool:
		if inv.get_item_count(LOOT_ITEM) != before + 1:
			return false
		for id in loot.ids():
			if str(id) != str(seen["id"]) and str(loot.get_pickup(str(id))["item_id"]) == LOOT_ITEM:
				return true
		return false, h._step_timeout() * 3.0)
	h._report("client_loot_synced", h.verdict(dropped, true), "taken-and-dropped" if dropped else "drop_not_seen-bag%d" % (inv.get_item_count(LOOT_ITEM) - before))

## Phase 280 — the held item is synced to peers in range: the host selects one hotbar item, then another, and the
## client's view of the host's avatar holds each (the host's pack is checked by the host's own wiring).
const HELD_FIRST := "StonePick"
const HELD_SECOND := "Thornwood"

func held_item_synced(h: Node) -> void:
	if h._role == "host":
		var peers: PackedInt32Array = h._root.multiplayer.get_peers()
		var pid: String = h._root._networking.get_player_id(peers[0]) if peers.size() > 0 else ""
		if pid == "":
			h._report("held_item_synced", "fail", "no_connected_peer")
			return
		if not await h._await_client_ready("held", pid):
			h._report("held_item_synced", "fail", "client_never_arrived")
			return
		h._root._inventory.add_item(HELD_FIRST, 1)
		h._root._inventory.add_item(HELD_SECOND, 1)
		GameBus.held_item_intent.emit(HELD_FIRST, "")
		var first: bool = h._root._held_item_wiring._held.get(h._root._held_item_wiring._local_id(), "") == HELD_FIRST
		await h._await_settle(2.0)
		GameBus.held_item_intent.emit(HELD_SECOND, "")
		var second: bool = h._root._held_item_wiring._held.get(h._root._held_item_wiring._local_id(), "") == HELD_SECOND
		await h._await_settle(6.0)   # the client reads both before this process (the last step) exits
		h._report("held_item_synced", h.verdict(first and second, true), "held" if first and second else "host_refused")
		return
	var announced := {}
	var seen: bool = await h._await_until(func():
		h._announce_ready("held", announced)
		return h._root._held_item_wiring._pending.get(1, "") == HELD_SECOND, h._step_timeout() * 4.0)
	# The avatar of the host may not be drawn yet this early (a headless client); when it is, it holds the item.
	var avatar: String = h._root._character.get_peer_character(1) if seen else ""
	if avatar != "":
		await h._await_until(func(): return h._root._character.held_item_of(avatar) == HELD_SECOND, h._step_timeout())
	var ok: bool = seen and (avatar == "" or h._root._character.held_item_of(avatar) == HELD_SECOND)
	h._report("held_item_synced", h.verdict(ok, true), "seen" if ok else ("never_synced" if not seen else "not_on_avatar"))


## Phase 292 — the market names the seller. The host gives the peer two Thornwood; the client lists one and the
## host lists one of its own. The client's market window text then names the host's listing by character name
## (`HOST_NAME`, created by the `create_character` step), its own listing reads "(you)", and no line prints a
## public handle. The harness host is a dedicated server with no UI, so it checks the market copy it sends a
## client instead: both listings carry their seller's name (`CLIENT_NAME`, `HOST_NAME`), and their rendered lines
## print neither a handle nor a player id.
const MARKET_ITEM := "Thornwood"
const PartyLabel := preload("res://src/ui/party_label.gd")
const I18n := preload("res://src/core/i18n.gd")
func market_names_seller(h: Node) -> void:
	const DETAIL := "names-seen-no-handle"
	var market: Node = h._root._market
	if h._role == "host":
		var pid: String = h._live_bound_id()
		if pid == "":
			h._report("market_names_seller", "fail", "no_connected_peer")
			return
		h._root._registry.get_inventory(pid).add_item(MARKET_ITEM, 2)
		h._root._chest_wiring._push_inventory(pid)   # the client lists from its own copy of the bag
		h._root._inventory.add_item(MARKET_ITEM, 1)
		var theirs: bool = await h._await_until(func() -> bool:
			return market.get_listings().any(func(l: Dictionary) -> bool: return str(l["seller"]) == pid), h._step_timeout() * 3.0)
		var mine: String = market.list_item(PartyLabel.SELF, MARKET_ITEM, 1, 5.0)
		# The harness host is a dedicated server: it builds no market window, so it checks the copy it SENDS.
		var verdict_detail := _sent_market_verdict(h) if theirs and mine != "" else ("client_never_listed" if not theirs else "host_list_refused")
		await h._await_settle(3.0 * h._time_scale)   # the client reads the host's listing before the step moves on
		h._report("market_names_seller", h.verdict(verdict_detail == DETAIL, true), verdict_detail)
		return
	var inv: Node = h._root._inventory
	var stocked: bool = await h._await_until(func(): return inv.get_item_count(MARKET_ITEM) >= 1, h._step_timeout() * 3.0)
	if not stocked:
		h._report("market_names_seller", "fail", "never_stocked")
		return
	market.list_item(PartyLabel.SELF, MARKET_ITEM, 1, 5.0)
	var both: bool = await h._await_until(func() -> bool:
		var sellers: Array = market.get_listings().map(func(l: Dictionary) -> String: return str(l["seller"]))
		return sellers.has(PartyLabel.SELF) and sellers.any(func(s: String) -> bool: return s.begins_with("p_")), h._step_timeout() * 3.0)
	var detail := _market_text_verdict(h, h.HOST_NAME) if both else "listings_not_synced"
	h._report("market_names_seller", h.verdict(detail == "names-seen-no-handle", true), detail)

## The text of the market window's rows as `UISlice.refresh_market` draws them (rows queued for deletion skipped).
static func market_window_text(ui: Node) -> String:
	ui.refresh_market()
	var lines: Array = []
	for row: Node in (ui._market_box.get_children() if ui._market_box != null else []):
		if row.is_queued_for_deletion():
			continue
		for c: Node in row.get_children():
			if c is Label:
				lines.append((c as Label).text)
	return "\n".join(lines)

## The market window's text on this side (every row as `UISlice.refresh_market` renders it): DETAIL when it names
## `other` and reads "(you)" on this side's own listing, with no public handle anywhere.
func _market_text_verdict(h: Node, other: String) -> String:
	var text := market_window_text(h._root._ui)
	var you := I18n.t("party.you", [""]).strip_edges()
	if RegEx.create_from_string("p_[0-9a-f]{16}").search(text) != null:
		return "handle_shown"
	if not text.contains(other):
		return "other_not_named"
	return "names-seen-no-handle" if text.contains(you) else "own_not_marked"

## Host side: the market blob a client is sent (`NetPart3.redact_blob`), each listing rendered as a client would
## (`PartyLabel.listing_line`): DETAIL when both sellers are named and no handle or player id is printed.
func _sent_market_verdict(h: Node) -> String:
	var sent: Variant = h._root._networking._m3.redact_blob("market", h._root._market.get_market_data())
	if not (sent is Dictionary):
		return "nothing_sent"
	var lines: Array = []
	for id in sent:
		var l: Dictionary = sent[id]
		lines.append(PartyLabel.listing_line({ "id": str(id), "item_id": str(l["item_id"]), "quantity": int(l["quantity"]),
			"price": float(l["price"]), "seller": str(l["seller"]), "seller_name": str(l.get("seller_name", "")) }))
	var text := "\n".join(lines)
	if RegEx.create_from_string("p_[0-9a-f]{16}|player_[0-9]").search(text) != null:
		return "handle_shown"
	if not text.contains(h.CLIENT_NAME) or not text.contains(h.HOST_NAME):
		return "other_not_named"
	return "names-seen-no-handle"

## Phase 293 — after `create_character` both players have a created look. The client drops its copy of the host
## (avatar and look) and the host forgets having sent it its body, so the host's next state is a first meeting: the host must
## push its look in that flush, and the client builds the host as a player body (the feminine body rig the host's
## look picks, the host's hair) without asking for the look. The host also holds the client's chosen look. The
## harness has one client, so "each sees the other" is the client drawing the host and the host knowing the client.
func remote_player_body(h: Node) -> void:
	const STEP := "remote_player_body"
	if h._role == "host":
		var peers: PackedInt32Array = h._root.multiplayer.get_peers()
		var pid: String = h._root._networking.get_player_id(peers[0]) if peers.size() > 0 else ""
		if pid == "":
			h._report(STEP, "fail", "no_connected_peer")
			return
		var ready: bool = await h._await_client_ready("body", pid)
		var pushed_before: int = h._root._networking._m1.looks_pushed
		h._root._networking._m1._host_seen.erase(peers[0])   # the client meets this host's body anew
		# Relay the host's body (a dedicated host's own body does not broadcast on its own).
		for i in 16:
			var here: Vector3 = h._root._player.get_position()
			GameBus.player_state_sync_requested.emit({ "position": here, "world_pos": WorldPos.from_world(here.x, here.y, here.z),
				"hp": float(PlayerSlice.MAX_HP), "max_hp": float(PlayerSlice.MAX_HP) })
			await h._await_settle(0.25)
		var theirs: Dictionary = h._root._registry.look_of(pid)
		var knows: bool = str(theirs.get("hair", "")) == "hair_m_spiky" and str(theirs.get("gender", "")) == "masculine"
		var pushed: bool = h._root._networking._m1.looks_pushed > pushed_before
		var ok := ready and knows and pushed
		h._report(STEP, h.verdict(ok, true), "player_rig_in_look" if ok else ("client_never_arrived" if not ready else ("client_look_unknown" if not knows else "no_look_pushed")))
		return
	var host_id: int = h._root._networking.HOST_PEER_ID
	h._root._peer_wiring._remove_remote_avatar(host_id)
	h._root._character._peer_looks.erase(host_id)   # the look only: the worn set stays as the host sent it
	var asked_before: int = h._root._peer_wiring.look_requests
	var announced := {}
	var dressed := func() -> bool:
		h._announce_ready("body", announced)
		var iid: String = h._root._character.get_peer_character(host_id)
		if iid == "" or not h._root._character._instances.has(iid):
			return false
		var inst: Dictionary = h._root._character._instances[iid]
		return inst.get("rig_node", null) != null and str(inst.get("rig_key", "")) == "models/characters/bodies/chibi_body_f.glb.raw" \
			and str(h._root._character.get_appearance(iid).get("hair", "")) == str(h.HOST_LOOK["hair"])
	var ok: bool = await h._await_until(dressed, h._step_timeout() * 4.0)
	var asked: int = h._root._peer_wiring.look_requests - asked_before
	var iid: String = h._root._character.get_peer_character(host_id)
	h._report(STEP, h.verdict(ok and asked == 0, true), "player_rig_in_look" if ok and asked == 0 else ("asked_for_look-%d" % asked if ok else ("no_avatar" if iid == "" else "body_%s_hair_%s" % [
		str(h._root._character._instances.get(iid, {}).get("rig_key", "none")), str(h._root._character.get_appearance(iid).get("hair", ""))])))

## Phase 294 — "two clients; one walks a straight line, the other's recorded positions of it have no step above the
## per-frame bound". The harness has one client, so the host is the walker: it reports its body walking +X at
## `WALK_MPS` every `RemoteMotion.players.sendIntervalMs` for `WALK_STATES` states, then steps back. The client
## records its avatar of the host every rendered frame and checks no frame moved it more than `MAX_STEP_M` per
## 16 ms of frame time (a slow frame may cover more ground, never faster than that), none moved it back along the
## line, and that it walked the line. The host's own body is broadcast straight to its AOI, so the relay's thinning
## (`RelayBatch`) is covered by the suite's track tests (keepalives, sparse and late states), not here.
const WALK_STATES := 30
const WALK_MPS := 4.5
const WALK_MAX_STEP_M := 0.25
func remote_walk_smooth(h: Node) -> void:
	const STEP := "remote_walk_smooth"
	var interval: float = RemoteMotionRules.player_send_interval_s()
	if h._role == "host":
		var peers: PackedInt32Array = h._root.multiplayer.get_peers()
		var pid: String = h._root._networking.get_player_id(peers[0]) if peers.size() > 0 else ""
		if pid == "":
			h._report(STEP, "fail", "no_connected_peer")
			return
		var ready: bool = await h._await_client_ready("walk", pid)
		var here: Vector3 = h._root._player.get_position()
		for i in WALK_STATES + 1:
			var at := here + Vector3(WALK_MPS * interval * float(i), 0.0, 0.0)
			GameBus.player_state_sync_requested.emit({ "position": at, "world_pos": WorldPos.from_world(at.x, at.y, at.z),
				"hp": float(PlayerSlice.MAX_HP), "max_hp": float(PlayerSlice.MAX_HP) })
			await h._await_settle(interval)
		await h._await_settle(3.0)
		# Back where the body stands, so later steps see the host where it is.
		GameBus.player_state_sync_requested.emit({ "position": here, "world_pos": WorldPos.from_world(here.x, here.y, here.z),
			"hp": float(PlayerSlice.MAX_HP), "max_hp": float(PlayerSlice.MAX_HP) })
		h._report(STEP, h.verdict(ready, true), "walked_smooth" if ready else "client_never_arrived")
		return
	var host_id: int = h._root._networking.HOST_PEER_ID
	var announced := {}
	var rec := { "start": null, "prev": null, "us": 0, "worst": 0.0, "frames": 0, "far": 0.0, "still_us": 0, "back": 0 }
	var walked := func() -> bool:
		h._announce_ready("walk", announced)
		var iid: String = h._root._character.get_peer_character(host_id)
		var at: Variant = h._root._character.get_character_position(iid) if iid != "" else null
		if not (at is Vector3):
			return false
		var now := Time.get_ticks_usec()
		if rec["start"] == null:
			rec["start"] = at
		if rec["prev"] != null:
			var frame_ms := maxf(float(now - int(rec["us"])) / 1000.0, 16.0)
			var step: float = (at as Vector3).distance_to(rec["prev"])
			rec["worst"] = maxf(float(rec["worst"]), step * 16.0 / frame_ms)
			rec["frames"] = int(rec["frames"]) + 1
			# The walk is along +X: a frame back along it is a fault, until the last metre, where the body carried
			# past the final state (at most one send interval) eases back to it once the host stops.
			if (at as Vector3).x < (rec["prev"] as Vector3).x - 0.001 and float(rec["far"]) < WALK_MPS * interval * float(WALK_STATES) - 1.0:
				rec["back"] = int(rec["back"]) + 1
			rec["still_us"] = int(rec["still_us"]) + (now - int(rec["us"])) if step < 0.0001 else 0
		rec["prev"] = at
		rec["us"] = now
		rec["far"] = maxf(float(rec["far"]), (at as Vector3).distance_to(rec["start"]))
		# Done once the avatar walked most of the line and has stood still for half a second.
		return float(rec["far"]) >= WALK_MPS * interval * float(WALK_STATES) * 0.8 and int(rec["still_us"]) >= 500000
	var done: bool = await h._await_until(walked, h._step_timeout() * 4.0)
	var smooth: bool = float(rec["worst"]) <= WALK_MAX_STEP_M and int(rec["back"]) == 0
	h._report(STEP, h.verdict(done and smooth, true), "walked_smooth" if done and smooth else (
		"not_walked_%.1fm" % float(rec["far"]) if not done else "step_%.3fm_per_16ms_back_%d_in_%d_frames" % [float(rec["worst"]), int(rec["back"]), int(rec["frames"])]))

## Phase 226 — several characters per player over the wire. The client leaves and comes back the way a menu join
## does: it asks for its character list before entering (`awaiting_character`), finds its one character, makes
## a second, enters with it (a fresh record on the host: empty pack, no skills, no clan), leaves, and enters with
## the first again, which the host binds to the original id. Both sides report the same token.
func character_roster(h: Node) -> void:
	const TOKEN := "listed-created-entered-reentered"
	if h._role == "host":
		# The client runs this on its own timeline, so the host reads what the visit left behind rather than
		# watching it: the account's second character was entered (stamped), saved fresh, and the first is back.
		var reg = h._root._registry
		# The client is whoever it last joined as (a step before this one rejoins as a fresh player), so the
		# account is found by its shape: two characters, both entered, the newer one offline, the older online.
		var pair := ["", ""]
		var done: bool = await h._await_until(func():
			for account: String in reg.roster.to_data():
				var chars: Array = reg.roster.characters_of(account)
				if chars.size() == 2 and reg.roster.played_at(chars[1]) > 0 and not reg.is_online(chars[1]) and reg.is_online(chars[0]):
					pair[0] = chars[0]
					pair[1] = chars[1]
					return true
			return false, h._step_timeout() * 3.0)
		var fresh := false
		if done:
			var data: Dictionary = reg.get_player_data(pair[1]) if reg.has_player(pair[1]) else h._root._persistence.load_player(pair[1])
			fresh = not data.is_empty() and (data.get("inventory", {}) as Dictionary).is_empty() \
				and (data.get("skills", {}) as Dictionary).is_empty() and (h._root._clans == null or h._root._clans.clan_of(pair[1]) == "")
		h._report("character_roster", h.verdict(done and fresh, true), TOKEN if done and fresh else "done%d-fresh%d" % [int(done), int(fresh)])
		return
	var net = h._root._networking
	var first: String = str(net.own_character_id)
	var lists: Array = []
	var on_list := func(peer: int, roster: Dictionary) -> void:
		if peer == 0:
			lists.append(roster)
	GameBus.character_roster_synced.connect(on_list)
	# Leave, and come back asking for the list first.
	net.disconnect_all()
	await h._await_settle(h.RECONNECT_WAIT_SECS * h._time_scale)
	net.awaiting_character = true
	var listed := false
	if join_host(h) == OK:
		listed = await h._await_until(func(): return not lists.is_empty(), h._step_timeout())
	var one: bool = listed and (lists[-1]["characters"] as Array).size() == 1 and str(lists[-1]["characters"][0]["id"]) == first
	await h._await_settle(0.5)
	net._m3.send_roster_intent("create")
	var made: bool = await h._await_until(func():
		return not lists.is_empty() and str(lists[-1]["result"]["op"]) == "create", h._step_timeout())
	var second: String = str(lists[-1]["result"]["id"]) if made and str(lists[-1]["result"]["reason"]) == "" else ""
	# Enter with the new one.
	h._root._snapshot_pending = true
	h._root._handshake_elapsed = 0.0
	h._root._handshake_retries = 0
	net._m3.choose_character(second)
	var in_second: bool = second != "" and await h._await_until(func():
		return net.own_character_id == second and not h._root._snapshot_pending, h._step_timeout() * 2.0)
	await h._await_settle(1.0 * h._time_scale)
	# Leave again, and enter with the first.
	net.disconnect_all()
	await h._await_settle(h.RECONNECT_WAIT_SECS * h._time_scale)
	net.chosen_character = first
	net.awaiting_character = false
	h._root._snapshot_pending = true
	h._root._handshake_elapsed = 0.0
	h._root._handshake_retries = 0
	var in_first := false
	if join_host(h) == OK:
		in_first = await h._await_until(func():
			return net.own_character_id == first and not h._root._snapshot_pending, h._step_timeout() * 2.0)
	GameBus.character_roster_synced.disconnect(on_list)
	net.chosen_character = ""
	var good: bool = one and second != "" and in_second and in_first
	h._report("character_roster", h.verdict(good, true), TOKEN if good else "listed%d-one%d-made%d-second%d-first%d" % [
		int(listed), int(one), int(second != ""), int(in_second), int(in_first)])
