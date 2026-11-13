# Changelog

Every release of Project Nihon, newest first. The version is `application/config/version` in
`project.godot`; CI fails when that version has no `## v<version>` entry here
(`tools/check_changelog.sh`). The release checklist is in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md#releasing).
Phase numbers point at [ROADMAP.md](ROADMAP.md) and [docs/roadmap-history/](docs/roadmap-history/README.md).

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
