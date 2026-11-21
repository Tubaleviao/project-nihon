# Changelog

Every release of Project Nihon, newest first. The version is `application/config/version` in
`project.godot`; CI fails when that version has no `## v<version>` entry here
(`tools/check_changelog.sh`). The release checklist is in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md#releasing).
Phase numbers point at [ROADMAP.md](ROADMAP.md) and [docs/roadmap-history/](docs/roadmap-history/README.md).

## v0.2.0

The first round after the owner's playtest of 2026-11-19 (Phases 278–290 filed), plus the network,
terrain-cache and stress work that followed v0.1.0. **A v0.2.0 client cannot join a v0.1.0 host or the
reverse:** the hot packets moved to a binary wire format.

**Work that feels like work (Phases 279, 288–290).** Picking up moved to E (the equipment window to T),
both rebindable input actions read by the controls legend and the tutorial cards. Holding to chop, dig or
mine shows a bar under the crosshair that says to keep holding, with a hint after an early release. The
stone shovel digs soil twice as fast, a held dig chains into the next block so a trench is one dig, and
the tutorial marks the nearest ferrite under shallow soil with a beacon. Crafting recipes are cards with
a real icon, the window opens wholly on screen and its columns follow its width.

**A world that looks less like boxes (Phases 278, 282–283).** Trees draw from a model per species with a
tapered trunk, a closed crown that sways (`nihon/graphics/tree_sway` turns it off) and faces wound the
right way round; a felled tree topples away from the feller, then sinks and fades. Loose stones and
branches draw with their own models, varied in turn, size and shape.

**Flight that handles like flight (Phase 237).** Inertia, steering by the camera, and a view that lags
and widens with speed.

**Faster revisits and lighter packets (Phases 244, 256).** Built chunk meshes (client) and generated
heightmaps (host) are cached on disk, keyed by world seed, generator, mesher and edits, so land seen
before loads from disk on a worker. Player states and snapshot chunks travel in a fixed binary layout,
compressed when large.

**Measuring the server (Phase 250).** The stress run can put its bots on another machine over a
token-checked control channel, and `docs/perf/server-ceiling.md` records the loopback numbers.

**Fixes.** A remote client's melee swing now reaches the host, which checks range, rate and target before
it lands. A refused pick-up says why. Sounds cap their polyphony. The tutorial marker searches again after
a teleport or respawn. The production art pin is the newest, and a release tag now must pin the assets
repo's newest `main` (`tools/check_assets_pin.sh`).

## v0.1.0

The first public build: everything from Phase 1 to Phase 255. The downloads carry the public
placeholder art only (grey boxes, simple shapes and CC0 textures), because the production art lives in a
private submodule. The game is complete without it, but it does not look finished.

**The design bible as a fabric (Phases 1–42).** Materials, creatures, skills, items and world systems
are declared once in a [Newel](https://github.com/Tubaleviao/newel) fabric and generated into the
bible, the wiki and the Godot resources the game reads, with a drift check in CI so the three never
disagree.

**A deterministic planet (Phases 43–98, 187–191, 211, 217).** An Earth-sized voxel world built from a
seed: climate, biomes, ores, peaks to about 8,850 m, static lakes and rivers, exact positions far from
the origin, and a stable-world rule so land that was recorded never changes under a newer generator.
Chunks build on worker threads, and the near ring keeps up with flight at 270 m/s.

**Multiplayer with a host that owns the truth (Phases 99–172, 194–196, 218).** A listen host or a
dedicated server runs the world and clients apply what it syncs. Network input is validated,
rate-limited and scoped per peer; chat and admin commands are host-authoritative; the world, the
players and their packs persist per region.

**Living in the world (Phases 99–172).** Gathering, crafting at stations, building with blocks, combat,
taming, creatures with bodies, a day and weather cycle, fast travel between waystones, and the whole
UI in English and Brazilian Portuguese (Phase 131).

**An RPG's face (Phases 173–186).** Item and window icons, attributes, a character sheet with a paper
doll, character creation, admin tools, and a guided first hour that teaches moving, gathering, the
first tools and stations, a shelter with a bed and a first hunt.

**Clans and buildings that stand up (Phases 197–216).** Clans with invites and every member's skills in
view, owned private or clan buildings with durability, dismantling and destruction, a circle round each
building where no creature spawns, skills that grow from work, chests and doors with locks, books and
blueprints, clan tiers, floor limits by material up to 163 floors, chibi body sheets and mounts.

**The front door (Phases 219–224).** Text fields that own the keyboard, Space-only jumping, re-creating
a character, a main menu with local worlds and a Join page, and an Esc menu.

**Terrain that looks right (Phases 240–243, 248–249).** Smooth natural ground from a surface-nets
mesher with a native port, terrain materials blended by a triplanar shader, level-of-detail rings out
to the horizon, and a native library built for release on Linux, Windows and macOS.

**A repository others can use (Phases 252–255).** An open-source licence and a contributor's guide,
flaky gates demoted to report-only with a gate-health check, `.uid` sidecars tracked, the version in a
corner of the main menu, this changelog, and a release workflow that plays the bot's `create`, `walk`
and `mine` steps on the Linux export before it publishes anything.
