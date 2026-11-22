#!/usr/bin/env node
// Phase 229 — proves the gear-tier validator rejects bad tables: a weapon, tool or station with no tier, a recipe or
// combat ability with no requiredTier, a tier that is not a skill tier, equipment whose tier is not its material's, a
// recipe asking for more gear than its skill guards or its station allow, a hand-made recipe above the floor, and a
// recipe no climb from bare hands can reach. Then checks the shipped data: master gear exists for smithing, novice
// recipes and abilities need no gear, and every ability's tier is its skill rule's.
//   node tools/check_gear_tiers.js
'use strict';
const g = require('../fabric/gameplay/gear_tiers');
const refs = g.gearTiersRefs();
let failed = 0;
const clone = (v) => JSON.parse(JSON.stringify(v));
function report(label, ok, detail) {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(detail)}`);
  if (!ok) failed++;
}
function expect(label, mutate, pattern) {
  const d = g.gearTiersData();
  const r = clone(refs);
  mutate(d, r);
  const problems = g.gearTiersProblems(d, r);
  report(label, pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p)), problems.slice(0, 6));
}

expect('the shipped tables are valid', () => {}, null);

// Missing tiers.
expect('a weapon with no tier fails', (d, r) => { delete r.equipment.FerriteShortSword.tier; }, /FerriteShortSword is equipment \(sword\) with no tier/);
expect('a tool with no tier fails', (d, r) => { delete r.equipment.StoneHammer.tier; }, /StoneHammer is equipment \(hammer\) with no tier/);
expect('a crafting station with no tier fails', (d, r) => { delete r.stationItems.MasterForge.tier; }, /MasterForge is the master forge crafting station with no tier/);
expect('a recipe with no requiredTier fails', (d, r) => { delete r.recipes.RecipeFerritePick.requiredTier; }, /RecipeFerritePick has no requiredTier/);
expect('a combat ability with no requiredTier fails', (d) => { delete d.abilities.Swordsmanship.abilities.executeCounterSlash; }, /Swordsmanship\.executeCounterSlash is a combat ability with no requiredTier/);
expect('a combat skill with no row fails', (d) => { delete d.abilities.Archery; }, /Archery\.executeSteadyShot is a combat ability with no requiredTier/);

// Bad values.
expect('an unknown item tier fails', (d, r) => { r.equipment.FerritePick.tier = 'legendary'; }, /FerritePick: tier "legendary" is not a skill tier/);
expect('an unknown recipe tier fails', (d, r) => { r.recipes.RecipeSteel.requiredTier = 'grandmaster'; }, /RecipeSteel\.requiredTier: tier "grandmaster"/);
expect('equipment above its material fails', (d, r) => { r.equipment.StoneAxe.tier = 'master'; }, /StoneAxe is master but its Ashite working part is novice/);
expect('equipment of an untiered material fails', (d) => { delete d.materialTiers.Voidite; }, /VoiditeEdge: its working material "Voidite" has no gear tier/);
expect('a material tier naming no material fails', (d) => { d.materialTiers.Mithril = 'master'; }, /materialTiers\.Mithril is not a material/);
expect('a recipe above its skill guards fails', (d, r) => { r.recipes.RecipeFerritePick.requiredTier = 'apprentice'; }, /RecipeFerritePick asks for apprentice gear, above its highest skill guard \(novice\)/);
expect('a recipe above its station fails', (d, r) => { r.recipes.RecipeRefinedVoiditeShard.requiredTier = 'journeyman'; }, /RecipeRefinedVoiditeShard asks for journeyman gear at a forge, which is only novice/);
expect('a hand-made recipe above the floor fails', (d, r) => { r.recipes.RecipeBed.requiredTier = 'apprentice'; r.recipes.RecipeBed.skillGuards = [{ skill: 'Carpentry', tier: 'expert' }]; }, /RecipeBed is made by hand .* must be novice/);
expect('a station with no tool rule fails', (d) => { delete d.stationTools.forge; }, /stationTools\["forge"\] is missing/);
expect('a tool rule naming no category fails', (d) => { d.stationTools.forge = 'tongs'; }, /stationTools\["forge"\]: "tongs" is not an equipment category/);
expect('a tool rule for a station no recipe uses fails', (d) => { d.stationTools.bed = 'hammer'; }, /stationTools\["bed"\]: no recipe is made at it/);
expect('an ability below its skill rule fails', (d) => { d.abilities.Swordsmanship.abilities.executeWhirlwindBlade = 'apprentice'; }, /executeWhirlwindBlade must need expert gear/);
expect('an unarmed ability above the floor fails', (d) => { d.abilities.Unarmed.abilities.executeGrapple = 'journeyman'; }, /Unarmed\.executeGrapple must need novice gear/);
expect('an ability that is not a behavior fails', (d) => { d.abilities.Archery.abilities.executeRainOfArrows = 'expert'; }, /abilities\.Archery\.executeRainOfArrows is not an ability of Archery/);
expect('a weapon category that does not exist fails', (d) => { d.abilities.Archery.weapons.push('crossbow'); }, /abilities\.Archery\.weapons: "crossbow" is not an equipment category/);
expect('a non-combat skill row fails', (d) => { d.abilities.Smithing = { weapons: [], abilities: {} }; }, /abilities\.Smithing is not a combat skill/);
expect('a refusal that is not a key fails', (d) => { d.refusals.tool = 'You need a better hammer'; }, /refusals\.tool must be a locale key/);

// The climb: with no hammer above stone, the apprentice recipes at the master forge can never be made.
expect('a recipe no climb reaches fails', (d, r) => { r.equipment.FerriteHammer.tier = 'novice'; r.equipment.FerriteHammer.material = 'Ashite'; },
  /RecipeVeilsteelIngot can never be crafted/);
expect('a tool only made with itself fails', (d, r) => { r.recipes.RecipeVeilsteelHammer.requiredTier = 'journeyman'; r.recipes.RecipeVeilsteelLongsword.requiredTier = 'apprentice'; r.recipes.RecipeVeilsteelChestplate.requiredTier = 'apprentice'; r.recipes.RecipeSteel.requiredTier = 'apprentice'; },
  /RecipeVeilsteelHammer can never be crafted/);

// The shipped data.
const d = g.gearTiersData();
const { craftable, tools } = g.climb(d, refs);
report('every recipe is reachable from bare hands', Object.keys(refs.recipes).every((k) => craftable.has(k)), Object.keys(refs.recipes).filter((k) => !craftable.has(k)));
report('the climb reaches a master hammer', tools.hammer === d.tiers.indexOf('master'), tools);
const novice = Object.entries(refs.recipes).filter(([, r]) => r.requiredTier === d.floor).length;
report('most recipes stay novice (no gear needed)', novice > Object.keys(refs.recipes).length / 2, novice);
report('some recipe needs gear above novice', Object.values(refs.recipes).some((r) => r.requiredTier !== d.floor), null);
const st = g.stationTiers(refs);
report('a novice forge and a master forge', st.forge === 'novice' && st['master forge'] === 'master', st);
report('the floor is novice', d.floor === 'novice', d.floor);

if (failed) { console.error(`\n${failed} check(s) failed`); process.exit(1); }
console.log('\nall gear-tier checks passed');
