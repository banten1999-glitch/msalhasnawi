'use strict';
/**
 * Coolers: numbering, close with snapshot, reopen, COOLER_CLOSED (docs/API.md sections 4, 6, 7).
 */
const test = require('node:test');
const {
  assert, ok, fail, failField, adminEnv, newCooler, newFarmer, buy, pay, getCooler, closeCooler, purchasePayload,
  auditRows, assertIsoInZone, assertNear, isDate, idNum, grams, piasters, approvedPackaging, dataSnapshot,
  assertNothingWritten, purchaseValue, BUSINESS_TZ,
} = require('./helpers');

const SUMMARY_KEYS = ['id', 'no', 'name', 'status', 'carNo', 'driver', 'notes', 'openedAt', 'openedBy', 'closedAt',
  'closedBy', 'farmers', 'purchases', 'boxes', 'weightGrams', 'valuePiasters', 'paidPiasters', 'remainingPiasters',
  'packagingApprovedPiasters', 'packagingLatePiasters', 'totalCostPiasters', 'avgPricePerKgPiasters', 'version',
  'closeSnapshot'];
const SNAPSHOT_KEYS = ['farmers', 'purchases', 'boxes', 'weightGrams', 'valuePiasters', 'paidPiasters',
  'remainingPiasters', 'packagingPiasters', 'totalCostPiasters'];

function assertSummaryShape(c, label) {
  SUMMARY_KEYS.forEach((k) => assert.ok(k in c, `${label}: CoolerSummary.${k} missing`));
  assert.match(String(c.id), /^CL-\d{4,}$/);
  assert.ok(Number.isInteger(c.no) && c.no >= 1);
  assert.ok(['open', 'closed'].includes(c.status));
  assert.ok(Number.isInteger(c.version) && c.version >= 1);
  ['farmers', 'purchases', 'boxes', 'weightGrams', 'valuePiasters', 'paidPiasters', 'remainingPiasters',
    'packagingApprovedPiasters', 'packagingLatePiasters', 'totalCostPiasters', 'avgPricePerKgPiasters']
    .forEach((k) => assert.ok(Number.isInteger(c[k]), `${label}: ${k} must be an integer, got ${c[k]}`));
}

test('coolers.create: open cooler, number = max + 1, id CL-NNNN, row written with opener and version 1', () => {
  const { env, admin } = adminEnv();
  const a = newCooler(env, admin, { name: 'براد أ', carNo: 'ق ط ٥٤٣٢', driver: 'محمود', notes: 'ملاحظة' });
  assertSummaryShape(a, 'created cooler');
  assert.equal(a.no, 1);
  assert.equal(a.status, 'open');
  assert.equal(a.name, 'براد أ');
  assert.equal(a.carNo, 'ق ط ٥٤٣٢');
  assert.equal(a.driver, 'محمود');
  assert.equal(a.closeSnapshot, null);
  assert.equal(a.purchases, 0);
  assertIsoInZone(a.openedAt, BUSINESS_TZ, 'openedAt');
  assertNear(env, a.openedAt, 'openedAt');
  assert.equal(typeof a.openedBy, 'string');
  assert.ok(a.openedBy.length > 0);
  const b = newCooler(env, admin);
  assert.equal(b.no, 2);
  assert.equal(idNum(b.id), idNum(a.id) + 1);

  const row = env.findRow('coolers', a.id);
  assert.equal(row['رقم البراد'], 1);
  assert.equal(row['الاسم / الوصف'], 'براد أ');
  assert.equal(row['رقم السيارة'], 'ق ط ٥٤٣٢');
  assert.equal(row['السائق'], 'محمود');
  assert.equal(row['الحالة'], 'مفتوح');
  assert.ok(isDate(row['تاريخ ووقت الفتح']));
  assert.ok(String(row['فتحه']).length > 0);
  assert.equal(row['الإصدار'], 1);
  assert.equal(row['تاريخ ووقت التقفيل'], '');
});

