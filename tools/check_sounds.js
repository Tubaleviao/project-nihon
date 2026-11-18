#!/usr/bin/env node
// Phase 275 — proves the sound-event validator rejects bad tables: a key outside the layout, a wrong bus, a
// positional UI sound, variants on a looping file, a 3d sound with no range, an unknown item/creature/biome, a
// shared key, a bad id or bus list; the shipped table passes. Also pins the file-name rule.
//   node tools/check_sounds.js
'use strict';
const s = require('../fabric/gameplay/sounds');
const refs = s.soundsRefs();
let failed = 0;
function report(label, ok, detail) {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + detail}`);
  if (!ok) failed++;
}
function expect(label, mutate, pattern) {
  const d = s.soundsData();
  mutate(d);
  const problems = s.soundsProblems(d, refs);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  report(label, ok, JSON.stringify(problems));
}
const ev = (d, id) => d.events[id];
expect('the shipped table is valid', () => {}, null);
expect('a key outside the layout fails', (d) => { ev(d, 'ui.click').key = 'sounds/click'; }, /not in the sound key layout/);
expect('a wrong bus fails', (d) => { ev(d, 'ui.click').bus = 'Effects'; }, /plays on bus UI/);
expect('a positional UI sound fails', (d) => { ev(d, 'ui.click').spatial = '3d'; ev(d, 'ui.click').maxDistance = 5; }, /ui sound is 2d/);
expect('variants on a music file fail', (d) => { ev(d, 'music.main_theme').variants = 2; }, /exactly 1 variant/);
expect('too many variants fail', (d) => { ev(d, 'footstep.grass').variants = 9; }, /variants must be 1\.\.8/);
expect('a non-looping ambience fails', (d) => { ev(d, 'ambience.TemperateForest').loop = false; }, /must have loop true/);
expect('a 3d sound with no range fails', (d) => { delete ev(d, 'footstep.grass').maxDistance; }, /needs maxDistance/);
expect('a range on a 2d sound fails', (d) => { ev(d, 'ui.click').maxDistance = 3; }, /maxDistance is for 3d/);
expect('an unknown item fails', (d) => { ev(d, 'item.StonePick.hit').key = 'sounds/sfx/items/Spoon/hit'; }, /Spoon is not one of the fabric's items/);
expect('an unknown creature fails', (d) => { ev(d, 'creature.GraywolfPack.attack').key = 'sounds/sfx/creatures/Dragon/attack'; }, /Dragon is not one of the fabric's creatures/);
expect('an unknown biome fails', (d) => { ev(d, 'ambience.TemperateForest').key = 'sounds/ambience/Moon'; }, /Moon is not one of the fabric's biomes/);
expect('a shared key fails', (d) => { d.events['ui.click2'] = { ...ev(d, 'ui.click') }; }, /already used by ui\.click/);
expect('a bad event id fails', (d) => { d.events['UI click'] = { ...ev(d, 'ui.click'), key: 'sounds/ui/other' }; }, /id must be/);
expect('a loud volume fails', (d) => { ev(d, 'ui.click').volumeDb = 12; }, /volumeDb must be/);
expect('a huge pitch jitter fails', (d) => { ev(d, 'ui.click').pitchJitter = 0.9; }, /pitchJitter must be/);
expect('a changed bus list fails', (d) => { d.buses = ['Music', 'Effects']; }, /buses must be/);
const files = s.soundFiles({ key: 'sounds/sfx/world/door', variants: 3 });
report('sfx variants are <key>_01.. files', JSON.stringify(files) === JSON.stringify(
  ['sounds/sfx/world/door_01.ogg.raw', 'sounds/sfx/world/door_02.ogg.raw', 'sounds/sfx/world/door_03.ogg.raw']), JSON.stringify(files));
const one = s.soundFiles({ key: 'sounds/ui/open', variants: 1 });
report('a ui sound is one <key>.ogg.raw file', JSON.stringify(one) === JSON.stringify(['sounds/ui/open.ogg.raw']), JSON.stringify(one));
if (failed) { console.error(`${failed} check(s) failed`); process.exit(1); }
console.log('all sound-event checks passed');
