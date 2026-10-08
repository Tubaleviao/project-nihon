# Roadmap history — Phases 33–38

Completed phases, archived unchanged from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 33 — Player identity and server-side persistence ✅ Done

**Goal:** Give each player a connection-independent id owning their inventory,
HP, position, and appearance, then write a real save lifecycle — load on server
boot, autosave, save on disconnect and shutdown. Today the dedicated server
(Phase 27) boots empty and discards the world: `_boot_server()` calls neither
save nor load, and every piece of player state is keyed on `peer_id`, which ENet
reassigns on every connection. Builds on Phase 32: by the time this phase starts
there is exactly one authoritative boot (`_boot_server()`), shared by the
listen host.

**Newel dependency:** `PlayerIdentityModel` — a new `decision` entity in
`fabric/constitution/decisions.js` (the ratified decision on whether identity is
a server-issued local UUID or an account-backed id). No generator change: the
`uuid` + `enum` field types and the `proposed → accepted → superseded` decision
state machine are already emitted. Run `pnpm validate` → `pnpm generate` →
`pnpm check-drift` after adding it.

**Deliverables:**
- Add a stable player id that survives reconnect; `peer_id` can't be the key.
  Mint a `player_id` on first join, persist it, and send it to the client so a
  reconnect re-binds to the same record (`networking_slice` keeps only the
  transport mapping `peer_id → player_id`).
- Make inventory per-player, preserving the Phase 25 per-instance
  durability-array invariant: a durable item's per-instance `Array` *is* the
  stack, and `get_durability_data()` / `replace_contents()` round-trip per
  player — no shared inventory across peers.
- Restore `player.position` and `player.hp` in `_on_load_completed` — the boot
  snapshot already writes both (`player` → `position` / `hp` in `game_root`),
  but load restores only inventory / technology / market / governance / trade.
- Add stations and creature state (deaths, respawn timers) to the snapshot.
  `station_slice` has no `get_station_data()` / `apply_station_data()` pair at
  all, and `creature_slice.get_snapshot_creatures()` carries only
  `{instance_id, creature_id, state, position}` — no `hp`, no `respawn_at`.
- Load the world in `_boot_server` — Phase 32's shared authoritative half — which
  currently calls neither save nor load (it only runs `chunk_manager.start()` /
  `refresh()` and `host()`). Loading there means the listen host inherits it.
- Autosave on an interval; save on peer disconnect.
- Save on shutdown: handle `WM_CLOSE_REQUEST` and `SIGTERM` — servers are
  killed, not closed, so the window-close path alone never fires. The WM-close
  half needs `get_tree().auto_accept_quit = false` before saving.
- Use the existing dirty-chunk tracking for incremental voxel saves, not full
  rewrites: `_on_save_completed` already calls `clear_dirty_chunks()`, so an
  autosave must rewrite only `get_dirty_chunk_keys()`'s manifests.
- Replace the single JSON slot with per-player records under a server save dir:
  `persistence_slice` writes one `user://saves/slot_NN.json` today; move to a
  world record (chunks / stations / creatures) plus one record per player under
  a server save dir, keeping `save` / `load_slot` working for the existing
  tests and the client-side legacy path.
- Ratify identity model (local UUID vs account) as a fabric decision entity:
  `PlayerIdentityModel` in `fabric/constitution/decisions.js`, accepted through
  the same decision state machine the other constitution decisions use.

**Acceptance criteria:** *(met — see the verification notes below)*
- [x] A restart round-trip (save → fresh boot → load) reproduces player
  position, HP, inventory with per-instance durability, stations, and creature
  death / respawn state.
- [x] Reconnecting with a new connection keeps the same inventory — the id
  survives the reconnect and the `peer_id` change.
- [x] A disconnect mid-craft leaves the inventory consistent after save: no
  half-consumed materials, no duplicated output.
- [x] A spoofed id is rejected — a client cannot claim or write into another
  player's record.
- [x] `_boot_server` loads the world on boot and autosave runs on its interval
  (host/authoritative only).
- [x] `pnpm validate` + `pnpm check-drift` clean (543 generated files match the
  manifest), headless suite green with the 4 new tests.

**Tasks / tests:**
- `identity: restart round-trip restores the world` — save → drop every slice →
  fresh slices → load: voxel edits (incl. the incrementally-merged chunk),
  station (id + type), creature state + wall-clock deadline, player position /
  HP / inventory durability / appearance recipe.
- `identity: reconnect keeps the inventory` — first join mints an id, disconnect
  drops the transport mapping, a NEW connection claiming the cached id re-binds
  to the same record and the same inventory.
- `identity: disconnect mid-craft stays consistent` — a craft, then the
  disconnect-time record write, then a restored inventory: exactly one craft's
  inputs consumed, the output present exactly once, the record equal to the live
  inventory.
- `identity: spoofed id is rejected` — a claim on a LIVE identity is refused and
  cannot read or write the victim's record; an unknown claimed id is discarded;
  a non-authoritative (client) registry mints nothing.

**Verification (headless, on this machine):**
- Suite: `6695/6695` before the phase → `6761/6761` after (the 4 new tests plus
  the two respawn tests moved to wall-clock deadlines).
- Dedicated server, no save: `[Server] no world record at
  user://saves/server/world.json — booting a fresh world` then
  `[Server] listening on port 7777, max_clients 64`.
- Listen host: writes `saves/server/world.json` +
  `saves/server/player_<player_id>.json`.
- Dedicated server again: `[Server] world loaded from …/world.json` and
  `[Server] restored 1 player record(s)`.
- Clean shutdown on a HEADLESS server (a signal cannot do this — see notes):
  with `user://shutdown_requested` present the server prints
  `[Server] shutdown requested — saving before quit`, writes
  `world saved (incremental) — 0 chunk manifest(s), 169 creature(s)`, deletes the
  request file and exits. `world.json`'s mtime moves; the process is gone.
- Identity handshake over a real socket (loopback, twice):
  `[Server] joined player 'player_1790181748_1_812e' as peer_506044089`, client
  caches `{"player_id": "player_1790181748_1_812e"}`, and on the second
  connection — a different peer id — `[Server] reconnected player
  'player_1790181748_1_812e' as peer_1148372338`. Two record files land in the
  save dir (the local player and the remote peer).

**Implementation notes:**
- **Respawn timers became wall-clock.** `creature_slice` used
  `Time.get_ticks_msec() + respawn_secs * 1000.0` — *process uptime*, so a saved
  deadline meant nothing after a restart. Deadlines are now Unix-epoch seconds
  (`Time.get_unix_time_from_system()`), matching the Phase 24 market/proposal and
  Phase 31 tree conventions. The two existing tests that faked an elapsed
  deadline with `get_ticks_msec()` were moved to the same clock (they had been
  passing *accidentally*: a ticks_msec deadline is always in the past for an
  epoch comparison).
- **`SIGTERM` cannot be intercepted by Godot 4.7 — verified, not assumed.** A
  probe (a throwaway project with a `_notification` print, run headless) showed
  the process dies on `SIGTERM` with **no** notification at all; `SIGINT` *is*
  caught but goes through the `auto_accept_quit` gate rather than reaching the
  scene tree. So the phase does all of: (a) `get_tree().auto_accept_quit = false`
  plus a `NOTIFICATION_WM_CLOSE_REQUEST` handler that saves then quits (the
  windowed path, authoritative roles only); (b) autosave on the fabric interval;
  (c) a polled `user://shutdown_requested` file that saves and quits — the
  headless shutdown hook, and the one the verification above exercises. The
  interval is what bounds the loss for a plain `kill -TERM`.
- **Creature instance ids are now deterministic** — `creature_<cx>_<cz>_<species>_<i>`
  instead of a `_next_id` counter. Persisting and replicating creature state by
  instance id makes the counter-id shape a correctness bug (a peer that streamed
  chunks in a different order named the same creature differently, and a chunk
  reload renumbered survivors): the same defect Phase 31 fixed for tree ids. An
  engaged creature kept alive across a despawn can still shift an index, so the
  state of a mid-fight chunk is not guaranteed to re-attach — noted in the
  function.
