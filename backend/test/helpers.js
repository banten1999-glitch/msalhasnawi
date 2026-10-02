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
const ERROR_CODES = ['AUTH_REQUIRED', 'AUTH_INVALID_TOKEN', 'AUTH_EXPIRED', 'SESSION_STALE', 'NOT_ALLOWED',
  'FORBIDDEN', 'VALIDATION', 'NOT_FOUND', 'CONFLICT', 'COOLER_CLOSED', 'LOCK_TIMEOUT', 'SHEET_NOT_CONFIGURED',
  'SHEET_UNREACHABLE', 'SHEET_SCHEMA', 'UNKNOWN_ACTION', 'INTERNAL'];
const PERMISSION_KEYS = ['addFarmers', 'recordPurchases', 'editOthers', 'recordPayments', 'packaging',
  'closeCoolers', 'reopenCoolers', 'manageUsers', 'manageSettings', 'viewData'];
const ENTRY_ALL = Object.freeze({ addFarmers: true, recordPurchases: true, editOthers: true, recordPayments: true,
  packaging: true, closeCoolers: true });
const ENTRY_NONE = Object.freeze({ addFarmers: false, recordPurchases: false, editOthers: false,
  recordPayments: false, packaging: false, closeCoolers: false });

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

/** Asserts an error envelope with the given code; checks the Arabic message; returns the error. */
function fail(res, code, label) {
  assert.ok(res && typeof res === 'object', `${label || 'response'}: no envelope`);
  if (res.ok !== false || !res.error || res.error.code !== code) {
    assert.fail(`${label || 'request'} should fail with ${code} but got: ${show(res)}`);
  }
  assert.match(String(res.serverTime), ISO_OFFSET, `${label || code}: serverTime must be ISO-8601 with offset`);
  assert.equal(typeof res.error.message, 'string', `${label || code}: error.message must be a string`);
  assert.match(res.error.message, ARABIC, `${label || code}: error.message must be Arabic: ${res.error.message}`);
  return res.error;
}

/** VALIDATION naming a field; optional regex the Arabic message must match (the field's Arabic name). */
function failField(res, field, messageRe, label) {
  const e = fail(res, 'VALIDATION', label);
  if (field instanceof RegExp) assert.match(String(e.field), field, `${label || 'VALIDATION'}: error.field`);
  else assert.equal(e.field, field, `${label || 'VALIDATION'}: error.field should be "${field}": ${show(res)}`);
  if (messageRe) assert.match(e.message, messageRe, `${label || 'VALIDATION'}: message should name the field: ${e.message}`);
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

function auditRows(env) { return env.readSheet('audit'); }

function isDate(v) { return Object.prototype.toString.call(v) === '[object Date]'; }

/** Numeric suffix of an id like PU-0012. */
function idNum(id) { const m = /^[A-Z]{2}-(\d+)$/.exec(String(id)); return m ? Number(m[1]) : NaN; }

module.exports = {
  assert, uuid, ok, fail, failField, show, adminEnv, addUser, userSession, newCooler, newFarmer, purchasePayload,
  buy, pay, getCooler, closeCooler, getPurchase, grams, piasters, isoIn, auditRows, isDate, idNum, createEnv,
  CLIENT_IDS, ADMIN, ARABIC, ISO_OFFSET, ERROR_CODES, PERMISSION_KEYS, ENTRY_ALL, ENTRY_NONE, SCHEMA,
};
