# Roadmap history — Phases 20–32

Completed phases, archived unchanged from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 20 — Skeleton rig and animation ✅ Done

**Goal:** Bring the animation spec from `characters.md` to life: a rigged
humanoid skeleton with a locomotion decision layer driven by the player
controller's real speed every frame, with per-family facing rate (`turnSpeed`)
sourced from the fabric.

**Newel dependency:** None. Animation spec is complete from Phase 7.

**Deliverables:**
- Base humanoid skeleton rig (`CharacterBody3D` + `Skeleton3D`) with standard
  bone hierarchy matching the `SkeletonDefinition` taxonomy in `characters.md`
- `src/character/character_slice.gd` — wires fabric `GameData.CHARACTERS`
  (skeletons, appearances) to runtime `MeshInstance3D` + `Skeleton3D`
  construction; exposes `apply_equipment(slot, item_key)` and
  `clear_equipment(slot)`
- Socket attachment system: equipment meshes attached at named sockets; SKINNED /
  RIGID / HYBRID deformation modes
- A locomotion decision layer (`characters.md` §37) — state machine
  (`idle / walk / run / fall / land / attack / death`) plus a continuous
  idle↔walk↔run blend curve — driven by the player controller's real speed
  every frame; a real `AnimationTree`/authored clips are asset-production work
  this layer is designed to plug into, not yet built
- Approximate foot IK: terrain-sampled whole-body vertical offset (not a
  per-leg bone solver — see Known simplifications)
- Per-family `turnSpeed` facing: the body rotates to face its movement
  direction at a fabric-defined rate instead of snapping or strafing

**Acceptance criteria:**
- Player character animates through idle → walk → run transitions based on speed ✓
- Attack and death animations play on the correct bus signals ✓
- Foot IK keeps feet approximately flush with terrain (whole-body offset, not
  per-leg placement — see Known simplifications) ✓
- Socket-attached equipment deforms correctly in SKINNED mode, stays rigid in
  RIGID mode ✓

**Implementation notes:**
- `src/character/locomotion.gd` — a pure, headless-testable locomotion state
  machine (`IDLE / WALK / RUN / FALL / LAND / ATTACK / DEATH`) mapping horizontal
  speed → state with timed attack/land one-shots and a terminal death state. A
  real `AnimationTree` would consume `get_state()` + `get_blend_weight()` to pick
  and blend skeletal clips — no such node exists yet; the decision logic lives
  here so transitions are unit-testable without a renderer.
- `src/character/skeleton_rig.gd` — builds a real `Skeleton3D` from the fabric
  `SkeletonDefinition` (`bones` ordered chain, parents precede children), reading
  `restPose`, `bodyShapeCoefficients`, and `turnSpeed` from the resource (not
  hardcoded) and scaling each bone's rest offset per its bone group (legs by
  `legLength`, arms by `armLength`, head by `headScale`, etc. — `characters.md`
  §8) instead of a single uniform height factor. Resolves sockets → bones
  (§5) and attaches equipment with deformation modes (§10): SKINNED/HYBRID
  follow the socket's bone via `BoneAttachment3D`, RIGID stays a rig-root child.
  `SkeletonRig.compute_landmarks()` centralizes the body-shape math (torso
  height, hip height, hand/socket offsets, leg reach) so the placeholder mesh,
  socket offsets, and foot IK all derive the same landmarks from one source
  instead of three independently-drifting copies.
- `character_slice.gd` now assembles every character with a `Skeleton3D` rig,
  exposes `apply_equipment(slot, item_key)` / `clear_equipment(slot)`, drives the
  per-instance locomotion state machine, and emits `character_state_changed`.
  `sync_player_avatar()` binds the player's own visual avatar to the real
  `PlayerSlice` controller every frame — position, facing (turnSpeed-limited
  rotation toward horizontal velocity), locomotion state, and foot IK — instead
  of the avatar spawning at a fixed offset and never moving. `game_root` forwards
  the player's combat (`combat_round_requested`) and death (`player_died`) into
  `character_attack_requested` / `character_death_requested`.
- Foot IK (`SkeletonRig.compute_foot_targets`) samples terrain under both feet
  and clamps each to the terrain surface within leg reach — pure and
  headless-testable against a `Callable` terrain sampler. `sync_player_avatar`
  uses the higher foot to offset the whole body vertically (not a per-leg
  solver — see Known simplifications) and stashes both foot targets as root
  metadata for a future real IK pass to consume.
- Body (chest/legs, or the generic non-humanoid body box) and head are skinned
  to the skeleton via `BoneAttachment3D`, so they deform with the bone chain.
  Hair and beard remain rig-root placeholder `BoxMesh` children (not bone-
  attached) pending real mesh + `Skin` asset production.

**Known simplifications (deferred to Phase 22):**
- Palette and material system not yet wired (placeholder albedo only).
- LOD simplification not yet applied (full-detail mesh at all distances).
- No blend-shape facial customization.
- No authored animation clips / `AnimationPlayer` / `AnimationTree` playback —
  the state machine and blend curve drive transitions and cross-fade weights,
  but no clip data or blend-tree node exists; that is asset-production work.
- No root motion — the player controller drives `CharacterBody3D.velocity`
  directly from input, not from extracted animation displacement.
- Foot IK is a whole-body vertical offset from the higher sampled foot, not an
  independent per-leg two-bone solver; legs do not visibly bend to match
  terrain slope.
- No sheathe/draw clips, dual-wield/two-handed upper-body layer, or emotes yet
  — `characters.md` §37.6–§37.8 specify the intended design, not a built
  system.

---

## Phase 21 — Asset separation and public placeholders ✅ Done

**Goal:** Keep production art private while the public repo clones and runs
clean. A private asset submodule (Git LFS) is packed into a `.pck` that mounts
over `res://` at startup and replaces the committed placeholders — the same
mechanism that will carry paid DLC packs later.

**Newel dependency:** None.

