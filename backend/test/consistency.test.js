'use strict';
/**
 * Consistency rules (docs/API.md section 7): idempotency, optimistic concurrency, locking, partial failure,
 * flush, audit trail, records never deleted.
 */
const test = require('node:test');
const {
  assert, ok, fail, adminEnv, newCooler, newFarmer, buy, pay, closeCooler, getPurchase, purchasePayload, saveDraft,
  auditRows, snapshotIds, assertNoRowsLost, assertLockedAndFlushed, dataSnapshot, assertNothingWritten, isDate,
  assertIsoInZone, idNum, uuid, userSession, ENTRY_ALL, BUSINESS_TZ, ADMIN,
} = require('./helpers');

function without(obj, key) {
  const o = Object.assign({}, obj);
  delete o[key];
  return o;
}

test('idempotency: the same requestId twice -> one purchase row (and one payment) and the same response', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const rid = uuid();
  const payload = purchasePayload(c, f, { payment: { mode: 'full', method: 'cash' } });
  const first = ok(env.call(admin, 'purchases.create', payload, rid), 'first');
  const second = ok(env.call(admin, 'purchases.create', payload, rid), 'repeat');
  assert.deepEqual(without(second, 'replayed'), without(first, 'replayed'), 'the stored result is returned');
  assert.equal(typeof second.replayed, 'boolean');
  assert.equal(env.readSheet('purchases').length, 1);
  assert.equal(env.readSheet('payments').length, 1);
  const entry = env.cache.entry(`req:${rid}`);
  assert.ok(entry, 'result cached under req:<requestId>');
  assert.equal(entry.ttl, 21600, 'cached for 6 hours');
});

test('idempotency after the cache expired: detected through مفتاح عدم التكرار, replayed: true', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const rid = uuid();
  const payload = purchasePayload(c, f, { payment: { mode: 'partial', amountPiasters: 1000, method: 'cash' } });
  const first = ok(env.call(admin, 'purchases.create', payload, rid));
  env.cache.clear();
  env.clock.advance(7 * 3600 * 1000);
  const again = ok(env.call(admin, 'purchases.create', payload, rid), 'repeat after cache loss');
  assert.equal(again.replayed, true);
  assert.equal(again.purchase.id, first.purchase.id);
  assert.equal(again.purchase.valuePiasters, first.purchase.valuePiasters);
  assert.equal(env.readSheet('purchases').length, 1);
  assert.equal(env.readSheet('payments').length, 1, 'the payment is not recorded twice');
  assert.equal(env.readSheet('purchases')[0]['مفتاح عدم التكرار'], rid);
});

test('idempotency for payments.create, coolers.create and farmers.create', () => {
  const { env, admin } = adminEnv();
  const rc = uuid();
  const c1 = ok(env.call(admin, 'coolers.create', { name: 'أ' }, rc));
  const c2 = ok(env.call(admin, 'coolers.create', { name: 'أ' }, rc));
  assert.deepEqual(c2, c1);
  assert.equal(env.readSheet('coolers').length, 1);
  const rf = uuid();
  const f1 = ok(env.call(admin, 'farmers.create', { name: 'حسن' }, rf));
  const f2 = ok(env.call(admin, 'farmers.create', { name: 'حسن' }, rf));
  assert.deepEqual(f2, f1, 'no duplicate-name error on a replay');
  assert.equal(env.readSheet('farmers').length, 1);
  const p = buy(env, admin, c1.cooler, f1.farmer).purchase;
  const rp = uuid();
  const pay1 = pay(env, admin, 'purchase', p.id, 1000, {}, rp);
  const pay2 = pay(env, admin, 'purchase', p.id, 1000, {}, rp);
  assert.deepEqual(pay2, pay1);
  env.cache.clear();
  const pay3 = pay(env, admin, 'purchase', p.id, 1000, {}, rp);
  assert.equal(pay3.payment.id, pay1.payment.id, 'payments are detected through مفتاح عدم التكرار too');
  assert.equal(env.readSheet('payments').length, 1);
  assert.equal(env.findRow('payments', pay1.payment.id)['مفتاح عدم التكرار'], rp);
  assert.equal(env.findRow('purchases', p.id)['المدفوع (ج.م)'], 10, 'paid counted once');
});

test('mutations without a requestId are rejected and write nothing', () => {
  const { env, admin } = adminEnv();
  const before = dataSnapshot(env);
  const res = env.post({ action: 'coolers.create', session: admin.token, payload: { name: 'بلا معرّف طلب' },
    client: { platform: 'web', version: '1.0.0' } });
  fail(res, 'VALIDATION');
  assertNothingWritten(env, before, 'mutation without requestId');
});

