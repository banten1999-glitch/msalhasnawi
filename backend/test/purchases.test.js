'use strict';
/**
 * Purchases: money/weight rules, payment modes, validation, sample method, update/cancel
 * (docs/API.md sections 4, 5, 6).
 */
const test = require('node:test');
const {
  assert, ok, fail, failField, failUnknownRef, adminEnv, newCooler, newFarmer, buy, pay, purchasePayload,
  getPurchase, auditRows, assertIsoInZone, assertNear, isDate, idNum, grams, piasters, dataSnapshot,
  assertNothingWritten, purchaseValue, uuid, BUSINESS_TZ,
} = require('./helpers');

const PURCHASE_KEYS = ['id', 'coolerId', 'coolerNo', 'farmerId', 'farmerName', 'occurredAt', 'boxes', 'avgWeightGrams',
  'weightMethod', 'sampleWeightsGrams', 'tareGrams', 'totalWeightGrams', 'pricePerKgPiasters', 'valuePiasters',
  'paidPiasters', 'remainingPiasters', 'payStatus', 'status', 'cancelReason', 'notes', 'createdAt', 'createdBy',
  'updatedAt', 'updatedBy', 'version'];

function setup() {
  const { env, admin } = adminEnv();
  const cooler = newCooler(env, admin, { name: 'براد ١٤' });
  const farmer = newFarmer(env, admin, 'حسن البدري');
  return { env, admin, cooler, farmer };
}

test('acceptance: 50 boxes x 11000 g x 1500 piasters/kg -> 550000 g, 825000 piasters; sheet 550 kg / 8250 EGP', () => {
  const { env, admin, cooler, farmer } = setup();
  const rid = uuid();
  const d = buy(env, admin, cooler, farmer, { notes: 'أول شحنة' }, rid);
  const p = d.purchase;
  PURCHASE_KEYS.forEach((k) => assert.ok(k in p, `Purchase.${k} missing`));
  assert.match(p.id, /^PU-\d{4,}$/);
  assert.equal(p.coolerId, cooler.id);
  assert.equal(p.coolerNo, cooler.no);
  assert.equal(p.farmerId, farmer.id);
  assert.equal(p.farmerName, 'حسن البدري');
  assert.equal(p.boxes, 50);
  assert.equal(p.avgWeightGrams, 11000);
  assert.equal(p.weightMethod, 'direct');
  assert.equal(p.totalWeightGrams, 550000);
  assert.equal(p.pricePerKgPiasters, 1500);
  assert.equal(p.valuePiasters, 825000);
  assert.equal(p.paidPiasters, 0);
  assert.equal(p.remainingPiasters, 825000);
  assert.equal(p.payStatus, 'unpaid');
  assert.equal(p.status, 'active');
  assert.equal(p.notes, 'أول شحنة');
  assert.equal(p.version, 1);
  assert.equal(d.payment, null);
  assert.equal(d.farmer, null);
  assert.equal(d.replayed, false);
  assertIsoInZone(p.occurredAt, BUSINESS_TZ, 'occurredAt');
  assertNear(env, p.occurredAt, 'occurredAt defaults to now');
  assertIsoInZone(p.createdAt, BUSINESS_TZ, 'createdAt');
  assert.ok(String(p.createdBy).length > 0);

  const rows = env.readSheet('purchases');
  assert.equal(rows.length, 1);
  const row = rows[0];
  assert.equal(row['المعرّف'], p.id);
  assert.equal(row['معرّف البراد'], cooler.id);
  assert.equal(row['رقم البراد'], cooler.no);
  assert.equal(row['معرّف المزارع'], farmer.id);
  assert.equal(row['اسم المزارع'], 'حسن البدري');
  assert.equal(row['عدد الصناديق'], 50);
  assert.equal(row['متوسط وزن الصندوق (كغ)'], 11);
  assert.equal(row['طريقة حساب الوزن'], 'مباشر');
  assert.equal(row['إجمالي الوزن (كغ)'], 550);
  assert.equal(row['سعر الكيلو (ج.م)'], 15);
  assert.equal(row['إجمالي السعر (ج.م)'], 8250);
  assert.equal(piasters(row['المدفوع (ج.م)']), 0);
  assert.equal(row['المتبقي (ج.م)'], 8250);
  assert.equal(row['حالة الدفع'], 'غير مدفوع');
  assert.equal(row['الحالة'], 'فعّالة');
  assert.ok(isDate(row['تاريخ ووقت العملية']));
  assert.ok(isDate(row['تاريخ الإنشاء الفعلي']));
  assert.ok(String(row['أنشأها']).length > 0);
  assert.equal(row['الإصدار'], 1);
  assert.equal(row['مفتاح عدم التكرار'], rid, 'requestId stored in the idempotency column');
});

