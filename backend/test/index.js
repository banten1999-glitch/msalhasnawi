'use strict';
/**
 * Entry point for `node --test backend/test/`.
 *
 * Node 22 treats a directory argument to `--test` as a module path, so it loads this index.js.
 * It requires every *.test.js file in this directory (sorted) so the documented command runs the
 * whole suite in one process. `node --test backend/test/*.test.js` also works and runs the files
 * in parallel processes.
 */
const fs = require('node:fs');
const path = require('node:path');

fs.readdirSync(__dirname)
  .filter((f) => f.endsWith('.test.js'))
  .sort()
  .forEach((f) => require(path.join(__dirname, f)));
