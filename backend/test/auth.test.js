'use strict';
/**
 * Authentication and sessions (docs/API.md section 3).
 */
const test = require('node:test');
const {
  assert, ok, fail, adminEnv, addUser, userSession, createEnv, uuid, decodeSession, signSession, auditRows,
  assertIsoInZone, isDate, idNum, show, dataSnapshot, assertNothingWritten, CLIENT_IDS, ADMIN, BUSINESS_TZ,
  PERMISSION_KEYS, PERMISSION_COLUMNS, ENTRY_ALL,
} = require('./helpers');

const DAY_S = 86400;

function login(env, idToken) {
  return env.post({ action: 'auth.login', session: null, requestId: uuid(), payload: { idToken },
    client: { platform: 'android', version: '1.0.0' } });
}

function assertUserShape(u, label) {
  assert.match(String(u.id), /^US-\d{4,}$/, `${label}: id`);
  assert.equal(typeof u.email, 'string');
  assert.equal(typeof u.name, 'string');
  assert.ok(['admin', 'entry', 'viewer'].includes(u.role), `${label}: role ${u.role}`);
  assert.ok(['active', 'disabled'].includes(u.status), `${label}: status ${u.status}`);
  assert.equal(typeof u.isBootstrap, 'boolean', `${label}: isBootstrap`);
  assert.ok(Number.isInteger(u.version) && u.version >= 1, `${label}: version integer >= 1`);
  assert.deepEqual(Object.keys(u.permissions).sort(), PERMISSION_KEYS.slice().sort(), `${label}: permission keys`);
  PERMISSION_KEYS.forEach((k) => assert.equal(typeof u.permissions[k], 'boolean', `${label}: permissions.${k}`));
}

// ---------------------------------------------------------------------------------------------
// auth.login
// ---------------------------------------------------------------------------------------------

test('bootstrap admin: first login auto-provisions an active مدير row and returns { session, expiresAt, user }', () => {
  const env = createEnv();
  const idToken = env.registerGoogleUser(ADMIN, { name: 'المالك' });
  const data = ok(login(env, idToken), 'auth.login');
  assert.equal(typeof data.session, 'string');
  assert.ok(data.session.length > 20);
  assertUserShape(data.user, 'bootstrap user');
  assert.equal(data.user.email, ADMIN);
  assert.equal(data.user.name, 'المالك', 'name from tokeninfo');
  assert.equal(data.user.role, 'admin');
  assert.equal(data.user.status, 'active');
  assert.equal(data.user.isBootstrap, true);
  PERMISSION_KEYS.forEach((k) => assert.equal(data.user.permissions[k], true, `admin has ${k}`));

  const users = env.readSheet('users');
  assert.equal(users.length, 1, 'exactly one Users row');
  const row = users[0];
  assert.equal(row['المعرّف'], data.user.id);
  assert.equal(String(row['البريد (Gmail)']).toLowerCase(), ADMIN);
  assert.equal(row['الاسم'], 'المالك');
  assert.equal(row['الدور'], 'مدير');
  assert.equal(row['الحالة'], 'نشط');
  Object.values(PERMISSION_COLUMNS).forEach((h) => assert.equal(row[h], 'نعم', `${h} = نعم`));
  assert.equal(Number(row['الإصدار']), data.user.version);
  assert.ok(Number(row['الإصدار']) >= 1);
  assert.ok(isDate(row['تاريخ الإضافة']), 'تاريخ الإضافة is a date');

  // A second login reuses the row and is not audit-logged (section 3 step 5).
  const auditBefore = auditRows(env).length;
  const again = ok(login(env, env.registerGoogleUser(ADMIN, { name: 'المالك' })), 'second login');
  assert.equal(again.user.id, data.user.id);
  assert.equal(env.readSheet('users').length, 1, 'no duplicate row on the second login');
  assert.equal(auditRows(env).length, auditBefore, 'logins are not audit-logged');
});

test('bootstrap admin without a tokeninfo name is provisioned with the email as name', () => {
  const env = createEnv();
  const data = ok(login(env, env.registerGoogleUser(ADMIN, { name: null })), 'auth.login');
  assert.equal(data.user.name, ADMIN);
  assert.equal(env.readSheet('users')[0]['الاسم'], ADMIN);
});