**Deliverables:**
- Production art lives in a private repo (`project-nihon-assets`), added to this
  repo as the `assets-prod/` git submodule (HTTPS remote, so
  `--recurse-submodules` doesn't require SSH credentials); large binaries are
  tracked with Git LFS inside that repo, which also carries a `.gdignore` so
  Godot's scanner never touches it in place.
- `assets/` — ugly placeholders committed at canonical `.raw`-suffixed paths
  (`assets/textures/placeholder_character.png.raw`) so a public clone resolves
  every asset reference with no missing-resource errors. The `.raw` suffix
  keeps Godot's importer from claiming the file, so its bytes survive a real
  export and are readable via `FileAccess` — a plain `.png` would not be.
- `tools/build_pck.sh` — stages a plain copy of `assets-prod/` into a
  disposable pack-only project (`tools/pack_project/`) and calls Godot's own
  exporter (`godot --export-pack`) over it, producing `assets.pck` with
  entries under `res://_overlay/…` (a `.pck` is the unit of optional
  content — the DLC monetization model). Exits non-zero on any packing
  failure — there is no separate custom packer script to silently swallow one.
- `export_presets.cfg` — "Linux"/"Windows Desktop" presets exclude both
  `assets-prod/*` and `_overlay/*` from the shipped game, splitting the
  public/Steam build from the private-asset-adjacent build tooling.
- `src/core/asset_overlay.gd` (autoload) — mounts `assets.pck` over `res://` at
  startup; `resolve_path(rel)`/`load_texture(rel)` prefer the mounted
  `res://_overlay/<rel>` override, falling back to the public placeholder at
  `res://assets/<rel>`. `character_slice.gd` is wired to `load_texture()` as
  the first real runtime consumer.
- `tools/gen_placeholder.py` — deterministically regenerates placeholder art.
- Build policy: Steam/release bundles `assets.pck` (mounted from next to the
  binary); the public/GitHub build ships placeholders only.
- No code references a private-only path — production art is addressed only via
  the public `res://assets/…` prefix and the pack's own `res://_overlay/…`
  namespace, both safe to ship; `_test_asset_no_private_paths_hardcoded`
  recursively scans `src/` to enforce this.

**Acceptance criteria:**
- A fresh `git clone --recurse-submodules` of the public repo opens and runs in
  Godot — placeholders present, no missing-resource errors ✓
- Production art is absent from the public repo (only the submodule pointer) ✓
- `assets.pck` is gitignored and never committed ✓
- `_test_asset_pck_round_trip_override` builds a fixture pck with `PCKPacker`,
  mounts it, and asserts the override is actually served — not just that the
  relevant constants look right ✓

Resolved: the import-pipeline limitation described in earlier drafts of this
phase (raw overlay files not working for recognized resource types) is fixed
by the `.raw` suffix convention above, rather than deferred to Phase 22. See
`assets/README.md` for the full mechanism.

---

## Phase 22 — Material and palette pipeline ✅ Done

**Goal:** Implement the pixel-art material system from `characters.md`: Primary /
Secondary / Accent masks, Metal + Emission + Wear channels, and per-instance
palette swaps without extra draw calls.

**Newel dependency:** None. The palette was already authored in the fabric
(`GameData.PALETTES`, one `DefaultPalette` with 256 hex entries).

**Deliverables:**
- `src/character/character_material.gdshader` — a custom spatial `ShaderMaterial`
  that samples a shared `256×1` palette texture by per-instance colour index.
  Primary / Secondary / Accent regions are driven by a `color_mask_tex`
  (R/G/B); Metal / Emission / Wear channels are driven by a `channel_tex`
  (R/G/B), each max()'d with a per-instance scalar so the placeholder build
  (no authored masks) still works — scalars now, authored masks later, one
  shader.
- `src/character/character_material.gd` — builds the shared palette
  `ImageTexture` (256×1, no mip-maps) and ONE shared `ShaderMaterial`, and
  exposes `set_index` / `get_index` for per-instance palette swaps (§20) via
  `set_instance_shader_parameter`.
- `src/character/character_slice.gd` — `_make_box` / equipment assembly now
  reference the shared `ShaderMaterial` and write per-instance palette indices +
  channel scalars instead of a per-part `StandardMaterial3D` albedo tint;
  `get_part_material`, `get_part_shader_parameter`, `get_palette_texture`, and
  `apply_palette_index` expose the pipeline to tests and tooling. Metal tones
  resolve to a metals-region palette index (§21, region bounds read from the
  generated palette's `regions` field); wear derives from the durability tiers
  (§23); emission resolves a palette index in the emission region from the
  per-item `emissionColor` field (§22); roughness varies by metal tone + wear
  (§21).
- Pixel-art texture constraints enforced on the shader's samplers
  (`filter_nearest`, `repeat_disable`, no mip-maps) rather than import presets —
  Point filtering is guaranteed independent of per-machine texture-filter
  settings.
- `characters.md` extended with §41.1 production checklist sign-offs:
  resolution table, Point filtering settings, UV mapping guide.
- `src/tests/test_suite.gd` — 5 new tests: shared 256×1 palette texture,
  palette-swap shader-parameter round-trip, shared shader resource, wear
  derived from durability, and palette-driven metal channel.

**Acceptance criteria:**
- Palette swap changes character color without creating a new texture asset ✓
- Two characters with different palettes share ONE `ShaderMaterial` + palette
  texture (per-instance shader parameters, no new material per character) ✓
- Parts with identical geometry share ONE `BoxMesh` per distinct size ✓
- Pixel-art textures render without bilinear blurring (Point filter enforced on
  the shader samplers) ✓
- Wear channel visually degrades equipment as durability decreases (wear derived
  from the §23 durability tiers) ✓

**Implementation notes:**
- The palette lives in `GameData.PALETTES` (tag `palette`), not
  `GameData.CHARACTERS` — the earlier roadmap draft named the wrong group. The
  fabric `DefaultPalette` is fixed at 256 entries and `_color_index` /
  `CharacterMaterial._idx` clamp indices to `[0, 255]`, so the one-byte palette
  cap (§19) holds without a generator change.
- The placeholder build authors no mask textures, so `color_mask_tex` and
  `channel_tex` default to black: parts render their `base_index` colour and
  channels fall back to the per-instance scalars. A real asset binds a mask
  texture and the same shader composites it — the pipeline is the point, not
  the placeholder art.

**Known simplifications (deferred to Phase 23):**
- LOD mesh switching not yet tied to this material system.
- Emission colour is palette-driven (per-item `emissionColor` index) but static;
  dynamic glow (e.g. enchantments) deferred.
- Authored mask textures (Primary/Secondary/Accent/Metal/Emission/Wear) are not
  yet produced — the placeholder drives colour through per-instance scalars.
- The fragment shader mixes palette samples and multiplies by the detail texture
  and wear desaturation in continuous RGB space, so the rendered colour can
  drift off-palette (§19); snapping the output to the nearest palette entry is
  deferred.

---

## Phase 23 — LOD and composition simplification ✅ Done

**Goal:** Apply the `minLodLevel` attachment rules from `characters.md` so
character rendering scales gracefully with draw distance and player count.

**Newel dependency:** None.

**Deliverables:**
- `src/character/character_slice.gd` — LOD manager: at runtime, evaluate each
  `CharacterBody3D`'s screen-space size or world distance and set the active LOD
  level (0 = full, 1 = medium, 2 = impostor)
- Per-attachment `minLodLevel` respected: accessories and high-poly details hidden
  at LOD 1; full socket set collapsed to body-only at LOD 2
- Simplified meshes at distance > 20 m (LOD 1 threshold) and > 60 m (LOD 2 /
  impostor billboard)
- Impostor billboard: a camera-facing coloured quad rendered in place of the full
  rig at LOD 2 (a placeholder for the deferred pre-baked sprite, see below)
- `src/tests/test_suite.gd` — tests: LOD level transitions at distance thresholds,
  attachment visibility toggling, impostor swap correctness

**Acceptance criteria:**
- Full-detail rig renders within 20 m; simplified mesh between 20–60 m; impostor
  beyond 60 m ✓
- `minLodLevel` attachments are hidden at their specified threshold (no earlier) ✓
- Impostor billboard uses the correct palette for the character instance ✓
- Frame time with 20 remote characters at 60 m is measurably lower than 20 full
  rigs ✓ (delivered by the impostor swap — 20 rigs collapse to 20 flat
  billboards; not benchmarked headless, see Implementation notes)

**Implementation notes:**
- LOD levels collapse to the Phase 23 three-tier model (0 = full, 1 = medium,
  2 = impostor); `MAX_LOD` is now 2 and `IMPOSTOR_LOD` is 2. The `characters.md`
  §35 table's LOD3 (extreme distance) folds into the impostor tier.
- Per-part LOD is stored as `max_lod` — the COARSEST level at which a part still
  renders (`node.visible = lod <= max_lod`), so the name reads as a max, not a
  min. Fine detail (hair, beard) is `max_lod` 0 (hidden at LOD 1); coarse body
  geometry is `max_lod` `MAX_LOD` (visible through the impostor tier). The fabric
  `minLodLevel` field carries the same "coarsest level" semantics on the old 0–3
  scale and defaults to `MAX_LOD` when absent.
- `CharacterSlice.update_lod(viewer_pos)` switches to distance-driven (`LOD_AUTO`)
  evaluation and is called every frame from `game_root._process` with the player
  position. `set_lod(level)` applies a manual level immediately (`LOD_MANUAL`)
  for the test suite and debug tooling, but it is NOT a persistent override — the
  next `update_lod` call re-asserts distance-driven mode. `lod_level_for_distance()`
  is the threshold function (≤20 m → 0, ≤60 m → 1, else 2) with a `LOD_HYSTERESIS`
  (2 m) dead-zone: dropping to a finer level only commits once inside the margin,
  preventing boundary flicker. `_apply_lod` early-outs when neither the resolved
  level nor the hideRegions hidden set changed since the last frame.
- The impostor is a camera-facing `QuadMesh` (`billboard_mode` enabled, unshaded)
  tinted to the character's skin palette colour via `palette_color()`. The colour
  is resolved ONCE at creation (a baked colour), so a palette-texture swap is NOT
  reflected here — a true pre-baked sprite impostor is deferred (see below). The
  quad mesh is cached by size and the material by skin colour. `_apply_lod` shows
  the impostor and force-hides every part at `IMPOSTOR_LOD`, regardless of each
  part's `max_lod`.

**Known simplifications (deferred):**
- LOD mesh generation is manual (artist-authored); no automatic mesh decimation.
- Pre-baked sprite impostor — the billboard is a coloured-quad placeholder, not a
  pre-baked render of the rig; palette-swap applied to the billboard texture and
  runtime re-bake on palette change are deferred.
- No per-platform LOD bias (mobile vs. desktop thresholds are identical).

---

## Phase 24 — Social systems and player economy ✅ Done

**Goal:** Ground the `CommunityOwnsTheFuture` and `EconomyIsPlayerDriven`
constitution principles in real game mechanics: trade, social skills, and
community governance hooks.

**Newel dependency:** None. Social skill tree already defined in
`fabric/gameplay/skills/social.js`.

**Deliverables:**
- `src/trade/trade_slice.gd` — player-to-player trade: propose trade (items +
  quantities), counter-offer, accept/reject; secured via host authority in
  multiplayer; emits `trade_completed` on the bus
- `src/world/market_slice.gd` — persistent world market: players list items at
  a price; other players browse and buy; listings expire after configurable
  duration; market data is part of the world save snapshot
- Social skill effects wired: `Trade` skill tier sets the trade broker fee;
  `Leadership` unlocks guild formation; `Lore` unlocks advanced wiki entries
- `src/governance/proposal_slice.gd` — in-game proposal system mirroring the
  constitution's `CommunityOwnsTheFuture` principle: players submit proposals,
  others vote within a window; ratification requires a quorum of distinct voters
  and a threshold fraction in favour (authors cannot self-vote); accepted
  proposals emit a fabric decision event (the fabric decision state machine:
  `proposed → accepted → superseded`)
- UI panels for trade, market, and proposals wired into `ui_slice.gd`

**Acceptance criteria:**
- Two players can complete a trade; inventory reflects the exchange on both sides ✓
- Market listings persist across save/load ✓
- Social skill tier visibly affects a trade or leadership action ✓
- Proposal system allows submission, voting, and ratification; accepted proposals
  update a runtime decisions log ✓

**Implementation notes:**
- **Trade broker fee** is the concrete Trade effect: the local player's Trade
  tier determines the fraction of received goods withheld as a broker fee
  (fabric `TradeSystem.brokerFee`: novice 10% → master 0%). Diplomacy is scoped
  to NPC factions in the fabric and does not affect player-to-player trade.
  Balance numbers live in `fabric/gameplay/economy.js`, not hardcoded constants.
- **`Lore` skill does not exist in the fabric** — `fabric/gameplay/skills/social.js`
  defines only `Diplomacy`, `Trade`, `Speechcraft`, and `Leadership`. The
  `Lore`-unlocks-wiki hook is therefore deferred until a `Lore` skill is
  authored (see Known simplifications).
- **`Leadership` guild-formation gate** is implemented as
  `ProposalSlice.can_form_guild(tier)` (apprentice or higher). Guild formation
  itself (the guild entity, roster, permissions) is deferred — only the skill
  gate is wired.
- **No currency model exists yet.** Market `price` is an abstract numeric value
  recorded on the listing; a buy transfers the item to the buyer and removes
  the listing, but no currency changes hands. Currency exchange is deferred
  until the fabric defines an economy token.
- **Trade resolution is inventory-symmetric** via a pluggable party-inventory
  map (`set_party_inventory`): the local player uses `inventory_slice`; tests
  inject a second `InventorySlice` to model the remote side, so "both sides"
  exchange is asserted directly.
- **Market expiry** is wall-clock: `get_listings` filters by `expires_at` (a
  Unix-epoch timestamp, not process uptime), and a runtime tick calls
  `expire_listings()` to remove lapsed listings, refund their escrow to the
  seller, and emit `market_listing_expired`. The save snapshot carries
  `listed_at`/`expires_at`, so a restored listing keeps its real deadline
  across sessions. The default lifetime is fabric
  `MarketSystem.defaultExpirySeconds`.
- **Ratification** requires quorum + threshold + window (fabric
  `GovernanceSystem.ratification`: threshold 0.6, quorum 3, window 86400 s): a
  proposal ratifies only once at least `quorum` distinct voters have cast
  ballots within the voting window and the for-fraction reaches the threshold.
  The author cannot vote on their own proposal, so a single author cannot
  self-ratify. A ratified proposal records into the runtime decisions log and
  emits `proposal_ratified`.

**Known simplifications (deferred):**
- **Currency exchange** — `price` is metadata only; no economy token is
  transferred on buy/sell (no currency model in the fabric yet).
- **`Lore` skill** — not authored in the fabric; the "Lore unlocks advanced
  wiki entries" hook needs a `Lore` skill entity first.
- **Full guild system** — `can_form_guild` gates formation, but guild entity,
  roster, and permissions are not built.
- **Trade UI** — a single-player demo flow (a seeded merchant) lets a player
  start and complete a trade; a full two-player / NPC negotiation UI is still
  deferred.
- **Market listing escrow** — listings now escrow the seller's goods (debited on
  list, transferred on buy, refunded on expiry); a listing is still not an
  escrowed *currency* reserve because there is no currency model.
- **Delta-based state sync** — the market, governance, and trade slices
  broadcast their *full* state (`market_synced` / `governance_synced` /
  `trade_synced`) on every mutation. That is simple and correct for now, but a
  populated world will outgrow it — full-state broadcasts should be replaced
  with per-mutation deltas (or a dirty-field diff) once lists grow.
- **Per-peer inventory** — multiplayer has a single shared inventory: the host's
  `inventory_slice` is synced to every client (`inventory_synced` /
  `replace_contents`). Party identity is now peer-scoped (a client's
  "player" resolves to `peer_<id>` on the host, never the host's own
  inventory), so a remote client's market purchase / trade fails closed rather
  than crediting the host. Actually delivering to a remote player needs a
  per-peer inventory store + per-peer sync, which is still deferred.

---

## Phase 25 — Tool and equipment repair ✅ Done

**Goal:** Close the last Phase 16 "Known simplification": broken tools could not
be repaired. Repairable equipment now has a fabric-authored repair spec and a
runtime repair flow that consumes materials, gates on skill + station, and
restores the item to pristine.

**Newel dependency:** None. Reuses the existing `json` field type (already
emitted by `generator-godot`); no generator change needed.

**Deliverables:**
- `fabric/gameplay/items/shared.js` — a `repairData()` helper returning a
  structured `repair` json field: `{ station, materials: [{item, quantity}],
  skillGuards: [{skill, tier}] }`. This mirrors `recipeData()` and makes the
  repair cost a fabric value, not a GDScript constant.
- `fabric/gameplay/items/{tools,weapons,armor}.js` — every non-stackable
  equipment item gains a `repair` field transcribed from its prose `repair`
  behavior rules (e.g. FerritePick → `forge` + 1 FerriteIngot + Smithing novice;
  VeilsteelLongsword → `master forge` + 1 VeilsteelIngot + Smithing journeyman;
  AethermiteBow → `arcane forge` + ThornwoodPlank + AethermiteDust + ArcaneForging
  apprentice).
- `src/inventory/inventory_slice.gd` — `repair_item(item_id)` restores a held
  durable item's durability to its fabric maximum (pristine), failing closed for
  non-durable / un-held items.
- `src/crafting/crafting_slice.gd` — `repair(item_id)` / `can_repair(item_id)` /
  `get_repair_spec(item_id)`. Reuses the existing skill-guard and station-gate
  checkers (`_check_skill_guards` / `_check_station_gate`) so repair obeys the
  same fail-closed gates as crafting: `not_repairable` / `no_inventory` /
  `no_item` / `already_pristine` / `skill_requirement:<skill>:<tier>` /
  `station_required:<type>` / `missing_inputs`. Materials are consumed atomically,
  then durability is restored.
- `src/core/bus.gd` — `repair_requested(item_id)` / `repair_resolved(result)`
  signals.
- `src/ui/ui_slice.gd` — a "Repairs" section in the crafting window listing held,
  repairable, non-pristine items with a Repair button wired through the bus;
  `repair_rows()` is a pure, headless-testable projection.
- `src/tests/test_suite.gd` — 8 repair tests (spec load, restore-to-pristine,
  material consumption, skill guard, station gate, pristine rejection,
  non-durable rejection, broken-tool-via-bus).

**Acceptance criteria:**
- Repair cost/station/skill come from the fabric `repair` field, not hardcoded ✓
- A worn/broken tool is restored to pristine by consuming its repair materials ✓
- Repair obeys the same skill + station gates as crafting, fail-closed ✓
- A pristine item is not repairable (no wasted materials) ✓
- Repair is reachable through the bus (`repair_requested` → `repair_resolved`) ✓
- All 8 repair tests pass at startup ✓

**Durability model (final, do NOT revert):** the per-instance durability array
**is** the durable stack — `InventorySlice._durability[item_id]` holds one
entry per held instance, and its `.size()` is the held quantity. Non-durable
(stackable) items keep their count in `_contents`; durable items live ONLY in
`_durability`. There is no separate per-item shared value, so the earlier
"one shared value per item_id × stack_count" design must not be reintroduced
(repair cost and wear both derive from the per-instance array). Cross-slice
transfers use the static `InventorySlice.transfer(src, dst, counts)`, which
carries the exact removed per-instance values; `replace_contents` resolves a
durable item's array via `_worst_values` (keep the worst instances on a shrink,
pad a short payload with its carried value, warn + grant fresh when a payload
omits a durable item).

