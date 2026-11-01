#!/usr/bin/env node
// Phase 203 — proves the structure validator catches bad tables: editing by non-owners, a circle that does not
// grow, no space kept around a structure, an abandoned clan structure kept from everyone, floor limits other than the owner's (wood 2, stone 5, concrete 10, top 163), classes out of order, a
// shape threshold that needs a weaker class, a rarer material with less durability, a build ceiling below the
// peak plus the tallest tower, a cheap offline destruction, a destroyer who gets materials, a dismantle share
// off its two fixed points or rising as durability falls, and an unlimited respawn all fail; the shipped
// tables pass and dismantling returns 100% and 50% at the fixed points.
//   node tools/check_structure.js
'use strict';
const s = require('../fabric/gameplay/structure');
const freshRefs = () => JSON.parse(JSON.stringify(s.structureRefs()));
let failed = 0;
function report(label, ok, detail) {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + detail}`);
  if (!ok) failed++;
}
function expect(label, mutate, pattern, mutateRefs) {
  const d = s.structureData();
  const refs = freshRefs();
  mutate(d);
  if (mutateRefs) mutateRefs(refs);
  const problems = s.structureProblems(d, refs);
  report(label, pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p)), JSON.stringify(problems));
}

expect('the shipped tables are valid', () => {}, null);
const dm = s.DURABILITY.dismantle;
report('dismantling returns 100% at full durability with the top Building level', Math.abs(s.dismantleShare(dm, 1, dm.topLevel) - 1) < 1e-9, s.dismantleShare(dm, 1, dm.topLevel));
report('dismantling returns 50% at full durability with no skill', Math.abs(s.dismantleShare(dm, 1, 0) - 0.5) < 1e-9, s.dismantleShare(dm, 1, 0));
report('a larger structure has a larger circle', s.circleRadius(s.STRUCTURE.circle, 400, 30) > s.circleRadius(s.STRUCTURE.circle, 1, 1), '');
expect('a clan structure edited by outsiders fails', (d) => { d.structure.ownership.edit.clan = 'anyone'; }, /only the owner edits/);
expect('clan members editing a private house fails', (d) => { d.structure.ownership.memberPrivateInTerritory.edit = true; }, /enter and dismantle, never edit/);
expect('no space kept around a structure fails', (d) => { d.structure.ownership.buffer = 0; }, /buffer must be an integer from 1 to 4/);
expect('a fractional buffer fails', (d) => { d.structure.ownership.buffer = 1.5; }, /buffer must be an integer from 1 to 4/);
expect('an abandoned clan structure kept from everyone fails', (d) => { d.structure.ownership.abandonedClan = 'nobody'; }, /abandonedClan must be "anyone"/);
expect('a circle with no growth fails', (d) => { d.structure.circle.footprintFactor = 0; d.structure.circle.heightFactor = 0; }, /larger structure has a larger circle/);
expect('a third wood floor fails', (d) => { d.structure.classes.wood.maxFloors = 3; }, /wood\.maxFloors must be 2/);
expect('a sixth stone floor fails', (d) => { d.structure.classes.stone.maxFloors = 6; }, /stone\.maxFloors must be 5/);
expect('an eleventh concrete floor fails', (d) => { d.structure.classes.concrete.maxFloors = 11; }, /concrete\.maxFloors must be 10/);
expect('a top class short of 163 floors fails', (d) => { d.structure.classes.composite.maxFloors = 100; }, /composite\.maxFloors must equal maxFloors 163/);
expect('classes out of order fail', (d) => { d.structure.classes.steel.maxFloors = 8; }, /steel\.maxFloors must be an integer above 10/);
expect('a floor that is not whole blocks fails', (d) => { d.structure.floorHeight = 3.1; }, /not a whole number of 0\.125 m blocks/);
expect('a more unusual shape allowing a weaker class fails', (d) => { d.structure.shapes.overhangReach[2].minClass = 'wood'; }, /must be stronger than stone/);
expect('an unknown shape class fails', (d) => { d.structure.shapes.unsupportedSpan[0].minClass = 'glass'; }, /"glass" is not a structural class/);
expect('collapsing existing builds fails', (d) => { d.structure.existingBuilds = 'collapse'; }, /never collapses/);
expect('a rarer material with less durability fails', () => {}, /Voidite \(legendary\) has durability 50/, (r) => { r.materials.Voidite.durability = 50; });
expect('a material with no structural class fails', () => {}, /Thornwood\.structuralClass "undefined"/, (r) => { delete r.materials.Thornwood.structuralClass; });
expect('a build ceiling below the peak plus 163 floors fails', () => {}, /buildCeiling 9000 must be at least/, (r) => { r.buildCeiling = 9000; });
expect('a cheap offline destruction fails', (d) => { d.durability.methods.pick.offlineFactor = 2; }, /offlineFactor must be >= 10/);
expect('a weather state with no loss rate fails', (d) => { delete d.durability.loss.weather.rain; }, /loss\.weather\.rain must be in/);
expect('an unknown weather state fails', (d) => { d.durability.loss.weather.hail = 0.1; }, /unknown weather state "hail"/);
expect('a destroyer who gets materials fails', (d) => { d.durability.destroyerGets = 'half'; }, /destroyerGets must be "nothing"/);
expect('a free repair fails', (d) => { d.durability.repair.share = 0; }, /repair\.share must be in/);
expect('a dismantle share off 50% with no skill fails', (d) => { d.durability.dismantle.atNoSkill = 0.4; }, /with no skill, not 0\.5/);
expect('a dismantle share off 100% with the top skill fails', (d) => { d.durability.dismantle.atTopSkill = 0.9; }, /with the top skill, not 1/);
expect('a dismantle share that rises as durability falls fails', (d) => { d.durability.dismantle.durabilityExponent = -1; }, /never rise as durability falls/);
expect('a respawn without a cooldown fails', (d) => { d.respawn.cooldownSeconds = 0; }, /rate-limited/);
expect('a respawn that skips the death rules fails', (d) => { d.respawn.deathRules = 'free'; }, /deathRules must be "normal"/);

let threw = false;
try { const d = s.structureData(); d.structure.classes.wood.maxFloors = 4; s.validateStructure(d, s.structureRefs()); } catch (e) { threw = true; }
report('validateStructure throws on bad data', threw, 'did not throw');
process.exit(failed ? 1 : 0);