test('expiresAt is an ISO-8601 timestamp in the business zone, SESSION_DAYS (default 7) after now', () => {
  const { env, admin } = adminEnv();
  assertIsoInZone(admin.expiresAt, BUSINESS_TZ, 'expiresAt');
  const expected = env.clock.now() + 7 * DAY_S * 1000;
  assert.ok(Math.abs(Date.parse(admin.expiresAt) - expected) < 5000, `expiresAt ~ now + 7 days, got ${admin.expiresAt}`);

  const env3 = createEnv({ extraProps: { SESSION_DAYS: '3' } });
  const s3 = env3.loginAs(ADMIN);
  assert.ok(Math.abs(Date.parse(s3.expiresAt) - (env3.clock.now() + 3 * DAY_S * 1000)) < 5000, 'SESSION_DAYS=3');
});

test('all three built-in client IDs are accepted as audience', () => {
  const env = createEnv();
  for (const aud of [CLIENT_IDS.web, CLIENT_IDS.ios, CLIENT_IDS.android]) {
    ok(login(env, env.registerGoogleUser(ADMIN, { aud })), `aud ${aud}`);
  }
});

test('Google ID tokens are rejected with AUTH_INVALID_TOKEN: wrong aud, wrong iss, unverified, expired, unknown', () => {
  const env = createEnv();
  const cases = [
    ['wrong aud', env.registerGoogleUser(ADMIN, { aud: '1234-other.apps.googleusercontent.com' })],
    ['wrong iss', env.registerGoogleUser(ADMIN, { iss: 'https://evil.example.com' })],
    ['unverified email', env.registerGoogleUser(ADMIN, { verified: false })],
    ['unverified (boolean false)', env.registerGoogleUser(ADMIN, { emailVerifiedRaw: false })],
    ['expired token', env.registerGoogleUser(ADMIN, { exp: Math.floor(env.clock.now() / 1000) - 10 })],
    ['unknown token (tokeninfo HTTP 400)', 'not-a-real-google-token'],
  ];
  for (const [label, idToken] of cases) {
    fail(login(env, idToken), 'AUTH_INVALID_TOKEN', label);
  }
  assert.equal(env.readSheet('users').length, 0, 'no Users row is created for rejected tokens');
  assert.equal(env.lastRequest.fetches.length, 1, 'tokeninfo is consulted');
  assert.equal(env.lastRequest.fetches[0].muteHttpExceptions, true, 'fetch uses muteHttpExceptions');
});

test('both issuer spellings and email_verified true/"true" are accepted', () => {
  const env = createEnv();
  ok(login(env, env.registerGoogleUser(ADMIN, { iss: 'accounts.google.com' })), 'iss accounts.google.com');
  ok(login(env, env.registerGoogleUser(ADMIN, { iss: 'https://accounts.google.com' })), 'iss https://…');
  ok(login(env, env.registerGoogleUser(ADMIN, { emailVerifiedRaw: true })), 'email_verified boolean true');
});

test('ALLOWED_CLIENT_IDS overrides the built-in client IDs', () => {
  const env = createEnv({ extraProps: { ALLOWED_CLIENT_IDS: 'custom-1.apps.googleusercontent.com, custom-2.apps.googleusercontent.com' } });
  ok(login(env, env.registerGoogleUser(ADMIN, { aud: 'custom-2.apps.googleusercontent.com' })), 'custom audience');
  fail(login(env, env.registerGoogleUser(ADMIN, { aud: CLIENT_IDS.web })), 'AUTH_INVALID_TOKEN', 'built-in id no longer allowed');
});

test('email not in the Users sheet -> NOT_ALLOWED with reason not_listed and details.email', () => {
  const { env } = adminEnv();
  const res = login(env, env.registerGoogleUser('Stranger@Gmail.com '));
  const e = fail(res, 'NOT_ALLOWED');
  assert.equal(e.details && e.details.reason, 'not_listed', show(res));
  assert.equal(e.details.email, 'stranger@gmail.com', 'details.email is lower-cased and trimmed');
  assert.equal(env.readSheet('users').length, 1, 'nothing appended for an unknown user');
});

test('no BOOTSTRAP_ADMIN_EMAIL and an empty Users sheet -> NOT_ALLOWED not_listed', () => {
  const env = createEnv({ bootstrapAdmin: null });
  const e = fail(login(env, env.registerGoogleUser(ADMIN)), 'NOT_ALLOWED');
  assert.equal(e.details.reason, 'not_listed');
  assert.equal(env.readSheet('users').length, 0);
});

