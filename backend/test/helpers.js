'use strict';
/**
 * Shared helpers for the backend test suite. Everything here is derived from docs/API.md.
 */
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { createEnv, CLIENT_IDS, DEFAULT_ADMIN, SCHEMA } = require('./harness');

const ADMIN = DEFAULT_ADMIN;
const ARABIC = /[؀-ۿ]/;
const ISO_OFFSET = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?(?:[+-]\d{2}:\d{2}|Z)$/;
const BUSINESS_TZ = 'Africa/Cairo';
const ERROR_CODES = ['AUTH_REQUIRED', 'AUTH_INVALID_TOKEN', 'AUTH_EXPIRED', 'SESSION_STALE', 'NOT_ALLOWED',
  'FORBIDDEN', 'VALIDATION', 'NOT_FOUND', 'CONFLICT', 'COOLER_CLOSED', 'LOCK_TIMEOUT', 'SHEET_NOT_CONFIGURED',
  'SHEET_UNREACHABLE', 'SHEET_SCHEMA', 'UNKNOWN_ACTION', 'INTERNAL'];
const PERMISSION_KEYS = ['addFarmers', 'recordPurchases', 'editOthers', 'recordPayments', 'packaging',
  'closeCoolers', 'reopenCoolers', 'manageUsers', 'manageSettings', 'viewData'];
const ENTRY_KEYS = ['addFarmers', 'recordPurchases', 'editOthers', 'recordPayments', 'packaging', 'closeCoolers'];
const ENTRY_ALL = Object.freeze({ addFarmers: true, recordPurchases: true, editOthers: true, recordPayments: true,
  packaging: true, closeCoolers: true });
const ENTRY_NONE = Object.freeze({ addFarmers: false, recordPurchases: false, editOthers: false,
  recordPayments: false, packaging: false, closeCoolers: false });
/** Sheet permission columns (section 3), in API-key order. */
const PERMISSION_COLUMNS = Object.freeze({ addFarmers: 'إضافة المزارعين', recordPurchases: 'تسجيل المشتريات',
  editOthers: 'تعديل عمليات الآخرين', recordPayments: 'تسجيل المدفوعات', packaging: 'مشتريات التعبئة',
  closeCoolers: 'تقفيل البرادات' });

const uuid = () => crypto.randomUUID();

function show(res) {
  try { return JSON.stringify(res, null, 1).slice(0, 2500); } catch (e) { return String(res); }
}

/** Asserts a success envelope and returns its data. */
function ok(res, label) {
  assert.ok(res && typeof res === 'object', `${label || 'response'}: no envelope`);
  if (res.ok !== true) assert.fail(`${label || 'request'} should succeed but got: ${show(res)}`);
  assert.ok('data' in res, `${label || 'request'}: success envelope without data: ${show(res)}`);
  assert.match(String(res.serverTime), ISO_OFFSET, `${label || 'request'}: serverTime must be ISO-8601 with offset`);
  return res.data;
}

/** Asserts an error envelope with the given code (or one of several); checks the Arabic message. */
function fail(res, code, label) {
  const codes = Array.isArray(code) ? code : [code];
  assert.ok(res && typeof res === 'object', `${label || 'response'}: no envelope`);
  if (res.ok !== false || !res.error || codes.indexOf(res.error.code) < 0) {
    assert.fail(`${label || 'request'} should fail with ${codes.join(' or ')} but got: ${show(res)}`);
  }
  assert.match(String(res.serverTime), ISO_OFFSET, `${label || codes[0]}: serverTime must be ISO-8601 with offset`);
  assert.equal(typeof res.error.message, 'string', `${label || codes[0]}: error.message must be a string`);
  assert.match(res.error.message, ARABIC, `${label || codes[0]}: error.message must be Arabic: ${res.error.message}`);
  assert.doesNotMatch(res.error.message, /\p{Extended_Pictographic}/u, `${label || codes[0]}: no emoji in messages`);
  return res.error;
}

