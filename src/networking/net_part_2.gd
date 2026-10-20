extends RefCounted
## Methods moved verbatim out of `networking_slice.gd` (Phase 154). `sl` is the owning slice; each moved method keeps a forwarder there.

var sl: Node

func _init(slice: Node) -> void:
	sl = slice

## Phase 135 — apply a named profile. False (nothing changed) for an unknown name. `loopback` turns
## the emulator off; any other profile turns it on. The one-way latency is the profile's, so the
## round trip is twice it (`profile_rtt_ms`).
func apply_profile(name: String) -> bool:
	if not sl.NET_PROFILES.has(name):
		return false
	var p: Dictionary = sl.NET_PROFILES[name]
	sl.net_profile = name
	sl.emulator_latency_ms = float(p["latency_ms"])
	sl.emulator_jitter_ms = float(p["jitter_ms"])
	sl.emulator_loss_rate = float(p["loss_rate"])
	sl.emulator_bandwidth_kbps = float(p["bandwidth_kbps"])
	sl.emulate_network = name != "loopback"
	# The real wire under it is reliable ENet, so a loss the profile models costs a retransmit delay.
	sl.emulator_retransmit = true
	return true

## Record the peer → player_id mapping, and (on a host) send the assigned id back
## to that peer so it can cache it for a reconnect.
func set_player_id(peer_id: int, player_id: String) -> void:
	if player_id.is_empty():
		return
	sl._player_ids[peer_id] = player_id
	if sl._role == sl.Role.HOST:
		sl._deliver(peer_id, {
			"type": "identity_assigned",
			"player_id": player_id,
			"handle": sl._public_handle(player_id),
		})

## Evict last-known states for peers that have been disconnected longer than
## LAST_KNOWN_STATE_TTL_MS. Called every frame from _process() so the host
## dict doesn't grow without bound over long sessions.
func _evict_stale_states() -> void:
	if sl._last_known_timestamps.is_empty():
		return
	var now_ms: float = float(Time.get_ticks_msec())
	for pid: int in sl._last_known_timestamps.keys():
		if now_ms - float(sl._last_known_timestamps[pid]) > float(sl.LAST_KNOWN_STATE_TTL_MS):
			sl._last_known_states.erase(pid)
			sl._last_known_exact.erase(pid)
			sl._teleport_pending.erase(pid)
			sl._last_known_timestamps.erase(pid)
			sl._peer_spatial.remove(pid)

func _on_block_edit_intent(action: String, position: Vector3, normal: Vector3, material: String, exact: Dictionary) -> void:
	if sl._role != sl.Role.CLIENT:
		# Host applies edits directly through the voxel slice; only clients
		# forward intents to the host.
		return
	var packet := {
		"type":     "block_edit_intent",
		"action":   action,
		"normal":   [normal.x, normal.y, normal.z],
		"material": material,
	}
	# Phase 119 — the exact aimed point rides the wire when the sender holds one, not a float32 position
	# quantised to metres far from the origin.
	if sl._is_exact_pos(exact) and sl.WorldPos.is_plausible_pos(exact):
		packet["pk"] = sl.WorldPos.pos_to_packet_text(exact)
	else:
		packet["position"] = sl.WorldPos.to_wire(position)
	sl._broadcast(packet)

## Phase 47 — host: tell the peers whose AOI contains `peer_id` what it wears. Used when
## a peer's position first becomes known: a reconnecting player's worn set is restored
## from its record, which fires no `equipment_changed`, and at the handshake the peer has
## no position yet to scope by (a reconnect gets a fresh ENet id, so the spawn default
## would be used). Does nothing for a peer with no connection, no worn set or no position.
func announce_equipment_to_aoi(peer_id: int) -> void:
	if sl._role != sl.Role.HOST or not sl._connected() or sl.player_registry == null or not sl.has_last_known_state(peer_id):
		return
	var worn = sl._worn_of_peer(peer_id)
	if worn.is_empty():
		return
	for pid in sl.equipment_targets(peer_id):
		sl._send_equipment(int(pid), peer_id, worn)