test('value = round_half_up(totalWeightGrams x pricePerKgPiasters / 1000)', () => {
  const { env, admin, cooler, farmer } = setup();
  const cases = [
    [1, 500, 1001, 501], // 500.5 -> 501
    [1, 1500, 1, 2], // 1.5 -> 2
    [3, 333, 1501, 1499], // 999 g x 1501 / 1000 = 1499.499 -> 1499
    [7, 12345, 1777, 153559], // 86415 g x 1777 / 1000 = 153559.455 -> 153559
    [100000, 60000, 100000, 600000000000], // the limits
  ];
  for (const [boxes, avg, price, expected] of cases) {
    const p = buy(env, admin, cooler, farmer, { boxes, avgWeightGrams: avg, pricePerKgPiasters: price }).purchase;
    assert.equal(p.totalWeightGrams, boxes * avg, `weight ${boxes}x${avg}`);
    assert.equal(p.valuePiasters, expected, `value ${boxes}x${avg}x${price}`);
    assert.equal(purchaseValue(boxes, avg, price).valuePiasters, expected);
    const row = env.findRow('purchases', p.id);
    assert.equal(piasters(row['إجمالي السعر (ج.م)']), expected, 'sheet value in EGP converts back exactly');
    assert.equal(grams(row['إجمالي الوزن (كغ)']), boxes * avg, 'sheet weight in kg converts back exactly');
    assert.equal(grams(row['متوسط وزن الصندوق (كغ)']), avg, 'average weight kg with 3 decimals');
    assert.equal(piasters(row['سعر الكيلو (ج.م)']), price);
  }
});

test('payment mode full: a payment equal to the value is recorded; cached paid/remaining/status on the purchase', () => {
  const { env, admin, cooler, farmer } = setup();
  const rid = uuid();
  const d = buy(env, admin, cooler, farmer, { payment: { mode: 'full', method: 'cash' } }, rid);
  assert.ok(d.payment, 'payment returned');
  assert.equal(d.payment.amountPiasters, 825000);
  assert.equal(d.payment.targetType, 'purchase');
  assert.equal(d.payment.targetId, d.purchase.id);
  assert.equal(d.payment.payeeType, 'farmer');
  assert.equal(d.payment.payeeId, farmer.id);
  assert.equal(d.payment.method, 'cash');
  assert.equal(d.payment.status, 'active');
  assert.match(d.payment.id, /^PY-\d{4,}$/);
  assert.match(d.payment.no, /^D-\d{4}$/);
  assert.equal(d.purchase.paidPiasters, 825000);
  assert.equal(d.purchase.remainingPiasters, 0);
  assert.equal(d.purchase.payStatus, 'paid');
  const row = env.findRow('purchases', d.purchase.id);
  assert.equal(row['المدفوع (ج.م)'], 8250);
  assert.equal(piasters(row['المتبقي (ج.م)']), 0);
  assert.equal(row['حالة الدفع'], 'مدفوع');
  const pays = env.readSheet('payments');
  assert.equal(pays.length, 1);
  assert.equal(pays[0]['المعرّف'], d.payment.id);
  assert.equal(pays[0]['رقم الدفعة'], d.payment.no);
  assert.equal(pays[0]['نوع المستفيد'], 'مزارع');
  assert.equal(pays[0]['اسم المستفيد'], 'حسن البدري');
  assert.equal(pays[0]['معرّف المستفيد'], farmer.id);
  assert.equal(pays[0]['نوع العملية'], 'شراء رمان');
  assert.equal(pays[0]['معرّف العملية'], d.purchase.id);
  assert.equal(pays[0]['معرّف البراد'], cooler.id);
  assert.equal(pays[0]['المبلغ (ج.م)'], 8250);
  assert.equal(pays[0]['طريقة الدفع'], 'نقدًا');
  assert.equal(pays[0]['الحالة'], 'فعّالة');
  assert.ok(isDate(pays[0]['تاريخ الدفعة']));
});