**Known simplifications (deferred):**
- **VoiditeEdge / VoidRuneTablet repair** — their prose repair rules reference a
  "refined voidite shard" (not modelled as an item/material) and gate on the
  VoidTouched profession (not wired). They carry no `repair` field and return
  `not_repairable` until those entities exist.
- **Per-condition-tier cost** — the fabric prose says e.g. "one ingot per
  condition tier restored"; the structured spec collapses this to a flat
  full-repair cost (restore straight to pristine for a fixed material spend).
- **AethermiteBow multi-tier repair** — the prose offers a separate string-only
  repair and a full stave repair; the spec models the full stave repair only.

---

## Phase 26 — Client-side rendering instancing ✅ Done

**Goal:** Collapse the per-entity scene-tree nodes and draw calls (one
`MeshInstance3D` + `StandardMaterial3D` + `Node3D` per creature / remote
player) into shared `MultiMeshInstance3D` renders so client rendering scales
with entity count instead of dying at a few hundred nodes.

**Newel dependency:** None.

**Deliverables:**
- `src/creature/creature_slice.gd` — creatures render through a single shared
  `MultiMesh` keyed by creature type. Each creature is one instance transform +
  a per-instance `COLOR` custom-data entry (the type tint, replacing the
  per-node `StandardMaterial3D` albedo). Death hides the instance (zero-scale
  transform) instead of `body.visible = false`; movement updates the instance
  transform instead of a `Node3D.position`. The `body` field in an instance
  record becomes an opaque `transform index`, not a live `Node3D`.
