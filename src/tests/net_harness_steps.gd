## Net harness steps for the late phases (208 onwards), split out of `net_harness.gd` for its line cap. Each
## takes the running harness `h` and uses its role, root, waits and report exactly as a step there does.
extends RefCounted

const WorldPos := preload("res://src/terrain/world_pos.gd")
const TitleRules := preload("res://src/character/title_rules.gd")
const PlayerSlice := preload("res://src/player/player_slice.gd")

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

## A client's own swing reaches the host. The host stands a probe creature beside the peer's reported body; the
## client swings with the player's real input path (`PlayerSlice._try_attack`), which on a client forwards an
## `attack_intent`. The host must resolve a round with the peer's player id as the attacker, and the client must
## see that swing come back as the synced hit. Before the fix, a client resolved its swings on its own copy of
## the creature and the host never heard of them.
const ATTACK_PROBE_ID := "creature_harness_attack_probe"
func client_attack_lands(h: Node) -> void:
	if h._role == "host":
		var peer: int = h._peer_id()
		var pid: String = h._root._networking.get_player_id(peer)
		if pid == "" or not await h._await_until(func(): return h._root._networking.has_last_known_state(peer), h._step_timeout()):
			h._report("client_attack_lands", "fail", "no_peer_position")
			return
		var rounds := { "n": 0 }
		var on_hit := func(attacker: String, _defender: String, _outcome: String, _dmg: float) -> void:
			if attacker == pid:
				rounds["n"] = int(rounds["n"]) + 1
		GameBus.combat_hit_resolved.connect(on_hit)
		# Keep the probe pinned beside wherever the peer reports itself until a swing lands.
		var landed := false
		var deadline: int = Time.get_ticks_msec() + int(h._step_timeout() * 3.0 * 1000.0)
		while Time.get_ticks_msec() < deadline and not landed:
			# Exact `{chunk, local}`: earlier steps leave the peer far from the origin, where metres are float32-coarse.
			var at: Dictionary = h._root._peer_wiring.peer_exact_pos(peer)
			at = { "chunk": at["chunk"], "local": (at["local"] as Vector3) + Vector3(1.5, 0.0, 0.0) }
			if not h._root._creature._instances.has(ATTACK_PROBE_ID):
				h._root._creature.apply_creature_state(ATTACK_PROBE_ID, "ForestBoar", "idle", WorldPos.to_scene(at, Vector2i.ZERO))
			h._root._creature.set_instance_pos(ATTACK_PROBE_ID, at)
			await h._await_settle(0.5)
			landed = int(rounds["n"]) > 0
		GameBus.combat_hit_resolved.disconnect(on_hit)
		# Let the client see the synced swing before the probe goes.
		await h._await_settle(2.0 * h._time_scale)
		h._root._creature.despawn_instance(ATTACK_PROBE_ID)
		h._report("client_attack_lands", h.verdict(landed, true), "host_resolved" if landed else "swing_never_reached_host")
		return
	var own_key := "p:%d" % h._root.multiplayer.get_unique_id()
	var seen := { "hit": false }
	var on_synced := func(attacker_key: String, _defender_key: String, _outcome: String) -> void:
		if attacker_key == own_key:
			seen["hit"] = true
	GameBus.combat_hit_synced.connect(on_synced)
	# The fold step left this client in a folded frame that would replay onto the host's creature positions (see
	# `_step_creature_far_delta`): set it aside for the probe and put it back.
	var folds: Array = h._root._creature._fold_log
	h._root._creature._fold_log = []
	h._report_actual = true
	var swung := { "n": 0 }
	var got: bool = await h._await_until(func() -> bool:
		if bool(seen["hit"]):
			return true
		h._report_position()
		if Time.get_ticks_msec() - int(swung.get("at", 0)) >= 400 and h._root._player._alive:
			swung["at"] = Time.get_ticks_msec()
			swung["n"] = int(swung["n"]) + 1
			h._root._player._try_attack()
		return false, h._step_timeout() * 3.0)
	GameBus.combat_hit_synced.disconnect(on_synced)
	h._root._creature._fold_log = folds
	h._report_actual = false
	h._report_position()
	h._report("client_attack_lands", h.verdict(got, true), "host_resolved" if got else "no_synced_swing-after-%d" % int(swung["n"]))