test('optimistic concurrency: CONFLICT carries details.currentVersion and details.current; every write bumps الإصدار', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const p = buy(env, admin, c, f).purchase;
  assert.equal(p.version, 1);
  const v2 = ok(env.call(admin, 'purchases.update', { id: p.id, expectedVersion: 1, changes: { notes: 'أ' } })).purchase;
  assert.equal(v2.version, 2);
  const v3 = ok(env.call(admin, 'purchases.update', { id: p.id, expectedVersion: 2, changes: { notes: 'ب' } })).purchase;
  assert.equal(v3.version, 3);
  assert.equal(env.findRow('purchases', p.id)['الإصدار'], 3);
  const e = fail(env.call(admin, 'purchases.update', { id: p.id, expectedVersion: 2, changes: { boxes: 10 } }), 'CONFLICT');
  assert.equal(e.details.currentVersion, 3);
  assert.equal(e.details.current.id, p.id);
  assert.equal(e.details.current.version, 3);
  assert.equal(e.details.current.notes, 'ب');
  assert.equal(env.findRow('purchases', p.id)['عدد الصناديق'], 50, 'the conflicting change was not applied');
});

test('LOCK_TIMEOUT when the script lock is busy: nothing written, the same requestId succeeds later', () => {
  const { env, admin } = adminEnv();
  const before = dataSnapshot(env);
  env.lock.setBusy(true);
  const rid = uuid();
  fail(env.call(admin, 'coolers.create', { name: 'أ' }, rid), 'LOCK_TIMEOUT');
  assertNothingWritten(env, before, 'lock timeout');
  assert.equal(env.cache.get(`req:${rid}`), null, 'a failed request is not cached');
  env.lock.setBusy(false);
  const c = ok(env.call(admin, 'coolers.create', { name: 'أ' }, rid), 'retry with the same requestId');
  assert.equal(c.cooler.no, 1);
  assert.equal(env.readSheet('coolers').length, 1);
});

test('all writes of a mutation happen under the script lock (waitLock 25000) and are followed by flush()', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  assertLockedAndFlushed(env, 'coolers.create');
  const f = newFarmer(env, admin, 'حسن');
  assertLockedAndFlushed(env, 'farmers.create');
  const d = buy(env, admin, c, f, { payment: { mode: 'partial', amountPiasters: 1000, method: 'cash' } });
  assertLockedAndFlushed(env, 'purchases.create');
  pay(env, admin, 'purchase', d.purchase.id, 2000);
  assertLockedAndFlushed(env, 'payments.create');
  ok(env.call(admin, 'purchases.update', { id: d.purchase.id,
    expectedVersion: getPurchase(env, admin, d.purchase.id).version, changes: { boxes: 51 } }));
  assertLockedAndFlushed(env, 'purchases.update');
  const draft = saveDraft(env, admin, { supplier: 'مورد', coolerId: c.id,
    items: [{ name: 'الصناديق', quantity: 1, unit: 'قطعة', unitPricePiasters: 100 }] });
  assertLockedAndFlushed(env, 'packaging.save');
  ok(env.call(admin, 'packaging.approve', { id: draft.packaging.id, expectedVersion: draft.packaging.version }));
  assertLockedAndFlushed(env, 'packaging.approve');
  closeCooler(env, admin, c);
  assertLockedAndFlushed(env, 'coolers.close');
  ok(env.call(admin, 'coolers.reopen', { id: c.id, reason: 'سبب' }));
  assertLockedAndFlushed(env, 'coolers.reopen');
  ok(env.call(admin, 'users.add', { email: 'k@gmail.com', name: 'ك', role: 'viewer' }));
  assertLockedAndFlushed(env, 'users.add');
  ok(env.call(admin, 'settings.update', { businessName: 'اسم' }));
  assertLockedAndFlushed(env, 'settings.update');
});

/** Request reads grouped by sheet: { title: { getValues: n, unlocked: n } }. */
function readsBySheet(env) {
  const out = {};
  env.lastRequest.reads.filter((r) => r.phase === 'request').forEach((r) => {
    const e = out[r.sheet] || (out[r.sheet] = { getValues: 0, unlocked: 0 });
    if (r.op === 'getValues') e.getValues += 1;
    if (!r.lockHeld) e.unlocked += 1;
  });
  return out;
}

