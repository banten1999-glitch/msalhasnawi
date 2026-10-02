'use strict';
/**
 * Payments: amounts, caps, closed coolers, cancellation, packaging targets (docs/API.md section 6).
 */
const test = require('node:test');
const {
  assert, ok, fail, failField, failUnknownRef, adminEnv, newCooler, newFarmer, buy, pay, closeCooler, getPurchase,
  saveDraft, approvedPackaging, getPackaging, auditRows, assertIsoInZone, isDate, piasters, dataSnapshot,
  assertNothingWritten, uuid, BUSINESS_TZ,
} = require('./helpers');

const PAYMENT_KEYS = ['id', 'no', 'payeeType', 'payeeName', 'payeeId', 'targetType', 'targetId', 'coolerId', 'coolerNo',
  'amountPiasters', 'method', 'paidAt', 'status', 'cancelReason', 'notes', 'createdAt', 'createdBy', 'version'];

function setup() {
  const { env, admin } = adminEnv();
  const cooler = newCooler(env, admin);
  const farmer = newFarmer(env, admin, 'حسن البدري');
  const purchase = buy(env, admin, cooler, farmer).purchase; // 825000
  return { env, admin, cooler, farmer, purchase };
}

test('payments.create on a purchase: Payment object, target updated, sheet row, audit دفعة', () => {
  const { env, admin, cooler, farmer, purchase } = setup();
  const rid = uuid();
  const auditBefore = auditRows(env).length;
  const d = pay(env, admin, 'purchase', purchase.id, 200000, { method: 'bank', paidAt: '2026-10-01T09:30:00+03:00',
    notes: 'تحويل' }, rid);
  const p = d.payment;
  PAYMENT_KEYS.forEach((k) => assert.ok(k in p, `Payment.${k} missing`));
  assert.match(p.id, /^PY-\d{4,}$/);
  assert.match(p.no, /^D-\d{4}$/);
  assert.equal(p.payeeType, 'farmer');
  assert.equal(p.payeeName, 'حسن البدري');
  assert.equal(p.payeeId, farmer.id);
  assert.equal(p.targetType, 'purchase');
  assert.equal(p.targetId, purchase.id);
  assert.equal(p.coolerId, cooler.id);
  assert.equal(p.coolerNo, cooler.no);
  assert.equal(p.amountPiasters, 200000);
  assert.equal(p.method, 'bank');
  assert.equal(p.paidAt, '2026-10-01T09:30:00+03:00');
  assert.equal(p.status, 'active');
  assert.equal(p.notes, 'تحويل');
  assertIsoInZone(p.createdAt, BUSINESS_TZ, 'createdAt');
  assert.equal(d.target.id, purchase.id);
  assert.equal(d.target.paidPiasters, 200000);
  assert.equal(d.target.remainingPiasters, 625000);
  assert.equal(d.target.payStatus, 'partial');

  const row = env.findRow('payments', p.id);
  assert.equal(row['رقم الدفعة'], p.no);
  assert.equal(row['نوع المستفيد'], 'مزارع');
  assert.equal(row['نوع العملية'], 'شراء رمان');
  assert.equal(row['معرّف العملية'], purchase.id);
  assert.equal(row['المبلغ (ج.م)'], 2000);
  assert.equal(row['طريقة الدفع'], 'تحويل بنكي');
  assert.equal(row['تاريخ الدفعة'].getTime(), Date.parse('2026-10-01T09:30:00+03:00'));
  assert.ok(isDate(row['تاريخ الإنشاء']));
  assert.equal(row['الحالة'], 'فعّالة');
  assert.equal(row['الإصدار'], 1);
  assert.equal(row['مفتاح عدم التكرار'], rid);
  const prow = env.findRow('purchases', purchase.id);
  assert.equal(prow['المدفوع (ج.م)'], 2000);
  assert.equal(prow['المتبقي (ج.م)'], 6250);
  assert.equal(prow['حالة الدفع'], 'جزئي');
  const a = auditRows(env).slice(auditBefore).find((r) => r['الإجراء'] === 'دفعة');
  assert.ok(a, 'audit دفعة');
  assert.equal(a['نوع السجل'], 'دفعة');

  const second = pay(env, admin, 'purchase', purchase.id, 625000);
  assert.equal(second.target.payStatus, 'paid');
  assert.equal(second.target.remainingPiasters, 0);
  assert.equal(env.findRow('purchases', purchase.id)['حالة الدفع'], 'مدفوع');
  assert.match(second.payment.no, /^D-\d{4}$/);
  assert.notEqual(second.payment.no, p.no);
});

