extends "res://src/tests/test_support.gd"
## Phase 292 — the market names the seller: the host sends each player-showing blob with the players' character
## names beside their handles, and every UI string that formats a player field prints the name, never a handle.

const PartyLabel := preload("res://src/ui/party_label.gd")
const ClanPanel := preload("res://src/ui/clan_panel.gd")
const NetHarnessSteps := preload("res://src/tests/net_harness_steps.gd")

const ALICE := { "name": "Alice", "gender": "feminine", "hair": "hair_f_bob", "hairColor": 129 }
const HOSTA := { "name": "Hosta", "gender": "masculine", "hair": "hair_m_spiky", "hairColor": 41 }
const FAR_FUTURE := 1.0e12

func register() -> void:
	_run_test("party names: a listing reaches a client with the seller's name and no player id", _test_listing_named_on_the_wire)
	_run_test("party names: the host's own listing crosses as its handle and name, not as the client's own literal", _test_host_listing_not_self)
	_run_test("party names: a client's market row shows the name, (you) on its own, unknown without one", _test_client_row_labels)
	_run_test("party names: a renamed or offline seller still has a name after a host restart", _test_name_after_restart)
	_run_test("party names: proposals and trades carry names too, with no player id", _test_governance_and_trade_named)
	_run_test("party names: every UI string that formats a player field prints no handle", _test_player_fields_print_no_handle)
	_run_test("party names: no UI file formats a player-field string except through PartyLabel", _test_player_field_audit)
	_run_test("party names: the host's own UI names a remote seller from the registry", _test_host_ui_names_remote_seller)
	_run_test("party names: an old-shaped host id never crosses the wire", _test_legacy_local_id_never_sent)

# --- fixtures ---------------------------------------------------------------------------------------------

## A host registry with a local player (Hosta) and one remote player (Alice, peer 5), both created.
func _registry() -> PlayerRegistry:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player(reg.mint_player_id())
	assert_eq(reg.create_character(reg.local_player_id, HOSTA, 1000), "", "the host creates Hosta")
	var alice := str(reg.resolve_identity(5))
	assert_eq(reg.create_character(alice, ALICE, 1000), "", "the peer creates Alice")
	return reg

func _alice(reg: PlayerRegistry) -> String:
	return reg.get_player_id(5)

func _host_net(reg: PlayerRegistry) -> Array:
	var n := NetworkingSlice.new()
	add_child(n)
	n.player_registry = reg
	n._role = NetworkingSlice.Role.HOST
	var wire := MemoryTransport.new([5])
	n.set_transport(wire)
	return [n, wire]

func _listing(seller: String) -> Dictionary:
	return { "seller": seller, "item_id": "Thornwood", "quantity": 1, "price": 5.0, "listed_at": 0.0, "expires_at": FAR_FUTURE, "durability": [] }

## The last packet of `type` the host sent.
func _sent(wire: MemoryTransport, type: String) -> Dictionary:
	var hits: Array = wire.outbox.filter(func(o: Dictionary) -> bool: return str(o["payload"].get("type", "")) == type)
	return hits.back()["payload"] if not hits.is_empty() else {}

## A client's market as it applies `data` (what the host sent, adopted with `handle` as its own).
func _client_market(data: Dictionary, handle: String) -> MarketSlice:
	var c := NetworkingSlice.new()
	add_child(c)
	c._role = NetworkingSlice.Role.CLIENT
	c.claimed_handle = handle
	var adopted: Dictionary = c.adopt_own_handle(data)
	c.free()
	var m := MarketSlice.new()
	add_child(m)
	m.is_authoritative = false
	m.apply_market_data(adopted)
	return m

func _with_locale(locale: String, fn: Callable) -> void:
	var old := TranslationServer.get_locale()
	TranslationServer.set_locale(locale)
	fn.call()
	TranslationServer.set_locale(old)

# --- tests ------------------------------------------------------------------------------------------------

func _test_listing_named_on_the_wire() -> void:
	var reg := _registry()
	var alice := _alice(reg)
	var r := _host_net(reg)
	var n: NetworkingSlice = r[0]
	n._on_market_synced({ "listing_0": _listing(alice) })
	var pkt := _sent(r[1], "market_synced")
	var l: Dictionary = (pkt.get("data", {}) as Dictionary).get("listing_0", {})
	assert_eq(str(l.get("seller_name", "")), "Alice", "the listing names its seller")
	assert_eq(str(l.get("seller", "")), reg.public_handle(alice), "beside the handle actions use")
	assert_false(JSON.stringify(pkt).contains(alice), "no player id anywhere in the packet")
	assert_false(JSON.stringify(pkt).contains(reg.local_player_id), "not even the host's")
	# The world snapshot carries the same names (one function for both doors).
	var snap: Dictionary = n.redact_social_state({ "market": { "listing_0": _listing(alice) } })
	assert_eq(str(snap["market"]["listing_0"].get("seller_name", "")), "Alice", "and so does the join snapshot")
	n.free()
	reg.free()

