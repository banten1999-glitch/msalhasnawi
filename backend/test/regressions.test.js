'use strict';
/**
 * Regression tests for review findings (security SEC-*, correctness F-*). Each test name starts with
 * the finding id so a failure points straight at the original report.
 */
const test = require('node:test');
const {
  assert, ok, fail, forbidden, uuid, adminEnv, userSession, createEnv, newCooler, newFarmer, buy, pay, getCooler,
  closeCooler, getPurchase, isoIn, ADMIN, BUSINESS_TZ, ENTRY_ALL,
} = require('./helpers');

const DAY_MS = 86400000;

function login(env, idToken) {
  return env.post({ action: 'auth.login', session: null, requestId: uuid(), payload: { idToken },
    client: { platform: 'android', version: '1.0.0' } });
}

/** Writes a cell directly in the fake sheet state, bypassing data validation (like a paste in Sheets). */
function rawSetCell(env, key, recordId, header, value) {
  const row = env.findRow(key, recordId);
  const col = env.column(key, header);
  assert.ok(row && col, `rawSetCell: ${key} ${recordId} ${header}`);
  env.sheetState(key).rows[row._row - 1][col - 1] = value;
}

// ---------------------------------------------------------------------------------------------
// SEC-1: credentials never reach LAST_ERROR
// ---------------------------------------------------------------------------------------------

test('SEC-1: a network failure calling tokeninfo does not store the Google ID token in LAST_ERROR', () => {
  const { env, admin } = adminEnv();
  const idToken = env.registerGoogleUser(ADMIN);
  const fault = env.failFetches({ message: 'Address unavailable' });
  const e = fail(login(env, idToken), 'AUTH_INVALID_TOKEN', 'tokeninfo unreachable');
  assert.equal(fault.fired, 1, 'the fetch was attempted and failed');
  assert.equal(e.details.reason, 'unavailable');
  const raw = env.props.get('LAST_ERROR');
  assert.ok(raw, 'the failure is still recorded in LAST_ERROR for diagnosis');
  const [, payload, sig] = idToken.split('.');
  assert.ok(!raw.includes(payload) && !raw.includes(sig), `LAST_ERROR must not contain the token: ${raw}`);
  assert.doesNotMatch(raw, /id_token=(?!<)/, `LAST_ERROR must not contain id_token=<value>: ${raw}`);
  const st = ok(env.call(admin, 'sheet.status', {}), 'sheet.status');
  assert.ok(st.lastError && /tokeninfo/.test(st.lastError.message), 'admins still see what failed');
  assert.ok(!JSON.stringify(st.lastError).includes(payload), 'sheet.status.lastError has no token');
});

test('SEC-1: LAST_ERROR redacts ID tokens, session tokens and id_token= values from any caller', () => {
  const env = createEnv();
  const jwt = 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjMifQ.c2lnbmF0dXJlX2J5dGVz';
  const session = 'eyJ1aWQiOiJVUy0wMDAxIiwiZW1haWwiOiJhQGIuY29tIn0=.QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVo=';
  env.evaluate(`cfgRecordError_('boom https://oauth2.googleapis.com/tokeninfo?id_token=${jwt}&x=1 session ${session} raw ${jwt}')`,
    { withBackend: true });
  const raw = env.props.get('LAST_ERROR');
  assert.ok(raw.includes('boom'), raw);
  assert.ok(!raw.includes('c2lnbmF0dXJlX2J5dGVz'), `JWT signature leaked: ${raw}`);
  assert.ok(!raw.includes('eyJzdWIiOiIxMjMifQ'), `JWT payload leaked: ${raw}`);
  assert.ok(!raw.includes('QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVo'), `session signature leaked: ${raw}`);
});

// ---------------------------------------------------------------------------------------------
// SEC-2: only the bootstrap admin may repoint the backend at another spreadsheet
// ---------------------------------------------------------------------------------------------