test('payment amount must be a positive integer <= remaining; method must be cash|bank|wallet', () => {
  const { env, admin, purchase } = setup();
  pay(env, admin, 'purchase', purchase.id, 800000);
  const before = dataSnapshot(env);
  const base = { targetType: 'purchase', targetId: purchase.id, method: 'cash' };
  for (const amount of [25001, 0, -10, 10.5, 'مئة']) {
    failField(env.call(admin, 'payments.create', Object.assign({ amountPiasters: amount }, base)), 'amountPiasters',
      /مبلغ/, `amount ${amount}`);
  }
  failField(env.call(admin, 'payments.create', Object.assign({}, base, { amountPiasters: 100, method: 'cheque' })),
    'method', /طريقة/);
  failField(env.call(admin, 'payments.create', Object.assign({}, base, { amountPiasters: 100, targetType: 'cooler' })),
    'targetType');
  failUnknownRef(env.call(admin, 'payments.create', Object.assign({}, base, { amountPiasters: 100, targetId: 'PU-9999' })),
    'targetId');
  assertNothingWritten(env, before, 'invalid payments');
  const last = pay(env, admin, 'purchase', purchase.id, 25000);
  assert.equal(last.target.remainingPiasters, 0, 'exactly the remaining amount is accepted');
});

test('payments on a closed cooler are allowed and capped at the remaining amount', () => {
  const { env, admin, cooler, purchase } = setup();
  pay(env, admin, 'purchase', purchase.id, 300000);
  closeCooler(env, admin, cooler);
  const before = dataSnapshot(env);
  failField(env.call(admin, 'payments.create', { targetType: 'purchase', targetId: purchase.id, amountPiasters: 525001,
    method: 'cash' }), 'amountPiasters', /مبلغ/, 'over the remaining amount on a closed cooler');
  assertNothingWritten(env, before, 'capped payment');
  const d = pay(env, admin, 'purchase', purchase.id, 525000);
  assert.equal(d.target.payStatus, 'paid');
  assert.equal(getPurchase(env, admin, purchase.id).remainingPiasters, 0);
  fail(env.call(admin, 'payments.create', { targetType: 'purchase', targetId: purchase.id, amountPiasters: 1,
    method: 'cash' }), 'VALIDATION', 'nothing left to pay');
});

test('payments.cancel: reason required; restores the target paid/remaining/status; row kept', () => {
  const { env, admin, purchase } = setup();
  const d = pay(env, admin, 'purchase', purchase.id, 825000);
  assert.equal(d.target.payStatus, 'paid');
  failField(env.call(admin, 'payments.cancel', { id: d.payment.id }), 'reason', /سبب/);
  const auditBefore = auditRows(env).length;
  const c = ok(env.call(admin, 'payments.cancel', { id: d.payment.id, reason: 'مبلغ خاطئ' }), 'payments.cancel');
  assert.equal(c.payment.status, 'cancelled');
  assert.equal(c.payment.cancelReason, 'مبلغ خاطئ');
  assert.equal(c.target.paidPiasters, 0);
  assert.equal(c.target.remainingPiasters, 825000);
  assert.equal(c.target.payStatus, 'unpaid');
  const row = env.findRow('payments', d.payment.id);
  assert.equal(row['الحالة'], 'ملغاة');
  assert.equal(row['سبب الإلغاء'], 'مبلغ خاطئ');
  const prow = env.findRow('purchases', purchase.id);
  assert.equal(piasters(prow['المدفوع (ج.م)']), 0);
  assert.equal(prow['حالة الدفع'], 'غير مدفوع');
  assert.equal(env.readSheet('payments').length, 1);
  const a = auditRows(env).slice(auditBefore).find((r) => r['معرّف السجل'] === d.payment.id);
  assert.ok(a && a['الإجراء'] === 'إلغاء' && a['السبب'] === 'مبلغ خاطئ', 'audit إلغاء for the payment');
  fail(env.call(admin, 'payments.cancel', { id: 'PY-9999', reason: 'x' }), 'NOT_FOUND');
});

