'use strict';
/**
 * Packaging purchases: drafts with incomplete items, removed items, approve, late cost
 * (docs/API.md sections 4 and 6).
 */
const test = require('node:test');
const {
  assert, ok, fail, failField, adminEnv, newCooler, newFarmer, buy, closeCooler, getCooler, saveDraft, getPackaging,
  auditRows, assertIsoInZone, isDate, piasters, dataSnapshot, assertNothingWritten, uuid, BUSINESS_TZ,
} = require('./helpers');

const SUMMARY_KEYS = ['id', 'no', 'supplier', 'invoiceNo', 'occurredAt', 'coolerId', 'coolerNo', 'status', 'itemsCount',
  'incompleteCount', 'completeTotalPiasters', 'paidPiasters', 'remainingPiasters', 'late', 'notes', 'createdAt',
  'createdBy', 'version'];
const ITEM_KEYS = ['id', 'name', 'quantity', 'unit', 'unitPricePiasters', 'totalPiasters', 'status', 'notes', 'version'];

function setup() {
  const { env, admin } = adminEnv();
  const cooler = newCooler(env, admin, { name: 'براد ٧' });
  return { env, admin, cooler };
}

test('packaging.save creates a draft; empty quantity/price stay empty (never 0) and mark the item incomplete', () => {
  const { env, admin, cooler } = setup();
  const rid = uuid();
  const d = saveDraft(env, admin, { supplier: 'مورد الكراتين', invoiceNo: 'INV-77', coolerId: cooler.id,
    occurredAt: '2026-10-01T11:00:00+03:00', notes: 'دفعة أولى',
    items: [
      { name: 'الصناديق', quantity: 100, unit: 'قطعة', unitPricePiasters: 1500 },
      { name: 'الملصقات', unit: 'رول' },
      { name: 'السترتش', quantity: 4, unit: 'لفة' },
    ] }, rid);
  const pk = d.packaging;
  SUMMARY_KEYS.forEach((k) => assert.ok(k in pk, `PackagingSummary.${k} missing`));
  assert.match(pk.id, /^PK-\d{4,}$/);
  assert.match(pk.no, /^P-\d{4}$/);
  assert.equal(pk.status, 'draft');
  assert.equal(pk.supplier, 'مورد الكراتين');
  assert.equal(pk.invoiceNo, 'INV-77');
  assert.equal(pk.coolerId, cooler.id);
  assert.equal(pk.coolerNo, cooler.no);
  assert.equal(pk.occurredAt, '2026-10-01T11:00:00+03:00');
  assert.equal(pk.itemsCount, 3);
  assert.equal(pk.incompleteCount, 2);
  assert.equal(pk.completeTotalPiasters, 150000);
  assert.equal(pk.paidPiasters, 0);
  assert.equal(pk.late, false);
  assertIsoInZone(pk.createdAt, BUSINESS_TZ, 'createdAt');
  assert.equal(d.items.length, 3);
  d.items.forEach((it) => ITEM_KEYS.forEach((k) => assert.ok(k in it, `PackagingItem.${k} missing`)));
  const [boxes, labels, stretch] = d.items;
  assert.match(boxes.id, /^PD-\d{4,}$/);
  assert.equal(boxes.quantity, 100);
  assert.equal(boxes.unitPricePiasters, 1500);
  assert.equal(boxes.totalPiasters, 150000);
  assert.equal(boxes.status, 'complete');
  assert.equal(labels.quantity, null);
  assert.equal(labels.unitPricePiasters, null);
  assert.equal(labels.totalPiasters, null);
  assert.equal(labels.status, 'incomplete');
  assert.equal(stretch.quantity, 4);
  assert.equal(stretch.unitPricePiasters, null);
  assert.equal(stretch.totalPiasters, null);
  assert.equal(stretch.status, 'incomplete');

  const row = env.findRow('packaging', pk.id);
  assert.equal(row['رقم الشراء'], pk.no);
  assert.equal(row['المورد'], 'مورد الكراتين');
  assert.equal(row['رقم الفاتورة'], 'INV-77');
  assert.equal(row['معرّف البراد'], cooler.id);
  assert.equal(row['الحالة'], 'مسودة');
  assert.equal(row['عدد العناصر'], 3);
  assert.equal(row['عناصر غير مكتملة'], 2);
  assert.equal(row['إجمالي العناصر المكتملة (ج.م)'], 1500);
  assert.ok(isDate(row['تاريخ ووقت الشراء']));
  assert.equal(row['مفتاح عدم التكرار'], rid);
  const items = env.readSheet('packaging_items');
  assert.equal(items.length, 3);
  const lab = items.find((r) => r['المعرّف'] === labels.id);
  assert.equal(lab['معرّف الشراء'], pk.id);
  assert.equal(lab['الكمية'], '', 'blank quantity stays blank, never 0');
  assert.equal(lab['السعر المفرد (ج.م)'], '', 'blank price stays blank');
  assert.equal(lab['الإجمالي (ج.م)'], '', 'no total for an incomplete item');
  assert.equal(lab['الحالة'], 'غير مكتمل');
  assert.equal(lab['الوحدة'], 'رول');
  const box = items.find((r) => r['المعرّف'] === boxes.id);
  assert.equal(box['الكمية'], 100);
  assert.equal(box['السعر المفرد (ج.م)'], 15);
  assert.equal(box['الإجمالي (ج.م)'], 1500);
  assert.equal(box['الحالة'], 'مكتمل');
  assert.equal(items.find((r) => r['المعرّف'] === stretch.id)['السعر المفرد (ج.م)'], '');
});