- `src/player/player_slice.gd` — remote player ghosts render through a shared
  `MultiMesh` (one instance per peer) rather than a `CapsuleMesh` node each.
- A `MultimeshPool` helper (or per-slice equivalent) that owns the
  `MultiMeshInstance3D` + material per entity type and maps instance index ↔
  entity id, so callers never touch raw `MultiMesh` internals.

**Acceptance criteria:**
- N creatures of one type produce ONE draw call (one `MultiMeshInstance3D`), not N ✓
- Per-type tint survives the swap (per-instance `COLOR`, no new material per creature) ✓
- Creature movement + death hide round-trip through instance transforms ✓
- Remote player ghosts share one `MultiMesh` ✓
- All existing creature/ghost tests pass unchanged ✓

**Implementation notes:**
- Per-instance colour uses `MultiMesh` custom-data (`INSTANCE_CUSTOM` →
  `COLOR`) with a single shared `StandardMaterial3D` whose
  `vertex_color_use_as_albedo` is on, mirroring the per-column vertex-colour
  terrain pattern (SKILL.md). This is the `MultiMesh` analogue of the Phase 22
  palette `instance uniform` — one material, per-instance data.
- The pool is the seam for the Phase 27 headless server: a headless server
  builds NO `MultiMeshInstance3D` (the pool is a no-op), so the same
  `creature_slice` data model drives both a rendered client and a bare sim.

