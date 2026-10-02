'use strict';
/**
 * Farmers (docs/API.md section 6).
 */
const test = require('node:test');
const {
  assert, ok, fail, failField, adminEnv, newFarmer, auditRows, isDate, dataSnapshot, assertNothingWritten,
} = require('./helpers');

test('farmers.create: id FR-NNNN, number max+1, phone kept as text, audit إنشاء مزارع', () => {
  const { env, admin } = adminEnv();
  const auditBefore = auditRows(env).length;
  const f = ok(env.call(admin, 'farmers.create', { name: 'حسن البدري', phone: '01001234567', village: 'البداري',
    notes: 'يفضل الدفع نقدًا' }), 'farmers.create').farmer;
  ['id', 'no', 'name', 'phone', 'village', 'notes', 'status', 'version'].forEach((k) => assert.ok(k in f, `farmer.${k}`));
  assert.match(f.id, /^FR-\d{4,}$/);
  assert.equal(f.no, 1);
  assert.equal(f.name, 'حسن البدري');
  assert.equal(f.phone, '01001234567');
  assert.equal(f.village, 'البداري');
  assert.equal(f.status, 'active');
  assert.equal(f.version, 1);
  const row = env.findRow('farmers', f.id);
  assert.equal(row['رقم المزارع'], 1);
  assert.equal(row['الهاتف'], '01001234567', 'leading zero kept');
  assert.equal(row['القرية / المنطقة'], 'البداري');
  assert.equal(row['الحالة'], 'نشط');
  assert.ok(isDate(row['تاريخ الإضافة']));
  assert.ok(String(row['أضافه']).length > 0);
  assert.equal(row['الإصدار'], 1);
  const a = auditRows(env).slice(auditBefore).find((r) => r['معرّف السجل'] === f.id);
  assert.ok(a && a['الإجراء'] === 'إنشاء' && a['نوع السجل'] === 'مزارع', 'audit إنشاء مزارع');

  env.appendRowObject('farmers', { 'المعرّف': 'FR-0040', 'رقم المزارع': 40, 'الاسم': 'مُضاف يدويًا', 'الحالة': 'نشط',
    'الإصدار': 1 });
  const g = newFarmer(env, admin, 'محمود');
  assert.equal(g.no, 41);
  assert.equal(g.id, 'FR-0041');
});

test('farmers.create: name required; same normalised name -> VALIDATION on name unless allowDuplicate', () => {
  const { env, admin } = adminEnv();
  newFarmer(env, admin, 'حسن البدري');
  const before = dataSnapshot(env);
  failField(env.call(admin, 'farmers.create', { name: '' }), 'name', /اسم/);
  failField(env.call(admin, 'farmers.create', { name: '   ' }), 'name', /اسم/);
  failField(env.call(admin, 'farmers.create', {}), 'name', /اسم/);
  failField(env.call(admin, 'farmers.create', { name: 'حسن البدري' }), 'name', /اسم|موجود|مسجل/);
  failField(env.call(admin, 'farmers.create', { name: '  حسن   البدري ' }), 'name', null, 'extra spaces normalised');
  assertNothingWritten(env, before, 'duplicate farmer');
  const dup = ok(env.call(admin, 'farmers.create', { name: 'حسن البدري', allowDuplicate: true })).farmer;
  assert.equal(dup.no, 2);
  assert.equal(env.readSheet('farmers').length, 2);
});

test('farmers.update with expectedVersion; CONFLICT when stale; inactive farmers hidden unless includeInactive', () => {
  const { env, admin } = adminEnv();
  const f = newFarmer(env, admin, 'حسن البدري', { phone: '01001234567' });
  const other = newFarmer(env, admin, 'محمود عيسى');
  const u = ok(env.call(admin, 'farmers.update', { id: f.id, expectedVersion: f.version, phone: '01112223334',
    village: 'أسيوط' })).farmer;
  assert.equal(u.phone, '01112223334');
  assert.equal(u.village, 'أسيوط');
  assert.equal(u.name, 'حسن البدري', 'unspecified fields unchanged');
  assert.equal(u.version, f.version + 1);
  const row = env.findRow('farmers', f.id);
  assert.equal(row['الهاتف'], '01112223334');
  assert.equal(row['الإصدار'], u.version);
  const e = fail(env.call(admin, 'farmers.update', { id: f.id, expectedVersion: f.version, phone: '01223334445' }), 'CONFLICT');
  assert.equal(e.details.currentVersion, u.version);
  assert.equal(e.details.current.phone, '01112223334');
  fail(env.call(admin, 'farmers.update', { id: 'FR-9999', expectedVersion: 1, phone: '01000000001' }), 'NOT_FOUND');

  const off = ok(env.call(admin, 'farmers.update', { id: other.id, expectedVersion: other.version, status: 'inactive' })).farmer;
  assert.equal(off.status, 'inactive');
  assert.equal(env.findRow('farmers', other.id)['الحالة'], 'موقوف');
  const listed = ok(env.call(admin, 'farmers.list', {})).farmers.map((x) => x.id);
  assert.deepEqual(listed, [f.id]);
  const all = ok(env.call(admin, 'farmers.list', { includeInactive: true })).farmers.map((x) => x.id).sort();
  assert.deepEqual(all, [f.id, other.id].sort());
  const q = ok(env.call(admin, 'farmers.list', { query: 'البدري', includeInactive: true })).farmers.map((x) => x.id);
  assert.deepEqual(q, [f.id]);
});