- **Load order in `_boot_server` matters.** Load the records, then
  `chunk_manager.start()` / `refresh()`, then re-apply the recorded creature
  state: `spawn_for_chunk()` builds fresh instance records and would otherwise
  wipe the restored death/respawn state.
- **Only the world-record save resets dirty-chunk tracking, and it does so by key.**
  `_on_save_completed` (the legacy `slot_NN` path) deliberately does not clear
  anything: the slot file is a single-file sample and not what a server loads, so
  letting it clear the dirty set dropped pre-slot edits from the next world save.
  The authoritative save clears exactly the keys it serialized
  (`clear_dirty_chunk_keys()`), because the write is off-thread (see the review
  notes below) — an edit made while the worker writes re-marks its chunk instead of
  being swallowed, and a FAILED write re-marks its keys (`mark_dirty_chunks()`).
- **Incremental saves carry only the dirty manifests.**
  `PersistenceSlice.dirty_chunk_subset(manifest, keys)` is the shared pure
  implementation (runtime + test), and `save_world(..., incremental)` merges it
  over the record on disk, so an autosave no longer re-serializes ~49 chunk
  manifests.
- **Id authority sits on the server.** The client presents a cached id at join;
  the host honours it only when it owns that record AND no live peer holds it —
  otherwise a fresh id is minted. That single rule gives both the reconnect
  re-bind and the spoof rejection. `resolve_identity` on a non-authoritative
  registry is a no-op, so a client can never mint.
- **Gate the lifecycle on `is_authoritative`.** A client neither loads a world
  nor autosaves; it receives state from the host (Phase 29's AOI-scoped snapshot
  stays the client's only view) and only caches its player id.
- **Writes are atomic.** `make_dir_recursive_absolute` + temp file + rename, so a
  kill during a save leaves either the old record or the new one, never a
  truncated file.
- Autosave interval, save-dir layout, record file names, the shutdown-request
  path and the atomic-write switch all live in the fabric `PersistenceSystem`
  (`fabric/gameplay/persistence.js`), not as bare GDScript constants.
- **`PlayerCharacter`'s per-player inventory is a registry-owned
  `InventorySlice`**; the local player's is the game's own `_inventory`
  (registered via `set_local_player`), which is what makes inventory per-player
  without touching any existing call site. `_build_snapshot` ships the CONNECTING
  peer's own contents instead of the host's, and `networking._peer_party` now
  resolves a client's `"player"` self-reference to its player id, so a peer's
  market/trade actions land on its own record — and keep landing there after a
  reconnect, which `peer_<id>` could not do.

**Known simplifications (deferred):**
- No account or auth service: identity is the server-issued local UUID the
  ratified `PlayerIdentityModel` decision lands on; account binding / login is
  out of scope.
- No world-shard handoff of a player record between servers — see Deferred →
  server sharding.
- Autosave is a plain interval timer; only ONLINE players' records are rewritten
  (an offline record cannot have changed), but a rewritten record is still whole —
  no field-level diffing.
- **Crafting is per-crafter now, not host-scoped.** `crafting_slice` resolves a
  recipe against `inventory_for(player_id)` — the PlayerRegistry's per-player
  inventory — so a remote peer's craft consumes and produces against ITS OWN
  persisted inventory. A client does not resolve crafts at all: it emits
  `craft_intent(recipe_id, "")`, the networking slice forwards it, and the host
  re-emits it with the identity it bound to that connection (`craft_intent`'s c2h
  arm refuses an un-handshaked peer and never trusts a payload-supplied id). Repair
  and technology research are still host-scoped: same plumbing, not yet moved.
- Appearance is persisted for the LOCAL player's record and rebuilt on boot;
  other players' appearances are not replicated to clients (clients still render
  their own avatar plus position-only ghosts).
- A headless server's clean shutdown needs the `shutdown_requested` file (or an
  autosave tick), because `SIGTERM` cannot be intercepted — see the notes above.

### Phase 33 — review fixes (durable state is not live state, twice over)

A post-implementation review of the branch found 19 defects. They cluster into
four shapes, each worth remembering:

- **A durable record treated as a live feed.** An incremental world save replaced
  the recorded `creatures` list wholesale, but the payload only carries the
  population the process holds (the streamed chunks), so a death in a chunk that
  was not in view was dropped — walk away from a corpse, save, walk back, and the
  creature was alive again. `PersistenceSlice.merge_creature_states()` folds the
  list per `instance_id`. Same shape twice more: a remote peer's position and HP
  were folded into its record only at disconnect (a hard kill restored it at the
  origin, at full health — they are folded on every autosave now, with
  `_last_known_hp` as the HP store), and `despawn_for_chunk` erased a dead
  creature outright so a chunk reload respawned it alive (`_dead_state` keeps the
  death, `_spawn` re-applies it, `get_snapshot_creatures` carries it, and the boot
  replay holds a death for an unstreamed chunk instead of skipping it).
- **A sentinel indistinguishable from a real value.** `apply_creature_state`'s
  optional `respawn_at` was assigned unconditionally, so the 4-argument per-tick
  delta wrote its `-1.0` default over a real wall-clock deadline and the creature
  never came back; `-1.0` now means "unchanged", exactly as `hp` already did.
  `get_last_known_state()`/`get_last_known_hp()` keep the `has_*()` discriminators
  for the same reason.
- **A credential that is not guessable.** `player_id` is a BEARER token —
  `resolve_identity` hands the record to whoever presents it — and it carried
  `randi() & 0xFFFF`: 65 536 guesses, brute-forceable in one connect flood. It is
  now 128 bits from `Crypto.generate_random_bytes(16)`, and `player_path()`
  SANITIZES the id before interpolating it into a filesystem path
  (`save_player`/`load_player` refuse a non-canonical id rather than silently
  reading a different record).
- **An authority gap on the local player.** A listen host never binds its own
  player to a peer id, so a peer-map lookup answered "offline" and
  `resolve_identity`'s rule — "the record exists and is not online" — handed the
  host's inventory and position to whichever client claimed the id first.
  `is_online()` counts the local player, and the id is refused explicitly.
  The spoof test now covers this third case (it had live-victim and
  never-issued, i.e. exactly the two claims that were already safe).

Plus the operational half:

- **The save no longer serializes on the main thread.** `_save_everything()`
  collects the payload (the part that reads live slice state) and hands a deep
  copy to a `Thread` running `PersistenceSlice.write_job()`, which does JSON +
  FileAccess with no signals and no node access. Dirty chunks are cleared by key
  at COLLECTION time (re-marked if the write fails), which is what makes the
  deferred clear exact; shutdown paths (`WM_CLOSE_REQUEST`, the polled
  shutdown-request file, `_exit_tree`) call `_flush_save()` so they cannot outrun
  their own write.
- **`file_exists(shutdown_request_path)` ran every frame** for a file written at
  most once — it is polled on the autosave tick now. The interval also falls back
  to 300 s when the fabric value is 0 instead of silently disabling the autosave
  (a headless server has no other save hook), and `dirty_chunks` was dropped from
  the world record: it was written and never read back.
- **Boot no longer loads every record on disk.** The registry never evicts, so a
  long-lived server held every player who had ever joined; a record is pulled in
  lazily by the claim that needs it (`set_record_loader`). The autosave writes
  only the ONLINE players' records for the same reason.
- **The reconnect snapshot was sent twice** (`peer_connected`, then
  `player_joined`) — and the first was the useless one, built before the identity
  existed so it carried no own-record. `send_snapshot` now has exactly two call
  sites: the handshake join and an AOI re-scope.
- **The atomic write has a documented limit**: temp file + rename is atomic
  against the PROCESS dying, but nothing is `fsync`ed, so a machine power loss can
  still lose the record. Godot 4.7 exposes no fsync, so this is stated rather than
  fixed.

Verification for this pass: headless host / `--server` / `--client` boots green at
`Results: 6894/6894 passed (0 failed)` (was 6776; +17 registered cases), a
throwaway-copy lifecycle probe with the cadence shortened to 1 s showing threaded
autosaves landing and a shutdown request consumed on the tick with the save
complete before exit, a real server+client pair showing `reconnected player
'<128-bit id>'` (the lazy load path over the wire), and a `send_snapshot` call-site
count of 3 → 2 against `HEAD`.