func _on_remote_player_state(peer_id: int, position: Vector3) -> void:
	if sl._role != sl.Role.HOST:
		return
	# Phase 19 — persist the client's last-known authoritative position so a
	# rejoining client can resume from it.
	var first_report = not sl.has_last_known_state(peer_id)
	sl.remember_player_state(peer_id, position, sl._inbound_exact)
	if first_report:
		sl.announce_equipment_to_aoi(peer_id)
	sl._refresh_equipment_pairs(peer_id)
	# Phase 97 — relay the peer's exact `{chunk, local}` when its report carried one, so a far-from-origin
	# avatar does not jitter by float32 metres on the other clients.
	var relayed: Dictionary = sl._inbound_exact if not sl._inbound_exact.is_empty() \
			else sl.WorldPos.from_world(position.x, position.y, position.z)
	var packet := {
		"type":     "remote_player_state",
		"peer_id":  peer_id,
		"pk":       sl.WorldPos.pos_to_packet_text(relayed),
	}
	sl._broadcast_aoi(packet, position)

## Phase 37 — host → one client: a creature struck THIS player. Damage is applied by
## the machine that simulates the body (`PlayerSlice` on the peer's own client, which
## owns its HP), so the host sends the round's outcome rather than trying to hold a
## peer's health it cannot verify (`PlayerRegistry.record_hp` refuses a
## client-declared HP for the same reason). Peer-scoped, like `send_own_state`: one
## player's damage is not world state.
func send_player_damaged(peer_id: int, damage: float, attacker_id: String) -> void:
	if sl._role != sl.Role.HOST:
		sl.Diag.warn("NetworkingSlice: send_player_damaged called on non-host — dropped")
		return
	sl._deliver(peer_id, {
		"type":        "player_damaged",
		"damage":      damage,
		"attacker_id": attacker_id,
	})

## Phase 156 — host → clients in range of `position`: one swing resolved, so each client can animate the
## attacker and the target. Keys are "p:<peer id>" (a player; the host's own body is peer 1) or
## "c:<creature id>"; nothing else rides along, so no identity or health leaves the host. Animation
## only: a client never reads damage or outcome from it as game state.
func send_combat_hit(attacker_key: String, defender_key: String, outcome: String, position: Vector3) -> void:
	if sl._role != sl.Role.HOST:
		sl.Diag.warn("NetworkingSlice: send_combat_hit called on non-host — dropped")
		return
	sl._broadcast_aoi({
		"type": "combat_hit",
		"a":    attacker_key,
		"d":    defender_key,
		"o":    outcome,
	}, position)

## Phase 159 — host → clients in range of `position`: peer `subject_peer` (the host's own body is peer 1)
## started `gesture_id`, or stood up (""). Animation only; the actor's own client is in range of itself.
func send_gesture(subject_peer: int, gesture_id: String, position: Vector3) -> void:
	if sl._role != sl.Role.HOST:
		sl.Diag.warn("NetworkingSlice: send_gesture called on non-host — dropped")
		return
	sl._broadcast_aoi({ "type": "gesture", "peer_id": subject_peer, "g": gesture_id }, position)

## Phase 159 — host: a peer just bound its identity; tell it the poses held by the players inside its AOI
## (`poses` is peer id -> gesture id, the host's own body as peer 1), so a late joiner sees them seated.
func send_peer_gestures_to(peer_id: int, poses: Dictionary) -> void:
	if sl._role != sl.Role.HOST or not sl._connected():
		return
	var center = sl._joiner_aoi_center(peer_id)
	for subject in poses:
		var o := int(subject)
		if o == peer_id or not sl._has_subject_position(o) or center.distance_to(sl._subject_position(o)) > sl.AOI_RADIUS:
			continue
		sl._deliver(peer_id, { "type": "gesture", "peer_id": o, "g": str(poses[subject]) })

