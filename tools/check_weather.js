#!/usr/bin/env node
// Phase 128 — proves the weather table validator catches bad tables: a moveSpeedFactor above 1, a
// negative weight and a biome that reaches no state all fail, and the shipped table passes.
//   node tools/check_weather.js
'use strict';
const weather = require('../fabric/world/weather');
const biomes = weather.biomeClimates(require('../fabric/world/biomes'));

const fresh = () => JSON.parse(JSON.stringify(weather.RULES));
let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

expect('the shipped table is valid', weather.weatherProblems(weather.RULES, biomes), null)

const fast = fresh(); fast.states.storm.moveSpeedFactor = 1.5
expect('moveSpeedFactor 1.5 fails', weather.weatherProblems(fast, biomes), /moveSpeedFactor must be in 0\.\.1/)

const heavy = fresh(); heavy.states.rain.weight = -1
expect('a negative weight fails', weather.weatherProblems(heavy, biomes), /weight must be >= 0/)

const dark = fresh(); dark.states.fog.visibilityFactor = -0.1
expect('visibilityFactor -0.1 fails', weather.weatherProblems(dark, biomes), /visibilityFactor must be in 0\.\.1/)

const stranded = fresh()
for (const id of Object.keys(stranded.states)) if (id !== 'storm') stranded.states[id].weight = 0
expect('a biome that reaches no state fails', weather.weatherProblems(stranded, biomes), /reaches no weather state/)

const unknown = fresh(); unknown.states.clear.biomes = ['Atlantis']
expect('an unknown biome name fails', weather.weatherProblems(unknown, biomes), /unknown biome "Atlantis"/)

const noClear = fresh(); delete noClear.states.clear
expect('a table with no "clear" fails', weather.weatherProblems(noClear, biomes), /must define "clear"/)

process.exit(failed ? 1 : 0)
