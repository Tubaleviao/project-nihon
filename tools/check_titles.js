#!/usr/bin/env node
// Phase 273 — proves the title validator rejects bad tables: a title with no name in a locale (read from
// locale/content.csv), a duplicated title source, an unknown profession or skill, a missing title for a
// profession state or a skill; the shipped table passes with a name in every locale.
//   node tools/check_titles.js
'use strict';
const fs = require('fs');
const path = require('path');
const t = require('../fabric/gameplay/titles');
const { readCatalog } = require('./check_content_locale');
const refs = t.titlesRefs();
const cat = readCatalog(fs.readFileSync(path.join(__dirname, '..', 'locale', 'content.csv'), 'utf8'));
function names(drop) {
  const out = {};
  for (const l of cat.locales) {
    out[l] = new Set();
    for (const r of cat.rows) {
      const m = /^title\.(.+)\.name$/.exec(r.key);
      if (m && r.cells[l] && !(drop && drop.locale === l && drop.id === m[1])) out[l].add(m[1]);
    }
  }
  return out;
}
let failed = 0;
function expect(label, mutate, pattern, drop) {
  const d = t.titlesData();
  if (mutate) mutate(d);
  const problems = t.titlesProblems(d, refs, names(drop));
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
expect('the shipped table is valid with a name in every locale', null, null);
expect('a title with no pt_BR name fails', null, /MasterSmithing: no pt_BR name/, { locale: 'pt_BR', id: 'MasterSmithing' });
expect('a title with no en name fails', null, /Newcomer: no en name/, { locale: 'en', id: 'Newcomer' });
expect('a duplicated title source fails', (d) => { d.titles.Smith2 = { source: { ...d.titles.MasterSmithing.source } }; }, /Smith2: same source as MasterSmithing/);
expect('an unknown profession fails', (d) => { d.titles.Ghost = { source: { kind: 'profession', id: 'Ghost', state: 'active' } }; }, /unknown profession Ghost/);
expect('an unknown skill fails', (d) => { d.titles.MasterGhost = { source: { kind: 'skill', id: 'Ghost', tier: 'master' } }; }, /unknown skill Ghost/);
expect('a profession with no mastered title fails', (d) => { delete d.titles.MasterBlacksmith; }, /Blacksmith: no title for mastered/);
expect('a skill with no master title fails', (d) => { delete d.titles.MasterMining; }, /Mining: no master title/);
expect('a missing built-in title fails', (d) => { delete d.titles.Newcomer; }, /builtin title Newcomer/);
expect('a skill title below master fails', (d) => { d.titles.MasterMining.source.tier = 'expert'; }, /master tier/);
if (failed) { console.error(`${failed} check(s) failed`); process.exit(1); }
console.log('all title checks passed');