### Phase 33 — review pass 2 (a restart that waits, a failure that hides, a client that gives up)

A second review of the same branch found five more defects. Two are the same shape
as before ("a bound that is really unbounded"), one is a trust boundary in the
wrong direction, and two are lifecycle gaps:

- **The shutdown poll was gated behind the autosave tick.** The
  `shutdown_requested` file was only checked once `autosaveIntervalSeconds` (300 s)
  had elapsed, so a restart request sat unread for up to five minutes. An
  orchestrator that writes the request and `SIGKILL`s after a short grace period
  killed the server *before* it saved — losing up to a full autosave interval on
  every restart. The poll now has its own fabric cadence,
  `shutdownPollSeconds` (default 5 s), resolved exactly like the autosave interval
  (a non-positive value falls back rather than meaning "never notice a restart"),
  and `PersistenceSlice.poll_due()` is the shared rule behind both. It is still
  not a per-frame `FileAccess.file_exists()` — the "don't stat every frame" fix
  stands, only the latency bound changed from *the autosave interval* to *the
  shutdown poll interval*.
- **A failed save was discovered one interval late, after the edits were already
  un-marked.** Dirty chunks are cleared at COLLECTION time (that is what makes the
  deferred clear exact), and the only reaper ran at the *start of the next*
  `_save_everything()`. So a write that failed was reported up to 300 s later,
  while its chunks read as clean: in that window the edits looked saved and were
  not, and a process that died inside it lost them with no error at all.
  `_poll_save_completion()` now reaps the worker as soon as `Thread.is_alive()` is
  false — one bool per frame, reusing the single `_finish_save()` result path, so
  the failure and the dirty-chunk re-mark land within a frame.
- **The handshake was fire-and-forget.** The client sent `join_intent` once on
  `connected_to_server`. Lose that packet (or the snapshot that answers it) and the
  client sat connected with no identity, no world, and no way to ask again — the
  snapshot-pending timer just gave up after 10 s. The client now re-presents the
  intent (`NetworkingSlice.request_handshake()`) every `HANDSHAKE_RETRY_SECS` up to
  `MAX_HANDSHAKE_RETRIES`, and each retry carries a fresh `seq` so the receiver's
  dedup passes it. The host half was also broken: `resolve_identity` returned early
  for an already-bound peer *without* emitting `player_joined`, so a retry would
  have produced no snapshot at all — it now re-answers idempotently.
- **A remote peer's HP was client-declared AND persisted.** The host kept the HP
  it received in the peer's own `player_moved` packet and folded it into the
  durable record, so `hp: 9999` on the wire became 9999 HP across a reconnect, a
  restart, and every later save — persistence as a cheat engine. Only the LOCAL
  player's host-simulated HP may be written (`PlayerRegistry.record_hp` refuses
  anything else, via the pure `hp_is_authoritative_locally()`), the remote fold
  call site is gone, and the now-consumerless `_last_known_hp` store was deleted
  rather than left as write-only state. The honest trade: a remote peer's HP is no
  longer durable, so a peer hard-killed mid-session resumes at its last
  *host-authored* HP instead of its last declared one.
- **Records and inventory nodes were never evicted.** The registry only ever grew:
  every player who had EVER connected kept a record plus a live `InventorySlice`
  node for the whole session. Now that the record is durable on disk and the
  registry holds a loader, `PlayerRegistry.evict_player()` releases both on
  disconnect (never the local player, never an online one, and only a node the
  registry itself parented — the local player's is the game's own `_inventory`).
  The reconnect claim re-loads from disk, so eviction costs one read and loses
  nothing. Consequences handled in the same pass: trade/market hold a raw node per
  party, and a freed node is not null, so both gained
  `clear_party_inventory()` (called on disconnect) and a `_inventory_for()` that
  treats a freed binding as "no inventory"; `game_root._peer_aoi_regions` is
  cleared for the peer id too, so a reused ENet id cannot have its first re-scope
  snapshot suppressed.

Verification for this pass: headless host / `--server` / `--client` boots green at
`Results: 6940/6940 passed (0 failed)` (was 6894; 7 registered cases replaced 1),
a throwaway-copy `--server` probe that wrote `user://shutdown_requested` mid-run
exiting **5.3 s later** with `[Server] shutdown requested — saving before quit`
followed by a completed world save (the old code needed up to 300 s, so the same
probe would still have been running), and a real server+client pair whose client
was `SIGKILL`ed mid-session: the disconnect wrote the client's record, left no
`SCRIPT ERROR` / `previously freed` / `Invalid` line in the server log, and a later
`shutdown_requested` saved `world.json` plus both player records.

---

## Phase 34 — Per-player repair and research ✅ Done

**Goal:** Finish the per-player authority Phase 33 started. Two player-scoped
actions still resolve against the host's own state: `CraftingSlice.repair()`
reads `inventory_slice` directly, and `TechnologySlice` keeps ONE
process-wide status dictionary whose material cost also comes off
`inventory_slice`. So on a host a research unlocks the technology for every
player at once and spends the host's materials — a peer can hand the whole
server a free technology tree — and neither repair nor research has any wire
path at all, so a client's attempt dies on the client. Phase 34 keys both on
the server-issued `player_id`, forwards them as intents, and pushes the peer
its own record slice back when the host resolves one on its behalf.

**Newel dependency:** None. The technology tree, the repair specs and the player
identity all already exist in the fabric; this phase changes who *owns* the
runtime state, not what the fabric describes, so no `pnpm validate` /
`generate` / `check-drift` step is involved.

**Deliverables:**
- `TechnologySlice` becomes per-player: `_status` and `_research_end_at` keyed
  on `player_id`, `inventory_for(player_id)` from the PlayerRegistry, plus
  `is_authoritative`. Every API takes `player_id := ""`, where "" resolves to
  this machine's local player (`begin_research`, `complete_research`,
  `is_unlocked`, `is_recipe_unlocked`, `get_status`, `get_statuses`,
  `apply_statuses`).
- `CraftingSlice` repair becomes per-player: `repair(item_id, player_id)`,
  `can_repair(item_id, spec, player_id)` and `_resolve_repair(...)` — with
  `_condition_tiers_to_restore` / `_refund` — resolve against
  `inventory_for(player_id)` instead of a fixed `inventory_slice`.
- The craft technology gate asks about the crafter:
  `_check_tech_gate(recipe_id, player_id)`.
- Repair and research travel as intents: new `repair_intent(item_id,
  player_id)` / `research_intent(tech_id, player_id)` bus signals, a
  non-authoritative slice forwarding its own request signal as an intent (the
  shape `craft_intent` set), and `networking_slice` c2h arms that require the
  handshake and re-emit with the identity bound to the CONNECTION.
- The host hands the peer its own record slice back: a new host→client
  `own_state_synced` payload (inventory contents + per-instance durability +
  technology) sent by `networking_slice.send_own_state(peer_id, data)` to that
  peer alone, driven by `game_root._sync_peer_own_state` after a craft, repair
  or research the host resolved for a remote peer.
- Persist per player: `record_technology(pid, get_statuses(pid))` when a
  research resolves and on save, and the record's technology applied to the
  player's OWN bucket on join.
- Results and events name their player: `technology_unlocked(tech_id,
  player_id)`, plus a `player_id` on every craft / repair / research result.
- Seven new test cases (per-player research + craft gate, client research
  forwarding, per-player repair, client repair forwarding, intent identity
  binding, own-state push scoping, client research never auto-completes).

**Acceptance criteria:** *(met — see the verification notes below)*
- [x] One player's research consumes only THEIR materials and moves only THEIR
  statuses; another player's tree stays locked, and a prerequisite is per-player.
  (`technology: tree and materials are per-player`: alice researching moves her
  stack and her status, bob's `Ferrite` stays 4 and his status `locked`; bob's
  `TechMasterForge` answers `prerequisite_locked` until HE holds
  `TechBasicSmithing`, and two players then hold the same technology
  independently.)
- [x] A remote peer's repair consumes the repair materials from and restores the
  durability of ITS OWN inventory; the host's is untouched.
  (`repair: resolves against the repairer's inventory`: alice's pick goes
  `worn` → `pristine` and her `FerriteIngot` 3 → 2 while bob's stays worn at the
  same durability with all 3 ingots.)