test('SEC-2: a second admin cannot sheet.connect; the bootstrap admin can', () => {
  const { env, admin } = adminEnv();
  const second = userSession(env, admin, 'second.admin@gmail.com', 'admin');
  assert.equal(second.user.permissions.manageSettings, true);
  const foreign = env.createSpreadsheet({ name: 'ملف خارجي' });
  const auditBefore = env.readSheet('audit').length;
  for (const target of [foreign, '1NoSuchSpreadsheetIdAtAll000000000000000000', 'not a url']) {
    const res = env.call(second, 'sheet.connect', { spreadsheet: target });
    const e = forbidden(res, 'manageSettings', `second admin connect ${target}`);
    assert.match(e.message, /المدير الأساسي/, 'message names who can do it');
    assert.ok(!JSON.stringify(res).includes(env.ownerEmail), 'the connection account is not revealed');
  }
  assert.equal(env.props.get('SPREADSHEET_ID'), null, 'SPREADSHEET_ID unchanged');
  assert.equal(env.readSheet('audit').length, auditBefore, 'nothing written');
  // repair and status stay available to every admin with manageSettings
  ok(env.call(second, 'sheet.status', {}), 'sheet.status');
  ok(env.call(second, 'sheet.repair', {}), 'sheet.repair');
  // the bootstrap admin can still connect
  const res = ok(env.call(admin, 'sheet.connect', { spreadsheet: foreign }), 'bootstrap connect');
  assert.equal(res.spreadsheetId, foreign);
});

// ---------------------------------------------------------------------------------------------
// SEC-3: unknown or blank user status fails closed
// ---------------------------------------------------------------------------------------------

test('SEC-3: a user whose الحالة is blank or not a known value is treated as disabled', () => {
  const { env, admin } = adminEnv();
  const emp = userSession(env, admin, 'emp@gmail.com', 'entry', ENTRY_ALL);
  ok(env.call(emp, 'auth.me', {}), 'active employee');
  for (const v of ['', 'موقوف', 'لا', 'active?']) {
    rawSetCell(env, 'users', emp.user.id, 'الحالة', v);
    const e = fail(env.call(emp, 'auth.me', {}), 'NOT_ALLOWED', `session with status "${v}"`);
    assert.equal(e.details.reason, 'disabled');
    assert.match(e.message, /الحالة/, 'message names the column');
    assert.match(e.message, /نشط/, 'message names the allowed value');
    const l = fail(login(env, env.registerGoogleUser('emp@gmail.com')), 'NOT_ALLOWED', `login with status "${v}"`);
    assert.equal(l.details.reason, 'disabled');
    const listed = ok(env.call(admin, 'users.list', {})).users.find((u) => u.id === emp.user.id);
    assert.equal(listed.status, 'disabled', `users.list shows "${v}" as disabled`);
  }
  // the canonical value without shadda is still read as disabled, and نشط restores access
  rawSetCell(env, 'users', emp.user.id, 'الحالة', 'معطل');
  assert.equal(fail(env.call(emp, 'auth.me', {}), 'NOT_ALLOWED').details.reason, 'disabled');
  rawSetCell(env, 'users', emp.user.id, 'الحالة', 'نشط');
  ok(env.call(emp, 'auth.me', {}), 'active again');
  // the bootstrap admin is never locked out by a blank status (break-glass)
  rawSetCell(env, 'users', admin.user.id, 'الحالة', '');
  ok(env.call(admin, 'auth.me', {}), 'bootstrap admin with blank status');
});

// ---------------------------------------------------------------------------------------------
// SEC-4: cheap local checks before spending a UrlFetch call
// ---------------------------------------------------------------------------------------------