test('locking covers the read-validate-write cycle: records a mutation validates are read under the lock', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const checks = [
    ['purchases.create', () => buy(env, admin, c, f, { payment: { mode: 'partial', amountPiasters: 10, method: 'cash' } }),
      ['البرادات', 'المزارعون', 'مشتريات الرمان', 'المدفوعات']],
    ['coolers.create', () => newCooler(env, admin), ['البرادات']],
    ['farmers.create', () => newFarmer(env, admin, 'محمود'), ['المزارعون']],
    ['coolers.close', () => closeCooler(env, admin, c), ['البرادات', 'مشتريات الرمان', 'المدفوعات']],
  ];
  for (const [label, run, sheets] of checks) {
    run();
    const by = readsBySheet(env);
    for (const title of sheets) {
      assert.ok(by[title], `${label}: reads ${title}`);
      assert.equal(by[title].unlocked, 0, `${label}: ${title} must be read while holding the script lock`);
    }
  }
});

test('batch reads: at most one getValues() per sheet per request', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const p = buy(env, admin, c, f, { payment: { mode: 'full', method: 'cash' } });
  saveDraft(env, admin, { supplier: 'مورد', coolerId: c.id, items: [{ name: 'الصناديق', unit: 'قطعة' }] });
  const requests = [
    ['dashboard.get', { period: 'all' }], ['coolers.list', { status: 'all' }], ['coolers.get', { id: c.id }],
    ['purchases.list', {}], ['payments.list', {}], ['packaging.list', {}],
    ['purchases.create', purchasePayload(c, f, { payment: { mode: 'full', method: 'cash' } })],
    ['payments.create', { targetType: 'purchase', targetId: p.purchase.id, amountPiasters: 0, method: 'cash' }],
  ];
  for (const [action, payload] of requests) {
    env.call(admin, action, payload);
    const by = readsBySheet(env);
    for (const title of Object.keys(by)) {
      assert.ok(by[title].getValues <= 1, `${action}: ${title} read with ${by[title].getValues} getValues() calls`);
    }
  }
});

test('reads never write to the spreadsheet', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const p = buy(env, admin, c, f, { payment: { mode: 'partial', amountPiasters: 5, method: 'cash' } });
  const draft = saveDraft(env, admin, { supplier: 'مورد', items: [{ name: 'الصناديق', unit: 'قطعة' }] });
  const reads = [['dashboard.get', { period: 'all' }], ['coolers.list', { status: 'all' }], ['coolers.get', { id: c.id }],
    ['farmers.list', {}], ['purchases.list', {}], ['payments.list', { targetId: p.purchase.id }], ['packaging.list', {}],
    ['packaging.get', { id: draft.packaging.id }], ['itemTypes.list', {}], ['settings.get', {}], ['auth.me', {}],
    ['users.list', {}], ['sheet.status', {}]];
  for (const [action, payload] of reads) {
    ok(env.call(admin, action, payload), action);
    assert.equal(env.lastRequest.writes.length, 0, `${action} must not write`);
  }
});

test('partial failure: a failed second write is compensated, LAST_ERROR recorded, INTERNAL returned, retry succeeds', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const rid = uuid();
  const payload = purchasePayload(c, f, { payment: { mode: 'full', method: 'cash' } });
  const fault = env.failWrites('payments', { times: 1 });
  fail(env.call(admin, 'purchases.create', payload, rid), 'INTERNAL');
  assert.equal(fault.fired, 1, 'the payment write failed');
  const purchases = env.readSheet('purchases');
  purchases.forEach((r) => {
    assert.equal(r['الحالة'], 'ملغاة', 'a purchase written before the failure is compensated');
    assert.equal(r['سبب الإلغاء'], 'تعذّر إكمال الحفظ');
  });
  assert.ok(env.props.get('LAST_ERROR'), 'LAST_ERROR recorded');
  assert.equal(env.cache.get(`req:${rid}`), null, 'the failed result is not cached');
  const st = ok(env.call(admin, 'sheet.status', {}));
  assert.ok(st.lastError && typeof st.lastError.message === 'string', 'sheet.status reports lastError');

  const retry = ok(env.call(admin, 'purchases.create', payload, rid), 'retry with the same requestId');
  assert.equal(retry.purchase.status, 'active');
  assert.equal(retry.purchase.paidPiasters, retry.purchase.valuePiasters);
  const active = env.readSheet('purchases').filter((r) => r['الحالة'] === 'فعّالة');
  assert.equal(active.length, 1, 'exactly one active purchase after the retry');
  const pays = env.readSheet('payments').filter((r) => r['الحالة'] === 'فعّالة');
  assert.equal(pays.length, 1, 'exactly one active payment after the retry');
  assert.equal(pays[0]['معرّف العملية'], active[0]['المعرّف']);
});