test('approve is blocked until every item is complete; removed items get محذوف and leave the totals', () => {
  const { env, admin, cooler } = setup();
  const d = saveDraft(env, admin, { supplier: 'مورد', coolerId: cooler.id, items: [
    { name: 'الصناديق', quantity: 100, unit: 'قطعة', unitPricePiasters: 1500 },
    { name: 'الملصقات', unit: 'رول' },
    { name: 'غطاء باليت', quantity: 2, unit: 'قطعة', unitPricePiasters: 9000 },
  ] });
  const before = dataSnapshot(env);
  fail(env.call(admin, 'packaging.approve', { id: d.packaging.id, expectedVersion: d.packaging.version }), 'VALIDATION',
    'approve with an incomplete item');
  assertNothingWritten(env, before, 'blocked approve');

  const [boxes, labels, cover] = d.items;
  const upd = saveDraft(env, admin, { id: d.packaging.id, expectedVersion: d.packaging.version, supplier: 'مورد',
    coolerId: cooler.id, items: [
      { id: boxes.id, name: 'الصناديق', quantity: 100, unit: 'قطعة', unitPricePiasters: 1500 },
      { id: labels.id, name: 'الملصقات', quantity: 10, unit: 'رول', unitPricePiasters: 2500 },
      { name: 'المناديل', quantity: 3, unit: 'كرتونة', unitPricePiasters: 4000 },
    ] });
  assert.equal(upd.packaging.id, d.packaging.id);
  assert.ok(upd.packaging.version > d.packaging.version);
  assert.equal(upd.packaging.itemsCount, 3, 'removed item excluded from counts');
  assert.equal(upd.packaging.incompleteCount, 0);
  assert.equal(upd.packaging.completeTotalPiasters, 150000 + 25000 + 12000, 'removed item excluded from totals');
  assert.equal(upd.items.length, 3);
  assert.equal(upd.items.some((it) => it.id === cover.id), false, 'removed item not returned');
  assert.equal(upd.items.find((it) => it.id === labels.id).totalPiasters, 25000);
  const coverRow = env.findRow('packaging_items', cover.id);
  assert.ok(coverRow, 'the removed item row is kept');
  assert.equal(coverRow['الحالة'], 'محذوف');
  assert.equal(env.readSheet('packaging_items').length, 4, 'no item rows deleted');
  const got = getPackaging(env, admin, d.packaging.id);
  assert.equal(got.items.length, 3);
  assert.equal(got.packaging.completeTotalPiasters, 187000);

  const appr = ok(env.call(admin, 'packaging.approve', { id: d.packaging.id, expectedVersion: upd.packaging.version }),
    'approve');
  assert.equal(appr.packaging.status, 'approved');
  assert.equal(appr.packaging.late, false);
  assert.equal(appr.items.length, 3);
  appr.items.forEach((it) => assert.equal(it.status, 'complete'));
  const row = env.findRow('packaging', d.packaging.id);
  assert.equal(row['الحالة'], 'معتمد');
  assert.equal(row['تكلفة متأخرة'], 'لا');
  assert.equal(piasters(row['إجمالي العناصر المكتملة (ج.م)']), 187000);

  // An approved purchase cannot be saved again.
  const before2 = dataSnapshot(env);
  fail(env.call(admin, 'packaging.save', { id: d.packaging.id, expectedVersion: appr.packaging.version, supplier: 'آخر',
    items: [{ name: 'الصناديق', quantity: 1, unit: 'قطعة', unitPricePiasters: 1 }] }), 'VALIDATION', 'save approved');
  assertNothingWritten(env, before2, 'saving an approved purchase');
  assert.equal(getCooler(env, admin, cooler.id).packagingApprovedPiasters, 187000);
});