test('payment mode partial and none', () => {
  const { env, admin, cooler, farmer } = setup();
  const part = buy(env, admin, cooler, farmer, { payment: { mode: 'partial', amountPiasters: 300000, method: 'wallet' } });
  assert.equal(part.payment.amountPiasters, 300000);
  assert.equal(part.payment.method, 'wallet');
  assert.equal(part.purchase.paidPiasters, 300000);
  assert.equal(part.purchase.remainingPiasters, 525000);
  assert.equal(part.purchase.payStatus, 'partial');
  const prow = env.findRow('purchases', part.purchase.id);
  assert.equal(prow['المدفوع (ج.م)'], 3000);
  assert.equal(prow['المتبقي (ج.م)'], 5250);
  assert.equal(prow['حالة الدفع'], 'جزئي');
  assert.equal(env.readSheet('payments')[0]['طريقة الدفع'], 'محفظة إلكترونية');

  const none = buy(env, admin, cooler, farmer, { payment: { mode: 'none' } });
  assert.equal(none.payment, null);
  assert.equal(none.purchase.paidPiasters, 0);
  assert.equal(none.purchase.remainingPiasters, 825000);
  assert.equal(none.purchase.payStatus, 'unpaid');
  assert.equal(env.readSheet('payments').length, 1, 'no payment row for mode none');
});

test('partial payment must be > 0 and < value -> VALIDATION naming the field; nothing written', () => {
  const { env, admin, cooler, farmer } = setup();
  const before = dataSnapshot(env);
  const field = /^(payment\.amountPiasters|payment|amountPiasters)$/;
  for (const amount of [825000, 900000, 0, -5, 12.5]) {
    failField(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer,
      { payment: { mode: 'partial', amountPiasters: amount, method: 'cash' } })), field, /مبلغ|دفع|مدفوع/,
    `partial ${amount}`);
  }
  failField(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer,
    { payment: { mode: 'partial', method: 'cash' } })), field, null, 'partial without amount');
  failField(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer,
    { payment: { mode: 'later' } })), /^(payment\.mode|payment|mode)$/, null, 'unknown payment mode');
  assertNothingWritten(env, before, 'invalid payments');
});

test('boxes validation: 0, negative, non-integer, too large, missing, text -> VALIDATION on boxes with an Arabic message', () => {
  const { env, admin, cooler, farmer } = setup();
  const before = dataSnapshot(env);
  for (const boxes of [0, -3, 2.5, 100001, null, 'خمسون', '']) {
    const payload = purchasePayload(cooler, farmer, { boxes });
    if (boxes === null) delete payload.boxes;
    failField(env.call(admin, 'purchases.create', payload), 'boxes', /صناديق/, `boxes=${JSON.stringify(boxes)}`);
  }
  assertNothingWritten(env, before, 'invalid boxes');
  ok(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer, { boxes: 100000 })), 'boxes = 100000 is allowed');
  ok(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer, { boxes: 1 })), 'boxes = 1 is allowed');
});

test('avgWeightGrams and pricePerKgPiasters limits; weightMethod must be direct|sample', () => {
  const { env, admin, cooler, farmer } = setup();
  const before = dataSnapshot(env);
  for (const v of [0, -1, 60001, 10.5, 'x']) {
    failField(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer, { avgWeightGrams: v })),
      'avgWeightGrams', /وزن/, `avgWeightGrams=${v}`);
  }
  for (const v of [0, -1, 100001, 1.5, 'x']) {
    failField(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer, { pricePerKgPiasters: v })),
      'pricePerKgPiasters', /سعر/, `pricePerKgPiasters=${v}`);
  }
  failField(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer, { weightMethod: 'guess' })),
    'weightMethod', /طريقة/);
  assertNothingWritten(env, before, 'invalid weight/price');
  ok(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer, { avgWeightGrams: 60000, pricePerKgPiasters: 100000 })));
});

test('unknown cooler / farmer, or no farmer at all -> rejected without writing', () => {
  const { env, admin, cooler, farmer } = setup();
  const before = dataSnapshot(env);
  failUnknownRef(env.call(admin, 'purchases.create', purchasePayload({ id: 'CL-9999' }, farmer)), 'coolerId');
  failUnknownRef(env.call(admin, 'purchases.create', purchasePayload(cooler, { id: 'FR-9999' })), 'farmerId');
  failField(env.call(admin, 'purchases.create', purchasePayload(cooler, null)), /^(farmerId|newFarmerName)$/);
  assertNothingWritten(env, before, 'bad references');
});

