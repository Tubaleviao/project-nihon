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
const player = require('../fabric/gameplay/player');

const fresh = () => JSON.parse(JSON.stringify(harvest.harvestData({ creatures, items, skills, player })));
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

let threw = false;
try { harvest.validateHarvest(spoon); } catch (e) { threw = true; }
expect('validateHarvest throws on bad data', threw ? [] : ['did not throw'], null);

process.exit(failed ? 1 : 0);
