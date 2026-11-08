## Net harness steps for the late phases (208 onwards), split out of `net_harness.gd` for its line cap. Each
## takes the running harness `h` and uses its role, root, waits and report exactly as a step there does.
extends RefCounted

const WorldPos := preload("res://src/terrain/world_pos.gd")

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
	transport._send_raw = func(to: int, json: String) -> void:
		if counting[0] and to == peer and json.contains(iid):
			counting[1] += 1
		real_send.call(to, json)
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

## Phase 223 — the main menu's join path connects. The client drops its connection, fills the menu's Join form
## with the host's address (`MainMenu.join_choice`), applies the choice the way the menu's start does
## (`MenuWiring.apply_choice`) and runs the shipped client boot (`GameRoot._boot_client`). The client gets its
## world snapshot and then reports its position; the host sees a new peer connect, bind an identity and report
## (so the host does not quit under a client whose snapshot is still crossing a slow link).
const MainMenu := preload("res://src/menu/main_menu.gd")
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
	h._root._networking.disconnect_all()
	await h._await_settle(h.RECONNECT_WAIT_SECS * h._time_scale)
	var snapshots := [0]
	var on_snapshot := func(_data: Dictionary) -> void: snapshots[0] += 1
	GameBus.world_snapshot_received.connect(on_snapshot)
	var choice: Dictionary = MainMenu.join_choice(h._root._host_address, "")
	var applied: bool = bool(choice["ok"]) and h._root._menu_wiring.apply_choice(choice)
	if applied:
		h._root._boot_client()
	var joined: bool = applied and await h._await_until(func():
		return snapshots[0] > 0 and str(h._root._networking.claimed_player_id) != "", h._step_timeout() * 3.0)
	GameBus.world_snapshot_received.disconnect(on_snapshot)
	if joined:
		for i in 3:   # the host's verdict waits on this report
			h._report_position()
			await h._await_settle(1.0 * h._time_scale)
	h._report("menu_join", h.verdict(joined, true), "joined-from-menu" if joined else "applied%d-snapshots%d" % [int(applied), snapshots[0]])
