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

**Follow-up debt cap.** No new feature phase starts while more than 10 `autopilot-followup`
issues are open. Burn them down first (fix, fold into the next phase, or close with a reason).

---

## Phase index

Phases 1–224 and 248 are done (200 and 201 were aborted). Their specs and acceptance criteria, and the
introductions of the arcs they belonged to, are archived in
[docs/roadmap-history/](docs/roadmap-history/README.md).

### Priority order

Set by the owner on 2026-11-10. Work the open phases top to bottom; the arc tables below keep their
numbers and specs, but this list decides what comes next. A phase that needs an earlier one still
waits for it. Phases 227, 228, 230, 231, 233, 236 and 246 are parked (see
[Parked phases](#parked-phases)). Phase 236 keeps its place in the list for when it is un-parked; the
others are not in it.

| Priority | Phase | Title |
|---|---|---|
| 1 | 238 | One world: a fixed seed, a 2,000 km planet and one continent |
| 2 | 239 | Streaming that keeps up |
| 3 | 249 | What to reuse from Zylann's godot_voxel |
| 4 | 240 | Smooth natural ground |
| 5 | 241 | The native smooth mesher, and coarse chunks built smooth |
| 6 | 242 | Terrain materials: blend weights, a triplanar shader and CC0 textures |
| 7 | 243 | Level of detail past the window |
| 8 | 244 | A chunk cache on disk |
| 9 | 225 | The options window |
| 10 | 237 | Flight that handles like flight |
| 11 | 250 | The server's ceiling: one machine serving, another running the bots |
| 12 | 245 | The planet bake: continents, rivers with flow, erosion and biomes at 2 km |
| 13 | 232 | Water that holds up: lake shores, the river seam and mounts at fords |
| 14 | 226 | Several characters per player |
| 15 | 229 | Skills capped by the gear |
| 16 | 247 | Ground cover: grass and bushes by biome |
| 17 | 235 | Roads |
| 18 | 234 | Boats |
| 19 | 236 | Changing hair style and colour (parked: picked up only when un-parked) |
| 20 | 251 | A human playtest: what would make the game fun |

Order notes that differ from the arcs' own order:

- Phase 242's low-end fallback and Phase 243's view distance are options of Phase 225, which now
  comes after them. They ship as project settings first, and Phase 225 puts them in the window.
- Phase 245 replaces Phase 217's river trace and now comes before Phase 232. Phase 232's river-seam
  fix applies to the baked rivers instead, and its lake-shore and ford work stays as written.
- Phase 229 used to take its tiers from Phase 227, which is parked. It now carries its own fabric PR
  (see its spec).

### Next: playtest fixes and the game's front door (Phases 219–226)

Filed by the owner on 2026-11-06 after playing `main`. Four are bugs found in play (typing in the
chat box, Enter jumping, re-creating a character, an overfull character window). Three give the game
what every game has and this one does not: a main menu, a pause menu on Esc and an options window.
The last lets a player keep several characters and pick one from the main menu. The bugs come first,
because the menus reuse the keyboard routing Phase 219 fixes.

| Phase | Title | Status |
|---|---|---|
| 219 | A focused text field owns the keyboard: no reversed text, no movement, jumps or hotkeys while typing | Done ([phases-219.md](docs/roadmap-history/phases-219.md)) |
| 220 | Enter never jumps: a `jump` action on Space only | Done ([phases-220.md](docs/roadmap-history/phases-220.md)) |
| 221 | Re-creating a character from the Character window | Done ([phases-221.md](docs/roadmap-history/phases-221.md)) |
| 222 | The Character window fits: fewer rows, the friend code moves to the map | Done ([phases-222.md](docs/roadmap-history/phases-222.md)) |
| 223 | A main menu: play a local world or join a server | Done ([phases-223.md](docs/roadmap-history/phases-223.md)) |
| 224 | The Esc menu: resume, options, exit to main menu, quit | Done ([phases-224.md](docs/roadmap-history/phases-224.md)) |
| 225 | The options window: sound, graphics and game settings | Open |
| 226 | Several characters per player: a new one starts from scratch, chosen in the main menu | Open |

### Arc: one character across worlds (Phases 227–231)

Parked on 2026-11-10 except Phase 229. The design below stands for when the arc is picked up again.

Decided by the owner on 2026-11-07. A player can take a character into a friend's world, level up
there, and keep that progress in their own world. Enshrouded does this by trusting a character file
held by the client. That breaks this game's trust rule (the host never trusts client-reported
state), and it would let one world flood another's economy. So only the character's **knowledge**
moves between worlds, and only as **evidence the host can verify**:

- **Travels:** the player's identity (a keypair), name, appearance, skill XP and cosmetics.
- **Stays in the world:** inventory, equipment, research (technology is per player, but it is
  discovered again in each world, never ported), books learned, position, spawn bed, clan
  membership and owned structures.
- **Skills are capped by the gear:** a combat skill's advanced abilities need a weapon of the same
  tier, and a crafting skill's advanced recipes need a tool and a crafting station of the same tier.
  Weapons, tools and stations are all made in the world. A ported master swordsman still has to
  research, gather and forge a master-tier blade in the new world first, and a ported master smith
  has to build a master-tier forge and hammer before making master-tier goods, so the new world's
  early game stays intact.
- **Cosmetics** are bound to the player's key. They travel to every world because they do nothing
  to the economy, and they can never be traded, dropped, gifted or worn by another player.
- No trophy items for now.

The arc starts after Phase 226, because the keypair identifies the player (the account) and Phase
226 separates player from character.

| Phase | Title | Status |
|---|---|---|
| 227 | Identity and portability in the fabric: keypair identity, what travels, gear-gated skills, bound cosmetics | Parked |
| 228 | Keypair identity at runtime: a challenge-response join replaces the cached player id | Parked |
| 229 | Skills capped by the gear: advanced abilities need a weapon of their tier, advanced recipes a tool and station of theirs | Open |
| 230 | Characters across worlds: signed progress, an import policy per world | Parked |
| 231 | Cosmetics bound to the key: they travel and cannot be shared | Parked |

Parked by the owner on 2026-11-10, except Phase 229, which stands on its own (see the priority order).

### Next: water, travel and the barber (Phases 232–236)

Filed by autopilot on 2026-11-10 from the Deferred list and the open review follow-ups. Phase 232
finishes the review notes on Phase 217's lakes and rivers (#573) and the mount follow-ups (#593).
Phase 233 makes water flow where players dig. Phases 234 and 235 are the boats and roads the
deferred fast-travel item names. Phase 236 is the hair and dye screen the owner deferred on
2026-11-06. Their order is now set by the priority order.

| Phase | Title | Status |
|---|---|---|
| 232 | Water that holds up: lake shores, the river seam and mounts at fords | Open |
| 233 | Flowing water: a bounded cellular automaton on edited chunks | Parked |
| 234 | Boats: crossing lakes, rivers and the sea | Open |
| 235 | Roads: built paths that speed travel on foot and on a mount | Open |
| 236 | Changing hair style and colour: scissors and dye | Parked |

Phases 233 and 236 were parked by the owner on 2026-11-10.

### Arc: terrain that looks, flies and streams well (Phases 237–247)

Filed by the owner on 2026-11-10 after comparing flight and terrain with Enshrouded. Three problems:

- **Flight is clumsy.** `/fly` is the walking controller with gravity off. Velocity follows the keys
  with no inertia, the look direction does not steer, and the capsule's step-up, dive guard and
  buried-lift rescue snap the body near the ground.
- **Streaming costs too much.** The voxel window is 9×9 chunks of 32 m (Phase 42), coarse inside it
  past the reach ring (Phase 190). Past the window there is nothing between it and the shape-only
  distant ring (Phases 51, 164, 165), so a flyer outruns the window and every crossing rebuilds. The
  build workers take every core but one, and no release export is ever measured: CI and the
  playtest run the editor binary with the `template_debug` native library.
- **The ground looks blocky.** Natural ground is meshed as stepped columns with vertex colour. There
  are no terrain textures.

Decided by the owner on 2026-11-10:

- **One world seed** for every world, in the fabric. Worlds differ by their players and edits, not by
  their terrain.
- **A small planet with one continent** (revised the same day; first decided as a quarter of Earth):
  the equator becomes 2,000 km, and one continent is open at launch. The others are reserved by the
  seed and opened later as fabric data, so the world can grow with its players.
- **Smooth natural ground** with blended, triplanar-textured materials. Placed blocks stay blocky.
- **Bake what a seed decides, in two layers.** The whole planet at 2 km cells (continents, rivers
  with flow, erosion, biomes), and 2 m erosion detail in 4 km regions, baked on demand around
  players and kept on disk. A full planet at 2 m would be about 2.5 TB, so it is never baked whole.
  The regional bake (Phase 246) is parked; the planet bake (Phase 245) stays.
- **CC0 terrain textures** (ambientCG / Poly Haven) to start, replaceable by production art later.

The order is set by the [priority order](#priority-order): the native base (248) and the world's size
and seed (238) first, then streaming (239), the godot_voxel review (249), the look (240–242), level of
detail and caching (243–244), and later flight (237), the planet bake (245) and ground cover (247).

| Phase | Title | Status |
|---|---|---|
| 237 | Flight that handles like flight: inertia, steering by the camera, no ground-walking fixes in the air | Open |
| 238 | One world: a fixed seed, a 2,000 km planet and one continent | Open |
| 239 | Streaming that keeps up: a speed-scaled lead, adaptive workers, an attach budget | Done |
| 240 | Smooth natural ground: a surface-nets mesher (GDScript reference) | Open |
| 241 | The native smooth mesher, and coarse chunks built smooth | Open |
| 242 | Terrain materials: blend weights, a triplanar shader and CC0 textures | Open |
| 243 | Level of detail past the window: voxel rings out to the distant ring, faded, under the haze | Open |
| 244 | A chunk cache on disk: the host keeps generated chunks, the client keeps built meshes | Open |
| 245 | The planet bake: continents, rivers with flow, erosion and biomes at 2 km | Open |
| 246 | The regional bake: 2 m erosion detail in 4 km regions, on demand around players | Parked |
| 247 | Ground cover: grass and bushes by biome, culled by distance | Open |

### Next: foundations, the server's ceiling and a human playtest (Phases 248–251)

Filed by the owner on 2026-11-10 with the priority order. Phase 248 splits the release build out of
Phase 239 and gives every later native port (241, 245, and whatever 249 adopts) one shared base.
Phase 249 checks what Zylann's voxel engine already solves before Phases 240–244 build it. Phase 250
measures how many players one server holds on real hardware. Phase 251 is the owner playing the game.

| Phase | Title | Status |
|---|---|---|
| 248 | The native library base and a release build | Done ([phases-248.md](docs/roadmap-history/phases-248.md)) |
| 249 | What to reuse from Zylann's godot_voxel: a review, then the parts that fit | Open |
| 250 | The server's ceiling: one machine serving, another running the bots | Open |
| 251 | A human playtest: what would make the game fun | Open |

## Phase 225 — The options window

Settings exist in scattered places (language since Phase 131, the tutorial switch since Phase 186,
admin-only tools). They get one window, reachable from the main menu and the Esc menu.

- **Sound**: master, music, effects volume (audio buses).
- **Graphics**: window mode, resolution, VSync, view distance (the near/far ring policy), FPS cap,
  render scale with FSR 2 upscaling (Godot's built-in `Viewport.scaling_3d_mode`), and terrain
  quality (Phase 242's triplanar fallback, Phase 243's LOD rings, Phase 247's ground cover, each
  read once those phases land).
- **Game**: language, tutorial on/off and reset, mouse sensitivity and invert, controls list.
- Saved to the existing user settings file and applied at once. Language follows the CLAUDE.md
  order: saved preference, then OS locale, then `en`.

**Acceptance criteria**
- A suite test changes each setting, saves, reloads the settings in a fresh object and reads back the
  same values, and asserts the change was applied (bus volume, `TranslationServer` locale, tutorial
  flag).
- A suite test asserts every options label is a key in both `en` and `pt_BR`.

## Phase 226 — Several characters per player

Decided by the owner (2026-11-06): a player cannot re-create a character in place (Phase 221), but
can create other characters from the main menu, and each new one starts from scratch. Today a
player id is one character: the registry, the creation record, inventory, skills, attributes,
research, clan membership and owned structures all key on the player id.

- **Fabric first** (separate PR): a character entity under the player (account), what belongs to the
  character (body, name, inventory, equipment, skills, attributes, research, books learned, clan
  membership, owned structures, spawn bed) and what belongs to the player (friend code, settings,
  admin flag). A character limit per player per server, and whether a deleted character's
  structures fall to its clan or become ownerless.
- **Runtime:** the registry keys character state by character id. The host refuses a new character
  over the limit, and a new character gets no items, skills, research or memberships from the
  player's other characters. Names stay unique per server across all characters (`name_taken`).
- **Main menu:** after choosing a local world or joining a server, a character list (name, body
  preview, last played) with **Play**, **New character** (the creation screen) and **Delete** (with a
  confirmation typed as the character's name). The host sends the list; the client never decides
  which characters exist.
- Existing saves migrate: each player's one character becomes their first character, unchanged.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass with the character entity; a `tools/check_*.js` rejects
  a table that puts inventory or skills on the player instead of the character.
- A suite test creates two characters for one player: the second has an empty inventory, base
  attributes, no skills, no research and no clan, and the first is unchanged.
- A suite test refuses a character over the limit and a name already used by another character on
  the server.
- A suite test loads a pre-Phase-226 save and finds each player's character as their first, with
  the same state.
- A net harness step: a client lists its characters, creates a second, enters with it, reconnects
  and enters with the first.

## Phase 229 — Skills capped by the gear

- **Fabric first** (separate PR): Phase 227 is parked, so this phase takes over its gear-gated-skills
  part only: every weapon, crafting tool and crafting station gets a `tier` (from `SKILL_TIERS`), each
  combat ability and each recipe a `requiredTier`, with a `tools/check_*.js` that rejects a weapon,
  tool or station with no tier and an ability or recipe with no `requiredTier`. Identity, travel and
  cosmetics stay in Phase 227.
- The weapon, tool, station, ability and recipe tiers load through `GameData`.
- **Combat:** the host decides whether an ability can be used from the skill tier **and** the
  equipped weapon's tier. An ability above the weapon's tier is refused with a localized reason key
  (`combat.refuse.weapon_tier`) and greyed out in the hotbar and skill UI, which show the tier needed.
- **Crafting:** the host decides whether a recipe can be crafted from the crafting skill's tier, the
  tier of the tool it uses (from the crafter's inventory or hand) **and** the tier of the station it
  is crafted at. A recipe above either is refused with `craft.refuse.tool_tier` or
  `craft.refuse.station_tier` and greyed out in the crafting window, which shows the tool or station
  tier needed. The host reads the station's tier from its own placed-structure record, never from the
  client.
- Skill XP still grows with any weapon, tool or station. Only use is capped, so carrying weaker gear
  never loses progress.

**Acceptance criteria**
- A suite test gives a character master Swordsmanship and a novice sword. Novice abilities resolve
  and higher abilities are refused with `combat.refuse.weapon_tier`. With a master sword, all of
  them resolve.
- A suite test gives a character master Smithing. A master-tier recipe is refused with a novice
  hammer at a master forge (`craft.refuse.tool_tier`) and with a master hammer at a novice forge
  (`craft.refuse.station_tier`), and crafts with both at master tier. No materials are consumed by a
  refused craft.
- A suite test: a client that sends an ability intent above its weapon's tier, or a craft intent
  naming a station tier it does not have, is refused by the host. No damage is applied and no item
  is made.
- A suite test: the hotbar and crafting window projections mark an ability or recipe above the
  equipped weapon, held tool or station tier as unavailable and carry the tier needed.
- A suite test asserts the refusal and tier labels are keys in both `en` and `pt_BR`.

## Phase 232 — Water that holds up: lake shores, the river seam and mounts at fords

Phase 217 put lakes and rivers on unrecorded land, and #589 fixed half of its review notes. The rest
are visible in play (a lake edge hanging as a wall of water, rivers jumping 512 m at the X seam,
water stopping dead at an older recorded chunk) or cost frame time (fresh water meshed on the main
thread for every chunk). Mounts still refuse any river, even a stream their own creature fords.

- **Lake shores:** `Hydrology.lake_of_cell` samples the ground with detail noise and massifs, not the
  shape alone, and the surface is clamped so no ground outside the disc lies below it. A lake whose
  rim cannot hold the surface is dropped.
- **River seam:** the river cell wrap period is an exact divisor of the circumference (or rivers are
  traced in seam-wrapped coordinates, `seam_wrap.gd`), so a river crossing the X seam continues on
  the other side. Phase 245 now runs first and replaces the local trace with baked rivers, so check
  the seam on the baked rivers; if the bake already wraps, this bullet reduces to its test.
- **Frontier:** a lake or river that reaches a recorded chunk of an older generator ends at a shore,
  not a cut: `frontier.gd` eases the water surface down to the recorded ground over `BLEND_CHUNKS`,
  as it already eases heights.
- **Spawn plain:** lake discs and river segments are excluded by their full extent, not their centre
  or vertices.
- **Build cost:** `voxel_build.build_chunk` skips fresh water when the chunk has no features, and
  builds the fresh-water surface on the worker thread with the rest of the chunk.
- **Mounts at fords:** `MountWiring._in_water` uses `CreaturePath.blocks_water(width,
  CreatureAI.FORD_WIDTH_M)`, so a ground mount carries its rider across a stream its creature would
  ford, and still refuses a wide river or a lake.
- Any change to world-gen output bumps `TerrainSlice.WORLDGEN_VERSION` with a history line and
  updates `_test_worldgen_golden`.

**Closes:** #573, #593

**Acceptance criteria**
- #573 (lake edge): a suite test samples the rim of 50 lakes on the pinned seed and finds no ground
  sample outside a disc below its surface.
- #573 (river seam): a suite test traces a river across the X seam and finds its two ends within one
  river width of each other.
- #573 (frontier): a suite test records an older-version chunk beside a lake and asserts the water
  surface meets the recorded ground with no vertical step over 0.5 m.
- #573 (spawn plain): a suite test asserts no lake disc or river segment overlaps the spawn plain on
  20 seeds.
- #573 (build cost): a suite test builds a chunk with no features and asserts no fresh-water node is
  made; the playtest `flight` step's worker and main-thread budgets still pass.
- #573: the items fixed by #589 (cache reset, record changes, crossing width, ice material) keep
  their tests; the issue's checklist is ticked in full.
- #593: a suite test calls the real `MountWiring._in_water` against a wired `CreatureSlice` (no
  stub): a stream narrower than `FORD_WIDTH_M` is not water, a wide river and a lake are.
- `WORLDGEN_VERSION` bumped and golden values updated if world-gen output changed; suite, both boot
  paths and `tools/net_harness.sh` green.

## Phase 234 — Boats: crossing lakes, rivers and the sea

Deferred "Fast travel beyond waystones" names roads and boats. With lakes and rivers (Phase 217),
water is now the main obstacle on foot, and ground mounts (Phase 216) refuse it.

- **Fabric first** (separate PR): a raft (wood and fibre, carpentry, early tier) and a boat (planks
  and nails, later tier) as placeable vehicles, with speed on water, seats, durability, the water
  depth each needs, and their recipes and technologies. A `tools/check_*.js` proves the table rejects
  a vehicle with no seats or a speed under swimming speed.
- **Runtime:** a vehicle is a world entity placed on water deeper than its draft, owned by the
  player who placed it (structure ownership rules, Phase 205). Mounting reuses the mount flow
  (Phase 216): interact to board, the vehicle moves with the rider's input, dismount on shore. A
  second seat carries a passenger.
- **Authority:** the host moves the vehicle, rate-limits and validates input like a mount, refuses
  boarding from out of reach, and beaches it (stops it) on ground shallower than its draft. A
  client never reports the vehicle's position.
- **Persistence:** a placed vehicle and its durability are saved with the world; picking it up
  returns the item.
- Labels and refusal reasons (`boat_too_shallow`, `boat_full`, …) are `I18n.t()` keys in `en` and
  `pt_BR`.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; the new check is in CI.
- A suite test places a raft on a lake, boards it, drives it across and asserts it moves at the
  fabric speed and stops at the shore; placing it on dry land or in water shallower than its draft is
  refused.
- A suite test: a passenger boards the second seat and moves with the boat; a third player is
  refused with `boat_full`.
- A suite test saves and reloads a world with a placed boat and finds it at the same position with
  the same durability; picking it up returns the item.
- A suite test asserts every vehicle label and refusal key exists in both `en` and `pt_BR`.
- A net harness step: a client crafts and places a raft, boards and crosses a lake; the host's
  position for it matches the client's within one tick, and a forged position update is ignored.

## Phase 235 — Roads: built paths that speed travel on foot and on a mount

The other half of the deferred fast-travel item. A clan that wants its villages close builds roads
between them, which costs work instead of being free like a waystone.

- **Fabric first** (separate PR): road surfaces (packed dirt, gravel, stone paving, by tier) with a
  walking and mount speed multiplier each, their recipes, the skill they grow (Building) and the
  durability lost to traffic.
- **Runtime:** a road is laid with a tool on the ground's top voxel layer (a voxel edit with a road
  material, Phase 205 ownership and dismantling rules apply). `PlayerSlice.walking_speed` and the
  mount speed read the surface under the body; off road nothing changes. Weather's speed factor
  (Phase 128) still applies on top.
- **Authority:** the host computes the speed from its own voxel data. The client predicts with the
  same function but the host's position is authoritative; a client claiming road speed off road is
  corrected.
- Roads show on the minimap and the map (Phase 222) as lines.
- Road names and prompts are `I18n.t()` keys in `en` and `pt_BR`.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; a `tools/check_roads.js` rejects a multiplier below 1 or
  a road with no recipe, and CI runs it.
- A suite test lays a stone road and asserts walking speed on it is the fabric multiplier times
  `SPEED` and unchanged one voxel beside it; rain still slows the walk on the road.
- A suite test asserts a mount on a road moves at its speed times the road multiplier.
- A suite test asserts a road voxel survives save and reload and is drawn on the minimap.
- A net harness step: a client walks along a road and the host accepts the speed; a client sending
  road-speed movement off road is corrected by the host.

## Phase 237 — Flight that handles like flight

`PlayerSlice._move` sets horizontal velocity straight from WASD each frame, and Space/Ctrl give a fixed
`AdminRules.FLY_VERTICAL_SPEED`. Releasing a key stops the body at once, pitching the camera does
nothing, and while flying the capsule still runs the stair step-up, the Phase 193 dive guard and the
buried-lift rescue.

- A pure `FlightRules` (new file, `src/player/flight_rules.gd`):
  `step(velocity, wish, look_basis, delta, params) -> Vector3`. W/S push along the camera's forward
  vector **including its pitch**, A/D strafe, and Space/Ctrl add up/down. Velocity eases toward the
  wish with an acceleration and a drag. Default: top speed in about 0.6 s, and a stop from top speed
  in about 1 s with no input. Speeds keep today's scale (`SPEED` × `/speed` × `FLY_SPEED_FACTOR`),
  so the playtest's 90 m/s flight is unchanged.
- While flying, the step-up probe, the dive guard and the buried-lift rescue are skipped. The body
  still collides (`move_and_slide`), and a collision kills only the velocity into the surface.
- Camera: a short follow lag on the pivot, and FOV widened by up to 12° at top speed (eased). The
  camera's height smoothing stays. Both are off in the headless server.
- Leaving flight keeps the current velocity, and gravity takes over from there.

**Acceptance criteria**
- Suite tests on `FlightRules.step`: from rest with W held, the body reaches 95% of top speed in
  0.5–0.8 s of steps. With no input it falls below 5% of top speed in 0.8–1.5 s. W with the camera
  pitched 30° up climbs at sin 30° of the speed (±5%). Opposite input reverses smoothly, never in one
  step.
- A suite test flies a body into a wall and a hillside: no step-up lift, no buried-lift jump, and the
  body ends outside solid ground.
- The playtest `flight` step passes at its current floors.

## Phase 238 — One world: a fixed seed, a 2,000 km planet and one continent

Decided by the owner on 2026-11-10. Every world uses the same seed. The planet is small, a 2,000 km
equator, and only one continent is open at launch; more are opened later as data, so the world grows
with its players. Today `TerrainSlice` draws `randi()` for a new world, the Phase 223 New world dialog
takes an optional seed, `WorldSystem.circumferenceKm` defaults to 40,000, and continents come from
noise everywhere (`WorldShape.continentalness`, `CONTINENT_CELLS` counted across the circumference).

- **Fabric first** (separate PR): `WorldSystem.worldSeed` (an integer), `circumferenceKm` 2,000, and a
  `continents` list. Each continent has an id, a centre (latitude, longitude), a radius in km and an
  `open` flag. At launch the list holds one open continent around the spawn, about 600 km across
  (tuned in the PR), and may list closed sites reserved for later.
- **Re-tune for the small planet**, and record each decision in the field description:
  `CONTINENT_CELLS` (counted across the circumference, so a 16-cell layer is now 125 km), the
  massif clearance around spawn (`MASSIF_SPAWN_CLEAR_M`, 100 km, is now 5% of the equator),
  `ridgeAmplitude`, `spawnMinColonizedDistance`, `oceanShare` and the hydrology cell sizes (Phase 217;
  the river wrap period must still divide the circumference). The open continent must hold at least
  one summit of 8 km or more for the playtest `far_peak` and `tower` steps.
- **One continent:** continentalness is masked by the open continents. Inside one, today's noise is
  kept and eased to the shelf over a rim; outside every open continent the ground is deep ocean.
  Closed sites are ocean too.
- **Room to add continents:** the host never records a chunk inside a closed site (its radius plus
  the rim) and refuses edits and placements there, so opening a site later (set `open`, bump
  `WORLDGEN_VERSION`) changes only unrecorded land, per the stable-world rule. The spawn search and
  the colonized-distance rule look only inside open continents.
- **Runtime:** a new world takes `worldSeed`, the fabric circumference and the continent list, and
  records the seed and circumference in its world record. The New world dialog has no seed field any
  more. `--playtest-seed` and an admin user arg stay as dev overrides. `PlaytestBot.WORLD_SEED`
  becomes the fabric seed, and every playtest step is re-checked on it (spawn, far_peak, pole, travel
  and tower read the world).
- **Saves:** a world created before this phase keeps the seed and circumference in its record, so its
  recorded chunks never move (the stable-world rule). A record without a circumference reads as
  40,000 km with no continent mask. Bump `WORLDGEN_VERSION`, add a history line and update
  `_test_worldgen_golden`.
- With one public seed anyone can compute ore and spawn positions offline. That was already true for
  a known seed in an open-source game. It is accepted, not hidden.
- Update the Deferred fast-travel note: walking around the planet takes about 4.5 days, not 90, and
  the open continent is crossed in about a day and a half.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass. A `tools/check_*.js` rejects a `worldSeed` that is not an
  integer, a `circumferenceKm` that is not positive, a continent list with no open continent, and
  two continents whose areas overlap.
- A suite test creates two new worlds and finds the same seed and the same heightmap for a sample of
  chunks. `TerrainSlice.circumference_chunks()` equals 2,000 km / 32 m (62,500).
- A suite test samples the planet: every sample outside the open continents and their rims is below
  sea level, and most samples in the open continent's core are land.
- A suite test: the host does not record a chunk inside a closed site and refuses an edit there. With
  that site marked open in a fixture, heights change only inside it, and every recorded chunk
  elsewhere is unchanged.
- A suite test: every spawn the search picks lies inside an open continent.
- A suite test loads a pre-Phase-238 world record and finds its own seed, a 40,000 km circumference,
  no continent mask, and its recorded chunks unchanged.
- A menu suite test finds no seed field in the New world dialog.
- The playtest passes every step on the fabric seed.

## Phase 239 — Streaming that keeps up

The window loads a fixed one-chunk lead whatever the speed (Phase 42), and Phase 194 orders the queue
along a fast flyer's lane. The pool runs every core but one all the time (`default_builds_in_flight`).
Attached meshes and collision land on the main thread as whole nodes.

- **Lead by speed:** the prefetch distance grows with the local body's speed (`ceil(speed ×
  LEAD_SECONDS / 32 m)`, capped), and the extra ring is queued only in a cone along the velocity. A
  standing player keeps today's window.
- **Adaptive workers:** the in-flight cap starts at half the cores (at least 2). It rises toward cores
  − 1 while the queue grows or the ground under the body is missing, and falls back after a few
  seconds with an empty queue. Fewer busy cores at rest is what keeps the fans down.
- **Attach budget:** at most `ATTACH_BUDGET_MS` of mesh and collision attach per frame. The chunk under
  a body attaches at once, whatever the budget. Meshes go in through `RenderingServer`
  (`mesh_add_surface_from_arrays`, an instance) instead of a new `MeshInstance3D` per chunk.
- The release build and its measured `flight` numbers come from Phase 248, which runs first: this
  phase's budgets are checked on the editor build as before, and the release numbers are recorded
  beside them.

**Acceptance criteria**
- Suite tests on the pure lead function: 0 m/s gives today's window, 90 m/s gives a deeper lead only
  inside the velocity cone, and the cap holds.
- A suite test on the pure worker-cap function: it rises under a growing queue, falls after the idle
  time, and never leaves [2, cores − 1].
- A suite test attaches 20 built chunks in one tick with the budget set low: only the chunk under the
  body and what fits the budget attach, and the rest attach on later ticks, nearest first.
- The playtest `flight` step: ground under the body in at least as many samples as the current floor,
  and the worker ms per crossing no worse than its budget.

**Implemented** (pure policy in `src/terrain/chunk_stream_policy.gd`; wiring in `chunk_part_1.gd`): the
lead is `ceil(speed × 1.5 s / 32 m)` chunks, capped at 6, queued in a 45° cone along the body's
velocity; the steady worker cap starts at half the cores and moves once a second inside
[2, cores − 1]; `apply_finished_builds` stops at `ATTACH_BUDGET_MS` (3 ms) except for the chunk under
the body; the ground surface of a chunk is a `ChunkSurface` (RenderingServer mesh and instance) when
`VoxelBuild.render_server_surfaces` is on (the game, not the suite's rigs). The `flight` step is gated
by CI's playtest run; no release-build numbers were recorded in this PR.

## Phase 240 — Smooth natural ground

Natural ground is meshed as stepped columns: each 0.5 m tile's runs become flat tops and vertical
walls at 0.125 m steps (`voxel_mesh.gd`). The runs already carry overhangs, caves and a material per
run. Placed blocks are runs too, with a non-empty material and an entry in the structure index.

- A surface-nets mesher in GDScript as the reference (`src/terrain/voxel_smooth.gd`), pure and safe on
  a worker, like `voxel_mesh.gd`. The density is sampled on a 0.5 m grid (tiles in XZ, 0.5 m in Y)
  from the resolved runs. A vertex's height on a column top comes from the run's exact top, so the
  ground stands where the runs say it does (±0.125 m), not on the grid.
- **Natural runs only.** A placed block (a run with a structure entry) is still meshed by the block
  mesher, in the same chunk, so walls, floors and roofs stay square. Where natural ground meets a
  placed block, the smooth surface stops at the block's faces with no gap.
- **Collision** is the same triangles (one shape per chunk, as today). On smooth slopes the body walks
  by `floor_max_angle`. The step-up probe stays for placed blocks. The dive guard and buried-lift
  rescue keep reading the runs, which have not changed.
- **Edits** still change 0.5 m cells. A mined pit shows rounded edges.
- Behind a project setting (`terrain/smooth_mesh`, on by default) until Phase 241. The block mesher
  stays for placed blocks and for tests.
- No world-gen change: runs, records and saves are untouched, so `WORLDGEN_VERSION` stays.

**Acceptance criteria**
- Suite tests on the mesher: a flat column gives a flat surface at the run's top. A 45° ramp of runs
  gives normals within 5° of the ramp. An overhang and a one-tile tunnel give a closed surface (every
  edge shared by exactly two triangles inside the chunk). Two neighbouring chunks share their border
  vertices exactly (no crack).
- A suite test: on 1,000 random natural tiles of the pinned seed, the mesh height above the tile's
  centre is within 0.125 m of the column's top run.
- A suite test builds a chunk with a 3×3 placed wall on natural ground: the wall's faces are the block
  mesher's, axis-aligned, and the ground around it is smooth.
- A suite test walks a body up a 30° natural slope with no step-up lift, and onto a placed block with
  one.
- The playtest walk, mine, place and tower steps pass.

## Phase 241 — The native smooth mesher, and coarse chunks built smooth

- Port `voxel_smooth.gd` to `native/` on the Phase 248 base (or the Transvoxel code Phase 249 adopts) as
  `build_smooth_arrays`, added to `NativeChunkBuilder.functions()`
  and routed by `native_builder.gd` like the Phase 166–169 builders. Bump `REQUIRED_VERSION`.
- Coarse builds (Phase 190, `voxel_coarse.gd`) run the same mesher on a downsampled density (2× and
  4× cells), with the edge skirts kept.
- Remove the `terrain/smooth_mesh` setting: smooth is the only natural-ground mesher.

**Acceptance criteria**
- A native parity suite test (as in `native_tests.gd`): GDScript and native give identical vertex,
  normal and index arrays for 50 chunks of the pinned seed, including edited chunks and chunks with
  placed blocks.
- A suite test: a coarse chunk next to a full one leaves no visible gap (the skirt covers the border
  height difference).
- The playtest `flight` and `stream` steps meet their budgets with the native mesher (worker ms per
  crossing no worse than the Phase 190 floor).

## Phase 242 — Terrain materials: blend weights, a triplanar shader and CC0 textures

Natural ground is drawn in vertex colour from the biome, and `assets/` holds no terrain textures.

- **Material weights per vertex:** up to four terrain materials per vertex (for example grass, dirt,
  rock, sand, snow, mud), stored in `CUSTOM0` (material ids) and `CUSTOM1` (weights). The weights are
  a pure function of the biome blend (Phase 120's `biome_blend`), slope (rock on steep ground),
  altitude (snow above the biome's snow line) and wetness (mud and sand near water, Phase 217). A
  placed block keeps its own material.
- **Terrain materials in the fabric** (separate PR): each with its texture key, scale and which biomes
  and slopes use it. A validator checks every biome resolves to at least one material.
- **Shader:** triplanar projection (no stretching on cliffs) with a texture array per map (albedo,
  normal, roughness), blended by the weights with height-based blending at the borders, and a detail
  texture fading in near the camera.
- **Textures:** a CC0 set (ambientCG or Poly Haven, 1K, credited in `assets/README.md`) in the public
  `assets/textures/terrain/`. CC0 can ship in the public repo, so it is also the placeholder for later
  production art (the placeholder rule holds).
- A low-end fallback: the graphics option from Phase 225 can drop to biplanar sampling and no detail
  texture.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass. A `tools/check_*.js` rejects a biome with no terrain
  material and a material whose texture key has no file in `assets/`.
- Suite tests on the weight function: weights sum to 1. Ground steeper than the rock slope is mostly
  rock. Ground above the snow line is mostly snow. A biome border blends over the same width as
  Phase 120.
- A suite test builds a chunk and finds `CUSTOM0`/`CUSTOM1` on every vertex, and the terrain material's
  shader compiling with every texture array set.
- `assets/README.md` lists each texture's source URL and licence.

## Phase 243 — Level of detail past the window

Past the 9×9 window, the distant ring (Phases 51, 164) and the bands (Phase 165) draw only
`WorldShape`, with no detail noise, records or edits. A flyer sees the near ground pop in, and the far
ground does not match it.

- **LOD rings** between the window and the distant ring: rings of chunks meshed with the smooth mesher
  on a downsampled density (4×, 8×, 16× cells), in the clipmap style of Phase 165. Each ring's cell
  doubles, so the cost per ring stays about flat. They use the same heights the full chunks use (detail
  noise, records, and edits summarised to the cell). The distant ring's hole grows to the outer LOD
  ring.
- **No pop:** a chunk changing level cross-fades (`visibility_range` fade, dithered) instead of
  swapping in one frame. The same fade applies to the window's coarse-to-full upgrade.
- **Haze hides the edge:** the clear-weather fog density is derived from the outer LOD radius, so the
  last LOD ring is mostly hazed. Weather still thickens it (Phase 128).
- **Render only** (no collision), and nothing on the headless server.
- The view-distance option (Phase 225) sets how many LOD rings a client draws.

**Acceptance criteria**
- A suite test builds an LOD-ring chunk and the full chunk at the same place: heights agree within the
  ring's cell size, and an edited tile's summary shows in the LOD mesh.
- A suite test: rings nest with no overlap and no gap, and the ring border has a skirt.
- A suite test on the haze function: fog reaches at least 90% at the outer LOD radius on clear weather.
- The playtest `horizon` and `far_peak` steps pass. The `flight` step meets its budgets.

## Phase 244 — A chunk cache on disk

Every visit rebuilds a chunk from noise. The host already stores edits and generation records per
region (`region_store`).

- **Host:** the resolved runs of a generated chunk are written next to its region the first time the
  chunk is built, keyed by `WORLDGEN_VERSION`, the worldgen fingerprint and the chunk's edit revision.
  A later build reads them instead of generating. Edits update the entry.
- **Client:** built mesh arrays (full, coarse and LOD levels) are cached under `user://cache/` with the
  same key plus the mesher version, capped in size with least-recently-used eviction. A revisit loads
  arrays from disk on a worker instead of meshing.
- A stale key is a miss, never an error. Deleting the cache only costs time.

**Acceptance criteria**
- Suite tests: a cached chunk and a freshly built one give identical runs and arrays. Bumping any key
  part turns the entry into a miss. An edit invalidates the entry.
- A suite test fills the client cache past its cap and finds the least recently used entries evicted.
- A playtest step flies a loop twice: the second pass's worker ms per crossing is at most half the
  first's.

## Phase 245 — The planet bake: continents, rivers with flow, erosion and biomes at 2 km

Phase 217 traces rivers locally (steepest descent in 64 m steps from a source cell) with no flow or
erosion, and continents come straight from noise.

- A native, deterministic bake of the whole planet on a 2 km grid (about 0.5 M cells on the Phase 238
  planet, a 2,000 × 1,000 km grid): base height from `WorldShape`, then flow accumulation, river networks from source to sea,
  hydraulic and thermal erosion, and the climate and biome fields read from the result. The arithmetic
  is fixed-point/integer, so every machine bakes the same bytes.
- Output: one file per world seed and worldgen version (height, flow, river ids, biome; about 8 bytes
  a cell, about 4 MB before compression). CI bakes it for the fabric seed and publishes it as a
  release asset. A host that does not find it bakes it at world creation, with a progress screen. A
  client downloads it from the host or bakes it itself, and checks the hash either way.
- The runtime reads macro height and rivers from the bake (interpolated). The detail noise stays on
  top. Phase 217's river trace is replaced. Lakes keep Phase 217's placement, fed by the baked flow;
  Phase 232, which now comes after this phase, fixes their shores and fords on top of it.
- Continents come from Phase 238's mask (open continents only); a closed site bakes as ocean until it
  is opened, and opening one re-bakes the planet under the bumped `WORLDGEN_VERSION`.
- Built on the Phase 248 native base (fixed-point helpers, parity harness).
- A world-gen change: bump `WORLDGEN_VERSION` (only unrecorded land changes, per the stable-world
  rule; `frontier.gd` blends at recorded borders).

**Acceptance criteria**
- A suite test bakes a small planet (a test circumference) twice and gets identical bytes, and the
  same bytes from the GDScript reference and the native bake.
- Suite tests on the baked rivers: every river reaches the sea or a lake, never flows uphill, and its
  width grows with flow.
- A suite test: a client with a corrupted bake file (wrong hash) refuses it and bakes or re-downloads.
- CI publishes the bake for the fabric seed, and the playtest `travel`, `far_peak` and `pole` steps
  pass on it.

## Phase 247 — Ground cover: grass and bushes by biome, culled by distance

Trees use `multimesh_pool.gd` and impostors (Phase 23). Natural ground has no grass or bushes.

- Ground cover per biome in the fabric (separate PR): plant kinds, density, and the terrain materials
  they grow on (grass on grass, none on rock or snow).
- Placement is a pure function of (seed, tile), so every client puts the same tufts in the same places.
  It is client-only, never synced, and absent on the headless server.
- Drawn with the MultiMesh pool in cells around the camera, with a density that falls with distance,
  and gone past a fade distance set by the graphics option. A wind sway in the vertex shader. A placed
  block or a mined tile removes the cover there.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass. A `tools/check_*.js` rejects ground cover on a material
  that is not a terrain material.
- Suite tests: placement is identical for the same seed and tile, nothing grows on rock, snow, water
  or a placed block, and density falls with distance.
- The playtest `walk` and `flight` steps meet their budgets with ground cover on.

## Phase 249 — What to reuse from Zylann's godot_voxel

[Zylann/godot_voxel](https://github.com/Zylann/godot_voxel) (MIT) is a mature voxel engine for Godot:
smooth meshing (Transvoxel), LOD, streaming, region files, generators and instancing. It ships mainly
as a C++ engine module (a custom Godot build), with a GDExtension build in progress. This project has
its own run-based voxel storage, a headless authoritative server, the stable-world rule and a
GDScript reference for every native function, so the engine as a whole does not fit, but parts of it
may save Phases 240–244 a lot of work.

- **Review** (`docs/research/godot-voxel.md`): for each of Transvoxel and its LOD seams, the LOD
  octree/clipmap, streaming and task scheduling, region/block storage and compression, mesh
  instancing for ground cover, and the SDF/edit tools, say what it does, which open phase it touches
  (239–244, 247), whether it fits (Godot 4.7, GDExtension rather than a custom engine, deterministic
  and safe on a worker, works on runs, headless server) and the verdict: adopt the code, port the
  algorithm, or skip.
- **Then implement what passes**, on the Phase 248 base, each part with its GDScript reference or
  parity test as this project requires. Code taken from the project keeps its MIT notice
  (`native/THIRD_PARTY.md` or equivalent). If a verdict changes how a later phase is built, update
  that phase's spec in this file in the same PR.
- If nothing fits, the review is the deliverable and the phase is done.

**Acceptance criteria**
- `docs/research/godot-voxel.md` exists with a verdict and its reason for each part listed above.
- Every adopted file carries its licence notice, and `native/THIRD_PARTY.md` lists its source commit.
- Each adopted part has a parity test (GDScript against native) or a suite test per behaviour it adds.
- The suite, the harness and the playtest pass.

## Phase 250 — The server's ceiling: one machine serving, another running the bots

The crowd numbers in the README (Phase 163) come from one desktop machine running the server, the
watching client and every bot at once, so the bots steal the server's CPU and the link is loopback.
How many players one dedicated server holds is unknown.

- `tools/stress.sh` gains a split mode: `STRESS_ROLE=server` boots only the dedicated server and the
  host recorder and waits for bots; `STRESS_ROLE=bots STRESS_SERVER=<addr>` runs the watcher and the
  bot process against a remote server. The "steady" and "stop" handshake goes over the network
  (a control message or a small TCP side channel) instead of shared files.
- Run the ladder (every pattern, crowd sizes up past the first failure) with the server on one
  machine and the bots on another over a real LAN, then over the `wan_br` profile.
- The report records each machine (CPU, cores, RAM, OS, Godot build, native on or off, release or
  debug), and per pattern: the largest crowd that met every budget, tick time, CPU and memory per
  player, bandwidth per player up and down, and the first bottleneck.
- Write `docs/perf/server-ceiling.md`: the measured limits, the machines, the command to repeat it,
  and how many players one server can hold with headroom for play. The README's crowd line points
  to it.

**Acceptance criteria**
- A suite test on the split-mode parsing: a bots role with no server address is refused, and the
  control messages round-trip.
- A loopback CI run of the split mode (both roles on one runner) reaches "steady", runs one small
  pattern and writes a report with the machine fields filled.
- `docs/perf/server-ceiling.md` exists with numbers from a two-machine run. The run itself needs two
  machines, so if none are available to automation it is filed as a GitHub issue (per the rule at
  the top of this file) and the document records the loopback numbers until the issue is closed.

## Phase 251 — A human playtest: what would make the game fun

The owner plays the game, as a new player would, to find what keeps it from being fun. Per the rule
at the top of this file this is not an automated criterion: it is tracked as a GitHub issue, and its
findings come back as new phases.

- Before the session: a release build from Phase 248 on the fabric world of Phase 238, a fresh
  character, and a checklist in the issue (first hour, gathering and crafting, building, combat,
  travel, playing with a friend, performance, anything confusing or dull).
- After: each finding becomes a GitHub issue (bug, polish or feature), and the ones worth a phase
  are written into this file with automated acceptance criteria.

**Acceptance criteria**
- A GitHub issue for the playtest exists with the checklist, and this phase records its number.
- The phase is done when the issue is closed and every finding is filed as an issue or a new phase.

---

## Parked phases

Parked by the owner on 2026-11-10. Their specs are kept as written so a phase can be picked up
again; check each against the phases done since before un-parking it. Phase 236 is also the
second-to-last entry of the priority order, which it keeps when un-parked.

## Phase 227 — Identity and portability in the fabric

Design-only (a fabric PR, no GDScript). Everything after it reads from this phase's entities.

- **`PlayerKeyIdentity` decision**, superseding `PlayerIdentityModel`: a player is a public key.
  The client generates a signing keypair once and keeps the private key in `user://`, never sent
  anywhere. The id the host stores is the key's fingerprint. On join the host sends a fresh random
  nonce and the client signs it, so presenting someone else's id without their private key fails.
  The decision names the algorithm: RSA through Godot's built-in `Crypto`/`CryptoKey`, or Ed25519,
  which needs a GDExtension. Record the trade-off (key and signature size, a dependency, the
  headless server). It also names the migration of saves keyed by a minted `player_id`, and that
  every host has a key too, whose fingerprint the client signs into the join answer (Phase 228).
- **Portability table:** each character field (from Phase 226's character entity) is marked
  `portable` or `world_bound`, following the arc introduction. Technology/research, inventory,
  equipment, books learned, clan membership and owned structures are `world_bound`.
- **World import policy:** `local` (default; every character starts from scratch, as today),
  `trusted` (accepts progress signed by listed host keys), `open` (accepts progress signed by any
  host). A **progress delta** entity: player key, character id, issuing host key, world id, skill
  XP gained per skill, sequence number, and the host's signature.
- **Gear-gated skills:** every weapon, crafting tool and crafting station gets a `tier` (from
  `SKILL_TIERS`). Each combat ability and each recipe gets a `requiredTier`. A rule says a combat
  ability is usable only when both the skill and the equipped weapon reach that tier, and a recipe
  can be crafted only when the crafting skill, the tool it uses and the station it is made at all
  reach that tier. Recipes that need no tool or no station skip that check.
- **Bound cosmetics:** a cosmetic entity kind (skin, emote, decoration, pet, per
  `MonetizationModel`) and a **cosmetic grant**: cosmetic id, owner key, issuer key, signature. A
  rule says cosmetics are never items: they have no stack, no trade, no drop, no chest, no loot.
  Cosmetic names are i18n keys, not prose.

**Acceptance criteria**
- `npm run validate` and `npm run check-drift` pass with the new entities, and
  `PlayerIdentityModel` is `superseded`.
- A new `tools/check_portability.js` (and its CI step) rejects a table that marks technology,
  inventory, equipment or owned structures as portable, a weapon, crafting tool or crafting station
  with no tier, a recipe with no `requiredTier`, and a cosmetic that
  can be traded, dropped or stored.

## Phase 228 — Keypair identity at runtime

- The client creates its keypair on first boot (`user://identity/`, private key file readable only
  by the user where the OS allows it) and reuses it after that. Losing the file means a new player,
  as losing a save does.
- Every host gets its own signing key here (`user://` for a listen host, the save folder for a
  dedicated server) and a world id; Phase 230 reuses them.
- The join handshake: the client sends its public key, the host replies with its own public key and
  a single-use nonce with an expiry, and the client signs `join | host key fingerprint | nonce`.
  Binding the host's key into the signed message stops a malicious host from relaying a nonce from
  another host and replaying the victim's answer there. The host verifies the signature and that the
  fingerprint is its own before binding the peer, and accepts no other intent from the peer until
  then. It refuses a key already bound to a live peer, an expired or reused nonce, an oversized key,
  a signature over another host's fingerprint and a bad signature, and it rate-limits failed
  attempts per address. Refusals reach the client as reason keys shown through `I18n.t()`.
- `PlayerRegistry` keys records by the key fingerprint. The cached-id claim is removed.
- **Migration:** an existing save's minted `player_id` records are bound once to the first key
  that joins and presents the old cached id. After that the old id is refused. The old id is a
  bearer secret only its client holds (the friend code never reveals it), so this is no weaker than
  today. A dedicated server logs every binding.
- The friend code (Phase 222 moves it to the map) keeps working; it does not reveal the key.

**Acceptance criteria**
- A suite test generates a key, signs a host nonce, and joins. Another test fails to join with: a
  replayed nonce, an expired nonce, a signature from another key, a signature over another host's
  key fingerprint, a key held by a live peer, and a key over the size limit. A peer that sends a
  gameplay intent before the handshake completes has it dropped. The refusal reason keys exist in
  both `en` and `pt_BR`.
- A suite test loads a pre-Phase-228 save, joins with the old cached id and a new key, finds the
  same record, and is refused when it presents the same old id with a second key.
- A net harness step: a client joins with its key, disconnects, reconnects and gets the same
  record. A second client that copies the first's public key but not its private key is refused.

## Phase 230 — Characters across worlds

- Each host signs with the key and world id from Phase 228.
- While a portable character is in a world, the host sends it a signed **progress delta** for the
  skill XP gained there since the last delta: at every autosave and on a clean logout or host
  shutdown. A dropped connection cannot be sent to, so it loses at most one autosave interval. The
  client stores the deltas in `user://characters/<id>/`. The skill XP never comes from the client;
  it comes from the host's signature over the host's own count.
- **Import:** joining a world with policy `trusted` or `open`, the client presents the character's
  name, appearance and its deltas. Skill XP comes only from verified deltas, never from a
  client-held total. The host verifies every signature, refuses a delta whose player key is not the
  key that signed the join (Phase 228), keeps only issuers its policy accepts, skips deltas it signed
  itself (its own record already holds that XP), skips duplicates by (issuer, sequence) and adds the
  XP. It records the applied (issuer, sequence) pairs per player key in its save, so presenting the
  same deltas on the next join adds nothing. The character arrives with its name, appearance, skills
  and cosmetics, and with no items, research, books or memberships. A world with policy `local`
  ignores the import and offers a fresh character.
- **Going home:** the home world applies its own policy the same way, so XP earned at a friend's
  comes back only if home is `trusted` with that friend's host key (or `open`). A `local` home
  keeps only its own XP.
- **`open` trusts anyone who runs a host**, since anyone can make a host key and sign any count. It
  is never the default, the options window says so, and it is bounded like every import.
- The import is bounded: a maximum number of deltas, a maximum file size, a cap on XP per delta and
  on XP imported per key per day (both from the fabric), and a rate limit on imports per key.
- The policy is a host setting in the options window (Phase 225) and a `--import-policy` flag for a
  dedicated server. All text through `I18n.t()`.

**Acceptance criteria**
- A suite test: host A signs a delta, host B with policy `trusted` listing A imports it and finds
  the XP. With policy `local` the character starts fresh. With `trusted` not listing A, the delta is
  ignored.
- A suite test refuses a delta with a bad signature, a delta issued to another player key, a
  duplicate (issuer, sequence), XP over the per-delta or per-day cap, and an import over the size
  or count limit. None of them changes the record. Presenting an already applied delta set on a
  second join, or a delta the importing host signed itself, adds no XP.
- A suite test asserts an imported character has an empty inventory, no research and no clan.
- A net harness step: a client plays on host A, gains skill XP, leaves, joins host B (`trusted` with
  A) and has the XP, then goes back to A (`trusted` with B) and has the XP earned on B.

## Phase 231 — Cosmetics bound to the key

- A cosmetic is owned by a **grant** signed by an issuer key. The official shop's public key is
  pinned in the game (the suite pins a test issuer key in its place). A host may add its own issuer
  key for cosmetics earned in its world; those show in that world and in worlds whose import policy
  trusts that host, and an unknown issuer's grant is refused.
- On join the client presents its grants. The host verifies each signature and that the grant's
  owner key is the key that signed the join nonce (Phase 228). A grant held by another key is
  refused, so copying a friend's grant file does nothing.
- Cosmetics travel to every world whatever the import policy, because they have no economic effect.
  They are applied only to the owner's own characters.
- Trade, drop, chest, loot and gift paths refuse a cosmetic. It never becomes an inventory item.
- Cosmetic names and the refusal reasons are keys shown through `I18n.t()`.

**Acceptance criteria**
- A suite test: a grant signed by the pinned shop key for the joining key is accepted and the
  cosmetic shows on that player's character. The same grant presented by another key is refused, and
  so is a grant with a bad signature or an unknown issuer.
- A suite test: trading, dropping, storing in a chest and gifting a cosmetic are all refused by the
  host.
- A suite test asserts every cosmetic name and refusal key exists in both `en` and `pt_BR`.
- A net harness step: a client joins host B (policy `local`) and its cosmetics are present; a second
  client given a copy of the first's grant files has none.

## Phase 233 — Flowing water: a bounded cellular automaton on edited chunks

Deferred since Phase 51, now possible because Phase 137 has a dirty-chunk pass for falling sand and
Phase 217 has fresh water. Today water is a static surface: a pit dug beside a lake stays dry and a
dam does nothing.

- **Fabric first** (separate PR): a `FluidFlow` table with the levels a cell can hold (8), the cells
  updated per tick per chunk, the flow budget per tick for the whole server, how far a source spreads
  over flat ground before it stops, and which materials water passes (none of the solids, sand
  falls through as in Phase 137).
- **Runtime:** water cells live only in chunks a player has edited near water. The static sea, lakes
  and rivers act as infinite sources at their surface; an edit that opens a hole in a shore, river
  bed or sea floor marks the chunk dirty and water flows in, down then sideways, level by level. A
  dam (a placed block) stops it; removing the dam starts it again. Untouched land never runs the
  automaton, so a fresh world costs nothing.
- **Authority:** the host runs the automaton on the server tick, deterministic per chunk (fixed
  update order, no floats in the cell state). Clients receive per-chunk water deltas through the
  existing chunk record sync, scoped to peers in range, and never compute flow themselves.
- **Persistence:** water cells are saved with the chunk's edits in the region store, so a flooded
  pit is still flooded after a restart. A chunk that settles (no change over a whole pass) leaves
  the dirty set.
- Swimming (`PlayerSlice._swimming_now`) and creature paths read the water cells as they read the
  static surface. Water cells are meshed with the fresh-water material (ice in a frozen chunk, where
  flow is off).

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; a `tools/check_fluid.js` rejects a table with zero
  levels, a negative budget or an unknown material, and CI runs it.
- A suite test digs a channel from a lake into a dry pit and, after N host ticks, the pit holds water
  level with the lake; placing a block across the channel first leaves it dry.
- A suite test runs the same edits twice from the same seed and gets identical water cells
  (determinism), and asserts a world with no edits near water has an empty dirty set.
- A suite test asserts a settled chunk leaves the dirty set and that the tick's cell updates never
  exceed the fabric budget.
- A suite test saves a flooded chunk, reloads the region and finds the same water cells; a player
  in the flooded pit reports the swimming state.
- A net harness step: the host floods a pit and a client in range receives the water cells; a client
  out of range receives none.

## Phase 236 — Changing hair style and colour: scissors and dye

Decided by the owner on 2026-11-06 (Deferred): not the creation screen, but a separate screen, open
only to a player who has crafted scissors (style) or dye (colour).

- **Fabric first** (separate PR): scissors (smithing, worn on use, durability) and dyes (alchemy,
  one per colour family, consumed on use), with their recipes, technologies and the hair styles and
  colours each unlocks. Styles and colours are the ones the creation screen already offers (Phase
  181); no new art.
- **Runtime:** a **Barber** window, opened from the Character window, shows the styles (needs
  scissors in the inventory) and colours (needs the matching dye). The client sends the choice; the
  host checks the item, wears the scissors or consumes the dye, updates the character's appearance
  and syncs it to peers in range. A choice without the item, or a style or colour not in the table,
  is refused.
- The doll in the Character window and the player's body in the world show the change at once.
- Labels and refusals (`needs_scissors`, `needs_dye`) are `I18n.t()` keys in `en` and `pt_BR`.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; a `tools/check_barber.js` rejects a dye whose colour is
  not a creation colour, and CI runs it.
- A suite test changes the hair style with scissors (durability drops by one) and the colour with a
  dye (one dye consumed), and asserts the appearance saved on the character is the new one.
- A suite test asserts the host refuses a style change without scissors, a colour change without the
  matching dye, and a style or colour id not in the table.
- A suite test asserts every Barber label and refusal key exists in both `en` and `pt_BR`.
- A net harness step: a client changes its hair colour and a second client sees the new colour on
  that body.

## Phase 246 — The regional bake: 2 m erosion detail in 4 km regions

The planet bake decides the large shapes. Carved ridges, gullies and sediment fans need erosion at
metres, which a whole planet cannot afford (about 250 TB at 2 m).

- The planet is split into fixed 4 km regions. A region is baked at 2 m cells when a body comes near
  it: the region it is in, then its neighbours along the body's heading. The planet bake is the input
  (heights, river paths), and regions overlap by a margin blended across, so borders do not show.
- Native and fixed-point, so the host and every client bake the same region from the same seed
  without sending terrain. A client too slow to keep up asks the host for the baked region
  (compressed heights, a few MB).
- Baked regions are kept on disk (host: next to the region store; client: in the Phase 244 cache), so
  a region is baked once per machine.
- Heights from the regional bake replace the detail noise inside baked regions. Before a region is
  baked, a chunk there is not built from noise: it waits, and the region is queued ahead of the body.
  Recorded chunks keep their records (the stable-world rule). Bump `WORLDGEN_VERSION`.

**Acceptance criteria**
- A suite test bakes the same region twice, with 1 and with 8 threads, and gets identical bytes.
- A suite test bakes two neighbouring regions and finds heights along the shared border equal within
  one height step.
- A suite test: a region's baked rivers follow the planet bake's paths within one 2 km cell.
- A net harness step: a client bakes a region, the host bakes it too, and their hashes match. A client
  started with `--no-regional-bake` receives it from the host.
- The playtest `flight` step meets its budgets with the regional bake on (the bake runs ahead of the
  body).

## Deferred (in priority order)

- **Fast travel beyond waystones** — a planet takes about 90 days to walk around. Phase 125 added
  waystones, Phase 216 mounts, and boats and roads are Phases 234–235. Ships for crossing oceans
  between continents remain.
- **Physics ragdolls** — Phase 157 animates deaths with a host-chosen landing spot and authored
  clips, so the headless server stays deterministic. A client-only ragdoll blend on top is later
  polish.
- **Localized fabric content** — entity names and descriptions (items, creatures, skills,
  technologies) translated through catalogs generated by Newel (`../newel/ROADMAP.md` Phase 15),
  consumed with the Phase 131 locale settings.
- **Public wiki deployment** — VitePress (or equivalent) static-site deployment and CI-triggered
  wiki regeneration from the fabric (deferred from Phase 9).
- **Voxel techniques from GDVoxelPlayground** — <https://github.com/JorisAR/GDVoxelPlayground>
  (MIT) was evaluated and not adopted wholesale: it ray-marches a fixed 128³ GPU grid, which does
  not fit an unbounded streamed world with a headless server. Worth borrowing later, CPU-side and
  deterministic: **WFC** for ruins, villages and dungeons, and a **brick occupancy map** if meshing
  becomes the bottleneck.
- **Raids** (dropped 2026-10-31, was Phase 200) — a warned, bounded creature attack on a village. Not wanted for now. Its spec is in git history (ROADMAP.md before PR #540).
- **Clan skills** — abilities (such as teleporting every member to one place) for the two or three members who contribute most to a clan. Contribution is to be defined, probably as a share of members' experience given to the clan. Clan tiers (Phase 210) give nothing until then.
- **Elder buildings** — buildings only a clan's top contributors can build. To be designed.
- **Settlement against settlement** — Phase 205 lets anyone destroy a structure they do not own. Organized sieges, wars and disputes between clans need governance and fairness rules first.
- **Real cross-region multiplayer run** — Phase 135 emulates WAN profiles in the harness. A run
  between real regions remains.
- **Automatic LOD mesh decimation** — simplified meshes are hand-authored (Phase 23).
- **Dynamic impostor re-bake** — impostor billboards are baked offline. A live re-bake on palette
  change is deferred from Phase 23.
- **Server sharding (last, not before maturity)** — split the authoritative simulation across
  servers by region once one headless server (Phase 27) with spatial hashing (Phase 28) and
  interest management (Phase 29) saturates. No structural change is needed before then. Revisit
  when Brazil-region load approaches one server's ceiling.
