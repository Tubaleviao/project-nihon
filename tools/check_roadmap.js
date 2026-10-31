#!/usr/bin/env node
// Keeps ROADMAP.md's phase index honest (Phase 146).
//   node tools/check_roadmap.js            check ROADMAP.md, then prove the check rejects bad fixtures
//   node tools/check_roadmap.js <file>     check one roadmap file only
const fs = require('fs');
const path = require('path');

const STATUSES = new Set(['Planned', 'On hold', 'In review', 'Done', 'Merged']);

function sections(text) {
  const out = new Map();
  const lines = text.split('\n');
  let cur = null;
  for (const line of lines) {
    const m = /^## Phase (\d+)\b/.exec(line);
    if (m) { cur = { n: Number(m[1]), body: [] }; out.set(cur.n, cur); continue; }
    if (/^## /.test(line)) cur = null;
    if (cur) cur.body.push(line);
  }
  return out;
}

// Returns a list of error strings. `baseDir` resolves history links.
function check(text, baseDir) {
  const errors = [];
  const secs = sections(text);
  const rows = [];
  for (const line of text.split('\n')) {
    const m = /^\| (\d+) \| (.*?) \| (.*?) \| (.*?) \|$/.exec(line);
    if (m) rows.push({ n: Number(m[1]), status: m[3], spec: m[4] });
  }
  for (const r of rows) {
    if (!STATUSES.has(r.status)) { errors.push(`phase ${r.n}: unknown status "${r.status}"`); continue; }
    const sec = secs.get(r.n);
    if (r.status === 'Planned' || r.status === 'On hold' || r.status === 'In review') {
      if (!sec) { errors.push(`phase ${r.n}: ${r.status} but ROADMAP.md has no "## Phase ${r.n}" section`); continue; }
      const body = sec.body.join('\n');
      const open = /^\s*- \[ \]/m.test(body);
      const ticked = /^\s*- \[x\]/mi.test(body);
      if (r.status === 'Planned' && ticked && !open) errors.push(`phase ${r.n}: all criteria ticked but marked Planned`);
      if (r.status === 'In review' && open) errors.push(`phase ${r.n}: In review but has unticked criteria`);
      if (r.status === 'In review' && !open) errors.push(`phase ${r.n}: In review with every criterion ticked; mark it Done`);
    } else if (r.status === 'Done') {
      const link = /\]\(([^)]+)\)/.exec(r.spec);
      if (!link) { errors.push(`phase ${r.n}: Done but the spec column has no history link`); continue; }
      const file = path.resolve(baseDir, link[1]);
      if (!fs.existsSync(file)) { errors.push(`phase ${r.n}: history file ${link[1]} does not exist`); continue; }
      const hist = fs.readFileSync(file, 'utf8');
      if (!new RegExp(`^## Phase ${r.n}\\b`, 'm').test(hist)) errors.push(`phase ${r.n}: ${link[1]} has no "## Phase ${r.n}" section`);
      if (sec) errors.push(`phase ${r.n}: Done but still specified in ROADMAP.md`);
    }
  }
  return errors;
}

function selfTest() {
  const dir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'roadmap-'));
  fs.writeFileSync(path.join(dir, 'h.md'), '## Phase 1 — x\n- [x] a\n');
  const row = (n, s, spec) => `| ${n} | t | ${s} | ${spec} |`;
  const cases = [
    ['Done row whose history file lacks its section', `${row(2, 'Done', '[history](h.md)')}\n`],
    ['Planned phase with no spec', `${row(3, 'Planned', 'below')}\n`],
    ['unknown status', `${row(4, 'Soon', 'below')}\n`],
    ['On hold phase with no spec', `${row(8, 'On hold', 'below')}\n`],
    ['Planned phase with every criterion ticked', `${row(5, 'Planned', 'below')}\n## Phase 5 — x\n- [x] a\n`],
    ['In review phase with every criterion ticked', `${row(6, 'In review', 'below')}\n## Phase 6 — x\n- [x] a\n`],
  ];
  let bad = 0;
  for (const [name, text] of cases) {
    if (check(text, dir).length === 0) { console.error(`self-test: check accepted ${name}`); bad++; }
  }
  const good = `${row(1, 'Done', '[history](h.md)')}\n${row(7, 'Planned', 'below')}\n## Phase 7 — x\n- [ ] a\n${row(9, 'On hold', 'below')}\n## Phase 9 — x\n- [ ] a\n`;
  const e = check(good, dir);
  if (e.length) { console.error('self-test: check rejected a valid roadmap:', e); bad++; }
  fs.rmSync(dir, { recursive: true });
  return bad;
}

const file = process.argv[2];
const target = file || path.join(__dirname, '..', 'ROADMAP.md');
const errors = check(fs.readFileSync(target, 'utf8'), path.dirname(target));
errors.forEach(e => console.error(`roadmap: ${e}`));
let bad = errors.length;
if (!file) bad += selfTest();
if (bad) process.exit(1);
console.log('check_roadmap: ok');
