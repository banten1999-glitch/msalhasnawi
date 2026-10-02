'use strict';
/**
 * Permissions are enforced in the backend for every action (docs/API.md sections 3 and 6).
 */
const test = require('node:test');
const {
  assert, ok, forbidden, adminEnv, userSession, newCooler, newFarmer, buy, pay, saveDraft, getCooler, getPurchase,
  dataSnapshot, assertNothingWritten, ENTRY_ALL, ENTRY_NONE,
} = require('./helpers');

/** Records created by the admin that the other roles try to touch. */
function fixture() {
  const { env, admin } = adminEnv();
  const cooler = newCooler(env, admin, { name: 'براد الصلاحيات' });
  const closed = newCooler(env, admin, { name: 'براد مقفّل' });
  const farmer = newFarmer(env, admin, 'حسن البدري');
  const bought = buy(env, admin, cooler, farmer, { payment: { mode: 'partial', amountPiasters: 1000, method: 'cash' } });
  const draft = saveDraft(env, admin, { supplier: 'مورد', coolerId: cooler.id,
    items: [{ name: 'الصناديق', quantity: 10, unit: 'قطعة', unitPricePiasters: 500 }] });
  const fresh = getCooler(env, admin, closed.id);
  ok(env.call(admin, 'coolers.close', { id: closed.id, expectedVersion: fresh.version, clientPendingCount: 0 }));
  return { env, admin, cooler, closed: getCooler(env, admin, closed.id), farmer, purchase: bought.purchase,
    payment: bought.payment, draft: draft.packaging };
}

/** Every mutation with a payload that would succeed for an admin, and the permission it needs. */
function mutations(f) {
  return [
    ['coolers.create', { name: 'براد' }, 'recordPurchases'],
    ['coolers.close', { id: f.cooler.id, expectedVersion: f.cooler.version, clientPendingCount: 0 }, 'closeCoolers'],
    ['coolers.reopen', { id: f.closed.id, reason: 'خطأ في التقفيل' }, 'reopenCoolers'],
    ['farmers.create', { name: 'مزارع جديد' }, 'addFarmers'],
    ['farmers.update', { id: f.farmer.id, expectedVersion: f.farmer.version, phone: '01001234567' }, 'addFarmers'],
    ['purchases.create', { coolerId: f.cooler.id, farmerId: f.farmer.id, boxes: 1, avgWeightGrams: 1000,
      weightMethod: 'direct', pricePerKgPiasters: 100, payment: { mode: 'none' } }, 'recordPurchases'],
    ['purchases.update', { id: f.purchase.id, expectedVersion: f.purchase.version, changes: { notes: 'x' } },
      ['recordPurchases', 'editOthers']],
    ['purchases.cancel', { id: f.purchase.id, reason: 'خطأ' }, ['recordPurchases', 'editOthers']],
    ['payments.create', { targetType: 'purchase', targetId: f.purchase.id, amountPiasters: 100, method: 'cash' },
      'recordPayments'],
    ['payments.cancel', { id: f.payment.id, reason: 'خطأ' }, 'recordPayments'],
    ['packaging.save', { supplier: 'مورد', items: [] }, 'packaging'],
    ['packaging.approve', { id: f.draft.id, expectedVersion: f.draft.version }, 'packaging'],
    ['packaging.cancel', { id: f.draft.id, reason: 'خطأ' }, 'packaging'],
    ['itemTypes.save', { name: 'صنف', unit: 'قطعة' }, 'manageSettings'],
    ['users.list', {}, 'manageUsers'],
    ['users.add', { email: 'new.person@gmail.com', name: 'جديد', role: 'viewer' }, 'manageUsers'],
    ['users.update', { id: f.admin.user.id, expectedVersion: f.admin.user.version, name: 'اسم' }, 'manageUsers'],
    ['settings.update', { businessName: 'اسم آخر' }, 'manageSettings'],
    ['sheet.status', {}, 'manageSettings'],
    ['sheet.repair', {}, 'manageSettings'],
    ['sheet.connect', { spreadsheet: 'some-id' }, 'manageSettings'],
  ];
}

const READS = [
  ['dashboard.get', { period: 'all' }],
  ['coolers.list', { status: 'all' }],
  ['farmers.list', {}],
  ['purchases.list', {}],
  ['payments.list', {}],
  ['packaging.list', {}],
  ['itemTypes.list', {}],
  ['settings.get', {}],
  ['auth.me', {}],
];

test('viewer can read everything but every mutation is FORBIDDEN (details.permission) and writes nothing', () => {
  const f = fixture();
  const { env } = f;
  const viewer = userSession(env, f.admin, 'viewer@gmail.com', 'viewer', ENTRY_ALL);
  for (const [action, payload] of READS.concat([['coolers.get', { id: f.cooler.id }], ['packaging.get', { id: f.draft.id }]])) {
    ok(env.call(viewer, action, payload), `viewer ${action}`);
  }
  const before = dataSnapshot(env);
  for (const [action, payload, perm] of mutations(f)) {
    forbidden(env.call(viewer, action, payload), perm, `viewer ${action}`);
  }
  assertNothingWritten(env, before, 'viewer mutations');
});