- [x] A client never resolves a repair or research locally: it forwards an
  intent, and its own state changes only through the host's `own_state_synced`.
  (`technology: client forwards research intent`, `repair: client forwards
  intent, mutates nothing` and `technology: client does not resolve research`:
  one intent, an empty `player_id`, nothing consumed or restored locally — and
  the slice's own auto-complete tick is authority-gated, so a status restored
  mid-research never completes on the client's clock.)
- [x] An un-handshaked peer's repair / research intent is dropped, and a
  `player_id` inside the payload is ignored — the identity comes from the
  connection. (`net: player intents bind connection identity`: no signal before
  the handshake, then both intents arrive carrying `player_7_1_deadbeef`, the id
  bound to the connection, not the `player_victim` the payload named.)
- [x] `technology_unlocked` names the player whose tree moved, and the listen
  host's own UI does not report a remote peer's outcome. (`technology_unlocked`
  now carries `player_id`, and `UiSlice._belongs_to_local_player` gates the
  craft / repair / research feedback labels on it — including the repair
  feedback that `_on_craft_resolved` clears.)
- [x] Headless suite green on the host, `--server` and `--client` boots, with no
  `SCRIPT ERROR` / `Parse Error` in any of them. (`Results: 6994/6994 passed
  (0 failed)` + `All tests passed ✓` on all three, and
  `[Server] listening on port 7777, max_clients 64` on the `--server` boot.)
- [x] A real server+client pair still handshakes, joins, reconnects, and
  receives its own record. (`[Server] reconnected player
  'player_1790211585_1_c1faa9ada576fae72382b700cd8555b8' as peer_693354570`
  with the client logging `[Client] identity assigned: …`.)

**Tasks / tests:**
- `technology: tree and materials are per-player`
- `technology: client forwards research intent`
- `repair: resolves against the repairer's inventory`
- `repair: client forwards intent, mutates nothing`
- `net: player intents bind connection identity`
- `net: own-state push is peer-scoped`
- `technology: client does not resolve research`

**Verification (headless, on this machine):**
- Suite: `6940/6940` before the phase → `6994/6994` after (+54 assertions from
  the 7 new registered cases), green on the listen host, `--server`, and
  `--client` boots.
- A real server+client pair over loopback: the client presents its cached id and
  the server answers `[Server] reconnected player
  'player_1790211585_1_c1faa9ada576fae72382b700cd8555b8' as peer_693354570`,
  with the client logging `[Client] identity assigned: …` — the per-player
  technology bucket is applied on the join path with no error.

**Implementation notes:**
- **"" means "the local player", not "no player".** Every id-taking call
  defaults to `""` and `resolve_player()` maps it to this machine's local player
  (the registry's `local_player_id`), so every pre-existing call site — the UI
  projections, the DEBUG boot demo, the isolated unit tests — keeps working
  untouched, and a client (no registry identity) or an isolated slice collapses
  to the single bucket that IS its own player.
- **Research deadlines are wall-clock Unix seconds now.** They were
  `Time.get_ticks_msec() + duration`, i.e. process uptime — the same value shape
  Phase 33 removed from creature respawns and Phase 24/31 already avoid. Nothing
  persists the deadline today (a restored "researching" status restarts its
  timer), but a deadline that only means something inside the process that set
  it is exactly the value that breaks the moment anything does.
- **The host pushes the peer's own state, because a client has no other way to
  learn it.** A client's inventory and tree only ever arrive in a snapshot, so a
  repair or research the host resolved on its behalf used to leave the peer
  showing stale contents until the next AOI re-scope or reconnect. The push is
  scoped to that peer — an inventory is private, so unlike an AOI world delta it
  cannot be broadcast. Craft got the same fix (it had the identical gap, and
  `_on_craft_resolved` was a `pass`), which is why craft results carry a
  `player_id` too. Position and HP are deliberately NOT in the payload: they are
  host-simulated and ride the normal player-state path, and re-sending a stored
  position would teleport the peer back to it.
- **Do not connect a listener to the signal the listener re-emits.**
  `own_state_synced` is emitted by the inbound route and read by `game_root`, and
  the outbound direction is a direct `send_own_state()` call — a networking
  listener that re-emitted the signal made a client loop on its own packet until
  the stack overflowed (caught by the push test, which saw 2041 arrivals instead
  of one).
- **Gate the whole lifecycle on `is_authoritative`.** A client neither resolves
  research nor repairs: it forwards the intent and caches nothing. That includes
  the slice's AUTOMATIC paths, not just its request handlers: `TechnologySlice`
  re-arms an auto-complete deadline for any status restored mid-research (so a
  real slice never stays stuck in `researching`), so an ungated `_tick_research`
  had the client unlock the technology on its OWN clock and emit
  `technology_unlocked` for a status the host never granted. The tick now returns
  early when not authoritative; repair has no tick, so its guard sits on the
  request / intent handlers.
- **The identity is bound to the connection, never read from the payload.**
  `repair_intent` / `research_intent` are dropped from an un-handshaked peer and
  re-emitted with `get_player_id(sender)`; a `player_id` in the packet body is
  ignored, exactly as `craft_intent` already did.
- **Two players can hold the same technology independently** — the status
  dictionary is a map of maps, so alice's `unlocked` and bob's `researching` for
  the same tech coexist, and each pays the cost from their own inventory.

**Known simplifications (deferred):**
- **The `own_state_synced` push is not acknowledged.** It is a plain reliable
  packet with no resend: a peer that loses it keeps the stale view until the next
  snapshot. The suite proves the routing and the payload, not the delivery.
- **No end-to-end socket exercise of the new intents.** The client's repair and
  research requests come from UI clicks, and a headless client has no UI, so the
  wire path is proven at the routing level (c2h identity binding, h2c delivery of
  `own_state_synced`) plus a real socket pair for the handshake, join and
  reconnect — not by driving a real client's research over the network.
- **Skill tiers and station proximity are still per-process, not per-player.**
  `CraftingSlice._skill_tiers` is one table for the machine, and
  `station_near_player` answers about the local player's position, so a remote
  peer's repair/craft is gated by the HOST's skills and the LOCAL player's
  distance to a station. Moving skill progression and per-player position into
  the record is the follow-up.
- **Other players' appearances are still not replicated**, and repair/technology
  research now share the same plumbing — that gap is unchanged from Phase 33.

---

## Phase 35 — Creature taming ✅ Done

**Goal:** Wire the `tame` capability the fabric has carried on creature entities
since Phase 5 — GraywolfPack's "tame a surviving pup after defeating the alpha
wolf" and GlimmerFox's "feed the fox to harvest shed fur without harming it" — so
a player can win a companion and the `wolfBondHolder` flag the Ranger profession
gate reads, and so the fabricated `tame` behavior stops being prose.

**Newel dependency:** None. Reuses the existing `json` field type (already
emitted by `generator-godot`) through a new `tameData()` helper in
`fabric/world/creatures/shared.js`, exactly as `dropsData()` and `techData()`
already do; no generator change. The fabric itself gained the structured `tame`
field on GraywolfPack and GlimmerFox, and `pnpm validate`, `pnpm generate` and
`pnpm check-drift` were all run.

**Deliverables:**
- `fabric/world/creatures/shared.js` — `tameData()`: result kind
  (`companion` | `yield`), `requiresUnarmed`, `requiresSkill {skill, tier}`,
  `requiresAnyItem` (alternatives), `requiresDefeated` (the alpha-down gate),
  `grantsFlag`, `yields`, `cooldownSeconds`, `suppressRespawn`.
- `fabric/world/creatures/temperate.js` / `twilight.js` — the `tame` field on
  GraywolfPack (companion, bare hands, Unarmed:journeyman, alpha down, grants
  `wolfBondHolder`, no respawn once tamed) and GlimmerFox (yield, bare hands,
  Alchemy:apprentice, rations or raw meat, sheds `glimmer_fur_tuft`, 600 s
  cooldown).
- `src/creature/taming_slice.gd` — fabric-driven `can_tame()` / `tame()`:
  requirement validation, the offering consumed from the tamer's own inventory,
  the granted flag, the companion binding, wall-clock cooldown, record sync.
- `src/core/bus.gd` — `tame_requested` / `tame_intent` / `tame_resolved` /
  `creature_tamed`.
- `src/creature/creature_slice.gd` — the instance's `tamed_by` binding plus
  `mark_tamed` / `is_tamed` / `get_tamed_by` / `companions_of` /
  `get_instance_position` / `has_defeated_species`; `nearest_creature()` skips a
  companion; the respawn tick honours `suppressRespawn`.
- `src/creature/creature_ai.gd` — a `tamed` state: a companion never aggros,
  never patrols, follows its owner, and is exempt from pack escalation.
- `src/persistence/player_registry.gd` — `flags` and `companions` on the player
  record (a pre-Phase-35 payload restores to empty defaults).
- `src/core/game_root.gd` — the slice wired and authority-gated; the flags and
  companion bindings ride the join snapshot and the Phase 34 `own_state_synced`
  push; restore on join, boot and autosave.
- `src/networking/networking_slice.gd` — the `tame_intent` c2h route, with the
  identity bound to the connection and the payload's `player_id` ignored.
- `src/player/player_slice.gd` — `G` tames the nearest creature; the controls
  panel lists it.
- `src/inventory/inventory_slice.gd` — `glimmer_fur_tuft` weight, alongside the
  other raw creature drops.
- `src/tests/test_suite.gd` — 15 taming tests under a `Phase 35` banner, including
  the atomic-refusal guard on the unidentified-tamer path.

**Acceptance criteria:**
- [x] The interaction is fabricated, not hardcoded: `tame_data()` is read for
  every creature and a creature with no `tame` field is refused as
  `not_tameable`, with its own test asserting the field-by-field contents (the
  wolf's flag/alpha/skill gates, the fox's offerings, cooldown and yield).
- [x] The wolf requires the alpha down before a pup can be tamed — "one instance
  of that species is dead" is the runtime's reading of the pack rule
  (`has_defeated_species`), and the test proves the gate is satisfied rather than
  skipped by asserting the SKILL reason that answers next.
- [x] The wolf grants `wolfBondHolder`, binds the instance as a companion, and
  the companion is not offered as an attack target
  (`nearest_creature()` skips it) and follows its owner instead of patrolling.
- [x] The fox yields `glimmer_fur_tuft` without dying, consumes the offering, and
  is refused for 600 s afterwards — the cooldown expired by hand in the test, so
  a second feed succeeds.
- [x] Requirements fail closed and name themselves: `armed`, `skill_locked:Unarmed:journeyman`
  (novice and apprentice both refused), `missing_offer`, `too_far`,
  `already_tamed`, `target_dead`, `on_cooldown`.
- [x] A tamed companion does not respawn (fabric `suppressRespawn`), while a wild
  creature with the same expired deadline does.
- [x] The flag and the companion binding survive the record round-trip through
  the player record, and a pre-Phase-35 payload restores to empty state.
- [x] Taming is per-player: one player's tame sets that player's flag, binds that
  player's companion and spends that player's offerings — a second player cannot
  feed the same fox on the first player's rations.
- [x] A client resolves nothing and forwards `tame_intent` with no identity.
- [x] Headless suite green on both boot paths — `Results: 7126/7126 passed
  (0 failed)` → `All tests passed ✓` with `[Server] listening on port 7777,
  max_clients 64` on the server boot (6994 before this phase: 132 new
  assertions).
- [x] A refused tame is atomic: an unidentified tamer's refusal leaves the wolf's
  `wolfBondHolder` flag unset and its offering unspent, asserted directly.

**Implementation notes:**
- **An empty owner is not a thing.** `tamed_by` is the instance's owner id and
  `""` means wild, so a companion needs an identified player. A tame resolved in
  the `""` bucket (a client, or an isolated slice with no registry) cannot bind a
  companion and is refused as `already_tamed` rather than silently writing a
  wild-looking owner. Every taming test wires a PlayerRegistry for this reason —
  a test that does not gets a refusal, not a binding. The refusal is ATOMIC: the
  offering is consumed first (for the race) but handed back if the binding then
  refuses, and the flag is granted only once the binding is taken, so a refused
  tame neither spends a ration nor moves progression. The one rig without a
  registry asserts exactly that.
- **The alpha-down gate is defined against what the runtime models.** A pack is N
  instances of one creature id; there is no separate alpha or pup instance, so
  "the alpha is dead" is "one instance of that species is dead", which is also
  what the pack's own `flee` rule implies. Stated in the slice docstring instead
  of left implicit.
- **Reason precedence is deliberate** (`can_tame`, documented in place):
  not-a-tame → `already_tamed` → `target_dead` → `too_far` → `alpha_alive` →
  `armed` → `skill_locked` → `missing_offer` → `inventory_full` → `on_cooldown`.
  A distance failure answers before a state failure, because a player who cannot
  reach the creature cannot act on its state either. The tests assert the
  precedence, so changing it is a deliberate edit with a failing test.
- **The shed yield must fit before the offering is consumed** (`can_add_items`),
  or a full pack eats the player's rations and hands back nothing.
- **Wall-clock deadlines**, like the market, trees, respawns and research already
  are: a process-uptime cooldown means nothing in a new process.
- **A companion is out of the pack.** A tamed wolf must not be dragged back into
  its former pack's alert/flee by the Phase 30 propagation, and a packed
  companion would otherwise fight its own owner — `_escalate_neighbor` refuses a
  companion.
- **The bare-hands rule reads the character slice for the LOCAL player only.** A
  remote peer's equipment is not replicated and the intent carries no equipment
  claim, so the rule cannot be evaluated for a peer and is reported as
  satisfied.

**Known simplifications (deferred):**
- Skill tiers remain the per-process table the crafting gates use
  (`CraftingSlice._skill_tiers`), not per-player progression — the same gap
  Phase 34 recorded. **(closed in Phase 36: the tiers moved onto the player
  record.)**
- The `tamed_by` binding is not replicated: a peer learns its own companions from
  its record (join snapshot / `own_state_synced`), and a peer's companion appears
  as a wild creature in its AOI stream. The follow AI only runs on the host.
- No end-to-end socket exercise of `tame_intent` — a headless client has no UI, so
  the path is proven at the routing level plus the intent forward, not by driving
  a real client's tame over the network (Phase 34's gap, unchanged).
- Companion movement is still direct kinematic stepping, not a nav-mesh — the
  NavigationAgent3D item below is unchanged.

---

## Phase 36 — Review pass: the network trust boundary, gated boots, per-player progression ✅ Done

**Goal:** close the ten findings of the Phase 36 review pass over Phases 33–35. Two
themes: what the host is willing to believe from a client (identity claims, world
edits, packet volume), and what the host tells a client (player ids that are also
bearer tokens).

**Newel dependency:** None. No fabric field changed — `pnpm check-drift` still
reports 543 files matching the manifest.

**Deliverables:**
- `src/networking/networking_slice.gd` — the inbound trust boundary: acting
  identity bound to the connection (`_actor_id`, `_refuse_unhandshaked`), world-edit
  reach validation (`_within_reach`, `_chop_is_in_reach`, `MAX_EDIT_REACH`), the
  packet size cap (`MAX_CLIENT_PACKET_BYTES`), the per-peer token bucket
  (`_allow_packet`, `RATE_BUCKET_CAPACITY`, `RATE_BUCKET_REFILL_PER_SEC`), and the
  outbound identity redaction (`redact_for_client`, `adopt_own_handle`,
  `_map_identities`, `IDENTIFIED_STATE_KEYS`, `claimed_handle`).
- `src/persistence/player_registry.gd` — `public_handle`, `player_id_for_handle`,
  `looks_like_player_id`, `resolve_named_party`, and the per-player skill tiers
  (`get_skill_tier` / `record_skill` / `record_skills`, carried by the record).
- `src/crafting/crafting_slice.gd` — `get_skill_for` / `set_skill_for` and
  `_check_skill_guards(spec, player_id)`.
- `src/creature/creature_ai.gd` — the `player_targets` provider and per-target
  ticking (`_player_targets`, `_nearest_target`, `_tick_instance(..., target_id)`).
- `src/creature/taming_slice.gd` — the bare-hands claim (`_unarmed_claims`,
  `is_unarmed` per player) and the claim-carrying intent handler.
- `src/core/bus.gd` — `tame_intent(instance_id, player_id, unarmed)`.
- `src/core/game_root.gd` — `should_run_tests` (the boot gate), the `_player_targets`
  provider, the redacted snapshot (`_build_snapshot`), and the new wiring
  (`_networking.tree_slice`, `_networking.player_registry`).
- `src/tests/test_suite.gd` — 17 new/rewritten tests.

**Acceptance criteria:**
- [x] A client cannot act as another player: every acting party (market
  seller/buyer, proposal author/voter, trade propose/accept/reject, craft, repair,
  research, tame) is the player id bound to the sending connection, and a payload's
  identity half is ignored. Asserted for all of them, plus that an un-handshaked
  peer cannot act at all.
- [x] World edits need a bound identity AND a target within `MAX_EDIT_REACH` (60 m)
  of the position the host last recorded for that peer; a peer with no recorded
  position is refused, and a tree chop resolves the tree's own position through the
  wired TreeSlice.
- [x] A client packet is capped at `MAX_CLIENT_PACKET_BYTES` before parsing, and each
  peer draws from its own token bucket: a burst is capped at `RATE_BUCKET_CAPACITY`,
  the bucket refills at the sustained rate, and a reconnect starts full.
- [x] No player id is broadcast: market, trade and governance state — values AND the
  keys of the offers/accepted maps — travel as public handles, in the delta
  broadcasts and in the world snapshot, and a leaked handle claims nothing while a
  leaked id is honoured as that player's reconnect (the takeover, demonstrated both
  ways).