func _test_host_listing_not_self() -> void:
	var reg := _registry()
	var r := _host_net(reg)
	var n: NetworkingSlice = r[0]
	n._on_market_synced({ "listing_0": _listing(PartyLabel.SELF) })
	var l: Dictionary = (_sent(r[1], "market_synced").get("data", {}) as Dictionary).get("listing_0", {})
	assert_eq(str(l.get("seller", "")), reg.public_handle(reg.local_player_id), "the host's own listing crosses as its handle")
	assert_eq(str(l.get("seller_name", "")), "Hosta", "named with the host's character name")
	var bob_view := _client_market({ "listing_0": l }, reg.public_handle(_alice(reg)))
	assert_true(str(bob_view.get_listings()[0]["seller"]) != PartyLabel.SELF, "a client does not read the host's listing as its own")
	bob_view.free()
	n.free()
	reg.free()

func _test_client_row_labels() -> void:
	var reg := _registry()
	var alice := _alice(reg)
	var r := _host_net(reg)
	var n: NetworkingSlice = r[0]
	var gone := reg.mint_player_id()   # a seller with no name left
	n._on_market_synced({ "listing_0": _listing(alice), "listing_1": _listing(gone), "listing_2": _listing(PartyLabel.SELF) })
	var data: Dictionary = _sent(r[1], "market_synced").get("data", {})
	# Bob is some third client: neither listing is his.
	var bob := _client_market(data, "p_" + "0".repeat(16))
	var ui := _new_test_ui()
	ui.market_slice = bob
	var by_id := {}
	for row in ui.market_rows():
		by_id[str(row["id"])] = PartyLabel.listing_line(row, "Bob")
	assert_true(str(by_id["listing_0"]).contains("Alice"), "the row names Alice")
	assert_false(str(by_id["listing_0"]).contains(reg.public_handle(alice)), "never her handle")
	assert_true(str(by_id["listing_2"]).contains("Hosta"), "the host's listing names the host")
	_with_locale("en", func() -> void:
		assert_true(PartyLabel.listing_line(_row(ui, "listing_1"), "Bob").contains("unknown seller"), "a nameless seller reads unknown seller (en)"))
	_with_locale("pt_BR", func() -> void:
		assert_true(PartyLabel.listing_line(_row(ui, "listing_1"), "Bob").contains("vendedor desconhecido"), "and vendedor desconhecido (pt_BR)"))
	assert_false(str(by_id["listing_1"]).contains(reg.public_handle(gone)), "never the handle")
	var window := NetHarnessSteps.market_window_text(ui)
	assert_true(window.contains("Alice") and window.contains("Hosta"), "the market window itself names both sellers")
	assert_false(RegEx.create_from_string("p_[0-9a-f]{16}").search(window) != null, "and prints no handle")
	ui.free()
	bob.free()
	# Alice's own client sees her listing marked as hers, in both locales.
	var hers := _client_market(data, reg.public_handle(alice))
	var ui2 := _new_test_ui()
	ui2.market_slice = hers
	_with_locale("en", func() -> void:
		assert_eq(PartyLabel.label(PartyLabel.SELF, "Alice"), "Alice (you)", "her own listing reads (you)")
		assert_true(PartyLabel.listing_line(_row(ui2, "listing_0"), "Alice").contains("Alice (you)"), "in her market window"))
	_with_locale("pt_BR", func() -> void:
		assert_true(PartyLabel.listing_line(_row(ui2, "listing_0"), "Alice").contains("Alice (você)"), "and in pt_BR"))
	ui2.free()
	hers.free()
	n.free()
	reg.free()

func _row(ui: Node, id: String) -> Dictionary:
	for row in ui.market_rows():
		if str(row["id"]) == id:
			return row
	return {}

func _test_name_after_restart() -> void:
	var reg := _registry()
	var alice := _alice(reg)
	var market := MarketSlice.new()
	add_child(market)
	market.apply_market_data({ "listing_0": _listing(alice) })
	var saved_market: Dictionary = market.get_market_data()
	assert_false(JSON.stringify(saved_market).contains("seller_name"), "the save holds no name: it is read at send time")
	var saved_names: Dictionary = reg.names_to_data()
	market.free()
	reg.free()
	# A restarted host: Alice is offline (no record loaded), only the world record's name index knows her.
	var reg2 := PlayerRegistry.new()
	add_child(reg2)
	reg2.names_from_data(saved_names)
	var market2 := MarketSlice.new()
	add_child(market2)
	market2.apply_market_data(saved_market)
	var r := _host_net(reg2)
	var n: NetworkingSlice = r[0]
	n._on_market_synced(market2.get_market_data())
	var l: Dictionary = (_sent(r[1], "market_synced").get("data", {}) as Dictionary).get("listing_0", {})
	assert_eq(str(l.get("seller_name", "")), "Alice", "an offline seller keeps her name after a restart")
	reg2.note_name(alice, "Alicia")
	n._on_market_synced(market2.get_market_data())
	l = (_sent(r[1], "market_synced").get("data", {}) as Dictionary).get("listing_0", {})
	assert_eq(str(l.get("seller_name", "")), "Alicia", "a renamed seller shows the new name at the next sync")
	n.free()
	market2.free()
	reg2.free()