test('approve needs at least one item', (t) => {
  const { env, admin } = setup();
  const res = env.call(admin, 'packaging.save', { supplier: 'مورد', items: [] });
  if (res.ok !== true) {
    failField(res, /items/, null, 'an empty draft may be refused with VALIDATION on items');
    t.diagnostic('backend refuses empty drafts; the >= 1 item rule is enforced at save time');
    return;
  }
  fail(env.call(admin, 'packaging.approve', { id: res.data.packaging.id, expectedVersion: res.data.packaging.version }),
    'VALIDATION', 'approve with no items');
  assert.equal(env.findRow('packaging', res.data.packaging.id)['الحالة'], 'مسودة');
});

test('item validation: quantity is an integer, prices are positive integers, unit from the list, name required', () => {
  const { env, admin } = setup();
  const before = dataSnapshot(env);
  const bad = [
    { name: 'الصناديق', quantity: 2.5, unit: 'قطعة', unitPricePiasters: 100 },
    { name: 'الصناديق', quantity: -1, unit: 'قطعة', unitPricePiasters: 100 },
    { name: 'الصناديق', quantity: 1, unit: 'قطعة', unitPricePiasters: -100 },
    { name: 'الصناديق', quantity: 1, unit: 'قطعة', unitPricePiasters: 10.5 },
    { name: 'الصناديق', quantity: 1, unit: 'برميل', unitPricePiasters: 100 },
    { name: '', quantity: 1, unit: 'قطعة', unitPricePiasters: 100 },
  ];
  for (const item of bad) {
    failField(env.call(admin, 'packaging.save', { supplier: 'مورد', items: [item] }), /items|quantity|unit|name|Price/i,
      null, `bad item ${JSON.stringify(item)}`);
  }
  assertNothingWritten(env, before, 'invalid items');
});

