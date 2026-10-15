# Project Nihon — Roadmap

Project Nihon is an open-source sandbox MMORPG where players build a
civilization. This document tracks the design and implementation roadmap.
The game's entire design bible — materials, creatures, skills, items, world
systems — is authored as a Newel fabric and generated into documentation,
runtime assets, and Godot resources.

See `../newel/ROADMAP.md` for the Newel-side changes each phase depends on.

**Human verification is not an acceptance criterion.** A criterion must be decidable by the
automated gates — `pnpm validate`, `pnpm check-drift`, the headless suite on both boot paths,
`tools/net_harness.sh`, CI. A check that needs a person at the keyboard (a playtest, a screenshot
judgement, a visual inspection) is not a criterion: it is filed as a GitHub issue and the phase
proceeds without it, so unpublished human work never parks the roadmap. The phase records the
issue number where the criterion used to be.

---

## Phase index

| Phase | Title | Status | Spec |
|---|---|---|---|
| 1 | Constitution fabric | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 2 | Materials and world primitives | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 3 | Skills and professions | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 4 | Items, recipes, and technology tree | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 5 | Creatures and combat systems | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 6 | `generator-bible` integration | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 7 | Character system specification | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 8 | `generator-godot` integration | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 9 | Public wiki | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 10 | Vertical slices: playable game loop | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 11 | Crafting slice | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 12 | Voxel mining and building | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 13 | Technology unlock gates | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 14 | Player UI: inventory, technology tree, crafting | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 15 | Creature AI and behavior | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 16 | Station-gated crafting and tool durability | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 17 | Chunk streaming and world expansion | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 18 | Multiplayer world sync (core) | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 19 | Multiplayer chaos resilience | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 20 | Skeleton rig and animation | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 21 | Asset separation and public placeholders | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 22 | Material and palette pipeline | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 23 | LOD and composition simplification | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 24 | Social systems and player economy | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 25 | Tool and equipment repair | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 26 | Client-side rendering instancing | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 27 | Headless data-oriented server | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 28 | Spatial hashing | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 29 | Interest management (area of interest) | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 30 | Pack and herd behavior | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 31 | Trees and resource appearance | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 32 | One authoritative boot path | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 33 | Player identity and server-side persistence | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 34 | Per-player repair and research | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 35 | Creature taming | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 36 | Review pass: the network trust boundary, gated boots, per-player progression | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 37 | Review pass: owner-scoped syncs, durable cooldowns, bounded memory, routed rounds | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 38 | Review pass: host-simulated peer health, one key list, the missing clear, an in-place prune | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 39 | Two-client network harness: prove the wire over a real socket | Done | [history](docs/roadmap-history/phases-39-42.md) |
| 40 | Review pass: the avatar's footing — the voxel surface, walked stairs | Done | [history](docs/roadmap-history/phases-39-42.md) |
| 41 | Deterministic world and volumetric terrain | Done | [history](docs/roadmap-history/phases-39-42.md) |
| 42 | Threaded chunk build and a loading screen | Done | [history](docs/roadmap-history/phases-39-42.md) |
| 43 | Natural resource distribution | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 44 | Spawn scarcity | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 45 | Asset pipeline for meshes and animation | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 46 | UI shell | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 47 | Character window | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 48 | Review pass: the equipment trust boundary | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 49 | Zone crossing and natural ground | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 50 | Planet coordinates | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 51 | Continents, oceans and mountains | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 52 | Region storage and per-player server streaming | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 53 | Spawn placement and friend codes | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 54 | World clock, day and night, seasons | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 55 | Two-client harness: equipment delivery over the socket | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 56 | Station placement follow-ups | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 57 | Spawn determinism and cost follow-ups | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 58 | UI layout file robustness | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 59 | Wire the Phase 45 rig into the game | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 60 | Host-authoritative equip | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 61 | Region storage correctness | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 62 | Peer streaming window limits | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 63 | Planet coordinates wiring | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 64 | Biome blend consistency | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 65 | World clock and season follow-ups | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 66 | Spawn point and colonization follow-ups | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 67 | Network test seam cleanup | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 68 | Distant terrain off the main thread | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 69 | Neighbour seam rebuilds that match the edits | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 70 | Equip intent ordering and refusal cost | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 71 | World-generation version stamp | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 72 | Stable, low-frequency rare-biome niches | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 73 | Swimming and the distant ring follow the real ground | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 74 | Minimap redraw cost and first-apply layout clamp | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 75 | Region edits survive eviction and malformed neighbours | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 76 | Niche field wraps the planet and is calibrated by a test | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 77 | One detail-noise formula and the ring's strip helper | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 78 | Exact player position far from the origin | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 79 | Deterministic peer-window rate limit and a production ref-count reader | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 80 | Rebase in the physics step and explicit shift sets | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 81 | Pole-aware tile biome and a mined-tile biome memo | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 82 | Honest peer-window refusal count and a thread-safe warning counter | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 83 | Distant-ring teardown that does not stall | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 84 | The suite exits with no leaked objects | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 85 | Peer claims and host syncs keep separate interval clocks | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 86 | Remote peers' positions stay exact far from the origin | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 87 | Exact spawn and respawn points | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 88 | The distant ring survives a reparent and its abort is proven | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 89 | A malformed region entry warns once per session | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 90 | One scene-origin source and one wire-position validator | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 91 | A legacy tile height survives a depletion overlay | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 92 | The shown-biome memo follows the terrain slice and one pole-ring rule | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 93 | Host-sync window moves are counted and a clock swap resets the throttles | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 94 | A test eviction helper and a bounded UI retire list | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 95 | Free pointer, right-click look, chat box and admin commands | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 96 | A detached ring rebuild does not orphan its worker | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 97 | Peer windows and position relays use the exact peer position | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 98 | An exact first-boot spawn and a public canonical helper | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 99 | Housekeeping sweep: legacy tiles, roadmap/README hygiene and review leftovers | Done | below |
| 100 | Follow-up issue backlog triage | Done | below |
| 101 | Chat and admin commands are host-authoritative, exact and proven on the wire | Done | below |
| 102 | An admin `/kill` lands on the host's simulated peer health | Merged | [Phase 101](#phase-101--chat-and-admin-commands-are-host-authoritative-exact-and-proven-on-the-wire) |
| 103 | Teleports carry the exact position and stay on the planet | Merged | [Phase 101](#phase-101--chat-and-admin-commands-are-host-authoritative-exact-and-proven-on-the-wire) |
| 104 | Two-client harness: chat and admin teleport over the socket | Merged | [Phase 101](#phase-101--chat-and-admin-commands-are-host-authoritative-exact-and-proven-on-the-wire) |
| 105 | Archive Phases 75–95 into the roadmap history | Merged | [Phase 99](#phase-99--housekeeping-sweep-legacy-tiles-roadmapreadme-hygiene-and-review-leftovers) |
| 106 | A world stamp that covers fabric parameters, and golden generator values | Done | below |
| 107 | A per-chunk generation record in the region store | Done | below |
| 108 | Terrain reads and writes the generation record on the host | Done | below |
| 109 | Generation records reach clients, scoped and validated | Done | below |
| 110 | Trees are pinned per chunk and cleared where players build | Done | below |
| 111 | A full-map window: zoom from the minimap out to a whole planet | Done | below |
| 112 | A biome adjacency table in the fabric and an offline scan | Done | below |
| 113 | Frontier generation: a new generator version meets recorded land | Done | below |
| 114 | Generation record and frontier cleanup sweep | Done | below |
| 115 | Chat, admin and test-tooling cleanup sweep | Done | below |
| 116 | Tree clears follow chunks onto clients | Done | below |
| 117 | Map waypoints, HUD toasts and an explored set that scales | Done | below |
| 118 | Void bursts, the survivor flag and the VoidTouched unlock | Done | below |
| 119 | An injected network transport and a compact per-tick wire form | Done | below |
| 120 | The distant ring draws recorded land | Done | below |
| 121 | Crash-consistent saves | Done | below |
| 122 | Far terrain without mirroring and one scene-offset helper | Done | below |
| 123 | The player rig wears the character material and body masks | Done | below |
| 124 | Research points: the fabric's `researchCost` is enforced | Done | below |
| 125 | Waystones: a first fast-travel network | Done | below |
| 126 | Tree clears the host keeps, and one seam-wrap module | Done | below |
| 127 | Terrain streaming, generation records and persistence cleanup sweep | Done | below |
| 128 | Weather: the fabric's `WeatherSystem` runs on the host | Done | below |
| 129 | Combat status effects: burn, paralysis, knockback, knockdown and stagger | Done | below |
| 130 | Creatures walk on the ground and around obstacles | Planned | below |
| 131 | Loose ground settles: sand and soil fall when undermined | Planned | below |
| 132 | Internationalization: translated UI and keyed host messages | Planned | below |

---

## Phase 99 — Housekeeping sweep: legacy tiles, roadmap/README hygiene and review leftovers ✅ Done

**Goal:** Phase 91 added a `legacy` tile op, but `VoxelSlice._normalise_tile_ops` (and its test)
hardcode the string `"legacy"` instead of `RegionStore.LEGACY_OP`; `RegionStore._is_legacy_height`
re-implements `VoxelSlice._legacy_height_of` and the two disagree on non-finite values; the hot load
path allocates two arrays per tile even when no op is `legacy`; and three branches have no test (#232).
`README.md`'s phase table has drifted from ROADMAP.md and nothing checks the two agree (#219).
ROADMAP.md still carries the full bodies of the Done phases from 75 on, though earlier eras were
archived to `docs/roadmap-history/`. Several review follow-up issues list small roadmap, docs, test
and region-store leftovers in the same areas. This phase clears all of it in one PR.

Merges the former Phases 99 (legacy-op constant and parser), 100 (README phase table check) and 105
(archive Phases 75–95).

**Newel dependency:** NO.

**Closes:** #196, #209, #217, #219, #224, #232, #233, #234.

**Depends on:** Phase 89, Phase 91.

**Deliverables:**
- `src/terrain/voxel_slice.gd` — compares against `RegionStore.LEGACY_OP`; `_normalise_tile_ops`
  returns `_normalise_ops(value)` directly when no op is `legacy`; the op-kind list near the top of the
  file documents `legacy` and notes that older builds ignore it on load.
- One legacy-height parser (in `RegionStore` or a shared helper) used by both files; NaN and infinity
  are rejected by both callers.
- `src/tests/test_suite.gd` — tests for the materials-stack legacy migration, the
  `apply_region_chunks` partial-chunk path with a legacy op, and the unreadable-legacy-op drop branch.
- `README.md` — the phase table lists every phase in ROADMAP.md's index with the same title and status
  (a `Merged` row included).
- `tools/check_readme_phases.js` (new) — parses both tables and exits non-zero naming each phase whose
  number, title or status differs, or that is in one table and not the other; `--self-test` mode.
  `.github/workflows/ci.yml` runs it (and its self-test) next to `npm run check-drift`.
- `docs/roadmap-history/phases-75-NN.md` (new, NN = the highest Done phase below 99 when this phase
  lands) — those phase bodies moved unchanged, in order, with the same header line as the other history
  files; `docs/roadmap-history/README.md` lists it; their index rows in ROADMAP.md link to it, and only
  Planned phases keep a body below the index.
- Every item of each issue under **Closes:** is resolved, or, where a later phase already resolved it
  (e.g. #219's ring reparent by Phase 88, #209's shown-biome memo by Phase 92), confirmed in the code.
  The PR body has one `Closes #n` line per issue and a table: issue item → fixed here / resolved by
  Phase N (with the file or test that proves it).

**Acceptance criteria:**
- [x] `grep -n '"legacy"' src --include=*.gd -r` finds only the `LEGACY_OP` definition.
- [x] Suite: `NAN`, `INF` and `"abc"` heights are refused by the shared parser and by the region-store
  check alike; a finite numeric height (e.g. `3.0`) is accepted by both.
- [x] Suite: the three new legacy branch tests pass; a tile with no legacy op round-trips unchanged.
- [x] `node tools/check_readme_phases.js` exits 0; `--self-test` (a README status flipped from Done to
  Planned in memory) exits 1 naming that phase; CI runs both on every push.
- [x] `grep -c "^## Phase" ROADMAP.md` equals the number of index rows whose spec is `below`; every
  moved `## Phase N` heading appears exactly once across `docs/roadmap-history/`, byte-identical
  (`git diff --color-moved`), and every relative link in the new history file resolves.
- [x] Every issue under **Closes:** is closed by the merge, each item accounted for in the PR table.
- [x] Suite green on both boot paths, harness green — `Results: 15758/15758 passed (0 failed)`, `--server` and `--quit-after-boot` boots log their ready lines, harness 15/15 steps.

---

## Phase 100 — Follow-up issue backlog triage ✅ Done

**Goal:** Review passes have opened one "Follow-ups from PR #… review" issue per PR, plus several
"Phase 50 remainder" issues (#120–#127, #136) from before Phase 50 was finished. Most are older than
the phases that fixed their items, so the open issue list no longer says what is actually left. This
phase checks every remaining item against the code, closes what is done, and folds what is left into a
few per-area issues that a later roadmap batch can take as whole sweep phases.

**Newel dependency:** NO.

**Closes:** every open issue authored by the repo owner whose title starts with "Follow-ups from PR"
or "Phase 50", except those listed under **Closes:** of a Planned phase (97, 98, 99) and the
human-verification issues (#133, #134), which stay open.

**Depends on:** Phase 99.

**Deliverables:**
- For each issue in scope, every item is checked against the current code: resolved items are named
  with the phase, commit or test that resolved them; items no longer applicable (code removed,
  superseded design) say why.
- Items still open are grouped by area (networking, terrain/streaming, distant terrain, persistence and
  region store, UI, tests and tooling). Each area gets ONE new issue labelled `autopilot-followup`,
  starting with an `Area:` line, then a `- [ ]` checklist where every item names its file and function
  and links its source issue.
- Each source issue is closed with a comment listing its items and, for each, "resolved by …" or
  "moved to #n".
- No code changes; the PR updates only ROADMAP.md (ticks this phase) and carries the triage table
  (source issue → item → outcome) in its body.

**Acceptance criteria:**
- [x] `gh issue list --state open --author @me --search "Follow-ups from PR in:title"` and the same
  for "Phase 50" list only issues created by this phase or listed under a Planned phase's **Closes:**.
- [x] Each new area issue carries the `autopilot-followup` label, an `Area:` line and at least one
  unchecked item; no area has two.
- [x] Every closed source issue has a closing comment that accounts for each of its items.

**Outcome:** 53 source issues triaged and closed; open items folded into #253 (networking), #254 (terrain and far-origin precision), #255 (distant terrain), #256 (persistence), #257 (UI), #258 (tests and tooling). The human-verification issues #133 and #134 stay open.

---

## Phase 101 — Chat and admin commands are host-authoritative, exact and proven on the wire ✅ Done

**Goal:** Phase 95 shipped chat and admin commands, but they skip guarantees the rest of the game has.
`chat_intent` is bounded only by the generic packet rate, and each accepted line is broadcast to every
peer, so one client can flood every chat box. `/kill <peer>` calls `networking.send_player_damaged`
directly, so the host's simulated HP (Phase 38) keeps the peer at full health and a reconnect restores
it. Teleports go through float32 (`ChatSlice._position_of`, a `Vector3` `player_teleport`,
`WorldPos.to_wire`), so ten thousand km out `/bring` and `/tp <player>` land up to a metre off, and
`/tp x y z` accepts a Z past the pole row or an X several laps round. None of it is exercised over a
real ENet connection.

Merges the former Phases 101 (chat rate limit), 102 (admin `/kill` on simulated HP), 103 (exact,
on-planet teleports) and 104 (two-client harness steps).

**Newel dependency:** NO.

**Depends on:** Phase 38, Phase 39, Phase 86, Phase 90, Phase 95.

**Deliverables:**
- `src/chat/chat_slice.gd` (or the host-side chat handler) — a per-player token bucket (`CHAT_BURST`
  lines, refilling at `CHAT_LINES_PER_SEC`) checked before a line is parsed or broadcast; a refused line
  is dropped, counted in `chat_rate_refused`, and answered with at most one "slow down" notice per player
  per interval. The host's own local player is subject to it too; an admin's commands bypass it except `/say`, which broadcasts (Phase 125). The clock is
  injectable, like `ChunkManager.set_clock`; the bucket entry survives a disconnect (Phase 115) and idle ones are pruned, with the least recently used evicted past `MAX_BUCKETS` (Phase 125).
- The same file — `_cmd_kill` on a remote target routes through the same host path as a creature hit
  (emit `GameBus.player_damaged(KILL_DAMAGE, "admin", target)` or call one shared host helper), never
  `send_player_damaged` on its own; the local-body branch is unchanged. No file outside `game_root.gd`
  calls `send_player_damaged`.
- The same file — `_position_of` returns the exact position (`PlayerSlice.get_world_pos()` for the local
  body, `NetworkingSlice.get_last_known_exact(peer)` for a peer, the float path only as fallback);
  `_teleport` passes it on unchanged.
- `src/core/bus.gd`, `src/core/game_root.gd` — `player_teleport` carries a `{chunk, local}` dictionary;
  `_on_player_teleport` rebases onto its chunk and calls `place_at_world_pos` with it.
- `src/networking/networking_slice.gd` — `send_teleport` sends `WorldPos.pos_to_wire(exact)`; the client
  decodes it with `WorldPos.pos_from_wire` and drops a packet that fails `WorldPos.is_wire`.
- `src/core/chat_commands.gd` — `/tp x y z` wraps X onto one lap and refuses a Z beyond the pole rows
  with a usage reply naming the limit.
- `src/tests/net_harness.gd` — steps `chat_relayed` (the client's plain line reaches both roles with the
  same sanitised text; the host-side sender is the client's handle, not any name the packet claimed),
  `admin_teleport` (the host runs `/bring <client handle>`; the client's body lands within 1 m of the
  host's and the host sees the client's next `player_moved` from there) and `non_admin_refused` (the
  client's `/give` gets a refusal addressed to it alone; its inventory is unchanged on both sides).

**Acceptance criteria:**
- [x] Suite: with a fake clock, a client sending `CHAT_BURST + 10` lines in one tick has exactly
  `CHAT_BURST` broadcast, `chat_rate_refused` raised by 10 and one notice sent to it alone; after
  `1 / CHAT_LINES_PER_SEC` seconds of fake time one more line is accepted; a disconnect keeps (Phase 115) the
  player's bucket entry.
- [x] Suite: an admin's `/kill` on a connected peer leaves `PlayerRegistry.get_hp(peer_id)` at 0 (the
  `simulated_hp_after_hit` floor) and sends exactly one `player_damaged` to that peer; after that peer
  disconnects and reconnects, its restored HP is the simulated value, not `MAX_HP`.
- [x] `grep -rn "send_player_damaged(" src --include=*.gd | grep -v -e game_root.gd -e networking_slice.gd -e test_suite.gd -e net_harness.gd`
  finds nothing.
- [x] Suite: `/bring` of a peer to a local player at chunk (1,200,000, 3) local (0.25, 10, 0.75) sends a
  teleport that decodes on the client to that chunk and a local within 1e-3 m; `/tp <peer>` by the
  local admin lands the body at the peer's exact chunk, local within 1e-3 m.
- [x] Suite: `/tp 0 10 z` with `z` one chunk past `TerrainSlice.pole_chunks()` is refused and no
  teleport is emitted; `/tp x 10 0` with `x` = 2.5 laps lands at the wrapped X; a `teleport` packet with
  a malformed position is dropped on the client and the body does not move.
- [x] `tools/net_harness.sh` reports 18/18 steps passed (the 15 existing plus the three above), both
  roles agree on every `compare: true` step, and each new step fails when its host-side handler is
  stubbed out in a scratch copy (noted in the PR body). CI's harness job runs the new steps.
- [x] Suite green on both boot paths, harness green.

---

## Phase 106 — A world stamp that covers fabric parameters, and golden generator values ✅ Done

**Goal:** Phases 106–113 let the generator change without moving land a player has already seen.
Today terrain is a pure function of the seed, and `TerrainSlice.WORLDGEN_VERSION` is the only guard.
It misses two things. `WorldShape.warm()` reads `seaLevel`, `minHeight`, `maxHeight`, `oceanShare`,
`ridgeAmplitude` and `heightSpline` from the fabric `WorldSystem`, and `ClimateField.warm()` reads every
biome's temperature, moisture, altitude and rarity envelope; editing any of them changes terrain with
no code change and no version bump. And the detail noise is `FastNoiseLite`, whose output a Godot
upgrade could shift without any change in this repo. This phase makes both visible.

**Newel dependency:** NO.

**Deliverables:**
- `src/terrain/terrain_slice.gd` — `static func worldgen_fingerprint() -> int`: an FNV-1a hash (as
  `ClimateField.niche_salt`, not `String.hash()`) over the `WorldSystem` fields above and the warmed
  `ClimateField` envelope table, in sorted key order.
- `src/persistence/persistence_slice.gd`, `src/core/game_root.gd` — `world.json` records
  `worldgenFingerprint` next to `worldgenVersion`; a load whose stored fingerprint differs raises
  `GameBus.worldgen_fingerprint_mismatch(saved, current)` once, on the same path as
  `worldgen_version_mismatch`. An absent fingerprint (an older save) is stamped, not reported.
- `src/tests/test_suite.gd` — golden values: `TerrainSlice.detail_of` at 8 fixed points,
  `WorldShape.height` at 8 fixed (seed, x, z) triples, and `ClimateField.biome_for_chunk` for 16 fixed
  chunks, with the expected numbers written into the test.
- `CLAUDE.md` — the world-gen rule now reads: anything that changes world-gen output, in code or in
  `WorldSystem` or biome envelopes, bumps `WORLDGEN_VERSION` and updates the golden values.

**Acceptance criteria:**
- [x] Suite: the fingerprint is stable across two calls and across a `warm()` reset; changing
  `ridgeAmplitude` in a scratch resource changes it.
- [x] Suite: a world record with a different fingerprint raises `worldgen_fingerprint_mismatch` exactly
  once; a record without one raises nothing and is stamped on the next save.
- [x] Suite: the golden detail-noise values match to 1e-6; the shape values match to 1e-8 (the goldens carry nine decimals, so an exact float compare is impossible) and the biome values match exactly.
- [x] `npm run validate`, `npm run check-drift` green; suite green on both boot paths.

---

## Phase 107 — A per-chunk generation record in the region store ✅ Done

**Goal:** a visited chunk keeps its look when the generator later changes only if what it looked like
is stored. The large-scale surface of a chunk is the four `WorldShape` heights at its corners (the
detail noise is a fixed function), and its biome is one key. That is about 20 bytes per chunk. This
phase adds the storage and nothing else; Phase 108 uses it.

**Newel dependency:** NO.

**Depends on:** Phase 52, Phase 89, Phase 106.

**Deliverables:**
- `src/persistence/region_store.gd` — `REGION_FORMAT_VERSION` 2. A chunk entry may carry
  `"gen": { "v": <worldgen version>, "f": <fingerprint>, "b": "<biome key>", "h": [c00, c10, c01, c11] }`
  beside `"edits"`. Version-1 files still load. `get_gen(chunk)` / `set_gen(chunk, rec)` mirror the edit
  API, `list_dirty` counts a chunk whose only change is a `gen`, and the write path stays atomic and
  safe on the save worker.
- A malformed `gen` (wrong types, a non-finite or out-of-range height, an unknown biome key, a version
  newer than the running one) is dropped with one warning per session, the Phase 89 pattern.

**Acceptance criteria:**
- [x] Suite: a `gen` record round-trips through `save_region` / `load_region` with heights equal to 1e-4.
- [x] Suite: a version-1 region file loads unchanged, and a save of it writes version 2 with its edits intact.
- [x] Suite: a malformed `gen` is dropped, its chunk's edits survive, and the warning fires once for two loads.
- [x] Suite: a region with 1,024 recorded chunks and no edits serialises to under 100 KB.
- [x] Suite green on both boot paths.

---

## Phase 108 — Terrain reads and writes the generation record on the host ✅ Done

**Goal:** make the record authoritative. When a chunk enters a player's streamed window and has no
record, the host generates it as today and writes its record. When it has one, the record wins over the
generator. Under one generator version the two agree, so nothing visibly changes; the phase is what a
later generator change stands on.

**Newel dependency:** NO.

**Depends on:** Phase 107.

**Deliverables:**
- `src/terrain/chunk_records.gd` (new) — a mutex-guarded table `chunk key -> record`, loaded by region
  as `ChunkManager` already loads edit regions. `ClimateField.biome_for_chunk` callers go through
  `TerrainSlice.biome_for_chunk`, which asks the table first; `OreField` reads it from its worker, so
  the table is read-only to workers, written only on the main thread, like the `_pool_cache` guard.
- `src/terrain/terrain_slice.gd` — `_shape_at` uses a record's four heights instead of
  `WorldShape.height` for that cell, and its biome result comes from the record.
- `src/terrain/chunk_manager.gd` — a chunk loaded into a player window with no record gets one written
  (host and dedicated server only, never a client).
- `src/terrain/distant_terrain.gd` — the ring reads records and never writes them: unvisited far
  chunks are not recorded, so the store grows with exploration only.

**Acceptance criteria:**
- [x] Suite: with no records, the heightmap hash and biome of 64 chunks equal their pre-phase values
  (the Phase 106 goldens plus a recorded hash).
- [x] Suite: a stub record with another biome and shifted corner heights makes `biome_for_chunk` and
  `generate_heightmap` return the record's values for that chunk and the generator's for its neighbours.
- [x] Suite: a chunk streamed into a window gets exactly one record, and a second load rewrites nothing.
- [x] Suite: building a ring writes no record; a client-role `ChunkManager` writes none either.
- [x] Suite: `OreField` asked from a worker thread for a recorded chunk gets the recorded biome.
- [x] Suite: with the recorded chunk's `v` set to an older number, its output is unchanged.
- [x] Suite and `--server` / `--quit-after-boot` boots green; harness green.

---

## Phase 109 — Generation records reach clients, scoped and validated ✅ Done

**Goal:** a client regenerates terrain from the seed (Phase 41). Once the host's record can differ from
the generator, the client has to receive the record or it draws different land from the host. Records
are small, so they ride the same scope as edits.

**Newel dependency:** NO.

**Depends on:** Phase 49, Phase 108.

**Deliverables:**
- `src/networking/networking_slice.gd`, `src/core/game_root.gd` — a join snapshot and every window
  re-scope carry the records of chunks inside the peer's streamed window plus its first ring, with the
  scope named, as edits do. A cap per packet and a per-peer interval clock bound the traffic.
- The client validates each record (types, finite floats, heights within `WorldShape.min_height()` to
  `max_height()`, biome key in `TerrainSlice.BIOME_KEYS`, at most the packet cap) and drops a bad
  one; it applies records before `ChunkManager.start()` and the first-ring gate waits for them.
- `src/tests/net_harness.gd` — step `chunk_record_synced`.

**Acceptance criteria:**
- [x] Suite: a snapshot for a peer carries records for its window only; one for a far peer carries none of them.
- [x] Suite: a record with a biome key outside `BIOME_KEYS`, a NaN height or a height above `max_height`
  is dropped and the rest of the packet applies.
- [x] Suite: a packet over the cap applies the first `cap` records and counts the rest as refused.
- [x] `tools/net_harness.sh`: the host records a chunk with a different biome than the generator would
  pick; the client reports the host's biome and heights, and both roles agree on the step.
- [x] Suite green on both boot paths, harness green.

---

## Phase 110 — Trees are pinned per chunk and cleared where players build ✅ Done

**Goal:** `TreeSlice.spawn_for_chunk` places every tree from the chunk coordinate and the original
terrain height. It reads neither voxel edits nor stations, so a base built in a forest keeps its trees
standing in its walls, and a tree on dug-out ground floats at the old surface. A chopped tree also
regrows, so clearing it never lasts. This phase records which trees a chunk has and lets building
clear them for good.

**Newel dependency:** NO.

**Depends on:** Phase 31, Phase 108, Phase 109.

**Deliverables:**
- The `gen` record gains `"t": <tree budget when generated>` and `"x": [<cleared spawn indices>]`.
  `TreeSlice.spawn_for_chunk` takes its budget from `t` when present, so a later density change does
  not add or drop trees in a recorded chunk, and skips indices in `x`.
- `TreeSlice` clears a tree for good when a voxel edit lands within `CLEAR_RADIUS_TILES` of its tile or
  a station is placed within `CLEAR_RADIUS_M` of it: the host adds its index to `x`, frees its collision
  and visual, and emits `tree_cleared(tree_id)` for clients to do the same.
- A tree standing on a tile that already has edits when its chunk first spawns is cleared by the same rule.

**Acceptance criteria:**
- [x] Suite: placing a block on a tree's tile removes the tree; after unloading and reloading the chunk,
  and after a save and load, it is still gone.
- [x] Suite: placing a station within `CLEAR_RADIUS_M` clears the trees inside the radius and none outside.
- [x] Suite: a recorded chunk keeps its tree count when the biome's `treeDensity` is changed in a scratch resource.
- [x] Suite: a client receiving `tree_cleared` frees the tree's collision and its MultiMesh slot; the
  orphan-node check stays clean.
- [x] Suite: a chopped-and-regrowing tree is unaffected: the stump still regrows after its cooldown.
- [x] Suite green on both boot paths, harness green.

---

## Phase 111 — A full-map window: zoom from the minimap out to a whole planet ✅ Done

**Goal:** the minimap shows a few chunks around the player. A player who wanders off needs the whole
picture: a Map window (key `M`, and an `M` box in the HUD's window dock) that opens on the explored
land and zooms out smoothly until the entire planet is a round globe, the way Google Earth does. At every
zoom the picture is the real world, drawn bit by bit from the same deterministic fields the terrain is
generated from, never a stored or approximated copy. The minimap's fog-of-war record (`_revealed`) is
kept per world and survives a relog, and the window marks the player's home.

**Newel dependency:** NO.

**Depends on:** Phase 87, Phase 51 (planet shape), and the HUD window dock (`src/ui/window_dock.gd`, which
reserves `M` for this window).

**Deliverables:**
- `src/ui/map_window.gd` — a Map window registered with the UI slice (`WINDOW_MAP`, key `M`, a dock box).
  Dragging pans; the wheel zooms; zoom is continuous from street level (one chunk is many pixels) out to a
  whole-planet view.
- Zoom ladder: close in it is the flat chunk map; further out the projection blends into an orthographic
  globe, and at the far end the planet is a round sphere that can be dragged to rotate. The blend is a pure
  function of zoom, so there is no jump between the two.
- The picture is the correct world, bit by bit: tiles are sampled from the world-gen fields
  (`WorldShape` height/ocean, climate, biome) in a coarse-to-fine pyramid. A coarse level draws at once, and
  finer levels fill in over the following frames on a worker thread, a few tiles per frame, with a bounded
  tile cache (oldest dropped first). A tile at a given zoom and place is a pure function of
  (seed, `WORLDGEN_VERSION`, tile), so the cache key carries all three.
- Fog of war stays honest: unexplored land is drawn dimmed, explored land in full colour; a toggle shows the
  true planet. The explored set persists per world seed under `user://saves/client/`, with a cap on stored
  chunks (oldest dropped first), runs encoded per row, and debounced writes.
- A home marker at the player's recorded respawn point (Phase 87): an icon on the map, and when the point is
  off-screen a direction arrow clamped to the edge with the distance. The clamp is a pure static function.
- The minimap keeps its own scroll and `+`/`-` zoom; clicking it opens this window.

**Acceptance criteria:**
- [x] Suite: the projection blend is a pure function of zoom: flat at the near end, a unit sphere at the far
  end, monotone between, with matching positions at the seam (no jump).
- [x] Suite: a map tile for a given (seed, version, tile) is identical across runs and equals the terrain's
  own sample at the tile centre; changing the seed or `WORLDGEN_VERSION` changes the cache key.
- [x] Suite: the tile cache never exceeds its cap and drops the oldest first; a request for a coarser level
  is answered before a finer one.
- [x] Suite: a revealed set round-trips through save and load; a file for another seed is ignored; a missing
  or corrupt file starts an empty set and warns once.
- [x] Suite: the cap drops the oldest chunks, and 10,000 contiguous chunks encode to under 20 KB.
- [x] Suite: the home clamp returns the point itself when inside the map, and an edge position on the line
  toward it, with the right distance, when outside; it is exact at 1,500,000 chunks from the origin.
- [x] Suite: `M` and the dock's `M` box toggle the Map window; no other window uses `M`.
- [x] Suite green on both boot paths.

---

## Phase 112 — A biome adjacency table in the fabric and an offline scan ✅ Done

**Goal:** nothing today stops snow lying against lava; adjacency is whatever the smooth climate noise
produces, and `BiomeBlend` only dithers the colour at a border. To change the generator safely the
rules have to be explicit, and a new biome has to be checked against them. They are enforced offline,
not per chunk: a chunk's biome stays a pure function of seed and position, so workers and clients keep
agreeing without talking to each other. The runtime use of the rules is Phase 113.

**Newel dependency:** NO.

**Depends on:** Phase 49, Phase 108.

**Deliverables:**
- `fabric/world/biomes/` — each biome gains `forbiddenNeighbours` (a list of biome keys, symmetric by
  construction) and `transition` (the biome that must lie between it and a forbidden one). The
  fabric validation rejects an unknown key, an asymmetric pair, or a missing transition.
- `npm run generate` emits the table into `godot/` for `GameData`.
- `src/tests/test_suite.gd` — an adjacency scan: for each of 4 fixed seeds, a 256×256 chunk grid at
  the equator, the temperate belt, the pole edge and a coastline, counts 4-neighbour pairs that are
  forbidden. Where the current generator violates a rule, the fix is a fabric envelope change shipped
  with a `WORLDGEN_VERSION` bump, which is safe for chunks already recorded (Phase 108).

**Acceptance criteria:**
- [x] `npm run validate` fails on a scratch fabric with an unknown key, an asymmetric pair or a
  forbidden pair with no transition, and passes on the real one.
- [x] `npm run generate`, `npm run check-drift` green.
- [x] Suite: the scan finds zero forbidden pairs across all grids.
- [x] Suite: the scan finds a violation when a scratch envelope is made to place two forbidden biomes
  side by side (the check can fail).
- [x] Suite green on both boot paths.

---

## Phase 113 — Frontier generation: a new generator version meets recorded land ✅ Done

**Goal:** after Phases 106–112 a generator change is safe for recorded chunks, but a new chunk beside
a recorded one would meet it with a cliff or a forbidden biome pair. This phase generates the frontier
so the two meet cleanly, then records it, so the choice is made once and never revisited.

**Newel dependency:** NO.

**Depends on:** Phase 108, Phase 109, Phase 112.

**Deliverables:**
- `src/terrain/frontier.gd` (new) — a deterministic function of the generator and the recorded
  neighbours. A new chunk's corner heights: a corner shared with a recorded chunk reuses its recorded
  value exactly; others ease from the recorded heights to the new generator's over `BLEND_CHUNKS`
  (smoothstep on Chebyshev distance to the nearest recorded chunk, as `WRAP_BLEND_CHUNKS` eases the
  seam). Biome: the generator's pick, unless it is forbidden next to a recorded 4-neighbour, in
  which case the forbidden biome's `transition`, then the next-best envelope.
- `src/terrain/chunk_manager.gd` — the host runs it for an unrecorded chunk in a window and writes the
  result as the chunk's record; the neighbouring regions are loaded first. Clients receive it by Phase 109.
- `CLAUDE.md` — document the stable-world rule: recorded chunks never change; a generator version
  affects only unrecorded land.

**Known limitation:** `DistantTerrain` draws far unrecorded chunks from the plain generator, so a ring
tile beside recorded land may change slightly when the player arrives and the frontier is computed.

**Acceptance criteria:**
- [x] Suite: after changing `WorldShape`'s warmed `ridgeAmplitude` and `heightSpline` (standing in for a
  new version), every recorded chunk's biome and heights are unchanged.
- [x] Suite: a new chunk next to a recorded one shares its corner heights exactly; the largest height
  step between adjacent corners across the blend band is below a stated bound.
- [x] Suite: a new chunk at least `BLEND_CHUNKS` from any recorded chunk equals the plain new generator.
- [x] Suite: the adjacency scan (Phase 112) around a recorded block, with the changed generator, finds
  zero forbidden pairs.
- [x] Suite: two hosts given the same records and generator produce identical records for a chunk.
- [x] Harness: the client receives a frontier record and agrees with the host.
- [x] Suite green on both boot paths, harness green.

---

## Phase 114 — Generation record and frontier cleanup sweep ✅ Done

**Goal:** Phases 106–113 made recorded chunks stable across generator changes, and their reviews left
a backlog of low-severity leftovers in the same code: the record table outlives a world in one
process, pending records are lost on shutdown, a failed region read can still mint a permanent record,
the frontier blend drops part of its offset in one step and depends on load order, and several tests
are looser than the roadmap claims. This phase resolves every item of the six issues below in one PR.

**Newel dependency:** NO.

**Depends on:** Phase 113.

**Closes:** #264, #268, #270, #271, #282, #283.

**Deliverables:**
- `src/terrain/chunk_records.gd`, `src/terrain/chunk_manager.gd` — `ChunkRecords.clear()` is called on
  world load and in `ChunkManager._exit_tree`; pending records are flushed before quit; `flush_records`
  backs off per region after a failed read or write instead of retrying every frame; tree-only record
  updates no longer bump the revision that flushes terrain corner caches (#268, #270).
- `src/terrain/chunk_manager.gd` `_record_generation` — defers (does not record) a chunk while any
  region within `BLEND_CHUNKS` failed to load or is backing off in `RegionStreamer.sync`; a region that
  later reads and swaps a record under a built chunk queues that chunk's rebuild; the overlong doc
  comment is rewrapped and the region-margin cost is noted (#268, #270, #282, #283).
- `src/persistence/region_store.gd` `normalize_gen` — a record with a newer `v` is kept verbatim on
  rewrite rather than stripped (#270).
- `src/terrain/frontier.gd` — `corner_height` uses a distance-weighted, order-independent offset whose
  smoothstep reaches 0 at the last ring; `HEIGHT_STEP` and the generated-height maths are shared with
  `RegionStore.GEN_HEIGHT_STEP` / `TerrainSlice.generation_record`; `gather` does one bulk read with an
  early-out when no neighbour is recorded; the remaining fill-order dependence of `record_for` and
  `pick_biome` is documented in `CLAUDE.md`'s stable-world rule (#282, #283).
- `src/persistence/region_streamer.gd` `regions_for_chunks` — the `BLEND_CHUNKS` margin loads a
  neighbouring region only for chunks that have no record yet (#283).
- `src/terrain/chunk_record_sync.gd`, `src/core/game_root.gd` — the client prunes its table to
  `gen_scope` on each re-scope and rebuilds already-built chunks whose record arrived late; the cap
  counts valid entries only and host truncation is logged; `_peer_records_msec` is stamped only when
  records are sent; `worldgen_fingerprint()` is cached and its literal step replaced (#270, #271).
- `src/core/game_root.gd` `_note_worldgen_version` — `worldgen_fingerprint_mismatch` reaches the UI
  through the same notice path as the version mismatch, once per world, and the stamp is updated after
  the notice so it does not repeat on every load (#264).
- `src/tests/test_suite.gd`, `src/tests/net_harness.gd` — `_test_worldgen_golden` compares shape
  values exactly (or the Phase 106 wording is amended to the tolerance actually used);
  `_test_worldgen_fingerprint` restores the statics it mutates even when an assert fails;
  `FRONTIER_MAX_STEP` is derived from the plain generator's own max step; the frontier pick is tested
  in two fill orders; the harness frontier step no longer mutates recorded host chunks (#264, #282).

**Acceptance criteria:**
- [x] #264: suite asserts exact golden shape values (or ROADMAP Phase 106 states the tolerance); a test
  proves the fingerprint mismatch reaches the UI notice once and not on the next load; the fingerprint
  test restores `_warmed`/`_envelopes` on a forced failure.
- [x] #268: suite proves `ChunkRecords` is empty after a world reload, pending records are on disk
  after `_exit_tree`, a failing region is retried at most once per backoff interval, and a late region
  adoption rebuilds the chunk.
- [x] #270: suite proves a re-scope prunes the client table, a newer-`v` record survives a rewrite, no
  record is written while a neighbouring region failed, and tree-only updates leave the revision alone.
- [x] #271: suite proves the client consumes `gen_scope`, the cap ignores malformed entries, and a join
  snapshot without records does not delay the first re-scope.
- [x] #282: suite: the frontier field is identical under two neighbour orders; the max-step bound is
  derived from the plain generator and fails on a scratch broken blend; zero forbidden pairs in both
  fill orders; harness frontier step passes without editing recorded chunks.
- [x] #283: suite: the blend weight is monotone and reaches 0 exactly at `BLEND_CHUNKS`; the streamer
  loads no extra region for an already-recorded window.
- [x] Suite green on both boot paths, `npm run check-drift` green; harness result equals `origin/main` (CI is the gate: `tree_cleared` `no_spare_tree` fails identically on main in the local environment).

---

## Phase 115 — Chat, admin and test-tooling cleanup sweep ✅ Done

**Goal:** the Phase 101 chat/admin review and the Phase 100 tests-and-tooling triage left small but
real leftovers: admin commands reply "done" when nothing was sent, far `/tp` targets lose metres in a
float32 detour, admin commands share the chat token bucket, a wall-clock test flakes on CI runners, and
several tests assert less than the roadmap claims. This phase resolves every item of the four issues
below in one PR.

**Newel dependency:** NO.

**Depends on:** Phase 101.

**Closes:** #258, #261, #262, #280.

**Deliverables:**
- `src/core/chat_commands.gd`, `src/chat/chat_slice.gd` — `parse_position` parses doubles and builds
  `{chunk, local}` directly, never through a `Vector3`; `/kill`, `/tp`, `/bring` reply success only when
  the host actually applied or sent the effect and report a reason otherwise; the token bucket charges
  plain chat and non-admin commands (admin commands are exempt) and is keyed by player id so a reconnect does not refill it (#261, #262).
- `src/tests/net_harness.gd` `admin_teleport` — waits until the destination chunk is loaded before
  checking the landing, and teleports the client back so later steps start from the usual place (#262).
- `src/tests/test_suite.gd` — 'chunk: the build split is measured' compares the median of several runs
  against a relative bound instead of one wall-clock sample; `_adjacency_origins` asserts that a coast
  was found; `_test_peer_exact_window_and_relay` asserts each relay separately;
  `_test_equipment_host_and_aoi_transitions` names its evict receivers and loses the garbled comment;
  the position tests use the tolerances ROADMAP states (or the criteria are reworded to match); new
  integration tests cover `_place_local_player`, `_build_snapshot` and `_on_world_snapshot_received`
  exact placement (#258, #261, #280).
- `src/creatures/creature_slice.gd` — `_spawn_fields` returns a typed result, and the missing-field
  warning test drives the real `spawn_for_chunk` (#258).
- `tools/check_readme_phases.js` — an unparseable row inside the phase table fails the check, with a
  self-test case for a decorated status (#258).
- `ROADMAP.md`, `docs/roadmap-history/` — Phase 101's chunk criterion names the chunk the test uses;
  the Phase 7/57/67/82/83 criteria flagged in #258 are reworded to what was actually run (#258, #262).

**Acceptance criteria:**
- [x] #258: `node tools/check_readme_phases.js --self-test` fails a decorated-status row; suite has the
  three new `GameRoot` placement tests and the separate relay asserts; the history criteria are reworded.
- [x] #261: suite: `/tp` to a point 1,200,000 chunks out lands within 1e-3 m of the typed coordinate;
  admin commands are not throttled by the chat bucket (non-admin commands are); the build-split test uses a median.
- [x] #262: suite: `/kill` on an unknown peer and `/tp` with no networking reply a failure; a reconnect
  does not reset the bucket; harness `admin_teleport` waits for the chunk and restores the client.
- [x] #280: suite: `_adjacency_origins` fails when no coast is found (proved with a scratch zero-step
  search).
- [x] Suite green on both boot paths (`--run-tests`, see PR); the net harness runs in CI.

---

## Phase 116 — Tree clears follow chunks onto clients ✅ Done

**Goal:** Phase 110 pins trees per chunk and clears them where players build, but a client learns about
clears only from its join snapshot and live `tree_cleared` events. A chunk that streams in later shows
ghost trees whose chop the host rejects; clears compare raw instead of seam-wrapped coordinates; a deep
mine clears surface trees; the client keeps wire-supplied ids forever. This phase sends each chunk's
tree record with the chunk, wraps every coordinate, bounds client memory and proves the wire path.

**Newel dependency:** NO.

**Depends on:** Phase 109, Phase 110.

**Closes:** #273, #274, #275.

**Deliverables:**
- `fabric/world/` — the clear radii (`clearRadiusTiles`, `clearRadiusMetres`) are authored in the tree
  data and read through `GameData`; `TreeSlice.CLEAR_RADIUS_*` constants go away (#274).
- `src/world/tree_slice.gd` — tree records (`t`, `x`) reach a client with the scoped record snapshots
  (Phase 109; each re-scope re-runs `resync_recorded_chunks`), so a late chunk spawns without its cleared
  trees; `clear_trees_near_*`
  share one loop that looks only at the edited chunk and its neighbours via `_by_chunk`, in
  `canonical_tile`-wrapped coordinates; `_on_block_changed` ignores edits deeper than the tree root and
  shifts by the face normal; a station clears trees in a not-yet-loaded neighbour by recording the clear
  in that chunk's record; `_on_edited_ground` checks stations as well as voxel edits with one
  per-chunk lookup; `_remove_clear` and `_trim_chunk_to` share their removal (#273, #274, #275).
- `src/world/tree_slice.gd` `_record_cleared` / `_budget_for` — clears for chunks without a record pin
  `t` once a record exists; indices up to the chunk budget persist (densities above `GEN_TREE_MAX` are
  refused by fabric validation instead of clamped); `_cleared_local` is range-checked, capped and evicted
  with the chunk; `resync_recorded_chunks` walks the loaded chunk set (#273, #274, #275).
- `src/persistence/region_store.gd` `normalize_gen` — an invalid optional `t` or `x` drops only that
  field (#275).
- `src/terrain/chunk_manager.gd` `update_record` — already bumped the `ChunkRecords` revision only when
  `b` or `h` change (covered by a new test); `chunk_record_sync.gd`'s size comment is updated for `t`/`x`
  (#273, #274, #275).
- `src/world/tree_slice.gd` `_on_tree_cleared` — a client keeps a `tree_cleared` id only for a chunk near
  its loaded ones (`_near_loaded_chunk`); `src/tests/net_harness.gd` gains a `tree_cleared` step
  (#274, #273).

**Acceptance criteria:**
- [x] Suite: a chunk streamed in after a clear spawns without the cleared tree on a client that was not
  in the clear's snapshot window.
- [x] Suite: a clear at the world seam (chunk X = −1 vs the wrapped lap) removes the same trees as one
  away from the seam; a mine 8 m below a tree does not clear it.
- [x] Suite: a station on a chunk edge clears a tree in the unloaded neighbour, which stays cleared when
  that chunk loads.
- [x] Suite: `_cleared_local` refuses out-of-range ids and never exceeds its cap; it is empty after the
  chunk is evicted; the MultiMesh slot of a cleared tree is released.
- [x] Suite: `normalize_gen` keeps `b`/`h` when only `t` is malformed; a tree-only update leaves the
  `ChunkRecords` revision unchanged.
- [x] `npm run validate` rejects a tree density above `GEN_TREE_MAX`; `npm run check-drift` green.
- [x] Harness: the new `tree_cleared` step passes (host clears, client removes the same tree).
- [x] Suite green on both boot paths, harness green.

---

## Phase 117 — Map waypoints, HUD toasts and an explored set that scales ✅ Done

**Goal:** the Phase 111 map window works, but its explored set is stored as string keys parsed on the
main thread (up to 50k per save and per redraw), the tile cache's stale list grows without bound, the
saved order loses age after a reload, and the home marker uses flat deltas on the globe. Notices such as
the world-version warning are a label in the Character panel. Players also have no way to mark a place
other than home. This phase adds player waypoints, a HUD toast channel for notices, and an explored set
that stays cheap at its cap.

**Newel dependency:** NO.

**Depends on:** Phase 111.

**Closes:** #257, #277, #278.

**Deliverables:**
- `src/ui/minimap.gd`, `src/ui/map_window.gd` — the explored set is held as `Vector2i` keys (or
  per-row runs); loaded chunks are wrapped and checked with `_in_world`; a late seed change waits for
  settle and does not save the throwaway seed's file; the map redraws only when the player's pixel or
  chunk changes and re-requests only newly visible tiles without dropping the queue; `_zoom` is clamped
  to `zoom_max`; the home marker uses great-circle direction and distance when the globe blend is high
  (#277, #278).
- `src/ui/map_tiles.gd` — `_stale` is capped and pruned oldest-first (#278).
- `src/persistence/revealed_store.gd` — encodes rows in age order as an array so the oldest-first cap
  survives a reload; the write runs on a worker with the main thread handing over an immutable
  snapshot (#277, #278).
- Waypoints — right-click on the map adds a named waypoint (up to a fixed cap), shown on the map and the
  minimap edge like home; stored per world in the revealed store's file with an exact `{chunk, local}`.
- `src/ui/ui_slice.gd` — a HUD toast queue (bounded, de-duplicated) replaces the Character-panel
  world-version label; pre-stamp saves no longer read as version 0 (#257).
- `src/core/chat_commands.gd` — the `/where` literal is one constant shared by `is_command` and `run`,
  and the chat box is its production caller (#257).
- `src/tests/test_suite.gd` — the NaN-token layout test asserts per-entry handling, and a test drives
  the `?` hotkey through `unicode == 63` (#257).

**Acceptance criteria:**
- [x] #257: suite: a world-version mismatch produces exactly one toast; a pre-stamp save produces none;
  the `?` hotkey path and per-entry NaN handling are tested; `/where` has one literal.
- [x] #277: suite: 50,000 revealed chunks save and reload with no string keys built on the main thread
  (the store API takes `Vector2i`); the home marker's distance at 1,500,000 chunks matches the
  great-circle value within 0.1%.
- [x] #278: suite: the cap drops the oldest chunks after a save/reload round-trip; `_stale` never exceeds
  its cap; a loaded out-of-world chunk is dropped; `_zoom` starts within `[zoom_min, zoom_max]` on a
  small world; an unchanged player pixel triggers no redraw.
- [x] Suite: a waypoint round-trips through save and load exactly, the cap refuses the extra one, and a
  file for another seed carries no waypoints.
- [x] Suite green on both boot paths.

---

## Phase 118 — Void bursts, the survivor flag and the VoidTouched unlock ✅ Done

**Goal:** the fabric says voidite refining can fail with a void burst, that surviving one grants the
`voidBurstSurvivor` flag, and that the flag gates the Void Smithing skill, enchanting voidite and the
`VoidTouched` profession. None of it runs: there is no refining recipe, no burst, no flag and no
profession unlock (deferred from Phase 13). This phase wires the chain end to end on the host.

**Newel dependency:** NO.

**Depends on:** Phase 13, Phase 34, Phase 38.

**Deliverables:**
- `fabric/gameplay/recipes/` — a `RecipeRefinedVoiditeShard` (1 Voidite → 1 refined shard, forge
  station) with structured `burst: { chance, damage }` data, and the refined-shard item where the
  fabric references it; `fabric/gameplay/professions/` gains structured unlock data for `VoidTouched`
  (two skill tiers plus a flag). `npm run generate` emits both for `GameData`.
- `src/crafting/crafting_slice.gd` — a recipe with `burst` rolls on the host from a deterministic
  `(world seed, player id, craft counter)` hash; a burst consumes the input, yields no output, deals
  `damage` to the crafter through the host-simulated HP (Phase 38) and, if the crafter survives,
  sets `voidBurstSurvivor` in the player's record flags. Clients never roll.
- `src/crafting/crafting_slice.gd` `_check_skill_guards` — skill guards that the fabric marks
  "not tutored, voidBurstSurvivor only" refuse with `requires_flag:voidBurstSurvivor`.
- Professions — a small `ProfessionSlice` (or a projection in `PlayerRegistry`) unlocks `VoidTouched`
  when Void Magic and Void Smithing are Expert and the flag is set, persisted on the record and synced
  to the owner only; recipes that name the profession check it.
- `src/core/bus.gd`, `src/networking/networking_slice.gd` — `void_burst_resolved` and
  `profession_unlocked` signals, owner-scoped on the wire.
- `ROADMAP.md` — the deferred `VoidTouched` bullet is marked delivered.

**Acceptance criteria:**
- [x] `npm run validate`, `npm run generate`, `npm run check-drift` green; `GameData` has the refining
  recipe with its burst data and the `VoidTouched` unlock data.
- [x] Suite: for a fixed seed and player the burst sequence is identical across runs, and its rate over
  10,000 crafts is within 1 percentage point of the authored chance.
- [x] Suite: a burst consumes the input, damages the crafter by the authored amount, and sets the flag
  only when the crafter survives; the flag survives a save/load.
- [x] Suite: a flag-gated skill guard refuses without the flag and passes with it; `VoidTouched`
  unlocks only when both tiers and the flag hold, and a recipe naming it is refused before.
- [x] Suite: a client's craft intent never rolls locally; the host's result reaches only the crafter.
- [x] Suite green on both boot paths, harness green.

---

## Phase 119 — An injected network transport and a compact per-tick wire form ✅ Done

**Goal:** the networking slice still carries its test seam (`_test_peers`, `_test_outbox`) in
production code, and every per-tick packet (`player_moved`, creature state) sends the verbose
`{chunk, local}` dictionary. Malformed peer packets warn without a throttle, are bounds-checked after
they have already been used, and a refused or clamped peer move only re-scopes on the next packet.
This phase puts the wire behind a small transport interface (ENet in the game, an in-memory transport
in the suite), adds a compact exact position encoding for per-tick packets, and resolves every item of
the networking triage issue below.

**Newel dependency:** NO.

**Depends on:** Phase 97, Phase 101.

**Closes:** #253.

**Deliverables:**
- `src/networking/transport.gd` (new), `src/networking/enet_transport.gd` (new),
  `src/tests/memory_transport.gd` (new) — a `Transport` interface (`peers()`, `send(peer, msg)`,
  `poll()`) that `NetworkingSlice` talks to; `_test_peers`, `_test_outbox`, `_test_seam_allowed` and
  the `_connected` / `_deliver` test branches leave `networking_slice.gd`; the suite injects the memory
  transport, and the injection point refuses outside a `GameRoot.should_run_tests` boot.
- `src/terrain/world_pos.gd`, `src/networking/networking_slice.gd` — a compact per-tick position form
  (packed chunk ints plus three floats, or a `PackedByteArray`) that round-trips the exact
  `{chunk, local}`; `player_moved` and creature state use it; the decoder validates before any use.
- `src/core/game_root.gd` `_on_remote_player_state` / `_route_c2h` — the non-finite and magnitude
  guards run before `aoi_region`; malformed-packet warnings go through a per-peer throttle; a refused
  or clamped `set_peer_center` re-sends the re-scope snapshot at once; `_fold_last_known_state` passes
  the exact dictionary into `remember_player_state`, drops the dead `_peer_window_chunk` guard, caps
  `_release_fold_hold` correctly and restreams once per fold; `canonical_world_pos` keeps heading and
  velocity and refuses a forged Z (#253, carrying #250 and #252).
- `src/terrain/chunk_manager.gd` `set_peer_center` — the first claim of an uncentred peer is clamped to
  the spawn window, and the rate limit and clamp compare seam-wrapped chunk differences.
- `src/persistence/player_registry.gd` — a refusal suppressed by the equip rate limit still sends one
  coalesced revoke; `note_equip_seq` accepts only increasing sequence numbers.
- `src/core/bus.gd` — `block_mine_requested` / `block_place_requested` arity matches their emitters;
  `block_edit_intent` carries the exact position, not a quantised float.

**Acceptance criteria:**
- [x] `grep -n "_test_peers\|_test_outbox" src/networking/networking_slice.gd` is empty; the suite's
  networking tests run on the memory transport; setting a transport in a non-test boot is refused
  (suite test).
- [x] Suite: the compact form round-trips `{chunk, local}` exactly at chunk X = 1,500,000 and at the
  seam; it is at least 30% smaller than the dictionary form in `var_to_bytes`; a truncated or
  non-finite packet is rejected before `aoi_region` is called.
- [x] Suite: 100 malformed packets from one peer produce at most one warning per throttle interval; a
  clamped peer move re-sends the re-scope snapshot in the same call.
- [x] Suite: an uncentred peer's first claim 1,000 chunks from spawn is clamped; a move across the X
  seam is rate-limited by the wrapped distance.
- [x] Suite: a rate-limited equip refusal still yields a revoke; a lower `seq` is ignored; mine/place
  signals are emitted with their declared arity.
- [x] Harness: all existing steps pass on the ENet transport with the compact per-tick form.
- [x] Suite green on both boot paths, harness green.

---

## Phase 120 — The distant ring draws recorded land ✅ Done

**Goal:** since Phase 113 a recorded chunk keeps its biome and corner heights across generator
versions, but `DistantTerrain` still samples the plain generator everywhere, so after a
`WORLDGEN_VERSION` bump the ring disagrees with the recorded land it surrounds and a seam shows where
near chunks meet it. The ring's request state is also spread across four fields, a worker started while
detached is never joined if the node is freed, and a worker lazily writes `TerrainSlice` static
caches. This phase feeds a snapshot of the ring's recorded corners to the worker, makes the ring's
lifecycle one record with a pre-delete join, and resolves every item of the distant-ring issue below.

**Newel dependency:** NO.

**Depends on:** Phase 113.

**Closes:** #255.

**Deliverables:**
- `src/terrain/distant_terrain.gd` `build_mesh` / `ground_at` — takes an immutable snapshot of the
  `ChunkRecords` corner heights and biomes inside the ring (taken on the main thread in `rebuild`) and
  uses a recorded chunk's corners and biome colour instead of the generator; unrecorded chunks keep
  the plain generator, as `CLAUDE.md` states.
- `src/terrain/distant_terrain.gd` — a revision of `ChunkRecords` newer than the built mesh's
  triggers one rebuild (debounced like a centre move); a main-thread `warm()` fills the
  `TerrainSlice.polar_ground` caches before any worker runs.
- `src/terrain/distant_terrain.gd` — `_built_*`, `_discarded`, `_queued` and `_task_args` fold into one
  request record; a `NOTIFICATION_PREDELETE` handler joins a worker started while detached;
  `_enter_tree` calls `_start(args, true)` directly; `builds_started` counts restarts from `poll` so
  its invariant holds; `main_thread_builds` moves to a test-visible counter object instead of a
  production static.
- `src/core/game_root.gd` `_process` — the ring rebuild key is cached in fields, not a formatted string
  per frame.
- `src/tests/test_suite.gd` — `_test_distant_ring_abort` frees an in-tree ring again (and a separate
  case covers detached); the detached-rebuild test asserts `_discarded` empty and `is_building()` false
  after `poll(true)`.

**Acceptance criteria:**
- [x] Suite: with a recorded chunk whose corners differ from the generator by 10 m, the ring's height
  at that chunk's corners equals the recorded corners exactly; an unrecorded neighbour equals the plain
  generator.
- [x] Suite: adding a record inside the ring after a build schedules exactly one rebuild.
- [x] Suite: freeing a detached ring with a running worker joins it (no leaked thread or orphan node);
  freeing an in-tree ring mid-build does not stall past the abort bound.
- [x] Suite: `builds_started == rebuilds_requested - rebuilds_dropped + restarts` across a queued
  restart; no static counter remains in `distant_terrain.gd`.
- [x] Suite: `polar_ground` caches are warm before the first worker build (a test counter proves no
  worker-side fill).
- [x] Suite green on both boot paths.

---

## Phase 121 — Crash-consistent saves ✅ Done

**Goal:** a save writes region files first and `world.json` second, but `world.json` is still written
after a region failure, a failed region re-marks every dirty chunk, region entries are only shallowly
validated, the streamer rescans everything every two seconds while a region is stranded and a
stationary server never retries one, and no test covers the world stamp going through a save job.
This phase makes a save one transaction (temp files, rename, a small commit marker), so a crash at
any step leaves either the old or the new world, and resolves every item of the persistence issue
below.

**Newel dependency:** NO.

**Depends on:** Phase 114.

**Closes:** #256.

**Deliverables:**
- `src/persistence/persistence_slice.gd` `_write_world_payload` — each file is written to a `.tmp`
  sibling and renamed; `world.json` is renamed only after every region rename succeeded, otherwise the
  previous `world.json` stays and the failed regions stay dirty; a load ignores and deletes stray
  `.tmp` files. `region_store` is built once and setters update it in place.
- `src/persistence/region_store.gd` — `write_chunks` re-marks only the chunks of the region that
  failed; `_chunk_entry_valid` checks each op's fields (kind, finite position, integer ids) and drops
  only the bad op with one warning.
- `src/persistence/region_streamer.gd` — `regions_for_chunks` expands only region-edge chunks (beyond
  the Phase 114 frontier margin); `sync` scans `edited_chunk_keys()` once; a stranded region is retried
  on a backoff timer independent of player movement, so a stationary server recovers it.
- `src/core/game_root.gd` — tests cover `_worldgen_stamp` carried into `_collect_save_job` and the bus
  signal emitted on load.

**Acceptance criteria:**
- [x] Suite: a fault-injected failure at each of the write steps (region tmp, region rename, world tmp,
  world rename) leaves a world that loads to either the full old or the full new state, never a mix.
- [x] Suite: a stray `.tmp` file is removed on load and does not shadow the real file.
- [x] Suite: one failing region of three leaves only its chunks dirty.
- [x] Suite: an entry with one malformed op loads its other ops and warns once.
- [x] Suite: `regions_for_chunks` for a window wholly inside one region returns that region only; a
  stranded region is retried after the backoff with no player movement; `edited_chunk_keys()` is called
  once per `sync`.
- [x] Suite: the world stamp round-trips through `_collect_save_job` and load emits the stamp signal.
- [x] Suite green on both boot paths, harness green.

---

## Phase 122 — Far terrain without mirroring and one scene-offset helper ✅ Done

**Goal:** `TerrainSlice.noise_coord` folds detail noise beyond 65,536 m with a triangle wave, so the
far world mirrors itself. Since Phase 113 a generator change only affects unrecorded land, so the fold
can now be replaced: a hashed per-cell offset keeps the noise input small without mirroring. The
remaining terrain and far-origin leftovers are folded in: eight slices copy the same `_scene_offset`
boilerplate, several `GameRoot` paths still read float32 positions, the corner cache locks a mutex on
every sample, and a set of duplicated constants and predicates remain. This phase resolves every item
of the terrain issue below.

**Newel dependency:** NO.

**Depends on:** Phase 113.

**Closes:** #254.

**Deliverables:**
- `src/terrain/terrain_slice.gd` `noise_coord` / `detail_of` — the fold becomes a per-cell hashed
  offset (cell size `NOISE_SPAN`, offsets from the world seed) blended across cell borders so detail
  noise is continuous and never mirrors; `WORLDGEN_VERSION` is bumped with a history line and the
  `_test_worldgen_golden` values are updated; recorded land is unchanged by the stable-world rule.
- `src/terrain/terrain_slice.gd` — `_corner_cache` is passed in per worker (no mutex per sample);
  `is_chunk_loadable` merges into `is_chunk_in_bounds`.
- `src/terrain/voxel_slice.gd` — one helper for the shaping-op check and corner offsets shared by
  `_commit_edits` and `seam_borders`; `blended_biome` / `shown_biome_at` blend corners and diagonals;
  `evict_clean_chunks` keeps the evicted chunk's deplete ops in `_vein_taken` and re-indexes only the
  released chunk; `water_mesh_for` scans only columns with water; `BEDROCK_DEPTH` follows the column's
  sea floor so deep ocean keeps the authored vein depth.
- `src/terrain/chunk_manager.gd` `rebuild_seam_neighbours` — the unused `skip` goes, and
  `rebuild_requests` moves to a test counter.
- `src/terrain/climate_field.gd`, `src/terrain/ore_field.gd`, `src/terrain/world_shape.gd` — header
  comments match the code; latitude cosine computed once; `OreField.warm()` latches only after
  `ClimateField.warm()` succeeds and `biome_for_chunk` before warm asserts instead of falling back;
  `SPAWN_CENTER` / `SPAWN_HEIGHT` come from one place; `oceanShare` drives the sea-level threshold or
  is removed from the fabric read.
- `src/core/scene_offset.gd` (new) — one `SceneOffset` helper used by the eight slices with
  `shift_scene`; `RebaseDriver` asserts on a target without it; `PlayerSlice.shift_scene` refuses a
  non-chunk-multiple shift and `place_at_world_pos` asserts a prior rebase.
- `src/core/game_root.gd` — `set_host_position`, `_build_snapshot` `within_aoi`, `_note_presence` and
  `_fold_last_known_state` use exact positions; `_clamp_to_world_exact` wraps in chunk space, not by
  adding a lap to a float; `_on_world_snapshot_received` refuses an invalid position (falls back to
  spawn) and canonicalises past the pole; `PlayerRegistry.record_world_pos` clamps `local` with chunk
  Z; `WorldPos.is_wire` accepts the first south fold row.

**Acceptance criteria:**
- [x] Suite: detail noise at x and at 2·`NOISE_SPAN` − x differ (no mirror) for 1,000 sampled points
  beyond 65,536 m, and the field is continuous across a cell border (max step below the authored
  bound); golden values updated with the version bump; a recorded chunk's heights are unchanged.
- [x] Suite: `grep -c "_scene_offset" src` finds it only in `scene_offset.gd`; `RebaseDriver` refuses a
  target without `shift_scene`; a non-multiple shift is refused.
- [x] Suite: corner and diagonal biome blends are symmetric; an eviction keeps deplete ops in
  `_vein_taken`; a deep-ocean column has the authored vein depth above bedrock.
- [x] Suite: snapshot AOI and presence use exact positions at chunk X = 1,500,000; a seam clamp leaves
  the float body within 1 m of the canonical position on the same frame; a snapshot with a bad
  position spawns at the spawn point; the first south fold row passes `is_wire`.
- [x] Suite: `OreField.warm()` retries until `ClimateField` is warm; `record_world_pos` clamps `local`.
- [x] Suite green on both boot paths, `npm run check-drift` green; harness result equals `origin/main` (CI is the gate: `tree_cleared` `no_spare_tree` fails identically on main in the local environment).

**Implementation notes (deviations from the deliverable list):** `noise_coord` is gone (cells of
2·`NOISE_SPAN`, `TerrainSlice.cell_offset`, 64 m blend). `_corner_cache` already took one lock per chunk;
the per-sample path (`get_height_at`) still locks. `is_chunk_loadable` was removed and the chunk manager
streams every row. `BEDROCK_DEPTH` is a constant -96 m (32 m under the lowest surface) rather than per
column. `water_mesh_for` already scans row spans; `evict_clean_chunks` already carries deplete ops in
`_vein_carry`/`_vein_taken`. `set_host_position`, `_fold_last_known_state` and `oceanShare` are unchanged
(`_clamp_to_world_exact` does not exist in this tree).

---

## Phase 123 — The player rig wears the character material and body masks ✅ Done

**Goal:** the private art repo ships a body detail sheet, a colour mask and a channel mask for the
player rig, and public placeholders exist for all three, but none of them reaches the rig: `attach_rig`
instances the glTF scene with no material (Godot's default material renders), and only `detail_tex`
is ever bound, on the procedural capsules. This phase binds the character shader and all three
textures on the rig through a rig material kept separate from the capsules' shared one, takes the
appearance's palette indices per instance, and resolves every item of the placeholder-tooling issues
below (the same generator and suite area), including the wall-clock chunk test that flakes on slow
runners.

**Newel dependency:** NO.

**Depends on:** Phase 59.

**Closes:** #314, #321, #324.

**Deliverables:**
- `src/character/character_material.gd` — a `rig_material(colors)` beside `shared_material`: one
  material per kind (capsules, rig), not one per character; per-instance `base_index` (skin colour)
  and `primary_index` / `secondary_index` / `accent_index` (outfit or defaults) set as instance
  shader parameters.
- `src/character/character_slice.gd` `attach_rig` — sets `material_override` on every
  `MeshInstance3D` of the rig scene: the character shader with `detail_tex` from
  `textures/characters/player.png.raw` (not `PLACEHOLDER_REL`), `color_mask_tex` and `channel_tex`
  from `textures/characters/player_color_mask.png.raw` / `player_channel.png.raw`, all loaded by key
  through `AssetOverlay.load_texture`; an appearance change re-applies the indices.
- `tools/gen_placeholder_glb.py` — `build_skinned_rig` stops rebinding the module globals
  (`JOINTS, REST, PARTS, PLAYER_CLIPS`) as locals and uses its parameter names; the scene root is named
  after the rig (not "PlayerRig" for the wolf); `SERPENT_CLIPS` `fall` gets a small curl instead of three
  identical keys; placeholders regenerated.
- `assets/README.md` — the creatures paragraph rewrapped; the rig texture keys documented.
- `src/tests/test_suite.gd` — `_test_asset_item_icon_placeholders` and
  `_test_asset_graywolfpack_placeholders` move above the `_test_asset_body_sheet_placeholders` doc
  comment; "chunk: the build split is measured" compares a work count or a ratio against the steady
  resolve instead of a fixed 16,667 µs wall-clock budget.
- The stray `.uid` files PR #320 added are checked: each one sits beside a tracked script (kept), any
  other is removed.

**Acceptance criteria:**
- [x] Suite: with the placeholders, every mesh of an attached rig carries the character shader as
  `material_override`, and `detail_tex`, `color_mask_tex` and `channel_tex` are all bound to the keys
  above.
- [x] Suite: two characters with different appearances share one rig material and differ only in
  instance parameters; the capsules still use `shared_material`; with the black placeholder masks the
  shader's colour inputs reduce to `base_index`.
- [x] Suite: the wolf placeholder rig's root is not named "PlayerRig"; the serpent `fall` clip has at
  least two distinct keys; `python3 tools/gen_placeholder_glb.py` regenerates byte-identical files.
- [x] Suite: the build-split test passes with an artificial 5× slowdown of the clock it reads (no fixed
  wall-clock budget).
- [x] Suite green on both boot paths, harness green.

---

## Phase 124 — Research points: the fabric's `researchCost` is enforced ✅ Done

**Goal:** every technology in the fabric carries a `researchCost` (research points), but the runtime
ignores it: research costs only materials and time (deferred from Phase 13). This phase gives each
player a host-owned research-point balance earned from play, makes `begin_research` spend
`researchCost`, persists the balance on the player record and shows it in the technology window. The
crafting path that earns points is the void-burst code from Phase 118, so its leftovers are resolved
here too.

**Newel dependency:** NO.

**Depends on:** Phase 34, Phase 118.

**Closes:** #299, #300.

**Deliverables:**
- `fabric/gameplay/technology/` — a `ResearchPointRule` table: points per source (`craft`, `gather`,
  `firstCraftOfRecipe`), with validators (non-negative integers); `npm run generate` emits it into
  `godot/`; a validator checks every technology's `researchCost` is reachable (≥ 0, below a bound).
- `src/technology/technology_slice.gd` — per-player `research_points` (host-owned); `begin_research`
  refuses with `insufficient_points` before consuming materials and spends `researchCost` on success;
  `grant_points(player_id, source, amount)` is host-only; saved and loaded with the per-player status
  snapshot (a legacy save without points loads as 0).
- `src/core/bus.gd` / `src/core/game_root.gd` — `research_points_synced(player_id, points)` sent only to
  the owner's peer; crafting and gathering resolutions on the host grant points by the fabric rule.
- `src/crafting/crafting_slice.gd` — the durable craft counter advances only after `consume_items`
  succeeds (a failed consume burns no draw, ordering documented); `_resolve_burst` is one guarded block
  that reports `flag` only after a successful grant (none for `player_id == ""`); `burst_roll` uses a
  custom integer mix instead of `hash(Array)`, pinned by golden values.
- `src/ui/` technology window — shows the balance and each technology's point cost; a research button
  is disabled with the reason when points are short.

**Acceptance criteria:**
- [x] `npm run validate` and `npm run check-drift` green with the rule table; a negative rule value
  fails validation.
- [x] Suite: research with too few points is refused with `insufficient_points` and consumes no
  materials; with enough points it spends exactly `researchCost`.
- [x] Suite: a craft on the host grants the fabric's points to the crafter only; a client's own grant
  call changes nothing; points round-trip through a registry save/load and a legacy record loads as 0.
- [x] Suite: a failed consume leaves the burst counter unchanged; the persisted counter survives a
  registry save/load and the next roll continues the sequence; `burst_roll` matches its golden values;
  `_resolve_burst` with `player_id == ""` reports no flag.
- [x] Harness: a step proves `research_points_synced` reaches only the owning client after a craft.
- [x] Suite green on both boot paths, harness green.

---

## Phase 125 — Waystones: a first fast-travel network ✅ Done

**Goal:** a planet takes about 90 days to walk around and the deferred list asks for a travel network.
The exact, host-authoritative teleport path from Phase 101 already moves a player anywhere on the
planet. This phase adds waystones: a craftable station a player attunes to by standing at it, and a
host-validated travel intent between two stones the player is attuned to, drawn and picked on the
full-map window. The map and teleport/chat leftovers are folded in, since the same window and the same
teleport path are touched.

**Newel dependency:** NO.

**Depends on:** Phase 101, Phase 111, Phase 117.

**Closes:** #290, #291, #297.

**Deliverables:**
- `fabric/` — a `Waystone` station item and recipe (existing profession and materials), a
  `WaystoneTravel` rule (attune radius, cooldown seconds, cost item and count per 1,000 km) with
  validators; regenerated into `godot/`, `bible/`, `wiki/`.
- `src/world/station_slice.gd` / new `src/world/waystone_slice.gd` — attunement recorded per player on
  the host and persisted on the player record; `waystone_travel_intent(from_id, to_id)` validated on
  the host (player within the attune radius of `from_id`, attuned to both, stones still exist,
  cooldown, cost paid from the player's inventory), resolved through the existing exact teleport; the
  owner receives `waystone_travel_resolved` with a reason on refusal; per-peer rate limit.
- `src/ui/map_window.gd` / `src/ui/minimap.gd` — attuned waystones drawn as markers; clicking one while
  at a waystone sends the intent; waypoints can be renamed; a right-click near the limb where
  `_world_pos_at_globe` does not converge shows a toast; a world-seed change saves the old seed's
  explored set and waypoints before clearing them.
- `src/core/chat_commands.gd` `parse_position` — Y range-checked against the `WorldPos.is_wire` local
  limit; the lap wrap / chunk split reuses `WorldPos`; the header comment no longer mentions
  `wrap_world`.
- `src/networking/networking_slice.gd` `send_teleport` — false when the peer is not connected or the
  emulator drops the packet.
- `src/chat/chat_slice.gd` — only non-broadcast admin commands bypass the bucket (`/say` does not);
  `_prune_buckets` bounds every bucket, not only idle ones; `_cmd_tp` / `_cmd_bring` report one failure
  string each for missing networking and unknown peer.
- `src/creature/creature_slice.gd` — the test-only `creature_table` seam and per-call `SpawnFields`
  allocation become a static helper.
- `src/tests/test_suite.gd` — `_find_coast` uses a stride that cannot skip a thin ocean strip, bounds its
  biome calls and updates `prev`; the chunk gather ceiling cannot exceed one frame on slow runners.
- `tools/check_readme_phases.js` — a multi-word status or a `|` in a title is parsed, not flagged.
- `src/tests/net_harness.gd` `_step_admin_teleport` — home recorded after load, the restore landing
  verified, `near` latched only after the chunk is loaded; a new `waystone_travel` step.
- `ROADMAP.md` — the Phase 101 text matches the bucket rule; the deferred "Fast travel" bullet points
  here.

**Acceptance criteria:**
- [x] `npm run validate` and `npm run check-drift` green with the waystone entities.
- [x] Suite: travel succeeds only when attuned to both stones, within the attune radius, off cooldown
  and with the cost in the inventory; each refusal reason is reported; a destroyed stone refuses; the
  landing is the exact destination at chunk X = 1,500,000.
- [x] Suite: attunements round-trip through a registry save/load; a client-forged intent for another
  player is refused.
- [x] Suite: a waypoint rename persists; a limb right-click that does not converge emits a toast; a
  seed change writes the old seed's file before clearing.
- [x] Suite: `parse_position` refuses a Y beyond the wire limit; `send_teleport` returns false for an
  unconnected peer and for an emulated drop; `/say` from an admin is bucket-limited; after a burst of
  distinct speakers `_prune_buckets` leaves at most the cap.
- [x] Suite: `_find_coast` finds a one-chunk ocean strip; `check_readme_phases.js --self-test` covers a
  multi-word status row.
- [x] Harness: `waystone_travel` moves the client between two stones over the socket; `admin_teleport`
  verifies the restore landing.
- [x] Suite green on both boot paths, harness green.

---

## Phase 126 — Tree clears the host keeps, and one seam-wrap module ✅ Done

**Goal:** since Phase 116 a tree cleared by building follows chunks onto clients, but the host's
`_cleared_local` is capped at 2,048 and evicts the oldest chunk's clears (those trees regrow, and the
host never saves them), a client drops unrecorded clears on despawn (ghost trees), and an unloaded
chunk's clear uses the plain-generator biome even when the frontier later records a transition biome,
so the pinned indices point at other trees. This phase makes the host's clears durable (adopted into
the chunk's generation record or saved), derives the client range from the snapshot scope, carries the
resolved edit tile instead of re-deriving it, and moves the duplicated seam-wrap helpers into one
module, resolving every item of the three tree issues below.

**Newel dependency:** NO.

**Depends on:** Phase 113, Phase 116.

**Closes:** #293, #294, #295.

**Deliverables:**
- `src/world/tree_slice.gd` — the host never evicts: a clear in an unrecorded chunk is recorded through
  the frontier path (so the biome and budget match the chunk's eventual record) or held in a saved
  pending set; the cap applies to clients only and evicts by recency with one warning;
  `CLEAR_ID_RANGE_CHUNKS` is derived from the snapshot `gen_scope` radius, and a client keeps an
  unrecorded clear until the host's record re-delivers it on return.
- `src/world/tree_slice.gd` `_on_edited_ground` / `_on_block_changed` — one `CLEAR_DEPTH_M` rule shared
  with `clear_trees_near_tile`; the edited tile comes from `VoxelSlice._resolve_edit_tile` (carried on
  `block_changed`), not from the float position and normal.
- `src/world/tree_slice.gd` — `get_all_stations()` fetched once per `spawn_for_chunk` and prefiltered to
  stations near the chunk; the lap-key lookup in `_clear_where` / `_clear_unloaded_chunk` resolved once
  per edit; `_near_loaded_chunk` indexes spawned chunks instead of scanning.
- `src/terrain/seam_wrap.gd` (new) — `_wrapped_delta` / `_wrapped_delta_f` / `_world_tiles` /
  `_world_metres` and their copies in `VoxelScript.canonical_tile` / `TerrainSlice.wrap_chunk` share one
  implementation.
- `src/persistence/region_store.gd` `normalize_gen` — a malformed `t` / `x` entry is dropped alone and
  logged once, the rest kept.
- `fabric/world/biomes/index.js` — the `treeDensity` validator bounds the noisy budget:
  `floor(GEN_TREE_MAX / (1 + DENSITY_NOISE))`, not the mean at 64.
- `src/tests/net_harness.gd` `_step_tree_cleared` — the target id is passed through a captured snapshot,
  and the host waits on the client's ack rather than a fixed 6 s.

**Acceptance criteria:**
- [x] Suite: 3,000 cleared chunks on the host keep every clear, and a save/load restores them; a
  client's cap evicts the least recently touched chunk and warns once.
- [x] Suite: a clear in an unloaded, unrecorded chunk next to recorded land whose frontier record picks
  a transition biome removes the same tree once the chunk loads.
- [x] Suite: a client that leaves and returns to a chunk with an unrecorded clear shows no ghost tree;
  the clear range equals the `gen_scope` radius.
- [x] Suite: a deep edit and `clear_trees_near_tile` agree on the same tree; an edit at chunk X =
  1,500,000 clears the tile `_resolve_edit_tile` picked.
- [x] Suite: `grep` finds the wrap helpers only in `seam_wrap.gd`; a `gen` with one malformed `t` keeps
  its other entries; a fabric `treeDensity` above the new bound fails `npm run validate`.
- [x] Harness: `tree_cleared` passes with an injected 5 s client lag.
- [x] Suite green on both boot paths, `npm run check-drift` green, harness green.

---

## Phase 127 — Terrain streaming, generation records and persistence cleanup sweep ✅ Done

**Goal:** the review leftovers of the generation records (Phase 113/114), the distant ring
(Phase 120), crash-consistent saves (Phase 121), far terrain (Phase 122) and the injected transport
(Phase 119) all touch the same code: `chunk_manager`, `chunk_records`, `region_store`,
`region_streamer`, `save_txn` and `game_root`'s record and peer-window paths. This sweep resolves every
item of each issue below.

**Newel dependency:** NO.

**Depends on:** Phase 119, Phase 121, Phase 122.

**Closes:** #287, #288, #302, #306, #307, #309, #317.

**Deliverables:**
- `src/terrain/chunk_manager.gd` — `flush_records_final` checks `write_chunks`, keeps failed keys
  pending and logs; one clock (`now_msec` / `set_clock`, no `_now`), so the flush backoff follows the
  injected clock; `_exit_tree` no longer clears the global `ChunkRecords` (GameRoot owns that); the
  deferred-record path does not spawn a plain-generator chunk that a later record rebuilds under the
  player's edits; `refresh` / `_retry_deferred_records` share one helper; `_in_bounds` removed;
  `first_claim_origin` set from the peer's spawn or saved chunk, or the first-claim clamp dropped.
- `src/terrain/chunk_records.gd` — `adopt_region` reports only ground changes (`_same_ground`), so
  tree-only differences do not rebuild meshes; `snapshot_near` keeps parsed coordinates or a per-chunk
  index instead of splitting every key under the mutex.
- `src/terrain/distant_terrain.gd` / `src/terrain/terrain_slice.gd` — `rebuild` checks a per-region
  revision instead of a deep compare; a records change inside the debounce window is picked up at
  expiry; `shape_height` looks a record up directly instead of building a snapshot per call;
  `NOISE_OFFSET_RANGE` doc matches `cell_offset`.
- `src/terrain/frontier.gd` `corner_height` — the blend cutoff leaves no step on diagonals.
- `src/terrain/climate_field.gd`, `src/terrain/world_pos.gd`, `src/terrain/chunk_record_sync.gd` — doc
  comments sit on the functions they document; `WORLDGEN_VERSION` history notes the 24 m of extra
  ground below the old bedrock floor.
- `src/terrain/world_pos.gd` `pos_from_compact` — length checked before base64 decode.
- `src/persistence/region_store.gd` — `fold_chunks`' empty-edit branch keeps the `is_newer_gen` guard;
  `recover()` removed or made journal-aware; `read_region` reports changes through a flag from
  `_drop_bad_ops`.
- `src/persistence/region_streamer.gd` — `regions_for_chunks` snapshots record keys once; the stranded
  backoff is per region and resets on success.
- `src/persistence/save_txn.gd` / `persistence_slice.gd` — a read during `commit` falls back to the
  `.bak`; the journal removal result is checked before `.bak` cleanup; a stale `.bak` is told apart from
  the current one; a permanently failing region escalates after a bound instead of blocking
  `world.json` forever; the recovery flag is locked so a main-thread load cannot delete a worker's
  staged files; the in-place mode runs recovery on write.
- `src/core/game_root.gd` — `_add_generation_records` rate-limits by window, not only when records were
  sent; the fingerprint stamp is not overwritten after the mismatch notice; a client rebuilds loaded
  chunks whose records `gen_scope` pruned; a refused or clamped peer move returns before building a
  snapshot; `_release_fold_hold` extends the hold once before giving up.
- `src/networking/networking_slice.gd` / `transport.gd` — a per-tick packet is decoded once; the
  emulator queue stores a serialised copy at enqueue; one transport flag replaces `poll()` /
  `is_memory()` / `stamps_seq()`.

**Acceptance criteria:**
- [x] #287: an older incoming gen never overwrites a newer stored gen in `fold_chunks`; a failed final
  flush keeps its keys pending; the fingerprint stamp survives a mismatch load; a tree-only adopt
  rebuilds no mesh.
- [x] #288: a jittery client sending window moves with no records is rate-limited; a pruned record's
  loaded chunk is rebuilt from the generator; a diagonal frontier corner has no step above the authored
  bound; freeing one manager leaves another's records intact.
- [x] #302: a refused peer move builds no snapshot; a 40-character compact position is refused before
  decoding; a per-tick packet is decoded once (counter); the emulator delivers the payload as it was at
  enqueue.
- [x] #306: `snapshot_near` on a 100,000-record table does no key splitting (counter).
- [x] #307: a records change inside the debounce window reaches the ring at expiry; `shape_height` with
  records allocates no snapshot (counter).
- [x] #309: a read during commit sees the old file, never "missing"; a stale `.bak` is not restored over
  a newer commit; a region failing past the bound escalates and `world.json` is written; a worker's
  staged files survive a concurrent load; a second stranded region starts at the base backoff.
- [x] #317: `_in_bounds` is gone; the doc comments sit on their functions (checked by the suite's
  doc-comment audit or a grep test); `NOISE_OFFSET_RANGE` matches `cell_offset`'s range.
- [x] Suite green on both boot paths, harness green.

---

## Phase 128 — Weather: the fabric's `WeatherSystem` runs on the host ✅ Done

**Goal:** `fabric/world/weather.js` describes weather as an emergent world system (rain, storm,
blizzard, fog, ash-fall, void-storm) driven by each biome's `avgTemperature` / `avgRainfall` and the
season, but no runtime code reads it: the sky never changes. This phase makes weather a deterministic
function of the world seed, the region, the biome and the world clock's in-game hour, so every host and
client computes the same state without a per-tile sync; the host owns overrides, and the first
gameplay effects (outdoor movement speed, visibility) are applied on both boot paths.

**Newel dependency:** NO.

**Depends on:** Phase 51, Phase 54.

**Deliverables:** (the `WeatherState` table lives in `WeatherSystem.rules.states`, validated by `weatherProblems` in `fabric/world/weather.js`; `tools/check_weather.js` proves bad tables fail in CI; the HUD weather label is appended to the minimap clock line)
- `fabric/world/weather.js` — a `WeatherState` table (id, `moveSpeedFactor`, `visibilityFactor`,
  `minTemperature` / `maxTemperature`, `minRainfall`, weight) and `WeatherSystem` fields
  (`cellSizeChunks`, `hoursPerRoll`, `overrideMaxHours`), with validators (factors in 0–1, weights
  ≥ 0, every biome reaches at least one state); `npm run generate` emits them into `godot/`, `bible/`,
  `wiki/`.
- `src/world/weather_slice.gd` (new) — `weather_at(chunk, hour) -> String`, a pure function of seed,
  weather cell (`cellSizeChunks`, wrapped on X like the rest of the planet), cell biome, season and the
  hour bucket, using an integer mix pinned by golden values; `VoidRift` cells roll only `void_storm` /
  `clear`; `current_for(position)` reads the world clock; an override table (cell → state, end hour)
  owned by the host, saved with `world.json` and synced to clients on join and on change.
- `src/core/bus.gd` / `src/core/game_root.gd` — `weather_override_requested` (host-only) and
  `weather_overrides_synced`; `weather_changed(state)` emitted locally when the player's cell state
  changes; the slice wired on both boot paths.
- `src/player/player_slice.gd` — outdoor walking speed is multiplied by the state's
  `moveSpeedFactor` (not while swimming; not under a roof span within 4 m above the head).
- `src/chat/chat_slice.gd` / `src/core/chat_commands.gd` — an admin `/weather <state> <hours>` sets an
  override on the admin's cell, bounded by `overrideMaxHours`, logged; a non-admin is refused.
- `src/ui/` — a HUD weather label beside the clock, and the environment's fog density scaled by
  `visibilityFactor` (client only; the headless server creates no environment).

**Acceptance criteria:**
- [x] `npm run validate` and `npm run check-drift` green; a `moveSpeedFactor` of 1.5 or a biome that
  reaches no state fails validation.
- [x] Suite: `weather_at` matches golden values for five (chunk, hour) pairs, is equal at chunk X and
  X + one planet lap, and is constant within one `hoursPerRoll` bucket.
- [x] Suite: over 10,000 sampled cells, a desert cell never rolls `blizzard`, a `VoidRift` cell rolls
  only `void_storm` or `clear`, and each state's share is within 5 percentage points of its weight
  among the states its biome allows.
- [x] Suite: in a `storm` cell, outdoor walking speed is `SPEED × moveSpeedFactor`, swimming speed is
  unchanged, and a player under a placed roof span walks at full speed.
- [x] Suite: `/weather storm 2` from an admin overrides the cell for two in-game hours and reverts
  after; a value above `overrideMaxHours` and a non-admin sender are refused; the override survives a
  save/load.
- [x] Harness: a `weather_override` step proves an admin override reaches the second client.
- [x] Suite green on both boot paths, harness green.

---

## Phase 129 — Combat status effects: burn, paralysis, knockback, knockdown and stagger ✅ Done

**Goal:** `CombatSystem.applyStatusEffects` and several creatures' attacks in the fabric name status
effects (LavaSlug heat-burn, VeilStalker paralysis, ForestBoar knockback, knockdown, stagger), but they
exist only as rule text: `BattleSlice.resolve_round` deals plain damage. This phase turns the rules into
a structured fabric table, applies effects on the host when a hit lands, ticks them on the host,
persists the ones a player can log out with, and shows them on the HUD. Rain from Phase 128 extinguishes
heat-burn, as the fabric rule says.

**Newel dependency:** NO.

**Depends on:** Phase 38, Phase 128.

**Deliverables:** (the table is `CombatSystem.statusEffects`, validated by `statusEffectProblems`/`onHitProblems` in `fabric/gameplay/combat.js`; `tools/check_combat.js` proves bad tables fail in CI; knockdown is also what CinderGargoyle's claw rolls; stagger has no creature source yet, only the table row; the HUD shows text labels in the top-right corner)
- `fabric/gameplay/combat.js` — a `StatusEffect` table (id, `durationSeconds`, `damagePerSecond`,
  `immobilize`, `damageTakenFactor`, `displaceTiles`, `stacks`, `extinguishedBy` weather states) and an
  `onHitEffects` field (`[{ effect, chance }]`) on the creatures whose attack rules name one; validators
  (chance in 0–1, an `onHitEffects` entry names a defined effect, non-stacking effects have
  `stacks: false`); regenerated.
- `src/battle/status_effects.gd` (new) — `apply(target_id, effect_id, now)` (refresh, not stack, when
  `stacks` is false), `tick(now) -> Array` of damage events, `damage_factor(target_id)`,
  `is_immobilized(target_id)`, `clear(target_id)`; the chance roll uses a seeded integer mix of
  (round seq, attacker, target), pinned by golden values.
- `src/battle/battle_slice.gd` — a landed hit rolls the attacker's `onHitEffects`; `resolve_round`
  multiplies damage by `damage_factor`; knockback moves the target by `displaceTiles` along the attack
  direction on the host, clamped to walkable ground; death and respawn clear every effect.
- `src/core/bus.gd` / `src/core/game_root.gd` — `status_effects_synced(target_id, effects)` sent to the
  target's own peer only; DoT ticks go through the host's simulated peer HP (Phase 38), never
  client-owned; a burning target in a weather state listed in `extinguishedBy` loses the burn.
- `src/player/player_slice.gd` / `src/creature/creature_ai.gd` — an immobilized player or creature
  does not move; stagger cancels the current action.
- `src/persistence/player_registry.gd` — active effects with their remaining seconds saved on the
  player record; a legacy record loads with none.
- `src/ui/` — HUD status icons with remaining time (text labels when no icon key exists; placeholders
  added under `assets/` for any icon key the art repo will use).

**Acceptance criteria:**
- [x] `npm run validate` and `npm run check-drift` green; an `onHitEffects` entry naming an undefined
  effect fails validation.
- [x] Suite: heat-burn deals `damagePerSecond × durationSeconds` total over its duration and then ends;
  reapplying a non-stacking effect refreshes the timer without doubling damage.
- [x] Suite: a knocked-down target takes `damageTakenFactor` × damage; a paralyzed player's movement
  input moves nothing for the duration; knockback never lands inside solid voxels.
- [x] Suite: the on-hit roll matches its golden values; over 10,000 seeded rolls VeilStalker's paralysis
  rate is within 1 percentage point of 20%.
- [x] Suite: a burning player whose cell turns to `rain` loses the burn on the next tick; death clears
  all effects; effects round-trip through a registry save/load and a legacy record loads with none.
- [x] Harness: a `status_effect` step proves the effect reaches only the target's client and that the
  DoT lowers the host's simulated HP for that peer.
- [x] Suite green on both boot paths, harness green.

---

## Phase 130 — Creatures walk on the ground and around obstacles

**Goal:** `CreatureAI._move_instance` steps a creature in a straight 3D line toward its target; the
ground height is read only at spawn, so a chasing creature floats over valleys, sinks into hills and
walks through placed walls and stations. The deferred list asks for path-finding (deferred from
Phase 15). A baked `NavigationAgent3D` mesh does not fit a streamed voxel world with a headless server,
so this phase gives creatures a host-side, bounded grid path over the voxel columns: each step follows
the walkable surface, a step taller than the creature can climb or deep water is routed around, and the
cost per tick is capped.

**Newel dependency:** NO.

**Depends on:** Phase 15, Phase 40, Phase 78.

**Deliverables:**
- `fabric/world/creatures/shared.js` — per-creature `maxStepMetres`, `canSwim`, `pathRadiusTiles` (with
  defaults and validators); regenerated.
- `src/creature/creature_path.gd` (new) — `find_path(from_tile, to_tile, rules, surface) -> Array` A*
  over tiles within `pathRadiusTiles`, a step allowed when the height difference ≤ `maxStepMetres` and
  the tile is not water unless `canSwim`; works on exact `WorldPos` tiles across the X wrap; returns a
  partial path toward the closest reached tile when the goal is unreachable; a node-expansion cap.
- `src/creature/creature_ai.gd` — chase, flee, patrol and companion follow move along the path; every
  step sets Y from the voxel surface (`VoxelSlice` column top, not the generator height, so mined pits
  and placed blocks count); a path is recomputed when the target moves more than two tiles or the next
  tile's column changed (`block_changed`); a per-tick budget of path searches shared by all creatures,
  overflow waits for the next tick in a round-robin queue.
- `src/creature/creature_slice.gd` — a creature in an unloaded chunk freezes instead of moving on
  generator heights; `set_instance_position` keeps the visual transform on the surface.
- `src/tests/net_harness.gd` — the existing creature-sync step asserts the client's creature Y equals
  the host's surface height.

**Acceptance criteria:**
- [ ] `npm run validate` and `npm run check-drift` green; a negative `maxStepMetres` fails validation.
- [ ] Suite: a creature chasing a player across a valley stays within 0.1 m of the surface at every
  step; a 3 m placed wall between them is walked around, not through.
- [ ] Suite: a non-swimming creature never enters a water tile; a goal on an island returns a partial
  path ending at the nearest shore tile.
- [ ] Suite: a search in a fully walled pocket stops at the expansion cap; with 200 creatures chasing
  at once, path searches per tick never exceed the budget and every creature has moved within
  `ceil(200 / budget)` ticks.
- [ ] Suite: a chase across the X wrap at chunk X = 1,500,000 takes the short way round.
- [ ] Harness green with the creature-height assertion; suite green on both boot paths.

---

## Phase 131 — Loose ground settles: sand and soil fall when undermined

**Goal:** the deferred list keeps a cellular automaton for loose materials (from the GDVoxelPlayground
evaluation). Today a player can mine out the ground under a beach and leave the sand hanging, or build
a floating sand pillar. This phase marks granular materials in the fabric and runs a host-side settling
pass on dirty columns only: a granular span with air below falls to the first support, the result goes
through the existing authoritative voxel edit path (persisted in the region store, synced to clients),
and the pass is bounded per tick so a large collapse spreads over several ticks.

**Newel dependency:** NO.

**Depends on:** Phase 12, Phase 52, Phase 121.

**Deliverables:**
- `fabric/world/materials/` — a `granular` boolean on materials (`Sand`, `Soil`, `Snow` true; rock,
  ores and metals false), with a validator that every biome `surfaceMaterial` declares it; regenerated.
- `src/terrain/settle.gd` (new) — a pure `settle_column(spans, granular) -> spans` that drops each
  unsupported granular span onto the next solid span below, keeping material and total volume; a
  `SettleQueue` of dirty columns (from `block_changed` on the host: the edited column and its four
  neighbours), processed in a deterministic order with a per-tick column budget.
- `src/terrain/voxel_slice.gd` — on the host, a settled column is written through the same edit path as
  a mine or place (region store, `block_changed`, client sync), marked as a settle edit so it grants no
  item and costs no material; clients never settle on their own.
- `src/terrain/voxel_slice.gd` / `chunk_manager.gd` — neighbour seam rebuilds follow settled columns;
  a settle in an unloaded neighbour chunk is queued until the chunk loads, not dropped.
- `src/world/tree_slice.gd` — a tree whose ground falls more than `CLEAR_DEPTH_M` is cleared through
  the Phase 116 path.
- Generated (unedited) terrain is not settled: only edited columns enter the queue, so world-gen output
  and `WORLDGEN_VERSION` are unchanged.

**Acceptance criteria:**
- [ ] `npm run validate` and `npm run check-drift` green; a biome whose `surfaceMaterial` lacks
  `granular` fails validation.
- [ ] Suite: `settle_column` keeps per-material volume; a sand span over air lands on the first solid
  span; a rock span over air does not move; settling an already-settled column is a no-op.
- [ ] Suite: mining the stone under a 5-block sand stack on the host leaves no granular span over air
  after the queue drains; the result survives a region save/load and the worldgen golden values are
  unchanged.
- [ ] Suite: a 1,000-column collapse never processes more than the per-tick budget and finishes within
  `ceil(1000 / budget)` ticks; a settle in an unloaded neighbour applies when that chunk loads.
- [ ] Suite: a client's local edit enqueues nothing; a settle edit grants no item.
- [ ] Harness: a `sand_settles` step mines under sand on the host and proves the client's column
  matches the host's after sync.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 132 — Internationalization: translated UI and keyed host messages

**Goal:** translation support is mandatory for every project (workspace rule). Today every
player-facing string in `src/` is a hard-coded English literal, and the host sends rendered text
(chat system lines, admin replies, toasts) to clients. This phase routes all UI text through Godot's
`TranslationServer` with English and Brazilian Portuguese catalogs, lets the player switch language
at runtime, and changes host-originated messages to a key plus arguments so each client renders
them in its own locale. Adding a language afterwards is data-only (a new catalog file).

**Newel dependency:** NO. Localized fabric content (item, creature, skill names) follows in a later
phase once Newel can emit translation catalogs (see Deferred).

**Depends on:** none.

**Deliverables:**
- `locale/ui.csv` (new) — Godot CSV translation catalog with `en` and `pt_BR` columns and stable
  snake-case keys (`hud.health`, `inventory.title`, `chat.system.player_joined`, ...);
  `project.godot` registers the imported translations and sets the fallback locale to `en`.
- `src/ui/`, `src/core/`, HUD, inventory, technology tree, crafting, map, chat and admin UIs — every
  player-facing literal becomes `tr("key")` (or `tr_n` for plurals, `String.format` placeholders for
  arguments); no concatenated sentences.
- `src/core/locale_settings.gd` (new) — chosen locale persisted in user settings, picked from saved
  preference → OS locale → `en`; `GameBus.locale_changed` re-renders open UI without a restart; a
  language selector in the settings/pause menu.
- Wire: host-originated chat/system/admin/toast messages carry `{key, args}` instead of text; the
  client validates the key against its catalog (unknown key → generic fallback line, never raw
  input) and bounds `args` count and length like other network input.
- Number and date formatting through one helper that follows the active locale.

**Acceptance criteria:**
- [ ] Suite: `en` and `pt_BR` columns of every catalog have the same key set and no empty cells.
- [ ] Suite (audit): no string literal is assigned to `.text`, `.tooltip_text`, `.title` or
  `.placeholder_text` in `src/` outside `tr()`; an allow-list file covers non-translatable cases
  (numbers, debug overlays) and each entry carries a reason.
- [ ] Suite: switching locale emits `locale_changed` and the HUD/inventory projections return
  pt-BR text; the choice survives a settings save/load round trip; an unsupported OS locale falls
  back to `en`.
- [ ] Suite: a host system message serializes as key + args; a client renders it per locale; an
  unknown key, too many args or an oversize arg is refused with the fallback line.
- [ ] Harness: a two-process run with host `en` and client `pt_BR` shows the joined-player chat
  line in Portuguese on the client.
- [ ] Suite green on both boot paths, `npm run check-drift` green, CI green.

---

## Deferred (in priority order)

- **Localized fabric content** — entity names and descriptions (items, creatures, skills,
  technologies) translated through catalogs generated by Newel (`../newel/ROADMAP.md` Phase 15),
  consumed with the Phase 132 locale settings.

- **Server sharding (final, not before maturity)** — split the authoritative
  simulation across multiple servers by region / spatial partition so total
  population exceeds one process. Deferred to LAST: it is a horizontal-scaling
  concern that only pays off once a single headless server (Phase 27) plus
  spatial hashing (Phase 28) and interest management (Phase 29) are already
  saturating. No structural change is required *before* the game matures to
  make sharding possible — the Phase 27 sim/visual split and the Phase 28
  hash are the prerequisites, and both are already planned ahead of it. Revisit
  when Brazil-region load approaches one server's ceiling.

- **Rivers, lakes and fluid flow** — water above sea level and flowing water
  (the cellular-automaton idea from the GDVoxelPlayground evaluation) follow
  Phase 51's static sea level. **(falling sand and soil planned: Phase 131; water remains.)**
- **Fast travel** — a planet takes about 90 days to walk around. Some form of
  travel network (roads, boats, waystones) is needed once players spread out
  (after Phase 53). **(Phase 125 added waystones; roads and boats remain.)**
- **Voxel techniques from GDVoxelPlayground (evaluated, not adopted wholesale)** —
  <https://github.com/JorisAR/GDVoxelPlayground> (MIT) ray-marches a FIXED 128³
  voxel grid on the GPU via `RenderingDevice` compute. It does not fit Nihon,
  which has an unbounded streamed world, a headless server with no
  `RenderingDevice`, seed-deterministic CPU terrain, sparse-run columns with
  trimesh collision, and per-edit authority and persistence. Three techniques
  are worth borrowing later, each CPU-side and deterministic:
  - a **cellular automaton** for sand, water and lava, run on dirty chunks
    only;
  - **WFC** for ruins, villages and dungeons;
  - a **brick occupancy map** if meshing becomes the bottleneck.

- **Public wiki deployment** — VitePress (or equivalent) static-site deployment
  and CI-triggered wiki regeneration from the fabric (deferred from Phase 9).
- **Research cost points** — the abstract `researchCost` points field is modelled
  in the fabric but not enforced at runtime (deferred from Phase 13). **(closed: Phase 124 — `begin_research` spends `researchCost` from a host-owned balance earned by the `ResearchPointRule` table.)**
- **`VoidTouched` special-case unlock** — the void-burst survivor unlock trigger
  is defined in the fabric but not wired to any runtime event (deferred from
  Phase 13). **(closed: Phase 118 — a refining craft can burst, survivors get
  `voidBurstSurvivor`, and `ProfessionSlice` unlocks `VoidTouched`.)**
- **Station placement UI** — **(closed: placement is grid-snapped to 1 m cells and
  refuses overlap via `StationSlice.try_place_station`; N toggles a translucent
  green/red preview ghost and V places at the aimed top face or the player's feet.
  A full build-mode menu remains out of scope.)**
- **NavigationAgent3D path-finding** — creature movement currently uses direct
  kinematic stepping; replacing it with nav-mesh baked from voxel terrain and
  `NavigationAgent3D` per-instance requires the chunk-streaming world from
  Phase 17 to produce stable nav-mesh regions (deferred from Phase 15).
  **(planned: Phase 130 replaces it with a host-side grid path over voxel columns.)**
- **WAN / cross-region multiplayer testing** — all Phase 18–19 multiplayer
  validation is loopback or LAN (deferred from Phase 19).
- **Automatic LOD mesh decimation** — simplified meshes are hand-authored;
  runtime decimation deferred from Phase 23.
- **Dynamic impostor re-bake** — impostor billboards are offline-baked; live
  palette-change re-bake deferred from Phase 23.
- **Peer damage over the wire** — a creature aggros and chases a remote peer, but
  the host opens no combat round against it: damage to a peer belongs to that
  peer's own client, and the host has no simulation of a peer's HP to hit or
  persist. Needs a host → client damage event plus per-peer HP ownership on the
  peer's side (deferred from Phase 36). **(delivered in Phase 37: the round is routed
  by target id, `player_damaged` carries the target, and the host sends the hit to the
  peer's own client. What remains is making a peer's HP authoritative rather than
  client-owned.)** **(closed in Phase 38: the host simulates the peer's HP itself and
  persists it on the peer's record. `player_damaged` stays a display update — a client
  that ignores it now diverges from the host's number instead of owning it.)**
- **Peer equipment replication** — **(closed in Phase 47: the host records each
  peer's worn set and the bare-hands rule reads it; late joiners are announced to
  their AOI, and the two-client harness step `equipment_recorded` proves the
  intent over a real socket.)**