## Phase 36 — per-peer client → host token bucket. `now_ms` is an argument (not a
## clock read) so the rule is testable without waiting: the same shape the
## emulator's `_sample_remote_state_at` uses. Returns true when a token was
## available and the packet may be routed, false when the bucket is empty and the
## packet is dropped.
##
## Refill is continuous (elapsed ms × RATE_BUCKET_REFILL_PER_SEC) and capped at
## RATE_BUCKET_CAPACITY, so an idle peer always has a full burst waiting and a
## flooding one is held to the sustained rate. The bucket is created on a peer's
## first packet with a full capacity — the join burst (handshake + first snapshot
## request + first movement packets) is exactly what that burst is for.
func _allow_packet(peer_id: int, now_ms: float) -> bool:
	if not sl._rate_buckets.has(peer_id):
		sl._rate_buckets[peer_id] = { "tokens": sl.RATE_BUCKET_CAPACITY, "at_ms": now_ms }
	var bucket: Dictionary = sl._rate_buckets[peer_id]
	var elapsed: float = maxf(0.0, now_ms - float(bucket["at_ms"]))
	bucket["at_ms"] = now_ms
	bucket["tokens"] = minf(
		sl.RATE_BUCKET_CAPACITY,
		float(bucket["tokens"]) + elapsed * 0.001 * sl.RATE_BUCKET_REFILL_PER_SEC
	)
	if float(bucket["tokens"]) < 1.0:
		var last_warn: float = float(sl._rate_warn_ms.get(peer_id, -sl.SEQ_GAP_WARN_INTERVAL_MS))
		if now_ms - last_warn >= sl.SEQ_GAP_WARN_INTERVAL_MS:
			sl._rate_warn_ms[peer_id] = now_ms
			sl.Diag.warn("NetworkingSlice: peer %d exceeded the client packet rate — dropping" % peer_id)
		return false
	bucket["tokens"] = float(bucket["tokens"]) - 1.0
	return true

## Host side: replace every player id inside a host → client payload with its public
## handle, recursively — dictionary KEYS as well as values, because a trade's `offers`
## and `accepted` maps are keyed by party.
##
## The player id is a BEARER TOKEN (`resolve_identity` hands the record to whoever
## presents it on join), so broadcasting it handed every client the means to take over
## any player's record once that player disconnected — inventories, positions,
## appearance, technology. Market listings, trade sessions, and proposals all named
## players by id; this is where they stop. The handle is derived, opaque and stable
## (see PlayerRegistry.public_handle), and it is not a claim: claiming it mints a new
## identity.
##
## Non-id strings ("merchant", a proposal title, an item key) are untouched: the
## shape test recognises a minted id and nothing else.
func redact_for_client(value: Variant) -> Variant:
	if sl.player_registry == null:
		return value
	return sl._map_identities(value, func(s: String) -> String:
		if sl.PlayerRegistry.looks_like_player_id(s):
			return sl._public_handle(s)
		return s
	)