test('newFarmerName creates the farmer (number max+1) together with the purchase', () => {
  const { env, admin, cooler, farmer } = setup();
  const d = ok(env.call(admin, 'purchases.create', purchasePayload(cooler, null, { newFarmerName: 'سعيد الجديد' })));
  assert.ok(d.farmer, 'farmer returned');
  assert.match(d.farmer.id, /^FR-\d{4,}$/);
  assert.equal(d.farmer.name, 'سعيد الجديد');
  assert.equal(d.farmer.no, farmer.no + 1);
  assert.equal(d.purchase.farmerId, d.farmer.id);
  assert.equal(d.purchase.farmerName, 'سعيد الجديد');
  const fr = env.findRow('farmers', d.farmer.id);
  assert.equal(fr['الاسم'], 'سعيد الجديد');
  assert.equal(fr['الحالة'], 'نشط');
});

test('sample method: avg must equal round(mean(sample) - tare) within 1 g; tare defaults to the settings value', () => {
  const { env, admin, cooler, farmer } = setup();
  const sample = [12400, 12900, 12600];
  // mean 12633.33 - tare 1900 = 10733.33 -> 10733
  const base = { weightMethod: 'sample', sampleWeightsGrams: sample, boxes: 10 };
  const d = buy(env, admin, cooler, farmer, Object.assign({ avgWeightGrams: 10733, tareGrams: 1900 }, base)).purchase;
  assert.equal(d.weightMethod, 'sample');
  assert.deepEqual(d.sampleWeightsGrams, sample);
  assert.equal(d.tareGrams, 1900);
  assert.equal(d.totalWeightGrams, 107330);
  const row = env.findRow('purchases', d.id);
  assert.equal(row['طريقة حساب الوزن'], 'عينة');
  assert.deepEqual(String(row['أوزان العينة (كغ)']).split(/\s*،\s*/).map(Number), [12.4, 12.9, 12.6],
    'stored as text "12.4، 12.9، 12.6" (kg)');
  assert.equal(grams(row['وزن الصندوق الفارغ (كغ)']), 1900);

  ok(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer, Object.assign({ avgWeightGrams: 10734 }, base))),
    'within 1 g, default tare 1.9 kg from settings');
  ok(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer, Object.assign({ avgWeightGrams: 10732 }, base))),
    'within 1 g below');
  const before = dataSnapshot(env);
  failField(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer, Object.assign({ avgWeightGrams: 10735 }, base))),
    'avgWeightGrams', /وزن|عينة/, 'avg 2 g off');
  failField(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer,
    Object.assign({}, base, { avgWeightGrams: 12633 }))), 'avgWeightGrams', null, 'tare ignored');
  assertNothingWritten(env, before, 'bad sample average');
});

test('sample method with explicit tare 0 and with a tare from updated settings', () => {
  const { env, admin, cooler, farmer } = setup();
  const sample = [10000, 10001];
  ok(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer, { weightMethod: 'sample',
    sampleWeightsGrams: sample, tareGrams: 0, avgWeightGrams: 10001 })), 'tare 0: round(10000.5) = 10001');
  ok(env.call(admin, 'settings.update', { emptyBoxGrams: 2000 }), 'settings.update emptyBoxGrams');
  const p = ok(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer, { weightMethod: 'sample',
    sampleWeightsGrams: [12000, 12000], avgWeightGrams: 10000 })), 'default tare now 2 kg').purchase;
  assert.equal(p.tareGrams, 2000);
});

test('sample validation: empty, more than 200, non-positive or non-integer weights, negative tare', () => {
  const { env, admin, cooler, farmer } = setup();
  const before = dataSnapshot(env);
  const mk = (o) => purchasePayload(cooler, farmer, Object.assign({ weightMethod: 'sample', avgWeightGrams: 10000 }, o));
  failField(env.call(admin, 'purchases.create', mk({ sampleWeightsGrams: [] })), 'sampleWeightsGrams', /عينة/);
  failField(env.call(admin, 'purchases.create', mk({})), 'sampleWeightsGrams', /عينة/, 'missing sample');
  failField(env.call(admin, 'purchases.create', mk({ sampleWeightsGrams: new Array(201).fill(11900) })),
    'sampleWeightsGrams', /عينة/, '201 weights');
  failField(env.call(admin, 'purchases.create', mk({ sampleWeightsGrams: [11900, 0] })), 'sampleWeightsGrams', /عينة/);
  failField(env.call(admin, 'purchases.create', mk({ sampleWeightsGrams: [11900, 11900.5] })), 'sampleWeightsGrams', /عينة/);
  failField(env.call(admin, 'purchases.create', mk({ sampleWeightsGrams: [11900], tareGrams: -1 })), 'tareGrams',
    /فارغ|صندوق|طرح/);
  assertNothingWritten(env, before, 'invalid samples');
  ok(env.call(admin, 'purchases.create', mk({ sampleWeightsGrams: new Array(200).fill(11900) })), '200 weights allowed');
});

