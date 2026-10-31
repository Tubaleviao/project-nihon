#!/usr/bin/env node
// Phase 203 — proves the writing validator catches bad tables: a book consumed on reading, writing without
// knowing the content, a free book, an unknown cost item or station, a book that teaches a recipe and a
// blueprint that teaches anything but a structure or station all fail; the shipped table passes.
//   node tools/check_writing.js
'use strict';
const w = require('../fabric/gameplay/writing');
const refs = w.writingRefs();
let failed = 0;
function expect(label, mutate, pattern) {
  const d = w.writingData();
  mutate(d);
  const problems = w.writingProblems(d, refs);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

expect('the shipped table is valid', () => {}, null);
expect('a book consumed on reading fails', (d) => { d.Book.consumedOnRead = true; }, /read again and lent/);
expect('writing what the writer does not know fails', (d) => { d.Blueprint.writerMustKnow = false; }, /only a player who knows the content/);
expect('a free book fails', (d) => { d.Book.cost = []; }, /Book\.cost must list at least one/);
expect('an unknown cost item fails', (d) => { d.Book.cost[0].item = 'Ink'; }, /"Ink" is not an item or material/);
expect('an unknown writing station fails', (d) => { d.Blueprint.station = 'scriptorium'; }, /"scriptorium" is not a placeable station type/);
expect('a book that teaches a recipe fails', (d) => { d.Book.teaches = 'recipe'; }, /Book\.teaches must be "technology"/);
expect('a blueprint for anything but a structure or station fails', (d) => { d.Blueprint.recipeKinds = ['weapon']; }, /teaches a structure or station/);
expect('a missing blueprint fails', (d) => { delete d.Blueprint; }, /Writing\.Blueprint is missing/);

let threw = false;
try { const d = w.writingData(); d.Book.consumedOnRead = true; w.validateWriting(d, refs); } catch (e) { threw = true; }
console.log(`${threw ? 'ok  ' : 'FAIL'} validateWriting throws on bad data`);
if (!threw) failed++;
process.exit(failed ? 1 : 0);