## Route a client → host packet. Only client-originated types are accepted;
## host-only types sent by a malicious client are dropped and logged.
func _route_c2h(sender: int, payload: Dictionary) -> void:
	match str(payload.get("type", "")):
		"join_intent":
			# Phase 33 — the client presents its cached id ("" on a first join).
			# The registry owns resolution; the host answers with player_joined.
			# Phase 53 — a first join may carry a friend's handle to spawn beside.
			if sl.player_registry != null and sl.player_registry.has_method("note_friend_code"):
				sl.player_registry.note_friend_code(sender, str(payload.get("friend_code", "")))
			GameBus.player_join_intent.emit(sender, str(payload.get("claimed_id", "")))
		"player_moved":
			# Phase 86 — a position that does not decode is refused, not read as the origin: the
			# previous last-known state stands.
			# Phase 119 — the packet is decoded and validated here, once, before any consumer
			# (`aoi_region` included) sees a number from it: a truncated, non-finite or implausible
			# position is refused, with one throttled warning per peer.
			# The compact position is decoded ONCE (`WorldPos.compact_decodes` counts them).
			var exact = sl.WorldPos.pos_from_packet(payload)
			if exact.is_empty() and (payload.has("pk") or not sl.WorldPos.is_wire(payload.get("position", null))):
				sl._warn_malformed_position(sender)
				return
			var pos = sl.WorldPos.to_scene(exact, Vector2i.ZERO) if not exact.is_empty() \
					else sl.WorldPos.from_wire(payload.get("position", null), Vector3.ZERO)
			# The packet also carries the peer's self-declared `hp` / `max_hp`,
			# used for its own display. The host deliberately keeps NO durable
			# copy of THAT value: it is client-declared and cannot be verified
			# here, so persisting it made health a restart-proof cheat (see
			# PlayerRegistry.record_hp). Phase 38 — a peer's health IS durable
			# now, but only from the number the host resolved itself
			# (record_simulated_hp, via combat_wiring.on_player_damaged); the
			# declared half still has no door. Position is the other half the
			# host retains, and only so a reconnect can resume from it.
			# Phase 130 — the host decides immobilization itself: a held peer's report is dropped
			# (its first report is kept, so it still has a position to be held at).
			if sl.has_last_known_state(sender) and sl.peer_held.is_valid() and bool(sl.peer_held.call(sender)):
				return
			sl._inbound_exact = exact
			GameBus.remote_player_state.emit(sender, pos)
			sl._inbound_exact = {}
		"craft_intent":
			# A remote peer's craft must resolve against ITS OWN inventory (crafting
			# is per-player now that each player persists one). The identity comes
			# from the connection, never from the payload: a client cannot name
			# whose inventory it crafts against.
			var crafter = sl._actor_id(sender)
			if crafter == "":
				sl._refuse_unhandshaked(sender, "craft_intent")
				return
			GameBus.craft_intent.emit(str(payload.get("recipe_id", "")), crafter)
		"repair_intent":
			# Phase 34 — the same identity rule as craft_intent: the repairing
			# player is the one bound to THIS connection, so a client cannot name
			# whose tool it repairs or whose materials it spends.
			var repairer = sl._actor_id(sender)
			if repairer == "":
				sl._refuse_unhandshaked(sender, "repair_intent")
				return
			GameBus.repair_intent.emit(str(payload.get("item_id", "")), repairer)
		"research_intent":
			# Phase 34 — and the same for research: whose tree moves is decided by
			# the connection, never by the payload.
			var researcher = sl._actor_id(sender)
			if researcher == "":
				sl._refuse_unhandshaked(sender, "research_intent")
				return
			GameBus.research_intent.emit(str(payload.get("tech_id", "")), researcher)
		"waystone_travel_intent":
			# Phase 125 — who travels is the connection's player, never a name in the payload.
			var traveller = sl._actor_id(sender)
			if traveller == "":
				sl._refuse_unhandshaked(sender, "waystone_travel_intent")
				return
			GameBus.waystone_travel_intent.emit(str(payload.get("from", "")).left(64), str(payload.get("to", "")).left(64), traveller)
		"settlement_intent":
			# Phase 140 — who acts is the connection's player. Only short scalar args are kept.
			var settler = sl._actor_id(sender)
			if settler == "":
				sl._refuse_unhandshaked(sender, "settlement_intent")
				return
			var raw_args: Variant = payload.get("args", {})
			var clean := {}
			if raw_args is Dictionary:
				for k: Variant in (raw_args as Dictionary).keys():
					var v: Variant = raw_args[k]
					if (v is String or v is int or v is float) and clean.size() < 8:
						clean[str(k).left(16)] = str(v).left(64) if v is String else v
			GameBus.settlement_intent.emit(str(payload.get("action", "")).left(16), clean, settler)
		"tame_intent":
			# Phase 35 — and the same for taming: the flag and the companion bind
			# to the connection's own player, never to a name in the payload.
			# Phase 47 — the payload's bare-hands claim is NOT read: the host
			# evaluates the fabric's rule against its own copy of the sender's worn
			# set (PlayerRegistry.get_equipment).
			var tamer = sl._actor_id(sender)
			if tamer == "":
				sl._refuse_unhandshaked(sender, "tame_intent")
				return
			GameBus.tame_intent.emit(str(payload.get("instance_id", "")), tamer)
		"chat_intent":
			# Phase 85 — a chat line or command is said BY the connection's player; the host's
			# ChatSlice decides whether a command is theirs to run.
			var speaker = sl._actor_id(sender)
			if speaker == "":
				sl._refuse_unhandshaked(sender, "chat_intent")
				return
			var said: Variant = payload.get("text", "")
			if said is String:
				GameBus.chat_intent.emit(said, speaker)
		"gesture_intent":
			# Phase 159 — a gesture is started or ended for the connection's own player, never for a name
			# in the payload; the host's GestureSlice validates the id, the player's state and the rate.
			var actor = sl._actor_id(sender)
			if actor == "":
				sl._refuse_unhandshaked(sender, "gesture_intent")
				return
			var wanted: Variant = payload.get("g", "")
			if wanted is String and (wanted as String).length() <= sl.GESTURE_ID_MAX:
				GameBus.gesture_intent.emit(wanted, actor)
		"equip_intent":
			# Phase 47 — a worn-slot action is applied to the connection's player, never
			# to a name in the payload; the registry checks it against the fabric and the bag.
			var wearer = sl._actor_id(sender)
			if wearer == "":
				sl._refuse_unhandshaked(sender, "equip_intent")
				return
			var slot: Variant = payload.get("slot", "")
			var item: Variant = payload.get("item", "")
			if slot is String and item is String:
				var seq: Variant = payload.get("seq", 0)
				var seq_n: int = int(seq) if (seq is int or seq is float) else 0
				# Phase 119 — an action numbered below one already applied is stale or replayed: ignored.
				if seq_n < sl.player_registry.equip_seq_of(wearer):
					return
				sl.player_registry.note_equip_seq(wearer, seq_n)
				GameBus.equip_intent.emit(wearer, slot, item)
		"block_edit_intent":
			# Phase 36 — a world edit needs a bound identity AND a target within the
			# host's evidence of arm's reach. The block position arrives as a bare
			# claim: with no reach check a client could mine or build anywhere in the
			# world (under another player's feet included), and with no handshake
			# requirement it could do so before the host knew who it was at all.
			#
			# Phase 42 review — the bound identity also RIDES the request now, so the
			# action resolves against that player's own pack: without it the host
			# credited its own inventory with a client's material (and spent its own on
			# a client's placement). `action`/`material` are still the client's claims,
			# but neither grants anything — the actor is the connection, the material
			# must be a real fabric material, and the debit lands on the actor's pack.
			if sl._actor_id(sender) == "":
				sl._refuse_unhandshaked(sender, "block_edit_intent")
				return
			var action := str(payload.get("action", ""))
			if payload.has("pk") and not sl.WorldPos.packet_has_pos(payload):
				sl._warn_malformed_position(sender)
				return
			var ipos = sl.WorldPos.packet_world(payload, sl._vec3(payload.get("position", [])))
			var iexact = sl.WorldPos.pos_from_packet(payload) if payload.has("pk") else {}
			var inorm = sl._vec3(payload.get("normal", [0, 1, 0]))
			if not sl._within_reach(sender, ipos, sl.MAX_EDIT_REACH):
				sl.Diag.warn("NetworkingSlice: block_edit_intent from peer %d is out of reach — dropped" % sender)
				return
			if action == "mine":
				GameBus.block_mine_requested.emit(ipos, inorm, sl._actor_id(sender), iexact)
			elif action == "place":
				GameBus.block_place_requested.emit(
					ipos, inorm, sl._actor_id(sender), str(payload.get("material", "")), iexact)
			else:
				sl.Diag.error("NetworkingSlice: unknown block_edit_intent action '%s'" % action)
		"tree_chop_intent":
			# Phase 36 — same two rules as block_edit_intent. The intent names only
			# a tree id, so the reach check resolves the tree's own position through
			# the wired TreeSlice (a tree the host does not have is not chopable
			# either — TreeSlice re-checks that too, authoritatively). The host then
			# re-runs the chop and broadcasts tree_chopped back to every client.
			#
			# Phase 42 review — and the bound identity rides the request, so the wood
			# and the axe's wear are the CHOPPER's (see the block_edit_intent arm).
			if sl._actor_id(sender) == "":
				sl._refuse_unhandshaked(sender, "tree_chop_intent")
				return
			var tree_id := str(payload.get("tree_id", ""))
			if not sl._chop_is_in_reach(sender, tree_id):
				sl.Diag.warn("NetworkingSlice: tree_chop_intent from peer %d is out of reach — dropped" % sender)
				return
			GameBus.tree_chop_requested.emit(tree_id, sl._actor_id(sender))
		"market_list_intent":
			# Phase 36 — a listing is the CONNECTION's player selling. `seller` used
			# to be passed through verbatim unless it read exactly "player", so a
			# client could name a victim: the escrow debit then emptied that player's
			# inventory into a listing the attacker could buy back.
			var seller = sl._actor_id(sender)
			if seller == "":
				sl._refuse_unhandshaked(sender, "market_list_intent")
				return
			GameBus.market_list_intent.emit(
				seller,
				str(payload.get("item_id", "")),
				int(payload.get("quantity", 0)),
				float(payload.get("price", 0.0))
			)
		"market_buy_intent":
			# Phase 36 — the buyer is the connection's player too: naming one let a
			# client drain a victim's market purchases into its own listing.
			var buyer = sl._actor_id(sender)
			if buyer == "":
				sl._refuse_unhandshaked(sender, "market_buy_intent")
				return
			GameBus.market_buy_intent.emit(str(payload.get("listing_id", "")), buyer)
		"proposal_submit_intent":
			# Phase 36 — the author is the connection's player, never a name.
			var author = sl._actor_id(sender)
			if author == "":
				sl._refuse_unhandshaked(sender, "proposal_submit_intent")
				return
			GameBus.proposal_submit_intent.emit(
				author,
				str(payload.get("title", "")),
				str(payload.get("body", ""))
			)
		"proposal_vote_intent":
			# Phase 36 — "one vote per distinct voter" is what a quorum MEANS, so the
			# voter must be the connection's player: a client that could name voters
			# could ratify any proposal alone, and could vote a proposal through under
			# the author's name (the one identity the rule forbids).
			var voter = sl._actor_id(sender)
			if voter == "":
				sl._refuse_unhandshaked(sender, "proposal_vote_intent")
				return
			GameBus.proposal_vote_intent.emit(
				str(payload.get("proposal_id", "")),
				voter,
				str(payload.get("verdict", ""))
			)
		"proposal_supersede_intent":
			# Superseding names no party — it is a transition between two proposals —
			# so there is no identity to bind. It still requires a bound identity: an
			# anonymous connection may not move the decisions log. WHICH players may
			# supersede a given proposal is a governance rule, not an identity one,
			# and is not decided here.
			if sl._actor_id(sender) == "":
				sl._refuse_unhandshaked(sender, "proposal_supersede_intent")
				return
			GameBus.proposal_supersede_intent.emit(
				str(payload.get("proposal_id", "")),
				str(payload.get("replacement_id", ""))
			)
		"trade_start_intent":
			# Phase 36 — party_a is the connection's player: a client cannot open a
			# session in someone else's name. party_b is the counterparty the client
			# NAMES — an invite is the one thing a payload may legitimately name here,
			# because it grants nothing: every later step (propose, accept, reject)
			# acts as the connection's own player, so a session aimed at a name nobody
			# answers simply never resolves. Rate-limited like every other intent, so
			# a nameless invite flood cannot be a cheap amplification either.
			var actor = sl._actor_id(sender)
			if actor == "":
				sl._refuse_unhandshaked(sender, "trade_start_intent")
				return
			var other = sl._named_party(str(payload.get("party_b", "")))
			if other == "" or other == actor:
				sl.Diag.warn("NetworkingSlice: trade_start_intent from peer %d names an unusable counterparty — dropped" % sender)
				return
			GameBus.trade_start_intent.emit(actor, other)
		"trade_propose_intent":
			# Phase 36 — the party proposing is the connection's player.
			var proposer = sl._actor_id(sender)
			if proposer == "":
				sl._refuse_unhandshaked(sender, "trade_propose_intent")
				return
			GameBus.trade_propose_intent.emit(
				str(payload.get("trade_id", "")),
				proposer,
				payload.get("give", {}),
				payload.get("want", {})
			)
		"trade_accept_intent":
			# Phase 36 — THE trade finding: `party` used to pass through verbatim,
			# so a client could accept AS the other side and commit the other
			# player's goods. The accepter is the connection's player, always.
			var accepter = sl._actor_id(sender)
			if accepter == "":
				sl._refuse_unhandshaked(sender, "trade_accept_intent")
				return
			GameBus.trade_accept_intent.emit(
				str(payload.get("trade_id", "")),
				accepter
			)
		"trade_reject_intent":
			# Phase 36 — and a client may only reject on its own behalf (a spoofed
			# reject closed another player's session for both sides).
			var rejecter = sl._actor_id(sender)
			if rejecter == "":
				sl._refuse_unhandshaked(sender, "trade_reject_intent")
				return
			GameBus.trade_reject_intent.emit(
				str(payload.get("trade_id", "")),
				rejecter
			)
		_:
			# Clients may not send host-authoritative types (block_changed,
			# inventory_synced, etc.) — drop anything else and log it.
			sl.Diag.warn("NetworkingSlice: unexpected type '%s' from client %d — dropped" \
				% [payload.get("type", ""), sender])