test('occurredAt input is stored and returned in the business time zone; creation time is separate', () => {
  const { env, admin, cooler, farmer } = setup();
  const p = buy(env, admin, cooler, farmer, { occurredAt: '2026-09-30T05:15:00Z' }).purchase;
  assert.equal(p.occurredAt, '2026-09-30T08:15:00+03:00');
  assertNear(env, p.createdAt, 'createdAt is the real creation time');
  const row = env.findRow('purchases', p.id);
  assert.equal(row['تاريخ ووقت العملية'].getTime(), Date.parse('2026-09-30T05:15:00Z'));
  assert.ok(Math.abs(row['تاريخ الإنشاء الفعلي'].getTime() - env.clock.now()) < 5000);
  const q = buy(env, admin, cooler, farmer, { occurredAt: '2026-09-29T21:40:00+03:00' }).purchase;
  assert.equal(q.occurredAt, '2026-09-29T21:40:00+03:00');
  failField(env.call(admin, 'purchases.create', purchasePayload(cooler, farmer, { occurredAt: 'أمس' })), 'occurredAt');
});

test('timestamps follow the time zone from settings', () => {
  const { env, admin, cooler, farmer } = setup();
  ok(env.call(admin, 'settings.update', { timezone: 'Asia/Dubai' }));
  const res = env.call(admin, 'purchases.create', purchasePayload(cooler, farmer, { occurredAt: '2026-09-30T05:15:00Z' }));
  const p = ok(res).purchase;
  assert.equal(p.occurredAt, '2026-09-30T09:15:00+04:00');
  assertIsoInZone(p.createdAt, 'Asia/Dubai', 'createdAt in Asia/Dubai');
  assertIsoInZone(res.serverTime, 'Asia/Dubai', 'serverTime in Asia/Dubai');
});

test('purchases.update recomputes value, bumps version, sets updatedAt/By, audits old/new values', () => {
  const { env, admin, cooler, farmer } = setup();
  const p = buy(env, admin, cooler, farmer, { payment: { mode: 'full', method: 'cash' } }).purchase;
  const auditBefore = auditRows(env).length;
  const u = ok(env.call(admin, 'purchases.update', { id: p.id, expectedVersion: p.version,
    changes: { boxes: 60, pricePerKgPiasters: 1600 } }), 'update').purchase;
  assert.equal(u.boxes, 60);
  assert.equal(u.totalWeightGrams, 660000);
  assert.equal(u.valuePiasters, 1056000);
  assert.equal(u.paidPiasters, 825000);
  assert.equal(u.remainingPiasters, 231000);
  assert.equal(u.payStatus, 'partial');
  assert.ok(u.version > p.version);
  assertIsoInZone(u.updatedAt, BUSINESS_TZ, 'updatedAt');
  assert.ok(String(u.updatedBy).length > 0);
  const row = env.findRow('purchases', p.id);
  assert.equal(row['عدد الصناديق'], 60);
  assert.equal(row['إجمالي السعر (ج.م)'], 10560);
  assert.equal(row['حالة الدفع'], 'جزئي');
  assert.equal(row['الإصدار'], u.version);
  assert.ok(isDate(row['آخر تعديل']));
  assert.ok(String(row['عدّلها']).length > 0);
  const a = auditRows(env).slice(auditBefore).find((r) => r['الإجراء'] === 'تعديل' && r['معرّف السجل'] === p.id);
  assert.ok(a, 'audit تعديل');
  assert.equal(a['نوع السجل'], 'شراء رمان');
  const prev = JSON.parse(a['القيم السابقة']);
  const next = JSON.parse(a['القيم الجديدة']);
  assert.ok(JSON.stringify(prev).includes('50'), 'previous values mention the old boxes');
  assert.ok(JSON.stringify(next).includes('60'), 'new values mention the new boxes');
});

