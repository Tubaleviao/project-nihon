#!/usr/bin/env node
// Phase 267 — the content catalog gate. `locale/content.csv` (columns `keys,en,pt_BR,...`) must name every
// player-visible fabric entity in every locale column: every item and material (materials sit in packs),
// recipe (or its first output's item), technology, skill, profession and placeable station. A key for an
// entity that no longer exists, a key of an unknown kind or field, and a duplicate key fail too.
// It first proves it rejects a missing pt_BR name and a stale key, then checks the shipped catalog.
//   node tools/check_content_locale.js
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const CATALOG = path.join(ROOT, 'locale', 'content.csv');
// Phase 274 — `category.<id>.name` names each skill category (skills/shared.js SKILL_CATEGORIES).
const FIELDS = { item: ['name', 'desc'], recipe: ['name'], tech: ['name', 'desc'], skill: ['name', 'desc'], profession: ['name'], station: ['name'], category: ['name'], title: ['name'] };

// RFC 4180: quoted cells may hold commas, quotes ("") and newlines.
function parseCsv(text) {
  const rows = [];
  let row = [], cell = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { cell += '"'; i++; }
      else if (c === '"') quoted = false;
      else cell += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(cell); cell = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(cell); rows.push(row); row = []; cell = '';
    } else cell += c;
  }
  if (cell !== '' || row.length) { row.push(cell); rows.push(row); }
  return rows.filter((r) => r.length && r[0].trim() !== '');
}

// { locales: [..], rows: [{ key, cells: { locale: text } }] }
function readCatalog(text) {
  const [header, ...body] = parseCsv(text);
  const locales = header.slice(1).map((s) => s.trim()).filter(Boolean);
  return {
    locales,
    rows: body.map((r) => ({ key: r[0].trim(), cells: Object.fromEntries(locales.map((l, i) => [l, (r[i + 1] || '').trim()])) })),
  };
}

const stationKey = (type) => type.replace(/ /g, '_');

// The player-visible entities, from the fabric: { item: Set, recipe: Map(id -> first output), ... }.
function fabricRefs() {
  const e = require('../fabric').entities;
  const dv = (ent, f) => ent && ent.fields && ent.fields[f] && ent.fields[f].defaultValue;
  const tagged = (t) => Object.keys(e).filter((k) => (e[k].tags || []).includes(t));
  const recipes = new Map();
  const stations = new Set();
  for (const id of tagged('recipe')) {
    const r = dv(e[id], 'recipe') || {};
    recipes.set(id, ((r.outputs || [])[0] || {}).item || '');
    if (r.station) stations.add(r.station);
  }
  for (const id of tagged('item')) {
    const rep = dv(e[id], 'repair');
    if (rep && rep.station) stations.add(rep.station);
  }
  // The stations placed without a recipe naming them (StationSlice.placeable_station_types).
  const rules = (n) => dv(e[n], 'rules') || {};
  for (const s of [rules('WaystoneTravel').stationType, rules('Settlement').hearthStation, rules('BedSpawn').stationType, ...Object.keys(rules('ChestsAndDoors').stations || {})]) {
    if (s) stations.add(s);
  }
  // Every item id a table names (creature drops, recipe inputs, costs...) can sit in a pack too.
  const named = new Set();
  const walk = (o) => {
    if (Array.isArray(o)) o.forEach(walk);
    else if (o && typeof o === 'object') {
      for (const [k, v] of Object.entries(o)) {
        if ((k === 'item' || k === 'itemId') && typeof v === 'string' && v !== '') named.add(v);
        walk(v);
      }
    }
  };
  for (const id of Object.keys(e)) walk(e[id].fields);
  return {
    item: new Set([...tagged('item'), ...tagged('material'), ...named]),
    recipe: recipes,
    tech: new Set(tagged('technology')),
    skill: new Set(tagged('skill')),
    profession: new Set(tagged('profession')),
    station: new Set([...stations].map(stationKey)),
    category: new Set(require('../fabric/gameplay/skills/shared').SKILL_CATEGORIES),
    title: new Set(Object.keys(require('../fabric/gameplay/titles').titlesData().titles)),
  };
}

