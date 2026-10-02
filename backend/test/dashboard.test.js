'use strict';
/**
 * dashboard.get (docs/API.md section 6): KPIs are sums of stored per-record values; paid comes only from
 * payments; period filters; cooler restriction; recent list.
 */
const test = require('node:test');
const {
  assert, ok, adminEnv, newCooler, newFarmer, buy, pay, closeCooler, saveDraft, approvedPackaging, roundHalfUp,
  purchaseValue, isoIn,
} = require('./helpers');

const KPI_KEYS = ['closedCoolers', 'openCoolers', 'distinctFarmers', 'purchases', 'boxes', 'weightGrams',
  'purchaseValuePiasters', 'packagingApprovedPiasters', 'paidPiasters', 'remainingPiasters', 'remainingFarmersPiasters',
  'remainingSuppliersPiasters', 'avgPricePerKgPiasters'];

function dash(env, s, payload) {
  const d = ok(env.call(s, 'dashboard.get', payload), `dashboard.get ${JSON.stringify(payload)}`);
  KPI_KEYS.forEach((k) => assert.ok(Number.isInteger(d.kpis[k]), `kpis.${k} must be an integer, got ${d.kpis[k]}`));
  assert.ok(d.period && typeof d.period.key === 'string' && typeof d.period.label === 'string', 'period object');
  assert.ok(Array.isArray(d.openCoolers));
  assert.ok(Array.isArray(d.recent));
  assert.equal(typeof d.empty, 'boolean');
  return d;
}

test('an empty spreadsheet gives an empty dashboard with zero KPIs', () => {
  const { env, admin } = adminEnv();
  const d = dash(env, admin, { period: 'all' });
  assert.equal(d.empty, true);
  KPI_KEYS.forEach((k) => assert.equal(d.kpis[k], 0, `kpis.${k}`));
  assert.equal(d.currentCooler, null);
  assert.deepEqual(d.openCoolers, []);
  assert.deepEqual(d.recent, []);
});

test('KPIs equal the sums of the inserted records; paid comes only from active payments', () => {
  const { env, admin } = adminEnv();
  const c1 = newCooler(env, admin, { name: 'براد ١' });
  const c2 = newCooler(env, admin, { name: 'براد ٢' });
  const c3 = newCooler(env, admin, { name: 'براد ٣' });
  const f1 = newFarmer(env, admin, 'حسن');
  const f2 = newFarmer(env, admin, 'محمود');
  const f3 = newFarmer(env, admin, 'سعيد');

  const specs = [
    [c1, f1, 50, 11000, 1500, { mode: 'full', method: 'cash' }],
    [c1, f2, 30, 12500, 1550, { mode: 'partial', amountPiasters: 200000, method: 'bank' }],
    [c2, f1, 12, 9800, 1420, { mode: 'none' }],
    [c2, f3, 7, 13333, 1777, { mode: 'partial', amountPiasters: 1, method: 'wallet' }],
  ];
  const made = specs.map(([c, f, boxes, avg, price, payment]) =>
    buy(env, admin, c, f, { boxes, avgWeightGrams: avg, pricePerKgPiasters: price, payment }));
  // A payment that is later cancelled, and a cancelled purchase: neither counts.
  const cancelledPay = pay(env, admin, 'purchase', made[2].purchase.id, 5000).payment;
  ok(env.call(admin, 'payments.cancel', { id: cancelledPay.id, reason: 'خطأ' }));
  const extraPay = pay(env, admin, 'purchase', made[2].purchase.id, 70000).payment;
  const gone = buy(env, admin, c3, f3, { boxes: 999 }).purchase;
  ok(env.call(admin, 'purchases.cancel', { id: gone.id, reason: 'خطأ' }));

  // Packaging: one approved with a supplier payment, one draft (not counted).
  const appr = approvedPackaging(env, admin, c1, [{ name: 'الصناديق', quantity: 200, unit: 'قطعة', unitPricePiasters: 1450 },
    { name: 'الشريط', quantity: 3, unit: 'رول', unitPricePiasters: 3333 }]);
  const supplierPay = pay(env, admin, 'packaging', appr.packaging.id, 120000).payment;
  saveDraft(env, admin, { supplier: 'مورد آخر', items: [{ name: 'الصناديق', quantity: 50, unit: 'قطعة', unitPricePiasters: 1000 }] });
  closeCooler(env, admin, c2);

  // Someone overwrites the cached paid column of a purchase in the sheet: KPIs must not use it.
  env.updateRow('purchases', made[2].purchase.id, { 'المدفوع (ج.م)': 999999 });
  env.clock.advance(61 * 1000); // past any 60 s dashboard cache

  const values = specs.map(([, , b, a, p]) => purchaseValue(b, a, p));
  const weight = values.reduce((s, v) => s + v.totalWeightGrams, 0);
  const value = values.reduce((s, v) => s + v.valuePiasters, 0);
  const farmerPaid = values[0].valuePiasters + 200000 + 1 + extraPay.amountPiasters;
  const packaging = 200 * 1450 + 3 * 3333;
  const supplierPaid = supplierPay.amountPiasters;
  assert.equal(appr.packaging.completeTotalPiasters, packaging);

  const d = dash(env, admin, { period: 'all' });
  assert.equal(d.empty, false);
  assert.equal(d.period.key, 'all');
  const k = d.kpis;
  assert.equal(k.closedCoolers, 1);
  assert.equal(k.openCoolers, 2);
  assert.equal(k.distinctFarmers, 3);
  assert.equal(k.purchases, 4);
  assert.equal(k.boxes, 50 + 30 + 12 + 7);
  assert.equal(k.weightGrams, weight);
  assert.equal(k.purchaseValuePiasters, value);
  assert.equal(k.packagingApprovedPiasters, packaging);
  assert.equal(k.paidPiasters, farmerPaid + supplierPaid, 'paid = sum of active payments (farmers + suppliers)');
  assert.equal(k.remainingFarmersPiasters, value - farmerPaid);
  assert.equal(k.remainingSuppliersPiasters, packaging - supplierPaid);
  assert.equal(k.remainingPiasters, value + packaging - farmerPaid - supplierPaid);
  assert.equal(k.avgPricePerKgPiasters, roundHalfUp(value * 1000, weight));
  assert.deepEqual(d.openCoolers.map((c) => c.id).sort(), [c1.id, c3.id].sort());
});

