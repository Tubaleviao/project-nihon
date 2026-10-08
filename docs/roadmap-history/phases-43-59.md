# Roadmap history — Phases 43–59

Completed phases, archived unchanged from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 43 — Natural resource distribution ✅ Done

**Goal:** Resources are a uniform draw. `BIOME_MATERIALS` gives every tile of a
biome the same weighted distribution, so Aethermite is 17/100 of every volcanic
tile a player ever mines — at every depth, in every chunk, forever. The
material's own prose ("deep underground near ley lines") describes nothing the
code does, and Phase 31 recorded the gap plainly: "Resource deposits have no
depth/quantity model yet (mining still yields one unit per `STEP_HEIGHT`
slice)". This phase replaces the biome-uniform draw with a deterministic 3D ore
field — vein blobs with a depth band and a quantity — retires `BIOME_MATERIALS`
to a bias rather than the distribution, and makes "deep near ley lines" a real
condition the world can be asked about. The depth band and the ley gate are
FABRIC VALUES on the material entities, not a GDScript table: this phase moves
them into the source of truth (with the newel dependency that requires), so the
field cannot disagree with the prose it is derived from.

**Newel dependency:** YES. The depth band and the ley gate become fabric fields
on the material entities (`depthBand`, plus a ley-gating field, on
`fabric/world/materials/*.js` — `Aethermite` already reads "Found deep underground
near ley lines and in meteor craters"), authored from the prose each material
carries today. `pnpm validate`, `pnpm generate` and
`pnpm check-drift` re-run; no runtime band table may be hand-written in GDScript.

**Closes:** item 7a, Phase 31 deferred.

**Deliverables:**
- `fabric/world/materials/*.js` — the depth band and the ley gate as ENTITY
  FIELDS, not GDScript: a `depthBand` (the min/max depth a material may appear at)
  and a ley-gating field on every material, authored from the prose each material
  already carries. The runtime field READS them through the generated resources.
- `src/terrain/ore_field.gd` (new, pure) — the field:
  `vein_at(chunk_pos, tile, depth) -> Dictionary` returning
  `{ material, quantity }` or `{}`, derived from a 3D noise blob threshold plus the
  material's fabric `depthBand`. A vein is a BLOB of neighbouring tiles at a depth,
  not an independent per-tile probability, so a rich spot is worth walking to.
- `src/terrain/ore_field.gd` — the ley-line field:
  `ley_line_value(world_xz) -> float` (2D noise) gates whichever materials carry
  the fabric ley gate, so a deep volcanic tile far from a ley line yields none for
  a ley-gated ore. This is the first code that makes the material's own lore true.
- `src/terrain/voxel_slice.gd` — `BIOME_MATERIALS` becomes `BIOME_BIAS` (the
  dominant material a biome favours for a vein that is not depth-gated);
  `material_for_biome` and the mesher's per-run tint (`_run_color`) read the field.
- `src/terrain/voxel_slice.gd` — `vein_deposits()` (the Phase 31 raised surface
  marker) reads the same field, so the marker marks a vein that is actually
  there, and takes its colour from the vein's material.
- Mining yields the vein's `quantity` rather than a flat one per slice, and an
  exhausted vein is recorded through the Phase 41 edit path (so its depletion
  survives a chunk rebuild and a save).

**Acceptance criteria:**
- [x] A fixed seed mines the same vein in the same place twice, and a client sees
  the same veins as the host with no snapshot (assert the pure field, not a
  visual).
  *(Landed: "ore: a fixed seed puts the same veins in the same place" samples 16 chunks × 12
  depths twice and compares, and a second seed differs. "ore: a client sees the host's veins
  with no snapshot" gives a host and a client slice their own `TerrainSlice` at one seed and
  compares `material_at` over a grid AND the two `build_runs` resolves of a chunk — equal with
  nothing exchanged.)*
- [x] Aethermite never appears above its depth band and never far from a ley
  line, sampled over a grid of tiles.
  *(Landed: "ore: aethermite keeps to its band and its ley lines" — 3 seeds × 144 chunks ×
  1024 tiles × 26 depths; every Aethermite sample is at or below the fabric `depthBand.min`
  and `near_ley_line`, and the sample is asserted non-empty so the gate is not vacuous. It
  holds PER TILE, not just per vein centre: `vein_at` clips each tile by the same gate.)*
- [x] The retired uniform draw is measurably gone: the per-chunk counts of a
  given material over a sample of chunks are non-constant (assert the variance
  against the old constant distribution).
  *(Landed: "ore: the uniform draw is gone" counts Aethermite in 16 volcanic chunks at three
  depths: the variance is asserted > 1 and most chunks sit more than half away from the
  retired constant share (17% of the samples, every chunk).)*
- [x] Mining a vein yields more than one unit and the vein is exhausted by
  repeated mining; mining surrounding rock yields the bias material and never the
  gated ore.
  *(Landed: "ore: a vein yields more than one and runs out" mines a surfacing vein slice by
  slice through `mine_block`: each live slice yields the vein's material × its `quantity`
  (2–4), the vein pays out exactly its `reserve`, and the next slice of the same blob yields
  host rock, one unit. "ore: surrounding rock is the bias, never the gated ore" mines
  non-vein tiles of a volcanic chunk: Ashite, one unit, never Aethermite.)*
- [x] The suite is green on both boot paths and the field is unit-tested (blob
  continuity across a chunk border, depth gate, ley gate).
  *(Landed: 422/422 tests green, and the two-client net harness 10/10. "ore: a blob is
  continuous across a chunk border" finds slices where one vein id covers tile 63 of chunk 0
  and tile 0 of chunk 1, and asserts a tile's answer does not depend on which chunk asks;
  the depth and ley gates are the Aethermite test above plus "ore: the ley field is a field
  of lines". Depletion: "ore: depletion is one op per vein and persists" (one op however
  many swings, dirty anchor chunk, JSON save round-trip, survives compaction, a malformed op
  is dropped) and "ore: a client replays the host's depletion" (same depletion and same edit
  log after `apply_block_change`).)*
- [x] `pnpm validate`, `pnpm generate` and `pnpm check-drift` are green, and the
  generated material resources carry `depthBand` and the ley gate — the field's
  band cannot disagree with the fabric because it IS a fabric value.
  *(Landed: `depthBand` (json `{ min, max }`) and `leyGated` (boolean) on all eight
  materials via `fabric/world/materials/deposit.js`; the generated `.tres` carry them and
  `OreField.warm()` reads them off `GameData.MATERIALS`. "ore: the bands are fabric values"
  asserts the runtime table equals every resource's fields. No newel change was needed —
  `json` and `boolean` fields with defaults already generate.)*