test('entry without closeCoolers cannot close; with it, can close', () => {
  const f = fixture();
  const { env } = f;
  const noClose = userSession(env, f.admin, 'noclose@gmail.com', 'entry', Object.assign({}, ENTRY_ALL, { closeCoolers: false }));
  const c = getCooler(env, f.admin, f.cooler.id);
  forbidden(env.call(noClose, 'coolers.close', { id: c.id, expectedVersion: c.version, clientPendingCount: 0 }),
    'closeCoolers');
  assert.equal(env.findRow('coolers', c.id)['الحالة'], 'مفتوح');
  const closer = userSession(env, f.admin, 'closer@gmail.com', 'entry', ENTRY_ALL);
  ok(env.call(closer, 'coolers.close', { id: c.id, expectedVersion: c.version, clientPendingCount: 0 }), 'entry closes');
});

test('reopen is admin-only: entry with every entry permission gets FORBIDDEN reopenCoolers', () => {
  const f = fixture();
  const { env } = f;
  const entry = userSession(env, f.admin, 'entry@gmail.com', 'entry', ENTRY_ALL);
  forbidden(env.call(entry, 'coolers.reopen', { id: f.closed.id, reason: 'إعادة' }), 'reopenCoolers');
  assert.equal(env.findRow('coolers', f.closed.id)['الحالة'], 'مقفّل');
  ok(env.call(f.admin, 'coolers.reopen', { id: f.closed.id, reason: 'إعادة' }), 'admin reopens');
});

test('sheet.*, settings.update and itemTypes.save need manageSettings; users.* need manageUsers (admin only)', () => {
  const f = fixture();
  const { env } = f;
  const entry = userSession(env, f.admin, 'entry@gmail.com', 'entry', ENTRY_ALL);
  const before = dataSnapshot(env);
  for (const [action, payload, perm] of mutations(f)) {
    if (!/^(sheet|users|settings|itemTypes)\./.test(action)) continue;
    forbidden(env.call(entry, action, payload), perm, `entry ${action}`);
  }
  assertNothingWritten(env, before, 'entry admin-only actions');
  ok(env.call(f.admin, 'sheet.status', {}), 'admin sheet.status');
  ok(env.call(f.admin, 'users.list', {}), 'admin users.list');
});

test('each entry permission gates its own actions', () => {
  const f = fixture();
  const { env } = f;
  const none = userSession(env, f.admin, 'none@gmail.com', 'entry', ENTRY_NONE);
  const before = dataSnapshot(env);
  for (const [action, payload, perm] of mutations(f)) {
    forbidden(env.call(none, action, payload), perm, `entry without permissions: ${action}`);
  }
  assertNothingWritten(env, before, 'entry without permissions');
  for (const [action, payload] of READS) ok(env.call(none, action, payload), `entry reads ${action}`);
});

test('purchases.create with newFarmerName also needs addFarmers', () => {
  const f = fixture();
  const { env } = f;
  const buyer = userSession(env, f.admin, 'buyer@gmail.com', 'entry', Object.assign({}, ENTRY_ALL, { addFarmers: false }));
  const base = { coolerId: f.cooler.id, boxes: 2, avgWeightGrams: 10000, weightMethod: 'direct',
    pricePerKgPiasters: 1500, payment: { mode: 'none' } };
  forbidden(env.call(buyer, 'purchases.create', Object.assign({ newFarmerName: 'مزارع جديد' }, base)), 'addFarmers');
  assert.equal(env.readSheet('farmers').length, 1, 'no farmer created');
  forbidden(env.call(buyer, 'farmers.create', { name: 'مزارع جديد' }), 'addFarmers');
  ok(env.call(buyer, 'purchases.create', Object.assign({ farmerId: f.farmer.id }, base)), 'existing farmer is fine');
});

test('editing or cancelling another user\'s purchase needs editOthers; own purchases do not', () => {
  const f = fixture();
  const { env } = f;
  const plain = userSession(env, f.admin, 'plain@gmail.com', 'entry', Object.assign({}, ENTRY_ALL, { editOthers: false }));
  const p = getPurchase(env, f.admin, f.purchase.id);
  forbidden(env.call(plain, 'purchases.update', { id: p.id, expectedVersion: p.version, changes: { notes: 'x' } }), 'editOthers');
  forbidden(env.call(plain, 'purchases.cancel', { id: p.id, reason: 'خطأ' }), 'editOthers');
  const own = buy(env, plain, f.cooler, f.farmer, { boxes: 3 }).purchase;
  const upd = ok(env.call(plain, 'purchases.update', { id: own.id, expectedVersion: own.version, changes: { boxes: 4 } }));
  assert.equal(upd.purchase.boxes, 4);
  ok(env.call(plain, 'purchases.cancel', { id: own.id, reason: 'خطأ في الإدخال' }), 'cancel own');
  const editor = userSession(env, f.admin, 'editor@gmail.com', 'entry', ENTRY_ALL);
  ok(env.call(editor, 'purchases.update', { id: p.id, expectedVersion: p.version, changes: { notes: 'تعديل' } }),
    'editOthers allows editing the admin\'s purchase');
});

test('payments need recordPayments; packaging needs packaging', () => {
  const f = fixture();
  const { env } = f;
  const noPay = userSession(env, f.admin, 'nopay@gmail.com', 'entry', Object.assign({}, ENTRY_ALL, { recordPayments: false }));
  forbidden(env.call(noPay, 'payments.create', { targetType: 'purchase', targetId: f.purchase.id, amountPiasters: 10,
    method: 'cash' }), 'recordPayments');
  const noPack = userSession(env, f.admin, 'nopack@gmail.com', 'entry', Object.assign({}, ENTRY_ALL, { packaging: false }));
  forbidden(env.call(noPack, 'packaging.save', { supplier: 'x', items: [] }), 'packaging');
  pay(env, noPack, 'purchase', f.purchase.id, 10);
});