test('payments.list filters by target, payee and cooler', () => {
  const { env, admin, cooler, farmer, purchase } = setup();
  const other = newCooler(env, admin);
  const f2 = newFarmer(env, admin, 'محمود');
  const p2 = buy(env, admin, other, f2).purchase;
  const a = pay(env, admin, 'purchase', purchase.id, 100).payment;
  const b = pay(env, admin, 'purchase', p2.id, 200).payment;
  const ids = (payload) => ok(env.call(admin, 'payments.list', payload)).payments.map((p) => p.id).sort();
  assert.deepEqual(ids({ targetId: purchase.id }), [a.id]);
  assert.deepEqual(ids({ payeeId: f2.id }), [b.id]);
  assert.deepEqual(ids({ coolerId: cooler.id }), [a.id]);
  assert.deepEqual(ids({}), [a.id, b.id].sort());
  assert.equal(farmer.id !== f2.id, true);
});

test('packaging payments: the packaging must be approved; payee is the supplier; capped at its remaining', () => {
  const { env, admin, cooler } = setup();
  const draft = saveDraft(env, admin, { supplier: 'مورد الكراتين', coolerId: cooler.id,
    items: [{ name: 'الصناديق', quantity: 100, unit: 'قطعة', unitPricePiasters: 1500 }] });
  const before = dataSnapshot(env);
  fail(env.call(admin, 'payments.create', { targetType: 'packaging', targetId: draft.packaging.id, amountPiasters: 100,
    method: 'cash' }), 'VALIDATION', 'draft packaging cannot be paid');
  assertNothingWritten(env, before, 'payment on a draft');
  const appr = ok(env.call(admin, 'packaging.approve', { id: draft.packaging.id, expectedVersion: draft.packaging.version }));
  failField(env.call(admin, 'payments.create', { targetType: 'packaging', targetId: draft.packaging.id,
    amountPiasters: 150001, method: 'cash' }), 'amountPiasters', /مبلغ/);
  const d = pay(env, admin, 'packaging', appr.packaging.id, 50000);
  assert.equal(d.payment.payeeType, 'supplier');
  assert.equal(d.payment.payeeName, 'مورد الكراتين');
  assert.equal(d.payment.targetType, 'packaging');
  assert.equal(d.target.id, appr.packaging.id);
  assert.equal(d.target.paidPiasters, 50000);
  assert.equal(d.target.remainingPiasters, 100000);
  const row = env.findRow('payments', d.payment.id);
  assert.equal(row['نوع المستفيد'], 'مورد');
  assert.equal(row['نوع العملية'], 'شراء تعبئة');
  const pk = env.findRow('packaging', appr.packaging.id);
  assert.equal(pk['المدفوع (ج.م)'], 500);
  assert.equal(pk['المتبقي (ج.م)'], 1000);
  assert.equal(getPackaging(env, admin, appr.packaging.id).packaging.paidPiasters, 50000);
  // packaging.cancel is blocked while active payments exist
  const e = fail(env.call(admin, 'packaging.cancel', { id: appr.packaging.id, reason: 'خطأ' }), 'VALIDATION');
  assert.match(e.message, /دفع/);
  approvedPackaging(env, admin, cooler, [{ name: 'الشريط', quantity: 1, unit: 'رول', unitPricePiasters: 100 }]);
});