/** VALIDATION naming a field; optional regex the Arabic message must match (the field's Arabic name). */
function failField(res, field, messageRe, label) {
  const e = fail(res, 'VALIDATION', label);
  if (field instanceof RegExp) assert.match(String(e.field), field, `${label || 'VALIDATION'}: error.field: ${show(res)}`);
  else if (field !== null && field !== undefined) {
    assert.equal(e.field, field, `${label || 'VALIDATION'}: error.field should be "${field}": ${show(res)}`);
  }
  if (messageRe) assert.match(e.message, messageRe, `${label || 'VALIDATION'}: message should name the field: ${e.message}`);
  return e;
}

/** FORBIDDEN naming the missing permission (details.permission). */
function forbidden(res, permission, label) {
  const e = fail(res, 'FORBIDDEN', label);
  const perms = Array.isArray(permission) ? permission : [permission];
  assert.ok(e.details && perms.indexOf(e.details.permission) >= 0,
    `${label || 'FORBIDDEN'}: details.permission should be ${perms.join(' or ')}: ${show(res)}`);
  return e;
}

/**
 * An unknown referenced id: the contract's NOT_FOUND ("record id unknown"), or a VALIDATION that names
 * the payload key holding the id.
 */
function failUnknownRef(res, field, label) {
  const e = fail(res, ['NOT_FOUND', 'VALIDATION'], label);
  if (e.code === 'VALIDATION') assert.equal(e.field, field, `${label || 'unknown id'}: VALIDATION must name ${field}`);
  return e;
}

function adminEnv(options) {
  const env = createEnv(options);
  const admin = env.loginAs(ADMIN, { name: 'المالك' });
  return { env, admin };
}

function addUser(env, admin, email, role, permissions, name) {
  const payload = { email, name: name || `موظف ${email.split('@')[0]}`, role };
  if (permissions) payload.permissions = permissions;
  return ok(env.call(admin, 'users.add', payload), `users.add ${email}`).user;
}

/** Adds a user and logs them in. */
function userSession(env, admin, email, role, permissions) {
  const user = addUser(env, admin, email, role, permissions);
  const s = env.loginAs(email);
  return Object.assign(s, { added: user });
}

function newCooler(env, s, extra) {
  return ok(env.call(s, 'coolers.create', Object.assign({ name: 'براد تجريبي' }, extra || {})), 'coolers.create').cooler;
}

function newFarmer(env, s, name, extra) {
  return ok(env.call(s, 'farmers.create', Object.assign({ name }, extra || {})), `farmers.create ${name}`).farmer;
}

function purchasePayload(cooler, farmer, o) {
  const p = Object.assign({
    coolerId: cooler.id,
    farmerId: farmer && farmer.id,
    boxes: 50,
    avgWeightGrams: 11000,
    weightMethod: 'direct',
    pricePerKgPiasters: 1500,
    payment: { mode: 'none' },
  }, o || {});
  if (p.farmerId === undefined) delete p.farmerId;
  return p;
}

function buy(env, s, cooler, farmer, o, requestId) {
  return ok(env.call(s, 'purchases.create', purchasePayload(cooler, farmer, o), requestId), 'purchases.create');
}

function pay(env, s, targetType, targetId, amountPiasters, extra, requestId) {
  return ok(env.call(s, 'payments.create', Object.assign({ targetType, targetId, amountPiasters, method: 'cash' }, extra || {}),
    requestId), 'payments.create');
}

function getCooler(env, s, id) {
  return ok(env.call(s, 'coolers.get', { id }), 'coolers.get').cooler;
}

function closeCooler(env, s, cooler, extra) {
  const fresh = getCooler(env, s, cooler.id);
  return ok(env.call(s, 'coolers.close', Object.assign({ id: cooler.id, expectedVersion: fresh.version,
    clientPendingCount: 0 }, extra || {})), 'coolers.close').cooler;
}