test('every mutation appends an audit row: AU- id, time, user, Arabic action and record type, record id', () => {
  const { env, admin } = adminEnv();
  const start = auditRows(env).length;
  const steps = [];
  const expect = (action, type, id) => steps.push([action, type, id]);
  const c = newCooler(env, admin); expect('إنشاء', 'براد', c.id);
  const f = newFarmer(env, admin, 'حسن'); expect('إنشاء', 'مزارع', f.id);
  const uf = ok(env.call(admin, 'farmers.update', { id: f.id, expectedVersion: f.version, phone: '01001234567' })).farmer;
  expect('تعديل', 'مزارع', f.id);
  const d = buy(env, admin, c, f); expect('إنشاء', 'شراء رمان', d.purchase.id);
  const py = pay(env, admin, 'purchase', d.purchase.id, 1000); expect('دفعة', 'دفعة', py.payment.id);
  ok(env.call(admin, 'payments.cancel', { id: py.payment.id, reason: 'خطأ' })); expect('إلغاء', 'دفعة', py.payment.id);
  ok(env.call(admin, 'purchases.update', { id: d.purchase.id,
    expectedVersion: getPurchase(env, admin, d.purchase.id).version, changes: { boxes: 40 } }));
  expect('تعديل', 'شراء رمان', d.purchase.id);
  const draft = saveDraft(env, admin, { supplier: 'مورد', items: [{ name: 'الصناديق', quantity: 1, unit: 'قطعة',
    unitPricePiasters: 10 }] });
  expect('إنشاء', 'شراء تعبئة', draft.packaging.id);
  ok(env.call(admin, 'packaging.cancel', { id: draft.packaging.id, reason: 'خطأ' })); expect('إلغاء', 'شراء تعبئة', draft.packaging.id);
  closeCooler(env, admin, c); expect('تقفيل', 'براد', c.id);
  ok(env.call(admin, 'coolers.reopen', { id: c.id, reason: 'سهو' })); expect('إعادة فتح', 'براد', c.id);
  const u = ok(env.call(admin, 'users.add', { email: 'k@gmail.com', name: 'ك', role: 'entry', permissions: ENTRY_ALL })).user;
  expect('إنشاء', 'مستخدم', u.id);
  ok(env.call(admin, 'users.update', { id: u.id, expectedVersion: u.version, name: 'كريم' })); expect('تعديل', 'مستخدم', u.id);
  ok(env.call(admin, 'settings.update', { businessName: 'اسم' })); expect('تعديل', 'إعدادات', null);
  assert.equal(uf.version, 2);

  const audit = auditRows(env).slice(start);
  for (const [action, type, id] of steps) {
    const hit = audit.find((r) => r['الإجراء'] === action && r['نوع السجل'] === type && (id === null || r['معرّف السجل'] === id));
    assert.ok(hit, `audit row ${action} / ${type} / ${id}`);
  }
  const ids = audit.map((r) => r['المعرّف']);
  ids.forEach((id) => assert.match(String(id), /^AU-\d{4,}$/));
  assert.equal(new Set(ids).size, ids.length, 'audit ids are unique');
  const nums = ids.map(idNum);
  assert.deepEqual(nums, nums.slice().sort((a, b) => a - b), 'audit ids increase');
  audit.forEach((r) => {
    assert.ok(isDate(r['التاريخ والوقت']), 'audit time is a date');
    const who = String(r['المستخدم']);
    assert.ok(who.includes('owner.admin@gmail.com') || who.includes('المالك'), `audit user names the actor: ${who}`);
    assert.match(String(r['الوصف']), /[؀-ۿ]/, 'Arabic description');
    for (const h of ['القيم السابقة', 'القيم الجديدة']) {
      if (r[h] !== '') JSON.parse(r[h]);
    }
  });
});

