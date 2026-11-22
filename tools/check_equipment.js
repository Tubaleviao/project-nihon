#!/usr/bin/env node
// Phase 295 — proves the equipment validator rejects bad tables and items: an item that declares toolType or
// harvestTool, an unknown category or trait, a work rule naming an unknown trait or category, a category with a
// pick-level combat multiplier, a former tool that lost its job, and armour without a number per damage type.
// Then checks the shipped data: every former axe fells, every former pick mines, every former knife dissects, and
// picks have the lowest combat multiplier of all categories.
//   node tools/check_equipment.js
'use strict';
const eq = require('../fabric/gameplay/equipment');
const refs = eq.equipmentRefs();
let failed = 0;
const clone = (v) => JSON.parse(JSON.stringify(v));
function report(label, ok, detail) {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(detail)}`);
  if (!ok) failed++;
}
function expect(label, mutate, pattern) {
  const d = eq.equipmentData();
  const r = clone(refs);
  mutate(d, r);
  const problems = eq.equipmentProblems(d, r);
  report(label, pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p)), problems.slice(0, 6));
}

expect('the shipped tables are valid', () => {}, null);
// Declared fields are read off the entity by itemSpecs, so these go through it on a cloned authored item.
function withAuthoredField(name, field, value) {
  return (d, r) => {
    const e = clone(require('../fabric/gameplay/items/authored')[name]);
    e.fields[field] = { type: 'string', description: 'x', defaultValue: value };
    r.items[name] = eq.itemSpecs({ [name]: e })[name];
  };
}
expect('an item declaring toolType fails', withAuthoredField('FerritePick', 'toolType', 'pick'), /FerritePick declares toolType/);
expect('an item declaring harvestTool fails', withAuthoredField('BoneSaw', 'harvestTool', 'bonetool'), /BoneSaw declares harvestTool/);
expect('a held item with no category fails', (d, r) => { r.items.FerriteShield.category = undefined; r.items.FerriteShield.traits = undefined; }, /FerriteShield is held/);
expect('worn armour with no protection fails', (d, r) => { r.items.NoviceTunic.protection = undefined; }, /NoviceTunic is worn/);
expect('an item doing two harvest works fails (the Phase 295 bridge)', (d, r) => { r.items.SkinningKnife.traits.Blunt = { strength: 1, grade: 'heavy' }; }, /SkinningKnife can dissect and cutBone/);
expect('a pick with no peer of its material fails', (d, r) => { r.items.VeilsteelPick.material = 'Lumenfite'; }, /VeilsteelPick: no other equipment of its material/);
expect('an unknown category fails', (d, r) => { r.items.CarpenterAxe.category = 'spoon'; }, /CarpenterAxe: equipmentCategory "spoon" is not in the category table/);
expect('an unknown item trait fails', (d, r) => { r.items.SkinningKnife.traits.Glowing = { strength: 1 }; }, /SkinningKnife\.traits: trait "Glowing" is not in the trait table/);
expect('a work rule naming an unknown trait fails', (d) => { d.workTraits.mine.ways[0].traits.Hard = {}; }, /work mine\.ways\[0\]\.traits: trait "Hard" is not in the trait table/);
expect('a work rule naming an unknown category fails', (d) => { d.workTraits.dissect.ways[0].category = 'cleaver'; }, /work dissect\.ways\[0\]: category "cleaver"/);
expect('a work rule needing nothing fails', (d) => { d.workTraits.build.ways[0] = { traits: {}, speed: 1 }; }, /names neither a category nor a trait/);
expect('a graded trait with no grade fails', (d, r) => { delete r.items.StoneHammer.traits.Blunt.grade; }, /StoneHammer\.traits\.Blunt needs a grade/);
expect('an axe without Blunt (heavy) fails', (d, r) => { r.items.StoneAxe.traits.Blunt.grade = 'light'; }, /every axe has Blunt \(heavy\)/);
expect('a category as weak as the pick fails', (d) => { d.categories.sword.combatMultiplier = d.categories.pick.combatMultiplier; }, /category sword: combatMultiplier .* picks are the weakest weapons/);
expect('a pick out-hitting another item of its tier fails', (d) => { d.categories.pick.combatMultiplier = 0.05; d.categories.lockpick.combatMultiplier = 0.06; d.traits.Piercing.damage = 0.1; }, /must deal less than/);
expect('a former axe that no longer fells fails', (d) => { d.workTraits.fell.ways[0].traits.Piercing = {}; }, /CarpenterAxe can no longer fell/);
expect('a former pick that got slower fails', (d) => { d.workTraits.mine.ways[0].speed = 0.5; }, /FerritePick does mine at 0\.5, slower than before/);
expect('an unknown clip family fails', (d) => { d.categories.mace.clipFamily = 'flail'; }, /category mace: clip family "flail"/);
expect('armour missing a damage type fails', (d, r) => { delete r.items.FerriteHelmet.protection.piercing; }, /FerriteHelmet\.protection\.piercing must be a share/);
expect('an item doing two old tool classes fails (the Phase 295 bridge)', (d, r) => { r.items.StonePick.traits.Broad = { strength: 1 }; }, /StonePick can mine and dig/);

// Every item that had a toolType or harvestTool on main before this phase (frozen here, apart from FORMER_JOBS, so
// dropping a FORMER_JOBS row cannot switch its no-regression check off unnoticed).
const FORMER_TOOLS = ['FerritePick', 'VeilsteelPick', 'CarpenterAxe', 'SkinningKnife', 'BoneSaw', 'Lockpick',
  'StoneAxe', 'StonePick', 'StoneShovel', 'StoneHammer', 'StoneKnife'];
{
  const missing = FORMER_TOOLS.filter((k) => !eq.FORMER_JOBS[k]);
  report('FORMER_JOBS covers every former tool', missing.length === 0, missing);
}

// The shipped data, read off the derived items.
const d = eq.equipmentData();
const byCat = (c) => Object.entries(refs.items).filter(([, s]) => s.category === c);
for (const [cat, work] of [['axe', 'fell'], ['pick', 'mine'], ['knife', 'dissect'], ['shovel', 'dig'], ['hammer', 'build'], ['lockpick', 'pickLock'], ['saw', 'cutBone']]) {
  const items = byCat(cat);
  const bad = items.filter(([, s]) => !(eq.workSpeed(s, work, d) > 0)).map(([k]) => k);
  report(`every ${cat} can ${work} (${items.map(([k]) => k).join(', ')})`, items.length > 0 && bad.length === 0, bad);
}
for (const [k, jobs] of Object.entries(d.formerJobs)) {
  const s = refs.items[k];
  const lost = Object.entries(jobs).filter(([w, speed]) => !(eq.workSpeed(s, w, d) >= speed)).map(([w]) => w);
  report(`${k} still does ${Object.keys(jobs).join(', ')} at its old speed`, lost.length === 0, lost);
}
{
  const swordKnife = eq.workSpeed(refs.items.FerriteShortSword, 'dissect', d);
  report('a sword does not dissect (only the knife category does)', swordKnife === 0, swordKnife);
  const noBlunt = eq.workSpeed({ category: 'knife', traits: { Sharp: { strength: 1 }, Piercing: { strength: 1 } } }, 'mine', d);
  report('Piercing without Blunt does not mine', noBlunt === 0, noBlunt);
  const noHeavy = eq.workSpeed({ category: 'sword', traits: { Sharp: { strength: 1 }, Blunt: { strength: 1, grade: 'light' } } }, 'fell', d);
  report('Sharp without Blunt (heavy) does not fell', noHeavy === 0, noHeavy);
  const stoneBone = eq.workSpeed(refs.items.StoneAxe, 'cutBone', d);
  report('a stone axe does not cut bone (as before this phase)', stoneBone === 0, stoneBone);
  const pick = d.categories.pick.combatMultiplier;
  const weaker = Object.entries(d.categories).filter(([c, cat]) => c !== 'pick' && !(cat.combatMultiplier > pick)).map(([c]) => c);
  report('picks have the lowest combat multiplier of all categories', weaker.length === 0, weaker);
  const dmg = eq.combatDamage(refs.items.FerritePick, d);
  report('a pick deals blunt and piercing damage', dmg.blunt > 0 && dmg.piercing > 0 && !dmg.slashing, dmg);
}

if (failed) { console.error(`${failed} check(s) failed`); process.exit(1); }
console.log('all equipment checks passed');