function getPurchase(env, s, id) {
  const list = ok(env.call(s, 'purchases.list', { includeCancelled: true }), 'purchases.list').purchases;
  const p = list.find((x) => x.id === id);
  assert.ok(p, `purchase ${id} not found in purchases.list`);
  return p;
}

function getPackaging(env, s, id) {
  return ok(env.call(s, 'packaging.get', { id }), 'packaging.get');
}

/** Saves a packaging draft (create when no id). */
function saveDraft(env, s, payload, requestId) {
  return ok(env.call(s, 'packaging.save', payload, requestId), 'packaging.save');
}

/** Creates a complete draft and approves it; returns the approve result. */
function approvedPackaging(env, s, cooler, items, extra) {
  const saved = saveDraft(env, s, Object.assign({ supplier: 'مورد التعبئة', invoiceNo: 'F-100',
    coolerId: cooler ? cooler.id : undefined, items }, extra || {}));
  return ok(env.call(s, 'packaging.approve', { id: saved.packaging.id, expectedVersion: saved.packaging.version }),
    'packaging.approve');
}

/** kg (sheet) -> grams; EGP (sheet) -> piasters, as the contract says. */
const grams = (kg) => Math.round(Number(kg) * 1000);
const piasters = (egp) => Math.round(Number(egp) * 100);

