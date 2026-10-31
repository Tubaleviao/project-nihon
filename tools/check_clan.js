#!/usr/bin/env node
// Phase 203 — proves the clan validator catches bad tables: a second clan per player, a member cap, a hearth,
// an outsider seeing skills, unlimited private messages, a migration that loses names or roles, a rarity weight
// that falls, tiers out of order and a tier that gives something all fail; the shipped tables pass.
//   node tools/check_clan.js
'use strict';
const c = require('../fabric/gameplay/clan');
const refs = c.clanRefs();
let failed = 0;
function expect(label, mutate, pattern) {
  const d = c.clanData();
  mutate(d);
  const problems = c.clanProblems(d, refs);
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}

expect('the shipped tables are valid', () => {}, null);
expect('two clans per player fails', (d) => { d.clan.maxClansPerPlayer = 2; }, /at most one clan/);
expect('a member cap fails', (d) => { d.clan.maxMembers = 50; }, /any number of members/);
expect('a clan hearth fails', (d) => { d.clan.hasHearth = true; }, /hasHearth must be false/);
expect('names not unique by skeleton fail', (d) => { d.clan.name.uniqueBy = 'exact'; }, /uniqueBy must be "skeleton"/);
expect('names outside the character-name rules fail', (d) => { d.clan.name.rules = 'none'; }, /checked as character names are/);
expect('a name shorter than a character name fails', (d) => { d.clan.name.minLength = 1; }, /below the character-name minimum/);
expect('a founder who cannot kick fails', (d) => { d.clan.roles.founder.kick = false; }, /founder holds every permission/);
expect('skills shown to outsiders fail', (d) => { d.clan.roster.skillsVisibleTo = 'everyone'; }, /outsider never sees/);
expect('unlimited private messages fail', (d) => { d.clan.messages.perMinute = 0; }, /rate-limited/);
expect('a migration that renames fails', (d) => { d.clan.migration.name = 'default'; }, /migration\.name must be "same"/);
expect('a migration that drops roles fails', (d) => { delete d.clan.roles.guest; }, /roles\.guest is missing/);
expect('a migration that keeps the hearth fails', (d) => { d.clan.migration.hearth = 'keep'; }, /returnToFounder/);
expect('a rarer material weighing less fails', (d) => { d.tiers.rarityWeight.epic = 3; }, /rarityWeight\.epic must be a number above/);
expect('tier thresholds out of order fail', (d) => { d.tiers.tiers[2].minScore = 100; }, /tiers\[2\]\.minScore must rise/);
expect('a first tier above zero fails', (d) => { d.tiers.tiers[0].minScore = 5; }, /every clan has a tier/);
expect('a tier that gives something fails', (d) => { d.tiers.gives = ['craftSpeed']; }, /gives nothing yet/);

let threw = false;
try { const d = c.clanData(); d.clan.maxClansPerPlayer = 3; c.validateClan(d, refs); } catch (e) { threw = true; }
console.log(`${threw ? 'ok  ' : 'FAIL'} validateClan throws on bad data`);
if (!threw) failed++;
process.exit(failed ? 1 : 0);
