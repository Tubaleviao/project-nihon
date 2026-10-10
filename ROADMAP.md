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
| 100 | Follow-up issue backlog triage | Planned | below |
| 101 | Chat and admin commands are host-authoritative, exact and proven on the wire | Planned | below |
| 102 | An admin `/kill` lands on the host's simulated peer health | Merged | [Phase 101](#phase-101--chat-and-admin-commands-are-host-authoritative-exact-and-proven-on-the-wire) |
| 103 | Teleports carry the exact position and stay on the planet | Merged | [Phase 101](#phase-101--chat-and-admin-commands-are-host-authoritative-exact-and-proven-on-the-wire) |
| 104 | Two-client harness: chat and admin teleport over the socket | Merged | [Phase 101](#phase-101--chat-and-admin-commands-are-host-authoritative-exact-and-proven-on-the-wire) |
| 105 | Archive Phases 75–95 into the roadmap history | Merged | [Phase 99](#phase-99--housekeeping-sweep-legacy-tiles-roadmapreadme-hygiene-and-review-leftovers) |
| 106 | A world stamp that covers fabric parameters, and golden generator values | Planned | below |
| 107 | A per-chunk generation record in the region store | Planned | below |
| 108 | Terrain reads and writes the generation record on the host | Planned | below |
| 109 | Generation records reach clients, scoped and validated | Planned | below |
| 110 | Trees are pinned per chunk and cleared where players build | Planned | below |
| 111 | The minimap remembers what was explored and marks home | Planned | below |
| 112 | A biome adjacency table in the fabric and an offline scan | Planned | below |
| 113 | Frontier generation: a new generator version meets recorded land | Planned | below |

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

## Phase 100 — Follow-up issue backlog triage

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
- [ ] `gh issue list --state open --author @me --search "Follow-ups from PR in:title"` and the same
  for "Phase 50" list only issues created by this phase or listed under a Planned phase's **Closes:**.
- [ ] Each new area issue carries the `autopilot-followup` label, an `Area:` line and at least one
  unchecked item; no area has two.
- [ ] Every closed source issue has a closing comment that accounts for each of its items.

---

## Phase 101 — Chat and admin commands are host-authoritative, exact and proven on the wire

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
  per interval. The host's own local player is subject to it too, admins included. The clock is
  injectable, like `ChunkManager.set_clock`; the bucket entry is erased when the peer disconnects.
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
- [ ] Suite: with a fake clock, a client sending `CHAT_BURST + 10` lines in one tick has exactly
  `CHAT_BURST` broadcast, `chat_rate_refused` raised by 10 and one notice sent to it alone; after
  `1 / CHAT_LINES_PER_SEC` seconds of fake time one more line is accepted; a disconnect removes the
  player's bucket entry.
- [ ] Suite: an admin's `/kill` on a connected peer leaves `PlayerRegistry.get_hp(peer_id)` at 0 (the
  `simulated_hp_after_hit` floor) and sends exactly one `player_damaged` to that peer; after that peer
  disconnects and reconnects, its restored HP is the simulated value, not `MAX_HP`.
- [ ] `grep -rn "send_player_damaged(" src --include=*.gd | grep -v -e game_root.gd -e networking_slice.gd -e test_suite.gd -e net_harness.gd`
  finds nothing.
- [ ] Suite: `/bring` of a peer to a local player at chunk (1,500,000, 3) local (0.25, 10, 0.75) sends a
  teleport that decodes on the client to that chunk and a local within 1e-3 m; `/tp <peer>` by the
  local admin lands the body at the peer's exact chunk, local within 1e-3 m.
- [ ] Suite: `/tp 0 10 z` with `z` one chunk past `TerrainSlice.pole_chunks()` is refused and no
  teleport is emitted; `/tp x 10 0` with `x` = 2.5 laps lands at the wrapped X; a `teleport` packet with
  a malformed position is dropped on the client and the body does not move.
- [ ] `tools/net_harness.sh` reports 18/18 steps passed (the 15 existing plus the three above), both
  roles agree on every `compare: true` step, and each new step fails when its host-side handler is
  stubbed out in a scratch copy (noted in the PR body). CI's harness job runs the new steps.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 106 — A world stamp that covers fabric parameters, and golden generator values

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
- [ ] Suite: the fingerprint is stable across two calls and across a `warm()` reset; changing
  `ridgeAmplitude` in a scratch resource changes it.
- [ ] Suite: a world record with a different fingerprint raises `worldgen_fingerprint_mismatch` exactly
  once; a record without one raises nothing and is stamped on the next save.
- [ ] Suite: the golden detail-noise values match to 1e-6; the shape and biome values match exactly.
- [ ] `npm run validate`, `npm run check-drift` green; suite green on both boot paths.

---

## Phase 107 — A per-chunk generation record in the region store

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
- [ ] Suite: a `gen` record round-trips through `save_region` / `load_region` with heights equal to 1e-4.
- [ ] Suite: a version-1 region file loads unchanged, and a save of it writes version 2 with its edits intact.
- [ ] Suite: a malformed `gen` is dropped, its chunk's edits survive, and the warning fires once for two loads.
- [ ] Suite: a region with 1,024 recorded chunks and no edits serialises to under 100 KB.
- [ ] Suite green on both boot paths.

---

## Phase 108 — Terrain reads and writes the generation record on the host

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
- [ ] Suite: with no records, the heightmap hash and biome of 64 chunks equal their pre-phase values
  (the Phase 106 goldens plus a recorded hash).
- [ ] Suite: a stub record with another biome and shifted corner heights makes `biome_for_chunk` and
  `generate_heightmap` return the record's values for that chunk and the generator's for its neighbours.
- [ ] Suite: a chunk streamed into a window gets exactly one record, and a second load rewrites nothing.
- [ ] Suite: building a ring writes no record; a client-role `ChunkManager` writes none either.
- [ ] Suite: `OreField` asked from a worker thread for a recorded chunk gets the recorded biome.
- [ ] Suite: with the recorded chunk's `v` set to an older number, its output is unchanged.
- [ ] Suite and `--server` / `--quit-after-boot` boots green; harness green.

---

## Phase 109 — Generation records reach clients, scoped and validated

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
- [ ] Suite: a snapshot for a peer carries records for its window only; one for a far peer carries none of them.
- [ ] Suite: a record with a biome key outside `BIOME_KEYS`, a NaN height or a height above `max_height`
  is dropped and the rest of the packet applies.
- [ ] Suite: a packet over the cap applies the first `cap` records and counts the rest as refused.
- [ ] `tools/net_harness.sh`: the host records a chunk with a different biome than the generator would
  pick; the client reports the host's biome and heights, and both roles agree on the step.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 110 — Trees are pinned per chunk and cleared where players build

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
- [ ] Suite: placing a block on a tree's tile removes the tree; after unloading and reloading the chunk,
  and after a save and load, it is still gone.
- [ ] Suite: placing a station within `CLEAR_RADIUS_M` clears the trees inside the radius and none outside.
- [ ] Suite: a recorded chunk keeps its tree count when the biome's `treeDensity` is changed in a scratch resource.
- [ ] Suite: a client receiving `tree_cleared` frees the tree's collision and its MultiMesh slot; the
  orphan-node check stays clean.
- [ ] Suite: a chopped-and-regrowing tree is unaffected: the stump still regrows after its cooldown.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 111 — The minimap remembers what was explored and marks home

**Goal:** even when land is stable, a player who wanders off needs a way back. The minimap already
keeps a fog-of-war record of visited chunks (`_revealed`), but only in memory, so a relog starts blank.
It also has no marker for the player's own base.

**Newel dependency:** NO.

**Depends on:** Phase 87.

**Deliverables:**
- `src/ui/minimap.gd` — the revealed set is saved per world (keyed by the world seed) under
  `user://saves/client/`, loaded on start, with a cap on stored chunks (oldest dropped first) and runs
  encoded per row so a long walk stays small. Writes are debounced.
- A home marker at the player's recorded respawn point (Phase 87): an icon on the map, and when the point
  is off the map a direction arrow clamped to the edge with the distance. The clamp is a pure static
  function so the suite can pin it.

**Acceptance criteria:**
- [ ] Suite: a revealed set round-trips through save and load; a file for another seed is ignored.
- [ ] Suite: the cap drops the oldest chunks, and 10,000 contiguous chunks encode to under 20 KB.
- [ ] Suite: the home clamp returns the point itself when inside the map, and an edge position on the
  line toward it, with the right distance, when outside; it is exact at 1,500,000 chunks from the origin.
- [ ] Suite: a missing or corrupt file starts an empty set and warns once.
- [ ] Suite green on both boot paths.

---

## Phase 112 — A biome adjacency table in the fabric and an offline scan

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
- [ ] `npm run validate` fails on a scratch fabric with an unknown key, an asymmetric pair or a
  forbidden pair with no transition, and passes on the real one.
- [ ] `npm run generate`, `npm run check-drift` green.
- [ ] Suite: the scan finds zero forbidden pairs across all grids.
- [ ] Suite: the scan finds a violation when a scratch envelope is made to place two forbidden biomes
  side by side (the check can fail).
- [ ] Suite green on both boot paths.

---

## Phase 113 — Frontier generation: a new generator version meets recorded land

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
- [ ] Suite: after changing `WorldShape`'s warmed `ridgeAmplitude` and `heightSpline` (standing in for a
  new version), every recorded chunk's biome and heights are unchanged.
- [ ] Suite: a new chunk next to a recorded one shares its corner heights exactly; the largest height
  step between adjacent corners across the blend band is below a stated bound.
- [ ] Suite: a new chunk at least `BLEND_CHUNKS` from any recorded chunk equals the plain new generator.
- [ ] Suite: the adjacency scan (Phase 112) around a recorded block, with the changed generator, finds
  zero forbidden pairs.
- [ ] Suite: two hosts given the same records and generator produce identical records for a chunk.
- [ ] Harness: the client receives a frontier record and agrees with the host.
- [ ] Suite green on both boot paths, harness green.

---

## Deferred (in priority order)

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
  Phase 51's static sea level.
- **Fast travel** — a planet takes about 90 days to walk around. Some form of
  travel network (roads, boats, waystones) is needed once players spread out
  (after Phase 53).
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
  in the fabric but not enforced at runtime (deferred from Phase 13).
- **`VoidTouched` special-case unlock** — the void-burst survivor unlock trigger
  is defined in the fabric but not wired to any runtime event (deferred from
  Phase 13).
- **Station placement UI** — **(closed: placement is grid-snapped to 1 m cells and
  refuses overlap via `StationSlice.try_place_station`; N toggles a translucent
  green/red preview ghost and V places at the aimed top face or the player's feet.
  A full build-mode menu remains out of scope.)**
- **NavigationAgent3D path-finding** — creature movement currently uses direct
  kinematic stepping; replacing it with nav-mesh baked from voxel terrain and
  `NavigationAgent3D` per-instance requires the chunk-streaming world from
  Phase 17 to produce stable nav-mesh regions (deferred from Phase 15).
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
