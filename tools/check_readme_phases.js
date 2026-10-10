#!/usr/bin/env node
// Checks that README.md's phase table lists every phase in ROADMAP.md's phase index with the same
// title and status. Exits non-zero naming each phase that differs or is in only one table.
//   node tools/check_readme_phases.js              check the repository files
//   node tools/check_readme_phases.js --self-test  prove the check catches a drifted README
'use strict';
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');

/** Rows `| N | title | status | ... |` of every markdown table in `text`, as Map<number, {title, status}>. */
function parsePhaseRows(text) {
  const rows = new Map();
  for (const line of text.split('\n')) {
    const m = /^\|\s*(\d+)\s*\|\s*(.*?)\s*\|\s*([A-Za-z]+)\s*\|/.exec(line);
    if (m) rows.set(Number(m[1]), { title: m[2], status: m[3] });
  }
  return rows;
}

/** Messages, one per phase whose number, title or status differs between the two tables. */
function diffTables(roadmap, readme) {
  const problems = [];
  const nums = [...new Set([...roadmap.keys(), ...readme.keys()])].sort((a, b) => a - b);
  for (const n of nums) {
    const a = roadmap.get(n);
    const b = readme.get(n);
    if (!a) problems.push(`Phase ${n}: in README.md but not in the ROADMAP.md index`);
    else if (!b) problems.push(`Phase ${n}: in the ROADMAP.md index but not in README.md`);
    else {
      if (a.title !== b.title) problems.push(`Phase ${n}: title differs (ROADMAP "${a.title}", README "${b.title}")`);
      if (a.status !== b.status) problems.push(`Phase ${n}: status differs (ROADMAP ${a.status}, README ${b.status})`);
    }
  }
  return problems;
}

function section(text, startMarker, endMarker) {
  const i = text.indexOf(startMarker);
  if (i < 0) return '';
  const j = endMarker ? text.indexOf(endMarker, i + startMarker.length) : -1;
  return j < 0 ? text.slice(i) : text.slice(i, j);
}

function load() {
  const roadmapText = fs.readFileSync(path.join(root, 'ROADMAP.md'), 'utf8');
  const readmeText = fs.readFileSync(path.join(root, 'README.md'), 'utf8');
  return {
    roadmap: parsePhaseRows(section(roadmapText, '## Phase index', '\n## ')),
    readme: parsePhaseRows(section(readmeText, '## Roadmap', '\n## ')),
  };
}

function main() {
  const { roadmap, readme } = load();
  if (roadmap.size === 0 || readme.size === 0) {
    console.error('check_readme_phases: found no phase rows in ' + (roadmap.size === 0 ? 'ROADMAP.md' : 'README.md'));
    return 1;
  }
  if (process.argv.includes('--self-test')) {
    const doneNum = [...readme.entries()].filter(([, v]) => v.status === 'Done').map(([k]) => k).pop();
    const drifted = new Map(readme);
    drifted.set(doneNum, { ...readme.get(doneNum), status: 'Planned' });
    const problems = diffTables(roadmap, drifted);
    if (!problems.some((p) => p.startsWith(`Phase ${doneNum}:`))) {
      console.error(`self-test failed: a README Phase ${doneNum} flipped to Planned was not reported`);
      return 2;
    }
    console.error(`self-test: the check reports the drift, as it should:\n  ${problems.join('\n  ')}`);
    return 1;
  }
  const problems = diffTables(roadmap, readme);
  if (problems.length) {
    console.error('README.md phase table disagrees with ROADMAP.md:\n  ' + problems.join('\n  '));
    return 1;
  }
  console.log(`README.md and ROADMAP.md agree on ${roadmap.size} phases`);
  return 0;
}

if (require.main === module) process.exit(main());
module.exports = { parsePhaseRows, diffTables };
