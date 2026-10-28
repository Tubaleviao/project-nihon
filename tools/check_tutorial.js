#!/usr/bin/env node
// Phase 184 — proves the tutorial validator catches bad tables: a duplicate step id, a forward or
// self `requires`, an unknown trigger kind, a trigger with a wrong or missing param, a param naming
// nothing (item, tag, station type, window, slot, technology) and a missing catalog key all fail,
// and the shipped fabric passes against both catalog columns. Also checks the bed rule.
//   node tools/check_tutorial.js
'use strict';
const fs = require('fs');
const path = require('path');
const tutorial = require('../fabric/gameplay/tutorial');
const bed = require('../fabric/gameplay/bed');
const items = require('../fabric/gameplay/items');

let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

// Every locale column of locale/ui.csv as a Set of keys. A quoted cell may span lines, so parse the
// whole file rather than splitting on newlines.
function catalog() {
  const text = fs.readFileSync(path.join(__dirname, '../locale/ui.csv'), 'utf8');
  const records = []; let rec = []; let cur = ''; let q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) { if (c === '"' && text[i + 1] === '"') { cur += '"'; i++ } else if (c === '"') q = false; else cur += c }
    else if (c === '"') q = true;
    else if (c === ',') { rec.push(cur); cur = '' }
    else if (c === '\n' || c === '\r') { if (c === '\r' && text[i + 1] === '\n') i++; rec.push(cur); cur = ''; if (rec.some(Boolean)) records.push(rec); rec = [] }
    else cur += c;
  }
  rec.push(cur); if (rec.some(Boolean)) records.push(rec);
  const header = records[0];
  const out = {};
  for (let col = 1; col < header.length; col++) {
    out[header[col]] = new Set(records.slice(1).filter((r) => (r[col] || '').trim() !== '').map((r) => r[0]));
  }
  return out;
}

const refs = { ...tutorial.tutorialRefs(), catalog: catalog() };
const fresh = () => tutorial.tutorialData();
const check = (d, r = refs) => tutorial.tutorialProblems(d, r);
const withStep = (mutate) => { const d = fresh(); mutate(d.steps); return d; };

expect('the shipped tutorial is valid against both catalog columns', check(fresh()), null);
expect('the catalog has an en and a pt_BR column', ['en', 'pt_BR'].every((l) => l in refs.catalog) ? [] : Object.keys(refs.catalog), null);

// The four the roadmap names.
expect('a duplicate step id fails', check(withStep((s) => s.push({ ...s[1] }))), /duplicate id "jump"/);
expect('a forward requires fails', check(withStep((s) => { s[0].requires = ['jump'] })), /requires "jump", which is not an earlier step/);
expect('an unknown trigger kind fails', check(withStep((s) => { s[0].trigger = { kind: 'teleported' } })), /unknown trigger kind "teleported"/);
expect('a missing catalog key fails', check(fresh(), { ...refs, catalog: { ...refs.catalog, pt_BR: new Set([...refs.catalog.pt_BR].filter((k) => k !== 'tutorial.chop.body')) } }), /catalog pt_BR has no key tutorial\.chop\.body/);

// Cycles and shape.
expect('a step requiring itself fails', check(withStep((s) => { s[1].requires = ['jump'] })), /requires itself/);
expect('a cycle (a requires b requires a) fails', check(withStep((s) => { s[0].requires = ['jump']; s[1].requires = ['move'] })), /not an earlier step/);
expect('a non-snake_case id fails', check(withStep((s) => { s[0].id = 'Move-Step' })), /snake_case/);
expect('an unknown chapter fails', check(withStep((s) => { s[0].chapter = 'endgame' })), /unknown chapter "endgame"/);
expect('a split chapter fails', check(withStep((s) => { s.push({ ...s[0], id: 'late_move', requires: [] }) })), /chapter "moving" is split/);
expect('an unknown input action fails', check(withStep((s) => { s[0].inputs = ['teleport'] })), /unknown input action "teleport"/);
expect('a chapter with no step fails', check({ ...fresh(), chapters: [...fresh().chapters, 'endgame'] }), /chapter "endgame" has no step/);

