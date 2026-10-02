'use strict';
/**
 * The deployable bundle backend/dist/Code.gs (built by backend/build.py, pasted by the owner per
 * backend/DEPLOY.md) must contain exactly sheets/setup.gs + backend/src/*.gs in the documented order.
 * Run the whole suite against the bundle alone with: RUMMAN_BACKEND_DIST=1 node --test backend/test/
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { REPO_ROOT, DIST_CODE, SETUP_GS, backendFiles } = require('./harness');

/** Mirrors build.py: a marker block per source, then the source with trailing whitespace removed. */
function expectedBody() {
  const sep = `// ${'='.repeat(92)}`;
  return [SETUP_GS].concat(backendFiles()).map((file) => {
    const rel = path.relative(REPO_ROOT, file).split(path.sep).join('/');
    const body = fs.readFileSync(file, 'utf8').replace(/\s+$/, '') + '\n';
    return `\n${sep}\n// المصدر: ${rel}\n${sep}\n\n${body}`;
  }).join('');
}

test('backend/dist/Code.gs is up to date with sheets/setup.gs + backend/src (run python3 backend/build.py)', (t) => {
  if (process.env.RUMMAN_BACKEND_SRC) {
    t.skip('RUMMAN_BACKEND_SRC points at another source tree');
    return;
  }
  assert.ok(fs.existsSync(DIST_CODE), 'backend/dist/Code.gs exists (python3 backend/build.py)');
  const dist = fs.readFileSync(DIST_CODE, 'utf8');
  const start = dist.indexOf(`\n// ${'='.repeat(92)}\n// المصدر: `);
  assert.ok(start > 0, 'the bundle has the generated header followed by source sections');
  assert.ok(dist.slice(0, start).includes('backend/build.py'), 'header names the generator');
  assert.ok(dist.slice(start) === expectedBody(),
    'backend/dist/Code.gs is stale: run `python3 backend/build.py` and commit backend/dist/');
  const manifest = path.join(REPO_ROOT, 'backend', 'appsscript.json');
  assert.equal(fs.readFileSync(path.join(path.dirname(DIST_CODE), 'appsscript.json'), 'utf8'),
    fs.readFileSync(manifest, 'utf8'), 'backend/dist/appsscript.json is a copy of backend/appsscript.json');
});