**Known simplifications (deferred):**
- Creature animation (idle/walk cycles) via `MultiMesh` is not modelled — the
  current box placeholders are static; per-instance animation would need a
  `MultiMesh` custom-data shader or a per-type animation texture.

---

## Phase 27 — Headless data-oriented server ✅ Done

**Goal:** Decouple the authoritative simulation from rendering so a dedicated
server process can run the whole world — creatures, AI, combat, voxel, economy —
as plain data with no `SceneTree` visual nodes, no viewport, and no
`MeshInstance3D`/`Skeleton3D` construction. This is the structural change that
must land before the population grows, because every later scale feature
(spatial hashing, interest management, sharding) assumes the sim no longer
drags a render graph behind it.

**Newel dependency:** None.

**Deliverables:**
- A simulation/rendering split flag (e.g. `GameRoot.headless_server`) selected
  by a `--server` command-line arg. When set, `game_root` skips building the
  player avatar, character rigs, lighting, and environment, and does NOT spawn
  the local `CharacterBody3D` + camera.
- `creature_slice` stores entity state data-oriented (parallel arrays / a flat
  record dict with NO `body: Node3D`), and the Phase 26 `MultimeshPool` is the
  only renderer — null on a headless server. Movement/AI/death mutate the data
  record; a client-side pool mirrors it visually.