- [x] The automated suite runs on boot only for a debug build or `--run-tests`; a
  release boot runs no suite.
- [x] Creature AI targets the nearest of every player the host can place on the
  machine, not only the host's own body, and a remote target is chased rather than
  handed to the battle slice. **(superseded in Phase 37: the round is now routed by
  target id, and a player target takes the forwarded-damage path — see Phase 37.)**
- [x] Skill tiers are per-player and durable: one player's tier neither unlocks nor
  gates another's craft, repair or tame, and a tier round-trips through the record.
- [x] A remote peer's bare hands are a claim that rides its tame intent; an
  unclaimed peer fails the fabric's `requiresUnarmed` rule closed.
- [x] Headless suite green on both boot paths — `Results: 7244/7244 passed
  (0 failed)` → `All tests passed ✓` with `[Server] listening on port 7777,
  max_clients 64` on the server boot (7165 at the start of this pass: 79 new
  assertions).
- [x] Every fix is RED-proven: with the fix reverted (source only, tests kept) the
  new assertion fails — quoted in each commit body.

**Implementation notes:**
- **The acting party is the connection, and only a trade invite may name anyone.**
  `_peer_party` used to pass any string except the literal `"player"` through
  verbatim, which is what made a spoofed accept/spoofed sale/spoofed vote possible.
  The counterparty on a trade invite is the one identity a payload may legitimately
  name, because it grants nothing: it is answered by that player's own accept, which
  is bound to its own connection. It is resolved against the registry's ONLINE set,
  so an invite to an offline or invented name is dropped instead of parked.