**Implementation notes:**
- **The field must be a pure function of (seed, world position, depth) — never of
  chunk load order.** That is what lets a host and a client agree with no
  replication at all: they evaluate the same function. The Phase 44 spawn work
  has exactly the same constraint, and both fail the same way when it is broken
  (a client's vein appears where the host has rock).
- **Depth is why this phase follows Phase 41.** A depth band needs a depth to
  index; before the volumetric column there was one surface and no "below".
- **A vein may straddle a chunk border, and must.** The field is evaluated per
  tile, so a blob crossing a border is continuous on both sides; do not "own" a
  vein by its centre chunk, or the border becomes a visible seam.
- **Vein identity, not per-tile depletion.** Depleting tile-by-tile makes a blob
  a checkerboard and makes the save grow with every swing. Name the vein (a hash
  of its blob origin) so "exhausted" is one recorded fact per vein, carried by
  the edit path Phase 41 already persists.
- **Depth gating is data, not code.** The band is a fabric field on the material
  (`depthBand`), beside the material's other properties, where the prose that
  states it already lives; the runtime field must not carry a hand-written
  `if material == "Aethermite"` table of bands. The generated resource is the only
  place the band is authored, so the field and the fabric can never drift.

**Known simplifications (deferred):**
- **The vein field's own noise constants stay GDScript.** What moves into the
  fabric is the material's DEPTH/QUANTITY model — the `depthBand` and the ley
  gate, entity fields on the material (`fabric/world/materials/*.js`). The SHAPE
  of the field itself (noise frequency, blob threshold, blob size, the 2D
  ley-noise frequency) stays a hand-written constant in `src/terrain/ore_field.gd`
  and does not ride a newel world-system entity in this phase. That is a narrower
  deferral than Phase 31 recorded, and a later separate change — the same one
  Phase 44 carries for tree density (`fabric/world/world.js`, Phase 44's wording).
- **No detection or prospecting skill interaction.** A deep vein has no surface
  tell beyond the raised marker on a vein that reaches the surface; finding ore
  with a skill/tech is a later feature.
- **No richer tool gating by ore.** The existing pick/axe discriminator path is
  unchanged; a depth-gated ore still yields to whatever pick the player holds
  (durability cost aside).
- **No vein regrowth.** A vein is a finite, depleting body; nothing replenishes
  it, and the tree stump cooldown is still the only regrowth clock in the world.

**As built (decisions the deliverables left open):**
- **Depth is measured from the tile's NATURAL surface** (its quantised heightmap top), not
  from world Y and not from the current column top: the datum is fixed by the seed, so a
  vein does not move when a player digs above it, and both peers compute it from the same
  heightmap.
- **The blob is a cell-hashed ellipsoid with a noise-perturbed surface**, not a global
  noise threshold. Space is cut into 16-tile × 4-unit cells, each holding at most one vein
  whose centre sits far enough inside that the blob (radius × (1 + `SHAPE_NOISE`)) cannot
  leave it — so a sample reads ONE cell, and the vein's identity is its cell id (the "hash
  of its blob origin"). The XZ cell grid is offset half a cell from the chunk grid, which is
  what makes veins straddle chunk borders. The top depth cell lets veins break the surface.
- **A vein's material is picked once at its centre** from the centre's biome
  (`TerrainSlice.biome_for_chunk`, now static): a weighted draw over the biome's non-host
  bias materials the fabric admits there, else the host itself (a rich pocket — the only
  kind TemperateForest has). Each tile is then clipped by the material's band and ley gate.
- **The host rock is not band-gated.** `BIOME_BIAS`'s heaviest entry is what every tile
  outside a live vein yields, at any depth — so a twilight tile is Lumenfite rock below
  Lumenfite's shallow band, and only a Lumenfite VEIN honours it.
- **Depletion is ONE edit-log op per vein**: `{ "op": "deplete", "vein": id, "taken": n }`
  on the vein's anchor tile, replaced in place on each mine. It rides the per-chunk save
  manifest and the join/re-scope snapshot, `apply_edits` re-derives `_vein_taken` from it,
  compaction carries it over, and the client's `apply_block_change` records the same
  depletion the host did. An exhausted vein renders and mines as host rock, and its chunks
  are rebuilt when it runs out (or when a snapshot flips it).
- **A natural run is still ONE colour**, the field's material at its top slice: a vein
  shows where a column's top slice reaches it (and gets the raised marker there), not on
  the side walls of a deeper cut. The marker now marks every live vein, ferrite included.
- **Cost:** the field adds ~15 ms to a chunk's resolve (≈42 → ≈56 ms measured over six
  noise chunks), all of it on the worker since Phase 42 moved the resolve there; the
  ellipsoid test short-circuits the 3D noise for every sample it can decide alone.

---

## Phase 44 — Spawn scarcity ✅ Done

**Goal:** Population is uniform and unbounded. `CreatureSlice.spawn_for_chunk`
spawns exactly `spawnCount` of every creature whose biome matches the chunk —
every chunk of a biome carries the same count, no chunk can be empty, nothing
clusters, and nothing stops a long walk from accumulating an unbounded number of
live instances. The field's own fabric description reads "Number of instances
spawned per game world" while the runtime reads it as per chunk, so the fabric
says one thing and the code does another. Trees have the mirror-image problem:
`TREES_BY_BIOME`'s `per_chunk` is a GDScript constant, which Phase 31 explicitly
deferred to a fabric world-system entity. This phase makes population a product
of per-chunk chance, density noise and a global cap, reinterprets `spawnCount` as
PACK size, and moves tree density into the fabric.

**Newel dependency:** YES — the first phase in this run that changes the fabric.
`fabric/world/creatures/*.js`: `spawnCount` becomes pack size (description and
defaults), plus new `spawnChance` and `spawnDensity` fields; a new
`fabric/world/world.js` (or the biome entities) carries `treeDensity` per biome,
replacing `TREES_BY_BIOME.per_chunk`. `pnpm validate`, then `pnpm generate`, then
`pnpm check-drift`. The generated diff is mostly `schemaHash` lines plus the IR
snapshot — verify with check-drift rather than by reading it (`grep -v
schemaHash` to see the real changes).

**Closes:** item 7b, Phase 31 deferred.

**Deliverables:**
- `fabric/world/creatures/*.js` — `spawnCount` is documented as PACK size
  ("instances placed together at one spawn point"), with `spawnChance` (0..1 per
  chunk) and `spawnDensity` (the noise amplitude that clusters or thins packs
  across the world) added to the shared creature field block.
- `fabric/world/world.js` (or the biome entities) — `treeDensity` per biome,
  the fabric home for what `TREES_BY_BIOME.per_chunk` holds today.
- `src/creature/creature_slice.gd` — `spawn_for_chunk` becomes: a seeded
  per-chunk chance roll, a density-noise multiplier, then `spawnCount` instances
  as ONE pack around one deterministic centre, admitted only if the global cap
  allows. `set_population_cap(n)` / `live_population()`, cap enforced host-only.
- `src/world/tree_slice.gd` — density is read from the fabric `treeDensity`, with
  the same chance/density-noise shape as creatures; a `TREES_BY_BIOME` fallback
  remains for isolated unit tests that have no fabric wired, mirroring
  `DEFAULT_BIOME`.
- `src/tests/test_suite.gd` — the pure roll/density/cap helpers asserted
  headless, including a small cap proving the ceiling holds and is released.

**Acceptance criteria:**
- [x] The same seed produces the same pack centres and sizes on a host and a
  client, with no snapshot carrying placement.
- [x] A chunk can roll no spawn at all, and the per-chunk counts of a species
  across a sample of chunks have non-zero variance (assert against the retired
  constant count).
- [x] With a small cap and a wide view ring, live instances never exceed the cap,
  and a despawn returns budget that a later pack can use.
- [x] `pnpm validate`, `pnpm generate` and `pnpm check-drift` are clean; no
  runtime code reads `spawnCount` as a per-chunk count anywhere
  (`grep -rn spawnCount src/`), and the fabric description says pack size.
- [x] The suite is green on both boot paths.

**Implementation notes:**
- **A cap is only honest if it counts LIVE instances and is released on
  despawn.** Retaining budget after a despawn is the same leak class Phase 37
  fixed twice (an in-memory table with no eviction point); the cap must be
  recomputed from what is alive, not decremented and forgotten.
- **Determinism comes from the seed, not from `randi()`.** The roll is derived
  from the world seed plus the chunk coordinate, so a client that never receives
  the spawn decision still places the same pack. `spawn_for_chunk` is already a
  no-op on a client without visuals; keep the roll pure anyway, so the host's
  decision can be recomputed rather than trusted.
- **A refused pack must be refused consistently.** The cap is a host-only
  quantity, and the host is what streams a pack to a client — so a cap-refused
  pack is simply never sent, which is what makes the client's view unable to
  disagree. Do not let the client re-roll admission locally.
- **Pack size changes what every biome's population MEANS.** `spawnCount: 3`
  used to mean three separate instances per chunk of that biome; as pack size it
  means three arriving together in one place, which is what the Phase 30
  pack/herd AI was written to consume. Say so in the fabric description rather
  than leaving a re-interpreted field looking unchanged.
- **The tree-density move is a real fabric change with a big generated diff.**
  Land it in the same commit as the creature fields and say so in the body; a
  reader scanning `grep -v schemaHash` should see two real changes, not one.

**As built (decisions the deliverables left open):**
- **The pure roll lives in `src/world/spawn_roll.gd`** (`SpawnRoll`): an integer hash of
  (seed, chunk, salt) for the chance roll, and smooth bilinear value noise on a 4-chunk
  lattice for density. `pack_size` scales the chance AND the pack by the density multiplier
  (1 ± `spawnDensity`), so a dense region rolls packs more often and larger; size is at
  least 1 when the roll passes. Trees reuse it with a 10% clearing chance and ±0.5 noise.
- **No world, no roll.** With no terrain slice wired (isolated tests) a creature spawns at
  its full `spawnCount` and a tree biome at its flat density, mirroring `DEFAULT_BIOME`.
- **Every spawn is a pack**: all creatures, not just pack/herd ones, cluster around one
  deterministic centre. The cap (`set_population_cap`, `live_population()`) is recounted from
  `_instances` (dead creatures excluded) on every admission; a pack that does not fit is
  refused whole.
- **Fabric**: `spawnCount` re-described as pack size, plus `spawnChance` (default 0.6) and
  `spawnDensity` (default 0.5) on every creature; `treeDensity` on every biome (8 / 2 / 8 /
  0 / 0). Tree species and wood stay in `TREES_BY_BIOME`, whose `per_chunk` is now only the
  no-fabric fallback.

**Known simplifications (deferred):**
- **No respawn or death-scarcity model.** The cap is on live instances, not on
  how many may die per hour; hunting a biome to local extinction and watching it
  recover is not modelled.
- **No per-species cap** unless the fabric gains one — the cap in this phase is
  global.
- **Spawn clearance is still minimal.** A pack can spawn inside a player's build;
  rejection near a built or claimed region is deferred (Phase 31 already recorded
  the same gap for trees).
- **The density field is 2D.** Surface population only; Phase 43's 3D field is
  about materials, not about where a pack sits vertically.

---

## Phase 45 — Asset pipeline for meshes and animation ✅ Done

**Goal:** The asset pipeline handles exactly one kind of asset. `AssetOverlay`
resolves a canonical key to a texture and decodes raw PNG bytes; there is no mesh
loader and no animation at all. Every character and creature body is a procedural
`BoxMesh` built in `character_slice._make_avatar` / the creature builders, and
`locomotion.gd` is a state machine that produces `get_state()` and
`get_blend_weight()` for an `AnimationTree` that does not exist — Phase 20's
deferrals ("No authored animation clips / `AnimationPlayer` / `AnimationTree`
playback", "no real mesh + `Skin` asset production") are still open, and the
private `assets-prod` submodule holds art that nothing but textures can load.
This phase extends the overlay from textures to meshes and clips through a keyed
manifest, wires a real `AnimationTree` to the locomotion state machine's existing
outputs, and lands the first rig and clip set.

**Newel dependency:** None for the loader. The manifest's keys are derived from
the fabric's existing entity names (the same convention the overlay already uses
for textures); emitting the manifest FROM the fabric is a newel-side follow-up
(see Known simplifications).

**Closes:** item 3, Phase 20 deferrals.

**Deliverables:**
- `assets/manifest.json` (committed, public) — the keyed manifest: canonical
  asset keys to relative paths, for meshes and animation libraries as well as
  textures. The private counterpart in `assets-prod/` overrides by KEY through
  the same `res://_overlay/` mount mechanism `AssetOverlay.resolve_path` already
  uses, so no code branches on which side is present.
- `src/core/asset_overlay.gd` — `manifest()`, `keys()`, `load_mesh(rel)` and
  `load_animation_library(rel)` beside `load_texture`. Both new loaders read bytes
  with `FileAccess.get_file_as_bytes()` and parse with
  `GLTFDocument`/`GLTFState.append_from_buffer` — never `load()` or
  `Image.load()`, for the reason the module comment already states: import-machinery
  paths cannot see pack-mounted content at the bare `res://` path. The `.raw`
  convention extends to meshes (`models/x.glb.raw`).
- `git submodule update --init assets-prod` — the private repo (requires access;
  documented in `assets/README.md`) is what actually provides the first rig and
  clips. Record the step in the README so a fresh clone knows why its avatar is
  still boxes.
- `src/character/character_slice.gd` — an `AnimationTree` per rig root, created
  when a real rig loads: an `AnimationNodeStateMachine` with one node per
  `Locomotion.State`, transitions driven by `state_name()`, a `BlendSpace1D` for
  IDLE/WALK/RUN driven by `get_blend_weight()`, and one-shots for ATTACK / LAND
  matching `ATTACK_DURATION` / `LAND_DURATION`. The state-to-node mapping is a
  pure function so the suite can assert every enum value has a node.
- The first rigged creature family and its clips — the same pipeline on a
  non-character skeleton, proving the loader and the tree are not
  character-specific.
- Fallback: a missing mesh or animation key warns and falls back to today's
  procedural body and an empty library, so a public clone still boots with zero
  missing-resource errors (Phase 21's invariant).

**Acceptance criteria:**
- [x] `load_mesh` and `load_animation_library` return a real `Mesh` and
  `AnimationLibrary` from a `.raw` `.glb`, both from a mounted pack and from the
  committed placeholder, and neither path calls `load()` on the asset.
- [x] A rigged avatar plays idle → walk → run continuously per
  `get_blend_weight()` and holds attack/land one-shots for the state machine's
  durations; the smooth blend reads as a cross-fade, not a snap.
- [x] With `assets-prod/` NOT initialised the game boots on placeholders with no
  missing-resource errors; with it initialised the real rig is used, and
  `AssetOverlay.asset_mode()` reports which.
- [x] The suite is green on both boot paths; the mapping and the manifest are
  unit-tested, and the animated rig is stated as exercised in game only (the
  suite has no frames).

**Implementation notes:**
- **The `.raw` convention is not optional for a mesh either.** An
  importer-claimed `.glb` is compiled and dropped from a real export at the bare
  path, exactly like a `.png` — so a shipped build would lose its models while a
  dev run looked fine. Parse from bytes.
- **Keys come from the fabric's names, not from file layout.** A key is derived
  (`models/creatures/<EntityName>.glb.raw`) so generating new entities does not
  require hand-editing a path. The manifest lists what EXISTS; a missing key is a
  warning and a fallback, never a crash.
- **Wiring an `AnimationTree` is not a rewrite of `locomotion.gd`.** The state
  machine was written for this consumer: `get_state()` drives the state machine
  node and `get_blend_weight()` drives the blend space. The single point where
  the tree and the enum can drift is the mapping table — keep it pure and assert
  total coverage of the enum, so a new locomotion state cannot silently animate
  as idle.
- **The submodule is a checkout step, not a code change.** A phase whose
  deliverable is "the real rig exists" must say that the art is in a private repo
  the reader may not have access to, and that the public path is the placeholder.
- **The suite cannot see the renderer.** Assert the manifest, the key derivation
  and the enum-to-node mapping; drive the actual animation in game only.

**As built:** `assets/manifest.json`, `AssetOverlay.manifest/keys/has_key/load_mesh/
load_animation_library/creature_model_key`, `src/character/rig_tree.gd` (pure
enum→node table, `build_tree`, `drive`), `CharacterSlice.attach_rig`, and a
generated placeholder rig (`tools/gen_placeholder_glb.py`). The real rig and the
first creature family's clips live in the private `assets-prod` submodule and were
not authored here; with no manifest entry `attach_rig` returns false and the
procedural body stays. The animated blend/one-shots are exercised in game only.

**Known simplifications (deferred):**
- **No root motion.** Still Phase 20's deferral: the controller drives
  `CharacterBody3D.velocity` directly, not extracted displacement.
- **No facial blendshapes and no per-leg IK** — Phase 20's deferrals stand; foot
  placement remains the whole-body offset Phase 40 fixed.
- **No fabric-generated manifest.** The manifest is a committed JSON keyed by
  entity name; generating it from the fabric is a newel-side follow-up.
- **One creature family only.** The rest keep procedural bodies until their rigs
  and clips exist, and equipment attachment stays procedural
  (`apply_equipment`, no animation-driven sockets).

---

## Phase 46 — UI shell ✅ Done

**Goal:** The window system is functional and inert. Six `PanelContainer`s are
built at fixed positions (`_build_window(key, title, content, position)` — no
title-bar drag, nothing persisted), the inventory window is a single `Label` fed
by `inventory_lines()`, so there is no slot grid, no icon, no hover, no
right-click, and the only item identity a player sees is a line of text. A
Controls legend already exists and is always on: `_build_shortcuts_menu()` builds
a `Controls` panel at `player_slice.gd:781` and `_build_hud()` attaches it to the
HUD at `:620`, so the key bindings are painted top-left for the whole session and
are mouse-transparent. This phase gives the shell a generic draggable window with
persisted positions, resolves item icons through the overlay, replaces the
inventory text dump with a slot grid (tooltip and right-click menu), and MOVES
that existing legend behind a collapsible `?` panel rather than adding one. The
phase is independent of Phase 45's asset pipeline — the shell is texture-keyed UI
work — and may land before it.

**Newel dependency:** None. Item identity is the entity name the fabric already
carries.

**Closes:** items 4 and 6.

**Deliverables:**
- `src/ui/ui_slice.gd` — ONE drag handler installed on every window's title bar:
  press starts a drag, motion moves the panel, release stores the position.
  Positions persist per window key, so a restart reopens windows where they were
  left. The layout is a per-player value and therefore needs a durable home and
  an eviction point (Phase 37's rule) — state in the commit whether it rides the
  player record or a client-only settings file.
- `src/ui/ui_slice.gd` — item icons through the overlay: a derived canonical key
  (`icons/items/<EntityName>.png.raw`) handed to `AssetOverlay.resolve_path` /
  `load_texture`, with a glyph placeholder when the key is absent, so a clone
  without the private art still renders a readable slot. **No overlay work is
  required:** `resolve_path` and `load_texture` are already general — any relative
  key resolves against a mounted pack first and the public `res://assets/`
  placeholder second, and an absent key decodes to `null`. This deliverable is key
  DERIVATION plus a `null` branch, not a loader change.
- `src/ui/ui_slice.gd` — the inventory slot grid: a `GridContainer` of slot
  controls replacing `_inventory_items`, each showing icon, quantity and a
  durability/wear indication; hover raises a tooltip (name, quantity, durability,
  the item's description); right-click opens a menu whose actions are the bus
  intents that already exist, so no new authority path is introduced.
- `src/ui/ui_slice.gd` — the Controls panel behind `?`: the EXISTING legend,
  MOVED rather than authored. The `I / T / C / Y / M / G` and movement/action
  bindings the HUD paints today are re-hosted in a new window that is collapsed by
  default.
- `src/player/player_slice.gd` — DELETION of the always-on legend:
  `_build_shortcuts_menu()` (`:781`) and its call site in `_build_hud()` (`:620`)
  both go, so the HUD paints no legend at all and the `?` panel is its only home.
  The drawn mouse-button cues the legend uses move with it — `_add_mouse_row()`
  and `mouse_icon.gd` (`src/ui/mouse_icon.gd`, loaded as `MouseIconScript`) are
  PORTED into the `?` panel, so the moved legend keeps its icons instead of
  degrading to a text list.
- `inventory_lines()` STAYS: it is the pure projection the suite asserts, and the
  grid is built from a pure projection (`inventory_rows()` / a slot view) rather
  than by reading `Control` state.

**Acceptance criteria:**
- [x] Every window drags by its title bar and reopens at its stored position
  across a restart; a window cannot be dragged fully off-screen.
- [x] An inventory of N items renders N slots in a grid; hovering shows
  name/quantity/durability; right-clicking offers the actions the item supports
  and each action emits the same bus intent the text UI emitted (assert the
  projection and the intent, not the widget).
- [x] An item with no icon asset renders the placeholder glyph, and one whose
  icon is present in a mounted pack renders the icon — `AssetOverlay.asset_mode()`
  distinguishes the two.
- [x] No Controls legend is visible on the HUD before `?` is pressed: the panel
  `_build_hud()` used to paint is gone and `?` is the only way to see the bindings
  (assert the HUD's child set, not a screenshot).
- [x] `?` opens and closes the Controls panel; ESC still closes the topmost
  window and the last close re-captures the mouse (the world-input gate is
  unchanged and no attack/mine slips through an open menu).
- [x] The suite is green on both boot paths, with tests for the new projections.

**Implementation notes:**
- **Persisted position is per-player state, so it needs a record home and an
  eviction point.** The same rule Phase 37 landed for flags, companions and
  cooldowns. A layout is not authority-bearing — a client may own its own view —
  so the choice between a player-record field (replicated, evicted by
  `forget_player_id`) and a local settings file (client-only, not per-connection)
  is legitimate, but leaving it in an in-memory dictionary that nobody evicts is
  not. Say which one and why.
- **The drag and the grid are `Control` code, and the suite cannot run them.**
  Everything decidable outside the tree stays pure: the off-screen clamp, the
  slot projection, the button-to-intent mapping and the key-to-window table.
  Assert those.
- **Reuse the existing intent paths.** Equipping, using and dropping go through
  the bus signals the crafting/equipment paths already consume, so the owner
  scoping and host binding rules (Phase 36/37) are inherited rather than
  re-derived. A UI that invokes a slice method directly re-opens a hole the
  network passes closed.
- **Icons resolve at fill time, not once per item definition.** The overlay may
  or may not have a pack mounted; caching a resolved path across that decision is
  how a placeholder gets painted over real art.

**Known simplifications (deferred):**
- **No layout save/load UI, no snapping or docking, no resize handles** — drag
  plus persist only.
- **No drag-and-drop between slots or containers.** The right-click menu is the
  only item action surface in this phase.
- **No redesign of the crafting / technology / trade / market / proposals
  windows.** They keep their contents and gain only the shared drag shell.
- **No gamepad or keyboard navigation** of the windows.

**As landed:**
- Layout persistence is a **client-only settings file** (`user://ui_layout.json`):
  a layout is a view preference with no authority, so it does not ride the player
  record. One entry per known window key, overwritten in place, unknown keys
  dropped on load — nothing accumulates, so there is no eviction point to miss.
- The slot right-click menu offers only intents that already exist on the bus.
  Today that is **Repair** (`repair_requested`) for held, non-pristine items with a
  repair spec; there are no equip/use/drop bus intents yet, so none are offered.
- No `icons/items/*` art is committed, so every slot paints the initial-letter
  glyph until a pack provides the key.

---

## Phase 47 — Character window ✅ Done

**Goal:** Equipment is a visual system with no interface and no numbers.
`apply_equipment(instance_id, slot, item_key, state)` attaches a socketed
placeholder to the rig and `equipmentSlot` is a fabric field on every
equippable, but nothing shows what is worn, nothing totals what wearing it means
(the armor entities carry prose — "reliable head protection" — and no numeric
value), and a worn set is neither persisted nor shared: a peer's gear is not
replicated, which is why the fabric's bare-hands rule is still evaluated against
the claim riding that peer's tame intent (the open `Peer equipment replication`
entry in the Deferred list, deferred from Phase 36). This phase gives the
character its window: armor slots on the existing `apply_equipment`, a derived
stats panel, equipped-state persistence, and peer equipment replication.

**Newel dependency:** YES — the derived stats panel needs NUMBERS on the
equippable items (`fabric/gameplay/items/shared.js`): a `defense`/`armorValue`
(and any other derived-stat contribution the panel sums) per armor entity, so a
stat is a sum of fabric values and never a reading of prose. `pnpm validate`,
`pnpm generate`, `pnpm check-drift` re-run; no runtime stat may be authored in
GDScript.

**Closes:** item 5 and the Deferred list's `Peer equipment replication` entry
(deferred from Phase 36).

**Deliverables:**
- `src/ui/ui_slice.gd` — a Character window (a new window key, toggled like the
  others) listing one slot per `equipmentSlot` the fabric defines, each showing
  the equipped item's Phase 46 icon and opening the shared right-click menu.
  Equipping issues the existing intent, so `apply_equipment` remains the only
  mutation path.
- `src/character/character_slice.gd` — `derived_stats(instance_id) ->
  Dictionary`, pure and headless-testable: it sums the equipped entries' fabric
  values (defense total, wear/durability, and whatever else the phase adds) and
  reports an empty set as zeros.
- `src/persistence/player_registry.gd` — equipped state on the player record
  (`record_equipment` / `get_equipment`, applied on join with `apply_record`), so
  a worn set survives a restart the same way flags, companions and technology do,
  with the eviction point that path already has.
- `src/networking/networking_slice.gd` + `src/character/character_slice.gd` —
  peer equipment replication: the host sends a peer's worn set to the peers whose
  area of interest contains it (Phase 29), and a client applies it to that peer's
  character instance, so the bare-hands rule and any defense check read
  replicated truth instead of a payload's claim. Identity is bound to the
  connection (a payload's `player_id` is ignored — Phase 36's rule).
- The bare-hands rule's consumers are re-pointed at the replicated set, and the
  tame-intent claim path is deleted or narrowed to the handshake window rather
  than left alongside it.

**Acceptance criteria:**
- [x] The Character window lists one slot per fabric `equipmentSlot`; equipping
  from it changes the avatar's attachment AND the derived stats panel's numbers.
- [x] The panel's totals equal the sum of the equipped fabric values, asserted
  against a synthetic set including the empty case (all zeros).
- [x] A worn set survives a host restart and a reconnect, asserted through the
  player record rather than through a client's own view.
- [x] A second peer's client sees the first peer's worn set on that peer's
  character instance, and a peer that forges a fully-armoured claim in its
  payload does not change what the host believes the peer is wearing.
- [x] The suite is green on both boot paths, and the two-client harness still
  reports `10/10 steps agreed across both peers` if the replication adds a step.

**Implementation notes:**
- **A derived stat may not be computed from prose.** Every number the panel shows
  is a fabric field summed by a pure function; a stat that exists only in the UI
  is a stat the host cannot validate and two clients can disagree about.
- **Equipped state is per-player durable state, so it needs a record home and an
  eviction point** — Phase 37's rule applied a third time. It travels on the join
  snapshot plus the per-player push, and it is released by the same
  `forget_player_id` path the flags and companions use.
- **Replication is an interest-management problem, not a broadcast.** A peer's
  gear travels with that peer's character record and is delivered to the peers
  whose AOI contains it (Phase 29) — never `_broadcast`, and never through a
  signal that fails to name its owner (the `inventory_synced(owner_id, …)` shape
  Phase 37 established). A per-player signal with no owner is a signal every
  instance of that slice will apply.
- **The bare-hands rule is a security-relevant consumer, not a display.**
  It gates a tame. Once equipment is replicated, the host evaluates the rule
  against the host's own copy of the peer's worn set, so a client cannot claim a
  free hand it does not have. Keeping the old claim path "just in case" keeps
  exactly the hole the replication closes.
- **Socket attachment is unchanged.** `apply_equipment` still resolves the item
  definition, refuses an unknown slot and attaches through `_attach_equipment`;
  the window and the replication both go through it, so there stays one mutation
  path.

**Shipped as:** `fabric/gameplay/items` gained an integer `defense` field
(helmet 4, chestplate 10, cloak 2, shield 6); `src/character/equipment_rules.gd`
holds the pure slot table / `sanitize` / `totals` / `hands_free`;
`CharacterSlice.derived_stats` / `get_equipment_set` / `apply_equipment_set` /
`set_peer_equipment`; `PlayerRegistry.record_equipment` / `get_equipment` (on the
record, the join snapshot and `evict_player`'s record drop); bus signals
`equip_intent` / `equipment_changed` / `peer_equipment_synced` (the client's first cut
sent a whole worn set as `equipment_intent`; Phase 60 replaced it with per-slot host-validated
actions); the Character window (key `K`). `TamingSlice.is_unarmed` reads the registry
(the tame intent's dead `unarmed` argument is gone, see Phase 60).

**Known simplifications (deferred):**
- **Replication is delta-only.** A peer's set is sent to
  AOI peers when it changes; a peer entering AOI later learns it on the next
  change. Remote peers have no character instances on a client yet, so the set is
  stored per owner and applied once `bind_peer_character` binds one. The
  two-client harness now has an `equipment_recorded` step (`11/11`): the host
  grants the item, the client claims a set over the socket (plus a wrong-slot and an
  unknown item) and the host records only the legitimate entry. Delivery of that
  set to a third peer is still covered in the suite, not over a socket.
- **Disconnect eviction of `_peer_equipment`/`_peer_characters`** on the client is
  wired (`forget_peer` from `_on_peer_disconnected`, asserted in the suite). A joiner's
  own restored set is now also pushed to the peers already in its AOI
  (`send_peer_equipment_to`, both directions).
- **No combat effect beyond the displayed totals.** Unless defense becomes a term
  in the damage formula in this phase, the panel shows a number nothing consumes —
  say so plainly instead of implying the armor already reduces damage; wiring it
  into `battle_slice` is a follow-up.
- **No set bonuses, sockets or enchantments.**
- **No upgrade/downgrade comparison** in the character window beyond the shared
  slot tooltip.
- **Equipment wear stays a visual indication** (`_wear_level`); the window is not
  a repair gate — repair remains the Phase 25 path.
- **No attributes — deliberately excluded, pending a fabric decision.**
  `fabric/gameplay/player.js` carries only `baseHp`, `currentHp` and `baseSpeed`:
  there is no attribute model (no Strength/Dexterity/Intellect, no attribute-to-
  stat derivation), and this phase does NOT invent one — the panel sums equipped
  gear values only, and nothing here may author an attribute or a derived-stat
  input in GDScript. Adding attributes is a design decision, so it belongs in
  `fabric/constitution/decisions.js` (a `decision` entity taken through the
  `proposed` → `accepted` state machine under community governance), not in a UI
  phase that would then be read as the authority for it.

---

## Phase 48 — Review pass: the equipment trust boundary ✅ Done

**Goal:** Phase 47 made the host the owner of a peer's worn set, but the review
follow-ups (#63, #64, #65, #66, #70) list the places where that ownership still
leaks: the claim is unbounded, ownership is checked only at equip time, the
listen host's own gear never leaves the host, and gear is only sent on change or
join. Close the host-side holes; display-only niceties stay out of scope.

**Newel dependency:** NO.

**Closes:** the host-side items of #63, #64, #65, #66 and #70.

**Deliverables:**
- `src/persistence/player_registry.gd` — `_on_equipment_intent` ignores a `worn`
  dictionary larger than `EquipmentRules.slots().size()` (no per-entry inventory
  lookup for an oversized claim) and filters slot keys through
  `EquipmentRules.sanitize` before the bag check.
- `src/persistence/player_registry.gd` — worn-set revalidation: when an item
  leaves a player's bag (drop, trade, craft consumption, sale), any slot wearing
  an item the bag no longer holds is cleared and the change is recorded and
  replicated like any other equipment change.
- `src/networking/networking_slice.gd` — the listen host's own worn set is
  replicated to the clients whose AOI contains the host avatar (the host has no
  peer id, so it is addressed by its player id / the `1` server peer).
- `src/networking/networking_slice.gd` — peer equipment is sent when a peer
  ENTERS another peer's AOI (not only on change / join), and a client evicts a
  peer's stored set when that peer leaves its AOI.
- `src/character/equipment_rules.gd` — `slots()` is computed once and cached;
  an empty `items` argument no longer silently means `GameData.ITEMS` (pass it
  explicitly).

**Acceptance criteria:**
- [x] A `worn` claim with more entries than there are slots is dropped without
  touching the record, asserted in the suite.
- [x] Wearing an item, then trading/dropping it away, clears that slot on the
  player record and emits `equipment_changed`; asserted through the record.
- [x] A client sees the listen host's worn set (suite test on the replication
  target list; the host is included). _`_test_equipment_host_and_aoi_transitions`
  drives `equipment_targets` / `_on_equipment_changed` through the networking
  slice's no-socket test seam (`_test_peers`, `_test_outbox`)._
- [x] A peer that walks into AOI after the last gear change receives the set; a
  peer that leaves AOI has its stored set evicted on the client. _Same test:
  `_refresh_equipment_pairs` sends on enter, emits one `peer_equipment_evict`
  per viewer on leave, and nothing more while the peer stays away._
- [x] Suite green on both boot paths; `net-harness` still reports
  `11/11 steps agreed across both peers`.

**Implementation notes:**
- Revalidation hooks the existing inventory-change path on the host; it must not
  add a second mutation path for equipment — clearing a slot goes through
  `record_equipment` and the same replication as an equip.
- The bare-hands rule still trusts an OMISSION (a client that never reports its
  weapon reads as unarmed). Fixing that needs host-authoritative equip (the host
  decides what is in the hand), which is a design change; it stays a known
  simplification and the taming comments must say so instead of overstating the
  protection.

---

## Phase 49 — Zone crossing and natural ground ✅ Done

**Goal:** Crossing a chunk edge glitches, and the ground does not look like
ground. Four separate problems produce this:

- **The biome is a stripe pattern.** `biome_for_chunk`
  (`src/terrain/terrain_slice.gd:122`) computes
  `posmod(BIOME_SEED + cx*2654435761 + cz*2246822519, 5)`. Modulo 5, those
  constants are 0, 1 and −1, so the expression reduces to `(cx − cz) mod 5`. As
  a result the biome changes on every axis-aligned chunk crossing (every 32 m) in
  diagonal stripes. The layout is identical in every world because it ignores
  the world seed. Each crossing therefore changes the ground colour, tree
  density and creature table all at once.
- **Concurrent builds produce seam walls.** A neighbour counts as "known" only
  after it has been built (`voxel_slice.gd:298`, `_gather_neighbour_heightmaps`
  `voxel_slice.gd:465`). With `DEFAULT_MAX_BUILDS_IN_FLIGHT := 4`, two adjacent
  new chunks often each treat the other as empty. Both then emit a full
  bedrock-to-top wall on the same plane. That wall z-fights under
  `CULL_DISABLED` and nothing ever rebuilds it, because `chunk_loaded`
  (`chunk_manager.gd:465`) has no consumer. The same wall is also in each
  chunk's trimesh collision. The capsule catches on it and
  `resolve_step_up` fires at the seam (`player_slice.gd:493`).
- **Crossing causes frame spikes.** A crossing unloads 9–17 chunks in one frame,
  and each unload runs `_prune_heightmaps`, which scans every heightmap key
  (`voxel_slice.gd:931`). The frames that follow each run three expensive steps:
  - a 4096-sample GDScript `generate_heightmap`;
  - a main-thread `ConcavePolygonShape3D.set_faces`;
  - a tree spawn that scans every live tree (`tree_slice.gd:130`).

  On top of that, every 96 m AOI re-scope (`AOI_RADIUS`) sends the client the
  whole world's edit manifest (`game_root.gd:1194`).
- **There is no grass.** Ground colour is the biome's host material
  (`ore_field.gd:69`). Temperate ground is pale-grey Ferrite and TwilightGrove
  is solid gold. A run is one colour from top to sides, and the only green in
  the game is `FALLBACK_TERRAIN_COLOR`.

This phase makes chunk edges invisible, makes biomes large, seeded and blended,
and covers most land with a grass topsoil so the world reads as Earth-like.

**Newel dependency:** YES. Biome entities (`fabric/world/biomes/*.js`) gain the
following fields, authored from each biome's prose:
- `surfaceMaterial` (e.g. `Grass`, `Moss`, `Ash`, `Void` — the covers the five
  biomes actually declare);
- a surface tint (`surfaceTint`) and a side-wall tint (`soilTint`);
- `topsoilDepth`;
- `soilMaterial` (issue #111: what mining a slice within `topsoilDepth` yields —
  the surface-material → soil-material mapping, authored here so no GDScript
  branch decides which cover becomes which soil);
- `surfaceVeinChance` (the per-biome share of the surface-reaching top-cell veins
  kept, read by `OreField.surface_vein_chance`);
- a climate envelope (`temperature` and `moisture` ranges) that the climate
  field selects with.

A `Grass`/`Soil` material pair joins `fabric/world/materials/`. Run
`pnpm validate`, `pnpm generate` and `pnpm check-drift`. No surface table may be
hand-written in GDScript.

**Closes:** the zone-crossing glitch and the non-natural zone materials (user
report, 2026-10-04).

**Deliverables:**
- `src/terrain/voxel_slice.gd`: an unbuilt neighbour's heightmap comes from
  `terrain_slice.generate_heightmap`, which is deterministic since Phase 41,
  rather than being treated as "unknown". Seam walls are then exact whatever
  the build order. Only the outer edge of the streamed window emits a skirt,
  and that skirt stops at the neighbour's generated surface rather than
  bedrock.
- `src/terrain/chunk_manager.gd`: consume `chunk_loaded`. When a chunk's first
  build guessed a neighbour that has since arrived with edits, rebuild that
  chunk once.
- `src/terrain/climate_field.gd` (new, pure): world-seeded, low-frequency
  `temperature(world_xz)` and `moisture(world_xz)` noise. `biome_at(world_xz)`
  picks the fabric biome whose climate envelope fits. Biomes become regions
  hundreds of metres across, not 32 m stripes.
  - `get_biome_at_chunk` stays as "the biome at the chunk centre" for spawn
    tables.
  - Colour and surface read the per-tile biome, blended across a border band
    of a few tiles with a deterministic dither.
- `src/terrain/voxel_slice.gd`: a topsoil model.
  - An unedited natural column's top face takes the biome's
    `surfaceMaterial` tint, with low-amplitude noise variation.
  - Side walls show soil down to `topsoilDepth`, with rock (the ore field's
    host material) below that.
  - The mesher already groups faces by direction and colour, so a top colour
    that differs from the side colour costs no extra draw calls.
  - Mining a slice within the topsoil yields the biome's fabric `soilMaterial`
    (Grass, Moss, Ash and Void covers alike), the host rock below. A placed block
    keeps its own colour.
- `src/terrain/ore_field.gd`: a surface-breaking vein is the exception, not
  55% of cells. A deposit marker shows only where the vein's top cell reaches
  the surface, and its density is the biome's fabric `surfaceVeinChance`.
- Crossing cost is spread over frames:
  - unloads are budgeted per frame like loads;
  - `_prune_heightmaps` is indexed by chunk, so it no longer scans every key;
  - tree spawn uses the spatial hash rather than a scan of every live tree;
  - the AOI re-scope snapshot carries only the edits of chunks inside the
    peer's AOI.
- `src/ui/minimap.gd` reads the per-tile biome and surface colour.

**Acceptance criteria:**
- [x] `terrain: neighbouring chunks mostly share a biome`: over a 32×32-chunk
  sample, at least 80% of axis-adjacent chunk pairs share a biome, and two
  seeds produce different layouts. This replaces the stripe pattern.
  `_test_chunk_biome_stable` still passes.
- [x] `voxel: concurrent seam is exact`: two adjacent chunks built from the same
  first-ring snapshot (neither built before the other) emit no wall at a seam
  where the surface is level. The faces match the sequential
  `_test_voxel_seam_wall_order_independent` result.
- [x] `voxel: grass top, soil side`: an unedited temperate column's top-face
  colour is the fabric grass tint and its side colour is soil.
  `_test_voxel_biome_materials` is updated to assert rock under the topsoil. _Suite
  `voxel: grass top, soil side` asserts grass top, soil within `topsoilDepth`, rock below._
- [x] With the camera in-game at default view distance, walking 20 chunks in a
  straight line shows no frame over 33 ms in the frame-time log and no
  visible seam flicker. The walk needs a person at the keyboard, so it is not an
  acceptance criterion: it is filed as #133 (human verification) and the phase
  proceeds without it.
- [x] An AOI re-scope snapshot's `edits` holds only chunks inside the AOI. _Suite
  `net: re-scope snapshot edits hold only AOI chunks`; the snapshot names its scope
  (`edits_aoi`) and the client keeps edits it holds outside it._
- [x] `pnpm check-drift` is clean and the suite is green on both boot paths.
  `tools/net_harness.sh` agrees on a fresh world. _check-drift clean, suite 8767/8767, net_harness 12/12._

**Progress:** the unbuilt-neighbour seam fix is in (`_generated_heightmap`). Biomes are chosen by the
fabric climate envelopes: biome entities carry `temperature`/`moisture` ranges (0–1) and
`src/terrain/climate_field.gd` samples world-seeded value noise (12-chunk wavelength) and picks the
biome whose envelope fits (`biome_for_climate`). `Grass`/`Soil` are fabric materials. Mining a slice
within a biome's `topsoilDepth` yields that biome's fabric `soilMaterial` — Grass, Moss, Ash and Void
covers alike yield `Soil`, not only the temperate one — with the host rock below. Topsoil colouring uses
the biome `surfaceTint`/`soilTint`/`topsoilDepth` fields. Surface veins are the exception, and the
density is each biome's own fabric `surfaceVeinChance` (badlands 0.25 … rift 0.05; the GDScript constant
is now a fallback for a missing resource only), so the field is observable. The minimap colours chunks
by `surfaceTint`. Frame-spike items
are in (`_prune_heightmaps`, tree and creature spawn/despawn indexed by chunk; unloads budgeted per frame; a chunk's heightmap is generated once).
The per-tile surface blend is in (`VoxelSlice.blended_biome`: a 4-tile border band with a
coordinate-hash dither), `ChunkManager` rebuilds built neighbours once when a chunk with edits
streams in, and the minimap draws 4x4 dithered cells per chunk. `ClimateField` and `OreField`
read plain snapshots filled by `OreField.warm()`, so the worker half never touches a Resource.
Every automated acceptance criterion passes: `check-drift` is clean, the suite is green
(8767/8767, both boot paths), and `net_harness.sh` reports 12/12. The 20-chunk in-game walk with a
frame-time log and screenshot needs a human, so it left the criteria for #133 and the phase is
done.

**Issue #111 follow-up (PR #110 review):** the surface-material → soil-material mapping is no longer a
GDScript branch on `surfaceMaterial == "Grass"` — it is the biome's fabric `soilMaterial` field
(`VoxelSlice._natural_yield`), so every cover yields soil and a new biome needs no code. The
per-biome `surfaceVeinChance` values were varied from the uniform 0.2 default so the fabric field
actually gates the field (pinned by `ore: surface-vein chance is the fabric value`, which measures the
kept share per biome off the ore field).

**Issue #111 follow-up, review pass:** the field's TARGET is now pinned — `voxel: every biome declares a
surface style` asserts each biome's `soilMaterial` names a declared fabric material, because
`_natural_yield` returns it verbatim as the mined item and a fabric typo would otherwise mint a phantom
material.

**Issue #111 follow-up, second review pass (docs-only):** the phase's own **Newel dependency** list now
names every field the phase adds — `soilMaterial` (this branch's new biome field) and the per-biome
`surfaceVeinChance` the Deliverables already cite, plus the real `surfaceTint`/`soilTint` names. The
list was the pre-#111 inventory and its `surfaceMaterial` example named `Sand`, a cover no biome
declares (the five biomes declare `Grass`/`Moss`/`Ash`/`Void`).

**Net harness:** it has 11 steps now (the equipment step joined it), so the `10/10 steps
agreed` lines in the older phase entries above are historical; a green run now reads `12/12`
(Phase 55 added `equipment_delivered`).

**Saved-world note (biome function change):** the Voronoi biome regions replaced the stripe
biome hash, so a chunk's biome, and with it the host material of any ore vein anchored there,
changed for worlds saved before it. Terrain heights and vein positions are unchanged; only the
biome-dependent material (and spawn table) of an existing area can differ. Edits are keyed by
tile and kept. There is no save-format version to migrate: the world is re-derived from the
seed on load.

**Known simplifications:**
- The grass is a vertex colour, with no texture and no grass blades. Textured
  terrain needs UVs that greedy merging drops; deferred.
- The climate field is planar here. Phase 51 makes temperature follow latitude
  and altitude.

---

## Phase 50 — Planet coordinates ✅ Done

**Goal:** The world is an 8 km square: `WORLD_RADIUS_CHUNKS := 128`,
`clamp_to_world` at `terrain_slice.gd:152`, and float32 positions with no
origin rebasing. The target is one persistent, Earth-sized world (about
510 million km²) that players can locate each other in by coordinates.

A literal voxel sphere is not attempted: gravity would vary per position, and
a cube-sphere chunk grid distorts at its face seams. Instead the world takes
**globe semantics on a flat chunk grid**:
- X wraps (about 40,000 km around), so walking east eventually returns you
  home.
- Z is latitude, bounded by impassable polar ice.
- Players see latitude, longitude and altitude.

The terrain is already seed-deterministic and only edits are stored, so the
huge world costs storage only where players build. Around 5×10¹¹ chunks are
generated on demand and never written.

**Newel dependency:** YES. A world-system entity in `fabric/world/world.js`
holds `circumferenceKm`, `polarLatitude` and `seaLevel` (used by Phase 51), so
the planet's size is a fabric fact.

**Closes:** the world-size limit.

**Deliverables:**
- `src/terrain/terrain_slice.gd`: `wrap_chunk(chunk_pos)` and
  `latitude_of(chunk_z)` / `longitude_of(chunk_x)` replace
  `WORLD_RADIUS_CHUNKS` and `clamp_to_world`. Noise sampling is periodic in
  X, so the wrap seam is invisible. Two options: 4D noise on a cylinder, or a
  blend over the last chunk column.
- A world position becomes `{ chunk: Vector2i, local: Vector3 }` everywhere it
  is saved or sent: player records, the join snapshot, edit RPCs, AOI
  centres, creature and station positions. An `int32` chunk index covers the
  whole planet (about 1.25M chunks per axis).
- The client rebases the scene origin when the player drifts more than about
  2 km from it, shifting all streamed nodes in one frame. The physics and
  render scene never see a large coordinate. The headless server keeps
  chunk-relative positions per entity.
- The HUD and minimap show latitude, longitude and altitude. `/where` prints
  them.
- Save migration: a pre-Phase-55 world maps its old origin to a fixed
  latitude/longitude, and old float positions convert to chunk + local.

**Acceptance criteria:**
- [x] `terrain: the world wraps east-west`: the heightmap of chunk
  `(circumference_chunks − 1, z)` meets chunk `(0, z)` with no seam wall.
- [x] `player: rebased origin keeps the world position`: after a rebase, the
  player's `{chunk, local}` is unchanged and every streamed chunk node is
  shifted by the same offset. _Suite: `WorldPos` rebase math plus `VoxelSlice.shift_scene` on chunk roots and the world floor; the per-frame client driver is still open._
- [x] A player teleported 10,000 km out walks, mines and builds with the same
  0.125 step precision as at the origin. The quantiser unit test at chunk 312,500 is
  in the suite; the in-game walk needs a person at the keyboard, so it is not an
  acceptance criterion: it is filed as #134 (human verification) and the phase
  proceeds without it.
- [x] A Phase 49 save loads with its edits at the mapped coordinates. _Player records migrate (suite); world/edit saves untouched, as edits are keyed by tile and the origin is unchanged._
- [x] Suite green on both boot paths (8785/8785, `--run-tests` with and without `--server`), and `tools/net_harness.sh` agrees (12/12 steps).

**Progress:** the `WorldSystem` fabric entity (circumferenceKm, polarLatitude,
seaLevel) is in. `TerrainSlice` has `wrap_chunk`, `latitude_of`/`longitude_of`/`latitude_at`/
`longitude_at`, `circumference_chunks`, `polar_chunks`; X no longer clamps, Z stops at the polar ice,
and heights blend over the last 8 east chunks into the west edge so the seam is exact. The minimap
draws only the polar lines. `src/terrain/world_pos.gd` holds the pure `{chunk, local}` conversion and
rebase math, covered by the suite. Player records save `chunk` + `local` beside `position` (old saves migrate
onto the same coordinates, `PlayerRegistry.world_pos_of`), and the minimap shows latitude/longitude/altitude
(`TerrainSlice.where_text`). Still open: float32 noise precision far from the origin (needs an
integer-lattice noise), canonicalising chunk keys at the seam in `ChunkManager`/`VoxelSlice`,
`{chunk, local}` in snapshots, RPCs, AOI, creatures and stations (player records done), the client scene-origin
rebase driver (`VoxelSlice.shift_scene` shifts chunk roots and the floor, suite-tested; trees, creatures, stations,
the player body and the trigger on `WorldPos.needs_rebase` are still to wire), a `/where` chat command (no command system exists; `where_text` is ready), and the
map/migration of world and edit saves. These remaining wiring items are tracked in #136; every acceptance criterion above passes.

---

## Phase 51 — Continents, oceans and mountains ✅ Done

**Goal:** Terrain is a single gentle FBM field 0–5 m tall (`HEIGHT_SCALE := 5.0`,
3 octaves at frequency 0.05) in a −8..16 m column. It has no sea level, no
ocean, no mountain and no climate. This phase gives the planet a large-scale
shape and makes biomes follow climate the way Earth's do.

**Newel dependency:** YES.
- Biome climate envelopes from Phase 49 are extended with altitude.
- Earth-like biomes join the fantasy ones: Ocean, Beach, Desert, Tundra,
  Alpine, Taiga and Savanna, each with `surfaceMaterial`, `treeDensity` and
  spawn rules.
- Fantasy biomes (TwilightGrove, VolcanicBadlands, VoidRift) become rare
  climate niches, not equal-share zones.
- `seaLevel` and the height range live on the world entity.

**Closes:** none (new capability).

**Deliverables:**
- `src/terrain/terrain_slice.gd`: layered height built from three noise
  fields:
  - **continentalness**, at thousand-kilometre scale: ocean basin, shelf,
    coast or inland;
  - **erosion**: flat plains versus rugged land;
  - **ridges and peaks**: mountain ranges.

  These combine through a fabric-authored spline. Sea level is at 0, and the
  vertical range grows to about −64..+512 m. Sparse runs (Phase 41) keep a
  tall column cheap, and `BEDROCK_DEPTH` moves with the surface (a fixed
  thickness below it).
- `src/terrain/climate_field.gd`: temperature falls with `|latitude|` and with
  altitude, and moisture follows distance to the ocean plus noise. The result
  is snow-capped peaks, polar tundra and equatorial forest.
- Water: a flat water surface mesh per chunk wherever terrain is below sea
  level, and a swim/wade state in `player_slice.gd`. This is a static water
  level only; the fluid CA stays deferred.
- Distant terrain: coarse heightmap rings outside the 3-chunk voxel window,
  render-only with no collision, so coastlines and mountains are visible from
  afar.
- Spawn tables (trees, creatures, ore bias) read the climate biome, and ocean
  chunks spawn none of the land tables.

**Acceptance criteria:**
- [x] Over a 1,000 km sample transect, the fraction of the transect below sea level
  lands within the fabric's target ocean share (about 60–70%), and at least
  one height above 300 m appears.
- [x] `climate: poles are cold, peaks are cold`: the biome at latitude 85° is
  polar, and a 450 m peak at the equator is Alpine.
- [x] A player cannot walk into deep water as if it were ground: they swim at
  the surface (a suite test on the movement state).
- [x] A distant-terrain ring renders at 10× the voxel window with no collision
  bodies (asserted).
- [x] `pnpm check-drift` clean and the suite green on both boot paths. _Drift clean; suite 9056/9056 with and without `--server`; `tools/net_harness.sh` 12/12._

**Progress:** done. `src/terrain/world_shape.gd` (integer-lattice, periodic, worker-safe
continentalness / erosion / ridges through the fabric `heightSpline`, with a spawn plain),
`ClimateField` (temperature from latitude and altitude; altitude envelopes; `rarity` niches for the
fantasy biomes), seven Earth-like fabric biomes (`fabric/world/biomes/earth.js`) plus Sand and Snow
materials, `WorldSystem` height/ocean fields, per-chunk water surface meshes (`VoxelSlice.water_mesh_for`),
swim/wade in `player_slice.gd`, and `src/terrain/distant_terrain.gd` (a 10× ring, render-only, wired
in `game_root.gd`). `BEDROCK_DEPTH` is a fixed −72 m (8 m under `minHeight`) and `MAX_HEIGHT` 640 m
rather than a per-column bedrock: a column is one run, so the deeper floor is free. The 1,000 km transect
criterion is tested pooled over 8 seeds × 5 latitudes (one transect is under half a continental
wavelength). The terrain heightmap samples the shape at chunk corners and interpolates, keeping the build split inside its budget.
Polar land is Tundra (the "polar" biome).

**Known simplifications:**
- No rivers or lakes above sea level (Deferred).
- No erosion simulation; the "erosion" field is noise.

---

## Phase 52 — Region storage and per-player server streaming ✅ Done

**Goal:** Two things stop the planet from persisting and simulating where its
players are.

- **One file holds every edit.** `user://saves/server/world.json` stores all
  edits and lives fully in RAM (`_edits`, `_edits_by_chunk`). Each save reads,
  merges and rewrites the whole file (`persistence_slice.gd`). That is
  O(total edits) and will not survive a planet.
- **The server only simulates near the origin.** The headless server streams
  chunks around a single centre, the idle body at `(16, 12, 16)`
  (`player_slice.gd:423`). Creatures and trees therefore only live near the
  origin, wherever the players actually are.

**Newel dependency:** NO.

**Closes:** none (scale prerequisite; sharding stays Deferred).

**Deliverables:**
- `src/persistence/region_store.gd` (new): edits are grouped into region files
  of 32×32 chunks (`regions/r.<rx>.<rz>.json`, later binary). A region is
  loaded when any of its chunks enters a streamed window, unloaded when none
  remain, and only dirty regions are written.
  - The interface is `load_region` / `save_region` / `list_dirty`, so a
    database backend can replace files without touching callers.
  - `world.json` keeps only global state: seed, market, governance and
    stations index.
- `src/terrain/chunk_manager.gd`: the server keeps a window per connected peer
  around that peer's position, with per-chunk reference counts. A chunk loads
  when its count first goes above zero and unloads when it returns to zero.
  The listen host keeps its own window as today.
- Creature and tree simulation, plus edit validation, run against the union
  window, so a peer 5,000 km away has a live world around them.
- Migration: a monolithic Phase 51 `world.json` splits into region files on
  first boot.

**Acceptance criteria:**
- [x] Two peers 100 km apart each have creatures simulated around them on a
  headless server (net harness step `far_peers_simulated`).
- [x] A save after editing one chunk writes exactly one region file.
- [x] Server RSS with 1,000 edited regions on disk and one connected peer stays
  within 10% of an empty world.
- [x] A Phase 51 save migrates with every edit intact.
- [x] Suite green on both boot paths, and `tools/net_harness.sh` agrees.

**Progress:** done. Verified: suite 10332/10332 on both boot paths, `tools/net_harness.sh` 13/13. `src/persistence/region_store.gd` (32×32-chunk region files `regions/r.<rx>.<rz>.json`,
`load_region` / `save_region` / `list_dirty`, pure region maths), `PersistenceSlice` writes a save's chunk
manifests region by region and keeps `world.json` to global state (`load_world_record`; `load_world()` is the
eager compatibility read; a Phase 51 monolithic record is split into regions on first read), and
`src/persistence/region_streamer.gd` keeps resident only the regions the streamed windows touch (clean regions
are released, dirty ones stay until a save). `ChunkManager` holds one window per connected peer
(`set_peer_center` / `clear_peer_center`) beside the local player's, with per-chunk reference counts; `game_root`
re-centres the peer windows twice a second and opens a joining peer's window before its snapshot is built.
The net harness gained `far_peers_simulated`.

**Known simplifications:**
- Region files are JSON; a binary format is a later swap behind the same interface.
- Region reads are synchronous on the main thread when a window first touches a region.
- The server always keeps the local (idle-body) window beside the peers' windows.

---

## Phase 53 — Spawn placement and friend codes ✅ Done

**Goal:** Every new player spawns at the hard-coded `Vector3(16, 12, 16)`
(`player_slice.gd:423`) on a terrain patch flattened for that purpose. On a
planet that puts everyone in one crowded square metre. A new player should
instead land on empty, habitable land. A group should be able to spawn
together using a code: the friend's existing `p_` player handle
(`player_registry.gd`, `HANDLE_PREFIX`), so no new entity is needed.

**Newel dependency:** YES. A world-system spawn rule in the fabric sets which
biomes count as habitable, the minimum distance from colonized regions, and
the friend spawn radius.

**Closes:** single spawn point.

**Deliverables:**
- `src/world/colonization_map.gd` (new): a per-region score built from edited
  chunk count, player homes and recent player presence. It persists with the
  Phase 52 region index.
- New-player spawn: a deterministic search (seeded by the player id) for
  habitable land (not ocean, ice or VoidRift) at least the fabric minimum
  distance from any colonized region. It lands on solid ground found by
  sampling the generated surface. The flattened `SPAWN_CENTER` disc is
  retired.
- Friend code: the join or new-character flow accepts an optional handle. A
  new player with a valid handle spawns on safe ground within the fabric
  radius (about 200 m) of that player's current position, or their last saved
  position if they are offline. An unknown handle falls back to the normal
  search, with a message.
- The handle is shown in the character window with a copy button.

**Acceptance criteria:**
- [x] `spawn: new players avoid colonized regions`: with 1,000 seeded colonized
  regions, 100 spawns all land on habitable land outside them.
- [x] `spawn: friend code lands near the friend`: the spawn is within the
  radius, on ground, and not in water.
- [x] An existing player reconnects at their saved position (Phase 33
  behaviour unchanged).
- [x] Net harness step `spawn_near_friend` agrees over the socket.

_Implementation notes:_
- Fabric: `WorldSystem` gained `spawnHabitableBiomes`, `spawnMinColonizedDistance` (2,000 m),
  `colonizedScore` and `friendSpawnRadius` (200 m). `SpawnFinder.rule()` reads them.
- `src/world/colonization_map.gd` persists as the `colonization` key of the world record and is
  seeded from the Phase 52 region files (one file = at least one edited chunk). There is no
  separate region index file: the region files are the index.
- The 20 m flattened disc in `TerrainSlice` is retired. `WorldShape`'s 1,500 m spawn plain (Phase 51)
  stays: the dev rig, the suite and the net harness stand on it, and nothing places a new player
  by it any more.
- Respawn after death goes to `PlayerSlice.respawn_point` (the player's placement), not the old
  fixed `(16, 12, 16)`.
- Friend codes ride the `join_intent` packet (`friend_code`, shape-checked as a handle on the host).
  An offline friend is found by hashing the ids of the player records on disk, which is linear in
  the number of records: fine per first join, worth an index if records reach the tens of thousands.
- The harness host answers a join with no code with RENDEZVOUS (the scenario's fixed stand-point);
  the `spawn_near_friend` step uses the real placer. `net-harness` reports
  `14/14 steps agreed across both peers`.

---

## Phase 54 — World clock, day and night, seasons ✅ Done

**Goal:** The only lighting is a static `DirectionalLight3D` at a fixed angle,
with no clock, day/night cycle, seasons or weather. A planet with latitude
should have days whose length varies, and seasons that are opposite in each
hemisphere.

**Newel dependency:** YES.
- The world entity gets `dayLengthMinutes`, `yearLengthDays` and `axialTilt`.
- Biomes get seasonal modifiers: foliage tint, snow line and growth or spawn
  multipliers.
- TwilightGrove's existing `dayNightSpeed` is reconciled with the global
  clock.

**Closes:** none.

**Deliverables:**
- `src/world/world_clock.gd` (new): the server-authoritative time is persisted
  in `world.json`, sent in the join snapshot and corrected by a periodic tick.
  The client interpolates between ticks.
- Sun angle and day length come from the clock, the player's latitude and the
  axial tilt. The southern hemisphere is in the opposite season.
- Seasons tint grass and foliage, put snow cover on surfaces whose seasonal
  temperature is below freezing, and apply the fabric growth and spawn
  multipliers.
- The HUD shows the time of day and season.

**Acceptance criteria:**
- [x] `clock: hemispheres are opposite`: on the same date, latitude +45° is in
  summer when −45° is in winter.
- [x] `clock: day length varies by latitude`: at the solstice, daylight is
  longer at +60° than at the equator.
- [x] A client's clock stays within 1 s of the host's over 10 minutes (net
  harness).
- [x] `pnpm check-drift` clean and the suite green on both boot paths.

_Implementation note:_ `src/world/world_clock.gd` holds the clock (`time_days`, host-owned, saved as
`clock` on the world record, sent in the join snapshot, ticked every 5 s as a `world_clock` packet) and
every projection as a static pure function. Fabric: `WorldSystem.dayLengthMinutes` / `yearLengthDays` /
`axialTilt`; every biome gets `seasonSwing`, `summerTint`, `winterTint`, `seasonGrowth`, `seasonSpawn`;
`dayNightSpeed` is now a 0–1 scale on how deep the biome's night runs against the global clock
(`WorldClock.biome_daylight`, 1 = follows the clock). Growth scales stump regrowth (`TreeSlice.regrow_seconds`)
and spawn scales a pack's chance (`CreatureSlice.season_spawn_multiplier`). The terrain tint and snow cover
are ONE tint on the shared terrain material, driven by the biome underfoot (no per-chunk re-meshing), so
snow whitens the whole loaded window rather than individual surfaces. The "within 1 s over 10 minutes"
criterion is asserted by a simulated 10-minute run in the suite (a 0.2 % fast client, 100 ms latency, ticks
every 5 s); the net harness step `clock_synced` (`15/15`) proves the same correction over the real socket.

---

## Phase 55 — Two-client harness: equipment delivery over the socket ✅ Done

**Goal:** The `equipment_recorded` harness step proves the host records a claim,
but its client verdict is vacuous and AOI delivery to a peer is covered only in
the suite (#71, #73, #74). Make the step's client side real and add a delivery
step.

**Newel dependency:** NO.

**Closes:** #71, #73, #74.

**Deliverables:**
- `src/tests/net_harness.gd` — `_step_equipment_recorded`: the client verdict
  asserts the packet was actually sent (drop the always-true `_await_until`), and
  the resend loop is replaced by a host-driven ready signal (the host acks the
  grant before the client claims).
- The step pins a fixture item (a named equippable key, not "first sorted key")
  and adds the case of an unknown item claimed under a REAL slot key.
- A new `equipment_delivered` step: the client equips, and the host's AOI fan-out
  delivers `peer_equipment` back to a second connection (or to the host's
  client-side view), asserted on both peers.
- `tools/net_harness.sh` planned-step count bumped; ROADMAP Phase 47 note
  updated with the new count.

**Acceptance criteria:**
- [x] Breaking the client send (e.g. not emitting the intent) makes the step fail
  on the client side, not only on the host side.
- [x] Unknown item in a real slot is refused by the host and recorded as such.
- [x] `net-harness` reports `12/12 steps agreed across both peers`, with the delivery
  step verified on both peers.

_Implementation note:_ the delivery step uses the listen host as the subject (its worn set
fans out to the client's AOI over the socket), and the client judges it on what ARRIVED
(`peer_equipment_synced`), not on the character slice's stored set: the host runs ahead into
the reconnect step and a dropped connection forgets the stored set. A worn item has to be in
the host's own bag, or the Phase 48 revalidation clears it on the next inventory event.

---

## Phase 56 — Station placement follow-ups ✅ Done

**Goal:** Close the PR #67 review findings (#68) so placement is cheap per frame,
consistent in height, honest when refused, and tested.

**Newel dependency:** NO.

**Closes:** #68.

**Deliverables:**
- `src/world/station_slice.gd` — `placeable_station_types()` cached (computed
  once from RECIPES/ITEMS); `placement_blocker` compares snapped cells (x/z on the
  1 m grid plus snapped y) instead of raw 3D distance, so two stations at the same
  x/z cell but different heights are judged by a defined rule; Public API header
  updated; `game_root` demo stations placed through `try_place_station`.
- `src/player/player_slice.gd` — `_station_target` feet fallback uses the same
  +0.5 y offset as the aimed branch; `_update_station_preview` is gated by
  `world_input_allowed()`; a refused `V` surfaces the `placement_blocker` reason
  (toast/status line via the UI shell).
- Suite tests for `_station_target` (aimed top face, side hit, feet fallback),
  the N toggle and V through `try_place_station`, including a refusal reason.

**Acceptance criteria:**
- [x] `show_preview` per frame does not rescan RECIPES/ITEMS (asserted by
  `StationSlice.placeable_scan_count`).
- [x] Overlap rule is defined on snapped cells and asserted for same-cell /
  different-height and adjacent-cell cases.
- [x] Preview ghost is hidden while a menu owns input.
- [x] A refused placement shows its reason; suite green on both boot paths.


_Shipped as:_ most of the deliverables had already landed with the Phase 49 review pass; this
phase added the missing suite tests (`_station_target` aimed top / side / underside / feet, the
V placement and its refusal reason on the label, the frozen-world ghost) and the scan counter.

---

## Phase 57 — Spawn determinism and cost follow-ups ✅ Done

**Goal:** Close the still-open PR #54 review notes (#55, #56, #57) on Phase 44
spawning: pin the hash, keep pack members in their chunk, stop the O(instances)
rescans, and fix docs that claim a client path that does not exist.

**Newel dependency:** NO (per-species density/chance values for bosses such as
RiftWarden are a fabric design question and stay out of scope).

**Closes:** the code items of #55, #56, #57.

**Deliverables:**
- `src/tests/test_suite.gd` — a test pinning `SpawnRoll._mix` (and the roll
  helpers built on it) to known output values, so an accidental hash change fails.
- `src/creature/creature_slice.gd` — a running live-population counter (updated on
  spawn, death, respawn, tame, despawn) replacing the per-call `live_population()`
  scan in `spawn_for_chunk` / `_tick_respawn`; the counter is asserted equal to a
  full scan after a mixed sequence.
- Pack centre inset by the maximum member offset so every member lands inside the
  chunk; packs larger than the offset table no longer stack on wrapped offsets.
- A creature resource missing `spawnChance`/`spawnDensity` logs one warning
  instead of silently never spawning.
- Per-species density salt (derived from the species key) so densities of
  different species/trees are not fully correlated.
- `src/world/tree_slice.gd` — `_chunk_biome` computed once per `spawn_for_chunk`.
- `spawn_roll.gd` header + ROADMAP Phase 44 wording: clients do not spawn
  creatures; the determinism is a host reload guarantee.

**Acceptance criteria:**
- [x] Hash-pin test exists and passes; changing `_mix` makes it fail
  (`_test_spawn_roll_mix_pinned`).
- [x] Every spawned member position lies inside its chunk (asserted over several
  chunks, full packs: `_test_spawn_pack_bounds_and_retry`).
- [x] Live counts agree with a full scan after spawn/kill/respawn sequences. _The
  running counter was replaced by a single pass (see note), so there is no second
  source of truth to compare; cap tests assert `live_population()` throughout._
- [x] Missing-field warning asserted (`_test_spawn_missing_fields_warns_once`);
  suite green on both boot paths.

_Implementation note:_ the running live counter was replaced by a single pass over the
instance table per `spawn_for_chunk` (survivors per species and the live count together),
which removes the per-species rescans without a second source of truth to keep in sync.
A cap-refused pack is also remembered and retried every 5 s while its chunk is loaded.

---

## Phase 58 — UI layout file robustness ✅ Done

**Goal:** Close the PR #60 review notes (#61) so a hand-edited or truncated
`ui_layout.json` and non-US keyboards behave.

**Newel dependency:** NO.

**Closes:** #61.

**Deliverables:**
- `src/ui/ui_slice.gd` — `parse_layout` rejects non-finite (NaN/inf) and absurd
  magnitudes per entry (that window falls back to its default); `_save_layout`
  writes to a temp file and renames over the target; `_apply_layout` clamps
  against the control's real size once laid out.
- The `?` controls-legend hotkey matches on `event.unicode == 63` (with the
  existing keycode path kept as a fallback) so non-US layouts open it.
- `parse_layout('not json')` test uses an input that does not log an engine
  ERROR line (or the parse path avoids `JSON.parse_string` noise).

**Acceptance criteria:**
- [x] A layout with `NaN`/`1e308` coordinates parses to defaults for that window,
  asserted in the suite.
- [x] Save leaves either the old or the new complete file (temp + rename),
  asserted by checking no partial file remains after a save.
- [x] Suite output contains no engine ERROR line from the layout tests.

---

## Phase 59 — Wire the Phase 45 rig into the game ✅ Done

**Goal:** `attach_rig`, `load_mesh`, `load_animation_library` and
`creature_model_key` have no non-test caller (#59), so the asset pipeline is not
exercised in play. Use it for the local avatar with a safe fallback.

**Newel dependency:** NO.

**Closes:** #59.

**Deliverables:**
- `src/character/character_slice.gd` — `attach_rig` hides the procedural box body
  and stops the procedural limb swing on success; on failure (missing scene,
  non-Node3D root — freed, not leaked) the procedural body stays.
- `RigTree.build_tree` checks the required clips (idle/walk/run/fall/land/attack/
  death), warns once per missing clip and maps missing ones to `idle`, so the
  placeholder rig does not spam "Animation not found"; the dead `anim_player`
  assignment / unused `player` param are removed or made real.
- Asset manifest: parsed once and cached; a private-pack `manifest.json` merges by
  key over the public one instead of replacing it.
- `game_root` / player boot calls `attach_rig` for the local avatar when a rig key
  resolves.

**Acceptance criteria:**
- [x] With the public placeholder rig, the avatar renders the rig only (no box
  body) and no "Animation not found" errors are logged. (See the Issue #112 note
  below — this criterion was false until the placeholder stopped being a triangle.)
- [x] With the rig key missing, the procedural body is used and nothing leaks.
- [x] Manifest merge asserted: a private key overrides, public-only keys survive.
- [x] Suite green on both boot paths.

**Issue #112 — the public placeholder rig was a single triangle.** Criterion 1 was
false on a public clone, and that was the whole of the bug: `attach_default_rig`
resolves to the committed `models/placeholder_rig.glb.raw` when no private player rig
is listed, `attach_rig` HIDES the procedural box body on success, and that placeholder
was ONE flat, single-sided 1x1 triangle in the XY plane (Phase 45 generated it as a
loader fixture, before anything rendered it). The player's own character was therefore
invisible from behind and a gray sliver from the front. `tools/gen_placeholder_glb.py`
now emits a BODY — a torso, a head, two arms and two legs as cubes on a flat node tree,
1.73 m tall with the feet on the root's ground plane — and the seven clips the tree
looks up (`idle`/`walk`/`run`/`fall`/`land`/`attack`/`death`, it shipped only `idle`),
so the clone logs no `[RigTree] rig has no …`. The six parts also had to be LINKED, which
the one-node triangle never needed: glTF reaches a node through its parent's `children`
array, so a node defined but never listed there is an orphan Godot imports without its
mesh — the root now names every part. The
suite pins the shape at `asset: placeholder rig is a visible body (#112)` — several
parts, ≥ 1 m tall, thickness on BOTH horizontal axes (a flat card fails here, which is
the exact regression), feet on the ground plane, every clip present. Measured: 6 parts,
merged AABB `size (0.84, 1.73, 0.30)`, `min y 0.000`.

**Review pass (self-driven, this branch).** Two items, both fixed in this pass. (1) The new
`asset: placeholder rig is a visible body` test built an `AnimationTree` and never freed it.
An orphan Node leaks to process exit — measured with a standalone `--script` probe: two
orphan `AnimationTree`s → `2 ObjectDB instances were leaked at exit` — and the rule the file
states after `_run_tests` plus both older `build_tree` callers free theirs. This one object
graph was 33 of the boot's leaked instances: the host boot's leak line went **44 → 11** and
the server's **53 → 20**, with the suite still `8781/8781` on both paths. (2) This note used
to claim the regeneration "fixed a silent loss in the old generator" — false, and the wording
above is corrected: the old file had ONE node and no `children` array, so nothing was orphaned
and nothing was lost (its single triangle rendered, which IS the reported bug); the orphan
hazard belongs to the new multi-part layout. Checked and found sound, no change needed: the
committed `.glb.raw` is byte-identical to a fresh `python3 tools/gen_placeholder_glb.py` run
(md5 `218d1100…` then, `95a5283d…` after the stride fix below, two runs each);
re-derived from the bytes, all six faces' winding cross-product
equals their outward normal (no face is backface-culled — that is the mechanism the triangle
bug came from), the tree carries no orphan node, and the merged AABB is exactly the quoted
`(0.84, 1.73, 0.30)` with `min y 0.000`.

**Review pass 2 (self-driven, same branch).** One item, fixed. The generator declared no
`byteStride` on the mesh's two vertex `bufferView`s, so Godot's glTF importer logged
`Buffer view byte stride should be declared for vertex attributes. Assuming packed data and
reading anyway.` three times on EVERY load of the rig — 24 lines across the 8 parses of one
`--verbose` boot (the seven asset tests plus the world boot's own `attach_rig`). `Blob.add`
now takes an optional stride and the POSITION/NORMAL views declare `12` (one tightly-packed
VEC3 float); the indices view must not declare one, so it does not. Re-measured on the same
verbose boot: **24 → 0 stride warnings**, the suite still `8781/8781` on both paths, and the
shape unchanged — the regenerated `.glb.raw` reads back the identical `(0.84, 1.73, 0.30)`
AABB at `min y 0.000`, the same seven clips, the same six-of-six outward winding, and no
orphan node, only 32 bytes larger (10 320 → 10 352). Independently verified this pass and
deliberately left alone: the world boot's exit noise — `11 ObjectDB instances were leaked at
exit` and `1 resources still in use` (`res://src/terrain/terrain_slice.gd`, named by a
`--verbose` run) — is IDENTICAL on `origin/main` with the old triangle, so it is pre-existing
and not this branch's. The world boot itself was exercised for the first time on this branch
(`--quit-after-boot`): the rig parses (`glTF: Total animations '7'`, six parts created) and
the run logs no `[RigTree] rig has no …` for the player's own rig — the only such lines are
the two deliberate negative tests.

**Review pass 3 (self-driven, same branch).** One item, fixed. The exit noise pass 2 recorded
as pre-existing had exactly one source inside this repo's test file:
`_test_rig_tree_state_mapping_total` (`src/tests/test_suite.gd:5637`) written
`RigTree.build_tree(AnimationPlayer.new())` — a bare `AnimationPlayer` with no parent, never
freed, so it survived to process exit as the single `Leaked instance: AnimationPlayer - Node
path: ` in the boot's leak report (the empty path is the tell: an orphan, not a world node —
the avatar's own player IS in the tree and is freed with it). It is pre-existing (`origin/main`
leaks the same instance and the same count) but it is the same defect class pass 2 fixed in the
test thirty lines above, in the file this branch edits, and the two-line fix is a strict
improvement rather than a re-roll: keep the player in a local and `player.free()` it after
`tree.free()`. Measured before/after on one boot each — host `11 → 10` leaked and the
`AnimationPlayer` **gone from the list**, `--server` `20 → 19`, the suite still `8781/8781`
`(0 failed)` on both paths (plus `[Server] listening on port 7777, max_clients 64`). No
behaviour changed — the player is only ever read by the tree builder.

Gates for this pass, all reproducing the branch's claims: `pnpm validate` ✓ Schema valid
(IR v3.0.0); `pnpm check-drift` ✓ No drift detected (555 file(s) match manifest); host
`--quit -- --run-tests` `8781/8781 passed (0 failed)`; `--server --quit -- --run-tests`
`8781/8781` + listening; `tools/net_harness.sh` under a fresh `XDG_DATA_HOME`
(`mktemp -d`) — `12/12 steps agreed across both peers`; the committed `.glb.raw`
byte-identical to a fresh `python3 tools/gen_placeholder_glb.py` run (md5
`95a5283d…`, no diff); `scripts/probe_glb.py` re-derived from the bytes — 7 nodes all
reachable, 0 orphans, clips `idle walk run fall land attack death`, **6 of 6 faces' winding
cross-product equal to their outward normal**, merged AABB exactly `(0.84, 1.73, 0.30)` at
`min y 0.000`. Also checked and found sound, no change needed: the new test's `root.free()` and
`tree.free()` are on every path (nothing leaks from it — the boot's lines are now dominated by
the four `FastNoiseLite` + four `Node` instances `origin/main` shares); the `_warned_missing`
static does not interact with the new test (the placeholder ships all seven clips, so it warns
for none — the only `[RigTree] rig has no …` lines in a full boot remain the two deliberate
negative tests); and the remaining exit noise (`1 resources still in use` —
`res://src/terrain/terrain_slice.gd` — and the five `Cannot get path of node` lines) is
identical on a `git worktree` of `origin/main` run side by side on the same `user://`, so it is
still not this branch's. `assets-prod` shows as a modified submodule in `git status` and was
left untouched, as in both earlier passes.