test('disabled user -> NOT_ALLOWED with reason disabled', () => {
  const { env, admin } = adminEnv();
  const u = addUser(env, admin, 'karim@gmail.com', 'entry', ENTRY_ALL);
  ok(env.call(admin, 'users.update', { id: u.id, expectedVersion: u.version, status: 'disabled' }), 'disable');
  const e = fail(login(env, env.registerGoogleUser('karim@gmail.com')), 'NOT_ALLOWED');
  assert.equal(e.details.reason, 'disabled');
  assert.equal(e.details.email, 'karim@gmail.com');
});

test('a user disabled directly in the sheet cannot log in', () => {
  const { env, admin } = adminEnv();
  const u = addUser(env, admin, 'karim@gmail.com', 'entry', ENTRY_ALL);
  env.updateRow('users', u.id, { 'الحالة': 'معطّل' });
  env.clock.advance(61 * 1000); // user lookups may be cached for at most 60 s
  const e = fail(login(env, env.registerGoogleUser('karim@gmail.com')), 'NOT_ALLOWED');
  assert.equal(e.details.reason, 'disabled');
});

test('email matching is case-insensitive and trimmed (token side and sheet side)', () => {
  const { env, admin } = adminEnv();
  addUser(env, admin, 'Mixed.Case@Gmail.com', 'viewer');
  ok(login(env, env.registerGoogleUser('mixed.case@gmail.com')), 'lower-case token email');
  ok(login(env, env.registerGoogleUser('MIXED.CASE@GMAIL.COM')), 'upper-case token email');
  // A row typed by the owner directly in the sheet with odd casing and spaces.
  env.appendRowObject('users', { 'المعرّف': 'US-0050', 'البريد (Gmail)': '  Sara.Owner@GMAIL.com ', 'الاسم': 'سارة',
    'الدور': 'مشاهدة فقط', 'الحالة': 'نشط', 'الإصدار': 1 });
  env.clock.advance(61 * 1000);
  const d = ok(login(env, env.registerGoogleUser('sara.owner@gmail.com')), 'row typed in the sheet');
  assert.equal(d.user.id, 'US-0050');
  assert.equal(d.user.role, 'viewer');
  // Bootstrap admin with an upper-case token email.
  const b = ok(login(env, env.registerGoogleUser(ADMIN.toUpperCase())), 'bootstrap upper-case');
  assert.equal(b.user.role, 'admin');
  assert.equal(env.readSheet('users').filter((r) => String(r['البريد (Gmail)']).trim().toLowerCase() === ADMIN).length, 1,
    'still one bootstrap row');
});

test('bootstrap admin is break-glass: a disabled / demoted bootstrap row still logs in as active admin and is repaired', () => {
  const { env, admin } = adminEnv();
  env.updateRow('users', admin.user.id, { 'الحالة': 'معطّل', 'الدور': 'مشاهدة فقط', 'إضافة المزارعين': 'لا' });
  env.clock.advance(61 * 1000);
  const d = ok(login(env, env.registerGoogleUser(ADMIN)), 'bootstrap login');
  assert.equal(d.user.role, 'admin');
  assert.equal(d.user.status, 'active');
  PERMISSION_KEYS.forEach((k) => assert.equal(d.user.permissions[k], true));
  const row = env.findRow('users', admin.user.id);
  assert.equal(row['الدور'], 'مدير', 'row repaired: role');
  assert.equal(row['الحالة'], 'نشط', 'row repaired: status');
  assert.equal(env.readSheet('users').length, 1);
  ok(env.call(d.session, 'users.list', {}), 'repaired admin can manage users');
});

test('the bootstrap admin keeps working when its row is disabled directly in the sheet (status check excepted)', () => {
  const { env, admin } = adminEnv();
  env.updateRow('users', admin.user.id, { 'الحالة': 'معطّل' });
  env.clock.advance(61 * 1000);
  const me = ok(env.call(admin, 'auth.me', {}), 'auth.me');
  assert.equal(me.user.role, 'admin');
});

// ---------------------------------------------------------------------------------------------
// Sessions
// ---------------------------------------------------------------------------------------------