test('records are never deleted: a long scenario keeps every row in place', () => {
  const { env, admin } = adminEnv();
  const snaps = [];
  const check = (label) => {
    if (snaps.length) assertNoRowsLost(env, snaps[snaps.length - 1], label);
    snaps.push(snapshotIds(env));
  };
  check('start');
  const c = newCooler(env, admin); check('cooler');
  const f = newFarmer(env, admin, 'حسن'); check('farmer');
  const d = buy(env, admin, c, f, { payment: { mode: 'partial', amountPiasters: 100, method: 'cash' } }); check('purchase');
  ok(env.call(admin, 'payments.cancel', { id: d.payment.id, reason: 'خطأ' })); check('payment cancel');
  ok(env.call(admin, 'purchases.cancel', { id: d.purchase.id, reason: 'خطأ' })); check('purchase cancel');
  const draft = saveDraft(env, admin, { supplier: 'مورد', items: [{ name: 'أ', quantity: 1, unit: 'قطعة', unitPricePiasters: 1 },
    { name: 'ب', quantity: 1, unit: 'قطعة', unitPricePiasters: 1 }] }); check('draft');
  saveDraft(env, admin, { id: draft.packaging.id, expectedVersion: draft.packaging.version, supplier: 'مورد',
    items: [{ id: draft.items[0].id, name: 'أ', quantity: 2, unit: 'قطعة', unitPricePiasters: 1 }] });
  check('item removed');
  assert.equal(env.findRow('packaging_items', draft.items[1].id)['الحالة'], 'محذوف');
  ok(env.call(admin, 'packaging.cancel', { id: draft.packaging.id, reason: 'خطأ' })); check('packaging cancel');
  closeCooler(env, admin, c); check('close');
  ok(env.call(admin, 'coolers.reopen', { id: c.id, reason: 'سهو' })); check('reopen');
  ok(env.call(admin, 'sheet.repair', {})); check('repair');
  assert.equal(env.readSheet('purchases').length, 1);
  assert.equal(env.readSheet('payments').length, 1);
  assert.equal(env.readSheet('packaging_items').length, 2);
  const deleted = env.world.log.deletedSheets.filter((x) => x.phase === 'request');
  assert.deepEqual(deleted, [], 'no sheet deleted by a request');
  const cleared = env.history.flatMap((h) => h.writes).filter((w) => w.op === 'clearSheet' && w.sheet !== 'لوحة الملخص');
  assert.deepEqual(cleared, [], 'no data sheet cleared');
  assert.deepEqual(env.world.log.anomalies, [], 'only strings, numbers, booleans, dates and blanks are written');
});

test('timestamps written by the backend are real dates; API timestamps are ISO in the business zone', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const p = buy(env, admin, c, f).purchase;
  ['occurredAt', 'createdAt'].forEach((k) => assertIsoInZone(p[k], BUSINESS_TZ, `purchase.${k}`));
  const row = env.findRow('purchases', p.id);
  ['تاريخ ووقت العملية', 'تاريخ الإنشاء الفعلي'].forEach((h) => assert.ok(isDate(row[h]), `${h} is a Date cell`));
  assert.ok(isDate(env.findRow('coolers', c.id)['تاريخ ووقت الفتح']));
});

test('every write bumps الإصدار: recording or cancelling a payment bumps the target purchase/packaging version', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const p = buy(env, admin, c, f).purchase;
  assert.equal(p.version, 1);
  const d = pay(env, admin, 'purchase', p.id, 1000);
  assert.equal(d.target.version, 2, 'payments.create updated the purchase row, so its version increases');
  const row = env.findRow('purchases', p.id);
  assert.equal(row['الإصدار'], 2);
  assert.ok(isDate(row['آخر تعديل']), 'آخر تعديل set on the purchase row');
  assert.ok(String(row['عدّلها']).length > 0, 'عدّلها set on the purchase row');
  // An edit based on the version read before the payment is now a conflict (the paid amount changed).
  const e = fail(env.call(admin, 'purchases.update', { id: p.id, expectedVersion: 1, changes: { boxes: 51 } }), 'CONFLICT');
  assert.equal(e.details.currentVersion, 2);
  assert.equal(e.details.current.paidPiasters, 1000);
  ok(env.call(admin, 'purchases.update', { id: p.id, expectedVersion: d.target.version, changes: { boxes: 51 } }),
    'the version returned in target is the current one');
  const cancelled = ok(env.call(admin, 'payments.cancel', { id: d.payment.id, reason: 'خطأ' }));
  assert.equal(cancelled.target.version, 4, 'payments.cancel bumps the purchase version again');
  assert.equal(env.findRow('purchases', p.id)['الإصدار'], 4);

  const draft = saveDraft(env, admin, { supplier: 'مورد', coolerId: c.id,
    items: [{ name: 'الصناديق', quantity: 10, unit: 'قطعة', unitPricePiasters: 500 }] });
  const appr = ok(env.call(admin, 'packaging.approve', { id: draft.packaging.id, expectedVersion: draft.packaging.version }));
  const pp = pay(env, admin, 'packaging', appr.packaging.id, 100);
  assert.equal(pp.target.version, appr.packaging.version + 1, 'packaging version bumped by its payment');
  assert.equal(env.findRow('packaging', appr.packaging.id)['الإصدار'], appr.packaging.version + 1);
});

