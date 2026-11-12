# Roadmap history — Phase 242

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 242 — Terrain materials: blend weights, a triplanar shader and CC0 textures ✅ Done

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

**Implemented**
- Fabric PR (#616): seven `terrain_material` entities in `fabric/world/terrain_materials.js` (grass, dirt,
  moss, rock, sand, snow, mud) with `layer`, `textureKey`, `scale`, `biomes`, `slopeMin` (rock, 40°),
  `aboveSnowLine` (snow) and `nearWater` (mud, 3 m); every biome has a `snowLine` (Alpine and Tundra 0,
  Taiga 400 m, the temperate pair 700 m, the rest never). `validateTerrainMaterials` and
  `tools/check_terrain_materials.js` reject a biome with no material, a map with no file in `assets/`,
  a repeated or skipped layer, an unknown biome, a missing snow line and a table with no snow material.
- Textures: ambientCG CC0 1K sets (Grass004, Ground048, Ground037, Rock030, Ground054, Snow006,
  Ground036) re-encoded as `assets/textures/terrain/<name>_{albedo,normal,roughness}.jpg.raw` (8.7 MB),
  credited in `assets/README.md`. `AssetOverlay.load_image` decodes JPEG keys.
- **Changed from the spec:** `CUSTOM0`/`CUSTOM1` hold one weight per layer (layers 0–3 and 4–7, RGBA8,
  summing to 255) instead of four ids and four weights. Ids interpolated across a triangle whose
  corners use different materials blend into a third material; per-layer weights interpolate
  correctly. This caps the table at eight layers (the validator checks it). A vertex still blends at
  most four.
- Weights: `src/terrain/terrain_weights.gd` (pure). The biome blend is Phase 64's border (`BiomeBlend.chance`
  over `VoxelSlice.BLEND_TILES`; the spec's "Phase 120" meant this), then wetness (distance to a lake or
  river edge from `Hydrology.features_for_chunk`), then the snow line (±15 m), then slope (±8° round
  `slopeMin`), each taking its share from what came before. Placed-block vertices weigh zero and the
  shader draws their vertex colour. The loop is native (`NativeChunkBuilder.terrain_weights`, native
  version 14, about 1 ms a chunk against about 35 ms in GDScript); `apply_gd` is the reference and a
  parity test compares 16 chunks, local and absolute, with and without water. Weights are added on the
  worker in every build path (full, coarse, the synchronous rebuild).
- Shader: `src/terrain/terrain_material.gdshader` / `terrain_material.gd`. It does triplanar sampling of
  three `Texture2DArray`s (albedo, normal with whiteout blending, roughness), height-based blending at
  borders (texel brightness plus weight), and a detail sample at 4× fading in within 24 m. The biome's
  season tint is a `tint` uniform on the per-biome `ShaderMaterial`.
- Low-end fallback: the project setting `nihon/graphics/terrain_quality` (0 = biplanar, no detail;
  1 = high, the default). Phase 225 puts it in the options window.
- Tests (`terrain_material_tests.gd`): the table, weights summing to 1 over a sweep, rock on steep
  ground, snow above the snow line, mud at a lake edge, the border blend width, packing, CUSTOM0/1 on
  every vertex of a built chunk (zero on placed blocks), native parity, the shader's uniforms with
  every array set, and the low-quality switches.
- Measured locally (xvfb playtest, opengl3, report-only): every step passed. `flight` had the ground
  under the body built in 100% of 42 samples, at 13 ms of worker time per crossing against a floor of
  15 ms (45 ms with coarse chunks off).
