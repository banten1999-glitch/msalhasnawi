'use strict';
/**
 * Users management (docs/API.md sections 3 and 6).
 */
const test = require('node:test');
const {
  assert, ok, fail, failField, adminEnv, addUser, userSession, createEnv, auditRows, isDate, idNum, dataSnapshot,
  assertNothingWritten, ADMIN, ENTRY_ALL, PERMISSION_COLUMNS,
} = require('./helpers');

test('users.add: entry user row with Arabic role/status and نعم/لا permission columns; audit إنشاء مستخدم', () => {
  const { env, admin } = adminEnv();
  const auditBefore = auditRows(env).length;
  const perms = { addFarmers: true, recordPurchases: true, editOthers: false, recordPayments: false, packaging: true,
    closeCoolers: false };
  const u = ok(env.call(admin, 'users.add', { email: 'karim@gmail.com', name: 'كريم عبد الله', role: 'entry',
    permissions: perms }), 'users.add').user;
  assert.match(u.id, /^US-\d{4,}$/);
  assert.equal(idNum(u.id), idNum(admin.user.id) + 1);
  assert.equal(u.email, 'karim@gmail.com');
  assert.equal(u.name, 'كريم عبد الله');
  assert.equal(u.role, 'entry');
  assert.equal(u.status, 'active');
  assert.equal(u.isBootstrap, false);
  assert.equal(u.version, 1);
  const row = env.findRow('users', u.id);
  assert.equal(String(row['البريد (Gmail)']).toLowerCase(), 'karim@gmail.com');
  assert.equal(row['الاسم'], 'كريم عبد الله');
  assert.equal(row['الدور'], 'موظف إدخال');
  assert.equal(row['الحالة'], 'نشط');
  Object.keys(perms).forEach((k) => assert.equal(row[PERMISSION_COLUMNS[k]], perms[k] ? 'نعم' : 'لا'));
  assert.ok(isDate(row['تاريخ الإضافة']));
  assert.ok(String(row['أضافه']).length > 0);
  assert.equal(row['الإصدار'], 1);
  const a = auditRows(env).slice(auditBefore).find((r) => r['معرّف السجل'] === u.id);
  assert.ok(a, 'audit row for users.add');
  assert.equal(a['الإجراء'], 'إنشاء');
  assert.equal(a['نوع السجل'], 'مستخدم');

  const list = ok(env.call(admin, 'users.list', {})).users;
  assert.deepEqual(list.map((x) => x.id).sort(), [admin.user.id, u.id].sort());
  assert.equal(list.find((x) => x.id === admin.user.id).isBootstrap, true);
  env.loginAs('karim@gmail.com');
});

test('users.add validation: email must look like an email, duplicates (any case) rejected, role and name required', () => {
  const { env, admin } = adminEnv();
  addUser(env, admin, 'karim@gmail.com', 'viewer');
  const before = dataSnapshot(env);
  for (const email of ['karim', 'karim@', '@gmail.com', 'karim gmail.com', '']) {
    failField(env.call(admin, 'users.add', { email, name: 'س', role: 'viewer' }), 'email', /بريد/, `email "${email}"`);
  }
  failField(env.call(admin, 'users.add', { email: 'KARIM@gmail.com', name: 'كريم', role: 'viewer' }), 'email', /بريد/,
    'duplicate in another case');
  failField(env.call(admin, 'users.add', { email: ` ${ADMIN} `, name: 'المالك', role: 'admin' }), 'email', /بريد/,
    'duplicate of the bootstrap admin');
  failField(env.call(admin, 'users.add', { email: 'new@gmail.com', name: 'جديد', role: 'boss' }), 'role', /دور/);
  failField(env.call(admin, 'users.add', { email: 'new@gmail.com', name: '', role: 'viewer' }), 'name', /اسم/);
  assertNothingWritten(env, before, 'invalid users.add');
});