test('packaging.save: stale expectedVersion -> CONFLICT; creation is idempotent on requestId', () => {
  const { env, admin, cooler } = setup();
  const rid = uuid();
  const payload = { supplier: 'مورد', coolerId: cooler.id, items: [{ name: 'الصناديق', quantity: 5, unit: 'قطعة' }] };
  const first = saveDraft(env, admin, payload, rid);
  const again = saveDraft(env, admin, payload, rid);
  assert.equal(again.packaging.id, first.packaging.id);
  assert.equal(env.readSheet('packaging').length, 1, 'one packaging row');
  assert.equal(env.readSheet('packaging_items').length, 1, 'items not duplicated');
  env.cache.clear();
  const third = saveDraft(env, admin, payload, rid);
  assert.equal(third.packaging.id, first.packaging.id, 'detected through مفتاح عدم التكرار after the cache expired');
  assert.equal(env.readSheet('packaging').length, 1);
  assert.equal(env.readSheet('packaging_items').length, 1);

  const upd = saveDraft(env, admin, Object.assign({ id: first.packaging.id, expectedVersion: first.packaging.version },
    payload, { notes: 'تعديل' }));
  const e = fail(env.call(admin, 'packaging.save', Object.assign({ id: first.packaging.id,
    expectedVersion: first.packaging.version }, payload)), 'CONFLICT');
  assert.equal(e.details.currentVersion, upd.packaging.version);
  assert.equal(e.details.current.id, first.packaging.id);
});

test('late cost: approving a packaging purchase whose cooler is already closed sets تكلفة متأخرة = نعم', () => {
  const { env, admin, cooler } = setup();
  const farmer = newFarmer(env, admin, 'حسن');
  buy(env, admin, cooler, farmer);
  const d = saveDraft(env, admin, { supplier: 'مورد', coolerId: cooler.id,
    items: [{ name: 'الباليتات', quantity: 4, unit: 'قطعة', unitPricePiasters: 25000 }] });
  closeCooler(env, admin, cooler);
  const auditBefore = auditRows(env).length;
  const appr = ok(env.call(admin, 'packaging.approve', { id: d.packaging.id, expectedVersion: d.packaging.version }));
  assert.equal(appr.packaging.late, true);
  assert.equal(env.findRow('packaging', d.packaging.id)['تكلفة متأخرة'], 'نعم');
  const c = getCooler(env, admin, cooler.id);
  assert.equal(c.packagingLatePiasters, 100000);
  assert.equal(c.closeSnapshot.packagingPiasters, 0, 'the close snapshot is not rewritten');
  assert.ok(auditRows(env).length > auditBefore, 'approve is audited');
});

test('packaging.cancel: reason required; sets ملغى; list filters by status and cooler', () => {
  const { env, admin, cooler } = setup();
  const a = saveDraft(env, admin, { supplier: 'أ', coolerId: cooler.id, items: [{ name: 'الصناديق', unit: 'قطعة' }] });
  const b = saveDraft(env, admin, { supplier: 'ب', items: [{ name: 'الصناديق', unit: 'قطعة' }] });
  const c3 = saveDraft(env, admin, { supplier: 'ج', coolerId: cooler.id, items: [{ name: 'الشمبر', unit: 'رزمة' }] });
  failField(env.call(admin, 'packaging.cancel', { id: a.packaging.id }), 'reason', /سبب/);
  const c = ok(env.call(admin, 'packaging.cancel', { id: a.packaging.id, reason: 'طلب ملغى' })).packaging;
  assert.equal(c.status, 'cancelled');
  assert.equal(env.findRow('packaging', a.packaging.id)['الحالة'], 'ملغى');
  const ids = (payload) => ok(env.call(admin, 'packaging.list', payload)).packaging.map((p) => p.id).sort();
  assert.deepEqual(ids({ status: 'draft' }), [b.packaging.id, c3.packaging.id].sort());
  assert.deepEqual(ids({ status: 'cancelled' }), [a.packaging.id]);
  assert.deepEqual(ids({ status: 'draft', coolerId: cooler.id }), [c3.packaging.id]);
  assert.deepEqual(ids({ status: 'cancelled', coolerId: cooler.id }), [a.packaging.id]);
  fail(env.call(admin, 'packaging.save', { id: a.packaging.id, expectedVersion: c.version, supplier: 'أ', items: [] }),
    'VALIDATION', 'a cancelled purchase cannot be saved');
  fail(env.call(admin, 'packaging.get', { id: 'PK-9999' }), 'NOT_FOUND');
});