test('session token = base64url(payload).base64url(HMAC) with { uid, email, uv, iat, exp }', () => {
  const { env, admin } = adminEnv();
  const { payload } = decodeSession(admin.token);
  assert.equal(payload.uid, admin.user.id);
  assert.equal(String(payload.email).toLowerCase(), ADMIN);
  assert.equal(payload.uv, admin.user.version);
  assert.ok(Number.isInteger(payload.iat) && Number.isInteger(payload.exp), 'iat/exp are unix seconds');
  assert.ok(Math.abs(payload.iat - env.clock.now() / 1000) < 5, 'iat ~ now');
  assert.equal(payload.exp - payload.iat, 7 * DAY_S, 'default SESSION_DAYS = 7');
  assert.equal(payload.exp, Math.floor(Date.parse(admin.expiresAt) / 1000), 'expiresAt matches exp');
});

test('SESSION_SECRET is generated on first use, kept in Script Properties and never returned', () => {
  const env = createEnv();
  assert.equal(env.props.get('SESSION_SECRET'), null);
  const admin = env.loginAs(ADMIN);
  const secret = env.props.get('SESSION_SECRET');
  assert.ok(secret && secret.length >= 64, 'two UUIDs joined');
  const me = ok(env.call(admin, 'auth.me', {}));
  env.loginAs(ADMIN);
  assert.equal(env.props.get('SESSION_SECRET'), secret, 'not regenerated');
  for (const rec of env.history) {
    assert.equal(rec.rawContent.indexOf(secret), -1, `secret leaked in ${rec.label}`);
  }
  assert.equal(me.user.id, admin.user.id);
});

test('a token built per the contract with SESSION_SECRET is accepted; other secrets are not', () => {
  const { env, admin } = adminEnv();
  const secret = env.props.get('SESSION_SECRET');
  const { payload } = decodeSession(admin.token);
  const good = signSession(payload, secret);
  ok(env.call(good, 'auth.me', {}), 'contract-format token signed with SESSION_SECRET');
  fail(env.call(signSession(payload, 'not-the-secret'), 'auth.me', {}), 'AUTH_EXPIRED', 'wrong secret');
});

test('tampered session tokens -> AUTH_EXPIRED', () => {
  const { env, admin } = adminEnv();
  const [part, sig] = admin.token.split('.');
  const flip = (s, i) => s.slice(0, i) + (s[i] === 'A' ? 'B' : 'A') + s.slice(i + 1);
  fail(env.call(`${part}.${flip(sig, 3)}`, 'auth.me', {}), 'AUTH_EXPIRED', 'signature changed');
  const { payload } = decodeSession(admin.token);
  const longer = Object.assign({}, payload, { exp: payload.exp + 365 * DAY_S });
  const forgedPart = signSession(longer, 'x').split('.')[0];
  fail(env.call(`${forgedPart}.${sig}`, 'auth.me', {}), 'AUTH_EXPIRED', 'payload changed, old signature');
  fail(env.call(`${part}.`, 'auth.me', {}), 'AUTH_EXPIRED', 'missing signature');
  fail(env.call('garbage-token', 'auth.me', {}), 'AUTH_EXPIRED', 'not a token');
  fail(env.call(`${part}.${sig}.extra`, 'auth.me', {}), 'AUTH_EXPIRED', 'three parts');
  ok(env.call(admin, 'auth.me', {}), 'the genuine token still works');
});

test('session tampering cannot escalate: forged payloads are rejected on mutations and nothing is written', () => {
  const { env, admin } = adminEnv();
  const viewer = userSession(env, admin, 'viewer@gmail.com', 'viewer');
  const { payload: vp, parts } = decodeSession(viewer.token);
  const { payload: ap } = decodeSession(admin.token);
  const before = dataSnapshot(env);
  // The viewer swaps in the admin identity but cannot produce the HMAC.
  const asAdmin = Object.assign({}, vp, { uid: ap.uid, email: ap.email, uv: ap.uv });
  const forgedPart = signSession(asAdmin, 'guess').split('.')[0];
  fail(env.call(`${forgedPart}.${parts[1]}`, 'coolers.create', { name: 'x' }), 'AUTH_EXPIRED', 'admin identity, viewer signature');
  fail(env.call(signSession(asAdmin, 'guess'), 'users.add', { email: 'evil@gmail.com', name: 'x', role: 'admin' }),
    'AUTH_EXPIRED', 'admin identity, wrong secret');
  fail(env.call(`${parts[0]}.${decodeSession(admin.token).parts[1]}`, 'coolers.create', { name: 'x' }), 'AUTH_EXPIRED',
    'viewer payload with the admin signature');
  const lowerCaseSig = `${parts[0]}.${parts[1].toLowerCase()}`;
  if (lowerCaseSig !== viewer.token) fail(env.call(lowerCaseSig, 'auth.me', {}), 'AUTH_EXPIRED', 'signature case changed');
  assertNothingWritten(env, before, 'forged sessions');
  fail(env.call(viewer, 'coolers.create', { name: 'x' }), 'FORBIDDEN', 'the genuine viewer token is still only a viewer');
});