- **Reach is measured from the host's evidence, not the client's claim.** The peer's
  position comes from the host's own record of its movement packets;
  `has_last_known_state()` is what separates "never reported" from "at the origin",
  so a peer with no position on record is refused rather than measured from an
  assumed spawn.
- **The channel is policed, not just its packet types.** Phase 19's dedup rejects a
  REPLAYED seq and never a fresh flood, so the token bucket is what bounds a peer's
  rate. Both bucket state and the size cap live before the payload is parsed.
- **Handles are derived, not minted**, and that is the whole point: a minted handle
  would need a record (absent for an offline seller named in a persisted listing), a
  re-mint after a save/load, and a place to live. `sha256(player_id)` truncated needs
  none of that, is stable across a restart, and cannot be turned back into the token.
  The id-SHAPE predicate is what finds the ids inside a payload, so an evicted
  player's id is still recognised as one.
- **The client is shown its own handle back as `"player"`.** Single-player and
  client-side code has always named the local player `"player"`; the adoption step
  keeps that true without the client ever holding another player's identity — and
  the demo's scaffolding literals (`"merchant"`) are not id-shaped, so they pass
  through every redaction untouched.
- **Skill tiers moved onto the record, with the process table kept for one narrow
  case:** this machine's own player when the record holds no tier yet (the
  pre-identity boot, the DEBUG demo's `set_skill`, and isolated tests). A peer has no
  such fallback, so a missing tier fails closed at the seed tier instead of borrowing
  this machine's numbers.
- **The bare-hands claim is deliberately short-lived.** It is installed for exactly
  the resolution its intent triggered and dropped immediately after, so a stale claim
  cannot silently arm or disarm a later attempt. The residual trust is stated in the
  code: a client that lies about its hands is believed, exactly as it is believed
  about its movement.
- **A remote target is chased but not struck.** Damage to a peer belongs to that
  peer's own client — the machine that simulates its health — and the host has no
  simulation of a peer's HP to hit or persist (`PlayerRegistry.record_hp` already
  refuses a client-declared value). Handing a player id to the battle slice would run
  it through the CREATURE path: tracked hit points, then a `creature_died` on
  somebody's id. Peer damage over the wire is deferred (below). **(closed in Phase 37:
  the round is routed by target id and the player path forwards damage with the target,
  which the host delivers to that peer's client. The danger named here was real — the
  RED run of the old policy produced 11 `creature_died` emissions on a peer's id.)**

**Known simplifications (deferred):**
- **Peer damage over the wire.** A creature aggros and chases a remote peer, but no
  combat round is opened against it (see above). Closing this needs a host → client
  damage event and per-peer HP ownership on the peer's own client. **(closed in Phase 37:
  the round is routed by target id, `player_damaged` carries the target, and the host
  sends the hit to that peer's own client — which applies it. A peer's HP is still owned
  by its own client, so the host's view of it remains that client's word.)**
- **Peer equipment is not replicated.** The bare-hands rule is evaluated against the
  peer's own claim. Verifying it means replicating worn gear, which is the feature
  the claim stands in for.
- **Trade's broker-fee tier is still slice-local** (`TradeSlice._skill_tiers`): it
  affects only the LOCAL player's own fee, and is read from the local table. Moving
  it onto the record is the remaining half of the per-player skill change.
- **A client is not sent its own skill tiers.** It never resolves a craft or a
  tame — it forwards an intent — so the tiers it displays (a gated recipe row) are
  the local table's. The host is the authority for every gate.
