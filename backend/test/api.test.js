'use strict';
/**
 * Transport (docs/API.md section 2): doGet health check, the JSON envelope, error envelope rules.
 */
const test = require('node:test');
const {
  assert, ok, fail, adminEnv, createEnv, uuid, assertIsoInZone, ERROR_CODES, BUSINESS_TZ,
} = require('./helpers');

test('doGet is a health check: { ok, data: { service, version } } as JSON, no data', () => {
  const env = createEnv();
  const res = env.get();
  assert.equal(res.ok, true);
  assert.deepEqual(res.data, { service: 'rumman-calculator', version: 1 });
  assert.equal(env.lastRequest.mimeType, 'JSON', 'ContentService.MimeType.JSON');
  assert.equal(env.lastRequest.writes.length, 0, 'health check must not write');
});

test('doPost answers with a JSON envelope whose serverTime is in the business time zone', () => {
  const { env, admin } = adminEnv();
  const res = env.call(admin, 'settings.get', {});
  const data = ok(res, 'settings.get');
  assert.equal(typeof data, 'object');
  assert.equal(env.lastRequest.mimeType, 'JSON');
  assertIsoInZone(res.serverTime, BUSINESS_TZ, 'serverTime');
  assert.ok(Math.abs(Date.parse(res.serverTime) - env.clock.now()) < 5000, 'serverTime is "now"');
});

test('error envelope: { ok:false, error:{ code, message (Arabic) }, serverTime }', () => {
  const { env } = adminEnv();
  const res = env.call(null, 'coolers.list', { status: 'all' });
  const e = fail(res, 'AUTH_REQUIRED');
  assert.ok(ERROR_CODES.includes(e.code));
  assertIsoInZone(res.serverTime, BUSINESS_TZ, 'serverTime on errors');
});

test('protected actions without a session return AUTH_REQUIRED (null, blank, missing)', () => {
  const { env } = adminEnv();
  fail(env.call(null, 'dashboard.get', { period: 'all' }), 'AUTH_REQUIRED', 'session null');
  fail(env.call('', 'dashboard.get', { period: 'all' }), 'AUTH_REQUIRED', 'session ""');
  fail(env.call('   ', 'dashboard.get', { period: 'all' }), 'AUTH_REQUIRED', 'session blank');
  fail(env.post({ action: 'coolers.create', requestId: uuid(), payload: { name: 'x' } }), 'AUTH_REQUIRED', 'no session key');
  fail(env.call(null, 'auth.me', {}), 'AUTH_REQUIRED', 'auth.me needs a session');
  assert.equal(env.readSheet('coolers').length, 0, 'nothing created without a session');
});

test('an unknown action returns UNKNOWN_ACTION', () => {
  const { env, admin } = adminEnv();
  fail(env.call(admin, 'coolers.explode', {}), 'UNKNOWN_ACTION');
  fail(env.call(admin, '', {}), 'UNKNOWN_ACTION', 'empty action');
});

test('a body that is not JSON still gets an error envelope (never an exception)', () => {
  const env = createEnv();
  const res = env.post(null, { raw: '{not json' });
  assert.equal(res.ok, false);
  assert.ok(ERROR_CODES.includes(res.error.code), `known error code, got ${res.error.code}`);
  fail(res, res.error.code, 'malformed body');
});

test('every response carries only ok/data/serverTime or ok/error/serverTime', () => {
  const { env, admin } = adminEnv();
  const good = env.call(admin, 'auth.me', {});
  ok(good);
  assert.deepEqual(Object.keys(good).sort(), ['data', 'ok', 'serverTime']);
  const bad = env.call(admin, 'nope.nope', {});
  assert.deepEqual(Object.keys(bad).sort(), ['error', 'ok', 'serverTime']);
  assert.equal(bad.ok, false);
});