test('users.update: name/role/status/permissions with optimistic concurrency', () => {
  const { env, admin } = adminEnv();
  const u = addUser(env, admin, 'karim@gmail.com', 'entry', ENTRY_ALL);
  const upd = ok(env.call(admin, 'users.update', { id: u.id, expectedVersion: u.version, name: 'كريم ع.',
    permissions: Object.assign({}, ENTRY_ALL, { editOthers: false }) })).user;
  assert.equal(upd.name, 'كريم ع.');
  assert.equal(upd.permissions.editOthers, false);
  assert.equal(upd.version, u.version + 1);
  const row = env.findRow('users', u.id);
  assert.equal(row['تعديل عمليات الآخرين'], 'لا');
  assert.equal(row['الإصدار'], upd.version);
  assert.ok(isDate(row['آخر تعديل']));
  const e = fail(env.call(admin, 'users.update', { id: u.id, expectedVersion: u.version, name: 'قديم' }), 'CONFLICT');
  assert.equal(e.details.currentVersion, upd.version);
  assert.equal(e.details.current.id, u.id);
  const v = ok(env.call(admin, 'users.update', { id: u.id, expectedVersion: upd.version, role: 'viewer' })).user;
  assert.equal(v.role, 'viewer');
  assert.equal(env.findRow('users', u.id)['الدور'], 'مشاهدة فقط');
  const d = ok(env.call(admin, 'users.update', { id: u.id, expectedVersion: v.version, status: 'disabled' })).user;
  assert.equal(d.status, 'disabled');
  assert.equal(env.findRow('users', u.id)['الحالة'], 'معطّل');
  fail(env.call(admin, 'users.update', { id: 'US-9999', expectedVersion: 1, name: 'x' }), 'NOT_FOUND');
  failField(env.call(admin, 'users.update', { id: u.id, expectedVersion: d.version, role: 'boss' }), 'role', /دور/);
});

test('the bootstrap admin cannot be disabled or demoted', () => {
  const { env, admin } = adminEnv();
  const second = userSession(env, admin, 'second.admin@gmail.com', 'admin');
  const boot = admin.user;
  const before = dataSnapshot(env);
  fail(env.call(second, 'users.update', { id: boot.id, expectedVersion: boot.version, status: 'disabled' }), 'VALIDATION',
    'disable bootstrap');
  fail(env.call(second, 'users.update', { id: boot.id, expectedVersion: boot.version, role: 'viewer' }), 'VALIDATION',
    'demote bootstrap');
  fail(env.call(admin, 'users.update', { id: boot.id, expectedVersion: boot.version, role: 'entry',
    permissions: ENTRY_ALL }), 'VALIDATION', 'bootstrap demoting itself');
  assertNothingWritten(env, before, 'bootstrap protection');
  ok(env.call(admin, 'auth.me', {}), 'bootstrap session untouched');
});

test('the last active admin cannot be disabled or demoted ("آخر مدير نشط")', () => {
  const { env, admin } = adminEnv();
  // The owner removes the bootstrap property: the provisioned row is now an ordinary admin.
  env.props.delete('BOOTSTRAP_ADMIN_EMAIL');
  const b = userSession(env, admin, 'b.admin@gmail.com', 'admin');
  ok(env.call(admin, 'users.update', { id: b.added.id, expectedVersion: b.added.version, role: 'entry',
    permissions: ENTRY_ALL }), 'demoting another admin is fine while one admin remains');
  const self = ok(env.call(admin, 'auth.me', {})).user;
  assert.equal(self.isBootstrap, false);
  const before = dataSnapshot(env);
  const e1 = fail(env.call(admin, 'users.update', { id: self.id, expectedVersion: self.version, status: 'disabled' }),
    'VALIDATION', 'disable the last admin');
  assert.match(e1.message, /آخر مدير/);
  const e2 = fail(env.call(admin, 'users.update', { id: self.id, expectedVersion: self.version, role: 'viewer' }),
    'VALIDATION', 'demote the last admin');
  assert.match(e2.message, /آخر مدير/);
  assertNothingWritten(env, before, 'last admin protection');
});

test('a disabled admin does not count as an active admin', () => {
  const env = createEnv();
  const admin = env.loginAs(ADMIN);
  env.props.delete('BOOTSTRAP_ADMIN_EMAIL');
  const b = addUser(env, admin, 'b.admin@gmail.com', 'admin');
  ok(env.call(admin, 'users.update', { id: b.id, expectedVersion: b.version, status: 'disabled' }), 'disable B');
  const self = ok(env.call(admin, 'auth.me', {})).user;
  fail(env.call(admin, 'users.update', { id: self.id, expectedVersion: self.version, role: 'viewer' }), 'VALIDATION');
});

test('a new user can log in right after users.add (users cache cleared on users.* writes)', () => {
  const { env, admin } = adminEnv();
  const login = (email) => env.post({ action: 'auth.login', session: null, requestId: 'r',
    payload: { idToken: env.registerGoogleUser(email) } });
  fail(login('late@gmail.com'), 'NOT_ALLOWED');
  addUser(env, admin, 'late@gmail.com', 'viewer');
  ok(login('late@gmail.com'), 'login right after users.add');
});
