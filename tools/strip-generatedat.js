#!/usr/bin/env node
// Strip the non-deterministic `generatedAt` timestamp from the committed newel
// manifest + IR snapshot, so regeneration never produces a one-line timestamp
// diff. `newel check-drift` reads only the `files` array, so this is safe.
//
// FORMATTING COUPLING: this rewrites both files with `JSON.stringify(x, null, 2)`
// and NO trailing newline, which must stay byte-identical to what @newel/core's
// writeManifest/writeSnapshot emit (also `JSON.stringify(x, null, 2)`, no
// trailing newline). If upstream newel changes its serialization (indent width,
// key order, trailing newline, or moves `generatedAt`), update this script to
// match or regeneration will introduce a formatting-only diff.
const fs = require('fs');
const path = require('path');

const files = ['newel.manifest.json', 'newel.ir-snapshot.json'];
for (const name of files) {
  const file = path.join(__dirname, '..', name);
  if (!fs.existsSync(file)) continue;
  const data = JSON.parse(fs.readFileSync(file, 'utf-8'));
  delete data.generatedAt;
  fs.writeFileSync(file, JSON.stringify(data, null, 2));
}