- `player_slice` remote-player state is pure data on the server (no ghost
  bodies); the client builds ghost `MultiMesh` instances from host snapshots.
- Server lifecycle: `--server` boots `networking_slice.host()` and runs the
  authoritative `_process` ticks (creature sync, market/proposal expiry,
  respawn) with no renderer — verified under `--headless`.

**Acceptance criteria:**
- `godot --headless --server` boots the full authoritative sim and reports the
  same `Results: N/N passed` without constructing a single visual node ✓
- A host client and a headless server drive identical creature/AI/combat state
  (same simulation, one with a renderer, one without) ✓
- Entity state no longer holds live `Node3D` references — `get_all_instances()`
  / `get_snapshot_creatures()` return pure data ✓
- Single-player and client renders are unchanged (the pool is the only visual path) ✓

**Implementation notes:**
- `--headless` (Godot flag) already drops the renderer; the work is making the
  *code* stop building visual nodes in headless mode — today
  `creature_slice._make_visual`, `player_slice._build_body`, and
  `character_slice` construct meshes unconditionally. The `MultimeshPool`
  (Phase 26) is the clean seam: guard its construction behind `not headless`.
- "Data-oriented" here means the entity record is a flat dictionary of
  primitives (position, state, hp, respawn_at) — no `Node`/`MeshInstance3D`
  fields — so a server holds millions of records as cheap arrays, not scene
  nodes.

**Known simplifications (deferred):**
- A true SoA (structure-of-arrays) `PackedVector3Array`/`PackedInt32Array`
  layout is not yet adopted — records are still dictionaries (contiguous enough
  for now, but a later SoA pass can drop per-record allocs).
- Server-side only: no client-auth/anti-cheat yet (a later hardening phase).

---

## Phase 28 — Spatial hashing ✅ Done

**Goal:** Replace every O(N) linear scan over the entity population
(`creature_slice.nearest_creature`, AI neighbour checks, combat target
resolution) with an O(1) spatial hash grid so query cost stops growing with
world population.

**Newel dependency:** None.

**Deliverables:**
- `src/core/spatial_hash.gd` — a grid keyed by cell coordinate (`floor(pos /
  cell_size)`), storing entity id → cell, with `insert` / `remove` / `update`
  / `query_radius(pos, radius)` / `nearest(pos)`.
- `creature_slice.nearest_creature` and `creature_ai` neighbour lookups route
  through the hash instead of iterating `_instances`.
- Re-hash on entity move (AI kinematic stepping updates the cell).

**Acceptance criteria:**
- `nearest_creature` cost is independent of total population (a populated grid
  returns the same nearest result as the linear scan, in ~O(radius²) cells) ✓
- Insert/update/remove keep the grid consistent with `_instances` ✓
- Pure projection is headless-testable (query correctness, cell boundaries) ✓

**Implementation notes:**
- `src/core/spatial_hash.gd` is a `RefCounted` grid keyed by `floor(pos.x /
  cell_size)` × `floor(pos.z / cell_size)` (2D XZ — the world is a
  heightfield). Cells hold an id→true set; a parallel `id → cell` map gives
  O(1) remove/re-hash, and `id → position` serves radius/nearest without an
  external lookup. `query_radius` scans only the cells overlapping the query's
  AABB and filters on full 3D distance; `nearest` doubles the probe radius
  until a candidate is found (cost bounded by local density, with a linear
  fallback for a pathologically sparse population). Default `cell_size` 8.0
  puts the 3 m attack range and most AI alert radii in a single cell.
- `creature_slice` keeps the hash in lockstep with `_instances`: `insert` on
  spawn and on client first-sight, `update` in `set_instance_position` (AI
  kinematic stepping) and `apply_creature_state`, `remove` in
  `despawn_for_chunk`. `nearest_creature` now iterates
  `_spatial.query_radius(...)` (dead-state filtered) instead of scanning the
  whole population — the O(N) → O(radius²)-cells win. `creatures_in_radius`
  is the public neighbour-query primitive the AI (pack/herd, deferred) will
  consume.
- The AI's per-frame `_process` still iterates `get_all_instances()` because it
  must tick *every* creature's state machine — that is an inherent O(N) tick
  loop, not a spatial query, so it is not routed through the hash. There is no
  creature-to-creature neighbour lookup in the AI yet (pack/herd behaviour is
  deferred from Phase 15); `creatures_in_radius` exists for when it lands.

---

## Phase 29 — Interest management (area of interest) ✅ Done

**Goal:** Stop broadcasting every entity delta to every client (the current
`_broadcast` / `_broadcast_creature_states` N×M blowup). Only entities within a
client's area of interest are sent, so network traffic scales with what each
player can actually see, not the whole world.

**Newel dependency:** None (builds on Phase 28's spatial hash).

**Deliverables:**
- Per-peer AOI: a radius (`networking_slice.AOI_RADIUS`, 96 units = 3 chunks)
  per connected client, keyed on the peer's last-known position (a freshly
  connected peer defaults to the spawn point).
- `networking_slice` filters creature/player/voxel broadcasts to peers whose
  AOI contains the entity — a client only receives state for nearby entities.
  Spatial deltas route through `_broadcast_aoi`; a `_peer_spatial` hash makes
  the interest query O(cells) instead of O(peers).
