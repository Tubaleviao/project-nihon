#!/usr/bin/env node
// Phase 226 — proves the character-roster validator rejects bad tables: inventory, skills or any other progress put
// on the player instead of the character, the friend code or admin flag put on the character, an owner that is
// neither, a save-record key with no owner, a character limit out of range, an unknown delete policy, names unique
// per player instead of per server, and a refusal that is not a locale key. Then checks the shipped data.
//   node tools/check_character_roster.js
'use strict';
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
for (const f of r.PLAYER_FIELDS) {
  expect(`${f} on the character fails`, (d) => { d.ownership[f] = 'character'; }, new RegExp(`^${f} is on the character, not the player`));
}
expect('an owner that is neither fails', (d) => { d.ownership.titles = 'clan'; }, /ownership\.titles: "clan" is not one of/);

// Every key of today's save record moves somewhere.
expect('a record key with no owner fails', (d) => { delete d.recordKeys.skill_xp; }, /recordKeys has no skill_xp/);
expect('a record key naming no field fails', (d) => { d.recordKeys.inventory = 'pack'; }, /recordKeys\.inventory: "pack" is not an ownership field/);

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

if (failed) {
  console.error(`\n${failed} check(s) failed`);
  process.exit(1);
}
console.log('\nall character-roster checks passed');