test('currentCooler: the given cooler, else the open cooler opened last; coolerId restricts everything', () => {
  const { env, admin } = adminEnv();
  const a = newCooler(env, admin, { name: 'أ' });
  env.clock.advance(60 * 1000);
  const b = newCooler(env, admin, { name: 'ب' });
  env.clock.advance(60 * 1000);
  const f = newFarmer(env, admin, 'حسن');
  buy(env, admin, a, f, { boxes: 10 });
  buy(env, admin, a, f, { boxes: 20 });
  buy(env, admin, b, f, { boxes: 5 });
  const all = dash(env, admin, { period: 'all' });
  assert.equal(all.currentCooler && all.currentCooler.id, b.id, 'latest opened open cooler');
  assert.equal(all.kpis.purchases, 3);
  const onlyA = dash(env, admin, { period: 'all', coolerId: a.id });
  assert.equal(onlyA.currentCooler.id, a.id);
  assert.equal(onlyA.kpis.purchases, 2);
  assert.equal(onlyA.kpis.boxes, 30);
  assert.equal(onlyA.kpis.purchaseValuePiasters, purchaseValue(30, 11000, 1500).valuePiasters);
  closeCooler(env, admin, b);
  const later = dash(env, admin, { period: 'all' });
  assert.equal(later.currentCooler && later.currentCooler.id, a.id, 'b is closed now');
  assert.equal(later.kpis.closedCoolers, 1);
  assert.equal(later.kpis.openCoolers, 1);
});

