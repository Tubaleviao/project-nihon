#!/usr/bin/env node
// Phase 177 — proves the attribute validator catches bad data: inconsistent bounds, a derived stat naming
// an unknown attribute, extremes (all 5s, all 30s) outside a stat's clamp, base 10 not reproducing today's
// constants, and a skill category without a growth row all fail, and the shipped fabric passes.
//   node tools/check_attributes.js
'use strict';
const attributes = require('../fabric/gameplay/attributes');
const harvest = require('../fabric/gameplay/harvest');
const { SKILL_CATEGORIES } = require('../fabric/gameplay/skills/shared');

const fresh = () => attributes.attributeData();
let failed = 0;
function expect(label, problems, pattern) {
  const ok = pattern === null ? problems.length === 0 : problems.some((p) => pattern.test(p));
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ' — ' + JSON.stringify(problems)}`);
  if (!ok) failed++;
}
const check = (d) => attributes.attributeProblems(d);

expect('the shipped attribute data is valid', check(fresh()), null);

// Base 10 reproduces today's constants.
const atBase = attributes.deriveAll(attributes.uniform(attributes.BOUNDS.base));
const today = [
  ['carry capacity 40 kg', atBase.carryCapacityKg === 40],
  ['max HP 100 (PlayerRules.MAX_HP)', atBase.maxHp === 100],
  ['HP regeneration 0.25/s (GestureRules.BASE_HP_REGEN_PER_S)', atBase.hpRegenPerSecond === 0.25],
  ['every factor is 1 and every chance and bonus 0', Object.entries(attributes.DERIVATION).every(([id, r]) =>
    atBase[id] === (r.kind === 'factor' ? 1 : r.kind === 'amount' ? r.base : 0))],
  ['harvest base capacity equals the Strength derivation at base', harvest.BASE_CARRY_CAPACITY_KG === atBase.carryCapacityKg],
];
for (const [label, ok] of today) expect(`at base 10: ${label}`, ok ? [] : ['mismatch'], null);

// The extremes stay inside each clamp and move every stat.
const low = attributes.deriveAll(attributes.uniform(attributes.BOUNDS.creationMin));
const high = attributes.deriveAll(attributes.uniform(attributes.BOUNDS.hardCap));
expect('all 5s and all 30s stay inside every clamp', Object.entries(attributes.DERIVATION).flatMap(([id, r]) =>
  [low[id], high[id]].filter((v) => v < r.min || v > r.max).map((v) => `${id} ${v}`)), null);
expect('all 30s change every derived stat', Object.keys(attributes.DERIVATION).filter((id) => high[id] === atBase[id]), null);
expect('every skill category has a growth row', SKILL_CATEGORIES.filter((c) => !(c in attributes.GROWTH.categories)), null);

// Every attribute and derived stat has a non-empty name (and an attribute a description) in every locale.
{
  const lines = require('fs').readFileSync(require('path').join(__dirname, '../locale/ui.csv'), 'utf8').split('\n').filter(Boolean);
  const cells = (line) => {
    const out = []; let cur = ''; let q = false;
    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (q) { if (c === '"' && line[i + 1] === '"') { cur += '"'; i++ } else if (c === '"') q = false; else cur += c }
      else if (c === '"') q = true; else if (c === ',') { out.push(cur); cur = '' } else cur += c;
    }
    return out.concat([cur]);
  };
  const header = cells(lines[0]);
  const rows = new Map(lines.slice(1).map((l) => { const c = cells(l); return [c[0], c] }));
  const keys = [...attributes.ATTRIBUTES.flatMap((a) => [attributes.nameKey(a), attributes.descKey(a)]),
    ...Object.keys(attributes.DERIVATION).map(attributes.statKey)];
  const missing = [];
  for (const k of keys) header.slice(1).forEach((loc, i) => { const r = rows.get(k); if (!r || !(r[i + 1] || '').trim()) missing.push(`${loc} ${k}`) });
  expect(`every attribute and derived stat has a catalog entry in ${header.slice(1).join(' and ')}`, missing, null);
}

const bounds = fresh(); bounds.bounds.creationMax = 35;
expect('creationMax above the hard cap fails', check(bounds), /bounds must satisfy/);

const order = fresh(); order.bounds.creationMin = 12;
expect('creationMin above the base fails', check(order), /bounds must satisfy/);

const unknown = fresh(); unknown.derivation.maxHp.attribute = 'charisma';
expect('a derived stat naming an unknown attribute fails', check(unknown), /maxHp names unknown attribute "charisma"/);

const steep = fresh(); steep.derivation.maxHp.perPoint = 20;
expect('a slope that leaves the clamp at the hard cap fails', check(steep), /maxHp: the hard cap \(30\) gives 500/);

const lowEnd = fresh(); lowEnd.derivation.carryCapacityKg.min = 35;
expect('a clamp the creation minimum falls below fails', check(lowEnd), /carryCapacityKg: the creation minimum \(5\) gives 30/);

const drift = fresh(); drift.derivation.maxHp.base = 120; drift.derivation.maxHp.max = 250;
expect('a base that no longer reproduces today\'s max HP fails', check(drift), /maxHp is an amount, so its base must equal today's constant 100/);

const factor = fresh(); factor.derivation.researchGainFactor.base = 1.1;
expect('a factor whose base is not 1 fails', check(factor), /researchGainFactor is a factor, so its base must be 1/);

const oneShot = fresh(); oneShot.derivation.meleeDamageFactor.max = 4; oneShot.derivation.meleeDamageFactor.perPoint = 0.1;
expect('a factor clamp large enough for a one-shot fails', check(oneShot), /meleeDamageFactor: clamp .* one-shot/);

const flat = fresh(); flat.derivation.moveSpeedFactor.perPoint = 0.001; flat.derivation.moveSpeedFactor.perPointBelow = 0.001;
expect('a stat the hard cap barely moves fails', check(flat), /moveSpeedFactor: the hard cap moves it by less than 5%/);

const zero = fresh(); zero.derivation.dodgeChance.perPoint = 0;
expect('a zero slope fails', check(zero), /dodgeChance\.perPoint must not be 0/);

const sign = fresh(); sign.derivation.dodgeChance.perPointBelow = -0.01;
expect('a below-base slope with the opposite sign fails', check(sign), /dodgeChance\.perPointBelow must be 0 or share/);

const orphan = fresh(); for (const r of Object.values(orphan.derivation)) if (r.attribute === 'perception') r.attribute = 'agility';
expect('an attribute that feeds nothing fails', check(orphan), /attribute perception feeds no derived stat/);

const noRow = fresh(); delete noRow.growth.categories.magic;
expect('a skill category without a growth row fails', check(noRow), /skill category magic has no growth row/);

const extraRow = fresh(); extraRow.growth.categories.cooking = { strength: 1 };
expect('a growth row for an unknown category fails', check(extraRow), /growth row cooking is not a skill category/);

const sum = fresh(); sum.growth.categories.combat.strength = 0.8;
expect('growth weights that do not sum to 1 fail', check(sum), /growth row combat weights sum to 1\.3/);

const badAttr = fresh(); badAttr.growth.categories.social = { charm: 1 };
expect('a growth row naming an unknown attribute fails', check(badAttr), /growth row social names unknown attribute "charm"/);

const noDim = fresh(); noDim.growth.costStep = 0;
expect('growth without diminishing returns fails', check(noDim), /costStep must be > 0/);

const cap = fresh(); cap.growth.totalPointsCap = 500;
expect('a total cap the hard cap cannot hold fails', check(cap), /totalPointsCap 500 exceeds/);

let threw = false;
try { attributes.validateAttributes(noRow); } catch (e) { threw = true; }
expect('validateAttributes throws on bad data', threw ? [] : ['did not throw'], null);

process.exit(failed ? 1 : 0);