func _test_governance_and_trade_named() -> void:
	var reg := _registry()
	var alice := _alice(reg)
	var r := _host_net(reg)
	var n: NetworkingSlice = r[0]
	var votes := {}
	votes[PartyLabel.SELF] = "for"
	n._on_governance_synced({ "proposals": { "proposal_0": { "id": "proposal_0", "title": "Walls", "author": alice, "votes": votes } },
		"decisions_log": [{ "author": PartyLabel.SELF }], "next_id": 1 })
	var gov: Dictionary = _sent(r[1], "governance_synced").get("data", {})
	var p: Dictionary = gov["proposals"]["proposal_0"]
	assert_eq(str(p.get("author_name", "")), "Alice", "a proposal names its author")
	assert_true((p["votes"] as Dictionary).has(reg.public_handle(reg.local_player_id)), "the host's own vote crosses as its handle")
	assert_eq(str(gov["decisions_log"][0]["author"]), reg.public_handle(reg.local_player_id), "so does its own decision")
	var offers := {}
	offers[alice] = { "give": { "Thornwood": 1 }, "want": {} }
	offers[PartyLabel.SELF] = { "give": {}, "want": { "Thornwood": 1 } }
	var trade := { "id": "trade_0", "parties": [PartyLabel.SELF, alice], "offers": offers, "accepted": {}, "state": "pending" }
	n._on_trade_synced({ "trades": { "trade_0": trade }, "next_id": 1 })
	var t: Dictionary = (_sent(r[1], "trade_synced").get("data", {}) as Dictionary)["trades"]["trade_0"]
	assert_eq(str((t["names"] as Dictionary).get(reg.public_handle(alice), "")), "Alice", "a trade names each party by handle")
	assert_eq(str((t["names"] as Dictionary).get(reg.public_handle(reg.local_player_id), "")), "Hosta", "the host's party too")
	assert_false((t["offers"] as Dictionary).has(PartyLabel.SELF), "and no party crosses as a client's own literal")
	n._on_trade_completed(trade)
	var done: Dictionary = _sent(r[1], "trade_completed").get("trade", {})
	assert_eq(str((done.get("names", {}) as Dictionary).get(reg.public_handle(alice), "")), "Alice", "a completed trade is named the same way")
	for type in ["governance_synced", "trade_synced", "trade_completed"]:
		var pkt := JSON.stringify(_sent(r[1], type))
		assert_false(pkt.contains(alice) or pkt.contains(reg.local_player_id), "%s carries no player id" % type)
	assert_eq(trade["parties"][0], PartyLabel.SELF, "the authoritative trade is not touched")
	n.free()
	reg.free()

## Every formatter in `PLAYER_FIELD_KEYS` rendered from a row whose player fields are handles: no handle shows.
func _test_player_fields_print_no_handle() -> void:
	var handle := "p_" + "ab".repeat(8)
	var named := { "listing_line": { "id": "listing_0", "item_id": "Thornwood", "quantity": 1, "price": 5.0, "seller": handle, "seller_name": "Alice" },
		"proposal_line": { "id": "proposal_0", "state": "proposed", "title": "Walls", "for": 1, "against": 0, "author": handle, "author_name": "Alice" },
		"trade_line": { "party": handle, "party_name": "Alice", "side": "give", "item_id": "Thornwood", "quantity": 1 } }
	assert_eq(PartyLabel.PLAYER_FIELD_KEYS.size(), 4, "four UI strings format a player field")
	for key in PartyLabel.PLAYER_FIELD_KEYS:
		var fn := str(PartyLabel.PLAYER_FIELD_KEYS[key])
		for locale in ["en", "pt_BR"]:
			TranslationServer.set_locale(locale)
			var with_name: String
			var nameless: String
			if fn == "ClanPanel.roster_lines":
				with_name = str(ClanPanel.roster_lines([{ "name": "Alice", "handle": handle, "role": "member", "online": true, "skills": {} }], "")[0])
				nameless = str(ClanPanel.roster_lines([{ "name": handle, "handle": handle, "role": "member", "online": true, "skills": {} }], "")[0])
			else:
				var row: Dictionary = named[fn]
				with_name = _format(fn, row)
				var bare := row.duplicate()
				for f in ["seller_name", "author_name", "party_name"]:
					bare.erase(f)
				nameless = _format(fn, bare)
			assert_true(with_name.contains("Alice") and not with_name.contains(handle), "%s (%s) prints the name, not the handle" % [key, locale])
			assert_false(nameless.contains(handle), "%s (%s) prints no handle when the name is missing" % [key, locale])
	TranslationServer.set_locale("en")