test('periods filter purchases by occurredAt and payments by paidAt; cooler counts ignore the period', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  const DAY = 86400 * 1000;
  const ago = (ms) => isoIn(env.clock.now() - ms, 'Africa/Cairo');
  // Box counts are powers of two, so the boxes KPI tells exactly which purchases a period includes.
  const now = buy(env, admin, c, f, { boxes: 1 }).purchase;
  const threeDays = buy(env, admin, c, f, { boxes: 2, occurredAt: ago(3 * DAY) }).purchase;
  buy(env, admin, c, f, { boxes: 4, occurredAt: ago(10 * DAY) });
  buy(env, admin, c, f, { boxes: 8, occurredAt: ago(45 * DAY) });
  buy(env, admin, c, f, { boxes: 16, occurredAt: '2026-07-15T10:00:00+03:00' }); // before the season start (2026-08-01)
  pay(env, admin, 'purchase', now.id, 1000);
  pay(env, admin, 'purchase', threeDays.id, 2000, { paidAt: ago(3 * DAY) });
  const has = (boxes, bit) => (boxes & bit) === bit;

  const today = dash(env, admin, { period: 'today' });
  assert.equal(today.period.key, 'today');
  assert.equal(today.kpis.boxes, 1, 'today: only the purchase made now');
  assert.equal(today.kpis.purchases, 1);
  assert.equal(today.kpis.paidPiasters, 1000, 'today: only the payment made now');
  const week = dash(env, admin, { period: 'week' });
  assert.equal(week.period.key, 'week');
  assert.ok(has(week.kpis.boxes, 1), 'week includes now');
  assert.ok(!has(week.kpis.boxes, 4) && !has(week.kpis.boxes, 8) && !has(week.kpis.boxes, 16), 'week excludes 10+ days ago');
  const month = dash(env, admin, { period: 'month' });
  assert.equal(month.period.key, 'month');
  assert.ok(has(month.kpis.boxes, 1), 'month includes now');
  assert.ok(!has(month.kpis.boxes, 8) && !has(month.kpis.boxes, 16), 'month excludes 45+ days ago');
  const season = dash(env, admin, { period: 'season' });
  assert.equal(season.period.key, 'season');
  assert.equal(season.period.label, 'هذا الموسم');
  assert.match(String(season.period.from), /^2026-08-01/, 'season starts at settings بداية الموسم');
  assert.ok(has(season.kpis.boxes, 1), 'season includes now');
  assert.ok(!has(season.kpis.boxes, 16), 'purchase before the season start excluded');
  const all = dash(env, admin, { period: 'all' });
  assert.equal(all.kpis.boxes, 31);
  assert.equal(all.kpis.paidPiasters, 3000);
  for (const p of ['today', 'week', 'month', 'season', 'all']) {
    const d = dash(env, admin, { period: p });
    assert.equal(d.kpis.openCoolers, 1, `${p}: cooler counts ignore the period`);
    assert.equal(d.kpis.closedCoolers, 0);
  }
});

test('a write is visible immediately (the 60 s cache is keyed by the data version)', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن');
  buy(env, admin, c, f, { boxes: 3 });
  assert.equal(dash(env, admin, { period: 'all' }).kpis.boxes, 3);
  buy(env, admin, c, f, { boxes: 4 });
  assert.equal(dash(env, admin, { period: 'all' }).kpis.boxes, 7);
});

test('recent: the last 10 operations across purchases, payments and packaging, newest first, cancelled labelled', () => {
  const { env, admin } = adminEnv();
  const c = newCooler(env, admin);
  const f = newFarmer(env, admin, 'حسن البدري');
  const ids = [];
  for (let i = 0; i < 6; i++) {
    env.clock.advance(60 * 1000);
    ids.push(buy(env, admin, c, f, { boxes: i + 1 }).purchase.id);
  }
  for (let i = 0; i < 4; i++) {
    env.clock.advance(60 * 1000);
    ids.push(pay(env, admin, 'purchase', ids[i], 100).payment.id);
  }
  env.clock.advance(60 * 1000);
  ids.push(saveDraft(env, admin, { supplier: 'مورد', coolerId: c.id, items: [{ name: 'الصناديق', unit: 'قطعة' }] }).packaging.id);
  env.clock.advance(60 * 1000);
  const last = buy(env, admin, c, f, { boxes: 2 }).purchase;
  ok(env.call(admin, 'purchases.cancel', { id: last.id, reason: 'خطأ' }));
  ids.push(last.id);

  const d = dash(env, admin, { period: 'all' });
  assert.equal(d.recent.length, 10);
  d.recent.forEach((r) => {
    ['type', 'id', 'title', 'subtitle', 'coolerNo', 'at', 'amountPiasters', 'status', 'statusLabel']
      .forEach((key) => assert.ok(key in r, `recent.${key}`));
    assert.ok(['purchase', 'payment', 'packaging'].includes(r.type));
  });
  const times = d.recent.map((r) => Date.parse(r.at));
  assert.deepEqual(times, times.slice().sort((x, y) => y - x), 'newest first');
  assert.deepEqual(d.recent.map((r) => r.id), ids.slice(-10).reverse());
  const cancelled = d.recent[0];
  assert.equal(cancelled.id, last.id);
  assert.equal(cancelled.type, 'purchase');
  assert.equal(cancelled.status, 'cancelled');
  assert.match(cancelled.statusLabel, /[؀-ۿ]/);
  assert.equal(d.recent.find((r) => r.type === 'packaging').status, 'draft');
  assert.equal(d.recent.find((r) => r.type === 'payment').status, 'active');
});