test('coolers.create numbering follows the highest number/id already in the sheet', () => {
  const { env, admin } = adminEnv();
  newCooler(env, admin);
  env.appendRowObject('coolers', { 'المعرّف': 'CL-0007', 'رقم البراد': 10, 'الاسم / الوصف': 'أُضيف يدويًا',
    'الحالة': 'مقفّل', 'الإصدار': 1 });
  const c = newCooler(env, admin);
  assert.equal(c.no, 11, 'رقم البراد = max + 1');
  assert.equal(c.id, 'CL-0008', 'id = max numeric suffix + 1');
});

test('coolers.list: newest first, status filter; coolers.get returns purchases and packaging', () => {
  const { env, admin } = adminEnv();
  const c1 = newCooler(env, admin, { name: 'أول' });
  const c2 = newCooler(env, admin, { name: 'ثاني' });
  const c3 = newCooler(env, admin, { name: 'ثالث' });
  closeCooler(env, admin, c2);
  const all = ok(env.call(admin, 'coolers.list', { status: 'all' })).coolers;
  assert.deepEqual(all.map((c) => c.no), [3, 2, 1], 'newest first');
  all.forEach((c) => assertSummaryShape(c, `list ${c.no}`));
  assert.deepEqual(ok(env.call(admin, 'coolers.list', { status: 'open' })).coolers.map((c) => c.id), [c3.id, c1.id]);
  assert.deepEqual(ok(env.call(admin, 'coolers.list', { status: 'closed' })).coolers.map((c) => c.id), [c2.id]);
  const farmer = newFarmer(env, admin, 'حسن');
  const p = buy(env, admin, c1, farmer).purchase;
  const got = ok(env.call(admin, 'coolers.get', { id: c1.id }), 'coolers.get');
  assert.equal(got.cooler.id, c1.id);
  assert.ok(Array.isArray(got.purchases) && got.purchases.some((x) => x.id === p.id));
  assert.ok(Array.isArray(got.packaging));
  fail(env.call(admin, 'coolers.get', { id: 'CL-9999' }), 'NOT_FOUND');
});

test('live cooler figures come from active purchases and payments', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f1 = newFarmer(env, admin, 'حسن');
  const f2 = newFarmer(env, admin, 'محمود');
  buy(env, admin, c, f1, { payment: { mode: 'full', method: 'cash' } }); // 550000 g, 825000
  const p2 = buy(env, admin, c, f1, { boxes: 20, avgWeightGrams: 12000, pricePerKgPiasters: 1600 }).purchase; // 240000 g, 384000
  pay(env, admin, 'purchase', p2.id, 100000);
  const p3 = buy(env, admin, c, f2, { boxes: 5, avgWeightGrams: 10000, pricePerKgPiasters: 1000 }).purchase;
  ok(env.call(admin, 'purchases.cancel', { id: p3.id, reason: 'خطأ' }));
  const live = getCooler(env, admin, c.id);
  assert.equal(live.farmers, 1, 'distinct farmers among active purchases');
  assert.equal(live.purchases, 2);
  assert.equal(live.boxes, 70);
  assert.equal(live.weightGrams, 790000);
  assert.equal(live.valuePiasters, 1209000);
  assert.equal(live.paidPiasters, 925000);
  assert.equal(live.remainingPiasters, 284000);
  assert.equal(live.avgPricePerKgPiasters, Math.round(1209000 * 1000 / 790000));
});

test('coolers.close: clientPendingCount > 0 -> VALIDATION, nothing written', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const before = dataSnapshot(env);
  failField(env.call(admin, 'coolers.close', { id: c.id, expectedVersion: c.version, clientPendingCount: 2 }),
    'clientPendingCount', /مزامنة/);
  assertNothingWritten(env, before, 'close with pending operations');
});

test('coolers.close: stale expectedVersion -> CONFLICT with currentVersion and the fresh record', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const res = env.call(admin, 'coolers.close', { id: c.id, expectedVersion: c.version + 5, clientPendingCount: 0 });
  const e = fail(res, 'CONFLICT');
  assert.equal(e.details.currentVersion, c.version);
  assert.equal(e.details.current && e.details.current.id, c.id);
  assert.equal(env.findRow('coolers', c.id)['الحالة'], 'مفتوح');
  fail(env.call(admin, 'coolers.close', { id: 'CL-9999', expectedVersion: 1, clientPendingCount: 0 }), 'NOT_FOUND');
});

