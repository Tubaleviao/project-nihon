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

Phases 1–225, 238–244, 248–250, 252–257, 259–276, 281–283, 289 are done (200 and 201 were aborted). Their specs and acceptance criteria, and the
introductions of the arcs they belonged to, are archived in
[docs/roadmap-history/](docs/roadmap-history/README.md).

### Priority order

Reordered by the owner on 2026-11-22 (first set on 2026-11-10, revised on 2026-11-12 after the
[repository review](#next-a-licence-a-green-main-and-a-first-release-phases-252258)). Work the open
phases top to bottom; the arc tables below keep their numbers and specs, but this list decides what
comes next. A phase that needs an earlier one still waits for it. The list is renumbered from 1 whenever
it changes, and done phases leave it. Phases 227, 228, 230, 231, 233, 236 and 246 are parked (see
[Parked phases](#parked-phases)). Phase 236 keeps a place for when it is un-parked; the others are not
in it. Phase 251 is last: it is a standing checkpoint played when the owner has time, not a phase to
work in order.

| Priority | Phase | Title |
|---|---|---|
| 1 | 245 | The planet bake: continents, rivers with flow, erosion and biomes at 2 km |
| 2 | 232 | Water that holds up: lake shores, the river seam and mounts at fords |
| 3 | 300 | Digging with a brush: one dig moves a shovelful, not a slab |
| 4 | 301 | Shaping the ground: fill, flatten and smooth, and a dug surface that shows what it is |
| 5 | 247 | Ground cover: grass and bushes by biome |
| 6 | 235 | Roads |
| 7 | 234 | Boats |
| 8 | 258 | The public wiki and the community channels |
| 9 | 299 | Many registries: signed entries, gossip and no single owner |
| 10 | 236 | Changing hair style and colour (parked: picked up only when un-parked) |
| 11 | 251 | A human playtest: what would make the game fun (a standing checkpoint, when the owner has time) |

Why this order:

- **295–296 done.** The last findings of the owner's fourth playtest (2026-11-20): 295 was the fabric PR,
  296 the runtime. They change what equipment is, so everything that reads gear waits for them.
- **229 done.** Skill tiers gated by gear, built on the equipment categories 295–296 introduced: the fabric
  PR (#737) and the runtime PR.
- **226 done.** Several characters per player: the fabric PR (#740) and the runtime PR.
- **297 done.** Finding servers nearby: ports and IPv6 in the address, a status port, a protocol version and LAN
  discovery on the Join screen.
- **298 done.** The server list: a `--registry` role, `--public` hosts that heartbeat to it, and the Join screen's
  Public servers tab. With 297 it makes finding a server the normal way to play instead of typing an address.
- **257 done.** A rename of the numbered `*_part_N.gd` files is cheap now and makes
  the terrain and net code easier to read for 245 onward.
- **245 → 232 → 300 → 301 → 247 → 235 → 234: the world.** Phase 245 replaces Phase 217's river trace, so 232's
  river-seam fix applies to the baked rivers (its lake-shore and ford work stays as written). Phase 245 also
  brings the terrain CSG helper (smooth subtract/union of distance shapes) that 232 carves lake basins with
  and 300–301 dig and shape with. Digging comes before ground cover (2026-11-25: the owner finds digging
  neither useful nor fun), so 247 knows from the start that a dug surface is bare; roads (235) cut and fill
  with 301's flatten brush.
- **258 late.** A public wiki and Discussions matter once there are players to read them.
- **299 near the end.** It brings the host-key part of parked Phase 228 forward and needs parked Phase
  227 (design-only) first.
- **251 last.** A standing checkpoint, never closed. Each session's findings become new phases placed
  where the owner says (past sets: 219–224, 259–276, 278–290, 291–296).

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
| 226 | Several characters per player: a new one starts from scratch, chosen in the main menu | Done |

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
| 229 | Skills capped by the gear: advanced abilities need a weapon of their tier, advanced recipes a tool and station of theirs | Done |
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
| 237 | Flight that handles like flight: inertia, steering by the camera, no ground-walking fixes in the air | Done |
| 238 | One world: a fixed seed, a 2,000 km planet and one continent | Done (runtime PR; spec below) |
| 239 | Streaming that keeps up: a speed-scaled lead, adaptive workers, an attach budget | Done |
| 240 | Smooth natural ground: a surface-nets mesher (GDScript reference) | Done ([phases-240.md](docs/roadmap-history/phases-240.md)) |
| 241 | The native smooth mesher, and coarse chunks built smooth | Done ([phases-241.md](docs/roadmap-history/phases-241.md)) |
| 242 | Terrain materials: blend weights, a triplanar shader and CC0 textures | Done ([phases-242.md](docs/roadmap-history/phases-242.md)) |
| 243 | Level of detail past the window: voxel rings out to the distant ring, faded, under the haze | Done ([phases-243.md](docs/roadmap-history/phases-243.md)) |
| 244 | A chunk cache on disk: the host keeps generated chunks, the client keeps built meshes | Done ([phases-244.md](docs/roadmap-history/phases-244.md)) |
| 245 | The planet bake: continents, rivers with flow, erosion and biomes at 2 km | Open |
| 246 | The regional bake: 2 m erosion detail in 4 km regions, on demand around players | Parked |
| 247 | Ground cover: grass and bushes by biome, culled by distance | Open |

### Arc: digging worth doing (Phases 300–301)

Filed by the owner on 2026-11-25 after reviewing [GDVoxelTerrain](https://github.com/JorisAR/GDVoxelTerrain)
(MIT, Joris AR), a Godot smooth-voxel plugin whose edits are SDF brushes: a dig or a build is one small
op (shape, position, radius, boolean or smooth boolean) applied to the field and re-meshed, with the
edit's material painted onto what it touched. Digging here is the opposite: one mine removes one
0.5 × 0.5 × 0.125 m slab (0.03 m³) from one column, a 1 m cube is 32 holds, and on the smooth
mesher (Phase 240) a slab barely shows. The review kept the brush ops, the smooth boolean maths
(`sdf_operations.h`), paint-on-edit and the populator's placement filters (into 247); it left the
octree storage, since the run columns, op logs and stable-world rule already work and the brush can be
rasterised into them.

| Phase | Title | Status |
|---|---|---|
| 300 | Digging with a brush: one dig moves a shovelful, not a slab | Open |
| 301 | Shaping the ground: fill, flatten and smooth, and a dug surface that shows what it is | Open |

### Next: foundations, the server's ceiling and a human playtest (Phases 248–251)

Filed by the owner on 2026-11-10 with the priority order. Phase 248 splits the release build out of
Phase 239 and gives every later native port (241, 245, and whatever 249 adopts) one shared base.
Phase 249 checks what Zylann's voxel engine already solves before Phases 240–244 build it. Phase 250
measures how many players one server holds on real hardware. Phase 251 is the owner playing the game.

| Phase | Title | Status |
|---|---|---|
| 248 | The native library base and a release build | Done ([phases-248.md](docs/roadmap-history/phases-248.md)) |
| 249 | What to reuse from Zylann's godot_voxel: a review, then the parts that fit | Done ([phases-249.md](docs/roadmap-history/phases-249.md)) |
| 250 | The server's ceiling: one machine serving, another running the bots | Done ([phases-250.md](docs/roadmap-history/phases-250.md)) |
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
files named `*_part_1.gd`, `*_part_2.gd`, `*_part_3.gd`, split by line count rather than by what (renamed in Phase 257)
they do. The deployed wiki deferred since Phase 9 is still deferred, and the repository has no
`CONTRIBUTING.md` and no Discussions, although the constitution's `CommunityOwnsTheFuture` principle
says decisions are proposed publicly.

| Phase | Title | Status |
|---|---|---|
| 252 | A licence and a contributor's front door | Done ([phases-252.md](docs/roadmap-history/phases-252.md)) |
| 253 | A green `main`: flaky gates demoted, the stress regression explained | Done ([phases-253.md](docs/roadmap-history/phases-253.md)) |
| 254 | Repository hygiene: `.uid` files tracked, one lockfile, nothing stray | Done ([phases-254.md](docs/roadmap-history/phases-254.md)) |
| 255 | The first release: `v0.1.0` from the release workflow | Done ([phases-255.md](docs/roadmap-history/phases-255.md)) |
| 256 | A binary wire format for the hot packets | Done ([phases-256.md](docs/roadmap-history/phases-256.md)) |
| 257 | Split files named by what they do | Done ([phases-257.md](docs/roadmap-history/phases-257.md)) |
| 258 | The public wiki and the community channels | Open |

### Next: the first hour, from nothing (Phases 259–266)

Filed by the owner on 2026-11-13 from a Phase 251 playtest session, as top priority. A new character
is handed a tunic and a carpenter's axe (Phase 180, Phase 184) and spawns wherever the per-player
spawn search lands (Phase 53, `spawn_finder.gd`), among whatever creatures live there. Mining and
chopping are one click each with no wait (`voxel_edit.gd` `mine_block`, `tree_slice.gd`
`chop_tree`); a tree takes bare hands, slowly, and the first pick needs a carpentry bench
and a forge (the tutorial's `first_stations` and `first_tools` chapters). A dig reaches the screen
only after the host applies it and the chunk is re-meshed on a worker. Dropping from the inventory
drops one unit, or the whole stack with Shift (`ui_slice.gd` `finish_world_drop`). The world avatar
is the `models/player_rig.glb` rig (`attach_default_rig`), while the creation screen and the
Character window's doll are built by the older procedural body (`character_body_actions.gd`
`_make_visual`), which draws hair as one box tinted by the colour and ignores the chosen style; the
per-style hair meshes (`models/characters/hair/<id>.glb.raw`) are generated but never loaded.

The owner wants the game to start from nothing: bare hands, loose stones and branches, stone tools
made on the spot, then trees, rock and weak creatures in a large gentle area with enough of
everything for the whole tutorial.

| Phase | Title | Status |
|---|---|---|
| 259 | Work takes time: bare hands, tools and a progress bar | Done |
| 260 | Stone tools: an axe, a pick and a shovel from wood and stone, no bench | Done |
| 261 | The newcomer grounds: a large, gentle spawn area with loose stones and branches | Done |
| 262 | Starting with nothing, and a tutorial that begins from bare hands | Done |
| 263 | Digging that shows at once: a predicted edit and a priority remesh | Done |
| 264 | Dropping part of a stack: a quantity slider | Done |
| 265 | One body everywhere: the creation screen, the Character window and the world draw the same avatar | Done |
| 266 | A chibi character worth looking at: the art direction and the player rig | Done |

### Next: stations you make, and windows a player can read (Phases 267–274)

Filed by the owner on 2026-11-14 from a Phase 251 playtest session. Every station is placed from
the start with B (cycle), N (ghost) and V (place); only waystones, beds, chests, doors and the
hearth cost an item. The crafting window lists every recipe, whatever station it needs, as text
rows that show entity ids ("RecipeAethermiteBow", "TechBasicSmithing") with no translation: fabric names were left to Newel's
catalog generator (the Deferred "Localized fabric content"), which Newel no longer plans. The
technology window is a list, not a tree. The skills window is a grid of buttons labelled by tier, so
every skill reads "novice", and nothing shows the professions skills lead to.

The owner wants stations crafted, carried in the hotbar and placed with a ghost; a hand crafting
window and one window per station; a technology tree with lines and zoom; a skill wheel with the
shared skills in the centre and the professions on the rim, each skill placed toward the professions
it belongs to and outward as it grows advanced and unique, with its own page and the player's focus;
professions that unlock titles the player chooses to wear; and gathering skills of their own
(Mining, Woodcutting, Foraging, Skinning) instead of gathering raising crafting skills. The game
has no classes (the constitution's "no hard class system"): professions stay earned from skill
tiers, several at once, and the UI calls them professions.

| Phase | Title | Status |
|---|---|---|
| 267 | Names a player can read: localized names for items, recipes, technologies, skills and professions | Done |
| 268 | Stations are made, carried and placed from the hotbar | Done |
| 269 | Crafting by hand, and at the station | Done |
| 270 | The technology tree: nodes, lines, zoom | Done |
| 271 | The skill wheel: professions around the edge, shared skills in the centre | Done |
| 272 | A skill's own page, and where the player's focus went | Done |
| 273 | Titles: professions unlock them, the player chooses one | Done |
| 274 | Gathering: Mining, Woodcutting, Foraging and Skinning are their own skills | Done |

### Next: sound (Phases 275–)

Agreed with the owner on 2026-11-18. The game had no sound: no files, no playback code, and the options
window's Music and Effects buses were created at runtime because the project shipped no bus layout. The owner
wants a working audio pipeline before any sound art: sounds load from the `.raw` asset tree like every other
asset, every key has a public placeholder, gameplay plays events from a fabric table, and the private assets repo
gets audio style rules, a checker and a SuperCollider source pipeline (its Phases A38 and A39). Real sound art is
not part of the arc. Phase 275 is the contract (keys, layout, manifest section, play API) the rest builds on.

| Phase | Title | Status |
|---|---|---|
| 275 | Audio foundation: a sound loader, an event table, a bus layout and placeholder sounds | Done |
| 276 | First sounds wired in: clicks, windows, footsteps, the dig, pickups, a creature's attack, ambience and music | Done |
| 277 | Sound gaps: other players' footsteps, rock underfoot on cliffs, music on the main menu | Open |

### Next: the third playtest set (Phases 278–290)

Filed by the owner on 2026-11-19 after playing `main` (Phase 251), at high priority. What was found: rocks and
branches on the ground are the same grey box; picking up is on T; the item chosen in the hotbar is not in the
hand; chopping a tree plays no animation; a felled tree squashes into the ground and stays; the top of a tree
can be seen into; hair floats above the head; the grass shows black spots; male and female characters look the
same; fighting looks stiff; the crafting window's icon area is a thin strip; the work bar is drawn half off
screen in the top-left corner and the tutorial never says to hold; digging to rock with the shovel is slow;
mining, digging, building and dissecting have no animation of their own. Each phase names the private art it pairs with (`project-nihon-assets` Phases
A40–A46). The placeholder rule holds: each phase lands with public placeholders and is playable without the art.

| Phase | Title | Status |
|---|---|---|
| 278 | Rocks and branches that look like rocks and branches | Open |
| 279 | Pick up with E | Done |
| 280 | The hotbar item in the hand | Done |
| 281 | Work you can see: chopping, mining, digging, building and dissecting animations | Done |
| 282 | A felled tree falls, then goes | Done |
| 283 | Trees that look like trees: closed faces, a trunk and a real crown | Done |
| 284 | Hair that sits on the head | Done |
| 285 | Grass without black spots | Done |
| 286 | Men and women who look different | Done |
| 287 | Fighting that reads: combos, impact timing and hit reactions | Done |
| 288 | Recipe cards you can read: a real icon area in the crafting window | Done |
| 289 | Hold to work, told and shown: the work bar in view, and the tutorial says hold | Done |
| 290 | Digging that does not drag: a faster shovel on the way to rock | Done |

### Next: the fourth playtest set (Phases 291–296)

Filed by the owner on 2026-11-20 after playing `main` with a friend (Phase 251). What was found: another player is
geometric shapes with a name above them, not a person; other players and creatures move in jumps instead of
walking; every right click moves the mouse pointer up and to the left; the market shows the seller's id, not
their name. And a design decision: there are no tools that cannot be used in combat. Every held item is equipment
of a category (knife, sword, axe, hammer, pick…), and what it can do follows from its traits: Sharp with Blunt
(heavy) fells trees, Piercing with Blunt mines, any knife dissects; picks are the weakest weapons.

| Phase | Title | Status |
|---|---|---|
| 291 | Right-click look puts the cursor back where it was | Done |
| 292 | The market names the seller | Done |
| 293 | Other players look like people | Done |
| 294 | Other players and creatures walk instead of jumping | Done |
| 295 | Equipment categories and traits replace tools (fabric) | Done |
| 296 | Work and combat by trait: no more tools in the game | Done |

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
  **Done** (the fabric PR, `fabric/gameplay/character_roster.js`, `tools/check_character_roster.js`): a `Player`
  entity (the account: friend code, settings, admin flag, last character) and the `CharacterRoster` world system.
  Its `ownership` table puts body, name, HP, position, pack, gear, skills and XP, attributes, research, books,
  taming flags, companions, waystones, clan membership, owned structures and spawn bed on the character, and
  friend code, settings, admin and last character on the player; `recordKeys` says where each key of today's
  `PlayerRegistry` record moves (the check tool scans the runtime so it cannot drift), and `worldKeys` says the
  world sections keyed by player id today (names, clans, structures, chests) key on the character. Limit 4 characters per player per server; a deleted character's structures go to
  its clan, or become ownerless when it has none; names unique per server; delete confirmed by the name typed and
  checked by the host; a pre-226 save becomes each player's first character, whose id is the old player id (the
  player keeps that id too, so the world sections keep resolving; `PlayerIdentityModel` is amended). `PlayerCharacter` gains `playerId`
  and `lastPlayedAt`. The validator pins every ownership field to its owner (inventory or skills on the player fail),
  and rejects a save-record key with no owner or moved onto the player, a limit outside 1–16 and an unknown delete
  policy. The runtime PR adds the `characters.refuse.*` locale rows (en and pt_BR) the fabric's `refusals` name.
- **Runtime:** the registry keys character state by character id. The host refuses a new character
  over the limit, and a new character gets no items, skills, research or memberships from the
  player's other characters. Names stay unique per server across all characters (`name_taken`).
- **Main menu:** after choosing a local world or joining a server, a character list (name, body
  preview, last played) with **Play**, **New character** (the creation screen) and **Delete** (with a
  confirmation typed as the character's name). The host sends the list; the client never decides
  which characters exist.
- Existing saves migrate: each player's one character becomes their first character, unchanged.
- **Done** (the runtime PR): the session's player id is the CHARACTER id, so every slice and world section keeps
  keying on it unchanged; the account is who connects. `src/character/character_roster.gd` is the host's table
  (account → characters oldest first, last character, last played), kept in the world record (`roster`, world
  format 6) and resident in full; `src/persistence/registry_accounts.gd` (`PlayerRegistry.accounts`) resolves a
  join: the claim is an account, the join intent's `character` picks one of its characters (another account's is
  refused with `characters.refuse.unknown` and nothing is bound), else its last; an unknown or busy claim, or a
  later character's id, mints a fresh account whose first character takes the same id. A pre-226 player record is
  adopted on first use (`adopt_legacy`): its id becomes the account and its first character, so names, clans,
  structures and chests resolve unchanged; the world record's `local_player_id` is the local account and
  `local_character` the one it plays. `identity_assigned` carries the `account` the client caches. List actions
  travel as `roster_intent` (`list`, `create`, `delete`; fields capped, 250 ms per connection) and come back as
  `roster` (`GameBus.character_roster_intent` / `character_roster_synced`, `RosterWiring`); a new character has
  no record until entered, when it is placed like any new player; over the limit is `characters.refuse.limit`;
  names stay server-wide (`creation.refuse.name_taken`). Delete compares the typed name (the handle for one never
  named) on the host, refuses one in the world (`characters.refuse.in_play`), drops it from its clan (a founder
  hands the clan to the highest-ranked member, or disbands it alone), gives its private structures, chests and
  doors to that clan or makes them ownerless (a clan lock of no clan: abandoned), frees its name and removes
  its record. Admin follows the account. The menu: a menu join waits for the list before its join intent
  (`NetworkingSlice.awaiting_character`), and a local world that already has a player loads, then waits for the
  local player's choice before binding it (`RosterWiring.local_pending`); a fresh world enters as its first
  character. `src/ui/character_list_panel.gd` lists name, body (body type and hair-colour swatch) and last played
  with Play, Delete (typed confirmation) and New character. Suite `character_roster_tests.gd`; net harness step
  `character_roster`.

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
  **Done** (the fabric PR, `fabric/gameplay/gear_tiers.js`, `tools/check_gear_tiers.js`): the
  `GearTiers` world system. Equipment carries `tier`, which must be its working part's material tier
  (`materialTiers`: Ashite novice, Ferrite apprentice, Aethermite journeyman, Voidite expert, Veilsteel
  master); each crafting station's item carries `tier` (carpentry bench and forge novice, masonry and
  alchemy benches apprentice, arcane forge journeyman, void-shielded workshop expert, master forge
  master). A recipe's `requiredTier` is at most its highest skill guard and its station's tier, and a
  hand recipe is novice. The tool a recipe uses is set by its station (`stationTools`: forges and the
  masonry bench a hammer, the carpentry bench an axe, the alchemy bench none). **Novice is the floor:**
  empty hands and a missing tool count as novice gear, so every novice recipe and ability needs nothing
  and nothing playable today is lost. Combat abilities are listed per combat skill with their weapon
  categories; an ability's tier is its skill rule's tier (Unarmed: the floor). The validator climbs the
  ladder from bare hands and fails on any recipe no reachable tool and station can make, so two hammers
  join the game: the Ferrite Hammer (apprentice, forge) and the Veilsteel Hammer (master, master forge).
  `abilityGaps` lists the abilities no weapon reaches yet (an expert bow, journeyman and expert shields);
  they stay refused until such gear exists. Refusal keys: `GearTiers.refusals`. With hammers at three tiers only, the
  journeyman arcane-forge and expert workshop recipes need the Veilsteel Hammer a smith makes, so an
  arcanist trades for it or learns smithing; journeyman and expert hammers are later content.
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
- **Done** (the runtime PR): `src/character/gear_tiers.gd` reads the `GearTiers` table from `GameData` (item,
  station, recipe and ability tiers; an item's tier is its own `tier`, else `itemTiers`, else its working
  material's). The runtime had no combat abilities before this phase, so it adds the route they travel:
  `GameBus.ability_intent(ability, instance_id, player_id)` (client → host as the `ability_intent` packet, the
  user bound to the connection) and `ability_resolved`. `CombatWiring.on_ability_intent` checks the skill tier
  (`combat.refuse.skill_tier`) and the wielded weapon's tier (`combat.refuse.weapon_tier`; bare hands and another
  skill's weapon are novice) from the host's own records, tells the user why in their locale, and runs an
  accepted ability as a swing through the plain attack checks (the abilities' own effects are later content).
  A worn-out weapon counts as bare hands, as a worn-out tool does for crafting. A hotbar skill box fires the
  highest ability its skill tier and the wielded weapon both reach at the nearest creature, and is dimmed with the
  refusal in its tooltip when the weapon reaches none (redrawn on `held_item_synced` / `equipment_changed`); the
  skill page lists every ability with its tier and what it needs. `CraftingSlice._check_gear_gate` (after the station gate, in `craft` and `can_craft`) refuses with
  `craft.refuse.tool_tier:<category>:<tier>` (best usable item of the station's tool category, worn or carried)
  or `craft.refuse.station_tier:<type>:<tier>` (the host's own record of the nearby station; stations match by
  exact type and the validator keeps `requiredTier` at or below the station's tier, so this refusal is defensive
  until a station can be made at more than one tier); a novice recipe skips both checks; crafting rows and
  cards carry `required_tier` and `tier_needed`. `I18n.reason_text` renders a dotted reason head as its own key
  and tiers through `ui.tier_*`. Suite `gear_tier_tests.gd` covers the criteria.

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
  shape alone, and the surface is clamped so no ground outside the disc lies below it. The basin is
  then carved with Phase 245's terrain CSG helper (revised 2026-11-25, from GDVoxelTerrain's
  composable SDF ops): the ground inside the shore is smooth-subtracted by a bowl (a flattened
  ellipsoid at the lake's depth), and where the rim sits less than a freeboard (fabric, about 0.5 m)
  above the surface it is smooth-unioned up into a low natural levee, so the water always meets a
  sloping bank instead of a wall. A lake whose levee would have to rise more than a fabric maximum
  (about 3 m) is dropped.
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
  sample outside a disc below its surface, and no shore step (adjacent tiles across the waterline)
  over 0.5 m.
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

**Acceptance criteria** (done: `src/player/flight_rules.gd`, `src/tests/suites/flight_tests.gd`; the wall/hillside criterion is proved on the pure collision response and a source audit, since `move_and_slide` does not run in the suite)
- [x] Suite tests on `FlightRules.step`: from rest with W held, the body reaches 95% of top speed in
  0.5–0.8 s of steps. With no input it falls below 5% of top speed in 0.8–1.5 s. W with the camera
  pitched 30° up climbs at sin 30° of the speed (±5%). Opposite input reverses smoothly, never in one
  step.
- [x] A suite test flies a body into a wall and a hillside: no step-up lift, no buried-lift jump, and the
  body ends outside solid ground.
- [x] The playtest `flight` step passes at its current floors.

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

**Implemented** (pure policy in `src/terrain/chunk_stream_policy.gd`; wiring in `chunk_build_queue.gd`): the
lead is `ceil(speed × 1.5 s / 32 m)` chunks, capped at 6, queued in a 45° cone along the body's
velocity; the steady worker cap starts at half the cores and moves once a second inside
[2, cores − 1]; `apply_finished_builds` stops at `ATTACH_BUDGET_MS` (3 ms) except for the chunk under
the body; the ground surface of a chunk is a `ChunkSurface` (RenderingServer mesh and instance) when
`VoxelBuild.render_server_surfaces` is on (the game, not the suite's rigs). The `flight` step is gated
by CI's playtest run; no release-build numbers were recorded in this PR.

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
- **Carving the bake into the ground** (added 2026-11-25, after the GDVoxelTerrain review): rivers
  are not only painted on the interpolated macro height. The runtime subtracts each baked river from
  the ground as a chain of capsules along its polyline (radius from flow, depth from width) with a
  smooth subtraction, so a river runs in a channel with soft banks at any detail-noise height. The
  maths lives in one terrain CSG helper, `src/terrain/terrain_csg.gd` with a native twin on the
  Phase 248 base: union, subtraction, intersection and their smooth (polynomial `k`) forms, as in
  GDVoxelTerrain's `sdf_operations.h` (MIT; notice in the file and a row in `native/THIRD_PARTY.md`),
  over 2D distance shapes (disc, capsule, polyline, box) for height fields and 3D shapes (sphere,
  cylinder, box, capsule) for run columns, in fixed point. Phases 232 (lake basins), 300–301 (dig and
  shape brushes) and 235 (road cut and fill) reuse it.
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
- Suite tests on the carve: along 50 baked river segments the ground at the centreline lies below the
  water surface and no bank step between adjacent tiles exceeds 0.5 m; `terrain_csg` matches reference
  values for each operation (including `k` → 0 equal to the sharp form), and its GDScript and native
  results are identical.
- A suite test: a client with a corrupted bake file (wrong hash) refuses it and bakes or re-downloads.
- CI publishes the bake for the fabric seed, and the playtest `travel`, `far_peak` and `pole` steps
  pass on it.

## Phase 247 — Ground cover: grass and bushes by biome, culled by distance

Trees use `multimesh_pool.gd` and impostors (Phase 23). Natural ground has no grass or bushes.

- Ground cover per biome in the fabric (separate PR): plant kinds, density, and the terrain materials
  they grow on (grass on grass, none on rock or snow). Each kind also carries the placement filters of
  GDVoxelTerrain's `JarTerrainPopulator` (revised 2026-11-25): a slope range (from the mesh normal),
  an altitude band, a scale range and whether it aligns to the surface normal (grass does, bushes stay
  upright).
- A dug, filled or flattened surface (Phases 300–301) shows soil or rock, not the biome's surface
  material, so nothing grows on it: the material filter reads the drawn vertex's dominant weight.
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
  or a placed block, nor on a slope or altitude outside its kind's range, nor in a fresh dig (Phase
  300), and density falls with distance.
- The playtest `walk` and `flight` steps meet their budgets with ground cover on.

## Phase 300 — Digging with a brush: one dig moves a shovelful, not a slab

A mine removes one `STEP_HEIGHT` slab of one 0.5 m tile (`VoxelEdit._mine_span`). Digging a cellar, a
ditch or a cave is hundreds of holds, each yielding one unit, and on the smooth mesher a slab is hard
to see. GDVoxelTerrain (see the [arc](#arc-digging-worth-doing-phases-300301)) treats a dig as one
brush op; this phase does the same on top of the run columns.

- **A dig is a brush op:** `{ shape, centre, radius, op, k }`. The shape is a sphere, a vertical
  cylinder or a box from Phase 245's `terrain_csg`; the centre is the ray hit pushed half a radius into
  the ground along the hit normal and quantised to the tile and `STEP_HEIGHT` grid; `k` is the smooth
  blend, so the rim eases out instead of ending in a cliff. A side hit carves sideways, so a cliff
  face gives a tunnel and a hole in the floor gives a pit.
- **Rasterised into the runs, nothing new stored:** the host walks every tile the brush bounds touch,
  intersects the shape with the column and appends the `remove` spans it cuts (quantised to
  `STEP_HEIGHT`) through `_append_edit`, batched with `_compact_if_long`. The op logs, compaction, the
  stable-world rule, the chunk-cache revisions, the save format and `settle` (loose ground over a new
  hole) are unchanged. Placed blocks are never cut: the brush clips to natural spans, and Phase 205's
  ownership rules still decide any mine of a placed block. Bedrock, closed sites and the newcomer
  grounds rules clip or refuse as they do for a single slab.
- **One op on the wire:** the client sends one dig intent; the host resolves it and broadcasts the op
  (Phase 256's binary format). Every peer rasterises the same op over the same runs, so the logs are
  identical, and Phase 263's prediction applies the whole brush at once. The rasteriser has a
  GDScript reference and a native port with a parity test.
- **Yield by volume:** the removed volume is summed per material: the biome's soil within
  `topsoilDepth`, host rock below it, and Phase 43's vein material where the ore field has one
  (depletion recorded per vein as now). Quantity is the volume over the fabric's unit volume per
  material, which defaults to one slab (0.03125 m³) so today's recipe and trade quantities keep their
  meaning; the remainder is kept per player and material (saved with the player), so many small digs
  yield the same as one big one.
- **Tools decide the brush** (fabric, separate PR): each digging tool has a shape, a radius and the
  materials it cuts. Bare hands: a small sphere in soil and sand only. A shovel: a larger sphere,
  soil, sand and gravel, the fastest per m³. A pick: a smaller sphere that also cuts rock and ore. A
  material the held tool cannot cut stays, so a shovel dig into a rock face stops at the rock.
  Work time (Phase 259) scales with the volume removed and the Mining skill; skill levels may grow the
  radius up to a fabric cap.
- **Trust boundary:** the host recomputes the brush from its own copy of the tool, skill and runs and
  ignores any shape or radius the client sends; one brush per completed work hold, rate-limited like
  mines today; the radius is capped in the fabric and by a validator.
- The old single-slab mine remains as the brush's smallest case (radius under one tile), so a player
  can still trim one step.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass. A `tools/check_dig_brush.js` rejects a tool brush over
  the radius cap and a brush that names a material that is not a terrain material.
- Suite tests: a sphere dig of radius 1 m on flat ground removes a volume within 5% of a half sphere;
  no column outside the brush bounds changes; a placed block inside the bounds is untouched; the cut
  stops at `BEDROCK_DEPTH`; a shovel dig into rock removes no rock; a side dig into a cliff leaves a
  roof run above the hole.
- Suite test: yield conservation — 20 small digs and one large dig of the same total volume yield the
  same quantity per material, and an ore vein's reserve falls by what was yielded.
- Suite test: the GDScript and native rasterisers produce identical op logs for 200 random brushes on
  the pinned seed.
- A `tools/net_harness.sh` step: a client digs with a shovel; the host and the second client hold
  identical runs for every touched tile.
- The playtest `mine` step digs a 1 m deep pit 1.5 m wide with a stone shovel in at most 6 holds and
  meets its budget.

## Phase 301 — Shaping the ground: fill, flatten and smooth, and a dug surface that shows what it is

Phase 300 removes ground; building needs the other half. GDVoxelTerrain also paints the edit's
material onto what it touched, which is what makes a dig read as a dig.

- **Fill:** smooth union of the brush with the ground, spending the carried loose material (soil,
  sand, gravel) by volume, at the same unit volume as Phase 300's yield. The added spans are natural-
  ground spans of that material (not placed blocks), so they mesh smooth and can be dug again.
- **Flatten:** the first hit sets a target plane; each hold removes ground above it and fills below it
  within the brush; what it removes yields as a Phase 300 dig, and the fill is paid from the
  inventory as above. Roads (Phase 235) and the tower's
  levelled ground (Phase 213's step) use it.
- **Smooth:** each hold relaxes the column tops in the brush toward their neighbours' mean, conserving
  volume (what one column loses its neighbours gain, so nothing is created), in whole `STEP_HEIGHT`
  steps. Like the dig, it moves natural spans only: a placed block neither moves nor takes ground.
- **A dug surface shows what it is:** `terrain_weights` reads, per vertex, how deep the exposed run
  top lies under the column's natural surface: within `topsoilDepth` it weighs the biome's soil
  material, below it the host rock, and on a vein its ore tint; a filled span shows its own material.
  The biome's surface material (grass) shows only on untouched natural ground, so a fresh pit is a
  brown hole with stone at its bottom. Phase 247 grows nothing on it.
- All three ops go through Phase 300's rasteriser, wire op, prediction and host checks; the fabric
  gives each tool the ops it can do (a shovel all three, a pick none of them).

**Acceptance criteria**
- `npm run validate` and `check-drift` pass, and Phase 300's validator covers the new ops.
- Suite tests: a fill spends exactly the inventory volume it adds and is refused with too little in
  the pack; a flatten leaves every column in the brush within one `STEP_HEIGHT` of the target plane;
  a smooth changes no total volume (sum of column heights) and lowers the largest step in the brush.
- Suite tests: on a column dug 1 m into a biome with `topsoilDepth` 3 the exposed vertex's dominant
  weight is the soil material; dug 4 m it is the host rock; an untouched column keeps the surface
  material; a filled column shows the fill material.
- A `tools/net_harness.sh` step: a flatten from one client gives identical runs on the host and the
  other client.

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
- 2026-11-20: the first session with a second player, filed as Phases 291–296 (after 287 in the priority
  order). Findings: other players are drawn as shapes, not people; other players and creatures jump instead of
  walking; a right click moves the pointer up-left; the market shows the seller's id. The owner also dropped
  the tool concept for equipment categories and traits.

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

## Phase 271 — The skill wheel: professions around the edge, shared skills in the centre

The skills window is a grid of buttons labelled by tier ("novice"), not by skill. The game has no
classes: the rim shows the professions (Blacksmith, Arcanist, Ranger and the rest), which a player
earns from skill tiers and can hold several of. There is no `Novice` entity; the centre is where the
skills anyone uses sit, with no label.

- **Fabric (separate PR):** each skill and each tier unlock it grants (recipes, abilities and passive
  bonuses already in the fabric; a tier with nothing to show gets a passive bonus in the same PR)
  becomes a node with an **affinity** per profession (derived from the professions' `relations`,
  overridable in the fabric; a skill no profession names has none) and a **depth** from 0 (anyone's)
  to 1 (unique to a profession, advanced). A validator rejects affinities that sum to neither 0 nor
  1, an affinity to an unknown profession, or depth that does not grow along a skill's tiers.
- **Layout as a pure function:** professions sit on an outer circle, evenly spaced. A node's angle is
  the affinity-weighted mean of its professions' angles, and its radius grows with depth, so an
  advanced, blacksmith-only smithing passive sits next to Blacksmith on the rim while a skill shared
  by Blacksmith and Warrior sits between them, nearer the centre. A node with no affinity sits in the
  centre disc. Lines join a node to the node it requires.
- **Drawing:** each node shows the skill's localized name (never the tier), an icon and a state
  (unlocked, available, locked); each profession on the rim shows its name, icon and state (locked,
  active, mastered). Zoom and pan as in Phase 270.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; the validator's self-check rejects affinities that sum
  to neither 0 nor 1, an unknown profession and a depth that decreases along a skill.
- Suite tests: the layout is identical across runs; a node with all affinity on one profession lies
  on that profession's ray; a deeper node of the same profession lies farther from the centre; nodes
  with no affinity lie inside the centre disc; no node label equals a tier name or an entity id.
- Every new string is in both locales.

## Phase 272 — A skill's own page, and where the player's focus went

- **Details window:** selecting a skill node opens its page: name, description, level and XP with a
  bar to the next level, what the next tiers unlock (passive or active), what trains it (the work
  kinds of Phase 207 and the recipes, creatures or materials that give it XP), the professions it
  leads to, and the player's focus on it with the bonus it gives now.
- **Focus:** the host counts, per player and per skill, the **active minutes** in the last
  `FocusWindow` of play time (fabric, default 1 hour): a minute counts for a skill when the player
  earned host-granted XP in that skill during it (one minute can count for several skills). It is
  play time, not wall-clock time: time logged off neither adds focus nor ages it. Minutes older
  than the window drop out.
- **The dedication bonus:** XP granted in a skill is multiplied by
  `1 + maxBonus × activeMinutes(skill) / windowMinutes` (fabric, default `maxBonus` 0.25), so one
  straight hour on one skill earns +25% in it and half an hour earns +12.5%. It is a bonus only: a skill
  with no focus earns the normal rate, never less, so trying something new costs nothing. The host
  applies it once, in `grant_skill_xp`, so every XP source gets it and none gets it twice.
  `grant_skill_xp` takes whole XP and many grants are 1 or 2, so the bonus's fraction is carried per
  player and skill (persisted with focus) and paid when it reaches a whole point, instead of being
  rounded away.
- **Display:** the details page and the wheel's centre show focus as shares by skill, grouped by the
  skill categories (combat, crafting, magic, exploration, social, gathering; Phase 274), so a player who spent
  the evening forging sees Smithing lead and the Blacksmith side of the wheel light up.
- A newly unlocked node pulses on the wheel and the toast (Phase 260) opens its page.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass with `FocusWindow` and `maxBonus` in the fabric; the
  validator rejects a negative bonus and a window of zero.
- Suite tests: the page's level and XP match the skill state; a minute with XP in a skill counts once
  for it; minutes older than the window drop out and time logged off does not age them; the
  multiplier is 1 with no focus, `1 + maxBonus` with a full window on one skill and never below 1; a
  grant is multiplied exactly once; 100 grants of 2 XP at +25% pay exactly 250 XP (the fraction is
  carried); focus is synced only to its own player; an unlock emits the toast
  that opens its page.
- Every new string is in both locales.

## Phase 277 — Sound gaps: other players' footsteps, rock underfoot on cliffs, music on the main menu

Phase 276 wired the first sounds but left three gaps the owner wants closed (agreed 2026-11-18). Each one uses
the event table and the `Sound` API from Phase 275 as they are; new events get placeholders through
`tools/gen_placeholder_audio.py`.

- **Other players' footsteps:** a remote player walking on the ground plays the same `footstep.<surface>` events
  as the local player, at that player's feet, with the same step cadence (`step_due`, one step per 1.6 m) driven by
  the synced position, not by local input. Steps beyond the event's `maxDistance` from the listener are skipped
  before any player node is made. A teleport or a correction snap does not count as distance walked.
- **Rock underfoot on cliffs:** where the ground under the feet is steeper than a slope threshold set in the
  fabric `footsteps` table, the surface is `stone` whatever the biome's ground material, so a cliff sounds like
  rock. The threshold and the override live in the fabric, not in code.
- **Music on the main menu:** the main menu plays a music track on the Music bus (a new `music.menu` event or
  `music.main_theme`, as the fabric decides) and cross-fades into the in-world music when a world loads. Leaving to
  the menu cross-fades back: today `AudioWiring.unwire` (run when the world's root is freed for the menu) cuts the
  music and ambience at once, so this phase replaces that cut with a fade into the menu track. The dedicated server
  still plays nothing.

**Acceptance criteria**
- `npm run validate`, `check-drift`, `node tools/check_sounds.js` and `python3 tools/gen_placeholder_audio.py
  --check` pass; the validator rejects a slope threshold outside 0–90°.
- Suite tests (through `Sound.trace`, not audible output): a remote player walking 3.2 m on grass fires two
  `footstep.grass` events at its position; a remote player beyond `maxDistance` fires none; a teleport fires none; a
  step on a slope above the threshold picks `stone`, one below keeps the biome surface; the menu starts its track
  and loading a world cross-fades to the world track; leaving to the menu fades back to it
  instead of cutting; a server boot plays nothing.
- Net harness step: the second client hears (traces) the first client's footsteps.
- No new user-facing strings, or every new one is in both locales.

## Phase 278 — Rocks and branches that look like rocks and branches

Owner's playtest, 2026-11-19: loose stones and branches on the ground both look like the same grey box. The cause
is in `src/world/loose_item_slice.gd` (~363–383): every kind shares one `BoxMesh` (0.35×0.18×0.35) in one
MultiMesh, and the per-instance colours (brown, grey) never show because no material sets
`vertex_color_use_as_albedo` (the tree pool does, `src/core/multimesh_pool.gd`). Meshes for both already exist at
`models/items/Branch.glb.raw` and `models/items/LooseStone.glb.raw` and are not used.

- One MultiMesh per loose kind, its mesh taken from the kind's item model (`AssetOverlay.item_model_key`), so a
  branch is a long thin stick and a stone a lump. The box stays only as the fallback when a key fails to load, and
  the fallback gets the vertex-colour material so the two kinds at least differ in colour.
- Each instance gets a yaw and a small scale jitter (0.85–1.15) seeded by its cell, so a field of them does not
  repeat; the jitter is deterministic, so host and client agree, and the pick-up ray still uses the logical
  position.
- Up to three variants per kind (`models/items/<Id>_v<n>.glb.raw`, n = 1..2, optional) are chosen by the same
  seed when present; placeholders for each variant key land with this phase. Art: assets Phase A40.

**Acceptance criteria** (done: `look_at_tile`, `variant_keys`, `loose_mesh` and `redraw` in `src/world/loose_item_slice.gd`, `VARIANT_ITEMS` in `tools/gen_item_assets.py`, `src/tests/suites/loose_item_visual_tests.gd`)
- [x] Suite: the loose-item renderer builds one MultiMesh per kind present, with the kind's model mesh (not a
  `BoxMesh`) when the key loads; with a missing key it falls back to the box and the material has
  `vertex_color_use_as_albedo`; the same cell gives the same yaw, scale and variant on two builds; a variant key
  that is absent is never picked.
- [x] Suite: every loose kind in the fabric has a placeholder model at its key, and every variant key has one.
- [x] Playtest bot `tutorial` step still passes: it picks up a branch and a loose stone (`_pick_loose`), and
  pick-up by aim is unchanged.

## Phase 279 — Pick up with E

Owner's playtest, 2026-11-19: picking up is on T (`PICK_KEY := KEY_T`, `loose_item_slice.gd:26`) and should be on
E, the key most games use. Bare E today toggles all equipment on and off (`player_slice.gd`, "inspect the naked
body"), and both keys are in `Hotbar.RESERVED_KEYS`.

- Picking up moves to E. The equipment toggle moves to T (the freed key). Both stay reserved for hotbar boxes.
- The keys become input-map actions in `project.godot` (`pick_up`, `toggle_equipment`) instead of hard-coded
  key codes, so later rebinding (an options-window task) has something to rebind. The handlers read the action,
  not the keycode, and still ignore Alt+letter window shortcuts and focused text fields (Phase 219).
- Every on-screen hint that names the key (`src/ui/input_labels.gd`, tutorial texts, the help overlay) reads it
  from the action, so no text says "T" for picking up. Locale strings that embed the letter take it as a param.

**Acceptance criteria** (done: `pick_up` / `toggle_equipment` in `project.godot`, `InputLabels.is_bare_action_press` in `src/ui/input_labels.gd`, `src/tests/suites/pick_up_key_tests.gd`)
- [x] Suite: an E press with a pickup in reach emits the pick-up intent; a T press emits the equipment toggle; E in a
  focused text field does neither; Alt+E still opens the inventory and does not pick up.
- [x] Suite: no `KEY_T` or `KEY_E` literal remains in the pick-up or equipment-toggle handlers (a source audit like the
  existing ones); the input labels for `pick_up` and `toggle_equipment` resolve to E and T.
- [x] Playtest bot `tutorial` step passes with E (its `_pick_loose` helper presses `KEY_T` today; it moves to
  the key bound to the `pick_up` action, not a literal).
- [x] Locale check: no new string in one locale only.

## Phase 280 — The hotbar item in the hand

Owner's playtest, 2026-11-19: putting an item in the hotbar and selecting it shows nothing in the character's
hand. Today `hotbar.selected_item()` only feeds station placement; held meshes exist only for worn equipment
(`CharacterSlice._attach_equipment`, Phase 153, `socket_weapon_r/l`).

- The selected hotbar slot is the held item: its model (`AssetOverlay.item_model_key`, the box fallback when absent)
  is attached to `socket_weapon_r`, replacing the main-hand equipment mesh while the slot holds something other
  than the equipped main-hand item; an empty slot shows the equipped main hand (or nothing).
- Two-handed carries and stations (Phase 268) keep their own pose; a station in the slot shows its carried
  form in both hands, not a full-size station.
- The held item is shown to other players. The hotbar is client-side UI (`src/ui/hotbar.gd` `slots` holds item ids,
  saved locally), so the host has no slot to check: the client sends the selected item id (or empty), and the host
  checks the player holds at least one of it in their inventory and that it is holdable (an item, not a skill
  entry), rate-limits changes, and syncs the held item id to peers in range. The host re-checks on inventory
  change: when the held item leaves the inventory, the host clears it and syncs empty (trust boundary).
- `RigTree.attack_clip_for` and the work swing (Phase 281) read the held item, so a pick held from the hotbar
  swings as a tool.
- Each item's grip (offset and rotation at the socket) comes from the item's model (a `grip` node when present,
  else the model origin); no per-item offsets in code. Art: the item meshes exist (assets A8, A11, A21, A34).

**Acceptance criteria**
- Suite: selecting a slot with an item attaches that item's mesh under `socket_weapon_r`; selecting an empty slot
  restores the main-hand equipment mesh; a missing model key gives the box fallback; switching slots frees the old
  mesh (no orphans); a `grip` node offsets the mesh.
- Suite (host): a held-item message naming an item the player does not have, an unknown id or a skill entry is
  refused and syncs nothing; more changes than the rate limit in a second are dropped; dropping or using up the
  last held item syncs empty.
- Net harness step: client B sees client A's held item id change when A selects another slot.

## Phase 284 — Hair that sits on the head

Owner's playtest, 2026-11-19: hair looks like it floats above the head. Hair meshes are parented to a
`BoneAttachment3D` on the `Head` bone at the bone origin with no fit (`avatar_builder.gd` ~44–70), so the fit
depends on each glb's origin matching the head, and the head size differs by body and proportion sliders.

- Each head mesh carries a `hair_anchor` node (scalp top) and each hair mesh a matching `anchor` node; the builder
  places the hair so the two coincide. Missing nodes fall back to today's placement.
- The hair is scaled with the head when proportion sliders change head size, so a bigger head does not poke
  through or leave a gap.
- A suite check measures the gap between each hair's inner surface and the head's scalp for every hair × head
  pair and fails above 1 cm (or any head vertex outside the hair's inner shell in its covered region, above 0.5 cm).
- Placeholders for heads and hair gain the anchor nodes. Art: assets A43 rebuilds hair to the scalp.

**Acceptance criteria**
- Suite: for every hair id and head id (placeholders), anchors coincide after attach (≤ 1 mm); the measured
  scalp gap is ≤ 1 cm; with head scale 1.2 the gap stays ≤ 1 cm.
- Suite: a hair glb without an `anchor` node attaches as before (no crash, logged once).
- Character creation tests (Phase 180/181) still pass.

**Done (placeholders).** The chibi heads and bodies carry `hair_anchor` (scalp top, under the Head bone) and every
hair mesh an `anchor`; `AvatarBuilder.attach_hair` fits by them (`fit_transform`) when the rig scene has a head
anchor and keeps the old placement otherwise (logged once per style). The hair sits on the Head bone attachment,
so it grows with a scaled head. The default `player_rig` has no head anchor until the art of assets A43 lands.

## Phase 285 — Grass without black spots

Owner's playtest, 2026-11-19: the grass ground texture shows black spots. First suspect, on the art side: the prod
`grass_albedo` may carry near-black texels that mipmaps spread (assets A44); check the prod map and its mipmaps
before changing the shader. In `src/terrain/terrain_material.gdshader` the blend sum cannot reach zero from dark
texels: the layer with the highest `height[i]` always adds `b = blend_depth`, so `sum >= blend_depth`. The shader
can still draw black or NaN where `blend_depth` is set to 0 (`col / sum` with `sum == 0`), where the blended
normals cancel (`normalize(nrm)` of a zero vector), and where every layer weight is at or below 0.002 (all
heights −1, `col` stays zero, black albedo); a vertex with total weight under 0.01 takes the vertex `COLOR` path
instead, so a dark vertex colour there also shows as a dark spot.

- The shader guards both divisions (`max(sum, 1e-4)`, a fallback normal when the length is near zero) and never
  outputs NaN; when no layer passes the 0.002 cut, the largest-weight layer is used alone instead of black.
  `blend_depth` is clamped above zero (`hint_range` minimum > 0).
- The blend height comes from a per-layer height value (the albedo luminance remapped and clamped to a floor per
  layer in the fabric `terrain_material` entity), not raw brightness, so no layer's dark texels all lose at once.
- A GDScript mirror of the blend (`terrain_weights.gd` already mirrors the vertex side) computes the pixel weights
  for tests.
- The terrain map loader rejects (logs and uses the placeholder) a map whose mean luminance or darkest-1% texels
  fall below fabric-set floors, so a broken prod map cannot ship black ground.

**Acceptance criteria**
- `npm run validate` / `check-drift` pass with the height floors; the validator rejects a floor outside 0–1.
- Suite: the GDScript blend mirror returns finite weights summing to 1 for zero vertex weights, all-black
  albedo and a zero normal, and picks the largest-weight layer when every weight is at or below 0.002; the shader
  source contains the two guards and a `blend_depth` minimum above zero (source audit).
- Suite: a synthetic map whose darkest 1% is black is rejected by the loader and the placeholder used; the public
  grass placeholder passes.

**Done.** Fabric `heightFloor`, `minMeanLuminance` and `minDarkLuminance` per terrain material (validated 0–1,
`tools/check_terrain_materials.js`); the shader floors the blend height per layer, guards both divisions and the
normal, always draws the heaviest layer and has `blend_depth` as `hint_range(0.01, 1.0)`; `src/terrain/terrain_blend.gd`
mirrors the blend; `TerrainMaterial.checked_albedo` refuses a dark map for the placeholder. The art-side check of
the production `grass_albedo` (assets A44) stays with the assets repo.

## Phase 286 — Men and women who look different

Owner's playtest, 2026-11-19: male and female characters look the same. Every body uses one rig mesh
(`DEFAULT_RIG_KEYS`); the body id only picks texture sheets. `chibi_body_m/f` and `chibi_head_m/f` exist but only the
creation tests load them; the fabric presets differ only slightly (height 0.75 vs 0.8, shoulders 0.95 vs 1.0).

- The body type picks its own body and head meshes on the shared skeleton and clips: `models/characters/bodies/
  <id>.glb.raw` and `heads/<id>.glb.raw` are attached by `attach_rig` for the character's body and head ids, the
  single rig mesh staying as the fallback.
- The shapes differ in a way the stylised (chibi) look can carry, readable at gameplay distance: the male has
  broader shoulders, narrower hips, a thicker neck, a squarer jaw and a heavier brow; the female has narrower
  shoulders, wider hips, a narrower waist, a modest bust, a softer jaw and longer lashes. Non-sexualised, matching
  the game's style guide.
- The fabric presets widen the default proportion gap (shoulder and hip width, height) and the sliders keep
  working on both bodies. The clips stay shared; the walk can take a per-body
  hip-sway weight from the fabric.
- Placeholders for both bodies and heads are regenerated with those differences measurable. Art: assets A45.
- Equipment (Phase 153) still fits both bodies: socket positions come from each body's skeleton pose.

**Acceptance criteria**
- Suite: a male character attaches `chibi_body_m` and a female `chibi_body_f` (placeholders); the attached meshes
  differ; measured on the placeholders, the male's shoulder/hip width ratio is at least 15% above the female's.
- Suite: every equipment slot's socket exists on both bodies; a chestplate attaches on both.
- Character creation and playtest `create`/`character_sheet` steps pass; the doll renders each body.

**Done (placeholders).** `AvatarBuilder.rig_key` picks `models/characters/bodies/<body>.glb.raw` when the manifest
lists it (the single rig stays the fallback); that body has no head of its own, so `attach_head` puts
`heads/<head>.glb.raw` on the Head bone. Male: broad shoulders, narrow hips, thick neck, square jaw, heavy brow.
Female: narrow shoulders, wide hips, narrow waist, modest bust, soft jaw, lashes. Presets widened (male height 0.85,
shoulders 1.1; female height 0.75, shoulders 0.9, the slider bounds). The optional per-body walk hip-sway weight is
not done. The playtest `create`/`character_sheet` steps need a display and run in CI.

## Phase 287 — Fighting that reads: combos, impact timing and hit reactions

Owner's playtest, 2026-11-19: fighting animation could be much better. Today one clip plays per attack, picked by
the main-hand item (`RigTree.attack_clip_for`: `attack_unarmed`, `attack_tool`, `attack_1h`), with no variation,
no link between the clip's strike and the damage, and the target barely reacts.

- Combos: repeated attacks within a window cycle through variants (`attack_1h`, `attack_1h_2`, `attack_1h_3`;
  `attack_unarmed`, `attack_unarmed_2`; two-handed weapons get `attack_2h`, `attack_2h_2`). The chain table
  (clip order, window, per-step damage multiplier and timing) lives in the fabric; a missing variant falls back
  to the base clip.
- Impact timing: the host resolves the hit at the clip's `impact` marker time (from the fabric table, which
  mirrors the asset's marker), not at the click; the client plays hit effects and sound at the same frame.
- At impact the host re-checks everything it checked at the click, with the state at impact: attacker and target
  both alive, target in range of the attacker's current position, and the damage from the weapon and combo step
  the swing started with (switching weapon mid-swing cancels it). The pending hit is cancelled if the attacker
  dies, is staggered, or starts another action before impact; a cancelled hit deals nothing and sends no hit sync.
- Upper-body attacks: attacking while moving plays the attack on the upper body over the walk/run (a bone-mask
  blend from the spine up), so the feet keep moving.
- Hit reactions: a struck player or creature plays `hit` (light) or `stagger` (heavy, past a damage share set
  in the fabric), with a short knock-back direction away from the attacker; a block/parry clip is out of scope.
- A short camera shake and a 40 ms hit-stop on the attacker's client for a landed hit, both switchable in the
  options window (new keys in both locales).
- New clip keys get placeholders on the public `player_rig` first. Art: assets A46.

**Acceptance criteria**
- `npm run validate` / `check-drift` pass with the chain table; the validator rejects a chain step naming a clip
  outside the rig contract, or an impact time outside 0–1.
- Suite: three attacks inside the window play `attack_1h`, `attack_1h_2`, `attack_1h_3`; a pause past the window
  restarts at the first; a rig without a variant plays the base clip.
- Suite (host): damage is applied at the impact time, not before; a hit above the stagger share plays `stagger`
  on the target, below it `hit`; the knock-back points away from the attacker.
- Suite (host): a target that leaves range before impact takes no damage; a target that dies before impact takes
  no further hit; an attacker who dies, is staggered or switches weapon before impact deals nothing.
- Suite: attacking while walking keeps the lower body on `walk` (blend mask applied).
- Playtest bot `fight` step passes and records the clip sequence.

**Done.** Fabric `CombatCombos` (validator, `tools/check_combos.js`, CI step); `combo_chain.gd` (variants, window,
fallback); `pending_hit.gd` + `BattleSlice.tick_impacts` (the host deals a player swing at the clip's impact time
after the re-checks (alive, not immobilised or staggered, not carrying a body, target living, untamed and in reach by exact
positions); the swing clip plays at the click and a click during a swing in flight is ignored); hit/stagger by the
fabric share, with the struck creature pushed `knockbackLight`/`knockbackHeavy` metres away (`CombatWiring.push_struck`; a
player's body is moved by its own client);
the bone-masked `UpperAttack` one-shot; `HitFeel` camera shake and hit-stop with the `camera_shake` / `hit_stop`
options (both locales); the playtest `fight` step records the clip sequence and waits out each impact. The host
announces a swing to clients in range at the click (`combat_hit` outcome `swing`), so observers see it then.

## Phase 288 — Recipe cards you can read: a real icon area in the crafting window

Owner's playtest, 2026-11-19: the crafting window does not show the items to craft properly; the part with the
item icons is too thin. In `src/ui/craft_window.gd` the card grid sits in a `ScrollContainer` with
`SIZE_EXPAND_FILL` and no minimum height, sharing the window's height with the search field, the tabs and the
detail panel below, so the detail takes the space and the grid shrinks to a strip. Each card is a 92×76 `Button`
with `expand_icon`, so the icon gets what is left of 76 px after the text line (11 px font) and shrinks further
when the name wraps.

- The card grid gets a minimum height of at least two full card rows, and the window's minimum size grows to fit
  it; the detail panel scrolls on its own instead of squeezing the grid.
- A card is a fixed layout, not a `Button` icon: a square icon area of at least 56×56 px (`TextureRect`,
  `STRETCH_KEEP_ASPECT_CENTERED`), the name under it on up to two lines with ellipsis, and the count badge in a
  corner. The selected card has a visible border; a card that cannot be crafted is dimmed but its icon stays
  readable. Applies to the hand window and the station windows (Phase 269), which share the class.
- The column count follows the window width (cards keep their size; a wider window shows more columns), so a
  resized window never squeezes the icons.
- The detail panel's input icons grow from 24 to 32 px.
- No new user-facing strings, or every new one is in both locales.

**Acceptance criteria** (done: `src/ui/craft_window.gd`, `src/tests/suites/crafting_window_tests.gd`, the bot's `craft` step)
- [x] Suite: a hand window built with the default size has a grid area at least two card rows tall; every card's
  icon rect is at least 56×56 px and square; with a long localized name the icon rect keeps its size; the
  column count is the most cards (with the grid's separation) that fit the grid's width, at three window widths.
- [x] Suite: a station window (Phase 269) gets the same card layout; the detail panel's input icons are 32 px.
- [x] Playtest bot `craft` step screenshot is taken with the window open and the step checks the card icon sizes.

## Phase 290 — Digging that does not drag: a faster shovel on the way to rock

Owner's playtest, 2026-11-19: digging with the shovel takes too long, so getting through the soil to the rock the
tutorial asks to mine (`tutorial.mine_stone`) is slow. Today (`fabric/gameplay/work_times.js`) soil is 0.8 s and
grass 0.6 s at speed 1.0, the stone shovel works at 0.6 (1.33 s a soil block), and each block is a separate host
round trip with its own bar.

- Digging soil is about twice as fast with the first shovel: the stone shovel's `shovel` speed goes from 0.6 to
  1.2. The stone shovel is the only shovel today; a later (forged) shovel must work at 1.2 or more, and the
  work-time validator rejects a shovel slower than the stone one. Soil, grass, sand and snow base times are left
  as they are, so bare hands and the pick are unchanged.
- A dig hold carries on to the next soil block under the crosshair without a gap: the next target's
  `work_start_requested` is sent when the current one completes, not on the next frame after the host answers,
  so a trench feels like one continuous dig.
- The tutorial area keeps the rock close under the surface: `tutorial.mine_stone` completes on one Ferrite
  gathered (Ferrite is the host rock of most biomes, `ore_field.gd`), and within 16 m of the newcomer-grounds
  spawn (Phase 261) the Ferrite under the soil is at most 2 blocks down. This is checked against world-gen, not
  made by changing it, so there is no `WORLDGEN_VERSION` bump. If world-gen does not give it, the step's target
  marker points to the nearest exposed Ferrite face within 30 m instead.
- The work-time table records the change in its comment (Phase 290) so the balance history stays readable.

**Acceptance criteria**
- `npm run validate` / `check-drift` pass; `tools/check_work_times.js` still rejects bad tables.
- Suite: the host's dig duration for a soil block with a stone shovel at Mining novice is at most 0.7 s; bare
  hands and pick durations on soil and rock are unchanged.
- `tools/check_work_times.js`: a table with a shovel slower than `StoneShovel` is rejected.
- Suite: on the pinned playtest world, either every column within 16 m of the newcomer spawn has Ferrite at
  most 2 blocks under the surface, or the `mine_stone` step's marker names an exposed Ferrite face within 30 m.
- Playtest bot `tutorial` step completes the dig and mine-rock steps within a time budget set from the new
  speed (dig-to-rock under 5 s of holding).

## Phase 291 — Right-click look puts the cursor back where it was

Owner's playtest with a second player, 2026-11-20 (Phase 251): every right click moves the mouse pointer up and to
the left. Cause: `PlayerSlice._begin_look` stores `get_viewport().get_mouse_position()`, which is in the root
viewport's coordinates, and `_end_look` hands it to `Input.warp_mouse`, which takes window pixels. With
`window/stretch/mode="canvas_items"` the two differ by the stretch scale whenever the window is larger than the
base size, so the pointer lands closer to the top-left corner on every release, by more the larger the window.

- Store and restore the pointer in one coordinate space: read the window position (`DisplayServer.mouse_get_position`
  minus the window position, or `get_window().get_mouse_position()`) and warp to it, or convert the stored viewport
  position through the root viewport's final transform before warping. One helper does the conversion; nothing else
  calls `warp_mouse` with a viewport position.
- The same fix covers every other `warp_mouse` call (grep finds them), and the cursor is not moved at all when the
  look ends because the window lost focus.
- A right click that never becomes a look (pressed and released with no motion) leaves the pointer exactly where it
  was.

**Done.** `src/player/pointer.gd` is the only `warp_mouse` caller: it converts the stored viewport position through
the viewport's final transform and does not warp when the window lost focus. The suite checks the round trip at
scales 1.0/1.5/2.0 through `_begin_look`/`_end_look` on a stretched SubViewport (the stored position is set directly, since an unparented viewport has no pointer), ten looks without
drift and a grep for stray `warp_mouse` calls.

**Acceptance criteria**
- Suite: with a stretch scale of 1.0, 1.5 and 2.0 (window size set against the base size), `_begin_look` then
  `_end_look` restores a pointer stored at (100, 100), the window centre and the bottom-right corner to within 1 px
  of where it started.
- Suite: ten looks in a row leave the pointer where it started (no drift).
- `tools/check_*.js` (or a suite grep test) rejects a `warp_mouse` call outside the helper.

## Phase 292 — The market names the seller

Owner's playtest, 2026-11-20: a market listing shows the seller's id, not their name. Cause: the host redacts a
listing's `seller` to a handle before broadcast (`NetworkingSlice._on_market_synced` → `redact_for_client`, Phase 36),
and `UISlice` prints that handle in `ui.listing` as it is.

- The host adds the seller's character name to each listing it sends (`seller_name`), read from the registry at send
  time, next to the redacted handle; the handle stays for actions (buy, cancel), the name is only shown. An offline
  seller's listing shows the name saved with the character; a seller with no name left (deleted character) shows a
  localized "unknown seller".
- The same rule for every replicated blob that shows a player to another player (trade, governance proposals and
  votes, clan rolls): a check lists the UI strings that format a player field and fails one that prints a handle.
- The market window shows "(you)" on the viewer's own listings (new key in both locales).

**Done.** `NetSession.redact_blob` names the players in the copy a client is sent (a listing's `seller_name`, a
proposal's `author_name`, a trade's `names` by party) from `PlayerRegistry.character_name` at send time, then
redacts ids to handles; the market, governance and trade broadcasts and the join snapshot all go through it, and the
listen host's own "player" literal crosses as the host's handle (a client used to read the host's listings as its own).
`src/ui/party_label.gd` renders every player field (`PLAYER_FIELD_KEYS`: the listing, proposal, trade and clan roll
lines): name, "<name> (you)", the merchant, or a localized "unknown seller" / "unknown player", never a handle. Suite
`party_name_tests.gd` covers the wire, the client rows in `en` and `pt_BR`, a restart from saved listings and names, and
an audit that no other UI file formats those strings; net harness step `market_names_seller`.

**Acceptance criteria**
- Suite (host): a listing created by Alice reaches Bob's client with `seller_name == "Alice"` and no raw player id
  anywhere in the packet.
- Suite (client): the listing row shows "Alice", never the handle; a listing with no name shows the "unknown
  seller" string in `en` and `pt_BR`.
- Suite: a renamed or offline seller still shows a name after a host restart (saved listings).
- Net harness step: two clients, one lists an item, the other's market window text contains the seller's name.

## Phase 293 — Other players look like people

Owner's playtest, 2026-11-20: another player is a set of geometric shapes with a name and title above it, not a
person. Cause: `PeerWiring._on_remote_avatar_state` creates every remote player as the placeholder
`TravellerHuman` creature and asks for the peer's look afterwards (Phase 181); the look either never reaches the
body or the placeholder body has no chibi player rig to put it on, so the player rig, hair, clothing and held item
the local player sees on themself are never drawn for anyone else.

- A remote player is built from the same `player_rig` and the same body spec as the local player and the Character
  window (Phase 266's one-body rule): body type (Phase 286), skin, hair (Phase 284), worn equipment and the hotbar
  item in the hand (Phase 280). One function builds a player body from a look dictionary, and all three callers use it.
- The host sends the look with the peer's first state in a client's AOI (not on a later request), and again when it
  changes (equipment, hand item, hair); until it arrives the body is the default player body, never a creature.
- The name and title plate stays, placed above the rig's head bone instead of a fixed height.
- The placeholder rule holds: a world without the private art shows the public placeholder player rig, which is a
  person (head, torso, arms, legs), not primitive shapes.

**Acceptance criteria**
- Suite: a remote avatar is built from the player rig, not the `TravellerHuman` creature; its body type, hair,
  skin and equipment match the look dictionary it was given.
- Suite: the local player, the Character window and a remote avatar built from the same look produce the same
  mesh set and bone count.
- Suite (host): the first `player_states` entry for a peer new to a client's AOI is followed by that peer's look in
  the same tick; an equipment change sends the look again.
- Net harness step: two clients, each sees the other as a player rig with the other's chosen hair and body type.

Done: `CharacterSlice.build_player_body(look, pos)` builds the client's own body at boot and every remote player;
the host sends a peer's look just ahead of its first state in a client's AOI (relayed players through
`RelayBatch.entered`, the host's own body through `introduce_host_body`), reading each look once (a cache replaced
on `player_look_changed`), and the hand item on AOI entry (`aoi_pair_entered`). The creation look carries no gear,
so an equipment change is not a second look: the existing `peer_equipment` sync carries it and the suite checks the
remote body wears it. The harness has one client, so its step `remote_player_body` checks the client drawing the
host's body in the host's look without asking for it, and the host pushing it; a listen host still draws its
clients as capsule ghosts (not in this phase's scope).

## Phase 294 — Other players and creatures walk instead of jumping

Owner's playtest, 2026-11-20: another player moves in jumps, as if teleporting, instead of walking; creatures do the
same, less visibly because they are slower. Causes: a remote avatar's body is moved by `set_character_position`, which
snaps the root to each new state as it arrives, so the jitter buffer's sampled position
(`_sample_remote_state_at`) is not what is drawn; the body does not turn to face where it goes; and no walk or run
clip plays from the speed. Creature states arrive through `relay_creature_state` and are applied the same way.

- One remote-motion component for remote players and creatures: it keeps the host's last states (position, yaw,
  move state, server time), samples them each rendered frame at playback time (now minus the jitter buffer), and
  moves the body to the sample; it never snaps unless the gap is larger than a teleport distance set in the fabric
  (a respawn, a bed, a portal), when it snaps once.
- Past the newest state it extrapolates along the last velocity for at most one send interval, then holds.
- The body turns to its movement direction (or the host's yaw when sent) with a turn rate, not at once.
- The locomotion clip follows the sampled speed: idle, walk, run (thresholds from the fabric, the same ones the
  local player uses), and jump/fall from the move state, so feet move with the ground covered.
- The send rate and the jitter buffer length for players and creatures are fabric values, and a creature far from
  every player may be sent less often without breaking the motion.

**Acceptance criteria**
- `npm run validate` / `check-drift` pass with the motion table (buffer length, teleport distance, extrapolation cap,
  turn rate, speed thresholds).
- Suite: states 100 ms apart, 1 m apart; a frame at every 16 ms between them draws the body at a position that moves
  forward every frame, never back, never more than 0.25 m per frame.
- Suite: a jump of more than the teleport distance snaps once and keeps interpolating afterwards.
- Suite: no state for 300 ms: the body moves on for at most one send interval, then stops.
- Suite: a remote body at walking speed plays `walk`, at running speed `run`, standing `idle`; it turns toward its
  movement with the turn rate.
- Suite: a creature driven by `relay_creature_state` uses the same component and passes the same frame test.
- Net harness step: two clients; one walks a straight line, the other's recorded positions of it have no step above
  the per-frame bound.

Done: the fabric's `RemoteMotion` world system (`fabric/gameplay/remote_motion.js`, `tools/check_remote_motion.js`)
holds the send intervals, buffers, extrapolation caps, teleport distance, turn rate and the walk/run thresholds, which
`Locomotion` now reads for the local player as well. One track, `src/networking/remote_motion.gd`, plays the host's
states back a buffer behind on a playback clock that only moves forward (it follows the measured gap between arrivals,
so a far body's sparser states stay smooth; a pause is not a gap), extrapolates at most `extrapolateMaxMs`, and
treats the carried distance as a correction that eases out (so a stop followed by the relay's keepalive never turns
the body round, and a creature the host stops sending eases back to its last state), and snaps once past
`teleportDistanceM` (100 m, validated against a 90 m/s flier over the relay's 750 ms far gap). Facing and the
locomotion speed come only from segments between two host states. Remote
avatars are driven every frame by `PeerWiring.tick_remote_avatars` (position, yaw at the turn rate, locomotion from
the played-back speed); client creatures by `CreatureSlice.tick_motion` (box and model, in an exact anchored frame).
The client used to report its body every 30 physics ticks (0.5 s) against a 100 ms buffer, so a remote body held and
then jumped; it now reports every `players.sendIntervalMs` (100 ms, buffered 200 ms since the host's relay flush is
also 100 ms; the crowd stress bots follow), an unchanged report only every 500 ms. A creature farther
than `farDistanceM` from every player is sent at most every `farSendIntervalMs`. The player relay carries positions
only (a fixed binary entry), so `fall` on a remote player is inferred from a steep, fast drop rather than a sent move
state; the track already takes an air flag for when the wire carries one. The harness has one client, so its step
`remote_walk_smooth` has the host walk a line and the client check its recorded avatar of it.

## Phase 295 — Equipment categories and traits replace tools (fabric)

Decided by the owner on 2026-11-20: there are no tools that cannot be used in combat. Every held item is equipment
of a **category** (knife, sword, axe, hammer, mace, spear, pick, shovel, and so on), and what it can do in the world
follows from its **traits**, not from a tool type. The `toolType` and `harvestTool` fields and the "tool" concept go
away.

- Fabric first (this phase is a fabric PR, no GDScript): an `EQUIPMENT_CATEGORIES` table (id, hands, the attack clip
  family from Phase 287, default traits) and a `TRAITS` table: `Sharp`, `Blunt` with a `heavy` grade, `Piercing`,
  and room for more. Each equipment item names its category and its traits; a material may add or raise a trait.
- Damage: each trait maps to a damage type (slashing for Sharp, blunt for Blunt, piercing for Piercing), and an
  item's combat damage is the sum of its traits' shares. Armour's existing blunt and slashing descriptions become
  numbers against these types.
- Work by trait, in one `WORK_TRAITS` table:
  - **Felling a tree** needs `Sharp` together with `Blunt (heavy)`. Every axe has both, so any axe fells trees;
    something with only one of the two fells nothing, or very slowly (the table says which).
  - **Mining rock** needs `Piercing` together with `Blunt`, as a pick has.
  - **Dissecting a creature** needs the knife category (every knife can dissect).
  - Digging, lock picking and the rest of today's `toolType` uses get a rule each in the same table.
  - The work speed comes from how strongly the item has the needed traits, with Phase 290's work times kept as the
    baseline for the item that today does that job.
- Picks are the weakest weapons: a pick has Blunt and Piercing but the lowest combat damage multiplier of any
  category; the table sets each category's combat multiplier.
- Every existing tool (stone and ferrite and veilsteel picks and axes, shovels, knives, bone tools, lockpicks) is
  rewritten as equipment of a category with traits, keeping its recipe, durability and repair.
- Validators: a work rule names only known traits or categories; every item that today has a `toolType` or
  `harvestTool` can still do that job under the new rules (no regression in what a player can do); no item
  declares `toolType` or `harvestTool`.

**Acceptance criteria**
- `npm run validate` / `check-drift` pass with the category, trait and work tables; generated docs list each
  category, its traits and what it can do.
- The validator rejects an item with `toolType` or `harvestTool`, a category or trait not in the tables, and a work
  rule naming an unknown trait.
- A check proves each former tool can still do its former job: every former axe fells, every former pick mines,
  every former knife dissects.
- A check proves picks have the lowest combat multiplier of all categories.
- Generated content names (categories, traits) are in the in-project catalog in both `en` and `pt_BR`.

Done (2026-11-22). `fabric/gameplay/equipment.js` holds the `Equipment` world system: `traits` (Sharp → slashing,
Blunt with a `light`/`heavy` grade → blunt, Piercing → piercing, and Broad, a shovel's flat head, → blunt),
`categories` (knife, sword, greatsword, axe, hammer, mace, spear, pick, shovel, saw, lockpick, bow: hands, Phase 287
clip family, combat multiplier, default traits), `materialTraits` (veilsteel raises the traits of its working part by
0.5) and `workTraits` (fell, mine, dig, build, pickLock, dissect, cutBone; each a list of ways, a category and/or
traits with a minimum grade, and a speed; an item that matches no way works as bare hands where bare hands can).
Every former tool and weapon declares `equipmentCategory` and `traits` (`{ <Trait>: { strength, grade? } }`, strength
1.0 = the forged item); armour declares `protection` per damage type. Each equipment item gets the derived `works`
and `combatDamage` fields. Until Phase 296 the runtime still reads `toolType`, `harvestTool`, `efficiency` and
`WorkTimes.toolSpeeds`: `items/index.js` derives them from the work table (the bridge; the validator reads the
authored items from `items/authored.js`, where none is declared). The derived values are exactly today's (an axe
cuts bone at half speed only from strength 1.0, so the stone axe still does not). Every held item is equipment (the
ferrite shield is a `shield`) and every worn piece has protection numbers. The
validator (and `tools/check_equipment.js` in CI) rejects a declared `toolType`/`harvestTool`, an unknown category or
trait, a work rule naming an unknown trait or category, a category whose multiplier is not above the pick's, a pick
that out-hits another item of its working material, a former tool slower at its former job (`formerJobs`), and an
item doing two old tool classes (the bridge reads one). `equipment.*`, `trait.*`, `work.*`, `grade.*` and `damage.*` names are
in `locale/content.csv` (en, pt_BR). The generated Equipment page lists each category, its traits and what it can do.

## Phase 296 — Work and combat by trait: no more tools in the game

Runtime for Phase 295. Everything that today asks for a `toolType` or `harvestTool` asks the work table instead.

- One rules function, `EquipmentRules.can_do(item, work)` and `work_speed(item, work)`, read from the fabric tables;
  `InventorySlice.find_tool`, `TreeSlice` felling, mining, digging, dissecting (`harvest`), chest lock picking,
  crafting's tool checks, the tutorial's tool tags and `RigTree.attack_clip_for` all call it, and none of them reads
  `toolType` again.
- The held item's traits set its combat damage and damage type on the host; armour reduces by damage type.
- The attack clip comes from the category (Phase 287's chains), not from whether the item is a tool.
- UI: the item tooltip shows the category, the traits and what the item can do (fell, mine, dissect…), all
  localized; the word "tool" is gone from the UI catalog.
- Saves: an item saved before this phase loads as the same equipment.
- Remove the Phase 295 bridge: `items/index.js` stops deriving `toolType`, `harvestTool` and `efficiency`, and
  `WorkTimes.toolSpeeds` gives way to `Equipment.workTraits`; the fabric validators that still read the bridge
  (work times, stone tools, chests, tutorial, harvest) read the work table instead.

**Acceptance criteria**
- A grep test fails on any `toolType` or `harvestTool` read in `src/`.
- Suite: any axe fells a tree; an item with Sharp but not Blunt (heavy) does not (or does at the table's slow speed);
  a pick mines rock; an item with Piercing but no Blunt does not; any knife dissects a creature; a sword does not
  dissect unless it is in the knife category.
- Suite (host): a pick's hit deals less damage than any other category's item of the same tier, and deals blunt and
  piercing damage; armour with blunt protection reduces the blunt share.
- Suite: an inventory saved before this phase loads with every item able to do what it did before.
- Suite: tooltip strings exist in both locales; no UI string contains the word "tool" as a category.
- Playtest bot `tutorial` and `fight` steps pass with the new rules.

Done (2026-11-22). `EquipmentRules` (`src/character/equipment_rules.gd`) reads the fabric's `Equipment` tables:
`spec_of`, `can_do(item, work)`, `work_speed(item, work)` (the same way-matching as the fabric, material raise
included), `works_of`, `harvest_work`, `combat_damage`, `clip_family`, `player_hit`, `creature_hit`, `protection` and
`armour_factor`. `InventorySlice.find_for_work(work)` replaces `find_tool` (the fastest usable held item for a work);
felling, mining and digging (`WorkTime.actions[..].work`, the item's work speed, else bare hands), building
(`Structure.buildWork`, refusal `build_required`), lock picking (`ChestsAndDoors.locks.work`), the chest destruction
method, harvesting (`CarcassRules.tools_of`, `Equipment.harvestWorks`), the tutorial's tags (the equipment category),
the crafting window's `work_gear` tab and `ComboChain.weapon_class` / `RigTree.attack_clip_for` (the category's clip
family; `CombatCombos.twoHandedItems` is gone) all go through it. The Phase 295 bridge is removed: no item carries
`toolType`, `harvestTool` or `efficiency`, `WorkTimes.toolSpeeds` is gone, and the work-time, stone-tool, chest,
tutorial and harvest validators read the items' `works`. On the host a player's hit deals the held item's
`combatDamage` × `Equipment.combatScale` (2.5), empty hands `Equipment.unarmed` (4 blunt; every item hits harder, the
validator checks), a creature's `baseDamage` split by `Equipment.creatureDamageShares`; a hit on a player keeps
Σ share × (1 − protection) of each type, the protection from the registry's worn set (host-validated at equip).
The inventory tooltip shows the category, the traits with their grades and what the item can do (`ui.tip_*`, en and
pt_BR), and the UI catalog no longer calls anything a tool (the suite checks both columns). Suite
`equipment_trait_tests.gd` covers the criteria, including a grep of `src/` for `toolType`/`harvestTool`.

## Phase 297 — Finding servers nearby: dual-stack IPv6, a status port and LAN discovery

Filed by the owner on 2026-11-22. Today a player joins by typing an address (main menu → Join server). The host
already listens on IPv4 and IPv6: `create_server` binds Godot's default `*` address as one dual-stack socket
(checked on Godot 4.7: a client reaches it on `::1`), but nothing tests that, and a bracketed IPv6 address
does not pass the Join form's rule. The port is fixed: the client always dials `DEFAULT_PORT` (7777), and an
address typed as `10.0.0.2:7777` passes the Join form's rule but is then handed to ENet whole, as a host name.
This phase is the base the server list (298, 299) builds on.

- **Address and port.** One parser (replacing `RecentServers.valid_address`, still shared by the Join form,
  `--client` and the recent-servers file) splits an address into host and port: `host`, `host:port`,
  `1.2.3.4:port`, `[v6]:port`, and a bare IPv6 literal, which never carries a port (`2001:db8::1` is the whole
  host). No port means `DEFAULT_PORT`. A host takes `--port <n>` (default 7777).
- **Dual-stack.** A listen host and a dedicated server keep the default `*` bind (dual-stack, and IPv4 alone where
  the OS has no IPv6), now covered by a test. `--bind <addr>` overrides it. The Join screen accepts IPv6 literals
  (`[2001:db8::1]:7777` and bare `2001:db8::1`), and a host name that resolves to both families is tried IPv6
  first, then IPv4 after 250 ms (Happy Eyeballs, RFC 8305), keeping whichever answers first. IPv6 does not lower
  latency; it matters because a self-hoster behind IPv4 CGNAT, common in Brazil, can be reached on IPv6 with only a
  firewall rule and no port forward.
- **Status port.** Every host answers a small UDP status query on a second port (default the game port + 1,
  `--status-port`, `0` turns it off). The answer: protocol version, game version, the game port, a world name,
  players online and max players. Names are the host's text, so they are shown as given, never
  translated; every label around them is an `I18n.t()` key. Anti-abuse: a query must be padded to at least the
  answer's size so the port cannot amplify a spoofed request; answers are rate-limited per source address; the
  answer has a fixed size cap; malformed queries are dropped without a reply.
- **Protocol version.** The status answer and the join handshake carry a protocol version. A client refuses to
  join a host whose version it does not speak and says so with a reason key (today an old client connects and
  misbehaves).
- **LAN discovery.** The Join screen sends the status query to the IPv4 broadcast address and the IPv6
  all-nodes link-local multicast group (`ff02::1`) on the default status port (broadcast enabled on the socket; the
  multicast query sent once per interface from `IP.get_local_interfaces()`, since a link-local group needs a
  scope), and lists every host that answers under "On this network", with its players and round-trip time,
  once per host even when it answers on both families. A row joins on click, using the game port from the
  answer.
- **Client round-trip.** The same query, sent to a known address, gives the ping shown beside each recent server.

**Acceptance criteria**
- Suite: the address parser accepts IPv4 and host names with and without a port, bracketed IPv6 with and
  without a port, and bare IPv6 (no port), returning the host and port for each; it rejects malformed input
  (a bad port, unclosed brackets, a scheme or path) with the existing `menu.join.error_address` key; `--client`,
  the Join form and the recent-servers loader agree on every case (the Phase 223 one-rule test).
- Suite: the status codec round-trips; a query smaller than the answer gets no reply; a query over the size cap
  or with a bad version gets no reply; the per-address rate limit drops the excess.
- Suite: a client with protocol version N refuses a host advertising N+1 with a reason key present in `en` and
  `pt_BR`.
- Net harness: a host and a client on `::1` (IPv6 loopback) connect and play the existing harness steps; the
  same on `127.0.0.1`. A LAN discovery query on loopback finds the harness host. Skipped with a logged reason on
  a runner without IPv6.
- Every new UI string is in `locale/ui.csv` in both columns.

**Done** (2026-11-24). `src/networking/net_address.gd` is the one address rule (`RecentServers.valid_address` is gone):
`parse` returns host, port and family for `host`, `host:port`, `[v6]:port`, `[v6]` and a bare IPv6 literal, and refuses
a scheme, path, whitespace, a zone (`%eth0`), an unclosed bracket and a port outside 1–65535 with
`menu.join.error_address`; `--client`, the Join form and the recent-servers loader all call it. A host takes `--port`,
`--bind` (default `*`, one dual-stack socket), `--status-port` (default the game port + 1, `0` off) and `--world-name`
(`BootWiring.parse_host_args` / `host_options`; a menu world answers with its own name). The status wire
(`src/networking/server_status.gd`) is binary and fixed-size: a query padded to the answer's 192 bytes (at most 512),
an answer of exactly 192 with the nonce echoed, protocol, game port, players, max players, a per-process instance id,
the game version and the world name (cut to their byte caps on a character boundary, control characters dropped).
`StatusServer` (a child of the networking slice while hosting) drops short, oversized, foreign and other-format
queries without a reply and answers at most 4 per source address and 200 in all per second. `PROTOCOL_VERSION` (1)
rides the status answer, a `server_hello` the host sends on connect, and every `join_intent` / `roster_intent`; a host
refuses an intent of another protocol (or none) with `protocol_refused` and drops the peer 0.5 s later, and a client
leaves on either with `menu.join.fail_protocol_newer` / `_older` (`GameBus.join_refused`). `ServerProbe` is the client
socket: queries matched to their nonce (a stray answer is ignored), names resolved on the resolver queue, LAN rows
merged by instance (one row per host, joined on its IPv4 address, at most 32, a faster newcomer replacing the slowest
row). The Join page lists "On this network" (world, players, round trip; another protocol listed but disabled),
re-asks every 3 s and drops a host silent for 7 s; Search again starts the list empty; a ping sits beside each recent
server. `ServerConnector.resolve_join` (a coroutine, one frame at a time: the window never freezes) resolves a name on
the resolver queue and races both families on the status query (IPv6, then IPv4 250 ms later, first answer wins, the
resolver's first address after 1 s) rather than on ENet, since a losing ENet attempt would leave a half-open peer on
the host. The status port's 200 answers a second are shared by all sources, so a spoofed flood can starve discovery
(not the game port) while it lasts: accepted for a convenience port. One deviation: Godot 4.7's sockets carry no IPv6 scope id (`ff02::1%eth0` is
accepted and the zone dropped, checked on this machine), so the `ff02::1` query goes out once, on the OS's default
multicast interface, not once per interface; IPv4 broadcast covers the rest of a LAN. Suite `discovery_tests.gd`
(parser, one rule, codec, query rules, rate limit, protocol refusal and wire, LAN rows and the Join page, Happy
Eyeballs, host flags, real dual-stack ENet and status sockets on `127.0.0.1` and `::1`, catalog); net harness step
`lan_discovery`, and the harness runs on both loopbacks in CI (`NET_HARNESS_ADDRESS`, a matrix; `::1` skipped with a
logged reason on a runner without it; `NET_HARNESS_PORT` moves it off 7777).

## Phase 298 — The server list: a registry and the Join screen's public list

Needs Phase 297. A server that wants to be public announces itself to a registry, and the Join screen lists the
public servers.

- **Registry role.** A new headless boot role, `--registry [port]`, in the same Godot build (no second stack to
  maintain). It keeps an in-memory table of public servers and answers list queries over TCP with
  length-prefixed JSON, every message size-capped.
- **Heartbeat.** A dedicated server started with `--public` (and a listen host that ticks "Show in server list")
  sends a heartbeat every 30 s over TCP (so its source address cannot be spoofed): game port, status port,
  world name, region tag, protocol version, players, max players. A dual-stack host heartbeats over IPv4 and
  over IPv6, and the registry lists each family's address it has verified. The registry takes the IP from the
  heartbeat's source, never from its body, and lists a server only after it answers a status query sent back
  to that IP and status port (so a heartbeat cannot list someone else's IP).
  An entry missing three heartbeats is dropped. Heartbeats are rate-limited per address, with a cap on servers
  per address.
- **Registry list.** The registries a client and a server use are a list in settings, seeded from a file in the
  repository (`config/registries.json`) so a community can run its own; empty means no public list.
- **Join screen.** A "Public servers" tab: the client fetches the list, then queries each server's status port
  itself (bounded parallelism, timeouts) and shows name, players, ping, version and a "can't join: other
  version" mark. Sort by ping or players, filter by text and "hide full". Clicking a row fills the address and
  joins. The list is cached on disk and shown at once on the next open while it refreshes.
- Region tags and every column header, filter and error are `I18n.t()` keys; dates and numbers go through the
  locale formatter.

**Acceptance criteria**
- Suite: the registry table adds an entry only after a successful back-probe; drops it after three missed
  heartbeats; ignores an address in the heartbeat body; enforces the per-address cap and rate limit; caps
  message size.
- Suite: list codec round-trip; a list over the cap is truncated, not trusted.
- Net harness: a registry, two `--public` hosts and a client on loopback; the client's list shows both hosts
  with players and ping; one host stops and drops out of the list within 100 s; the client joins the other
  from the list.
- Suite: every new key exists in both `en` and `pt_BR`.

**Done** (2026-11-24). `--registry [port]` (`BootWiring.start_registry`, default TCP 7700, dual-stack) is a headless
process holding `RegistryTable` and nothing else. The wire (`src/networking/registry_wire.gd`) is one length-prefixed
JSON frame each way per connection (`RegistryExchange`): a request at most 1 KiB, a list reply at most 64 KiB and 256
entries, each exchange on a 5 s deadline; a frame over its cap is never read past its length. The table keys an entry
by the connection's source IP and the heartbeat's game port (an `ip`/`address`/`host` in the body is never read),
lists it only after a status query sent back to that IP and the heartbeat's status port is answered from that IP
naming that game port (a new status port is probed again; an unverified entry whose probe goes unanswered is dropped
at once), re-asks a listed entry's status port on each heartbeat and lists the player counts of that answer, never the
heartbeat's, drops it 92 s after its last heartbeat (three missed 30 s heartbeats plus 2 s), and caps, per address
bucket (an IPv4 address or an IPv6 /64), 4 servers, 8 heartbeats per 30 s, 4 open connections and 20 list queries per
10 s; in all 4,096 entries (256 unverified) and 64 connections. The list reply is encoded once per table change. A host heartbeats with `--public` (a dedicated server) or "Show in server list" on the Play page (a
listen host, with a region picked beside it), over TCP to each registry's first IPv6 and first IPv4 address (`RegistryClient.families`), and only with
its status port open; `--region <tag>` (`sa`, `na`, `eu`, `af`, `as`, `oc`, shown as `menu.region.*`) and `--save-dir`
(a second server on one machine) came with it. The registries are `--registries a,b`, else the player's list under
`registries` in `user://settings.json` (edited on the Public servers tab), else `config/registries.json` (empty: no
public list until a community runs one; exported with the game). The Join page has two tabs; Public servers
(`src/menu/public_servers.gd`) shows the cached list (`user://server_list.json`, read back through the same decoder)
at once, fetches every 15 s while open, queries each server's status port itself (16 at a time, 2 s timeout; an answer
from another IP or naming another game port is ignored; servers never heard from are asked first, in random order),
shows a dual-stack host once (an IPv4 and an IPv6 row on one game port whose answers agree), with world, region,
players, ping and version, and lets a row be joined only once the server answered this client on this protocol
(another protocol is marked "Can't join: other version");
sorts by ping or players, filters by name or region and hides full servers; a row fills the address and joins.
Numbers go through `I18n.number`. Suite `registry_tests.gd` (table rules, wire caps, list codec and truncation, real
loopback registry on 127.0.0.1 and ::1, the tab, boot flags, registry list, catalog); `tools/registry_harness.sh` (CI
job `registry-harness`, both loopbacks): a registry, two `--public` servers and a `--menu-public-join` client: both
listed with players and ping, the stopped one leaves the list 90 s after it stopped, the client joins the other from
it. Folded in #744: `ServerConnector`'s preload no longer shares a line in `game_root.gd`, and the two-client harness
already runs under a 480 s CI deadline (a full local run is about 5 min). Two-family dedupe on the client is by the
status answer, so a registry may list a host twice; a server that mirrors another's live status answer can still
pose as its other family until Phase 299 signs entries.

## Phase 299 — Many registries: signed entries, gossip and no single owner

Needs Phase 298 and parked Phase 227 (the key algorithm). The list should survive any one registry going away
and be hard to fake, in keeping with an open-source game anyone can host.

- **Host key.** Every host gets its own signing key and a world id, as Phase 228 specifies (`user://` for a
  listen host, the save folder for a dedicated server); this phase brings that part of 228 forward, and 228
  reuses it when un-parked. Needs Phase 227's algorithm decision first (design-only, a fabric PR): a key
  minted with a stand-in algorithm would have to be replaced when 228 lands, and every recent server would
  then trip the changed-key warning below.
- **Signed entries.** A heartbeat carries the entry signed by the host key with a sequence number. Registries
  store and pass on the signed entry; a client verifies the signature and shows the key's short fingerprint.
  The entry does not carry the host's address (a host behind NAT does not know it), so a copied entry could be
  announced from another machine. To close that, the status query carries a random nonce and a host with a key
  signs `status | nonce | key fingerprint` in its answer: a registry's back-probe and the client's own status
  query both check that the address answers for the entry's key, and an address that cannot is not listed.
  The signature counts toward the status answer's size cap and the query's padding.
  Recent servers remember the fingerprint, and a known address that later answers with another key is shown
  with a warning instead of joined silently.
- **Many registries.** A server heartbeats to every registry in its list; a client queries all of them and
  merges by host key, keeping the highest sequence number.
- **Gossip.** Registries exchange their signed entries with the other registries they know every few minutes
  (bounded batch, rate-limited), and each back-probes an entry before listing it, so a server announced to one
  registry appears on the others and a dead registry loses nothing.
- **Fallback.** If no registry answers, the client shows its cached list and the LAN list; if a public server
  is configured with a `--peer-list` it can also answer list queries for the servers it has seen, so the list
  can be bootstrapped from any known server.
- A full DHT (as BitTorrent's) was considered and not adopted: it needs bootstrap nodes anyway, is harder to
  protect from fake entries, and the server count does not need it.

**Acceptance criteria**
- Suite: a valid signed entry verifies; an entry with a changed field, another key's signature or a lower
  sequence number is rejected.
- Suite: a registry back-probe and a client status query reject an address whose status answer is unsigned,
  signed over another nonce, or signed by a key other than the entry's (a copied entry replayed from another
  host).
- Suite: merging two registry answers keeps one entry per host key, the highest sequence.
- Suite: a recent server whose key changed is flagged; the warning key exists in both locales.
- Net harness: two registries and one `--public` host announced to only the first; within two gossip rounds
  the second lists it; the first registry stops and the client still lists the host from the second.
- Net harness: a client with every registry down shows the cached list and joins from it.

---

## Parked phases

Parked by the owner on 2026-11-10. Their specs are kept as written so a phase can be picked up
again; check each against the phases done since before un-parking it. Phase 236 also keeps a
place near the end of the priority order (before Phase 251) for when it is un-parked.

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
  dedicated server) and a world id; Phase 230 reuses them. If Phase 299 is done first, it has already
  made them: reuse its key and world id instead of minting new ones.
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
- **Fishing and Farming** (owner, 2026-11-14) — two more `gathering` skills (Phase 274). Neither
  system exists yet; each skill is added with its system so no skill is filed without an XP source.
- **Real cross-region multiplayer run** — Phase 135 emulates WAN profiles in the harness. A run
  between real regions remains.
- **Automatic LOD mesh decimation** — simplified meshes are hand-authored (Phase 23).
- **Dynamic impostor re-bake** — impostor billboards are baked offline. A live re-bake on palette
  change is deferred from Phase 23.
- **Server sharding (last, not before maturity)** — split the authoritative simulation across
  servers by region once one headless server (Phase 27) with spatial hashing (Phase 28) and
  interest management (Phase 29) saturates. No structural change is needed before then. Revisit
  when Brazil-region load approaches one server's ceiling.