test('purchases.update: stale version -> CONFLICT; value below paid -> VALIDATION; unknown id -> NOT_FOUND', () => {
  const { env, admin, cooler, farmer } = setup();
  const p = buy(env, admin, cooler, farmer, { payment: { mode: 'partial', amountPiasters: 500000, method: 'cash' } }).purchase;
  const u = ok(env.call(admin, 'purchases.update', { id: p.id, expectedVersion: p.version, changes: { notes: 'أ' } })).purchase;
  const before = dataSnapshot(env);
  const e = fail(env.call(admin, 'purchases.update', { id: p.id, expectedVersion: p.version, changes: { boxes: 40 } }), 'CONFLICT');
  assert.equal(e.details.currentVersion, u.version);
  assert.equal(e.details.current.id, p.id);
  assert.equal(e.details.current.notes, 'أ');
  // 20 boxes -> 330000 < 500000 already paid
  fail(env.call(admin, 'purchases.update', { id: p.id, expectedVersion: u.version, changes: { boxes: 20 } }), 'VALIDATION');
  failField(env.call(admin, 'purchases.update', { id: p.id, expectedVersion: u.version, changes: { boxes: 0 } }),
    /boxes/, /صناديق/);
  fail(env.call(admin, 'purchases.update', { id: 'PU-9999', expectedVersion: 1, changes: { boxes: 2 } }), 'NOT_FOUND');
  assertNothingWritten(env, before, 'rejected updates');
});

test('purchases.cancel: reason required; blocked while active payments exist; sets status + reason, row kept', () => {
  const { env, admin, cooler, farmer } = setup();
  const d = buy(env, admin, cooler, farmer, { payment: { mode: 'partial', amountPiasters: 1000, method: 'cash' } });
  failField(env.call(admin, 'purchases.cancel', { id: d.purchase.id }), 'reason', /سبب/);
  const e = fail(env.call(admin, 'purchases.cancel', { id: d.purchase.id, reason: 'خطأ' }), 'VALIDATION');
  assert.match(e.message, /دفع/, 'tells the user to cancel the payments first');
  ok(env.call(admin, 'payments.cancel', { id: d.payment.id, reason: 'خطأ' }), 'payments.cancel');
  const auditBefore = auditRows(env).length;
  const c = ok(env.call(admin, 'purchases.cancel', { id: d.purchase.id, reason: 'إدخال مكرر' })).purchase;
  assert.equal(c.status, 'cancelled');
  assert.equal(c.cancelReason, 'إدخال مكرر');
  const row = env.findRow('purchases', d.purchase.id);
  assert.equal(row['الحالة'], 'ملغاة');
  assert.equal(row['سبب الإلغاء'], 'إدخال مكرر');
  assert.equal(env.readSheet('purchases').length, 1, 'the row is kept');
  const a = auditRows(env).slice(auditBefore).find((r) => r['الإجراء'] === 'إلغاء');
  assert.ok(a && a['معرّف السجل'] === d.purchase.id && a['السبب'] === 'إدخال مكرر', 'audit إلغاء with reason');
  const list = ok(env.call(admin, 'purchases.list', {})).purchases;
  assert.equal(list.some((x) => x.id === d.purchase.id), false, 'cancelled purchases hidden by default');
  assert.equal(getPurchase(env, admin, d.purchase.id).status, 'cancelled', 'includeCancelled shows it');
});

test('purchases.list filters by cooler, farmer and occurredAt range', () => {
  const { env, admin, cooler, farmer } = setup();
  const other = newCooler(env, admin);
  const f2 = newFarmer(env, admin, 'محمود');
  const a = buy(env, admin, cooler, farmer, { occurredAt: '2026-09-01T10:00:00+03:00' }).purchase;
  const b = buy(env, admin, cooler, f2, { occurredAt: '2026-09-10T10:00:00+03:00' }).purchase;
  const c = buy(env, admin, other, farmer, { occurredAt: '2026-09-20T10:00:00+03:00' }).purchase;
  const ids = (payload) => ok(env.call(admin, 'purchases.list', payload)).purchases.map((p) => p.id).sort();
  assert.deepEqual(ids({ coolerId: cooler.id }), [a.id, b.id].sort());
  assert.deepEqual(ids({ farmerId: farmer.id }), [a.id, c.id].sort());
  assert.deepEqual(ids({ from: '2026-09-05T00:00:00+03:00' }), [b.id, c.id].sort());
  assert.deepEqual(ids({ from: '2026-09-05T00:00:00+03:00', to: '2026-09-15T00:00:00+03:00' }), [b.id]);
  assert.ok(idNum(c.id) > idNum(a.id));
});