test('SEC-4: malformed or foreign ID tokens are rejected locally without calling tokeninfo', () => {
  const env = createEnv();
  const nowS = Math.floor(env.clock.now() / 1000);
  const cases = [
    ['not a JWT', 'x', 'malformed'],
    ['two parts', 'abc.def', 'malformed'],
    ['payload is not JSON', 'eyJhbGciOiJSUzI1NiJ9.bm90LWpzb24.c2ln', 'malformed'],
    ['wrong aud', env.registerGoogleUser(ADMIN, { aud: 'other.apps.googleusercontent.com' }), 'audience'],
    ['wrong iss', env.registerGoogleUser(ADMIN, { iss: 'https://evil.example.com' }), 'issuer'],
    ['expired', env.registerGoogleUser(ADMIN, { exp: nowS - 10 }), 'expired'],
    ['aud missing from the JWT', env.registerGoogleUser(ADMIN, { jwtClaims: { aud: undefined } }), 'audience'],
  ];
  for (const [label, idToken, reason] of cases) {
    const e = fail(login(env, idToken), 'AUTH_INVALID_TOKEN', label);
    assert.equal(e.details.reason, reason, `${label}: reason`);
    assert.equal(env.lastRequest.fetches.length, 0, `${label}: no UrlFetch call`);
  }
  // a well-formed token for an allowed client still goes to tokeninfo (the authoritative check)
  ok(login(env, env.registerGoogleUser(ADMIN)), 'valid token');
  assert.equal(env.lastRequest.fetches.length, 1, 'tokeninfo consulted for a plausible token');
  const unknown = env.registerGoogleUser(ADMIN);
  delete env.world.tokens[unknown];
  fail(login(env, unknown), 'AUTH_INVALID_TOKEN', 'plausible but unknown to Google');
  assert.equal(env.lastRequest.fetches.length, 1, 'tokeninfo decides');
});

// ---------------------------------------------------------------------------------------------
// F1: a multi-range row update that fails half way is fully undone
// ---------------------------------------------------------------------------------------------

test('F1: purchases.update failing on its second sheet write leaves the row exactly as before', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const p = buy(env, admin, c, f).purchase;
  const before = env.values('purchases');
  const fault = env.failWrites('purchases', { skip: 1, times: 1 });
  const rid = uuid();
  const res = env.call(admin, 'purchases.update', { id: p.id, expectedVersion: p.version, changes: { boxes: 10 } }, rid);
  fail(res, 'INTERNAL', 'second write fails');
  assert.equal(fault.fired, 1, 'the fault fired on the second write');
  assert.deepEqual(env.values('purchases'), before, 'every cell restored');
  const api = getPurchase(env, admin, p.id);
  assert.equal(api.boxes, 50);
  assert.equal(api.totalWeightGrams, 50 * 11000);
  assert.equal(api.version, p.version);
  // the same requestId can be retried and succeeds
  const again = ok(env.call(admin, 'purchases.update', { id: p.id, expectedVersion: p.version, changes: { boxes: 10 } }, rid));
  assert.equal(again.purchase.boxes, 10);
  assert.equal(again.purchase.totalWeightGrams, 10 * 11000);
});

// ---------------------------------------------------------------------------------------------
// F2: remaining KPIs never go negative under a period filter
// ---------------------------------------------------------------------------------------------