function contentLocaleProblems(cat, refs) {
  const problems = [];
  const have = new Map();
  for (const { key, cells } of cat.rows) {
    if (have.has(key)) problems.push(`${key}: duplicate key`);
    have.set(key, cells);
    const m = /^([a-z]+)\.(.+)\.([a-z]+)$/.exec(key);
    if (!m || !FIELDS[m[1]]) { problems.push(`${key}: not <kind>.<Id>.<field> with a known kind`); continue; }
    const [, kind, id, field] = m;
    if (!FIELDS[kind].includes(field)) problems.push(`${key}: ${kind} has no field ${field}`);
    if (!refs[kind].has(id)) problems.push(`${key}: stale key, no ${kind} ${id} in the fabric`);
    for (const l of cat.locales) if (!cells[l]) problems.push(`${key}: empty ${l} cell`);
  }
  const named = (key, l) => have.has(key) && have.get(key)[l];
  for (const l of cat.locales) {
    for (const kind of ['item', 'tech', 'skill', 'profession', 'station', 'category', 'title']) {
      for (const id of refs[kind]) if (!named(`${kind}.${id}.name`, l)) problems.push(`${kind}.${id}.name: no ${l} name`);
    }
    for (const [id, out] of refs.recipe) {
      if (!named(`recipe.${id}.name`, l) && !named(`item.${out}.name`, l)) problems.push(`recipe.${id}.name: no ${l} name (nor its output ${out || 'none'})`);
    }
  }
  return problems;
}

module.exports = { parseCsv, readCatalog, fabricRefs, contentLocaleProblems };

if (require.main === module) {
  const text = fs.readFileSync(CATALOG, 'utf8');
  const refs = fabricRefs();
  let failed = 0;
  function expect(label, mutate, pattern) {
    const cat = readCatalog(text);
    mutate(cat);
    const problems = contentLocaleProblems(cat, refs);
    const ok = problems.some((p) => pattern.test(p));
    console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems.slice(0, 5))}`);
    if (!ok) failed++;
  }
  const row = (cat, key) => cat.rows.find((r) => r.key === key);
  expect('a missing pt_BR item name fails', (c) => { row(c, 'item.FerritePick.name').cells.pt_BR = ''; }, /item\.FerritePick\.name: (no pt_BR name|empty pt_BR cell)/);
  expect('a missing skill row fails', (c) => { c.rows = c.rows.filter((r) => r.key !== 'skill.Tailoring.name'); }, /skill\.Tailoring\.name: no en name/);
  expect('a stale key fails', (c) => { c.rows.push({ key: 'item.RemovedSword.name', cells: { en: 'Removed', pt_BR: 'Removida' } }); }, /item\.RemovedSword\.name: stale key/);
  expect('an unknown kind fails', (c) => { c.rows.push({ key: 'creature.ForestBoar.name', cells: { en: 'Boar', pt_BR: 'Javali' } }); }, /not <kind>/);
  expect('a duplicate key fails', (c) => { c.rows.push({ ...row(c, 'tech.TechSteel.name') }); }, /tech\.TechSteel\.name: duplicate key/);
  expect('a skill category with no name fails', (c) => { c.rows = c.rows.filter((r) => r.key !== 'category.gathering.name'); }, /category\.gathering\.name: no en name/);
  expect('a station with no name fails', (c) => { c.rows = c.rows.filter((r) => r.key !== 'station.master_forge.name'); }, /station\.master_forge\.name: no en name/);
  expect('a recipe with neither its own nor its output name fails', (c) => {
    c.rows = c.rows.filter((r) => r.key !== 'recipe.RecipeHealthPotion.name' && r.key !== 'item.AlchemyPotion.name');
  }, /recipe\.RecipeHealthPotion\.name: no en name/);
  const problems = contentLocaleProblems(readCatalog(text), refs);
  console.log(`${problems.length ? 'FAIL' : 'ok  '} the shipped catalog names every player-visible entity in every locale`);
  for (const p of problems) console.error(`  ${p}`);
  if (problems.length) failed++;
  if (failed) { console.error(`${failed} check(s) failed`); process.exit(1); }
  console.log('all content-locale checks passed');
}
