#!/usr/bin/env node
// Phase 160 — proves the harvest validator catches bad data: a tool category no item provides, a creature
// without a carcass mass, a Skinning table that skips a level or falls with level, and a carry rule the
// mass cannot satisfy all fail, and the shipped fabric passes.
//   node tools/check_harvest.js
'use strict';
const harvest = require('../fabric/gameplay/harvest');
const creatures = require('../fabric/world/creatures');
const items = require('../fabric/gameplay/items');
const skills = require('../fabric/gameplay/skills');

const fresh = () => JSON.parse(JSON.stringify(harvest.harvestData({ creatures, items, skills })));
let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

expect('the shipped fabric is valid', harvest.harvestProblems(fresh()), null);

const spoon = fresh(); spoon.creatures.ForestBoar.drops[0].tool = 'spoon';
expect("tool 'spoon' fails", harvest.harvestProblems(spoon), /tool must be one of/);

const nobody = fresh(); delete nobody.tools.BoneSaw; delete nobody.tools.CarpenterAxe;
expect('a category no item provides fails', harvest.harvestProblems(nobody), /no item provides tool "bonetool"/);

const mass = fresh(); delete mass.creatures.ForestBoar.carcassMassKg;
expect('a creature without carcassMassKg fails', harvest.harvestProblems(mass), /ForestBoar: creature needs carcassMassKg/);

const skill = fresh(); skill.creatures.ForestBoar.drops[0].skill = 'Juggling';
expect('an unknown skill fails', harvest.harvestProblems(skill), /unknown skill "Juggling"/);

const short = fresh(); short.skinning.qualityCurve.pop();
expect('a quality table missing a level fails', harvest.harvestProblems(short), /qualityCurve must cover every level/);

const fall = fresh(); fall.skinning.yieldCurve[5] = 0.1;
expect('a yield table that falls with level fails', harvest.harvestProblems(fall), /yieldCurve falls at level 5/);

const grade = fresh(); grade.skinning.qualityCurve[9] = 'poor';
expect('a quality grade that falls with level fails', harvest.harvestProblems(grade), /qualityCurve falls at level 9/);

const heavy = fresh(); heavy.creatures.GlimmerFox.carcassMassKg = 500;
expect('a carry body over the capacity fails', harvest.harvestProblems(heavy), /GlimmerFox: carryRule carry but/);

const weak = fresh(); weak.tools.CarpenterAxe.efficiency = 1.5;
expect('a tool efficiency above 1 fails', harvest.harvestProblems(weak), /CarpenterAxe\.efficiency/);

const drag = fresh(); drag.creatures.ForestBoar.carcassMassKg = 10;
expect('a drag body that fits the base capacity fails', harvest.harvestProblems(drag), /ForestBoar: carryRule drag but 10 kg fits/);

const cs = fresh(); cs.creatures.ForestBoar.corpseSeconds = 0;
expect('corpseSeconds 0 fails', harvest.harvestProblems(cs), /ForestBoar: corpseSeconds/);

const rl = fresh(); rl.rules.harvestRangeMetres = 0;
expect('a zero harvest range fails', harvest.harvestProblems(rl), /harvestRangeMetres/);

const xp = fresh(); xp.skinning.xpToLevel[3] = xp.skinning.xpToLevel[2];
expect('xpToLevel that does not rise fails', harvest.harvestProblems(xp), /xpToLevel falls at level 3/);

const xp0 = fresh(); xp0.skinning.xpToLevel[0] = 5;
expect('xpToLevel not starting at 0 fails', harvest.harvestProblems(xp0), /xpToLevel must start at 0/);

const ch = fresh(); ch.skinning.chanceCurve[10] = 1.5;
expect('a chance curve above 1 fails', harvest.harvestProblems(ch), /chanceCurve entries/);

const cr = fresh(); cr.creatures.ForestBoar.carryRule = 'fly';
expect('an unknown carry rule fails', harvest.harvestProblems(cr), /carryRule must be one of/);

const sk = fresh(); sk.creatures.ForestBoar.drops[0].skill = 'Smithing';
expect('a skill other than Skinning fails', harvest.harvestProblems(sk), /skill must be Skinning/);

const mx = fresh(); mx.skinning.maxLevel = 7;
expect('Skinning maxLevel differing from levelCap fails', harvest.harvestProblems(mx), /maxLevel \(7\) must equal levelCap/);

const big = fresh(); big.creatures.ForestBoar.carcassMassKg = 1000;
expect('a drag body over the drag limit fails', harvest.harvestProblems(big), /ForestBoar: carryRule drag but 1000 kg exceeds/);

const none = fresh(); none.tools.BoneSaw.harvestTool = 'none';
expect("an item with harvestTool 'none' fails", harvest.harvestProblems(none), /BoneSaw\.harvestTool must be one of/);

const qty = fresh(); qty.creatures.ForestBoar.drops[0].maxQty = 0; qty.creatures.ForestBoar.drops[0].minQty = 0;
expect('maxQty 0 fails', harvest.harvestProblems(qty), /needs 0 <= minQty <= maxQty/);

const chn = fresh(); chn.creatures.ForestBoar.drops[0].chance = 0;
expect('chance 0 fails', harvest.harvestProblems(chn), /chance must be in/);

let threw = false;
try { harvest.validateHarvest(spoon); } catch (e) { threw = true; }
expect('validateHarvest throws on bad data', threw ? [] : ['did not throw'], null);

process.exit(failed ? 1 : 0);
