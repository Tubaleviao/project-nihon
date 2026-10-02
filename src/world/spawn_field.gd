extends RefCounted
## Spawn field — how many creatures and trees a chunk holds (Phase 44).
##
## Before this phase `CreatureSlice.spawn_for_chunk` placed exactly `spawnCount` of every
## creature of the chunk's biome in EVERY chunk of that biome, and `TreeSlice` planted a
## constant `per_chunk` trees: no chunk could be empty, nothing clustered, and a long walk
## accumulated live instances without bound. This field replaces the constants with a roll:
##
##   • a creature's chunk holds AT MOST ONE pack, admitted by a seeded per-chunk chance
##     (`spawnChance`) scaled by a seeded 2D density noise (`spawnDensity` is its
##     amplitude), so some regions are thick with a species and others hold none;
##   • the pack is `spawnCount` instances around ONE deterministic centre;
##   • a tree chunk plants its biome's fabric `treeDensity` scaled by the same kind of
##     noise, so a forest has clearings and thickets.
##
## Pure, static and object-free: every answer is a function of (world seed, chunk, key) and
## of the fabric numbers passed in — never of `randi()` or of chunk load order. A host and a
## client evaluating it with the same seed agree with nothing replicated, which is the same
## constraint the Phase 43 ore field lives under; it reuses that field's integer hash and
## lattice value noise (`OreField._mix` / `_value_noise_2d`) rather than a second copy.
##
## The CAP is not here: it is a host-only quantity of live instances (see
## `CreatureSlice.live_population`). This file only answers `admits(live, pack, cap)`, the
## pure all-or-nothing rule the slice applies.
##
## Public API (all static):
##   density_noise(seed, chunk_pos, key) -> float          — in [-1, 1], smooth over chunks
##   effective_chance(chance, density, noise) -> float     — the chance after the noise, 0..1
##   pack_rolls(seed, chunk_pos, key, chance, density) -> bool
##   pack_center(seed, chunk_pos, key, chunk_size, tile_size) -> Vector2   — world XZ
##   tree_count(seed, chunk_pos, biome, tree_density) -> int
##   admits(live, pack_size, cap) -> bool

const OreField := preload("res://src/terrain/ore_field.gd")

## Width, in chunks, of one feature of the density noise: packs of a species cluster over
## regions about this many chunks across and thin out between them.
const DENSITY_WAVELENGTH_CHUNKS := 5.0

## Amplitude of the tree density noise. Not a fabric field (the noise SHAPE stays
## GDScript, as Phase 43's does); 1.0 lets a chunk swing from bare to twice its mean.
const TREE_DENSITY_AMPLITUDE := 1.0

const _SALT_DENSITY := 101
const _SALT_ROLL := 102
const _SALT_CENTER_X := 103
const _SALT_CENTER_Z := 104
const _SALT_TREES := 105

## A stable integer for a species / biome key. `String.hash()` is deterministic for a
## given string on every machine, which is all the roll needs.
static func _key_salt(key: String) -> int:
	return key.hash() & 0x7FFFFFFF

## Smooth seeded noise over chunk coordinates, in [-1, 1]. Each key gets its own field,
## so two species of one biome cluster independently.
static func density_noise(seed: int, chunk_pos: Vector2i, key: String) -> float:
	var s := OreField._mix(seed, _key_salt(key), _SALT_DENSITY, 0, 0)
	# Offset by half a cell so a chunk never sits exactly on a lattice corner (where value
	# noise collapses to the corner value and neighbours stop varying smoothly).
	return OreField._value_noise_2d(s,
		(float(chunk_pos.x) + 0.5) / DENSITY_WAVELENGTH_CHUNKS,
		(float(chunk_pos.y) + 0.5) / DENSITY_WAVELENGTH_CHUNKS)

## The per-chunk chance once the density noise has scaled it: `chance × (1 + density ×
## noise)`, clamped to 0..1. A density of 0 leaves the fabric chance untouched.
static func effective_chance(chance: float, density: float, noise: float) -> float:
	return clampf(chance * (1.0 + density * noise), 0.0, 1.0)

## Does this chunk hold a pack of `key`? A uniform draw hashed from (seed, chunk, key)
## against the effective chance — the same answer on every peer, every load.
static func pack_rolls(seed: int, chunk_pos: Vector2i, key: String, chance: float, density: float) -> bool:
	var p := effective_chance(chance, density, density_noise(seed, chunk_pos, key))
	if p <= 0.0:
		return false
	if p >= 1.0:
		return true
	var u := OreField._unit(OreField._mix(seed, chunk_pos.x, chunk_pos.y, _key_salt(key), _SALT_ROLL))
	return u < p

## The pack's centre in world XZ: a hashed tile inside the chunk, inset far enough from
## its edge (PACK_INSET tiles) that the members' small offsets stay inside the chunk too.
const PACK_INSET := 6
static func pack_center(seed: int, chunk_pos: Vector2i, key: String, chunk_size: int, tile_size: float) -> Vector2:
	var inset := mini(PACK_INSET, maxi(floori(chunk_size * 0.5) - 1, 0))
	var inner := maxi(chunk_size - 2 * inset, 1)
	var salt := _key_salt(key)
	var lx := inset + OreField._mix(seed, chunk_pos.x, chunk_pos.y, salt, _SALT_CENTER_X) % inner
	var lz := inset + OreField._mix(seed, chunk_pos.x, chunk_pos.y, salt, _SALT_CENTER_Z) % inner
	return Vector2(
		float(chunk_pos.x * chunk_size + lx) * tile_size + tile_size * 0.5,
		float(chunk_pos.y * chunk_size + lz) * tile_size + tile_size * 0.5)

## Trees in one chunk of `biome`: the fabric mean scaled by the density noise, rounded.
## A mean of 0 plants nothing; otherwise a chunk ranges 0..2× its mean.
static func tree_count(seed: int, chunk_pos: Vector2i, biome: String, tree_density: float) -> int:
	if tree_density <= 0.0:
		return 0
	var n := density_noise(seed, chunk_pos, "trees:" + biome)
	# A tiny hashed jitter breaks ties so neighbouring chunks on one smooth slope do not
	# round to the same count in long runs.
	var jitter := OreField._unit(OreField._mix(seed, chunk_pos.x, chunk_pos.y, _key_salt(biome), _SALT_TREES)) - 0.5
	return maxi(roundi(tree_density * (1.0 + TREE_DENSITY_AMPLITUDE * n) + jitter), 0)

## The cap rule, all or nothing: a pack is admitted only when every member fits under the
## cap beside what is already alive. A partial pack would be a lone wolf the pack AI was
## never written for. A non-positive pack is trivially admitted (nothing to place).
static func admits(live: int, pack_size: int, cap: int) -> bool:
	if pack_size <= 0:
		return true
	return live + pack_size <= cap