/** Formats an instant as ISO-8601 with offset in a time zone (test-side reference). */
function isoIn(ms, tz) {
  const f = new Intl.DateTimeFormat('en-US', { timeZone: tz, hourCycle: 'h23', year: 'numeric', month: '2-digit',
    day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' });
  const p = {};
  f.formatToParts(new Date(ms)).forEach((x) => { p[x.type] = x.value; });
  const t = Math.floor(ms / 1000) * 1000;
  const off = Math.round((Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour % 24, +p.minute, +p.second) - t) / 60000);
  const pad = (n) => String(n).padStart(2, '0');
  const xxx = off === 0 ? 'Z' : `${off < 0 ? '-' : '+'}${pad(Math.floor(Math.abs(off) / 60))}:${pad(Math.abs(off) % 60)}`;
  return `${p.year}-${p.month}-${p.day}T${pad(+p.hour % 24)}:${p.minute}:${p.second}${xxx}`;
}

/** Asserts an ISO-8601 string is expressed in the given zone with its correct offset. */
function assertIsoInZone(iso, tz, label) {
  assert.match(String(iso), ISO_OFFSET, `${label}: ISO-8601 with offset expected, got ${iso}`);
  const ms = Date.parse(iso);
  assert.ok(!Number.isNaN(ms), `${label}: unparsable timestamp ${iso}`);
  assert.equal(String(iso).replace(/\.\d{3}/, ''), isoIn(ms, tz), `${label}: must be wall time in ${tz} with offset`);
}

/** Asserts a timestamp is within `toleranceMs` of the harness clock "now". */
function assertNear(env, iso, label, toleranceMs) {
  const ms = Date.parse(iso);
  assert.ok(Math.abs(ms - env.clock.now()) <= (toleranceMs || 5000), `${label}: ${iso} should be "now"`);
}

function auditRows(env) { return env.readSheet('audit'); }

function isDate(v) { return Object.prototype.toString.call(v) === '[object Date]'; }

/** Numeric suffix of an id like PU-0012. */
function idNum(id) { const m = /^[A-Z]{1,2}-(\d+)$/.exec(String(id)); return m ? Number(m[1]) : NaN; }

/** Every record id (or settings key) per sheet, with its row number. */
function snapshotIds(env) {
  const out = {};
  for (const def of SCHEMA.sheets) {
    const keyCol = def.columns.some((c) => c.name === 'المعرّف') ? 'المعرّف' : def.columns[0].name;
    if (!env.sheetState(def.title)) continue;
    out[def.title] = {};
    for (const r of env.readSheet(def.title)) {
      if (r[keyCol] !== '' && r[keyCol] !== undefined) out[def.title][String(r[keyCol])] = r._row;
    }
  }
  return out;
}

/** Records are never deleted (or moved): every id seen before is still on the same row. */
function assertNoRowsLost(env, before, label) {
  const after = snapshotIds(env);
  for (const title of Object.keys(before)) {
    for (const id of Object.keys(before[title])) {
      assert.ok(after[title] && after[title][id] === before[title][id],
        `${label}: ${title} row ${id} (row ${before[title][id]}) was deleted or moved`);
    }
  }
}

/** All values of every schema sheet (for "nothing was written" checks). */
function dataSnapshot(env) {
  const out = {};
  for (const def of SCHEMA.sheets) if (env.sheetState(def.title)) out[def.title] = env.values(def.title);
  return out;
}

function assertNothingWritten(env, before, label) {
  assert.deepEqual(dataSnapshot(env), before, `${label}: the spreadsheet must not change`);
}

/**
 * The last request wrote only while holding the script lock, acquired the lock with a 25 s timeout
 * before its first write, and flushed after its last write.
 */
function assertLockedAndFlushed(env, label) {
  const rec = env.lastRequest;
  assert.ok(rec, `${label}: no request recorded`);
  const writes = rec.writes.filter((w) => w.phase === 'request');
  assert.ok(writes.length > 0, `${label}: expected the mutation to write to the sheet`);
  const unlocked = writes.filter((w) => !w.lockHeld);
  assert.equal(unlocked.length, 0, `${label}: writes without the script lock: ${show(unlocked)}`);
  const acquire = rec.lockOps.find((o) => (o.op === 'waitLock' || o.op === 'tryLock') && o.seq < writes[0].seq);
  assert.ok(acquire, `${label}: the lock must be acquired before the first write`);
  assert.equal(acquire.ms, 25000, `${label}: waitLock(25000) expected`);
  assert.ok(rec.flushedAfterLastWrite, `${label}: SpreadsheetApp.flush() must run after the last write`);
}

/** Session token parts (section 3). */
function decodeSession(token) {
  const parts = String(token).split('.');
  assert.equal(parts.length, 2, `session token must be payload.signature: ${token}`);
  const payload = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
  return { parts, payload };
}

/** Builds a token exactly as section 3 describes (Apps Script web-safe base64 keeps "=" padding). */
function signSession(payload, secret) {
  const b64ws = (buf) => Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_');
  const part = b64ws(Buffer.from(JSON.stringify(payload), 'utf8'));
  const sig = b64ws(crypto.createHmac('sha256', Buffer.from(String(secret), 'utf8')).update(part, 'utf8').digest());
  return `${part}.${sig}`;
}

function sum(list, f) { return list.reduce((a, x) => a + f(x), 0); }

/** round_half_up(a / b) for non-negative integers. */
function roundHalfUp(a, b) { return Math.floor((2 * a + b) / (2 * b)); }

/** The API value of a purchase per section 5. */
function purchaseValue(boxes, avgWeightGrams, pricePerKgPiasters) {
  const w = boxes * avgWeightGrams;
  return { totalWeightGrams: w, valuePiasters: roundHalfUp(w * pricePerKgPiasters, 1000) };
}

module.exports = {
  assert, uuid, ok, fail, failField, forbidden, failUnknownRef, show, adminEnv, addUser, userSession, newCooler,
  newFarmer, purchasePayload, buy, pay, getCooler, closeCooler, getPurchase, getPackaging, saveDraft,
  approvedPackaging, grams, piasters, isoIn, assertIsoInZone, assertNear, auditRows, isDate, idNum, snapshotIds,
  assertNoRowsLost, dataSnapshot, assertNothingWritten, assertLockedAndFlushed, decodeSession, signSession, sum,
  roundHalfUp, purchaseValue, createEnv,
  CLIENT_IDS, ADMIN, ARABIC, ISO_OFFSET, BUSINESS_TZ, ERROR_CODES, PERMISSION_KEYS, ENTRY_KEYS, ENTRY_ALL, ENTRY_NONE,
  PERMISSION_COLUMNS, SCHEMA,
};
