# Project Nihon — Roadmap

Project Nihon is an open-source sandbox MMORPG where players build a
civilization. This document tracks the design and implementation roadmap.
The game's entire design bible — materials, creatures, skills, items, world
systems — is authored as a Newel fabric and generated into documentation,
runtime assets, and Godot resources.

See `../newel/ROADMAP.md` for the Newel-side changes each phase depends on.

**Human verification is not an acceptance criterion.** A criterion must be decidable by the
automated gates — `npm run validate`, `npm run check-drift`, the headless suite on both boot paths,
`tools/net_harness.sh`, CI. A check that needs a person at the keyboard (a playtest, a screenshot
judgement, a visual inspection) is not a criterion: it is filed as a GitHub issue and the phase
proceeds without it, so unpublished human work never parks the roadmap. The phase records the
issue number where the criterion used to be.

**Follow-up debt cap.** No new feature phase starts while more than 10 `autopilot-followup`
issues are open. Burn them down first (fix, fold into the next phase, or close with a reason).

---

## Phase index

Phases 1–225, 238–243, 248, 249 and 252–254 are done (200 and 201 were aborted). Their specs and acceptance criteria, and the
introductions of the arcs they belonged to, are archived in
[docs/roadmap-history/](docs/roadmap-history/README.md).

### Priority order