- **Still no end-to-end socket exercise** of the new guards: they are proven at the
  routing level (`_route_c2h`, `_route_h2c`, `redact_for_client`) rather than by
  driving two real clients through ENet (Phase 34/35's gap, unchanged).
- **The taming mirrors are still never evicted on disconnect** and `tamed_by` is
  still not replicated — both carried over from Phase 35, unchanged. **(closed in
  Phase 37: `TamingSlice.forget_player_id` releases the flags, companion and cooldown
  mirrors with the record that was just written; `tamed_by` replication is still
  deferred.)**

---

## Phase 37 — Review pass: owner-scoped syncs, durable cooldowns, bounded memory, routed rounds ✅ Done

**Goal:** close the seven findings of the review pass over Phases 33–36. Three themes:
data that was addressed to nobody (inventory syncs, combat rounds), state that only lived
in memory (cooldowns, the taming mirrors, half-reassembled snapshots), and one predicate
that answered a question it should not (a raw player id in a counterparty name).

**Newel dependency:** None. No fabric field changed — `pnpm validate` is clean and
`pnpm check-drift` still reports 543 file(s) matching the manifest.

**Deliverables:**
- `src/core/bus.gd` — `inventory_synced(owner_id, contents, durabilities)` and
  `player_damaged(damage, attacker_id, target_id)`.
- `src/inventory/inventory_slice.gd` — `owner_id`, `LOCAL_OWNER_LITERALS`,
  `is_owned_by()`, and the owner filter in `_on_inventory_synced`.
- `src/persistence/player_registry.gd` — `cooldowns` on the player record
  (`record_cooldowns` / `get_cooldowns` / static `live_cooldowns`), the owner stamp in
  `get_inventory`, and `resolve_named_party()` restricted to public handles.
- `src/creature/taming_slice.gd` — cooldowns persisted and restored with the record,
  and `forget_player_id()` releasing the three per-player mirrors.
- `src/networking/networking_slice.gd` — peer-scoped inventory sync
  (`_peer_for_inventory_owner`), `send_player_damaged` plus its inbound route, and the
  snapshot buffer eviction in `forget_player_id` / `disconnect_all`. **(extended in Phase
  38: both of those sites are on the host's half of the wire, so the CLIENT's path —
  `_on_server_disconnected` — was added.)**
- `src/creature/creature_slice.gd` — `instances_view()` (cached, read-only, live
  records), `_view_stale` / `_invalidate_view`, and `instance_id` on the instance record.
- `src/creature/creature_ai.gd` — the per-frame loop reads the cached view and emits a
  round for whatever target the creature engaged.
- `src/battle/battle_slice.gd` — static `is_player_target()`, the player path keyed on
  the defender SHAPE, and creature hit points no longer initialised for a player.
- `src/player/player_slice.gd` — `_on_player_damaged(..., target_id)` with
  `_is_local_target()`.
- `src/core/game_root.gd` — the merchant inventory's owner stamp, `_taming.forget_player_id`
  on disconnect, and `_on_player_damaged` forwarding a peer's damage to its own client.
- `src/tests/test_suite.gd` — 9 new tests (135 new assertions) and 3 rewritten ones.

**Acceptance criteria:**
- [x] An inventory sync is applied by the OWNER's inventory only: a peer's sync leaves
  the local pack and the demo merchant's stock untouched, and the local bucket answers
  under either of its literals. On the wire the host sends a sync to the owner's peer
  alone, carries no player id, and fails closed (no broadcast fallback) for the local
  bucket, an unresolvable owner, or an unwired registry.
- [x] A tame cooldown survives a restart: it is written on the player record, pruned of
  expired deadlines on the way in and out, and a restored slice still refuses the feed
  with `on_cooldown`.
- [x] An incomplete snapshot's reassembly entry is evicted with the connection that was
  carrying it, while a snapshot that completes still empties its own entry.
- [x] The per-player taming mirrors (flags, companion bindings, cooldowns) are released
  on disconnect — and refused for the local player — with the durable record re-applied
  by the reconnect path.
- [x] Every combat round is routed by the target the creature engaged: a remote peer's
  player id reaches the battle slice down the PLAYER path (no tracked hit points, no
  `creature_died` on a player id — asserted over 20 rounds), and the host forwards the
  hit to that peer's own client, which applies it to the local body.
- [x] `get_all_instances()` still hands out copies, `instances_view()` returns the
  cached live records (identical array between calls, no rebuild until membership
  changes, rebuilt after a despawn), and the AI's per-frame loop uses it.
- [x] A named counterparty must be a public handle: a raw player id — online, the local
  player's own, or unknown — resolves to nothing, so the resolver is no longer an
  online-status oracle. The invite path and the resolver are both asserted.
- [x] Headless suite green on both boot paths — `Results: 7379/7379 passed  (0 failed)`
  → `All tests passed ✓` with `[Server] listening on port 7777, max_clients 64` on the
  server boot (7244 at the start of this pass: 135 new assertions).
- [x] Every fix is RED-proven: with the pre-fix policy restored (source only, tests
  kept) the new assertions fail — quoted in the commit body.

**Implementation notes:**
- **An inventory sync now names its owner, and the local bucket has two literals.** One
  process holds several inventories at once (the local player's, one per connected peer
  created by the registry, the demo merchant's), and the signal is bus-wide, so an
  unfiltered handler replaced every one of them. `owner_id` is a FILTER, never an
  authority — the host still binds the acting identity to the connection
  (`_actor_id`) — and `""` / `"player"` both name this machine's own player (the Phase 34
  `resolve_player` convention and `TradeSlice.PARTY_PLAYER`). The wire packet carries no
  owner at all: it is delivered to the owner's peer, so the only inventory it can be is
  that client's own, and a player id stays off the wire (Phase 36's rule).
- **A cooldown is a rule about the PLAYER, not about the process.** Kept in memory it
  was cleared by a restart, which is exactly the loop the fabric's `cooldownSeconds`
  exists to stop — one reconnect away. It now rides the record, pruned to live deadlines
  by one shared pure rule (`PlayerRegistry.live_cooldowns`), so the mirror and the record
  cannot disagree about what is still in force.
- **A half-reassembled snapshot is transport state.** Chunks are indexed by
  `snapshot_id` and a lost chunk means the entry is never completed, so it lived for the
  whole session — one leak per lost chunk, on a connection that may be long gone.
  Reassembly belongs to the connection that carried it.
- **The taming mirrors are the registry's rule, applied one slice over.** The record
  written at disconnect is the durable copy (the same argument
  `PlayerRegistry.evict_player` already makes), so the mirrors are released with it and
  re-applied by `apply_record` on the next claim. The local player is refused, for the
  same reason `evict_player` refuses it: it is online by definition.
- **Rounds are routed by target, and a player target never reaches the creature path.**
  `combat_round_requested` now carries whoever the creature engaged, and
  `BattleSlice.is_player_target()` (the literal `"player"`, or an id-shaped player id)
  decides which path the round takes. The creature path is the dangerous one — it tracks
  hit points in `_hp_state` and emits `creature_died` when they run out, which on a
  player id is a corpse on somebody's identity (the RED run produced 11 of them). Those
  hit points are now initialised only for a creature defender: nothing here holds a
  number it cannot verify.
- **The hit itself is applied where the body is simulated.** The host owns the
  authoritative simulation and so knows a creature struck a peer, but it still holds no
  verifiable HP for that peer — `PlayerRegistry.record_hp` refuses a client-declared
  value for exactly that reason — so it sends the round to that peer's own client rather
  than applying or persisting it. `player_damaged` gained the target for that routing,
  and the peer-scoped packet arrives as the local body's id, the only one it can be.
  The residual trust is stated in place: the peer's HP is still its own client's to
  keep, so a client that lies about its health is believed about it, exactly as it is
  about its movement.
- **The cached view is read-only by contract, and that is the whole design.** The
  records in `instances_view()` are the slice's own, so it is cheap (no allocation per
  creature per frame) and live (a write through it writes the world); only MEMBERSHIP
  changes invalidate it, since a moved creature needs no rebuild. `get_all_instances()`
  keeps its copy semantics for the UI and for tests, and the two are asserted apart.
- **Handles only, because the alternative was an oracle.** `resolve_named_party`
  answering a raw id told a client whether that exact id was connected, and an id is a
  bearer token: presenting one on join claims the record. Nothing legitimate still sends
  one — a client learns ids nowhere (`redact_for_client`) — so the branch was pure
  probing surface.
- **A suite leak was fixed on the way past.** `_test_taming_record_round_trip` left two
  TamingSlices alive on the shared bus, so a later test's tame was resolved — and
  refused — by an unwired leftover first. Every test slice is torn down immediately, as
  the suite's own docstring requires.

**Known simplifications (deferred):**
- **A peer's HP is still client-owned.** The host now delivers a creature's hit to the
  peer's own client, but the value that client keeps is still its own word: the host
  holds no simulation of a peer to check it against. Making peer health authoritative
  means simulating peer bodies (or at least their HP) on the host. **(closed in Phase 38:
  the host simulates a peer's HP itself — `PlayerRegistry.record_simulated_hp`, seeded by
  the pure `simulated_hp_after_hit` — and persists it on the peer's record, so the
  forwarded `player_damaged` is a display update rather than the only copy. What is still
  deferred is what happens to a peer at zero: no death consequence is resolved host-side.)**
- **Peer equipment is still not replicated.** The bare-hands rule is evaluated against
  the peer's own claim (unchanged from Phase 36).
