#!/usr/bin/env node
// Strip the non-deterministic `generatedAt` timestamp from the committed newel
// manifest + IR snapshot, so regeneration never produces a one-line timestamp
// diff. `newel check-drift` reads only the `files` array, so this is safe.
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