// Trigger params.
expect('a missing required param fails', check(withStep((s) => { s[0].trigger = { kind: 'moved_metres' } })), /moved_metres needs "metres"/);
expect('both item and tag fails', check(withStep((s) => { s[5].trigger = { kind: 'item_gathered', item: 'Thornwood', tag: 'material', count: 1 } })), /exactly one of item, tag/);
expect('an extra param fails', check(withStep((s) => { s[1].trigger = { kind: 'jumped', count: 2 } })), /jumped takes no "count"/);
expect('a zero count fails', check(withStep((s) => { s[5].trigger.count = 0 })), /count must be an integer >= 1/);
expect('an unknown item fails', check(withStep((s) => { s[5].trigger.item = 'Unobtainium' })), /item "Unobtainium" does not exist/);
expect('a tag naming nothing fails', check(withStep((s) => { s[4].trigger.tag = 'spaceship' })), /tag "spaceship" names nothing/);
expect('an unplaceable station type fails', check(withStep((s) => { s.find((x) => x.id === 'place_bench').trigger.type = 'moon base' })), /station type "moon base" is not placeable/);
expect('an unknown window fails', check(withStep((s) => { s[3].trigger.window = 'cheats' })), /window "cheats" does not exist/);
expect('an unknown equipment slot fails', check(withStep((s) => { s.find((x) => x.id === 'equip_weapon').trigger.slot = 'Tail' })), /equipment slot "Tail" does not exist/);
expect('an unknown technology fails', check(withStep((s) => { s.find((x) => x.id === 'research_carpentry').trigger.technology = 'TechWarp' })), /technology "TechWarp" does not exist/);
expect('validateTutorial throws on a bad table', (() => { try { tutorial.validateTutorial(withStep((s) => { s[0].trigger = { kind: 'nope' } }), refs); return [] } catch (e) { return [e.message] } })(), /unknown trigger kind/);

// The shipped references resolve: the bed is placeable, and the axe and pick tags name tools.
expect('bed is a placeable station type', refs.stationTypes.includes(bed.RULES.stationType) ? [] : refs.stationTypes, null);
expect('the pick tag names a tool', (refs.tags.pick || []).includes('FerritePick') ? [] : [JSON.stringify(refs.tags.pick)], null);

// The bed rule.
const itemKeys = Object.keys(items);
const bedWith = (patch) => ({ ...JSON.parse(JSON.stringify(bed.RULES)), ...patch });
const shelterWith = (patch) => bedWith({ shelter: { ...bed.RULES.shelter, ...patch } });
expect('the shipped bed rule is valid', bed.bedProblems(bed.RULES, itemKeys), null);
expect('a placement item that is not an item fails', bed.bedProblems(bedWith({ placementItem: 'Cot' }), itemKeys), /placementItem "Cot"/);
expect('perPlayer 0 fails', bed.bedProblems(bedWith({ perPlayer: 0 }), itemKeys), /perPlayer/);
expect('a notice outside bed.* fails', bed.bedProblems(bedWith({ notices: { lost: 'You lost your bed' } }), itemKeys), /notices\.lost/);
expect('minClosedSides 5 fails', bed.bedProblems(shelterWith({ minClosedSides: 5 }), itemKeys), /minClosedSides/);
expect('a wall check above the roof fails', bed.bedProblems(shelterWith({ wallCheckMetres: 4 }), itemKeys), /below roofWithinMetres/);
expect('an unknown shelter field fails', bed.bedProblems(shelterWith({ doors: 1 }), itemKeys), /unknown field "doors"/);
expect('every bed notice is in both catalog columns', Object.entries(refs.catalog).flatMap(([loc, keys]) =>
  Object.values(bed.RULES.notices).filter((k) => !keys.has(k)).map((k) => `${loc}: ${k}`)), null);

process.exit(failed ? 1 : 0);