test('a session signed with an old SESSION_SECRET is rejected after the secret is deleted (log everyone out)', () => {
  const { env, admin } = adminEnv();
  ok(env.call(admin, 'auth.me', {}));
  env.props.delete('SESSION_SECRET');
  fail(env.call(admin, 'auth.me', {}), 'AUTH_EXPIRED', 'old token after the secret was removed');
  assert.ok(env.props.get('SESSION_SECRET'), 'a new secret is generated on first use');
  const again = env.loginAs(ADMIN);
  ok(env.call(again, 'auth.me', {}), 'a new login works with the new secret');
});

test('a correctly signed session whose row now holds another email is not accepted', () => {
  const { env, admin } = adminEnv();
  const k = userSession(env, admin, 'karim@gmail.com', 'entry', ENTRY_ALL);
  env.updateRow('users', k.added.id, { 'البريد (Gmail)': 'someone.else@gmail.com' });
  env.clock.advance(61 * 1000);
  const e = fail(env.call(k, 'coolers.create', { name: 'x' }), ['NOT_ALLOWED', 'SESSION_STALE']);
  if (e.code === 'NOT_ALLOWED') assert.equal(e.details.reason, 'not_listed');
  assert.equal(env.readSheet('coolers').length, 0);
});

test('expired session: SESSION_DAYS=0 -> AUTH_EXPIRED', () => {
  const env = createEnv({ extraProps: { SESSION_DAYS: '0' } });
  const admin = env.loginAs(ADMIN);
  env.clock.advance(1500);
  fail(env.call(admin, 'auth.me', {}), 'AUTH_EXPIRED');
});

test('expired session: default 7 days -> AUTH_EXPIRED after the 7th day', () => {
  const { env, admin } = adminEnv();
  env.clock.advance(7 * DAY_S * 1000 - 60 * 1000);
  ok(env.call(admin, 'auth.me', {}), 'still valid a minute before expiry');
  env.clock.advance(2 * 60 * 1000);
  fail(env.call(admin, 'auth.me', {}), 'AUTH_EXPIRED', 'after expiry');
});

test('a token whose exp has passed is rejected even when correctly signed', () => {
  const { env, admin } = adminEnv();
  const { payload } = decodeSession(admin.token);
  const nowS = Math.floor(env.clock.now() / 1000);
  const old = signSession(Object.assign({}, payload, { iat: nowS - 100, exp: nowS - 1 }), env.props.get('SESSION_SECRET'));
  fail(env.call(old, 'auth.me', {}), 'AUTH_EXPIRED');
});

test('SESSION_STALE after users.update changes that user; a new login works', () => {
  const { env, admin } = adminEnv();
  const karim = userSession(env, admin, 'karim@gmail.com', 'entry', ENTRY_ALL);
  ok(env.call(karim, 'auth.me', {}), 'fresh session works');
  const u = karim.added;
  const upd = ok(env.call(admin, 'users.update', { id: u.id, expectedVersion: u.version,
    permissions: Object.assign({}, ENTRY_ALL, { closeCoolers: false }) }), 'users.update');
  assert.ok(upd.user.version > u.version, 'users.update bumps the version');
  fail(env.call(karim, 'auth.me', {}), 'SESSION_STALE', 'old session after permissions change');
  fail(env.call(karim, 'coolers.list', { status: 'all' }), 'SESSION_STALE', 'also on reads');
  const again = env.loginAs('karim@gmail.com');
  assert.equal(again.user.version, upd.user.version);
  assert.equal(again.user.permissions.closeCoolers, false);
  ok(env.call(again, 'auth.me', {}));
});