test('F2: dashboard remaining is computed from the period\'s purchases minus all their payments', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const old = buy(env, admin, c, f, { occurredAt: isoIn(env.clock.now() - 60 * DAY_MS, BUSINESS_TZ) }).purchase;
  pay(env, admin, 'purchase', old.id, 100000); // paid today for a purchase two months ago
  const today = ok(env.call(admin, 'dashboard.get', { period: 'today' }), 'today').kpis;
  assert.equal(today.purchaseValuePiasters, 0);
  assert.equal(today.paidPiasters, 100000, 'paid stays filtered by paidAt');
  assert.equal(today.remainingPiasters, 0, 'no purchase in the period, nothing remaining');
  assert.equal(today.remainingFarmersPiasters, 0);
  assert.equal(today.remainingSuppliersPiasters, 0);

  // a purchase made today with a back-dated payment: remaining = value - all of its active payments
  const fresh = buy(env, admin, c, f, { boxes: 10 }).purchase; // 10 × 11 kg × 15 = 1,650.00
  pay(env, admin, 'purchase', fresh.id, 50000, { paidAt: isoIn(env.clock.now() - 40 * DAY_MS, BUSINESS_TZ) });
  const k = ok(env.call(admin, 'dashboard.get', { period: 'today' }), 'today 2').kpis;
  assert.equal(k.purchaseValuePiasters, 165000);
  assert.equal(k.paidPiasters, 100000, 'the back-dated payment is outside today');
  assert.equal(k.remainingPiasters, 165000 - 50000, 'remaining counts every active payment of today\'s purchase');
  assert.equal(k.remainingFarmersPiasters, 115000);
  for (const period of ['today', 'week', 'month', 'season', 'all']) {
    const kk = ok(env.call(admin, 'dashboard.get', { period }), period).kpis;
    assert.ok(kk.remainingPiasters >= 0 && kk.remainingFarmersPiasters >= 0 && kk.remainingSuppliersPiasters >= 0,
      `${period}: remaining is never negative ${JSON.stringify(kk)}`);
  }
  const all = ok(env.call(admin, 'dashboard.get', { period: 'all' }), 'all').kpis;
  assert.equal(all.remainingPiasters, all.purchaseValuePiasters + all.packagingApprovedPiasters - all.paidPiasters,
    'without a period filter the identity value + packaging - paid still holds');
});

// ---------------------------------------------------------------------------------------------
// F3: coolers.create / farmers.create stay idempotent after the request cache is evicted
// ---------------------------------------------------------------------------------------------

test('F3: coolers.create and farmers.create replay from مفتاح عدم التكرار after the cache is evicted', () => {
  const { env, admin } = adminEnv();
  const rid = uuid();
  const a = ok(env.call(admin, 'coolers.create', { name: 'أ' }, rid), 'first create').cooler;
  env.cache.clear();
  const b = ok(env.call(admin, 'coolers.create', { name: 'أ' }, rid), 'retry after eviction');
  assert.equal(b.cooler.id, a.id, 'same cooler returned');
  assert.equal(b.replayed, true);
  assert.equal(env.readSheet('coolers').length, 1, 'no second cooler row');
  assert.equal(env.readSheet('coolers')[0]['مفتاح عدم التكرار'], rid, 'requestId stored on the row');

  const fid = uuid();
  const fa = ok(env.call(admin, 'farmers.create', { name: 'حسن', allowDuplicate: true }, fid)).farmer;
  env.cache.clear();
  const fb = ok(env.call(admin, 'farmers.create', { name: 'حسن', allowDuplicate: true }, fid), 'farmer retry');
  assert.equal(fb.farmer.id, fa.id);
  assert.equal(fb.replayed, true);
  assert.equal(env.readSheet('farmers').length, 1, 'no duplicate farmer');
  // without allowDuplicate the retry is not mistaken for a duplicate name either
  const gid = uuid();
  const ga = ok(env.call(admin, 'farmers.create', { name: 'سعيد' }, gid)).farmer;
  env.cache.clear();
  assert.equal(ok(env.call(admin, 'farmers.create', { name: 'سعيد' }, gid), 'retry').farmer.id, ga.id);
  assert.equal(ok(env.call(admin, 'dashboard.get', {})).kpis.openCoolers, 1);
});