test('idempotent replay writes nothing: no second row and no second audit row (cache hit and key-column hit)', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const cases = [
    ['purchases.create', purchasePayload(c, f, { payment: { mode: 'partial', amountPiasters: 500, method: 'cash' } })],
    ['payments.create', null],
    ['packaging.save', { supplier: 'مورد', items: [{ name: 'الصناديق', quantity: 2, unit: 'قطعة', unitPricePiasters: 10 }] }],
  ];
  let purchaseId = null;
  for (const [action, base] of cases) {
    const payload = base || { targetType: 'purchase', targetId: purchaseId, amountPiasters: 100, method: 'cash' };
    const rid = uuid();
    const first = ok(env.call(admin, action, payload, rid), `${action} first`);
    if (action === 'purchases.create') purchaseId = first.purchase.id;
    const before = dataSnapshot(env);
    ok(env.call(admin, action, payload, rid), `${action} repeat (cache)`);
    assert.equal(env.lastRequest.writes.length, 0, `${action}: a cached repeat writes nothing`);
    env.cache.clear();
    const again = ok(env.call(admin, action, payload, rid), `${action} repeat (key column)`);
    assert.equal(again.replayed, true, `${action}: replayed through مفتاح عدم التكرار`);
    assertNothingWritten(env, before, `${action} replays`);
  }
});

test('a cached result is returned only to the session that produced it; another user goes through every check', () => {
  const { env, admin } = adminEnv();
  const viewer = userSession(env, admin, 'viewer@gmail.com', 'viewer');
  const rid = uuid();
  const created = ok(env.call(admin, 'coolers.create', { name: 'براد المدير' }, rid));
  const before = dataSnapshot(env);
  const e = fail(env.call(viewer, 'coolers.create', { name: 'براد المدير' }, rid), 'FORBIDDEN',
    'a viewer reusing the admin requestId');
  assert.equal(e.details.permission, 'recordPurchases');
  assertNothingWritten(env, before, 'viewer replay');
  const again = ok(env.call(admin, 'coolers.create', { name: 'براد المدير' }, rid), 'the owner still gets the cached result');
  assert.deepEqual(again, created);
  const relogin = env.loginAs(ADMIN);
  assert.deepEqual(ok(env.call(relogin, 'coolers.create', { name: 'براد المدير' }, rid)), created,
    'same user with a new session token: same cached result');
  assert.equal(env.readSheet('coolers').length, 1);
});

test('partial failure in coolers.create: the cooler row is kept but closed, so it never becomes the current cooler', () => {
  const { env, admin } = adminEnv();
  const rid = uuid();
  env.failWrites('audit', { times: 1 });
  fail(env.call(admin, 'coolers.create', { name: 'براد' }, rid), 'INTERNAL');
  const rows = env.readSheet('coolers');
  assert.equal(rows.length, 1, 'the row written before the failure is kept (records are never deleted)');
  assert.equal(rows[0]['الحالة'], 'مقفّل', 'compensated cooler is closed');
  assert.match(String(rows[0]['ملاحظات']), /تعذّر إكمال الحفظ/);
  assert.ok(env.props.get('LAST_ERROR'));
  const retry = ok(env.call(admin, 'coolers.create', { name: 'براد' }, rid), 'retry with the same requestId').cooler;
  assert.equal(retry.status, 'open');
  const d = ok(env.call(admin, 'dashboard.get', { period: 'all' }));
  assert.equal(d.currentCooler && d.currentCooler.id, retry.id, 'the retried cooler is the current one');
  assert.deepEqual(d.openCoolers.map((x) => x.id), [retry.id]);
  const f = newFarmer(env, admin, 'حسن');
  fail(env.call(admin, 'purchases.create', purchasePayload({ id: rows[0]['المعرّف'] }, f)), 'COOLER_CLOSED',
    'no purchases can land in the compensated cooler');
});