test('close snapshot: distinct farmers counted once, totals equal the sums, cancelled purchases excluded', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const other = newCooler(env, admin);
  const f1 = newFarmer(env, admin, 'حسن البدري');
  const f2 = newFarmer(env, admin, 'محمود عيسى');
  const lines = [
    [f1, 50, 11000, 1500, { mode: 'full', method: 'cash' }],
    [f1, 20, 12000, 1600, { mode: 'partial', amountPiasters: 100000, method: 'bank' }],
    [f2, 10, 10500, 1450, { mode: 'none' }],
  ];
  const created = lines.map(([f, boxes, avg, price, payment]) =>
    buy(env, admin, c, f, { boxes, avgWeightGrams: avg, pricePerKgPiasters: price, payment }).purchase);
  pay(env, admin, 'purchase', created[2].id, 50000, { method: 'wallet' });
  const cancelled = buy(env, admin, c, f2, { boxes: 5, avgWeightGrams: 10000, pricePerKgPiasters: 1000 }).purchase;
  ok(env.call(admin, 'purchases.cancel', { id: cancelled.id, reason: 'إدخال مكرر' }));
  buy(env, admin, other, f2, { boxes: 99 }); // another cooler: not included

  const expWeight = lines.reduce((a, l) => a + purchaseValue(l[1], l[2], l[3]).totalWeightGrams, 0);
  const expValue = lines.reduce((a, l) => a + purchaseValue(l[1], l[2], l[3]).valuePiasters, 0);
  assert.equal(expWeight, 895000);
  assert.equal(expValue, 1361250);
  const expPaid = 825000 + 100000 + 50000;

  const auditBefore = auditRows(env).length;
  const closed = closeCooler(env, admin, c);
  assert.equal(closed.status, 'closed');
  assertIsoInZone(closed.closedAt, BUSINESS_TZ, 'closedAt');
  assert.ok(String(closed.closedBy).length > 0);
  const snap = closed.closeSnapshot;
  assert.ok(snap, 'closeSnapshot present after close');
  SNAPSHOT_KEYS.forEach((k) => assert.ok(Number.isInteger(snap[k]), `snapshot.${k} integer`));
  assert.equal(snap.farmers, 2, 'the same farmer selling twice counts once');
  assert.equal(snap.purchases, 3);
  assert.equal(snap.boxes, 80);
  assert.equal(snap.weightGrams, expWeight);
  assert.equal(snap.valuePiasters, expValue);
  assert.equal(snap.paidPiasters, expPaid);
  assert.equal(snap.remainingPiasters, expValue - expPaid);
  assert.equal(snap.packagingPiasters, 0);
  assert.equal(snap.totalCostPiasters, expValue);

  const row = env.findRow('coolers', c.id);
  assert.equal(row['الحالة'], 'مقفّل');
  assert.ok(isDate(row['تاريخ ووقت التقفيل']));
  assert.ok(String(row['قفّله']).length > 0);
  assert.equal(row['عدد المزارعين عند التقفيل'], 2);
  assert.equal(row['عدد العمليات عند التقفيل'], 3);
  assert.equal(row['الصناديق عند التقفيل'], 80);
  assert.equal(grams(row['الوزن عند التقفيل (كغ)']), expWeight);
  assert.equal(row['الوزن عند التقفيل (كغ)'], 895);
  assert.equal(piasters(row['قيمة الرمان عند التقفيل (ج.م)']), expValue);
  assert.equal(piasters(row['المدفوع عند التقفيل (ج.م)']), expPaid);
  assert.equal(piasters(row['المتبقي عند التقفيل (ج.م)']), expValue - expPaid);
  assert.equal(piasters(row['إجمالي التكلفة عند التقفيل (ج.م)']), expValue);
  assert.ok(Number(row['الإصدار']) > 1, 'version bumped');
  assert.ok(isDate(row['آخر تعديل']), 'آخر تعديل set');
  assert.ok(String(row['عدّله']).length > 0, 'عدّله set');

  const audit = auditRows(env).slice(auditBefore);
  assert.ok(audit.some((r) => r['الإجراء'] === 'تقفيل' && r['نوع السجل'] === 'براد' && r['معرّف السجل'] === c.id),
    'audit row تقفيل');
});

