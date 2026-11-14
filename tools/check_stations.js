#!/usr/bin/env node
// Phase 268 — proves the station placement validator catches bad tables: a placeable station type with no
// placement item, a placement item not tagged station or placing two types, a placement item no recipe makes, a
// first station that is not hand-made from the newcomer grounds' goods, a station no earlier station leads to and
// a pick-up anyone may do all fail; the shipped table passes.
//   node tools/check_stations.js
'use strict';
const s = require('../fabric/gameplay/stations');
const baseRefs = s.stationsRefs();
let failed = 0;
function expect(label, mutate, pattern, mutateRefs) {
  const d = s.stationsData();
  const refs = JSON.parse(JSON.stringify(baseRefs));
  mutate(d);
  if (mutateRefs) mutateRefs(refs);
  const problems = s.stationsProblems(d, refs);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

expect('the shipped table is valid', () => {}, null);
expect('a placeable type with no placement item fails', (d) => { delete d.stations.forge; }, /stations\["forge"\] is missing: a placeable station type with no placement item/);
expect('a new recipe station with no placement item fails', () => {}, /stations\["kiln"\] is missing/,
  (r) => { r.stationTypes.push('kiln'); });
expect('a placement item with no recipe fails', () => {}, /no recipe makes its placement item "Forge"/,
  (r) => { for (const k of Object.keys(r.recipes)) if (r.recipes[k].outputs.some((o) => o.item === 'Forge')) delete r.recipes[k]; });
expect('a placement item not tagged station fails', (d) => { d.stations.forge.placementItem = 'FerritePick'; }, /"FerritePick" is not an item tagged station/);
expect('two types placed by one item fail', (d) => { d.stations.forge.placementItem = 'CarpentryBench'; }, /places two station types/);
expect('an item that disagrees with its own rule fails', (d) => { d.stations.chest.placementItem = 'Door'; d.stations.door.placementItem = 'Chest'; }, /disagrees with its own rule/);
expect('a type that is not placeable fails', (d) => { d.stations.kiln = { placementItem: 'Forge' }; }, /"kiln"\] is no placeable station type/);
expect('a first station that needs a station fails', (d) => { d.first = 'forge'; }, /no recipe makes "Forge" by hand/);
expect('hand inputs that are not the grounds\' goods fail', (d) => { d.handInputs = ['Thornwood']; }, /must be what the newcomer grounds lay out/);
expect('a station no earlier station leads to fails', () => {}, /"master forge"\] cannot be reached/,
  (r) => { for (const k of Object.keys(r.recipes)) if (r.recipes[k].outputs.some((o) => o.item === 'MasterForge')) r.recipes[k].station = 'master forge'; });
expect('a second station made by hand from raw goods fails', () => {}, /RecipeForge: a station other than the carpentry bench/,
  (r) => { r.recipes.RecipeForge.station = ''; r.recipes.RecipeForge.inputs = [{ item: 'LooseStone', quantity: 8 }]; });
expect('a pick-up anyone may do fails', (d) => { d.pickUp.ownerOnly = false; }, /ownerOnly must be true/);
expect('a pick-up with no reach fails', (d) => { d.pickUp.reachMetres = 0; }, /reachMetres must be in/);

let threw = false;
try { const d = s.stationsData(); delete d.stations.bed; s.validateStations(d, baseRefs); } catch (e) { threw = true; }
console.log(`${threw ? 'ok  ' : 'FAIL'} validateStations throws on bad data`);
if (!threw) failed++;
process.exit(failed ? 1 : 0);
