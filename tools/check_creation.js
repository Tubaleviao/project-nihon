#!/usr/bin/env node
// Phase 180 — proves the character-creation validator catches bad data: a gender preset naming a missing
// appearance, a hair style or colour that refers to nothing, a gender without a hair style, a preset outside
// the chibi head ratio and an invalid default all fail, and the shipped fabric passes. Also checks that
// every preset part and hair style has a public placeholder at its key, and every refusal and gender a
// catalog entry in each locale.
//   node tools/check_creation.js
'use strict';
const fs = require('fs');
const path = require('path');
const creation = require('../fabric/gameplay/characters/creation');

const ROOT = path.join(__dirname, '..');
const fresh = () => creation.creationData();
const refs = () => creation.creationRefs();
let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
const check = (d, r = refs()) => creation.creationProblems(d, r);

expect('the shipped creation data is valid', check(fresh()), null);

{ const d = fresh(); d.genders.masculine.appearance = 'NoSuchPreset'; expect('a gender naming a missing appearance is refused', check(d), /appearance NoSuchPreset does not exist/); }
{ const d = fresh(); d.hairStyles.hair_x = { gender: 'neuter', shape: 'crop' }; expect('a hair style of an unknown gender is refused', check(d), /hair hair_x: unknown gender/); }
{ const d = fresh(); d.hairStyles.hair_m_crop.shape = 'afro'; expect('a hair style with an unknown shape is refused', check(d), /unknown shape afro/); }
{ const d = fresh(); for (const [id, h] of Object.entries(d.hairStyles)) if (h.gender === 'feminine') delete d.hairStyles[id];
  if (d.defaultCreation.gender === 'feminine') d.defaultCreation = { gender: 'masculine', hair: 'hair_m_crop', hairColor: d.hairColors[0] };
  expect('a gender without a hair style is refused', check(d), /gender feminine: no hair style/); }
{ const d = fresh(); d.hairColors.push(256); expect('a hair colour outside the palette is refused', check(d), /256 is not a palette index/); }
{ const d = fresh(); d.hairColors.push(d.hairColors[0]); expect('a duplicate hair colour is refused', check(d), /duplicate index/); }
{ const d = fresh(); d.defaultCreation.hair = 'hair_f_bob'; expect('a default with the other gender\'s hair is refused', check(d), /defaultCreation: refused \(hair_gender\)/); }
{ const d = fresh(); d.defaultCreation.hairColor = 0; expect('a default with an unlisted colour is refused', check(d), /defaultCreation: refused \(hair_color\)/); }
{ const d = fresh(); d.startingKit = [{ item: 'GoldenCrown', quantity: 1 }]; expect('a starting kit naming no item is refused', check(d), /GoldenCrown is not an item/); }
{ const r = refs(); r.appearances.NoviceMasculine = { ...r.appearances.NoviceMasculine, proportions: { height: 1, legLength: 1, headScale: 1 } };
  expect('a preset with adult proportions is outside the chibi head ratio', check(fresh(), r), /gender masculine: head-to-height ratio/); }
{ const d = fresh(); d.name.confusables['A'] = 'a'; expect('an upper-case confusable is refused', check(d), /not one lower-case code point/); }
{ const d = fresh(); d.name.maxMarksPerLetter = -1; expect('a negative mark limit is refused', check(d), /maxMarksPerLetter -1/); }
{ const d = fresh(); d.name.reserved.push('Admin'); expect('a reserved name not in skeleton form is refused', check(d), /reserved "Admin"/); }

// The fold table comes from Unicode NFD: a few spot checks.
const fold = fresh().name.accentFold;
expect('accent fold covers é, ã, ç, ñ, ё and ά', ['é', 'ã', 'ç', 'ñ', 'ё', 'ά'].filter((c) => !fold[c]), null);

// Every part a preset or hair style names has a public placeholder (placeholder rule) and a manifest entry.
{
  const manifest = JSON.parse(fs.readFileSync(path.join(ROOT, 'assets/manifest.json'), 'utf8'));
  const keys = [];
  const d = fresh();
  const apps = refs().appearances;
  for (const g of Object.values(d.genders)) {
    const a = apps[g.appearance];
    keys.push(['meshes', `models/characters/bodies/${a.body}.glb.raw`], ['meshes', `models/characters/heads/${a.head}.glb.raw`],
      ['textures', `textures/characters/eyes/${a.eyes}.png.raw`]);
  }
  for (const id of Object.keys(d.hairStyles)) keys.push(['meshes', `models/characters/hair/${id}.glb.raw`], ['textures', `icons/hair/${id}.png.raw`]);
  // Item icons are read by key without a manifest entry (gen_item_assets.py), so only the file is required.
  for (const k of d.startingKit) keys.push(['meshes', `models/items/${k.item}.glb.raw`], [null, `icons/items/${k.item}.png.raw`]);
  const missing = keys.filter(([sec, k]) => !fs.existsSync(path.join(ROOT, 'assets', k)) || (sec && manifest[sec][k] !== k)).map(([, k]) => k);
  expect('every preset part, hair style and kit item has a placeholder and a manifest entry', missing, null);
}

// Every refusal and gender label is in both catalogs.
{
  const text = fs.readFileSync(path.join(ROOT, 'locale/ui.csv'), 'utf8');
  const rows = new Map(text.split('\n').map((l) => [l.split(',')[0], l]));
  const want = [...creation.REFUSALS.map(creation.refusalKey), ...Object.keys(creation.GENDERS).map(creation.genderKey)];
  const missing = want.filter((k) => { const r = rows.get(k); return !r || r.split(',').length < 3 || r.split(',').slice(1).some((c) => !c.trim()); });
  expect('every refusal and gender has en and pt_BR catalog entries', missing, null);
}

if (failed) { console.error(`${failed} check(s) failed`); process.exit(1); }
console.log('all creation checks passed');