Set by the owner on 2026-11-10 and revised on 2026-11-12 after a repository review (Phases 252–258,
see [the review arc](#next-a-licence-a-green-main-and-a-first-release-phases-252258)). Work the open
phases top to bottom; the arc tables below keep their numbers and specs, but this list decides what
comes next. A phase that needs an earlier one still waits for it. Done phases (238–243, 248, 249, 252–254)
have left the list. Phases 227, 228, 230, 231, 233, 236 and 246 are parked (see
[Parked phases](#parked-phases)). Phase 236 keeps its place in the list for when it is un-parked; the
others are not in it.

| Priority | Phase | Title |
|---|---|---|
| 1 | 259 | Work takes time: bare hands, tools and a progress bar |
| 2 | 260 | Stone tools: an axe, a pick and a shovel from wood and stone, no bench |
| 3 | 261 | The newcomer grounds: a large, gentle spawn area with loose stones and branches |
| 4 | 262 | Starting with nothing, and a tutorial that begins from bare hands |
| 5 | 263 | Digging that shows at once: a predicted edit and a priority remesh |
| 6 | 264 | Dropping part of a stack: a quantity slider |
| 7 | 265 | One body everywhere: the creation screen, the Character window and the world draw the same avatar |
| 8 | 266 | A chibi character worth looking at: the art direction and the player rig |
| 9 | 255 | The first release: `v0.1.0` from the release workflow |
| 10 | 244 | A chunk cache on disk |
| 11 | 256 | A binary wire format for the hot packets |
| 12 | 250 | The server's ceiling: one machine serving, another running the bots |
| 13 | 237 | Flight that handles like flight |
| 14 | 251 | A human playtest: what would make the game fun (a standing checkpoint) |
| 15 | 245 | The planet bake: continents, rivers with flow, erosion and biomes at 2 km |
| 16 | 232 | Water that holds up: lake shores, the river seam and mounts at fords |
| 17 | 226 | Several characters per player |
| 18 | 229 | Skills capped by the gear |
| 19 | 247 | Ground cover: grass and bushes by biome |
| 20 | 235 | Roads |
| 21 | 234 | Boats |
| 22 | 257 | Split files named by what they do |
| 23 | 258 | The public wiki and the community channels |
| 24 | 236 | Changing hair style and colour (parked: picked up only when un-parked) |

Order notes that differ from the arcs' own order:

- Phases 259–266 come first. They are the owner's playtest findings of 2026-11-13 (Phase 251), filed
  as top priority: a new player should start with nothing and grow from bare hands, in a gentle
  area, with work that shows its progress, digging that shows at once, a drop that asks how many,
  and a character that looks the same everywhere and looks good. 259–262 depend on each other in
  that order (work time, then the tools it rewards, then the ground they are used on, then the
  empty start that needs all three); 263–266 stand alone.
- Phase 251 moved five places down on 2026-11-13, behind 225, 244, 256, 250 and 237, instead of
  being closed. It is a standing checkpoint: it is never closed, and each session's findings become
  new phases placed where the owner says.

- Phases 252–255 come first because each is small and each unblocks something no feature phase can:
  252 makes the "open-source" claim true, 253 makes a red `main` mean something again, 254 removes
  the ways a routine commit damages the repository, and 255 gives Phase 251 a build to play.
- Phase 251 moved from last to fifth on 2026-11-12. The owner's one session on 2026-11-06 produced
  four bugs and three menus (Phases 219–224) in an evening; nothing else on the list finds problems
  that cheaply. It repeats: after every five feature phases, a new playtest issue is opened from the
  same checklist. (Moved again on 2026-11-13, see above.)
- Phase 256 comes before Phase 250. The stress report's first two hot spots are `remote_player_state`
  (611% of the per-peer bandwidth budget at 200 bots) and `snapshot_chunk` (229%), both JSON text.
  Measuring the server's ceiling before the encoding changes would measure the encoding.
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
| 225 | The options window: sound, graphics and game settings | Done |
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
| 238 | One world: a fixed seed, a 2,000 km planet and one continent | Done (runtime PR; spec below) |
| 239 | Streaming that keeps up: a speed-scaled lead, adaptive workers, an attach budget | Done |
| 240 | Smooth natural ground: a surface-nets mesher (GDScript reference) | Done ([phases-240.md](docs/roadmap-history/phases-240.md)) |
| 241 | The native smooth mesher, and coarse chunks built smooth | Done ([phases-241.md](docs/roadmap-history/phases-241.md)) |
| 242 | Terrain materials: blend weights, a triplanar shader and CC0 textures | Done ([phases-242.md](docs/roadmap-history/phases-242.md)) |
| 243 | Level of detail past the window: voxel rings out to the distant ring, faded, under the haze | Done ([phases-243.md](docs/roadmap-history/phases-243.md)) |
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
| 249 | What to reuse from Zylann's godot_voxel: a review, then the parts that fit | Done ([phases-249.md](docs/roadmap-history/phases-249.md)) |
| 250 | The server's ceiling: one machine serving, another running the bots | Open |
| 251 | A human playtest: what would make the game fun | Ongoing (a standing checkpoint, never closed) |

### Next: a licence, a green `main` and a first release (Phases 252–258)

Filed on 2026-11-12 from a read-only review of the repository (its findings, ranked by impact, are
the order of this table). The repository is public and says "open-source" but has no licence file,
so legally nobody may fork, build on or redistribute it. `main` was red in 18 of its last 40 CI
runs: 7 of the last 8 failures were the playtest bot's gait assertion on the `walk` step ("left foot
ahead 100% of 36 frames, 0 lead switches"), a presentation check that fails the whole gate, and the
latest was the stress job finding a largest passing crowd of 0 for `cluster`, `cross` and `spread`
(baseline 16) and 16 for `pole` (baseline 32) on the merge of Phase 243 (#618). The release workflow
exists but no tag has ever been pushed, so no one but the owner has ever run a build. The working
tree carried an unignored `.claude/` folder of 600 MB, eight untracked `.uid` files, two lockfiles
and a submodule pointer rewound three commits. The 1,500-line cap on source files is met by nine
files named `*_part_1.gd`, `*_part_2.gd`, `*_part_3.gd`, split by line count rather than by what
they do. The deployed wiki deferred since Phase 9 is still deferred, and the repository has no
`CONTRIBUTING.md` and no Discussions, although the constitution's `CommunityOwnsTheFuture` principle
says decisions are proposed publicly.

| Phase | Title | Status |
|---|---|---|
| 252 | A licence and a contributor's front door | Done ([phases-252.md](docs/roadmap-history/phases-252.md)) |
| 253 | A green `main`: flaky gates demoted, the stress regression explained | Done ([phases-253.md](docs/roadmap-history/phases-253.md)) |
| 254 | Repository hygiene: `.uid` files tracked, one lockfile, nothing stray | Done ([phases-254.md](docs/roadmap-history/phases-254.md)) |
| 255 | The first release: `v0.1.0` from the release workflow | Open |
| 256 | A binary wire format for the hot packets | Open |
| 257 | Split files named by what they do | Open |
| 258 | The public wiki and the community channels | Open |

### Next: the first hour, from nothing (Phases 259–266)

Filed by the owner on 2026-11-13 from a Phase 251 playtest session, as top priority. A new character
is handed a tunic and a carpenter's axe (Phase 180, Phase 184) and spawns wherever the per-player
spawn search lands (Phase 53, `spawn_finder.gd`), among whatever creatures live there. Mining and
chopping are one click each with no wait (`voxel_edit.gd` `mine_block`, `tree_slice.gd`
`chop_tree`); a tree refuses bare hands (`axe_required`), and the first pick needs a carpentry bench
and a forge (the tutorial's `first_stations` and `first_tools` chapters). A dig reaches the screen
only after the host applies it and the chunk is re-meshed on a worker. Dropping from the inventory
drops one unit, or the whole stack with Shift (`ui_slice.gd` `finish_world_drop`). The world avatar
is the `models/player_rig.glb` rig (`attach_default_rig`), while the creation screen and the
Character window's doll are built by the older procedural body (`character_part_2.gd`
`_make_visual`), which draws hair as one box tinted by the colour and ignores the chosen style; the
per-style hair meshes (`models/characters/hair/<id>.glb.raw`) are generated but never loaded.

The owner wants the game to start from nothing: bare hands, loose stones and branches, stone tools
made on the spot, then trees, rock and weak creatures in a large gentle area with enough of
everything for the whole tutorial.

| Phase | Title | Status |
|---|---|---|
| 259 | Work takes time: bare hands, tools and a progress bar | Open |
| 260 | Stone tools: an axe, a pick and a shovel from wood and stone, no bench | Open |
| 261 | The newcomer grounds: a large, gentle spawn area with loose stones and branches | Open |
| 262 | Starting with nothing, and a tutorial that begins from bare hands | Open |
| 263 | Digging that shows at once: a predicted edit and a priority remesh | Open |
| 264 | Dropping part of a stack: a quantity slider | Open |
| 265 | One body everywhere: the creation screen, the Character window and the world draw the same avatar | Open |
| 266 | A chibi character worth looking at: the art direction and the player rig | Open |

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

**Status (2026-11-13): done.** `src/core/game_settings.gd` (spec, validation, save under `options` in
`user://settings.json`, apply) and `src/ui/options_window.gd` (Sound / Graphics / Game tabs), opened from the
main menu and the Esc menu. View distance sets `nihon/graphics/lod_rings`, terrain quality sets
`nihon/graphics/terrain_quality`; render scale and FSR 2 set the root viewport's `scaling_3d_*`; the Music and
Effects buses are created on first use. Only saved options are applied at boot, so a fresh install keeps the
engine's own window and scale. Phase 247's ground-cover option waits for that phase (it adds a `SPEC` entry).

**Acceptance criteria**
- [x] A suite test changes each setting, saves, reloads the settings in a fresh object and reads back the
  same values, and asserts the change was applied (bus volume, `TranslationServer` locale, tutorial
  flag). (`options_tests.gd`)
- [x] A suite test asserts every options label is a key in both `en` and `pt_BR`.

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

**Done.** Runtime landed with the fabric PR (#606): `WorldShape.continent_mask` (open continents only, a land core and a highland ring, deep ocean elsewhere), `TerrainSlice.set_world_circumference` / `adopt_record_circumference` (a record without a circumference reads as 40,000 km with no mask), closed sites never recorded or edited (`in_closed_site`), spawns inside open continents, no seed field in New world, `PlaytestBot.WORLD_SEED` = 238, `WORLDGEN_VERSION` 13, the native chunk builder mirrors the mask (`NativeChunkBuilder` version 9), tests in `one_world_tests.gd`. Re-tune: ridge and massif lattices keep their metre sizes on the small planet (`ridge_cells`, `massif_cells`), massif spawn clearance 40 km, hydrology cells 500 m and 1,000 m (divide 2,000 km). The suite pins a pre-238 world (40,000 km, no mask) for its older goldens; a test of the new planet passes `modern_world`. The playtest passes every step on the fabric seed.

Decided by the owner on 2026-11-10. Every world uses the same seed. The planet is small, a 2,000 km
equator, and only one continent is open at launch; more are opened later as data, so the world grows
with its players. Today `TerrainSlice` draws `randi()` for a new world, the Phase 223 New world dialog
takes an optional seed, `WorldSystem.circumferenceKm` defaults to 40,000, and continents come from
noise everywhere (`WorldShape.continentalness`, `CONTINENT_CELLS` counted across the circumference).

- **Fabric first** (separate PR; landed with `worldSeed` and `continents`, `tools/check_world_shape.js`; `circumferenceKm` moves to 2,000 in the runtime PR because the runtime reads it): `WorldSystem.worldSeed` (an integer), `circumferenceKm` 2,000, and a
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

## Phase 244 — A chunk cache on disk

Every visit rebuilds a chunk from noise. The host already stores edits and generation records per
region (`region_store`).

- **Host:** the resolved runs of a generated chunk are written next to its region the first time the
  chunk is built, keyed by `WORLDGEN_VERSION`, the worldgen fingerprint and the chunk's edit revision.
  A later build reads them instead of generating. Edits update the entry.
- **Client:** built mesh arrays (full, coarse and LOD levels) are cached under `user://cache/` with the
  same key plus the mesher version, capped in size with least-recently-used eviction. A revisit loads
  arrays from disk on a worker instead of meshing.
- **One file per region and layer** (Phase 249, the region-file layout ported from godot_voxel, MIT
  notice in the file and a row in `native/THIRD_PARTY.md`): a header with a sector table (one 32-bit
  entry per chunk of the 32×32 region: a 24-bit sector index and an 8-bit sector count, 0 for absent),
  entries at fixed-size sector boundaries, compressed with Godot's `compress(COMPRESSION_ZSTD)`. An
  entry that outgrows its sectors is moved to the end and the following sectors close the gap. Each
  entry starts with its own key, so a stale entry is a miss without reading the rest. The
  authoritative `region_store` JSON files do not change.
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
- **On the drawn surface** (Phase 249, ported from godot_voxel's instancer, MIT notice in the file and
  a row in `native/THIRD_PARTY.md`): (seed, tile) decides whether and what grows and its jitter; the
  height and normal come from the chunk's built mesh (the triangle under that point), so a tuft never
  floats or sinks where the smooth surface sits off the run top. Each plant kind has a level of detail:
  grass only on full-detail chunks, bushes on coarse ones too. A rebuilt chunk re-emits from its new
  mesh, so nothing is saved.
- Drawn with the MultiMesh pool in cells around the camera, with a density that falls with distance,
  and gone past a fade distance set by the graphics option. A wind sway in the vertex shader. A placed
  block or a mined tile removes the cover there.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass. A `tools/check_*.js` rejects ground cover on a material
  that is not a terrain material.
- Suite tests: placement is identical for the same seed and tile, nothing grows on rock, snow, water
  or a placed block, and density falls with distance.
- The playtest `walk` and `flight` steps meet their budgets with ground cover on.

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
- Revised 2026-11-12: the playtest repeats. After every five feature phases closed since the last
  one, a new issue is opened from the same checklist and this phase's number is reused; a phase that
  starts while such an issue is overdue is noted in its PR.
- Revised 2026-11-13: this phase is a standing checkpoint and is never closed. Each session's issue
  is closed when its findings are filed; the phase itself stays in the priority order, where the
  owner places it.

**Sessions**
- 2026-11-06: four bugs and three menus, filed as Phases 219–226.
- 2026-11-13: the first hour and the character, filed as Phases 259–266 (top of the priority
  order). Findings: the character starts with a tunic and an axe instead of nothing; there is no
  gentle area to start in; tools need a bench and bare hands cannot chop; gathering is one click
  with no sense of how long it takes; a dig takes a visible while to change the ground; a drop of a
  stack has no way to choose how many; the character is ugly and not the chibi style the owner
  wants; the creation screen does not show the chosen hair style; the Character window shows a
  different body from the one walking in the world.

## Phase 255 — The first release: `v0.1.0` from the release workflow

`release.yml` builds the native library on three platforms and attaches Linux, Windows and macOS
exports to a GitHub Release when a `v*` tag is pushed. It has never run: the repository has no tags.
Nobody but the owner has ever run a build, Phase 251 has nothing to hand a tester, and the
"public game must build and be fully playable without the submodule" rule has never been checked
by a player.

- A `CHANGELOG.md` with a `v0.1.0` entry (the arcs shipped, in a paragraph each) and a release
  checklist in `docs/DEVELOPMENT.md`: bump `config/version` in `project.godot`, write the changelog
  entry, tag, push, watch the workflow, smoke-test each download.
- `project.godot` gains `application/config/version` and the main menu shows it in a corner.
- The README's first screen gets a **Download** line pointing at the latest release, with the
  placeholder-art caveat.
- The release workflow runs the playtest bot's `create`, `walk` and `mine` steps against the Linux
  export under xvfb before publishing, so a broken export never becomes a release.
- Tag `v0.1.0` on the merge commit of this phase.

**Status (2026-11-13):** the version (`0.1.0`) and its menu label, `CHANGELOG.md` with `tools/check_changelog.sh` in
the `fabric` job, the release checklist, the README download line and the release workflow's dry run (manual or
on a PR touching anything a release depends on, with `create`, `walk` and `mine` played on the Linux export
through `tools/run_export_playtest.sh`, shared with CI's release-flight job) are in. Only the tag-only publish
job has a write token; the tag check runs before the native builds. Open: tag `v0.1.0` on the merge commit and check the release's assets.

**Acceptance criteria**
- A suite test reads `application/config/version` and asserts it parses as `major.minor.patch`.
- The release workflow has a `workflow_dispatch` dry run (no tag, no publish) that CI exercises on
  pull requests touching it, and it runs the three playtest steps on the export.
- `CHANGELOG.md` exists and a CI step fails when the version in `project.godot` has no entry.
- A GitHub Release `v0.1.0` exists with three assets; the README download link resolves to it.

## Phase 256 — A binary wire format for the hot packets

Every packet is a JSON string carried by two RPCs (`_rpc_c2h`, `_rpc_h2c`), parsed with `_parse`
and capped at `MAX_CLIENT_PACKET_BYTES`. The stress report ranks `remote_player_state` first among
hot spots (+2.01 kbit/s per peer per bot, 611% of the 64 kbit/s per-peer budget at 200 bots) and
`snapshot_chunk` second (229%). Phase 250 measures the server's ceiling; with text encoding it would
measure the encoding. The guards at `_accept_c2h` (size cap, token bucket, dedup) stay in front of
whatever is parsed.

- A `PacketCodec` (`src/networking/packet_codec.gd`, native port optional later) with a fixed
  layout per hot type: a one-byte type tag, a `u16` seq, and for `remote_player_state` the peer id
  and position quantised to centimetres as three `i32` (the rebase origin is sent with the chunk
  window, not per packet); `snapshot_chunk` carries its index, count and the chunk's bytes as a
  `PackedByteArray` instead of a base-64 string. Every other type stays JSON until it earns a layout.
- The two RPCs take a `PackedByteArray`; the first byte says binary or JSON (`{`), so a peer that
  predates the codec is read correctly and refused with the usual version mismatch.
- The host rejects a binary packet whose length does not match its type's layout, with the same
  silent drop and rate-limited warning as an oversized one.
- The stress baseline (`docs/perf/crowd-baseline.md`, `StressRules.BASELINE_LARGEST`) is re-recorded
  after the change, and the hot-spot table in this file's Phase 250 is updated from it.

**Acceptance criteria**
- A suite test round-trips each binary type through the codec, including positions at ±1,000 km
  from the origin, and rejects a packet one byte short and one byte long.
- A suite test asserts a `remote_player_state` packet is at most 20 bytes on the wire.
- The net harness passes under `lan`, `wan_br` and `wan_bad`; the `wan_bad` run no longer mutes
  creature position deltas for bandwidth (or the harness records why it still must).
- The stress run's `down_kbps_per_peer` at 16 bots in `lan/cluster` falls by at least 3× against the
  baseline recorded before this phase, and no series' largest passing size falls.

## Phase 257 — Split files named by what they do

Phase 154's 1,500-line cap is met: seven files sit at 1,497–1,500 lines and nine are named by
number (`net_part_1.gd`, `net_part_2.gd`, `net_part_3.gd`, `ui_part_1.gd`, `ui_part_2.gd`,
`chunk_part_1.gd`, `character_part_1.gd`, `character_part_2.gd`, `character_part_3.gd`; 4,038
lines). The split satisfies the cap's letter: a reader must know which part holds a function, which
is harder than one long file. The cap stays; the parts get names.

- Each `*_part_N.gd` is renamed for its responsibility (for example `net_part_2.gd` →
  `net_player_state.gd` if that is what it holds) and its header comment says what belongs there and
  what does not. Functions that landed in a part only because the slice was full move to the file
  whose name fits.
- The suite's source audit (`MAX_SOURCE_LINES`) also refuses any `.gd` whose name matches
  `_part_\d+` or ends in a digit, and refuses a file within 50 lines of the cap unless its header
  names the split that is planned for it.
- `CLAUDE.md`'s architecture section names the new files where it names the slices.

**Acceptance criteria**
- No file under `src/` matches `_part_\d+\.gd`; the audit test proves it rejects a fixture that
  does.
- The suite, the net harness and the playtest bot pass unchanged (a rename is behaviour-free).
- `grep -c` of the old names in `src/`, `tools/`, `docs/` and `CLAUDE.md` is 0.

## Phase 258 — The public wiki and the community channels

`npm run generate` writes `wiki/` from the fabric on every merge and nobody can read it without a
clone; "Public wiki deployment" has been in the Deferred list since Phase 9. The constitution's
`CommunityOwnsTheFuture` says decisions are proposed publicly and ratified by contributor consensus,
and the repository has no Discussions and no place a proposal could be made. This phase comes after
Phases 252 and 255 because a wiki and a forum for a project nobody may legally fork or download
would be empty.

- A GitHub Pages workflow (`pages.yml`) builds `wiki/` with VitePress (or the static generator
  Newel's wiki generator targets) on every push to `main` and deploys it; the bible is linked from it.
- The README links the wiki and the Discussions, and `CONTRIBUTING.md` says where proposals go.
- Enabling Discussions and Pages are repository settings: filed as a GitHub issue for the owner, the
  number recorded here.

**Acceptance criteria**
- `pages.yml` builds the site in CI on pull requests touching `wiki/`, `fabric/` or the workflow,
  and fails on a broken internal link (the generator's link check, or `lychee` over the output).
- A GitHub issue asks the owner to enable Pages and Discussions; this phase records its number.
- After the issue closes, the README's wiki link returns 200 from a CI step on `main`.

## Phase 259 — Work takes time: bare hands, tools and a progress bar

Mining a span and chopping a tree each finish on one click, so nothing tells a player that a pick is
better than a fist, and a tree refuses bare hands outright (`tree_slice.gd` `chop_tree`,
`axe_required`). Every gathering action becomes timed work: held, shown as progress, and faster with
the right tool.

- **Fabric (separate PR):** a `WorkTimes` table. Each material has a `workSeconds` base (soil and
  sand low, host rock higher, ores by tier, each wood by tree). Each action (`dig`, `mine`, `chop`)
  names the tool class that suits it (`shovel` digs soil, `pick` mines rock and ore, `axe` chops).
  Each tool item gets a `workSpeed` per class it serves; bare hands are a fixed slow factor (about
  4× the base, tuned so the first stone tool feels like a real step). A tool of the wrong class
  counts as bare hands. Ores above a tier refuse bare hands and tools below it, as deep seams do
  today. A `tools/check_work_times.js` rejects a material with no time, a tool with no speed for its
  own class, and bare hands faster than any tool.
- **Bare hands chop:** a tree no longer refuses an empty hand; it takes the bare-hands time. The
  `axe_required` refusal is removed (its locale keys go with it).
- **Hold to work:** pressing the gather input on a target starts the work; holding it fills
  progress; releasing, turning to another target, leaving reach or being hit cancels it and the
  progress is lost. On completion the existing `mine_block` / `chop_tree` run unchanged. Holding on
  after a completion starts the next target under the crosshair, so digging a trench is one hold.
- **The host times it (trust boundary):** the client sends a work start (target, action); the host
  checks reach and the held tool, records the start tick and the duration it computed itself, and
  completes the work when that time has passed while the player still holds it. A completion the
  client claims early is never accepted; a cancel is accepted at any time. Start intents are
  rate-limited like other gather intents.
- **The progress bar:** a small radial bar around the crosshair (or a thin bar under it) fills over
  the duration, with the target's name and a rough time left (`~3 s`, through `I18n.t`). A fist,
  pick, axe or shovel icon shows which tool is being used. A crack overlay on the targeted block
  and a shake on the tree mark the same progress in the world, for other players too.
- Skills (Phase 207) are granted as before, on completion.

**Progress (in flight):** done — fabric `WorkTimes` + `tools/check_work_times.js` (CI step), `src/core/work_time.gd` (pure time), `src/core/work_session.gd` (host timer), bare-handed chop (`axe_required` gone). Left — bus/net work start/cancel/complete intents with rate limit, hold-to-work input, progress bar + crack/shake, net harness step, playtest `mine`/`gather` holds, locale strings.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; `tools/check_work_times.js` passes its own bad tables.
- Suite tests: a work time is a pure function of (material, action, held tool); bare hands on soil,
  rock and wood are slower than every tool of the right class; a wrong-class tool equals bare hands.
- Suite tests: a tree is chopped bare-handed; the host refuses a completion before the duration,
  completes on time with the input held, and cancels on release, retarget and leaving reach,
  spending no durability on a cancel.
- Net harness step: a client holds work on a span and the host completes it once, at the host's
  time, with a forged early completion dropped.
- The playtest `mine` and `gather` steps hold work instead of clicking and still pass, and record
  the time each work took.
- Every new string is in both `en` and `pt_BR` in `locale/ui.csv`.

## Phase 260 — Stone tools: an axe, a pick and a shovel from wood and stone, no bench

The first pick is a ferrite pick from a forge (Phase 184's `first_tools` chapter), and the axe came
from the starting kit. A newcomer makes simple tools on the spot instead.

- **Fabric (separate PR):** items `Branch` (a stick picked off the ground or from a felled tree) and
  `LooseStone` (a stone picked off the ground or knocked from rock), both stackable and light.
  Tools `StoneAxe`, `StonePick`, `StoneShovel`, plus `StoneKnife` (Phase 160's `knife` harvest tool
  at a low `efficiency`) and `StoneHammer` if building needs one. Each is `Branch` + `LooseStone` in
  small amounts, with **no station**, under a free technology (research cost 0, no prerequisite,
  like `TechBasicCarpentry`) and a novice skill guard. Low durability; their `workSpeed` sits
  between bare hands and the ferrite tools (Phase 259).
- **The shovel** gives a new tool class, `shovel`, that digs soil, sand and gravel fastest;
  `voxel_edit.gd` reads the held shovel like it reads the pick.
- Felling a tree also yields a few branches; mining host rock has a chance to yield a loose stone
  beside its material, so the inputs never run out where there is rock and wood.
- The crafting window lists station-free recipes without a station, as the bed already is
  (Phase 184).

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; a `check_*.js` rejects a stone tool with a station or a
  technology that costs research points.
- Suite tests: each stone tool is craftable with no station from `Branch` and `LooseStone` only, on
  a fresh character's known technologies; the shovel digs soil faster than the pick and the pick
  mines rock faster than the shovel.
- `tutorial_tests.gd` `_first_hour_items`: with an empty starting kit and only loose stones and
  branches, every stone tool is reachable.
- Every new string is in both locales.

## Phase 261 — The newcomer grounds: a large, gentle spawn area with loose stones and branches

A new character spawns wherever the spawn search seeded by the player id lands, among whatever lives
there. Newcomers get their own ground instead.

- **Fabric (separate PR):** a `NewcomerGrounds` entry in `WorldSystem`: how many grounds there are on
  the open continent (a few, so players meet but do not crowd), their radius (about 1 km), the
  biomes they may sit in (temperate forest and grassland edges: trees, open ground and rock in
  reach), the creatures allowed inside (passive or weak ones only, by a fabric level or danger
  cap), and the density of loose items.
- **Placement:** the grounds' centres are a pure function of the world seed (Phase 238), chosen on
  habitable land with trees and surface rock within each ground. The spawn search places a new
  character at a point inside one ground (picked by the player id, as now), never in water or on a
  steep slope.
- **Creatures:** spawning inside a ground draws only from its allowed list; an aggressive creature
  that wanders in turns back at the edge (a no-go zone for its AI, as structures' circles are since
  Phase 213). Enough weak creatures live there for the tutorial's first hunt.
- **Loose stones and branches:** small pickable props on the ground, denser inside the grounds and
  sparse elsewhere, placed as a pure function of (seed, tile) like trees (no world-gen change, so no
  `WORLDGEN_VERSION` bump). Picking one up is the interact input, instant, and grants the item.
  The host keeps which were taken and regrows them after a fabric delay, so the ground never runs
  dry for the next newcomer. They are drawn with the MultiMesh pool and synced like tree state.
- **Resources:** the guarantee is checked, not hoped for: every ground has, within a fabric radius of
  each spawn point, trees, surface rock, soil, loose items and the creatures the tutorial needs.
- Claims: no structure may be placed within a small radius of a ground's centre, so a newcomer's
  spawn is never walled in. Building elsewhere in the ground is allowed.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; a `check_*.js` rejects an aggressive creature in the
  allowed list and a radius below the tutorial's needs.
- Suite tests: the grounds' centres are identical for the same seed; a new character's spawn lies
  inside a ground on dry, walkable land; within the fabric radius of sampled spawn points there are
  trees, rock, soil, loose stones, branches and an allowed creature spawn.
- Suite tests: loose-item placement is identical for the same (seed, tile); a picked item is gone
  for every peer and regrows after the delay; a pick-up out of reach or of an item already taken is
  refused by the host.
- Suite test: no creature outside the allowed list spawns inside a ground, and placement within the
  protected radius is refused.
- Net harness step: a client picks up a loose stone and the second client sees it gone.

## Phase 262 — Starting with nothing, and a tutorial that begins from bare hands

Depends on Phases 259–261.

- `CharacterCreation.startingKit` becomes empty. The `NoviceTunic` stays an item that can be made
  (a cheap fibre or hide recipe) but is not handed out; a new character wears the base body's
  plain clothes, which are part of the appearance, not an item, so nobody is shown naked and nothing
  is given.
- The tutorial (`fabric/gameplay/tutorial.js`) is rewritten to start from nothing: move, look, pick
  up a branch and a stone, open the inventory, craft a stone axe (the crafting window), chop a tree,
  craft a stone pick and shovel, dig soil, mine stone, then the existing stations, bed, shelter,
  first hunt (with a stone knife for the harvest), map and the rest. Each step's card names the
  input and, where it helps, the place (for example "loose stones lie on the ground nearby").
- `_first_hour_items` (`tutorial_tests.gd`) starts from an empty kit plus what bare hands, loose
  items and the newcomer grounds give, and still reaches the bed, the first ferrite pick and the
  first weapon.
- Stress and playtest bots, which relied on the starting kit (`stress_clan_bots.gd`), gather or
  craft what they need first, or are given items through a test-only path that real play cannot
  reach.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; the creation validator accepts an empty kit.
- Suite tests: a new character's bag and equipment are empty; the first-hour reach test passes from
  an empty kit; every tutorial step's requirements name earlier steps (as now).
- The playtest `create` step asserts an empty bag, and the `tutorial` step completes the moving,
  gathering, first-tools, first-stations and first-hunt chapters from bare hands.

## Phase 263 — Digging that shows at once: a predicted edit and a priority remesh

A dig waits for the host to apply it, then for the chunk's rebuild to come out of the worker queue
behind streaming work. The ground should change the frame the work completes.

- **Measure first:** the playtest `mine` step records, per edit, the time from completion to the
  edited mesh on screen, split into network, queue wait and build, on the listen host and on a
  client under `lan` and `wan_br`.
- **A priority remesh:** an edited chunk (and the neighbour whose seam it touches) jumps the build
  queue, ahead of streaming. If the build is short enough (native smooth mesher), it runs on the
  main thread at once for that one chunk; otherwise it takes the next worker. Collision follows the
  same path, so the player never falls into a hole they cannot see, or stands on one they can.
- **Prediction on the client:** when the host's timer (Phase 259) is about to complete, the client
  applies the edit to its own copy and remeshes as above, marked pending. The host's
  `block_changed` confirms it; a refusal (or no answer within a timeout) rolls the chunk back and
  shows the refusal. Inventory and durability stay host-only: the item appears when the host says
  so.
- Placement gets the same path.

**Acceptance criteria**
- Suite tests: an edited chunk is built before every queued streaming chunk; a predicted edit is
  applied to the client's voxel data and rolled back on a host refusal, leaving the chunk byte-equal
  to before; inventory never changes on prediction alone.
- The playtest `mine` step reports edit-to-visible time; its p95 on the listen host is at most two
  frames at the target frame rate, gated in `docs/perf/playtest-budget.json`.
- The net harness's `wan_br` run shows a client's predicted edit visible before the host's
  confirmation arrives, and a refused edit rolled back.

## Phase 264 — Dropping part of a stack: a quantity slider

Dragging a stack into the world drops one unit, or all of it with Shift. There is no way to drop,
say, 7 of 20.

- Dropping a stack of more than one (drag to the world, or a Drop entry where the inventory offers
  one) opens a small dialog: the item's icon and name, a slider from 1 to the stack size, a number
  field kept in sync with it, buttons for 1, half and all, then Drop and Cancel. Enter confirms and
  Esc cancels; the number field owns the keyboard while focused (Phase 219).
- The slider starts at the whole stack. Shift-drag keeps dropping the whole stack without the
  dialog, and a stack of one never opens it.
- The request goes through `request_drop`, and the host clamps the quantity to what the bag holds,
  as now.

**Acceptance criteria**
- Suite tests: a drag of a stack above one opens the dialog with its range 1..count; a stack of one
  and a Shift-drag drop without it; the slider and the field stay equal; confirming emits one drop
  of the chosen quantity, cancelling emits none; Enter and Esc do the same while the field has focus.
- Suite test: the host clamps a drop request above the bag's count.
- Every new string is in both locales.

## Phase 265 — One body everywhere: the creation screen, the Character window and the world draw the same avatar

The world avatar is the `models/player_rig.glb` rig with its material and palette
(`attach_default_rig`). The creation screen and the Character window's doll are built by the older
procedural body in `character_part_2.gd` `_make_visual`, so they show a different character. That
body draws hair as one box tinted by the hair colour and never reads the style, which is why picking
a hair style changes nothing on the right of the creation screen. The per-style hair meshes
(`models/characters/hair/<id>.glb.raw`, drawn by `gen_placeholder_glb.py`) are never loaded.

- **One builder:** an avatar builder (for example `src/character/avatar_builder.gd`) takes an
  appearance and a worn set and returns the rig the world uses: the player rig, its material and
  palette indices, the hair style's mesh on the head socket, and the worn equipment on their
  sockets. The world avatar, the creation screen's rig and the Character window's doll all call it.
  The procedural box body remains only as the fallback when no rig is listed in the manifest.
- **Hair:** the chosen style's mesh is loaded from its key and tinted by the hair colour; a style
  change on the creation screen swaps it on the next frame. The same mesh is what other players see.
- **The doll and the creation rig animate** with the idle clip, lit like the world's camera sees the
  avatar, so the three views match.

**Acceptance criteria**
- Suite tests: for the same appearance and worn set, the world avatar, the creation rig and the
  doll have the same mesh resources, the same material parameters and the same attached nodes.
- Suite tests: every hair style in `CharacterCreation.hairStyles` loads its own mesh on the head
  socket; two different styles give different meshes; changing the style on the creation screen
  replaces the hair mesh.
- Every hair key has a placeholder in `assets/` (the placeholder rule), checked by the suite.
- The playtest `create` and `character_sheet` steps assert the rig's hair mesh matches the chosen
  style, and still render non-blank.

## Phase 266 — A chibi character worth looking at: the art direction and the player rig

The owner finds the player character ugly and not the style they want: the cute, big-headed chibi
look of classic 2000s isometric MMOs (the owner's reference is Ragnarok Online). The goal is that
feel in this game's own art; no assets, sprites or likenesses are taken from any other game.

- **An art direction document** (`docs/art/character-style.md`): proportions (head to body about
  1:2 to 1:2.5, within `CharacterCreation.headRatio`), silhouette rules, big expressive eyes, simple
  shapes, flat or toon shading with an outline, a limited palette (the existing `DefaultPalette`
  regions), and how hair and equipment read at the default camera distance.
- **The decision to make first** (owner, filed as an issue): a toon-shaded 3D chibi rig, or
  pre-rendered sprites in 8 directions drawn over the 3D world (the classic look, harder to combine
  with free camera rotation and equipment). The document records the choice and the reason.
- **The placeholder rig** (`gen_placeholder_glb.py`) is redrawn to those proportions so the public
  build already has the shape, and the production rig in `assets-prod/` follows with the same bones
  and clips. A toon shader and outline for characters, if chosen, live in `character_material`.
- The hair meshes (Phase 265) are redrawn to the same style.

**Acceptance criteria**
- `docs/art/character-style.md` exists with the proportions, and the choice between 3D and
  sprites is recorded in it.
- A suite test measures the placeholder rig's head height against its full height and asserts it
  is within `CharacterCreation.headRatio`.
- The placeholder rig keeps every bone and clip the production rig has (the placeholder rule), and
  the playtest `walk` and `create` steps pass with it.
- Whether the result looks good is a human judgement: filed as a GitHub issue per the rule at the
  top of this file, and this phase records its number.

---

## Parked phases

Parked by the owner on 2026-11-10. Their specs are kept as written so a phase can be picked up
again; check each against the phases done since before un-parking it. Phase 236 is also the
last entry of the priority order, which it keeps when un-parked.

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

- **Fast travel beyond waystones** — a planet takes about 4.5 days to walk around (Phase 238: 2,000 km; the open continent is crossed in about a day and a half). Phase 125 added
  waystones, Phase 216 mounts, and boats and roads are Phases 234–235. Ships for crossing oceans
  between continents remain.
- **Physics ragdolls** — Phase 157 animates deaths with a host-chosen landing spot and authored
  clips, so the headless server stays deterministic. A client-only ragdoll blend on top is later
  polish.
- **Localized fabric content** — entity names and descriptions (items, creatures, skills,
  technologies) translated through catalogs generated by Newel (`../newel/ROADMAP.md` Phase 15),
  consumed with the Phase 131 locale settings.
- **Public wiki deployment** — now Phase 258 (filed 2026-11-12; deferred from Phase 9 until then).
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