test('close snapshot includes approved packaging linked to the cooler in packaging and total cost', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  buy(env, admin, c, f); // 825000
  approvedPackaging(env, admin, c, [{ name: 'الصناديق', quantity: 100, unit: 'قطعة', unitPricePiasters: 1500 }]);
  const closed = closeCooler(env, admin, c);
  assert.equal(closed.closeSnapshot.packagingPiasters, 150000);
  assert.equal(closed.closeSnapshot.totalCostPiasters, 825000 + 150000);
  const row = env.findRow('coolers', c.id);
  assert.equal(piasters(row['التعبئة عند التقفيل (ج.م)']), 150000);
  assert.equal(piasters(row['إجمالي التكلفة عند التقفيل (ج.م)']), 975000);
});

test('closing an already closed cooler -> COOLER_CLOSED', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const closed = closeCooler(env, admin, c);
  fail(env.call(admin, 'coolers.close', { id: c.id, expectedVersion: closed.version, clientPendingCount: 0 }),
    'COOLER_CLOSED');
});

test('COOLER_CLOSED for purchase create / update / cancel on a closed cooler; nothing written', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const p = buy(env, admin, c, f).purchase;
  closeCooler(env, admin, c);
  const before = dataSnapshot(env);
  fail(env.call(admin, 'purchases.create', purchasePayload(c, f)), 'COOLER_CLOSED', 'create');
  fail(env.call(admin, 'purchases.update', { id: p.id, expectedVersion: p.version, changes: { boxes: 51 } }),
    'COOLER_CLOSED', 'update');
  fail(env.call(admin, 'purchases.cancel', { id: p.id, reason: 'خطأ' }), 'COOLER_CLOSED', 'cancel');
  assertNothingWritten(env, before, 'operations on a closed cooler');
});

test('coolers.reopen: reason required, keeps the snapshot, audit إعادة فتح with the reason, purchases allowed again', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  buy(env, admin, c, f);
  const closed = closeCooler(env, admin, c);
  failField(env.call(admin, 'coolers.reopen', { id: c.id }), 'reason', /سبب/);
  failField(env.call(admin, 'coolers.reopen', { id: c.id, reason: '   ' }), 'reason', /سبب/);
  const rowClosed = env.findRow('coolers', c.id);
  const auditBefore = auditRows(env).length;
  const reopened = ok(env.call(admin, 'coolers.reopen', { id: c.id, reason: 'نسيت شحنة' }), 'reopen').cooler;
  assert.equal(reopened.status, 'open');
  assert.deepEqual(reopened.closeSnapshot, closed.closeSnapshot, 'snapshot kept');
  const row = env.findRow('coolers', c.id);
  assert.equal(row['الحالة'], 'مفتوح');
  ['عدد المزارعين عند التقفيل', 'عدد العمليات عند التقفيل', 'الصناديق عند التقفيل', 'الوزن عند التقفيل (كغ)',
    'قيمة الرمان عند التقفيل (ج.م)', 'المدفوع عند التقفيل (ج.م)', 'المتبقي عند التقفيل (ج.م)',
    'إجمالي التكلفة عند التقفيل (ج.م)'].forEach((h) => assert.equal(row[h], rowClosed[h], `${h} kept`));
  assert.ok(Number(row['الإصدار']) > Number(rowClosed['الإصدار']));
  const audit = auditRows(env).slice(auditBefore);
  const a = audit.find((r) => r['الإجراء'] === 'إعادة فتح');
  assert.ok(a, 'audit إعادة فتح');
  assert.equal(a['نوع السجل'], 'براد');
  assert.equal(a['معرّف السجل'], c.id);
  assert.equal(a['السبب'], 'نسيت شحنة');
  buy(env, admin, c, f, { boxes: 3 });
});