## Drain the emulator queue, delivering due packets via the real RPC.
func _drain_emulator(now_ms: float = -1.0) -> void:
	var now := now_ms if now_ms >= 0.0 else float(Time.get_ticks_msec())
	var i := 0
	while i < sl._pending.size():
		var entry: Dictionary = sl._pending[i]
		if float(entry["at_ms"]) <= now:
			var msg: Variant = JSON.parse_string(str(entry["payload"]))
			# Phase 135 — a packet whose connection is gone (or never completed) is lost with it, as on
			# a real wire; sending it would raise an RPC error per packet on every frame.
			if msg is Dictionary and sl._peer_reachable(int(entry["peer_id"])):
				sl._ensure_transport().send(int(entry["peer_id"]), msg)
			else:
				sl.emulator_dropped += 1
				if sl._role == sl.Role.HOST:
					sl._link_free_at_ms.erase(int(entry["peer_id"]))
					sl._ordered_at_ms.erase(int(entry["peer_id"]))
			sl._pending.remove_at(i)
		else:
			i += 1

## Phase 19 — a peer disconnecting does NOT erase its last-known position; it is
## retained (with a TTL) so a rejoining client resumes from where it left off and
## the record written at disconnect carries that position.
## A disconnect timestamp is set so _evict_stale_states() can expire the entry
## after LAST_KNOWN_STATE_TTL_MS if the peer never reconnects.
func _on_peer_disconnected(id: int) -> void:
	sl._malformed_position_warn_ms.erase(id)
	GameBus.peer_disconnected.emit(id)
	# Phase 33 — the connection is gone, so its transport mapping goes with it.
	# The player's durable record stays on disk, which is what lets a reconnect
	# with the same player id re-bind to it; game_root writes it and then releases
	# the in-memory copy (PlayerRegistry.evict_player).
	sl.forget_player_id(id)
	sl._forget_equipment_pairs(id)
	forget_peer_channels(id)
	if not sl._last_known_states.has(id):
		sl._teleport_pending.erase(id)   # nothing will age it out otherwise
	if sl._last_known_states.has(id):
		sl._last_known_timestamps[id] = Time.get_ticks_msec()

## Phase 162 — drop the per-peer receive channels (`"<peer>:<type>"` seq frontiers, dedup windows, gap
## warning clocks) and the emulated link of a peer that left. They were kept for every peer that ever
## connected: the crowd stress run's `churn` pattern counts them as orphans.
func forget_peer_channels(id: int) -> void:
	var prefix := "%d:" % id
	for table: Dictionary in [sl._recv_seq, sl._recv_seen, sl._seq_gap_warn_ms]:
		for key in table.keys():
			if str(key).begins_with(prefix):
				table.erase(key)
	sl._link_free_at_ms.erase(id)
	sl._ordered_at_ms.erase(id)