test('F3: a spreadsheet created before the new key columns keeps working (key columns optional until repair)', () => {
  const { env, admin } = adminEnv();
  for (const key of ['coolers', 'farmers']) {
    env.setCell(key, env.schema.headerRow, env.column(key, 'مفتاح عدم التكرار'), '');
  }
  const c = newCooler(env, admin);
  newFarmer(env, admin, 'حسن');
  assert.equal(c.no, 1);
  const st = ok(env.call(admin, 'sheet.status', {}));
  assert.equal(st.ok, false, 'sheet.status still asks for a repair');
  assert.deepEqual(st.sheets.find((s) => s.key === 'coolers').missingColumns, ['مفتاح عدم التكرار']);
  ok(env.call(admin, 'sheet.repair', {}));
  assert.equal(ok(env.call(admin, 'sheet.status', {})).ok, true);
  const rid = uuid();
  const x = ok(env.call(admin, 'coolers.create', {}, rid)).cooler;
  env.cache.clear();
  assert.equal(ok(env.call(admin, 'coolers.create', {}, rid)).cooler.id, x.id, 'idempotent after repair');
});

// ---------------------------------------------------------------------------------------------
// F4: re-closing after a reopen replaces the «عند التقفيل» snapshot; the old one stays in the audit log
// ---------------------------------------------------------------------------------------------

test('F4: re-closing replaces the snapshot, the previous one is kept in سجل التعديلات, and the sheet says so', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  buy(env, admin, c, f);
  const first = closeCooler(env, admin, c).closeSnapshot;
  ok(env.call(admin, 'coolers.reopen', { id: c.id, reason: 'وصلت عملية متأخرة' }));
  assert.deepEqual(getCooler(env, admin, c.id).closeSnapshot, first, 'reopen keeps the snapshot');
  buy(env, admin, c, f, { boxes: 10 });
  const second = closeCooler(env, admin, c).closeSnapshot;
  assert.equal(second.purchases, 2);
  assert.equal(first.purchases, 1);
  const closes = env.readSheet('audit').filter((r) => r['الإجراء'] === 'تقفيل');
  const last = closes[closes.length - 1];
  assert.deepEqual(JSON.parse(last['القيم السابقة']).closeSnapshot, first, 'previous snapshot in the audit row');
  const desc = env.schema.sheets.find((s) => s.key === 'coolers').description;
  assert.doesNotMatch(desc, /مرة واحدة/, 'description no longer says "saved once"');
  assert.match(desc, /سجل التعديلات/, 'description says where earlier snapshots are kept');
  assert.equal(env.values('coolers')[1][0], desc, 'row 2 of the sheet shows the same description');
});

// ---------------------------------------------------------------------------------------------
// F5: a cooler row left by a failed coolers.create is not a real cooler
// ---------------------------------------------------------------------------------------------

test('F5: a cooler compensated after a failed save is not listed or counted', () => {
  const { env, admin } = adminEnv();
  env.failWrites('audit', { times: 1 });
  const rid = uuid();
  fail(env.call(admin, 'coolers.create', { name: 'أ' }, rid), 'INTERNAL', 'audit write fails');
  const failed = env.readSheet('coolers');
  assert.equal(failed.length, 1, 'the row is kept (never deleted)');
  assert.equal(failed[0]['الحالة'], 'مقفّل');
  const retry = ok(env.call(admin, 'coolers.create', { name: 'أ' }, rid), 'retry').cooler;
  assert.notEqual(retry.id, failed[0]['المعرّف']);
  const k = ok(env.call(admin, 'dashboard.get', { period: 'all' })).kpis;
  assert.equal(k.closedCoolers, 0, 'no phantom closed cooler');
  assert.equal(k.openCoolers, 1);
  const list = ok(env.call(admin, 'coolers.list', {})).coolers;
  assert.deepEqual(list.map((x) => x.id), [retry.id], 'coolers.list shows only the real cooler');
  assert.deepEqual(ok(env.call(admin, 'coolers.list', { status: 'closed' })).coolers, []);
  // a real cooler that was closed normally is still counted
  closeCooler(env, admin, retry);
  const k2 = ok(env.call(admin, 'dashboard.get', { period: 'all' })).kpis;
  assert.equal(k2.closedCoolers, 1);
});