func _format(fn: String, row: Dictionary) -> String:
	match fn:
		"listing_line":
			return PartyLabel.listing_line(row)
		"proposal_line":
			return PartyLabel.proposal_line(row)
		"trade_line":
			return PartyLabel.trade_line(row)
	assert_true(false, "%s is a formatter this test renders" % fn)
	return ""

## The UI strings in `PLAYER_FIELD_KEYS` are formatted only in party_label.gd (and the clan roll, through
## `PartyLabel.member`): a new call site that formats one itself would print whatever the row holds.
func _test_player_field_audit() -> void:
	var hits := _key_uses("res://src")
	for key in PartyLabel.PLAYER_FIELD_KEYS:
		var files: Array = hits.get(key, [])
		var allowed: Array = ["res://src/ui/party_label.gd"] if key != "clan.member_line" else ["res://src/ui/clan_panel.gd"]
		assert_eq(files, allowed, "%s is formatted only in %s" % [key, allowed])
	var clan := FileAccess.get_file_as_string("res://src/ui/clan_panel.gd")
	assert_true(clan.contains("I18n.t(\"clan.member_line\", [PartyLabel.member(m)"), "the clan roll names a member through PartyLabel")

## key -> the src/ files (tests excluded) that call `I18n.t("<key>"` for a key of PLAYER_FIELD_KEYS.
func _key_uses(dir: String) -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string(dir.path_join(f))
		for key in PartyLabel.PLAYER_FIELD_KEYS:
			if src.contains("I18n.t(\"%s\"" % key):
				if not out.has(key):
					out[key] = []
				(out[key] as Array).append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if d != "tests":
			var sub := _key_uses(dir.path_join(d))
			for key in sub:
				if not out.has(key):
					out[key] = []
				(out[key] as Array).append_array(sub[key])
	return out

func _test_host_ui_names_remote_seller() -> void:
	var reg := _registry()
	var alice := _alice(reg)
	var market := MarketSlice.new()
	add_child(market)
	market.apply_market_data({ "listing_0": _listing(alice), "listing_1": _listing(PartyLabel.SELF) })
	var ui := _new_test_ui()
	ui.market_slice = market
	# As game_root wires it: the host's own literal resolves through its local id.
	ui.party_name_of = func(p: String) -> String: return reg.character_name(reg.local_player_id if p == "player" else p)
	ui.set_own_handle(reg.public_handle(reg.local_player_id))
	_with_locale("en", func() -> void:
		var text := NetHarnessSteps.market_window_text(ui)
		assert_true(text.contains("Alice"), "the host's market window names the remote seller")
		assert_true(text.contains("Hosta (you)"), "and marks its own listing with its name")
		assert_false(text.contains(alice) or text.contains(reg.public_handle(alice)), "with no id or handle"))
	# A host that skipped creation: its own row reads a bare "(you)", never its handle.
	ui.party_name_of = Callable()
	_with_locale("en", func() -> void:
		var text := NetHarnessSteps.market_window_text(ui)
		assert_true(text.contains("(you)"), "a nameless own row still reads (you)")
		assert_false(text.contains(reg.public_handle(reg.local_player_id)), "and never the handle own_display_name falls back to"))
	ui.free()
	market.free()
	reg.free()

## A host whose own id predates the minted shape (`looks_like_player_id` false, so `redact_for_client` passes it
## through): its own listing still crosses as its handle, never the id.
func _test_legacy_local_id_never_sent() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	var legacy := "host_legacy_cafe"
	reg.set_local_player(legacy)
	var r := _host_net(reg)
	var n: NetworkingSlice = r[0]
	n._on_market_synced({ "listing_0": _listing(PartyLabel.SELF) })
	var trade := { "id": "trade_0", "parties": [PartyLabel.SELF, "merchant"], "offers": { PartyLabel.SELF: { "give": {}, "want": {} } }, "accepted": {}, "state": "pending" }
	n._on_trade_synced({ "trades": { "trade_0": trade }, "next_id": 1 })
	for type in ["market_synced", "trade_synced"]:
		var pkt := JSON.stringify(_sent(r[1], type))
		assert_false(pkt.contains(legacy), "%s does not carry an old-shaped host id" % type)
		assert_true(pkt.contains(reg.public_handle(legacy)), "%s names the host by its handle" % type)
	n.free()
	reg.free()
