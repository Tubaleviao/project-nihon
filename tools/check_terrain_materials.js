#!/usr/bin/env node
// Phase 242 — proves the terrain-material validator catches bad data: a biome no material covers, a
// texture key with no file in assets/, a repeated or skipped layer, an unknown biome, a biome with no
// snowLine, a table with no snow material and a scale that does not tile a chunk all fail, and the shipped fabric passes.
//   node tools/check_terrain_materials.js
'use strict';
const tm = require('../fabric/world/terrain_materials');
const biomes = require('../fabric/world/biomes');

const clone = (o) => JSON.parse(JSON.stringify(o));
const fresh = () => ({ materials: clone(tm.TERRAIN_MATERIALS), biomes: clone(biomes) });
const problems = (d) => tm.terrainMaterialProblems(d.materials, d.biomes);
const set = (m, f, v) => { m.fields[f].defaultValue = v; };
let failed = 0;
function expect(label, found, pattern) {
  const ok = pattern === null ? found.length === 0 : found.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(found)}`);
  if (!ok) failed++;
}

expect('the shipped fabric is valid', problems(fresh()), null);

const bare = fresh(); set(bare.materials.TerrainSand, 'biomes', ['Ocean', 'Beach']);
expect('a biome with no terrain material fails', problems(bare), /biome Desert resolves to no terrain material/);

const missing = fresh(); set(missing.materials.TerrainMud, 'textureKey', 'textures/terrain/swamp');
expect('a texture key with no file fails', problems(missing), /swamp_albedo\.jpg\.raw has no file in assets/);

const twice = fresh(); set(twice.materials.TerrainMud, 'layer', 0);
expect('a repeated layer fails', problems(twice), /layer 0 is also/);

const gap = fresh(); set(gap.materials.TerrainMud, 'layer', 7);
expect('a skipped layer fails', problems(gap), /layers skip 6/);

const high = fresh(); set(high.materials.TerrainMud, 'layer', 8);
expect('a layer past the eight weight channels fails', problems(high), /layer 8 is outside 0..7/);

const ghost = fresh(); ghost.materials.TerrainGrass.fields.biomes.defaultValue.push('Atlantis');
expect('an unknown biome fails', problems(ghost), /unknown biome "Atlantis"/);

const noLine = fresh(); delete noLine.biomes.Taiga.fields.snowLine;
expect('a biome with no snowLine fails', problems(noLine), /biome Taiga declares no numeric snowLine/);

const noSnow = fresh(); set(noSnow.materials.TerrainSnow, 'aboveSnowLine', false);
expect('a table with no snow material fails', problems(noSnow), /no terrain material covers ground above the snow line/);

const odd = fresh(); set(odd.materials.TerrainRock, 'scale', 6);
expect('a scale that does not tile a chunk fails', problems(odd), /scale 6 must fit a 32 m chunk/);

const flat = fresh(); set(flat.materials.TerrainRock, 'slopeMin', 95);
expect('a slope outside (0, 90) fails', problems(flat), /slopeMin must be -1 or in \(0, 90\)/);

let threw = false;
try { tm.validateTerrainMaterials(bare.materials, bare.biomes); } catch (e) { threw = /Terrain materials:/.test(e.message); }
expect('validateTerrainMaterials throws on bad data', threw ? [] : ['did not throw'], null);

process.exit(failed ? 1 : 0);
