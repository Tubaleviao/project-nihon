#!/usr/bin/env node
// Phase 226 — proves the character-roster validator rejects bad tables: any ownership field moved to the other owner
// (inventory or skills on the player, the friend code on the character…), a missing or unknown field, an owner that
// is neither, a save-record key with no owner or moved onto the player, a world section not keyed by character, a
// character limit out of range, an unknown delete policy, names unique per player instead of per server, and a
// refusal that is not a locale key. Then checks the shipped data, and that `recordKeys` names every key the runtime
// writes on a player record today (PlayerRegistry and BedStore), so the migration table cannot drift from the code.
//   node tools/check_character_roster.js
'use strict';
const fs = require('fs');
const path = require('path');
const r = require('../fabric/gameplay/character_roster');
let failed = 0;
function report(label, ok, detail) {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(detail)}`);
  if (!ok) failed++;
}
function expect(label, mutate, pattern) {
  const d = r.characterRosterData();
  mutate(d);
  const problems = r.characterRosterProblems(d);
  report(label, pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p)), problems.slice(0, 6));
}

expect('the shipped table is valid', () => {}, null);

// Progress on the player: a second character would inherit it.
expect('inventory on the player fails', (d) => { d.ownership.inventory = 'player'; }, /inventory is on the player, not the character/);
expect('skills on the player fails', (d) => { d.ownership.skills = 'player'; }, /skills is on the player, not the character/);
for (const f of r.CHARACTER_FIELDS) {
  expect(`${f} on the player fails`, (d) => { d.ownership[f] = 'player'; }, new RegExp(`^${f} is on the player`));
  expect(`${f} missing from the table fails`, (d) => { delete d.ownership[f]; }, new RegExp(`ownership has no ${f}`));
}
// Who connects on the character.
for (const f of r.PLAYER_FIELDS.concat(['lastCharacter'])) {
  expect(`${f} on the character fails`, (d) => { d.ownership[f] = 'character'; }, new RegExp(`^${f} is on the character, not the player`));
}
// Every field is pinned, not only the ones the spec names.
for (const f of ['titles', 'waystones', 'companions', 'tamingFlags', 'hp', 'position', 'spawnPoint']) {
  expect(`${f} on the player fails`, (d) => { d.ownership[f] = 'player'; }, new RegExp(`^${f} is on the player`));
}
expect('an unknown ownership field fails', (d) => { d.ownership.mood = 'character'; }, /ownership\.mood is not a known field/);
expect('an owner that is neither fails', (d) => { d.ownership.titles = 'clan'; }, /ownership\.titles: "clan" is not one of/);

// Every key of today's save record moves somewhere.
expect('a record key with no owner fails', (d) => { delete d.recordKeys.skill_xp; }, /recordKeys has no skill_xp/);
expect('a record key naming no field fails', (d) => { d.recordKeys.inventory = 'pack'; }, /recordKeys\.inventory: "pack" is not an ownership field/);
expect('a record key moved onto the player fails', (d) => { d.recordKeys.inventory = 'admin'; }, /recordKeys\.inventory moves to admin, which is the player's/);
expect('a world section not keyed by character fails', (d) => { d.worldKeys.structures = 'player'; }, /worldKeys\.structures must key on the character/);
expect('a missing world section fails', (d) => { delete d.worldKeys.clans; }, /worldKeys\.clans must key on the character/);

// Limit, delete policy, names, confirmation, migration.
expect('a limit of 0 fails', (d) => { d.limit = 0; }, /limit must be an integer/);
expect('a limit over the range fails', (d) => { d.limit = 99; }, /limit must be an integer/);
expect('a fractional limit fails', (d) => { d.limit = 2.5; }, /limit must be an integer/);
expect('an unknown delete policy fails', (d) => { d.onDelete = 'heir'; }, /onDelete must be one of/);
expect('ownerless is a valid delete policy', (d) => { d.onDelete = 'ownerless'; }, null);
expect('names unique per player fail', (d) => { d.names = 'player'; }, /names must be unique per server/);
expect('a delete confirmed by a click fails', (d) => { d.deleteConfirm = 'click'; }, /deleteConfirm must be "name"/);
expect('a migration that drops the old record fails', (d) => { d.migration = 'fresh'; }, /migration must be "firstCharacter"/);
expect('a refusal that is prose fails', (d) => { d.refusals.limit = 'Too many characters'; }, /refusals\.limit must be a locale key/);
expect('a missing refusal fails', (d) => { delete d.refusals.confirm; }, /refusals\.confirm must be a locale key/);

// The shipped data.
const d = r.characterRosterData();
report('names are unique across the server, as creation\'s name_taken', d.names === 'server' && d.refusals.nameTaken === 'creation.refuse.name_taken', d.refusals);
report('a player keeps more than one character', d.limit > 1, d.limit);
report('every character field the spec lists is the character\'s',
  ['body', 'name', 'inventory', 'equipment', 'skills', 'attributes', 'research', 'booksLearned', 'clanMembership', 'ownedStructures', 'spawnBed']
    .every((f) => d.ownership[f] === 'character'), d.ownership);
report('friend code, settings and the admin flag are the player\'s',
  ['friendCode', 'settings', 'admin'].every((f) => d.ownership[f] === 'player'), d.ownership);

// The runtime's player record today: every key PlayerRegistry and BedStore write must have an owner in recordKeys.
const root = path.join(__dirname, '..');
const reg = fs.readFileSync(path.join(root, 'src/persistence/player_registry.gd'), 'utf8');
const bed = fs.readFileSync(path.join(root, 'src/world/bed_store.gd'), 'utf8');
function funcBody(src, name) {
  const i = src.indexOf('func ' + name + '(');
  if (i < 0) return null;
  const j = src.indexOf('\nfunc ', i + 1);
  return src.slice(i, j < 0 ? undefined : j);
}
const written = new Set();
const ensure = funcBody(reg, 'ensure_player');
const save = funcBody(reg, 'get_player_data');
report('PlayerRegistry still has ensure_player and get_player_data to read keys from', ensure !== null && save !== null, null);
if (ensure) for (const m of ensure.matchAll(/^\t\t\t"([a-z_]+)"\s*:/gm)) written.add(m[1]);
if (save) {
  for (const m of save.matchAll(/^\t\t"([a-z_]+)"\s*:/gm)) written.add(m[1]);
  for (const m of save.matchAll(/data\["([a-z_]+)"\]\s*=/g)) written.add(m[1]);
}
for (const src of [reg, bed]) for (const m of src.matchAll(/rec\["([a-z_]+)"\]\s*=/g)) written.add(m[1]);
const unowned = [...written].filter((k) => !Object.hasOwn(d.recordKeys, k)).sort();
report(`every key the runtime writes on a player record has an owner (${written.size} keys)`, unowned.length === 0, unowned);
report('the scan found the record (position, inventory, bed_station)', ['position', 'inventory', 'bed_station'].every((k) => written.has(k)), [...written]);

if (failed) {
  console.error(`\n${failed} check(s) failed`);
  process.exit(1);
}
console.log('\nall character-roster checks passed');