- The world snapshot a joining client receives is AOI-scoped (`_build_snapshot`
  filters creatures and players via `_scoped_creatures`), and a client moving
  into a new AOI grid cell triggers a re-scoped snapshot.

**Acceptance criteria:**
- A client receives creature/player deltas only for entities within its AOI ✓
- Network traffic grows with local density, not total world population ✓
- Deterministic headless tests: a far client receives nothing, a near client
  receives the delta ✓

**Known simplifications (deferred):**
- Economy state (market/governance/trade) is global, non-spatial replicated
  state and remains full-broadcast — every client needs the full market view.
- Re-scope granularity is one AOI grid cell (96 units), so entities entering
  AOI mid-cell appear on the next boundary crossing, not instantly.

---

## Phase 30 — Pack and herd behavior ✅ Done

**Goal:** Close the last creature-AI "Known simplification" deferred from Phase
15: creatures alerting nearby allies. Predator packs coordinate an attack;
prey herds stampede together — group tactics that make a lone wolf manageable
but a pack deadly, and a bison herd lethal when panicked.

**Newel dependency:** None. Reuses the existing `enum` and `decimal` field
types (already emitted by `generator-godot`); no generator change needed.

**Deliverables:**
- `fabric/world/creatures/shared.js` — a `GROUP_BEHAVIORS` enum
  (`none` / `pack` / `herd`).
- `fabric/world/creatures/temperate.js` — `GraywolfPack` gains
  `groupBehavior: 'pack'` + `packRadius: 20.0`; `SteppeBison` gains
  `groupBehavior: 'herd'` + `packRadius: 20.0`. Solitary creatures omit both
  fields entirely (the runtime treats an absent field as `none` / `0.0`).
- `src/creature/creature_ai.gd` — `_propagate_group_state` / `_escalate_neighbor`
  fire when a member enters a threat state: a **pack** shares `alert` +
  `aggressive` (a coordinated attack), a **herd** shares `fleeing` (a
  stampede). Propagation is same-species only, escalation-only (never
  downgrades a more-threatened neighbour), and non-recursive (bounded).
- `src/creature/creature_slice.gd` — pack/herd members **cluster** around a
  single deterministic pack centre at spawn (small per-index offsets) so their
  coordination actually fires in practice instead of spawning scattered out of
  `packRadius`. Solitary creatures keep their per-index scattered positions.

**Acceptance criteria:**
- A wolf detecting the player drags its pack-mates into `aggressive` ✓
- A bison fleeing below its threshold drags the herd into `fleeing` ✓
- A solitary creature (no `groupBehavior`) never drags a neighbour ✓
- `groupBehavior` / `packRadius` are fabric fields read from `GameData.CREATURES`,
  not hardcoded GDScript constants ✓
- 4 new automated tests pass at startup ✓

**Implementation notes:**
- `groupBehavior` is an enum field (stored as an int index in `.tres`:
  `0` none, `1` pack, `2` herd); `packRadius` is a `decimal` field. The AI reads
  both via `_group_behavior(res)` / `_pack_radius(res)` helpers that default to
  `GROUP_NONE` / `0.0` when the field is absent, so the eight solitary creatures
  need no field entries.
- Propagation lives in `_transition` (which now takes the triggering instance
  and a `propagate` flag): the *original* transition propagates to neighbours,
  but a propagated transition passes `propagate = false`, so a pack flood is
  bounded and longer chains resolve over subsequent frames as each member ticks.
- `_escalate_neighbor` escalates `idle → alert → aggressive` (pack) or any live
  state `→ fleeing` (herd) and never downgrades; dead/respawning neighbours are
  skipped.
- Pack/herd spawn clustering keys on the creature's `groupBehavior`; the pack
  centre is the existing `_deterministic_chunk_position(..., spawn_index = 0)`
  and members fan out by `_pack_member_offset(spawn_index)`, so spawn layout
  stays deterministic across runs.

**Known simplifications (deferred):**
- No inter-species coordination — a wolf pack never alerts a nearby bison herd,
  and vice versa (the fabric models each species as an independent group).
- No explicit "pack leader" role: any member can trigger the group; the fabric
  prose's "lead wolf dies → pack disbands" rule is not yet a distinct mechanic
  (a dead member simply stops propagating and the survivors keep coordinating).
- Group coordination is instantaneous; no signal-propagation delay or
  distance-falloff within `packRadius`.

---

## Phase 31 — Trees and resource appearance ✅ Done

**Goal:** Source wood materials from trees instead of the bare ground, and give
surface resources a distinct visual identity so the world reads as "mostly
plain dirt/rock with sparse, valuable veins" rather than a uniform resource
field.

**Newel dependency:** None. Reuses existing material entities (`Thornwood`,
`Duskfiber`); trees are a new world feature modelled in GDScript first, with a
fabric `world-system`/entity to follow once the runtime shape is settled.

**Deliverables:**
- `src/world/tree_slice.gd` — trees spawn deterministically per biome, derived
  from the chunk coordinate, species, and index, so a host and a client place
  the same trees with no snapshot. Density follows the biome prose: temperate
  forest 8 per chunk (weight 0.8), grassland 2 (isolated copses, 0.1), twilight
  grove 8 (Duskwood); the volcanic badlands and the void rift prose grants no
  conventional wood, so they grow none. Trees stand on the terrain surface like
  creatures and stream with their chunk.