test('SESSION_STALE after a role change', () => {
  const { env, admin } = adminEnv();
  const v = userSession(env, admin, 'viewer@gmail.com', 'viewer');
  ok(env.call(admin, 'users.update', { id: v.added.id, expectedVersion: v.added.version, role: 'entry',
    permissions: ENTRY_ALL }));
  fail(env.call(v, 'auth.me', {}), 'SESSION_STALE');
});

test('disabling a user through users.update ends that user\'s session', () => {
  const { env, admin } = adminEnv();
  const k = userSession(env, admin, 'karim@gmail.com', 'entry', ENTRY_ALL);
  ok(env.call(admin, 'users.update', { id: k.added.id, expectedVersion: k.added.version, status: 'disabled' }));
  fail(env.call(k, 'auth.me', {}), ['SESSION_STALE', 'NOT_ALLOWED']);
  fail(env.call(k, 'coolers.create', { name: 'x' }), ['SESSION_STALE', 'NOT_ALLOWED']);
  assert.equal(env.readSheet('coolers').length, 0);
});

test('a user disabled directly in the sheet is refused (NOT_ALLOWED disabled) once the 60 s user cache expires', () => {
  const { env, admin } = adminEnv();
  const k = userSession(env, admin, 'karim@gmail.com', 'entry', ENTRY_ALL);
  ok(env.call(k, 'auth.me', {}));
  env.updateRow('users', k.added.id, { 'الحالة': 'معطّل' });
  env.clock.advance(61 * 1000);
  const e = fail(env.call(k, 'auth.me', {}), 'NOT_ALLOWED');
  assert.equal(e.details && e.details.reason, 'disabled');
});

test('a version bumped directly in the sheet makes the session stale once the user cache expires', () => {
  const { env, admin } = adminEnv();
  const k = userSession(env, admin, 'karim@gmail.com', 'entry', ENTRY_ALL);
  env.updateRow('users', k.added.id, { 'الإصدار': k.added.version + 1 });
  env.clock.advance(61 * 1000);
  fail(env.call(k, 'auth.me', {}), 'SESSION_STALE');
});

test('auth.me returns the user; auth.logout returns {}', () => {
  const { env, admin } = adminEnv();
  const me = ok(env.call(admin, 'auth.me', {}), 'auth.me');
  assertUserShape(me.user, 'auth.me');
  assert.equal(me.user.id, admin.user.id);
  assert.deepEqual(me.user, admin.user);
  const out = ok(env.call(admin, 'auth.logout', {}, uuid()), 'auth.logout');
  assert.deepEqual(out, {});
});

test('role -> permissions: admin all, viewer only viewData (whatever the sheet columns say), entry = viewData + its columns', () => {
  const { env, admin } = adminEnv();
  const v = addUser(env, admin, 'viewer@gmail.com', 'viewer', ENTRY_ALL);
  PERMISSION_KEYS.forEach((k) => assert.equal(v.permissions[k], k === 'viewData', `viewer ${k}`));
  const vs = env.loginAs('viewer@gmail.com');
  PERMISSION_KEYS.forEach((k) => assert.equal(vs.user.permissions[k], k === 'viewData', `viewer session ${k}`));

  const partial = { addFarmers: true, recordPurchases: true, editOthers: false, recordPayments: true, packaging: false,
    closeCoolers: false };
  const e = addUser(env, admin, 'entry@gmail.com', 'entry', partial);
  Object.keys(partial).forEach((k) => assert.equal(e.permissions[k], partial[k], `entry ${k}`));
  assert.equal(e.permissions.viewData, true);
  ['reopenCoolers', 'manageUsers', 'manageSettings'].forEach((k) => assert.equal(e.permissions[k], false, `entry ${k}`));
  const row = env.findRow('users', e.id);
  Object.keys(partial).forEach((k) => assert.equal(row[PERMISSION_COLUMNS[k]], partial[k] ? 'نعم' : 'لا', PERMISSION_COLUMNS[k]));
  assert.equal(row['الدور'], 'موظف إدخال');

  const a = addUser(env, admin, 'second.admin@gmail.com', 'admin');
  PERMISSION_KEYS.forEach((k) => assert.equal(a.permissions[k], true, `admin ${k}`));
  assert.equal(a.isBootstrap, false);
  assert.equal(env.findRow('users', a.id)['الدور'], 'مدير');
  assert.ok(idNum(a.id) > idNum(admin.user.id));
});