- **`tamed_by` is still not replicated**, so a peer's companion appears as a wild
  creature in its AOI stream while the follow AI runs only on the host (unchanged from
  Phase 35).
- **Still no end-to-end socket exercise** of these paths: every fix is proven at the
  routing level (`_route_c2h` / `_route_h2c`, the bus, `_pending`) rather than by driving
  two real clients through ENet (Phase 34/35/36's gap, unchanged).
- **A combat round's damage event is not sequenced against movement.** The peer applies
  whatever arrives; a reordered pair could apply a hit after the peer's own position
  update reported a death. Phase 19's dedup covers duplicates and reordering per type,
  not ordering BETWEEN types.
- **The registry-held peer inventories are still only released on disconnect.** They are
  evicted with the player (`evict_player`), but nothing bounds the inventory of a peer
  whose disconnect was never delivered (a hard kill) beyond the autosave interval.

---

## Phase 38 — Review pass: host-simulated peer health, one key list, the missing clear, an in-place prune ✅ Done

**Goal:** close the five findings of the review pass over Phases 33–38. Two of them are the
same hole seen from both ends — the host resolved a combat round against a peer and then
kept no number for it, so a client's health was its own client's word — and three are
single-list/single-site bugs: a hardcoded key set beside an unused constant, a clear that
only ever ran on the host's side of the wire, and a prune that only ever ran on the copy
that was being saved.

**Newel dependency:** None. No fabric field changed — `pnpm validate` is clean and
`pnpm check-drift` still reports 543 file(s) matching the manifest.

**Deliverables:**
- `src/persistence/player_registry.gd` — `get_hp()`, the pure static
  `simulated_hp_after_hit()`, and `record_simulated_hp()`: the HOST's own resolution of a
  remote peer's health, the door `record_hp` deliberately is not. `record_hp` keeps
  refusing a remote id, so the declared value still has no path into a record.
- `src/core/game_root.gd` — `_on_player_damaged` applies the hit to the host's own record
  for the peer BEFORE forwarding the display update, `_social_state()` plus the
  `redact_social_state` merge in `_build_snapshot`, and the `_fold_last_known_state` /
  `_snapshot_remote_players` notes brought in line with a peer's HP now being durable.
- `src/networking/networking_slice.gd` — `redact_social_state(state)` (the host half of
  `IDENTIFIED_STATE_KEYS`), `_on_server_disconnected()` and its wiring, so a CLIENT that
  loses its host drops the snapshot it was reassembling.
- `src/creature/taming_slice.gd` — `_cooldowns_for()` prunes expired deadlines in place,
  through the same shared rule the record is written with.
- `src/tests/test_suite.gd` — 4 new tests (36 new assertions) under a `Phase 38` banner.

**Acceptance criteria:**
- [x] A peer's health is the HOST's: `simulated_hp_after_hit` starts an unmodelled body at
  full health (never at a value the peer declared), clamps to `[0, max_hp]`, and
  `record_simulated_hp` writes it on the peer's durable record — asserted through
  `get_player_data` → `apply_player_data`, so a reconnect or a restart no longer hands the
  peer a full bar. The declared door stays shut: `record_hp` still refuses a remote id, the
  local body is still `record_hp`'s, an id this host holds no record for is refused rather
  than minted, and a non-authoritative registry writes nothing.
- [x] The snapshot's social blobs travel under `IDENTIFIED_STATE_KEYS` and are walked from
  it: only those keys are carried (a blob the list does not name is dropped, not passed
  through unredacted), every listing seller / proposal author / trade party reaches the
  wire as a public handle — including a trade party used as a dictionary KEY — and no
  player id survives the walk.
- [x] A client that loses its host clears its snapshot buffer, while a host-role call
  changes nothing (the local teardown path already covers it).
- [x] The cooldown mirror is pruned in place: an elapsed deadline is gone from
  `TamingSlice._cooldowns` after a read, a live one stays, and a deadline written after a
  prune lands in the same table the reader left behind.
- [x] Headless suite green on both boot paths — `Results: 7415/7415 passed  (0 failed)` →
  `All tests passed ✓` with `[Server] listening on port 7777, max_clients 64` on the server
  boot (7379 at the start of this pass: 36 new assertions).
- [x] Every fix is RED-proven: with the pre-fix policy restored (source only, tests kept)
  the new assertions fail — quoted in the commit body.

**Implementation notes:**
- **A hit the host resolved is evidence, and evidence has to be kept.** Phase 37 routed the
  round by target and delivered it to the peer's own client, which closed the "no round is
  ever opened" hole but left the OUTCOME client-owned: a modified client could ignore the
  packet and be unkillable, and an honest one lost its health on every reconnect and every
  restart. The host now applies the hit to its own number for that peer first and sends the
  round afterwards as a display update, so a client that drops it diverges from a truth it
  does not hold instead of being the truth. The seed for a body the host has never modelled
  is FULL health — the only honest choice, since the record is empty and the peer's own
  declared value is what made a durable record a cheat in the first place (that value is
  still ignored on `player_moved` and still refused by `record_hp`).
- **Two writers for one field, and the split is the security property.** `record_hp` is the
  live-body writer and refuses a remote id; `record_simulated_hp` is the host's own
  resolution and refuses the local id, an empty id, a player with no resident record, and
  any non-authoritative machine. Keeping them separate is what lets the durable rule stay
  testable on its own (`simulated_hp_after_hit` is pure) instead of hiding behind "the host
  may write anything".
- **One list for identity-bearing state, read in both directions.** `IDENTIFIED_STATE_KEYS`
  existed but the SNAPSHOT builder hardcoded the same three keys, so the constant only ever
  governed the receiving side: a fourth entry would have been adopted by every client while
  never being redacted on the way out — a player id on the wire, the exact leak the constant
  exists to prevent. `redact_social_state` walks the constant now, and a key the list does
  not name is dropped rather than passed through: an identity-bearing blob nobody has added
  to the list is a blob whose redaction story has not been decided.
- **The buffer's eviction points were both on the host's half of the wire.** One was this
  slice's own teardown and the other was a PEER disconnecting — and a client has no peers to
  disconnect, so a client's half-reassembled snapshot sat there for the rest of the session.
  `server_disconnected` is the missing end of the same lifecycle (`_attach_peer` /
  `_detach_peer`), and the handler is role-gated so it cannot become a second, weaker clear.
- **A prune that only ran on the saved copy is not a prune.** `get_cooldowns` handed the
  record a filtered copy while `_cooldowns` kept every deadline the player had ever set, so
  the mirror grew with every fox ever fed and the record only caught up at a `sync_record`.
  The prune now runs where the table is READ — the same `live_cooldowns` rule on both sides
  — and allocates nothing when nothing expired, so the write path keeps landing in the one
  dictionary the mirror holds.

**Known simplifications (deferred):**
- **Peer health has a durable floor but no death consequence.** The host simulates and
  persists a peer's HP, but a peer reaching zero is still not resolved host-side (no
  `creature_died`-style outcome, no respawn): the downed body stays the peer's own client's
  business, as the whole of its movement is. **(closed in Phase 39, for the floor: the host
  now writes a respawn deadline when its own simulation reaches zero and resolves it lazily
  on read, and the client starts its own countdown the moment `set_hp()` hands it a zero, so
  a downed peer recovers instead of freezing at zero across reconnects and restarts. What is
  still deferred is the death CONSEQUENCE: no corpse, no loot, no kill credit is resolved
  host-side.)**
- **A hit is not sequenced against the hit that preceded it.** The host applies each
  resolved round as it comes, and `player_damaged` still carries only the delta, so a
  client that lost a packet converges on the host's number a round late rather than never.
- **Peer equipment is still not replicated.** The bare-hands rule is evaluated against the
  peer's own claim (unchanged from Phase 36/37).
- **`tamed_by` is still not replicated**, so a peer's companion appears as a wild creature
  in its AOI stream while the follow AI runs only on the host (unchanged from Phase 35).
- **Still no end-to-end socket exercise** of these paths: every fix is proven at the routing
  level (`_route_c2h` / `_route_h2c`, the bus, `_pending`, and directly against the registry
  rule) rather than by driving two real clients through ENet (Phase 34/35/36/37's gap,
  unchanged).