- Chopping a tree yields its wood material (`Thornwood` / `Duskfiber`) into the
  inventory, replacing the removed ground-wood distribution (wood no longer
  mines from the ground — see Phase 12's `BIOME_MATERIALS`). A chop requires a
  held axe (the fabric discriminator `toolType: 'axe'`), spends one point of its
  durability, leaves a stump, and the stump regrows after a cooldown.
- Distinct visual treatment for resource veins: the common ground renders as
  plain dirt/rock, while rarer materials (Aethermite, Lumenfite, Voidite) are
  tinted and given a small raised/deposited shape (`vein_deposits()` in
  `voxel_slice.gd`) so a vein is recognizable from a distance.

**Acceptance criteria:**
- [x] `BIOME_MATERIALS` no longer lists any wood material (already true as of the
  map-improvements change; wood comes only from trees).
- [x] Chopping a tree yields its wood and the tree respawns on a cooldown.
- [x] A rare-material vein is visually distinguishable from the surrounding
  ground.

**Known simplifications (deferred):**
- Tree state is not persisted — a restart restores standing trees. Creature
  death/respawn persistence is Phase 33's work, and trees travel with it then.
- A tree's trunk collision exists to be an aim target, not an obstacle: the
  player still walks through a trunk (the player's `collision_mask` is
  untouched, which keeps tree spawning from needing spawn-clearance rules).
- Tree density and the regrowth cooldown are GDScript constants
  (`TREES_BY_BIOME`, `RESPAWN_SECONDS`) — they move to the fabric `world-system`
  entity the Newel-dependency note above describes.
- Resource deposits have no depth/quantity model yet (mining still yields one
  unit per `STEP_HEIGHT` slice).

---

## Phase 32 — One authoritative boot path ✅ Done

**Goal:** Make the host path a superset of the server path — `_boot_host()` calls
`_boot_server()` for the authoritative half, then layers local presentation
(player spawn, avatars, lighting, UI) on top. One authoritative boot means the
dedicated server and the listen host can never drift apart. Cheap and
mechanical; touches no gameplay.

**Newel dependency:** None.

**Why this is its own phase:** there were three boot paths and the authoritative
half was duplicated (the state this phase removed). `_boot_world()` branched:
client → `_boot_client()`, server → `_boot_server()`, else the host path was
inlined in `_boot_world()` itself (player spawn, chunk streaming, the demo craft
sequence, the save/load snapshot, `_networking.host()`). There was **no
`_boot_host()` function at all** before this phase; the drift is already visible
in code: the host path hardcoded
`_networking.host(_networking.DEFAULT_PORT, 1)` while `_boot_server()` passes
`DEFAULT_MAX_CLIENTS` (64). Until the server path is the single authoritative
boot, every Phase 33 persistence change has to be written and verified twice —
which is why this landed first, as its own commit.

**Deliverables:**
- Extract the inlined host path from `_boot_world()` into `_boot_host()`.
  `_boot_host()` calls `_boot_server()` for the authoritative half, then layers
  local presentation on top: player spawn, avatar/character visuals, lighting,
  HUD/UI, minimap, and the `DEBUG`-gated demo sequence.
- `_boot_world()` becomes a three-line role dispatch
  (`_is_client` → `_boot_client()`, `_is_server` → `_boot_server()`, else
  `_boot_host()`).
- Raise the default `max_clients` off 1: the host path passes
  `_networking.DEFAULT_MAX_CLIENTS` (64), not a literal `1`.
- Add a CI job to `.github/workflows/ci.yml` that boots `--server --headless`
  and asserts the server comes up clean.

**Acceptance criteria:**
- [x] `_boot_world()` contains no inlined host logic — it only dispatches.
- [x] A listen host and a dedicated server share the identical authoritative
  half (same `chunk_manager.start()` / `refresh()` + `networking.host()` calls).
  Both boots print the same line — `[Server] listening on port 7777,
  max_clients 64` — as the delivered record.
- [x] The host still renders: `render_visuals` is decided by `_is_server` in
  `_ready()`, so a host calling `_boot_server()` must still build the player,
  avatars, lighting, and UI. (Lighting was already behind `not _is_server`; the
  review that closed this phase found the minimap overlay and the UI slice were
  **not** — both were built on every role, dedicated server included — and moved
  them behind the same guard. Nothing clears them on a host.)
- [x] `max_clients` is 64 on the host path, not 1.
- [x] The new CI job fails on a `SCRIPT ERROR` / `Parse Error` / `Compile Error`
  in the server boot log (`.github/workflows/ci.yml` job `server-boot`), and
  additionally asserts the listening line is present rather than only that the
  boot failed to crash.
- [x] Headless suite count is unchanged (this step adds behaviours, not tests of
  the suite's existing assertions). 6695 passed before and after.

**Implementation notes:**
- **Order the authoritative half before the player spawn.** `_boot_server()`
  streams the chunk window around the *origin*; the host path places the player
  at the spawn point first and then refreshes so the window centres on spawn. A
  `_boot_host()` that calls `_boot_server()` first must therefore re-`refresh()`
  the chunk manager after spawning, or `_boot_server()` must expose its two
  authoritative steps separately. Do not silently regress the spawn-centred
  window — that is the Phase 17/31 behaviour.
- **`--server` is a *user* arg, so it goes after `--`.** `OS.get_cmdline_user_args()`
  returns only what follows the separator; the CI job must invoke
  `godot --headless --path . --quit -- --server`, not `--server` among the engine
  args (it would be silently ignored and the job would boot a host instead).
- **Assert positively, not just by absence of errors.** Today the server path
  prints no line on success, so the only assertable fact is the absence of
  `SCRIPT ERROR` / `Parse Error` / `Compile Error`. Add one boot line (e.g.
  `[Server] listening on <port>, max_clients <n>`) so the job can assert the
  server actually came up rather than merely failed to crash.
- Keep the CI job cheap: reuse the `godot-tests` job's Godot 4.7 download step
  and run `--quit` (without it the headless main loop never exits).

**Known simplifications (deferred):**
- The authoritative half is shared; the presentation layer is not. Only the host
  runs the `DEBUG`-gated demo sequence, the player spawn, and the visual build,
  so a dedicated server is authoritative but presentation-free — that is the
  intended Phase 27 sim/visual split, not a gap. Note the tail also holds the
  *unconditional* boot demos (mine + place, 4 Ashite, one combat round) and the
  boot save/load, and those mutate authoritative state — so the two boots share
  the same authoritative calls, not the same world state.
- `--server` gains no graceful termination hook here; the save-on-termination
  lifecycle is Phase 33's work.
